import AppKit
import EchoTypeCore
import Foundation
import Observation

/// Owns the session lifecycle: the hotkey opens a session, the hotkey or a click on the pill
/// commits it, Escape discards it, and the outcome is inserted at the caret.
///
/// The overlay pill shows the session from the press to its end, errors included. `state` is
/// what the menu bar renders.
///
/// The settings window's Test button runs the same session through `test()`, which shows no
/// pill and inserts nothing. The hotkey, Escape and the pill ignore it.
///
/// The hotkey and Escape arrive inside the event tap's callback, which must only decide whether
/// to consume the event. So those handlers change `phase`, which is what that decision reads,
/// and leave every other piece of work to a task.
@MainActor @Observable final class DictationController {
  private(set) var state: SessionMachine.State = .idle

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
    /// moment every session. Presses and clicks are ignored; Escape abandons the start.
    case starting
    /// Escape was pressed while starting. The start stops at its next step.
    case abandoned
    case running(SessionMachine)
    /// A test from the settings window, from its start to its outcome.
    case testing
  }

  /// No dictation or test is starting or running, so a test may start.
  var isIdle: Bool {
    if case .idle = phase { true } else { false }
  }

  /// The monitor reads the hotkey from it live; each session reads a copy of the rest.
  private let store: SettingsStore
  private let audio = AudioCapture()
  private let inserter = Inserter()
  @ObservationIgnored private lazy var panel = OverlayPanel { [weak self] in self?.clicked() }
  private var phase = Phase.idle
  private var monitor: HotkeyMonitor?

  /// The session's pill and the screen it stays on, from the press until the session ends.
  private var pill: Pill?
  private var screen: NSScreen?
  /// Fades an error pill after it has been read.
  private var errorFade: Task<Void, Never>?

  init(store: SettingsStore) {
    self.store = store
    audio.onLevel = { [weak self] level in self?.levelChanged(level) }
    let monitor = HotkeyMonitor(
      store: store,
      onHotkey: { [weak self] in self?.hotkeyPressed() },
      onEscape: { [weak self] in self?.escapePressed() ?? false }
    )
    monitor.start()
    self.monitor = monitor
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
      Task { commit() }
    }
  }

  /// Called inside the event tap. Escape belongs to the focused app unless a session is
  /// starting or running.
  private func escapePressed() -> Bool {
    switch phase {
    case .idle, .testing:
      return false
    case .starting:
      phase = .abandoned
      Task { end() }
      return true
    case .abandoned:
      return true
    case .running(let session):
      Task { await session.cancel() }
      return true
    }
  }

  /// A click commits a running session, as Opt+D does. It never opens one, so clicking an
  /// error pill, or a pill fading after a session, never starts the microphone. Only Opt+D
  /// starts a session.
  private func clicked() {
    guard case .running = phase else { return }
    commit()
  }

  /// Commits by ending capture rather than triggering the session here. The pump sends what is
  /// still queued and the partial last chunk `stop()` flushes, then triggers, so the last word
  /// reaches xAI before `audio.done`. A second commit does nothing.
  private func commit() {
    audio.stop()
  }

  // MARK: Session

  /// One session, from the first press to the insertion.
  private func dictate() async {
    defer { phase = .idle }
    // Read once, here, so a change in Settings never reaches a session already running.
    let settings = store.settings
    showStarting()
    switch await start(settings) {
    case .abandoned:
      end()
    case .failed(let error):
      end(showing: error)
    case .started(let session, let chunks):
      phase = .running(session)
      let (outcome, audioFailure) = await run(session, streaming: chunks)
      finish(outcome, audioFailure: audioFailure)
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
    case .started(let started, let stream):
      (session, chunks) = (started, stream)
    }

    let commitAfterFive = Task {
      try? await Task.sleep(for: .seconds(5))
      if !Task.isCancelled { commit() }
    }
    let (outcome, audioFailure) = await run(session, streaming: chunks)
    // A session that ended early must not have a later one committed for it.
    commitAfterFive.cancel()
    return switch (outcome, audioFailure) {
    case (_, let error?), (.failed(_, let error as any Error), nil): .failed(describe(error))
    case (.insert(let text), nil): .heard(text)
    case (.nothing, nil): .heardNothing
    }
  }

  private enum Start {
    case started(SessionMachine, AsyncThrowingStream<Data, any Error>)
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
      return .failed("Add your xAI API key in EchoType Settings")
    }

    // The socket opens here, on trigger, because an idle open socket bills streaming time.
    let transport = URLSessionWebSocketTransport(
      url: STTConnection.streamingURL(settings: settings), apiKey: apiKey)
    let session = SessionMachine(transport: transport, settings: settings, clock: SystemClock())
    return .started(session, chunks)
  }

  private var isAbandoned: Bool {
    if case .abandoned = phase { true } else { false }
  }

  /// Escape arrived while starting: release the microphone and open no socket.
  private func abandon() -> Start {
    audio.stop()
    return .abandoned
  }

  /// Runs the session to its outcome, mirroring it into the menu and the pill and feeding it
  /// audio. Returns the error that ended capture early, if the microphone failed.
  private func run(
    _ session: SessionMachine, streaming chunks: AsyncThrowingStream<Data, any Error>
  ) async -> (SessionMachine.Outcome, (any Error)?) {
    let outcome = Task { await session.run() }
    var pump: Task<(any Error)?, Never>?
    for await snapshot in session.snapshots {
      state = snapshot.state
      updatePill { $0.apply(snapshot) }
      // The first snapshot is `listening`, from which point `send(audio:)` accepts audio rather
      // than dropping it.
      if pump == nil { pump = Task { await self.pump(chunks, into: session) } }
    }
    let result = await outcome.value
    // Ends the stream, which ends the pump, and releases the microphone.
    // A session that ended on its own (cancel, silence, the hard cap, a failure) still has a
    // stream open. After a commit this is a second `stop()`, which does nothing.
    audio.stop()
    let audioFailure = await pump?.value ?? nil
    state = .idle
    return (result, audioFailure)
  }

  /// Feeds the session every chunk the stream yields, then commits it. The stream ends on
  /// `stop()`, from a commit or the end of the session, or by throwing if the microphone
  /// fails. Returns that failure, if any.
  private func pump(
    _ chunks: AsyncThrowingStream<Data, any Error>, into session: SessionMachine
  ) async -> (any Error)? {
    var failure: (any Error)?
    do {
      for try await chunk in chunks {
        // A failed send means the socket failed, and the session reports that itself. Keep
        // draining, so the pump only ever ends with the stream and the trigger below.
        try? await session.send(audio: chunk)
      }
    } catch {
      // The microphone failed mid-session. Commit what was heard rather than lose it, and
      // report why it stopped.
      failure = error
    }
    // Does nothing if the session has already ended.
    await session.trigger()
    return failure
  }

  private func finish(_ outcome: SessionMachine.Outcome, audioFailure: (any Error)?) {
    var failure = audioFailure
    switch outcome {
    case .insert(let text):
      inserter.insert(text)
    case .nothing:
      break
    case .failed(let text, let error):
      if !text.isEmpty { inserter.insert(text) }
      failure = failure ?? error
    }
    end(showing: failure.map(describe))
  }

  // MARK: Pill

  /// Shows the pill in its starting state on the screen holding the focused window, replacing
  /// an error still showing from the last session.
  private func showStarting() {
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

  private func describe(_ error: any Error) -> String {
    switch error {
    case AudioCapture.Failure.microphoneDenied:
      "Microphone access is off. Allow it in System Settings > Privacy & Security > Microphone"
    case AudioCapture.Failure.noInputDevice:
      "No microphone found"
    case AudioCapture.Failure.captureFailed(let underlying):
      "Microphone failed: \(underlying.localizedDescription)"
    // A wrong key is a 400 from api.x.ai, and 401 means no key reached it at all.
    case SessionError.stt(.badRequest), SessionError.stt(.unauthorized):
      "xAI rejected the API key"
    case SessionError.stt(.rateLimited):
      "xAI rate limit reached"
    case SessionError.stt(.unavailable):
      "xAI is unavailable"
    case SessionError.stt(.server(let serverError)):
      "xAI error: \(serverError.message)"
    case SessionError.socket(let description):
      "Connection failed: \(description)"
    default:
      "Dictation failed: \(error)"
    }
  }
}

extension Pill {
  /// Takes a snapshot's text, and its state once audio is flowing. Until then the pill stays
  /// `starting`, whatever the session says, because nothing said yet is being heard.
  fileprivate mutating func apply(_ snapshot: SessionMachine.Snapshot) {
    settled = snapshot.settled
    provisional = snapshot.provisional
    switch snapshot.state {
    case .listening where phase != .starting: phase = .listening
    case .paused where phase != .starting: phase = .paused
    case .finalizing, .inserting: phase = .transcribing
    default: break
    }
  }
}
