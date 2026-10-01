import EchoTypeCore
import Foundation
import Observation

/// Owns capture, transcription, revision and insertion for one admitted command.
@MainActor @Observable final class DictationOperation {
  /// Advisory hints shown before finishing. Only finishing captures the insertion destination.
  struct Readiness: Equatable {
    var microphone = false
    var destination = false
  }

  enum Presentation: Equatable {
    case starting(Readiness)
    case capturing(SessionMachine.Snapshot, Readiness)
    case finishing
    case inserting
    case cancelled

    /// Nil once finishing, inserting or cancelled.
    var readiness: Readiness? {
      switch self {
      case .starting(let readiness), .capturing(_, let readiness): readiness
      case .finishing, .inserting, .cancelled: nil
      }
    }

    fileprivate func with(_ readiness: Readiness) -> Presentation {
      if case .capturing(let snapshot, _) = self { return .capturing(snapshot, readiness) }
      return .starting(readiness)
    }

    var pillPhase: Pill.Phase? {
      switch self {
      case .starting(let readiness), .capturing(_, let readiness):
        guard readiness.microphone else { return .starting }
        guard readiness.destination else { return .selectInput }
        if case .capturing(let snapshot, _) = self, snapshot.state == .paused { return .paused }
        return .listening
      case .finishing: return .transcribing
      case .inserting: return .inserting
      case .cancelled: return nil
      }
    }
  }

  struct Result {
    var outcome: SessionMachine.Outcome
    var insertion: Clipboard.InsertionResult
    var trace: DictationTrace?
    var startupFailure: (any Error)? = nil
  }

  struct Dependencies {
    var startCapture: @MainActor (String?) async throws -> AsyncThrowingStream<Data, any Error>
    var stopCapture: @MainActor () -> Void
    var releaseCapture: @MainActor () async -> Void
    var key: @Sendable () async -> String?
    var transport: @MainActor (Settings, String) -> any WebSocketTransport
    var captureDestination: @MainActor () -> Destination?
    var insert: @MainActor (String, Destination?, Bool, @escaping @MainActor () -> Bool, @escaping @MainActor () -> Void) async -> Clipboard.InsertionResult
    var revise: @MainActor (String) -> Reviser
    var clock: any SessionClock
    var testClock: any SessionClock
  }

  let settings: Settings
  let isTest: Bool
  private let dependencies: Dependencies
  private let onPresentation: @MainActor (Presentation, String, String) -> Void
  private(set) var presentation: Presentation = .starting(.init())
  var cancelled: Bool { presentation == .cancelled }
  private var settled = ""
  private var provisional = ""
  private var session: SessionMachine?
  private var reviser: Reviser?
  private var pump: Task<Void, Never>?
  /// The one finishing routine. See `finish()`.
  private var finisher: Task<Void, Never>?
  private var controls: [Task<Void, Never>] = []
  private var finalRevision: Task<String, Never>?
  private var destination: Destination?
  private var trace: DictationTrace?
  private var startupCaptureFailure: (any Error)?
  private var hasRun = false
  private var lastDestinationProbe: TimeInterval?
  /// Capture buffers report levels even during silence; reuse them instead of owning a timer.
  private static let destinationProbeInterval: TimeInterval = 0.5
  /// Finishing, inserting or cancelled.
  private var finishing: Bool { presentation.readiness == nil }

  init(settings: Settings, isTest: Bool = false, dependencies: Dependencies,
    onPresentation: @escaping @MainActor (Presentation, String, String) -> Void = { _, _, _ in }
  ) {
    self.settings = settings
    self.isTest = isTest
    self.dependencies = dependencies
    self.onPresentation = onPresentation
  }

  var canCommit: Bool {
    if case .capturing = presentation { true } else { false }
  }

  var canCancel: Bool { !isTest && presentation != .inserting && !cancelled }

  func microphoneReady() {
    guard hasRun, var readiness = presentation.readiness else { return }
    readiness.microphone = true
    let now = dependencies.clock.now
    if !isTest && lastDestinationProbe.map({ now - $0 >= Self.destinationProbeInterval }) != false {
      lastDestinationProbe = now
      // Advisory only. Never retain this token for insertion.
      readiness.destination = dependencies.captureDestination() != nil
    }
    let next = presentation.with(readiness)
    if next != presentation { publish(next) }
  }

