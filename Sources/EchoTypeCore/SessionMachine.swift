import Foundation

/// The session's only source of time, injected so that tests move time forward explicitly
/// instead of waiting.
///
/// A session needs one wake-up at a time: the silence timeout while listening, and the hard cap
/// once it is paused or once silence has already fired. Scheduling replaces whatever was
/// pending, so there is no timer identity to track on either side of the seam.
public protocol SessionClock: Sendable {
  /// Seconds on a monotonic timeline. Only differences are meaningful.
  var now: TimeInterval { get }

  /// Runs `fire` when the clock reaches `deadline`, replacing any wake-up scheduled before it.
  func schedule(at deadline: TimeInterval, fire: @Sendable @escaping () async -> Void)

  /// Cancels the pending wake-up, if any.
  func cancel()
}

/// The clock a real session runs on.
///
/// Time is `systemUptime` rather than a date, so a session is unaffected by the wall clock
/// moving under it.
public final class SystemClock: SessionClock, @unchecked Sendable {
  private let lock = NSLock()
  private var pending: Task<Void, Never>?

  public init() {}

  public var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

  public func schedule(at deadline: TimeInterval, fire: @Sendable @escaping () async -> Void) {
    let delay = max(0, deadline - now)
    let task = Task {
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await fire()
    }
    lock.lock()
    let previous = pending
    pending = task
    lock.unlock()
    previous?.cancel()
  }

  public func cancel() {
    lock.lock()
    let previous = pending
    pending = nil
    lock.unlock()
    previous?.cancel()
  }
}

/// Why a session ended badly, in the form the overlay has to render.
public enum SessionError: Error, Equatable, Sendable {
  /// The endpoint reported a failure, or the client could not read the stream.
  case stt(STTError)
  /// The socket failed or closed before the transcript was finalised.
  case socket(String)

  init(_ error: any Error) {
    if let error = error as? STTError {
      self = .stt(error)
    } else {
      self = .socket(String(describing: error))
    }
  }
}

