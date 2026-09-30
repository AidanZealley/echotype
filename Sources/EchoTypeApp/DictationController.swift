import AppKit
import EchoTypeCore
import Foundation
import Observation

/// Owns the session lifecycle: the hotkey opens and commits a session, Escape discards it,
/// and the outcome is inserted at the caret.
///
/// With cleanup on, committed text revises in the pill and the final revision is inserted.
/// A failed revision leaves the streamed words available.
///
/// The overlay pill shows the session from the press to its end, errors included. `state` is
/// what the menu bar renders.
///
/// The settings window's Test button runs the same session through `test()`, which shows no
/// pill and inserts nothing. The hotkey, Escape and the pill ignore it.
///
/// The read-aloud hotkey starts a `Reader`, which reads the selection aloud under a `Reading`
/// pill. Space pauses or resumes it. The read-aloud hotkey or Escape stops it, and the dictation hotkey stops it and
/// starts a dictation. The read-aloud hotkey does nothing while a dictation or a test is starting
/// or running, and a test cannot start while reading.
///
/// `speak(_:)` reads text handed over by the `--mcp` process the same way, replacing a reading
/// in progress and dropped while a dictation or test is starting or running.
///
/// Each dictation that reaches `running` is recorded as a `DictationTrace` and published as
/// `lastTrace` when it ends, for the Last Dictation window. Tests and readings are not recorded.
///
/// The hotkey and Escape arrive inside the event tap's callback, which must only decide whether
/// to consume the event. So those handlers change `phase`, which is what that decision reads,
/// and leave every other piece of work to a task.
@MainActor @Observable final class DictationController {
  private(set) var state: SessionMachine.State = .idle
  private(set) var hasAPIKey: Bool?
  private(set) var lastError: String?
  private var keyStatusGeneration = 0
  /// The last dictation that reached `running`, whatever its outcome. Nil until one ends. Kept in
  /// memory only.
  private(set) var lastTrace: DictationTrace?
  /// The dictation being recorded, from `running` until it is published.
  @ObservationIgnored private var trace: DictationTrace?

  /// What a test heard, for the settings window to show.
  enum TestOutcome {
    case heard(String)
    case heardNothing
    /// Worded by `describe(_:)`, as the pill would show it.
    case failed(String)
  }

  private enum Phase {
    case idle
    /// Opening the microphone, reading the key and opening the socket, which takes a noticeable
    /// moment every session. Hotkey presses are ignored; Escape abandons the start.
    case starting
    /// Escape was pressed while starting. The start stops at its next step.
    case abandoned
    case running(SessionMachine)
    /// A test from the settings window, from its start to its outcome.
    case testing
    /// Reading the selection, or text handed over by another process, aloud, from the start until
    /// the reader ends.
    case reading(Reader)
  }

  /// No dictation, test or reading is under way, so a test may start.
  var isIdle: Bool {
    if case .idle = phase { true } else { false }
  }

  /// The monitor reads the hotkey from it live; each session reads a copy of the rest.
  private let store: SettingsStore
  private let audio = AudioCapture()
  private let clipboard = Clipboard()
  private var destination: Destination?
  private var insertionCancelled = false
  private var insertionBegan = false
  @ObservationIgnored private let panel = OverlayPanel()
  private var phase = Phase.idle
  private var monitor: HotkeyMonitor?
  @ObservationIgnored private var speakObserver: (any NSObjectProtocol)?

  /// The session's pill and the screen it stays on, from the press until the session ends.
  private var pill: Pill?
  private var screen: NSScreen?
  private var currentSnapshot: SessionMachine.Snapshot?
  /// Fades an error pill after it has been read.
  private var errorFade: Task<Void, Never>?

