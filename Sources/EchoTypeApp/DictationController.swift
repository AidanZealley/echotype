import AppKit
import EchoTypeCore
import Foundation
import Observation

/// Reserves commands synchronously and owns each admitted operation's top-level task.
@MainActor @Observable final class DictationController {
  enum State { case idle, starting, listening, reading, paused, finishing, inserting, cancelled }
  var state: State {
    if case .reading(let reader) = phase {
      return switch reader.presentation {
      case .starting: .starting
      case .playing: .reading
      case .paused: .paused
      case .failed, .stopped: .idle
      }
    }
    guard case .dictating(let operation) = phase else { return .idle }
    switch operation.presentation {
    case .starting: return .starting
    case .capturing(let snapshot, let readiness):
      guard readiness.microphone else { return .starting }
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
  private let clipboard: Clipboard
  typealias ReadingFactory = (Reader.Source, UUID, Settings,
    @escaping @MainActor (Reader) -> Void, @escaping @MainActor (Double) -> Void) -> Reader
  private let makeReader: ReadingFactory
  private let makeDictation: ((Bool) -> DictationOperation)?
  private let focusedScreen: () -> NSScreen?
  private let showPanel: (Pill, NSScreen?) -> Void
  private let hidePanel: () -> Void
  @ObservationIgnored private var operationTask: Task<DictationOperation.Result, Never>?
  @ObservationIgnored private var readingTask: Task<Void, Never>?
  private var phase = Phase.idle
  private var monitor: HotkeyMonitor?
  @ObservationIgnored private var speakObserver: (any NSObjectProtocol)?

  /// The session's pill and the screen it stays on, from the press until the session ends.
  private var pill: Pill?
  private var screen: NSScreen?
  /// Fades an error pill after it has been read.
  private var errorFade: Task<Void, Never>?

  init(store: SettingsStore, clipboard: Clipboard, makeReader: @escaping ReadingFactory,
    focusedScreen: @escaping () -> NSScreen?, showPanel: @escaping (Pill, NSScreen?) -> Void,
    hidePanel: @escaping () -> Void, makeDictation: ((Bool) -> DictationOperation)? = nil
  ) {
    self.makeDictation = makeDictation
    self.store = store; self.clipboard = clipboard; self.makeReader = makeReader
    self.focusedScreen = focusedScreen; self.showPanel = showPanel; self.hidePanel = hidePanel
  }

  convenience init(store: SettingsStore) {
    let clipboard = Clipboard()
    let panel = OverlayPanel()
    self.init(store: store, clipboard: clipboard, makeReader: { source, id, settings, present, level in
      Reader(source, id: id, settings: settings, dependencies: .init(
        selection: { await clipboard.copySelection(cancelled: $0) },
        cleanup: { await clipboard.waitForCleanup() },
        key: { await Task.detached { Keychain.apiKey() }.value },
        request: { SpeechRequest($0) }, player: SpeechPlayer(onLevel: level)), onPresentation: present)
    }, focusedScreen: { NSScreen.forFocusedWindow() }, showPanel: { pill, screen in
      if let screen { panel.show(pill, on: screen) }
    }, hidePanel: { panel.hide() })
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
    speakObserver = DistributedNotificationCenter.default().addObserver(
      forName: SpeechDelivery.requestName, object: nil, queue: .main
    ) { [weak self] notification in
      guard let fields = notification.userInfo else { return }
      let request = SpeechDelivery.Incoming(fields)
      MainActor.assumeIsolated {
        guard let self,
          let reply = SpeechAdmission.receive(request, pid: getpid(),
            now: ProcessInfo.processInfo.systemUptime, admit: self.speak)
        else { return }
        DistributedNotificationCenter.default().postNotificationName(
          SpeechDelivery.replyName, object: nil, userInfo: reply, options: [.deliverImmediately])
      }
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
  func hotkeyPressed() {
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
  func readAloudPressed() {
    switch phase {
    case .idle:
      startReading(.selection)
    case .reading(let reader):
      reader.stop()
    case .dictating, .testing:
      break
    }
  }

  /// Reads `text` given by another process, under the same rules as the read-aloud hotkey,
  /// except that a reading in progress is replaced. Declined while a dictation or test is
  /// starting or running, so the agent never talks over the user.
  @discardableResult func speak(_ text: String) -> Bool {
    switch phase {
    case .idle:
      startReading(.text(text))
      return true
    case .reading(let reader):
      startReading(.text(text), replacing: reader)
      return true
    case .dictating, .testing:
      return false
    }
  }

  /// Admission reserves the successor synchronously. Its startup waits for the old run and
  /// clipboard cleanup, so packet 5 can reply as soon as this boundary accepts the request.
  private func startReading(_ source: Reader.Source, replacing old: Reader? = nil) {
    let previous = readingTask
    old?.stop()
    lastError = nil
    errorFade?.cancel()
    let settings = store.settings
    let id = UUID()
    let operation = makeReader(source, id, settings, { [weak self] reader in
      guard self?.isReading(reader) == true else { return }
      self?.showReading(reader)
    }, { [weak self] level in
      guard let self, case .reading(let reader) = self.phase, reader.id == id else { return }
      reader.receiveLevel(level)
    })
    phase = .reading(operation)
    // Focus lookup and playback setup stay outside the event-tap callback.
    readingTask = Task {
      if isReading(operation) {
        screen = focusedScreen()
        showReading(operation)
      }
      await previous?.value
      await clipboard.waitForCleanup()
      let failure = await operation.run()
      guard isReading(operation) else { return }
      phase = .idle; readingTask = nil
      end(showing: failure.map(describe))
    }
  }

  private func showReading(_ reader: Reader) {
    let phase: Pill.Phase
    switch reader.presentation {
    case .starting: phase = .readingStarting
    case .playing: phase = .reading
    case .paused: phase = .readingPaused
    case .failed(let message): phase = .error(message)
    case .stopped: end(); return
    }
    pill = Pill(phase: phase, isReading: true, level: reader.level,
      startedAt: reader.startedAt, pausedAt: reader.pausedAt, pausedDuration: reader.pausedDuration)
    updatePill { _ in }
  }

  /// Called inside the event tap. Escape belongs to the focused app unless a session is
  /// starting or running, or a reading is under way.
  func escapePressed() -> Bool {
    switch phase {
    case .idle, .testing:
      return false
    case .reading(let reader):
      reader.stop()
      return true
    case .dictating(let operation):
      guard operation.canCancel else { return false }
      operation.cancel()
      return true
    }
  }

  /// Space belongs to the focused app except during a reading.
  func spacePressed(repeated: Bool) -> Bool {
    guard case .reading(let reader) = phase else { return false }
    if !repeated { reader.togglePause() }
    return true
  }

  // MARK: Dictation

  private func makeOperation(isTest: Bool) -> DictationOperation {
    if let makeDictation { return makeDictation(isTest) }
    let audio = AudioCapture()
    let operation = DictationOperation(settings: store.settings, isTest: isTest,
      dependencies: .init(
        startCapture: { try await audio.start(deviceUID: $0) },
        stopCapture: { audio.stop() },
        releaseCapture: { await audio.waitForCleanup() },
        key: { await Task.detached { Keychain.apiKey() }.value },
        transcription: XAI.transcription,
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
        if case .starting(let readiness) = presentation, !readiness.microphone { self?.showStarting() }
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
    let previousReading = readingTask
    readingTask = nil
    if let reader {
      reader.stop()
      end()
    }
    operationTask = Task {
      await previousReading?.value
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

  /// Joins the operation reserved at call time, including selection restoration.
  func waitForCompletion() async {
    let reading = readingTask
    let dictation = operationTask
    await reading?.value
    _ = await dictation?.value
  }

  /// Last Dictation Copy shares the clipboard owner with reading and insertion.
  func copyLastDictation(_ text: String) async { await clipboard.copy(text) }

  // MARK: Reading

  private func isReading(_ reader: Reader) -> Bool {
    if case .reading(let current) = phase { current === reader } else { false }
  }

  // MARK: Pill

  /// Shows the pill in its starting state on the screen holding the focused window, replacing
  /// an error still showing from the last session.
  private func showStarting() {
    lastError = nil
    errorFade?.cancel()
    screen = focusedScreen()
    pill = Pill(phase: .starting, startedAt: .now, canCommit: false, dictationHotkey: store.settings.hotkey)
    updatePill { _ in }
  }

  /// Changes the live pill and shows it. Does nothing once the session's pill has ended.
  private func updatePill(_ change: (inout Pill) -> Void) {
    guard var pill else { return }
    change(&pill)
    pill.dictationHotkey = store.settings.hotkey
    self.pill = pill
    showPanel(pill, screen)
  }

  /// Ends the session's pill: fades it, or shows `error` in red for three seconds first.
  private func end(showing error: String? = nil) {
    lastError = error
    guard var pill else { return }
    self.pill = nil
    guard let error else { return hidePanel() }
    pill.phase = .error(error)
    showPanel(pill, screen)
    errorFade = Task {
      try? await Task.sleep(for: .seconds(3))
      if !Task.isCancelled { hidePanel() }
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
    // Reading throws `ProviderError` itself, where dictation wraps it in `SessionError`.
    case SessionError.provider(let error), let error as ProviderError:
      describe(error)
    case SessionError.socket(let description):
      "Connection failed: \(description)"
    case let error as URLError:
      "Connection failed: \(error.localizedDescription)"
    default:
      "Dictation failed: \(error)"
    }
  }

  private func describe(_ error: ProviderError) -> String {
    switch error {
    case .rejectedCredential: "xAI rejected the API key"
    case .rateLimited: "xAI rate limit reached"
    case .unavailable: "xAI is unavailable"
    case .failed(let description): "xAI error: \(description)"
    }
  }
}