/// One dictation session, from the hotkey that starts it to the text a macOS layer inserts.
///
/// The machine owns the socket for the life of the session, drives an `STTClient` over it, and
/// decides when to pause, cancel, finalise or give up. Nothing is ever committed by a timer
/// except the hard cap: quiet only changes what the overlay renders.
///
/// Usage is `run()` in its own task, `send(audio:)` while it lasts, and `trigger()` or
/// `cancel()` to end it. `run()` returns the session's one outcome, and `states` carries the
/// transitions an overlay renders.
///
/// `states` carries no transcript text, because nothing renders it yet. An overlay that wants
/// live text extends this type rather than reading the socket itself: a WebSocket message is
/// delivered to exactly one reader, so a second read would take frames away from this one.
public actor SessionMachine {
  /// The specification's states. `listening` and `paused` differ only in what is rendered;
  /// audio streams in both.
  public enum State: Equatable, Sendable {
    case idle
    case listening
    case paused
    case finalizing
    case inserting
    case cancelled
  }

  /// What a session leaves behind. Exactly one of these is produced, by `run()`.
  public enum Outcome: Equatable, Sendable {
    /// Text to insert. Never empty.
    case insert(String)
    /// Nothing to insert: cancelled, never spoken, or an empty transcript.
    case nothing
    /// The session's transcript ended without the user asking for it: the socket failed, closed,
    /// or finalised itself. Whatever was finalised before that survives, because losing a minute
    /// of speech to a dropped connection is worse than inserting a visibly truncated transcript.
    case failed(text: String, error: SessionError)
  }

  /// How the message loop ended, which is what decides the outcome.
  private enum Ending {
    case finalised
    case cancelled
    /// The transcript ended without a trigger: the socket closed, or sent `transcript.done`
    /// unasked.
    case closed
    case failed(any Error)
  }

  private let transport: any WebSocketTransport
  private let settings: Settings
  private let clock: any SessionClock
  private let relay: RelayTransport
  private let client: STTClient

  /// Every state the session enters, in order. Finishes when the session does.
  public nonisolated let states: AsyncStream<State>
  private nonisolated let transitions: AsyncStream<State>.Continuation

  private var state: State = .idle

  private var startedAt: TimeInterval = 0
  private var lastSpeechAt: TimeInterval = 0
  private var heardSpeech = false
  private var ending: Ending?
  private var clientTask: Task<String, any Error>?

  public init(transport: any WebSocketTransport, settings: Settings, clock: any SessionClock) {
    self.transport = transport
    self.settings = settings
    self.clock = clock
    let relay = RelayTransport(base: transport)
    self.relay = relay
    self.client = STTClient(transport: relay)
    (states, transitions) = AsyncStream.makeStream(of: State.self)
  }

  /// Runs the session to its one outcome.
  ///
  /// Reads the socket itself and hands every message on to the client, because the client
  /// exposes only the final text while pausing needs to see the partials.
  public func run() async -> Outcome {
    guard state == .idle else { return .nothing }
    begin()
    let ending = await readUntilEnd()
    return await conclude(ending)
  }

  /// Hands one chunk of audio to the endpoint. Audio streams while paused too, since pausing is
  /// a display state.
  public func send(audio: Data) async throws {
    guard isActive else { return }
    try await client.send(audio: audio)
  }

  /// Opt+D or a click on the overlay: commit what has accumulated.
  public func trigger() async {
    guard isActive else { return }
    await beginFinalizing()
  }

  /// Escape: discard everything.
  public func cancel() {
    guard isActive else { return }
    ending = .cancelled
    transition(to: .cancelled)
    clock.cancel()
    transport.close()
  }

  /// Whether the session still accepts input: it is streaming, and nothing has ended it yet.
  ///
  /// `ending` is set the moment the outcome is decided, including before `conclude` suspends
  /// waiting for the client, so a late `trigger()` or `cancel()` cannot land behind a session
  /// that is already on its way out.
  private var isActive: Bool {
    ending == nil && (state == .listening || state == .paused)
  }

  private func begin() {
    startedAt = clock.now
    lastSpeechAt = startedAt
    transition(to: .listening)
    clientTask = Task { [client] in try await client.run() }
    reschedule()
  }

  private func readUntilEnd() async -> Ending {
    do {
      for try await message in transport.messages() {
        // A frame that is not decodable JSON throws here and ends the session the same way a
        // dropped socket does. The client throws on that frame too, so carrying on would leave
        // the two disagreeing: the session would keep reporting `listening` while its transcript
        // had already stopped growing, and the trigger would report a truncation as a success.
        if let event = try STTEvent.decode(message) {
          observe(event)
        }
        relay.deliver(message)
        if let ending { return ending }
      }
      // A socket that closes once finalisation is under way has said everything it is going to
      // say, so the transcript in hand is the result rather than a failure.
      return ending ?? (state == .finalizing ? .finalised : .closed)
    } catch {
      return ending ?? .failed(error)
    }
  }

  private func observe(_ event: STTEvent) {
    switch event {
    case .partial(let partial):
      guard isSpeech(partial) else { return }
      heardSpeech = true
      lastSpeechAt = clock.now
      if state == .paused { transition(to: .listening) }
      reschedule()
    case .done:
      // Text reaches the target app only on an explicit trigger or the hard cap, so a `done`
      // arriving without one is the socket ending the transcript on its own. The accumulated
      // text surfaces as a failure rather than as an insertion nobody asked for.
      ending = state == .finalizing ? .finalised : .closed
    case .error(let serverError):
      ending = .failed(STTError.server(serverError))
    case .created:
      break
    }
  }

  /// Whether a partial says anyone is speaking.
  ///
  /// The endpoint emits `transcript.partial` at about 1 Hz with empty text throughout a silence
  /// and emits nothing at all for two to three seconds while it decides where an utterance
  /// ended, so the arrival of a partial carries no signal. Text does, and so does the end of an
  /// utterance.
  private func isSpeech(_ partial: STTEvent.Partial) -> Bool {
    partial.speechFinal
      || !partial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Sets the one pending wake-up: the sooner of the silence timeout and the hard cap while
  /// listening, and the hard cap alone once paused, since silence has already been answered.
  private func reschedule() {
    let hardCap = startedAt + settings.hardCap
    let deadline: TimeInterval
    switch state {
    case .listening: deadline = min(lastSpeechAt + settings.silenceTimeout, hardCap)
    case .paused: deadline = hardCap
    case .idle, .finalizing, .inserting, .cancelled:
      clock.cancel()
      return
    }
    clock.schedule(at: deadline) { [weak self] in await self?.deadlineReached() }
  }

  private func deadlineReached() async {
    guard isActive else { return }
    if clock.now >= startedAt + settings.hardCap {
      await beginFinalizing()
    } else if heardSpeech {
      transition(to: .paused)
      reschedule()
    } else {
      // Nothing said at all: close silently rather than leave an empty overlay sitting open.
      cancel()
    }
  }

  /// The only route to `finalizing`: an explicit trigger or the hard cap.
  private func beginFinalizing() async {
    transition(to: .finalizing)
    clock.cancel()
    do {
      try await client.finish()
    } catch {
      // The socket is gone, so `transcript.done` will never arrive. End the loop and keep
      // whatever was finalised.
      ending = .failed(error)
      transport.close()
    }
  }

  private func conclude(_ ending: Ending) async -> Outcome {
    // Recorded before the await below, so a trigger or cancel arriving while the client is
    // still finishing is rejected rather than transitioning a session that has already ended.
    self.ending = ending
    clock.cancel()
    relay.finish()
    // Closed before awaiting the client, so a client suspended in a send on a socket that has
    // already failed is unblocked rather than waited on.
    transport.close()
    let text = await finalText()

    let outcome: Outcome
    switch ending {
    case .cancelled:
      outcome = .nothing
    case .finalised:
      outcome = text.isEmpty ? .nothing : .insert(text)
      settle(text: text)
    case .closed:
      outcome = .failed(text: text, error: .socket("the transcript ended before the session did"))
      settle(text: text)
    case .failed(let error):
      outcome = .failed(text: text, error: SessionError(error))
      settle(text: text)
    }
    transitions.finish()
    return outcome
  }

  /// The transcript the client assembled, or whatever it had finalised before it threw.
  private func finalText() async -> String {
    guard let clientTask else { return "" }
    if let text = try? await clientTask.value { return text }
    return await client.text
  }

  /// Ends a session that was not cancelled. `inserting` is entered only when there is text, so
  /// an empty transcript produces no insertion.
  private func settle(text: String) {
    if !text.isEmpty { transition(to: .inserting) }
    transition(to: .idle)
  }

  private func transition(to next: State) {
    guard state != next else { return }
    state = next
    transitions.yield(next)
  }
}

/// The transport `STTClient` sees: messages the session has already read, and sends passed
/// straight through to the real socket.
private final class RelayTransport: WebSocketTransport {
  private let base: any WebSocketTransport
  private let stream: AsyncThrowingStream<String, any Error>
  private let continuation: AsyncThrowingStream<String, any Error>.Continuation

  init(base: any WebSocketTransport) {
    self.base = base
    (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
  }

  func deliver(_ message: String) {
    continuation.yield(message)
  }

  func finish() {
    continuation.finish()
  }

  func send(binary: Data) async throws {
    try await base.send(binary: binary)
  }

  func send(text: String) async throws {
    try await base.send(text: text)
  }

  func messages() -> AsyncThrowingStream<String, any Error> {
    stream
  }

  /// The session owns the socket's lifetime, so a client teardown is not one.
  func close() {}
}