  init(store: SettingsStore) {
    self.store = store
    audio.onLevel = { [weak self] level in self?.levelChanged(level) }
    audio.onDevice = { [weak self] device in self?.updatePill { $0.inputDevice = device } }
    let monitor = HotkeyMonitor(
      store: store,
      onHotkey: { [weak self] hotkey in
        switch hotkey {
        case .dictation: self?.hotkeyPressed()
        case .readAloud: self?.readAloudPressed()
        }
      },
      onEscape: { [weak self] in self?.escapePressed() ?? false },
      onSpace: { [weak self] repeated in self?.spacePressed(repeated: repeated) ?? false }
    )
    monitor.start()
    self.monitor = monitor
    // Posted by the `--mcp` process, so the text arrives from outside the app. The poster
    // uses `deliverImmediately`, which gets past the suspension an inactive app is under.
    speakObserver = DistributedNotificationCenter.default().addObserver(
      forName: SpeakNotification.name, object: nil, queue: .main
    ) { [weak self] notification in
      guard let text = notification.userInfo?[SpeakNotification.textKey] as? String else { return }
      MainActor.assumeIsolated { self?.speak(text) }
    }
    Task { await refreshAPIKeyStatus() }
  }

  func refreshAPIKeyStatus(clearError: Bool = false) async {
    keyStatusGeneration += 1
    let generation = keyStatusGeneration
    let available = await Task.detached { Keychain.apiKey() != nil }.value
    guard generation == keyStatusGeneration else { return }
    hasAPIKey = available
    if clearError { lastError = nil }
  }

  // MARK: Input

  /// Called inside the event tap.
  private func hotkeyPressed() {
    switch phase {
    case .idle:
      phase = .starting
      Task { await dictate() }
    case .starting, .abandoned, .testing:
      break
    case .running:
      Task { await commit() }
    case .reading(let reader):
      // The reading ends on its own once stopped, and leaves the pill to the dictation.
      phase = .starting
      Task {
        reader.stop()
        await dictate()
      }
    }
  }

  /// Called inside the event tap.
  private func readAloudPressed() {
    switch phase {
    case .idle:
      startReading(.selection)
    case .reading(let reader):
      Task { reader.stop() }
    case .starting, .abandoned, .running, .testing:
      break
    }
  }

  /// Reads `text` given by another process, under the same rules as the read-aloud hotkey,
  /// except that a reading in progress is replaced. Dropped while a dictation or test is
  /// starting or running, so the agent never talks over the user.
  private func speak(_ text: String) {
    switch phase {
    case .idle:
      startReading(.text(text))
    case .reading(let reader):
      // The old reading's task sees it no longer owns the phase and leaves the pill alone.
      reader.stop()
      startReading(.text(text))
    case .starting, .abandoned, .running, .testing:
      break
    }
  }

  private func startReading(_ source: Reader.Source) {
    lastError = nil
    errorFade?.cancel()
    screen = NSScreen.forFocusedWindow()
    // The pill shows at once, for a selection and for given text alike; an empty selection
    // then turns it into its error.
    pill = Pill(phase: .reading, isReading: true, startedAt: .now)
    let reader = Reader(
      source,
      settings: store.settings,
      clipboard: clipboard,
      onLevel: { [weak self] level in self?.updatePill { $0.level = level } })
    phase = .reading(reader)
    Task { await read(reader) }
  }

  /// Called inside the event tap. Escape belongs to the focused app unless a session is
  /// starting or running, or a reading is under way.
  private func escapePressed() -> Bool {
    switch phase {
    case .idle, .testing:
      return false
    case .reading(let reader):
      Task { reader.stop() }
      return true
    case .starting:
      phase = .abandoned
      Task { end() }
      return true
    case .abandoned:
      return true
    case .running(let session):
      guard !insertionBegan else { return false }
      insertionCancelled = true
      Task { await session.cancel() }
      return true
    }
  }

  /// Space belongs to the focused app except during a reading.
  private func spacePressed(repeated: Bool) -> Bool {
    guard case .reading(let reader) = phase else { return false }
    if !repeated { Task { toggleReadingPause(reader) } }
    return true
  }

