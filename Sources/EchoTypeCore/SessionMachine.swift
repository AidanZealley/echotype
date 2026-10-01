import Foundation

/// Why a session ended badly, in the form the overlay has to render.
public enum SessionError: Error, Equatable, Sendable {
  /// The provider reported a failure.
  case provider(ProviderError)
  /// The connection failed or closed before the transcript was finalised.
  case socket(String)

  public init(_ error: any Error) {
    if let error = error as? ProviderError {
      self = .provider(error)
    } else {
      self = .socket(String(describing: error))
    }
  }
}

/// One dictation session, from the hotkey that starts it to the text a macOS layer inserts.
///
/// The machine owns a `LiveTranscriber` for the life of the session, reads its events, and
/// decides when to pause, cancel, finalise or give up. Nothing is ever committed by a timer
/// except the hard cap: quiet only changes what the overlay renders. It gives the transcriber
/// the guarantees `LiveTranscriber` documents: audio is held until `.ready`, and every send and
/// the one `finish()` are ordered.
///
/// Usage is `run()` in its own task and `send(audio:)` while it lasts. The owner ends it with
/// `beginFinishing()`, then `sendClosing()` once its own audio has drained, or with `cancel()`
/// or `fail(_:)`. The machine never calls back into its owner: when the hard cap fires it begins
/// finishing itself, and the `finalizing` snapshot is the owner's cue to drain and close.
/// `run()` returns the session's one outcome, and `snapshots` carries what an overlay renders.
///
/// The machine holds the session's one transcript: the text it inserts and the text it shows
/// come from the same events. Anything else that wants live text reads `snapshots` rather than
/// the transcriber, whose events have exactly one reader.
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
    /// The session's transcript ended without the user asking for it: the transcriber failed,
    /// ended, or finished on its own. Whatever was finalised before that survives, because
    /// losing a minute of speech to a dropped connection is worse than inserting a visibly
    /// truncated transcript.
    case failed(text: String, error: SessionError)
  }

  /// What an overlay renders at one moment of the session.
  public struct Snapshot: Equatable, Sendable {
    public var state: State
    public var transcript: Transcript

    public init(state: State, transcript: Transcript) {
      self.state = state
      self.transcript = transcript
    }
  }

  /// How the message loop ended, which is what decides the outcome.
  private enum Ending {
    case finalised
    case cancelled
    /// The transcript ended before closing began: the events ended, or `.finished` arrived
    /// before `finish()` was called.
    case closed
    /// The finishing deadline passed before `.finished` came back.
    case timedOut
    case failed(any Error)
  }

  private let transcriber: any LiveTranscriber
  private let settings: Settings
  private let clock: any SessionClock

  /// A snapshot for every state the session enters and every change to its text, in order.
  /// Finishes when the session does, and the last snapshot still carries the last text.
  public nonisolated let snapshots: AsyncStream<Snapshot>
  private nonisolated let publisher: AsyncStream<Snapshot>.Continuation
  private var published: Snapshot?

  private var state: State = .idle
  private var transcript = Transcript()

  private var startedAt: TimeInterval = 0
  private var lastSpeechAt: TimeInterval = 0
  /// Recorded by `beginFinishing()`. It covers drain, `finish()` and `.finished`.
  private var finishingDeadline: TimeInterval = 0
  public static let readinessTimeout: TimeInterval = 5
  private var ready = false
  /// Finishes when `.ready` arrives or the session ends, releasing a `sendClosing()` that waits
  /// to send held audio first.
  private let readiness: AsyncStream<Void>
  private let readinessPublisher: AsyncStream<Void>.Continuation
  private var heardSpeech = false
  /// Set once `sendClosing()` begins. The transcriber answers `finish()` with `.finished`, so a
  /// `.finished` after this point completes the session whatever `finish()` later reports.
  private var closingStarted = false
  private var ending: Ending?

  /// Five seconds of 16 kHz mono Int16 audio, held while the transcriber becomes ready.
  public static let heldAudioLimit = 160_000
  private var heldAudio: [Data] = []
  private var heldBytes = 0
  /// The most recently enqueued send. Each new send waits for it before reaching the
  /// transcriber, which keeps audio in the order it was handed over while an earlier send is
  /// still suspended, and keeps `finish()` behind the last chunk.
  private var lastSend: Task<Void, any Error>?

  public init(transcriber: any LiveTranscriber, settings: Settings, clock: any SessionClock) {
    self.transcriber = transcriber
    self.settings = settings
    self.clock = clock
    (snapshots, publisher) = AsyncStream.makeStream(of: Snapshot.self)
    (readiness, readinessPublisher) = AsyncStream.makeStream(of: Void.self)
  }

  /// Reads the transcriber's events and applies transcript and lifecycle decisions.
  public func run() async -> Outcome {
    // Escape can reach this actor before its owner's run task does. The session still needs
    // normal teardown and a finished snapshot stream.
    if ending == nil {
      begin()
      await readUntilEnd()
    }
    return await conclude(ending ?? .closed)
  }

  /// Hands one chunk of audio to the transcriber, or holds it until `.ready`. Audio streams
  /// while paused too, since pausing is a display state. Returns once the chunk is sent or held,
  /// which gives capture back pressure.
  public func send(audio: Data) async throws {
    guard ending == nil, !closingStarted, state != .idle, state != .cancelled else { return }
    do {
      if ready {
        try await inOrder { try await $0.send(audio: audio) }
      } else {
        try hold(audio)
      }
    } catch {
      fail(error)
      throw error
    }
  }

  /// Moves to `finalizing` and arms the finishing deadline. Idempotent across stop, reply
  /// request and hard cap. The owner then drains its audio and calls `sendClosing()`.
  public func beginFinishing() {
    guard isActive else { return }
    finishingDeadline = clock.now + settings.finalizeTimeout
    transition(to: .finalizing)
  }

  /// Calls `finish()` behind the audio already handed over, waiting for readiness first if
  /// audio is still held. A failure before `.finished` fails the session.
  public func sendClosing() async {
    guard ending == nil, state == .finalizing, !closingStarted else { return }
    closingStarted = true
    if !ready && !heldAudio.isEmpty {
      for await _ in readiness {}
    }
    guard ending == nil else { return }
    do { try await inOrder { try await $0.finish() } }
    catch { fail(error) }
  }

  public func fail(_ error: any Error) {
    guard ending == nil else { return }
    decide(.failed(error))
    transcriber.close()
  }

  /// Escape: discard everything.
  public func cancel() {
    guard ending == nil else { return }
    decide(.cancelled)
    transition(to: .cancelled)
    transcriber.close()
  }

  /// Whether the session still accepts input: it is streaming, and nothing has ended it yet.
  ///
  /// `ending` is set the moment the outcome is decided, so a late `beginFinishing()` or
  /// `cancel()` cannot land behind a session that is already on its way out.
  private var isActive: Bool {
    ending == nil && (state == .listening || state == .paused)
  }

  /// Records how the session ends. The first ending decided wins: closing the transcriber does
  /// not discard events already received, so a `.finished` or failure read after Escape must not
  /// turn the cancel into an insertion.
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
      for try await event in transcriber.events {
        guard ending == nil else { return }
        await observe(event)
        guard ending == nil else { return }
      }
      decide(.closed)
    } catch {
      decide(.failed(error))
    }
  }

  private func observe(_ event: TranscriptionEvent) async {
    switch event {
    case .ready:
      ready = true
      readinessPublisher.finish()
      reschedule()
      await sendHeldAudio()
    case .transcript(let next):
      // Text is kept in every state, including what finishing resolves the tail into.
      transcript = next
      publish()
    case .speech:
      // Speech only moves the silence and pause bookkeeping while the session is streaming.
      // Once finalising, speech in the tail that finishing resolves must leave the finishing
      // deadline alone.
      guard isActive else { return }
      heardSpeech = true
      lastSpeechAt = clock.now
      if state == .paused { transition(to: .listening) } else { reschedule() }
    case .finished:
      // Text reaches the target app only once closing has begun, after an explicit stop or the
      // hard cap, so `.finished` before that is the transcriber ending the transcript on its
      // own. The accumulated text surfaces as a failure rather than as an insertion nobody
      // asked for.
      decide(closingStarted ? .finalised : .closed)
    }
  }

  private func hold(_ audio: Data) throws {
    guard heldBytes + audio.count <= Self.heldAudioLimit else {
      throw SessionError.socket("Audio backlog exceeded while connecting")
    }
    heldBytes += audio.count
    heldAudio.append(audio)
  }

  /// Sends the audio held before `.ready`, ahead of any audio handed over after it.
  private func sendHeldAudio() async {
    let held = heldAudio
    heldAudio.removeAll()
    heldBytes = 0
    guard !held.isEmpty else { return }
    do {
      try await inOrder { transcriber in
        for chunk in held { try await transcriber.send(audio: chunk) }
      }
    } catch {
      fail(error)
    }
  }

  /// Puts one call behind every send already handed over. Enqueuing happens before the first
  /// suspension, so a caller feeding audio from one task cannot overtake a send suspended in the
  /// transcriber, and `finish()` cannot overtake chunks still on their way out. A failed send
  /// fails everything behind it.
  private func inOrder(
    _ work: @Sendable @escaping (any LiveTranscriber) async throws -> Void
  ) async throws {
    let previous = lastSend
    let transcriber = self.transcriber
    let send = Task {
      try await previous?.value
      try Task.checkCancellation()
      try await work(transcriber)
    }
    lastSend = send
    try await send.value
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
      // Drain, `finish()` or `.finished` outlasted the deadline. Ending the loop keeps the
      // committed text, on the same reasoning as a dropped connection: a visibly truncated
      // transcript beats losing the speech.
      decide(.timedOut)
      transcriber.close()
    case .idle, .cancelled:
      break
    }
  }

  private func conclude(_ ending: Ending) async -> Outcome {
    // Recorded so that a late `beginFinishing()` or `cancel()` is rejected rather than
    // transitioning a session that has already ended.
    decide(ending)
    clock.cancel()
    await closeTranscriber()
    let text = transcript.committed

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

  /// Closes the transcriber, releases a waiting `sendClosing()` and joins every send and the
  /// transcriber's own work.
  private func closeTranscriber() async {
    transcriber.close()
    readinessPublisher.finish()
    lastSend?.cancel()
    _ = await lastSend?.result
    await transcriber.waitForClose()
    heldAudio.removeAll()
    heldBytes = 0
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
    let snapshot = Snapshot(state: state, transcript: transcript)
    guard snapshot != published else { return }
    published = snapshot
    publisher.yield(snapshot)
  }
}
