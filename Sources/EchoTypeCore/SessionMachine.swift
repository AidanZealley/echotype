import Foundation

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
/// `cancel()` to end it. `run()` returns the session's one outcome, and `snapshots` carries
/// what an overlay renders.
///
/// The machine holds the session's one transcript: the text it inserts and the text it shows
/// come from the same assembler. Anything else that wants live text reads `snapshots` rather
/// than the socket: a WebSocket message is delivered to exactly one reader, so a second read
/// would take frames away from this one.
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

  /// What an overlay renders at one moment of the session.
  public struct Snapshot: Equatable, Sendable {
    public var state: State
    /// Committed text plus the settled runs of the current utterance, rendered solid. The
    /// utterance's `speech_final` text replaces its runs wholesale, so this is not guaranteed
    /// to only grow at its end.
    public var settled: String
    /// The tail the model may still rewrite, rendered dimmed after `settled`.
    public var provisional: String

    public init(state: State, settled: String, provisional: String) {
      self.state = state
      self.settled = settled
      self.provisional = provisional
    }
  }

  /// How the message loop ended, which is what decides the outcome.
  private enum Ending {
    case finalised
    case cancelled
    /// The transcript ended without a trigger: the socket closed, or sent `transcript.done`
    /// unasked.
    case closed
    /// `finalize` and `audio.done` went out and `transcript.done` never came back.
    case timedOut
    case failed(any Error)
  }

  private let transport: any WebSocketTransport
  private let settings: Settings
  private let clock: any SessionClock
  private let relay: RelayTransport
  private let client: STTClient

  /// A snapshot for every state the session enters and every change to its text, in order.
  /// Finishes when the session does, and the last snapshot still carries the last text.
  public nonisolated let snapshots: AsyncStream<Snapshot>
  private nonisolated let publisher: AsyncStream<Snapshot>.Continuation
  private var published: Snapshot?

  private var state: State = .idle
  private var transcript = TranscriptAssembler()

  private var startedAt: TimeInterval = 0
  private var lastSpeechAt: TimeInterval = 0
  private var heardSpeech = false
  private var ending: Ending?

  public init(transport: any WebSocketTransport, settings: Settings, clock: any SessionClock) {
    self.transport = transport
    self.settings = settings
    self.clock = clock
    let relay = RelayTransport(base: transport)
    self.relay = relay
    self.client = STTClient(transport: relay)
    (snapshots, publisher) = AsyncStream.makeStream(of: Snapshot.self)
  }

  /// Runs the session to its one outcome.
  ///
  /// Reads the socket itself and hands every message on to the client, which keeps the protocol
  /// while the machine keeps the transcript and decides when to pause.
  public func run() async -> Outcome {
    guard state == .idle else { return .nothing }
    begin()
    let ending = await readUntilEnd()
    return conclude(ending)
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
    decide(.cancelled)
    transition(to: .cancelled)
    clock.cancel()
    transport.close()
  }

  /// Whether the session still accepts input: it is streaming, and nothing has ended it yet.
  ///
  /// `ending` is set the moment the outcome is decided, so a late `trigger()` or `cancel()`
  /// cannot land behind a session that is already on its way out.
  private var isActive: Bool {
    ending == nil && (state == .listening || state == .paused)
  }

  /// Records how the session ends. The first ending decided wins: closing the socket does not
  /// discard frames already received, so a `transcript.done` or `error` read after Escape must
  /// not turn the cancel into an insertion.
  private func decide(_ ending: Ending) {
    guard self.ending == nil else { return }
    self.ending = ending
  }

  private func begin() {
    startedAt = clock.now
    lastSpeechAt = startedAt
    transition(to: .listening)
    // The client's own failures reach the machine as the frames or socket errors behind them,
    // so its result is not needed.
    Task { [client] in _ = try? await client.run() }
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
    // Text is kept in every state, including the partial `finalize` resolves into.
    transcript.apply(event)
    defer { publish() }
    switch event {
    case .partial(let partial):
      // Speech only moves the silence and pause bookkeeping while the session is streaming.
      // Once finalising, the trailing partial `finalize` resolves into must leave the
      // finalize deadline alone.
      guard isActive, isSpeech(partial) else { return }
      heardSpeech = true
      lastSpeechAt = clock.now
      if state == .paused { transition(to: .listening) }
      reschedule()
    case .done:
      // Text reaches the target app only on an explicit trigger or the hard cap, so a `done`
      // arriving without one is the socket ending the transcript on its own. The accumulated
      // text surfaces as a failure rather than as an insertion nobody asked for.
      decide(state == .finalizing ? .finalised : .closed)
    case .error(let serverError):
      decide(.failed(STTError.server(serverError)))
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
    do {
      try await client.finish()
    } catch {
      // The socket is gone, so `transcript.done` will never arrive. End the loop and keep
      // whatever was finalised. `conclude` cancels the wake-up still pending from `listening`.
      decide(.failed(error))
      transport.close()
      return
    }
    // An endpoint that accepts the closing messages and then says nothing would leave the
    // message loop suspended forever, so the wait is bounded. Scheduling replaces the silence
    // and hard cap wake-up, and `conclude` cancels whatever is still pending. A session that
    // ended while the closing messages were sending has already concluded, so nothing is armed.
    guard ending == nil else { return }
    clock.schedule(at: clock.now + settings.finalizeTimeout) { [weak self] in
      await self?.finalizingDeadlineReached()
    }
  }

  /// The endpoint never answered `finalize`. Ending the loop keeps the committed segments, on
  /// the same reasoning as a dropped socket: a visibly truncated transcript beats losing the
  /// speech.
  private func finalizingDeadlineReached() {
    guard ending == nil, state == .finalizing else { return }
    decide(.timedOut)
    transport.close()
  }

  private func conclude(_ ending: Ending) -> Outcome {
    // Recorded so that a late trigger or cancel is rejected rather than transitioning a session
    // that has already ended.
    decide(ending)
    clock.cancel()
    relay.finish()
    transport.close()
    let text = transcript.text

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
    case .timedOut:
      outcome = .failed(
        text: text, error: .socket("the endpoint never answered the finalize request"))
      settle(text: text)
    case .failed(let error):
      outcome = .failed(text: text, error: SessionError(error))
      settle(text: text)
    }
    publisher.finish()
    return outcome
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
    publish()
  }

  /// Publishes the current snapshot unless it is the one already published.
  private func publish() {
    let snapshot = Snapshot(
      state: state, settled: transcript.settled, provisional: transcript.provisional)
    guard snapshot != published else { return }
    published = snapshot
    publisher.yield(snapshot)
  }
}