  private func toggleReadingPause(_ reader: Reader) {
    guard isReading(reader) else { return }
    let paused = reader.togglePause()
    updatePill {
      let now = Date.now
      if paused {
        $0.pausedAt = now
      } else if let pausedAt = $0.pausedAt {
        $0.pausedDuration += now.timeIntervalSince(pausedAt)
        $0.pausedAt = nil
      }
      $0.phase = paused ? .readingPaused : .reading
      $0.level = 0
    }
  }

  /// Commits by ending capture rather than triggering the session here. The pump sends what is
  /// still queued and the partial last chunk `stop()` flushes, then triggers, so the last word
  /// reaches xAI before `audio.done`. A second commit does nothing.
  private func commit() async {
    if case .running(let session) = phase { await session.enterFinishing() }
    audio.stop()
  }

  // MARK: Session

  /// One session, from the first press to the insertion.
  private func dictate() async {
    defer { phase = .idle }
    // Read once, here, so a change in Settings never reaches a session already running.
    let settings = store.settings
    destination = nil
    insertionCancelled = false
    insertionBegan = false
    showStarting()
    switch await start(settings) {
    case .abandoned:
      end()
    case .failed(let error):
      end(showing: error)
    case .started(let session, let chunks, let apiKey):
      phase = .running(session)
      trace = DictationTrace(startedAt: .now, cleanUp: settings.cleanUp)
      let reviser = settings.cleanUp ? Reviser(
        request: { try await RevisionRequest.revise($0, apiKey: apiKey, final: false) },
        finalRequest: { try await RevisionRequest.revise($0, apiKey: apiKey, final: true) }) : nil
      let (live, audioFailure) = await run(
        session, streaming: chunks, reviser: reviser,
        endsOnReplyRequest: settings.sendReplyRequests)
      let outcome = await revisedOutcome(live, reviser: reviser)
      // Decided on the text that is inserted, so a send always has the request in it.
      // Only a dictation's `.insert` outcome can send.
      var sends = false
      if settings.sendReplyRequests, audioFailure == nil, case .insert(let text) = outcome {
        sends = ReplyRequest.matches(text)
      }
      let insertion = await finish(outcome, audioFailure: audioFailure, sends: sends)
      await publishTrace(outcome, audioFailure: audioFailure, reviser: reviser, insertion: insertion)
    }
  }

  /// Publishes available final text and the clipboard transaction attempts separately.
  private func publishTrace(
    _ outcome: SessionMachine.Outcome, audioFailure: (any Error)?, reviser: Reviser?,
    insertion: Clipboard.InsertionResult
  ) async {
    guard var trace else { return }
    self.trace = nil
    trace.endedAt = .now
    // A cancelled request may still be settling. The trace does not wait for it.
    trace.revisions = await reviser?.attempts ?? []
    switch outcome {
    case .insert(let text):
      trace.finalText = text
      trace.outcome = .completed
    case .failed(let text, let error):
      trace.finalText = text
      trace.outcome = .failed(describe(error))
    case .nothing:
      // `run` recorded `.cancelled` if the session was cancelled.
      break
    }
    if let audioFailure { trace.outcome = .failed(describe(audioFailure)) }
    trace.insertion = insertion.insertion
    trace.sending = insertion.sending
    if insertion.insertion == .cancelled {
      trace.finalText = ""
      trace.outcome = .cancelled
    }
    lastTrace = trace
  }

  private func revisedOutcome(
    _ outcome: SessionMachine.Outcome, reviser: Reviser?
  ) async -> SessionMachine.Outcome {
    guard let reviser else { return outcome }
    switch outcome {
    case .insert(let committed):
      let text = await reviser.finish(committed: committed)
      updatePill { $0.settled = text; $0.provisional = "" }
      return .insert(text)
    case .failed(let committed, let error):
      let text = await reviser.submit(committed: committed)
      await reviser.stop()
      updatePill { $0.settled = text; $0.provisional = "" }
      return .failed(text: text, error: error)
    case .nothing:
      await reviser.stop()
      return .nothing
    }
  }