  /// Synchronous admission signals. Resources and suspended children belong to this instance.
  func commit() {
    guard canCommit else { return }
    // The stop is acknowledged at once; `finish()` captures the destination and publishes again.
    publish(.finishing)
    finish()
  }

  func captureFailed(_ error: any Error) {
    guard !cancelled, presentation != .inserting else { return }
    if let session {
      controls.append(Task { await session.fail(error) })
    } else {
      startupCaptureFailure = error
      dependencies.stopCapture()
    }
  }

  func cancel() {
    guard canCancel else { return }
    publish(.cancelled)
    dependencies.stopCapture()
    pump?.cancel()
    finalRevision?.cancel()
    controls.append(Task {
      await session?.cancel()
      await reviser?.stop()
    })
  }

  func run() async -> Result {
    precondition(!hasRun, "A dictation operation runs once")
    hasRun = true
    let outcome: SessionMachine.Outcome
    var startupFailure: (any Error)?
    do {
      outcome = try await startAndTranscribe()
    } catch {
      startupFailure = cancelled ? nil : error
      outcome = cancelled ? .nothing : .failed(text: "", error: SessionError(error))
    }
    await releaseCapture()
    let final = await revise(outcome)
    return await insertAndRecord(final, startupFailure: startupFailure)
  }

  private func startAndTranscribe() async throws -> SessionMachine.Outcome {
    try checkStartup()
    let destinationReady = !isTest && dependencies.captureDestination() != nil
    if !isTest { lastDestinationProbe = dependencies.clock.now }
    publish(.starting(.init(destination: destinationReady)))
    let chunks = try await dependencies.startCapture(settings.inputDeviceID)
    try checkStartup()
    guard let key = await dependencies.key() else {
      try checkStartup()
      throw OperationError.noAPIKey
    }
    try checkStartup()
    let transport = dependencies.transport(settings, key)
    let session = SessionMachine(transport: transport, settings: settings, clock: dependencies.clock)
    self.session = session
    if !isTest { trace = DictationTrace(startedAt: .now, cleanUp: settings.cleanUp) }
    if settings.cleanUp && !isTest { reviser = dependencies.revise(key) }
    return await transcribe(session, chunks: chunks)
  }

  private func joinControls() async {
    while !controls.isEmpty {
      let pending = controls
      controls.removeAll()
      for task in pending { await task.value }
    }
  }

  /// Runs once the session has ended for any reason. Ending the session is what releases a
  /// stalled drain or send: capture stops, and the pump and finishing routine are cancelled
  /// and joined.
  private func releaseCapture() async {
    dependencies.stopCapture()
    pump?.cancel()
    finisher?.cancel()
    await pump?.value
    await finisher?.value
    await joinControls()
    await dependencies.releaseCapture()
    dependencies.testClock.cancel()
  }

  private func insertAndRecord(_ final: SessionMachine.Outcome, startupFailure: (any Error)?) async -> Result {
    let text: String
    let sends: Bool
    switch final {
    case .insert(let value): text = value; sends = settings.sendReplyRequests && ReplyRequest.matches(value)
    case .failed(let value, _): text = value; sends = false
    case .nothing: text = ""; sends = false
    }
    let insertion: Clipboard.InsertionResult
    if isTest {
      insertion = .init(insertion: .notAttempted, sending: .notRequested)
    } else {
      insertion = await dependencies.insert(text, destination, sends,
        { self.cancelled }, { self.publish(.inserting) })
    }
    await joinControls()
    let resultOutcome: SessionMachine.Outcome = cancelled ? .nothing : final
    if var trace {
      trace.endedAt = .now
      trace.finalText = cancelled ? "" : text
      trace.revisions = await reviser?.attempts ?? []
      trace.insertion = insertion.insertion
      trace.sending = insertion.sending
      if cancelled { trace.outcome = .cancelled }
      else if case .failed(_, let error) = final { trace.outcome = .failed(String(describing: error)) }
      else if case .nothing = final { trace.outcome = .nothing }
      else { trace.outcome = .completed }
      self.trace = trace
    }
    return Result(outcome: resultOutcome, insertion: insertion, trace: trace, startupFailure: startupFailure)
  }

  private func checkStartup() throws {
    if cancelled { throw CancellationError() }
    try Task.checkCancellation()
    if let startupCaptureFailure { throw startupCaptureFailure }
  }

