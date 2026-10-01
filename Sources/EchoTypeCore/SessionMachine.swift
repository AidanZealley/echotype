import Foundation

/// Why a session ended badly, in the form the overlay has to render.
public enum SessionError: Error, Equatable, Sendable {
  /// The endpoint reported a failure, or the client could not read the stream.
  case stt(STTError)
  /// The socket failed or closed before the transcript was finalised.
  case socket(String)

  public init(_ error: any Error) {
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
/// Usage is `run()` in its own task and `send(audio:)` while it lasts. The owner ends it with
/// `beginFinishing()`, then `sendClosing()` once its own audio has drained, or with `cancel()`
/// or `fail(_:)`. The machine never calls back into its owner: when the hard cap fires it begins
/// finishing itself, and the `finalizing` snapshot is the owner's cue to drain and close.
/// `run()` returns the session's one outcome, and `snapshots` carries what an overlay renders.
///
/// The machine holds the session's one transcript: the text it inserts and the text it shows
/// come from the same assembler. Anything else that wants live text reads `snapshots` rather
/// than the socket: a WebSocket message is delivered to exactly one reader, so a second read
/// would take frames away from this one.
public actor SessionMachine {
  /// Session states. `listening` and `paused` differ only in what is rendered;
  /// audio streams in both.
  public enum State: Equatable, Sendable {
    case idle
    case listening
    case paused
    case finalizing
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
    /// Text closed by `speech_final` or `transcript.done`; it only grows at the end.
    public var committed: String
    /// Settled runs in the current utterance, which `speech_final` can replace.
    public var utterance: String
    /// The unsettled run, rendered dimmed.
    public var provisional: String

    public init(state: State, committed: String, utterance: String, provisional: String) {
      self.state = state
      self.committed = committed
      self.utterance = utterance
      self.provisional = provisional
    }
  }

  /// How the message loop ended, which is what decides the outcome.
  private enum Ending {
    case finalised
    case cancelled
    /// The transcript ended without completing the protocol: the socket closed, or sent
    /// `transcript.done` before closing began.
    case closed
    /// The finishing deadline passed before `transcript.done` came back.
    case timedOut
    case failed(any Error)
  }

  private let transport: any WebSocketTransport
  private let settings: Settings
  private let clock: any SessionClock
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
  /// Recorded by `beginFinishing()`. It covers drain, the closing sends and `transcript.done`.
  private var finishingDeadline: TimeInterval = 0
  public static let readinessTimeout: TimeInterval = 5
  private var ready = false
  private var heardSpeech = false
  /// Set once `sendClosing()` begins. The endpoint answers `audio.done` with `transcript.done`,
  /// so a `done` after this point completes the protocol whatever the send later reports.
  private var closingStarted = false
  private var ending: Ending?

  public init(transport: any WebSocketTransport, settings: Settings, clock: any SessionClock) {
    self.transport = transport
    self.settings = settings
    self.clock = clock
    self.client = STTClient(transport: transport)
    (snapshots, publisher) = AsyncStream.makeStream(of: Snapshot.self)
  }

  /// Runs the client's single typed receive loop and applies transcript/lifecycle decisions.
  public func run() async -> Outcome {
    // Escape can reach this actor before its owner's run task does. The session still needs
    // normal teardown and a finished snapshot stream.
    if ending == nil {
      begin()
      await readUntilEnd()
    }
    return await conclude(ending ?? .closed)
  }

  /// Hands one chunk of audio to the endpoint. Audio streams while paused too, since pausing is
  /// a display state.
  public func send(audio: Data) async throws {
    guard ending == nil, state != .idle, state != .cancelled else { return }
    do { try await client.send(audio: audio) }
    catch { fail(error); throw error }
  }

  /// Moves to `finalizing` and arms the finishing deadline. Idempotent across stop, reply
  /// request and hard cap. The owner then drains its audio and calls `sendClosing()`.
  public func beginFinishing() {
    guard isActive else { return }
    finishingDeadline = clock.now + settings.finalizeTimeout
    transition(to: .finalizing)
  }

  /// Sends `finalize` and `audio.done` behind the audio already handed over, waiting for
  /// readiness first if audio is still held. A failure before `transcript.done` fails the
  /// session.
  public func sendClosing() async {
    guard ending == nil, state == .finalizing, !closingStarted else { return }
    closingStarted = true
    do { try await client.finish() }
    catch { fail(error) }
  }

  public func fail(_ error: any Error) {
    guard ending == nil else { return }
    decide(.failed(error))
    transport.close()
  }

  /// Escape: discard everything.
  public func cancel() {
    guard ending == nil else { return }
    decide(.cancelled)
    transition(to: .cancelled)
    transport.close()
  }

  /// Whether the session still accepts input: it is streaming, and nothing has ended it yet.
  ///
  /// `ending` is set the moment the outcome is decided, so a late `beginFinishing()` or
  /// `cancel()` cannot land behind a session that is already on its way out.
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
  }

  private func readUntilEnd() async {
    do {
      try await client.run { [weak self] event in
        guard let self else { return false }
        return await self.handle(event)
      }
      decide(.closed)
    } catch {
      decide(.failed(error))
    }
  }

  private func handle(_ event: STTEvent) -> Bool {
    guard ending == nil else { return false }
    observe(event)
    return ending == nil
  }

  private func observe(_ event: STTEvent) {
    // Text is kept in every state, including the partial `finalize` resolves into.
    transcript.apply(event)
    defer { publish() }
    switch event {
    case .partial(let partial):
      // Speech only moves the silence and pause bookkeeping while the session is streaming.
      // Once finalising, the trailing partial `finalize` resolves into must leave the
      // finishing deadline alone.
      guard isActive, isSpeech(partial) else { return }
      heardSpeech = true
      lastSpeechAt = clock.now
      if state == .paused { transition(to: .listening) } else { reschedule() }
    case .done:
      // Text reaches the target app only once closing has begun, after an explicit stop or the
      // hard cap, so a `done` arriving before that is the socket ending the transcript on its
      // own. The accumulated text surfaces as a failure rather than as an insertion nobody
      // asked for.
      decide(closingStarted ? .finalised : .closed)
    case .error:
      break // STTClient throws server errors before invoking the observer.
    case .created:
      ready = true
      reschedule()
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

  private var hardCap: TimeInterval { startedAt + settings.hardCap }

  /// Sets the session's one pending wake-up from its state. This is the only place a deadline
  /// is scheduled; every state change and every input to a deadline calls it.
  private func reschedule() {
    let deadline: TimeInterval
    switch state {
    case .listening where !ready: deadline = startedAt + Self.readinessTimeout
    // Paused has already answered silence, so only the hard cap remains.
    case .listening: deadline = min(lastSpeechAt + settings.silenceTimeout, hardCap)
    case .paused: deadline = hardCap
    case .finalizing: deadline = finishingDeadline
    case .idle, .cancelled:
      clock.cancel()
      return
    }
    clock.schedule(at: deadline) { [weak self] in await self?.deadlineReached() }
  }

  private func deadlineReached() {
    guard ending == nil else { return }
    switch state {
    case .listening where !ready:
      fail(SessionError.socket("The transcription connection did not become ready"))
    case .listening, .paused:
      if clock.now >= hardCap {
        // The owner sees `finalizing` and drains and closes as it would for a stop.
        beginFinishing()
      } else if heardSpeech {
        transition(to: .paused)
      } else {
        // Nothing said at all: close silently rather than leave an empty overlay sitting open.
        cancel()
      }
    case .finalizing:
      // Drain, closing or `transcript.done` outlasted the deadline. Ending the loop keeps the
      // committed segments, on the same reasoning as a dropped socket: a visibly truncated
      // transcript beats losing the speech.
      decide(.timedOut)
      transport.close()
    case .idle, .cancelled:
      break
    }
  }

  private func conclude(_ ending: Ending) async -> Outcome {
    // Recorded so that a late `beginFinishing()` or `cancel()` is rejected rather than
    // transitioning a session that has already ended.
    decide(ending)
    clock.cancel()
    await client.close()
    let text = transcript.text

    let outcome: Outcome
    switch ending {
    case .cancelled:
      outcome = .nothing
    case .finalised:
      outcome = text.isEmpty ? .nothing : .insert(text)
      transition(to: .idle)
    case .closed:
      outcome = .failed(text: text, error: .socket("the transcript ended before the session did"))
      transition(to: .idle)
    case .timedOut:
      outcome = .failed(
        text: text, error: .socket("the endpoint never answered the finalize request"))
      transition(to: .idle)
    case .failed(let error):
      outcome = .failed(text: text, error: SessionError(error))
      transition(to: .idle)
    }
    publisher.finish()
    return outcome
  }

  /// Every state change publishes and recomputes the pending deadline.
  private func transition(to next: State) {
    guard state != next else { return }
    state = next
    publish()
    reschedule()
  }

  /// Publishes the current snapshot unless it is the one already published.
  private func publish() {
    let snapshot = Snapshot(
      state: state, committed: transcript.text, utterance: transcript.utterance,
      provisional: transcript.provisional)
    guard snapshot != published else { return }
    published = snapshot
    publisher.yield(snapshot)
  }
}