  /// Runs a session as a dictation would, with the same settings and device, and commits it
  /// after five seconds as the hotkey does. Returns nil without starting if a dictation or
  /// another test is under way.
  func test() async -> TestOutcome? {
    guard isIdle else { return nil }
    phase = .testing
    defer { phase = .idle }
    let session: SessionMachine
    let chunks: AsyncThrowingStream<Data, any Error>
    switch await start(store.settings) {
    case .abandoned:
      // Only Escape abandons, and Escape ignores a test.
      return nil
    case .failed(let error):
      return .failed(error)
    case .started(let started, let stream, _):
      (session, chunks) = (started, stream)
    }

    let commitAfterFive = Task {
      try? await Task.sleep(for: .seconds(5))
      if !Task.isCancelled { await commit() }
    }
    let (outcome, audioFailure) = await run(session, streaming: chunks, reviser: nil, endsOnReplyRequest: false)
    // A session that ended early must not have a later one committed for it.
    commitAfterFive.cancel()
    return switch (outcome, audioFailure) {
    case (_, let error?), (.failed(_, let error as any Error), nil): .failed(describe(error))
    case (.insert(let text), nil): .heard(text)
    case (.nothing, nil): .heardNothing
    }
  }

  private enum Start {
    /// Carries the key read at session start for revision requests.
    case started(SessionMachine, AsyncThrowingStream<Data, any Error>, apiKey: String)
    /// Escape was pressed while starting. The microphone is released and no socket opened.
    case abandoned
    /// Why the session could not start, worded for the user.
    case failed(String)
  }

  /// Opens the microphone, reads the key and prepares the socket, which the session opens when
  /// it runs. The one start sequence for dictation and test alike.
  private func start(_ settings: Settings) async -> Start {
    // The microphone first: before the socket, so a denied grant never opens a billed
    // connection, and before the key, so the Keychain read is not in the first word's path
    // and the first press raises the Microphone prompt even with no key seeded. Chunks buffer
    // in the stream until the session accepts them.
    let chunks: AsyncThrowingStream<Data, any Error>
    do {
      chunks = try await audio.start(deviceUID: settings.inputDeviceID)
    } catch {
      return isAbandoned ? .abandoned : .failed(describe(error))
    }
    guard !isAbandoned else { return abandon() }
    let apiKey = await Task.detached(operation: { Keychain.apiKey() }).value
    guard !isAbandoned else { return abandon() }
    guard let apiKey else {
      audio.stop()
      return .failed(Self.noAPIKey)
    }

    // The socket opens here, on trigger, because an idle open socket bills streaming time.
    let transport = URLSessionWebSocketTransport(
      url: STTConnection.streamingURL(settings: settings), apiKey: apiKey)
    let session = SessionMachine(
      transport: transport, settings: settings, clock: SystemClock(),
      onFinishing: { [weak self] in await self?.captureDestination() })
    return .started(session, chunks, apiKey: apiKey)
  }

  /// Invoked by the session at finishing entry, never by a presentation snapshot.
  private func captureDestination() {
    if case .running = phase, !insertionCancelled { destination = DestinationFocus().capture() }
    audio.stop()
  }

  private var isAbandoned: Bool {
    if case .abandoned = phase { true } else { false }
  }

  /// Escape arrived while starting: release the microphone and open no socket.
  private func abandon() -> Start {
    audio.stop()
    return .abandoned
  }

