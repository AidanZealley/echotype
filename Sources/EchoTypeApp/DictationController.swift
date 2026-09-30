import AppKit
import EchoTypeCore
import Foundation
import Observation

/// Reserves commands synchronously and owns each admitted operation's top-level task.
@MainActor @Observable final class DictationController {
  enum State { case idle, starting, listening, paused, finishing, inserting, cancelled }
  var state: State {
    guard case .dictating(let operation) = phase else { return .idle }
    switch operation.presentation {
    case .starting: return .starting
    case .capturing(let snapshot, let ready, _):
      guard ready else { return .starting }
      return snapshot.state == .paused ? .paused : .listening
    case .finishing: return .finishing
    case .inserting: return .inserting
    case .cancelled: return .cancelled
    }
  }
  private(set) var hasAPIKey: Bool?
  private(set) var lastError: String?
  private var keyStatusGeneration = 0
  /// The last dictation that reached `running`, whatever its outcome. Nil until one ends. Kept in
  /// memory only.
  private(set) var lastTrace: DictationTrace?
  /// What a test heard, for the settings window to show.
  enum TestOutcome {
    case heard(String)
    case heardNothing
    /// Worded by `describe(_:)`, as the pill would show it.
    case failed(String)
  }

  private enum Phase {
    case idle
    case dictating(DictationOperation)
    case testing(DictationOperation)
    case reading(Reader)
  }

  /// No dictation, test or reading is under way, so a test may start.
  var isIdle: Bool {
    if case .idle = phase { true } else { false }
  }

  /// The monitor reads the hotkey from it live; each session reads a copy of the rest.
  private let store: SettingsStore
  private let clipboard = Clipboard()
  @ObservationIgnored private var operationTask: Task<DictationOperation.Result, Never>?
  @ObservationIgnored private let panel = OverlayPanel()
  private var phase = Phase.idle
  private var monitor: HotkeyMonitor?
  @ObservationIgnored private var speakObserver: (any NSObjectProtocol)?

  /// The session's pill and the screen it stays on, from the press until the session ends.
  private var pill: Pill?
  private var screen: NSScreen?
  /// Fades an error pill after it has been read.
  private var errorFade: Task<Void, Never>?

  init(store: SettingsStore) {
    self.store = store
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
      startDictation()
    case .testing:
      break
    case .dictating(let operation):
      operation.commit()
    case .reading(let reader):
      startDictation(after: reader)
    }
  }

  /// Called inside the event tap.
  private func readAloudPressed() {
    switch phase {
    case .idle:
      startReading(.selection)
    case .reading(let reader):
      Task { reader.stop() }
    case .dictating, .testing:
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
    case .dictating, .testing:
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
    case .dictating(let operation):
      guard operation.canCancel else { return false }
      operation.cancel()
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

  // MARK: Dictation

  private func makeOperation(isTest: Bool) -> DictationOperation {
    let audio = AudioCapture()
    let operation = DictationOperation(settings: store.settings, isTest: isTest,
      dependencies: .init(
        startCapture: { try await audio.start(deviceUID: $0) },
        stopCapture: { audio.stop() },
        releaseCapture: { await audio.waitForCleanup() },
        key: { await Task.detached { Keychain.apiKey() }.value },
        transport: { URLSessionWebSocketTransport(url: STTConnection.streamingURL(settings: $0), apiKey: $1) },
        captureDestination: { DestinationFocus().capture() },
        insert: { [clipboard] text, destination, sends, cancelled, begin in
          await clipboard.insert(text, destination: destination, sends: sends, cancelled: cancelled, onBegin: begin)
        },
        revise: { key in
          Reviser(request: { try await RevisionRequest.revise($0, apiKey: key, final: false) },
            finalRequest: { try await RevisionRequest.revise($0, apiKey: key, final: true) })
        },
        clock: SystemClock(), testClock: SystemClock()),
      onPresentation: { [weak self] presentation, settled, provisional in
        if presentation == .cancelled { self?.end(); return }
        if case .starting(false, _) = presentation { self?.showStarting() }
        self?.updatePill {
          if case .capturing = presentation { $0.canCommit = true } else { $0.canCommit = false }
          $0.settled = settled
          $0.provisional = provisional
          if let phase = presentation.pillPhase { $0.phase = phase }
          if presentation == .finishing { $0.level = 0 }
        }
      })
    audio.onLevel = { [weak self, weak operation] level in
      guard let operation, self?.owns(operation) == true else { return }
      operation.microphoneReady()
      self?.updatePill { $0.level = level }
    }
    audio.onDevice = { [weak self, weak operation] device in
      guard let operation, self?.owns(operation) == true else { return }
      self?.updatePill { $0.inputDevice = device }
    }
    audio.onFailure = { [weak self, weak operation] error in
      guard let operation, self?.owns(operation) == true else { return }
      operation.captureFailed(error)
    }
    return operation
  }

  private func owns(_ operation: DictationOperation) -> Bool {
    switch phase {
    case .dictating(let current), .testing(let current): return current === operation
    default: return false
    }
  }

  private func startDictation(after reader: Reader? = nil) {
    let operation = makeOperation(isTest: false)
    phase = .dictating(operation)
    operationTask = Task {
      reader?.stop()
      await clipboard.waitForCleanup()
      let result = await operation.run()
      guard owns(operation) else { return result }
      if let trace = result.trace { lastTrace = trace }
      var message = result.startupFailure.map(describe)
      if message == nil, case .failed(_, let error) = result.outcome { message = describe(error) }
      if case .skipped = result.insertion.insertion {
        message = [message, "Destination changed or unavailable. Copy the text from Last Dictation."].compactMap { $0 }.joined(separator: " ")
      } else if case .skipped = result.insertion.sending {
        message = "Sending skipped because the destination changed. Text is in Last Dictation."
      }
      phase = .idle
      operationTask = nil
      end(showing: message)
      return result
    }
  }

  /// Five seconds of the same capture/transcription lifetime, without overlay or trace.
  func test() async -> TestOutcome? {
    guard isIdle else { return nil }
    let operation = makeOperation(isTest: true)
    phase = .testing(operation)
    let task = Task { await operation.run() }
    operationTask = task
    let result = await task.value
    guard owns(operation) else { return nil }
    phase = .idle
    operationTask = nil
    if let failure = result.startupFailure { return .failed(describe(failure)) }
    return switch result.outcome {
    case .insert(let text): .heard(text)
    case .nothing: .heardNothing
    case .failed(_, let error): .failed(describe(error))
    }
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
    pill = Pill(phase: .starting, startedAt: .now, canCommit: false, dictationHotkey: store.settings.hotkey)
    updatePill { _ in }
  }

  /// Changes the live pill and shows it. Does nothing once the session's pill has ended.
  private func updatePill(_ change: (inout Pill) -> Void) {
    guard var pill, let screen else { return }
    change(&pill)
    pill.dictationHotkey = store.settings.hotkey
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
    case DictationOperation.OperationError.noAPIKey:
      Self.noAPIKey
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