  /// Ends capture and closes the protocol behind it. Started at most once, by the stop hotkey,
  /// reply-request detection, or the `finalizing` snapshot of the session's hard cap.
  private func finish() {
    guard finisher == nil, !cancelled, let session else { return }
    finisher = Task {
      // The finishing deadline covers everything after this, so a stalled drain or send ends.
      await session.beginFinishing()
      if !cancelled {
        if !isTest { destination = dependencies.captureDestination() }
        publish(.finishing)
      }
      // Drain the remaining chunks, including the partial one capture flushes on stop, so the
      // closing frames follow every word.
      dependencies.stopCapture()
      await pump?.value
      guard !cancelled else { return }
      await session.sendClosing()
    }
  }

  private func transcribe(_ session: SessionMachine, chunks: AsyncThrowingStream<Data, any Error>) async -> SessionMachine.Outcome {
    let running = Task { await session.run() }
    var revisionUpdates: Task<Void, Never>?
    if let reviser {
      revisionUpdates = Task {
        for await _ in reviser.updates {
          guard case .capturing(let snapshot, _) = presentation else { continue }
          let shown = await reviser.shown
          guard case .capturing(let current, _) = presentation, current == snapshot else { continue }
          publish(presentation, settled: [shown, snapshot.utterance].filter { !$0.isEmpty }.joined(separator: " "), provisional: snapshot.provisional)
        }
      }
    }
    var committedLength = 0
    for await snapshot in session.snapshots {
      if pump == nil {
        pump = Task {
          do {
            for try await chunk in chunks { try await session.send(audio: chunk) }
          } catch {
            if !cancelled { await session.fail(error) }
          }
        }
        if isTest {
          dependencies.testClock.schedule(at: dependencies.testClock.now + 5) { [weak self] in
            await self?.commit()
          }
        }
      }
      if snapshot.committed.count > committedLength {
        trace?.commits.append(.init(at: .now, text: snapshot.committed.dropFirst(committedLength).trimmingCharacters(in: .whitespaces)))
      }
      committedLength = snapshot.committed.count
      trace?.streamed = snapshot.committed
      if snapshot.state == .cancelled { publish(.cancelled) }
      // A `finalizing` snapshot this operation didn't request is the hard cap.
      if snapshot.state == .finalizing { finish() }
      let shown = await reviser?.submit(committed: snapshot.committed) ?? snapshot.committed
      if !cancelled && !finishing && (snapshot.state == .listening || snapshot.state == .paused) {
        publish(.capturing(snapshot, presentation.readiness ?? .init()), settled: [shown, snapshot.utterance].filter { !$0.isEmpty }.joined(separator: " "), provisional: snapshot.provisional)
        if !isTest && settings.sendReplyRequests && ReplyRequest.matches(snapshot.committed) { commit() }
      } else if !cancelled && finishing {
        publish(.finishing, settled: [shown, snapshot.utterance].filter { !$0.isEmpty }.joined(separator: " "), provisional: snapshot.provisional)
      }
    }
    let result = await running.value
    revisionUpdates?.cancel()
    await revisionUpdates?.value
    return result
  }

  private func revise(_ outcome: SessionMachine.Outcome) async -> SessionMachine.Outcome {
    guard let reviser else { return cancelled ? .nothing : outcome }
    switch outcome {
    case .insert(let committed):
      let revision = Task { await reviser.finish(committed: committed) }
      finalRevision = revision
      let text = await withTaskCancellationHandler { await revision.value } onCancel: { revision.cancel() }
      finalRevision = nil
      if cancelled { await reviser.stop(); return .nothing }
      publish(.finishing, settled: text, provisional: "")
      return text.isEmpty ? .nothing : .insert(text)
    case .failed(let committed, let error):
      let text = await reviser.submit(committed: committed)
      await reviser.stop()
      return .failed(text: text, error: error)
    case .nothing:
      await reviser.stop()
      return .nothing
    }
  }

  private func publish(_ next: Presentation, settled: String? = nil, provisional: String? = nil) {
    presentation = next
    if let settled { self.settled = settled }
    if let provisional { self.provisional = provisional }
    if !isTest { onPresentation(next, self.settled, self.provisional) }
  }

  enum OperationError: Error { case noAPIKey }
}