  /// Runs a session, mirroring streamed and revised text into the pill while feeding audio.
  private func run(
    _ session: SessionMachine, streaming chunks: AsyncThrowingStream<Data, any Error>,
    reviser: Reviser?, endsOnReplyRequest: Bool
  ) async -> (SessionMachine.Outcome, (any Error)?) {
    let outcome = Task { await session.run() }
    var pump: Task<(any Error)?, Never>?
    let revisions = reviser.map { reviser in
      Task {
        for await _ in reviser.updates {
          guard let snapshot = self.currentSnapshot else { continue }
          let text = await reviser.shown
          // The snapshot loop renders its own newer text. A queued revision signal must not
          // overwrite it with text read for an earlier snapshot.
          guard snapshot == self.currentSnapshot else { continue }
          self.show(snapshot, committed: text)
        }
      }
    }
    var committedLength = 0
    for await snapshot in session.snapshots {
      if snapshot.committed.count > committedLength {
        if endsOnReplyRequest, ReplyRequest.matches(snapshot.committed) { await commit() }
        // Committed text only grows at its end, so the suffix is the new segment. This
        // includes the tail `transcript.done` commits.
        trace?.commits.append(.init(
          at: .now,
          text: snapshot.committed.dropFirst(committedLength)
            .trimmingCharacters(in: .whitespaces)))
      }
      trace?.streamed = snapshot.committed
      if snapshot.state == .cancelled { trace?.outcome = .cancelled }
      committedLength = snapshot.committed.count
      currentSnapshot = snapshot
      state = snapshot.state
      let committed = if let reviser {
        await reviser.submit(committed: snapshot.committed)
      } else { snapshot.committed }
      show(snapshot, committed: committed)
      // The first snapshot is `listening`, when `send(audio:)` begins accepting audio.
      if pump == nil { pump = Task { await self.pump(chunks, into: session) } }
    }
    let result = await outcome.value
    audio.stop()
    let audioFailure = await pump?.value
    revisions?.cancel()
    currentSnapshot = nil
    state = .idle
    return (result, audioFailure)
  }

  private func show(_ snapshot: SessionMachine.Snapshot, committed: String) {
    updatePill { pill in
      pill.apply(snapshot, committed: committed)
    }
  }

  /// Feeds each chunk to the session, then triggers it when capture ends.
  private func pump(
    _ chunks: AsyncThrowingStream<Data, any Error>, into session: SessionMachine
  ) async -> (any Error)? {
    var failure: (any Error)?
    do {
      for try await chunk in chunks {
        // The session reports a failed socket itself. Drain capture until it closes.
        try? await session.send(audio: chunk)
      }
    } catch {
      await session.enterFinishing()
      failure = error
    }
    await session.trigger()
    return failure
  }

  private func finish(
    _ outcome: SessionMachine.Outcome, audioFailure: (any Error)?, sends: Bool
  ) async -> Clipboard.InsertionResult {
    var failure = audioFailure
    let text: String
    switch outcome {
    case .insert(let final): text = final
    case .nothing: text = ""
    case .failed(let final, let error):
      text = final
      failure = failure ?? error
    }
    let result = await clipboard.insert(
      text, destination: destination, sends: sends,
      cancelled: { self.insertionCancelled },
      onBegin: {
        self.insertionBegan = true
        self.updatePill { $0.phase = .inserting }
      })
    var message = failure.map(describe)
    if case .skipped = result.insertion {
      message = [message, "Destination changed or unavailable. Copy the text from Last Dictation."].compactMap { $0 }.joined(separator: " ")
    } else if case .skipped = result.sending {
      message = "Sending skipped because the destination changed. Text is in Last Dictation."
    }
    end(showing: message)
    return result
  }

  /// Last Dictation Copy shares the clipboard owner with reading and insertion.
  func copyLastDictation(_ text: String) async { await clipboard.copy(text) }

  // MARK: Reading

  /// One reading, from the press until the audio ends, it is stopped or it fails. The reader
  /// reads the settings once, when it is created at the press, which also sets up its pill.
  private func read(_ reader: Reader) async {
    var failure: (any Error)?
    do { try await reader.finished() } catch { failure = error }
    // A dictation took over, and owns the phase and the pill now.
    guard isReading(reader) else { return }
    phase = .idle
    end(showing: failure.map(describe))
  }

  private func isReading(_ reader: Reader) -> Bool {
    if case .reading(let current) = phase { current === reader } else { false }
  }

  // MARK: Pill

  /// Shows the pill in its starting state on the screen holding the focused window, replacing
  /// an error still showing from the last session.
  private func showStarting() {
    lastError = nil
    errorFade?.cancel()
    screen = NSScreen.forFocusedWindow()
    pill = Pill(phase: .starting, startedAt: .now)
    updatePill { _ in }
  }

  /// A level arrived: audio is flowing, so a starting pill is now listening.
  private func levelChanged(_ level: Double) {
    updatePill { pill in
      pill.level = level
      if pill.phase == .starting { pill.phase = .listening }
    }
  }

  /// Changes the live pill and shows it. Does nothing once the session's pill has ended.
  private func updatePill(_ change: (inout Pill) -> Void) {
    guard var pill, let screen else { return }
    change(&pill)
    self.pill = pill
    panel.show(pill, on: screen)
  }

  /// Ends the session's pill: fades it, or shows `error` in red for three seconds first.
  private func end(showing error: String? = nil) {
    lastError = error
    guard var pill, let screen else { return }
    self.pill = nil
    guard let error else { return panel.hide() }
    pill.phase = .error(error)
    panel.show(pill, on: screen)
    errorFade = Task {
      try? await Task.sleep(for: .seconds(3))
      if !Task.isCancelled { panel.hide() }
    }
  }

  private static let noAPIKey = "Add your xAI API key in EchoType Settings"

  /// Words a dictation or reading failure for the pill.
  private func describe(_ error: any Error) -> String {
    switch error {
    case Reader.Failure.nothingSelected:
      "Nothing selected"
    case Reader.Failure.noAPIKey:
      Self.noAPIKey
    case Reader.Failure.playback(let underlying):
      "Audio output failed: \(underlying.localizedDescription)"
    case AudioCapture.Failure.microphoneDenied:
      "Microphone access is off. Allow it in System Settings > Privacy & Security > Microphone"
    case AudioCapture.Failure.noInputDevice:
      "No microphone found"
    case AudioCapture.Failure.captureFailed(let underlying):
      "Microphone failed: \(underlying.localizedDescription)"
    // A wrong key is a 400 from api.x.ai, and 401 means no key reached it at all.
    // Reading throws `STTError` itself, where dictation wraps it in `SessionError`.
    case SessionError.stt(.badRequest), SessionError.stt(.unauthorized),
      STTError.badRequest, STTError.unauthorized:
      "xAI rejected the API key"
    case SessionError.stt(.rateLimited), STTError.rateLimited:
      "xAI rate limit reached"
    case SessionError.stt(.unavailable), STTError.unavailable:
      "xAI is unavailable"
    case SessionError.stt(.server(let serverError)):
      "xAI error: \(serverError.message)"
    case SessionError.socket(let description):
      "Connection failed: \(description)"
    case let error as STTError:
      "xAI error: \(error)"
    case let error as URLError:
      "Connection failed: \(error.localizedDescription)"
    default:
      "Dictation failed: \(error)"
    }
  }
}

extension Pill {
  /// Takes a snapshot's text, and its state once audio is flowing. Until then the pill stays
  /// `starting`, whatever the session says, because nothing said yet is being heard.
  fileprivate mutating func apply(_ snapshot: SessionMachine.Snapshot, committed: String) {
    settled = [committed, snapshot.utterance].filter { !$0.isEmpty }.joined(separator: " ")
    provisional = snapshot.provisional
    switch snapshot.state {
    case .listening where phase != .starting: phase = .listening
    case .paused where phase != .starting: phase = .paused
    case .finalizing, .inserting: phase = .transcribing
    default: break
    }
  }
}
