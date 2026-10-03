import AppKit
import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Synchronization
import Testing

// These tests drive `DictationOperation` only through its dependencies, its admission signals and
// its presentation, and assert outcomes: inserted text, calls to the transcriber, the trace and which
// resources were released. They must keep passing unchanged while the session's internals move.

private final class Gate: Sendable {
  private let stream: AsyncStream<Void>
  private let release: AsyncStream<Void>.Continuation
  init() { (stream, release) = AsyncStream.makeStream() }
  /// Returns once opened, or when the waiting task is cancelled.
  func wait() async { for await _ in stream { break } }
  func open() { release.finish() }
}

/// Places the fakes pass through, and presentation the operation publishes.
enum Point: Hashable, Sendable {
  case captureStart, key, transcriberStart, audioSend, finish, finished, captureStop, captureRelease
  case destination, revision
  /// Insertion before and after the clipboard boundary.
  case insertion, clipboard
  case heard, paused, finishing
}

/// Records each point reached. A test waits for a point, or holds one to keep the operation
/// suspended there until it releases it.
private final class Points: Sendable {
  private struct State {
    var counts: [Point: Int] = [:]
    var arrivals: [Point: Gate] = [:]
    var holds: [Point: Gate] = [:]
  }
  private let state = Mutex(State())

  func record(_ point: Point) {
    state.withLock { state -> Gate? in
      state.counts[point, default: 0] += 1
      return state.arrivals.removeValue(forKey: point)
    }?.open()
  }

  func pass(_ point: Point) async {
    record(point)
    await state.withLock { $0.holds[point] }?.wait()
  }

  func reached(_ point: Point) async {
    let arrival = state.withLock { state -> Gate? in
      guard state.counts[point, default: 0] == 0 else { return nil }
      if let gate = state.arrivals[point] { return gate }
      let gate = Gate()
      state.arrivals[point] = gate
      return gate
    }
    await arrival?.wait()
  }

  func count(_ point: Point) -> Int { state.withLock { $0.counts[point, default: 0] } }
  func hold(_ point: Point) { state.withLock { $0.holds[point] = Gate() } }
  func release(_ point: Point) { state.withLock { $0.holds.removeValue(forKey: point) }?.open() }
}

/// Time moves only when a test advances it. `advance` returns after a due wake-up has run.
private final class ManualClock: SessionClock, Sendable {
  private struct State {
    var now: TimeInterval = 0
    var action: (@Sendable () async -> Void)?
    var deadline: TimeInterval?
  }
  private let state = Mutex(State())
  /// Opens on the first wake-up scheduled.
  let armed = Gate()
  var now: TimeInterval { state.withLock { $0.now } }
  func schedule(at deadline: TimeInterval, fire: @escaping @Sendable () async -> Void) {
    state.withLock { $0.deadline = deadline; $0.action = fire }
    armed.open()
  }
  func cancel() { state.withLock { $0.deadline = nil; $0.action = nil } }
  func advance(_ seconds: TimeInterval) async {
    let action = state.withLock { state -> (@Sendable () async -> Void)? in
      state.now += seconds
      guard let deadline = state.deadline, deadline <= state.now else { return nil }
      defer { state.action = nil; state.deadline = nil }
      return state.action
    }
    await action?()
  }
}

/// Records calls (audio as `audio <first byte>`, then `finish`) and lets the test emit events.
/// Answers `finish()` with `.finished` unless told not to.
private final class Transcriber: LiveTranscriber {
  private struct State {
    var calls: [String] = []
    var committed = ""
    var failing: Point?
    var answersFinish = true
    var closed = false
  }
  private let points: Points
  private let state = Mutex(State())
  let events: AsyncThrowingStream<TranscriptionEvent, any Error>
  private let publisher: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  init(_ points: Points) {
    self.points = points
    (events, publisher) = AsyncThrowingStream.makeStream()
  }

  var calls: [String] { state.withLock { $0.calls } }
  var closed: Bool { state.withLock { $0.closed } }
  /// Calls at this point throw.
  func fail(at point: Point) { state.withLock { $0.failing = point } }
  func withholdFinished() { state.withLock { $0.answersFinish = false } }

  func emit(_ event: TranscriptionEvent) { publisher.yield(event) }
  /// Commits `words` after what was already said.
  func say(_ words: String) {
    let committed = state.withLock { state in
      state.committed = state.committed.isEmpty ? words : "\(state.committed) \(words)"
      return state.committed
    }
    emit(.transcript(Transcript(committed: committed)))
    emit(.speech)
  }
  /// The provider ends the events.
  func disconnect() { publisher.finish() }

  func send(audio: Data) async throws {
    try await pass(.audioSend)
    state.withLock { $0.calls.append("audio \(audio.first ?? 0)") }
  }
  func finish() async throws {
    try await pass(.finish)
    let answers = state.withLock { state in
      state.calls.append("finish")
      return state.answersFinish
    }
    points.record(.finished)
    if answers { emit(.finished) }
  }
  private func pass(_ point: Point) async throws {
    await points.pass(point)
    try Task.checkCancellation()
    if state.withLock({ $0.failing == point }) { throw ProviderError.unavailable }
  }
  /// Closing releases suspended calls, as a real connection does.
  func close() {
    state.withLock { $0.closed = true }
    points.release(.audioSend)
    points.release(.finish)
    publisher.finish()
  }
  func waitForClose() async {}
}

private struct Insertion: Equatable {
  var text: String
  var sends: Bool
}

@MainActor private final class Harness {
  let points = Points()
  let transcriber: Transcriber
  let clock = ManualClock()
  let testClock = ManualClock()
  let revisionClock = ManualClock()
  private let capture: AsyncThrowingStream<Data, any Error>
  private let chunks: AsyncThrowingStream<Data, any Error>.Continuation
  /// The partial chunk capture flushes when it stops.
  var finalChunk: Data?
  var focusedDestination: Destination?
  var insertedDestination: Destination?
  var insertions: [Insertion] = []
  var presented: [DictationOperation.Presentation] = []
  var insertionResult = Clipboard.InsertionResult(insertion: .attempted, sending: .notRequested)
  var credential = Credential.apiKey(placeholder: "")
  var storedKey: String? = "fake-key"
  /// Nil for a provider with the default, always-ready readiness.
  var readiness: ServiceReadiness?
  var requests: [TranscriptionRequest] = []

  init() {
    transcriber = Transcriber(points)
    (capture, chunks) = AsyncThrowingStream.makeStream()
  }

  func speak(_ chunk: Data) { chunks.yield(chunk) }

  func operation(test: Bool = false, cleanup: Bool = false) -> DictationOperation {
    let points = points
    return DictationOperation(settings: Settings(sendReplyRequests: true), isTest: test,
      dependencies: .init(
        startCapture: { _ in
          await points.pass(.captureStart)
          return self.capture
        },
        stopCapture: {
          if let chunk = self.finalChunk { self.chunks.yield(chunk); self.finalChunk = nil }
          // Holding `.captureStop` stalls the drain: the stream stays open until released.
          Task { await points.pass(.captureStop); self.chunks.finish() }
        },
        releaseCapture: { points.record(.captureRelease) },
        provider: Provider(
          id: "fixture", name: "Fixture", summary: "", credential: credential, languages: [.english],
          transcription: TranscriptionService(keytermLimit: 100) { request in
            await MainActor.run { self.requests.append(request) }
            await points.pass(.transcriberStart)
            return self.transcriber
          },
          voice: VoiceService(voices: [Voice(id: "default", name: "Default")], speedRange: 1...1, maximumCharacters: 1) { _ in
            fatalError("Not spoken")
          },
          cleanup: cleanup ? CleanupService { request in
            guard request.final else { return request.text }
            await points.pass(.revision)
            try Task.checkCancellation()
            return request.text
          } : nil,
          readiness: readiness.map { answer in
            Readiness(check: { _ in answer }, changes: { AsyncStream { _ in } })
          } ?? .always),
        key: { [storedKey] in
          await points.pass(.key)
          return storedKey
        },
        captureDestination: { points.record(.destination); return self.focusedDestination },
        insert: { text, destination, sends, cancelled, begin in
          self.insertedDestination = destination
          await points.pass(.insertion)
          if cancelled() { return .init(insertion: .cancelled, sending: .notRequested) }
          if text.isEmpty { return .init(insertion: .notAttempted, sending: .notRequested) }
          begin()
          await points.pass(.clipboard)
          self.insertions.append(.init(text: text, sends: sends))
          return self.insertionResult
        },
        clock: clock, testClock: testClock, revisionClock: revisionClock),
      onPresentation: { phase, _, _ in
        self.presented.append(phase)
        switch phase {
        case .capturing(let snapshot, _):
          if snapshot.state == .paused { points.record(.paused) }
          if !snapshot.transcript.committed.isEmpty { points.record(.heard) }
        case .finishing: points.record(.finishing)
        default: break
        }
      })
  }

  /// Runs the operation until `words` are committed.
  func start(_ operation: DictationOperation, saying words: String = "spoken words") async -> Task<DictationOperation.Result, Never> {
    let task = Task { await operation.run() }
    transcriber.emit(.ready)
    transcriber.say(words)
    await points.reached(.heard)
    return task
  }
}

/// What ends capture and starts finishing.
enum Trigger: Sendable, CaseIterable { case stop, replyRequest, hardCap }
enum ReadinessFailure: Sendable, CaseIterable { case noReady, backlog }

@Suite(.timeLimit(.minutes(1))) @MainActor
struct DictationOperationTests {
  private func destination(target: pid_t = 3) -> Destination {
    Destination(application: AXUIElementCreateApplication(1),
      window: AXUIElementCreateApplication(2), target: AXUIElementCreateApplication(target), pid: 1)
  }

  // MARK: Readiness

  @Test("Destination readiness follows focus during silent buffers and cannot revive finishing")
  func destinationReadiness() async {
    let h = Harness()
    let operation = h.operation()
    let task = await h.start(operation)
    #expect(operation.presentation.pillPhase == .starting)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.points.count(.destination) == 1)
    h.focusedDestination = destination()
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.points.count(.destination) == 1)
    await h.clock.advance(0.5)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .listening)
    #expect(h.points.count(.destination) == 2)
    await h.clock.advance(10)
    await h.points.reached(.paused)
    #expect(operation.presentation.pillPhase == .paused)
    // Silent buffers keep reporting levels after the session pauses.
    h.focusedDestination = nil
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.points.count(.destination) == 3)
    operation.commit()
    await h.points.reached(.finishing)
    let probes = h.points.count(.destination)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .transcribing)
    #expect(h.points.count(.destination) == probes)
    _ = await task.value
  }

  @Test("Ready focus preserves microphone startup; cancellation stops advisory probes")
  func microphoneReadinessPrecedence() async {
    let h = Harness()
    h.focusedDestination = destination()
    h.points.hold(.captureStart)
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.points.reached(.captureStart)
    #expect(operation.presentation.pillPhase == .starting)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .listening)
    operation.cancel()
    await h.clock.advance(1)
    operation.microphoneReady()
    #expect(operation.presentation == .cancelled && h.points.count(.destination) == 1)
    h.points.release(.captureStart)
    _ = await task.value
  }

  // MARK: Startup

  @Test("Cancellation before run acquires nothing and shows only cancellation")
  func cancelledBeforeRun() async {
    let h = Harness()
    let operation = h.operation()
    operation.cancel()
    let result = await operation.run()
    #expect(result.outcome == .nothing && result.startupFailure == nil && result.trace == nil)
    #expect(h.points.count(.captureStart) == 0 && h.points.count(.key) == 0 && h.points.count(.transcriberStart) == 0)
    #expect(h.insertions.isEmpty && h.points.count(.captureRelease) == 1)
    #expect(h.presented == [.cancelled])
  }

  @Test("Cancellation during capture or key setup never starts a transcriber", arguments: [Point.captureStart, .key])
  func cancelledStartup(at point: Point) async {
    let h = Harness()
    h.points.hold(point)
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.points.reached(point)
    operation.cancel()
    h.points.release(point)
    let result = await task.value
    #expect(result.outcome == .nothing && result.trace == nil)
    #expect(h.points.count(.transcriberStart) == 0 && h.insertions.isEmpty && h.points.count(.captureRelease) == 1)
  }

  @Test("Escape while the transcriber starts closes it without running a session")
  func cancelledWhileStarting() async {
    let h = Harness()
    h.points.hold(.transcriberStart)
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.points.reached(.transcriberStart)
    operation.cancel()
    h.points.release(.transcriberStart)
    let result = await task.value
    #expect(result.outcome == .nothing && result.trace == nil && h.transcriber.closed)
    #expect(h.insertions.isEmpty && h.points.count(.captureRelease) == 1)
  }

  @Test("Capture failure during key setup prevents a later transcriber start")
  func captureFailureDuringStartup() async {
    let h = Harness()
    h.points.hold(.key)
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.points.reached(.key)
    operation.captureFailed(CaptureError("Microphone stopped"))
    h.points.release(.key)
    let result = await task.value
    guard case .failed = result.outcome else { Issue.record("Expected startup failure"); return }
    #expect(h.points.count(.transcriberStart) == 0 && h.insertions.isEmpty && h.points.count(.captureRelease) == 1)
    #expect(result.startupFailure != nil && result.trace == nil)
  }

  @Test("A provider that needs no credential dictates without a stored key")
  func noCredentialNeeded() async {
    let h = Harness()
    h.credential = .none
    h.storedKey = nil
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    #expect(await task.value.outcome == .insert("spoken words"))
    #expect(h.requests.map(\.credential) == [nil])
  }

  @Test("A missing key fails before a transcriber starts")
  func missingKey() async {
    let h = Harness()
    h.storedKey = nil
    let result = await h.operation().run()
    guard result.startupFailure is MissingCredential else {
      Issue.record("Expected MissingCredential"); return
    }
    #expect(h.points.count(.transcriberStart) == 0 && h.points.count(.captureRelease) == 1)
  }

  @Test("Readiness fails the session without .ready in five seconds or past the held audio bound",
    arguments: ReadinessFailure.allCases)
  func readinessFailure(_ failure: ReadinessFailure) async {
    let h = Harness()
    let operation = h.operation()
    if failure == .backlog { h.speak(Data(count: SessionMachine.heldAudioLimit + 1)) }
    let task = Task { await operation.run() }
    await h.clock.armed.wait()
    if failure == .noReady { await h.clock.advance(5) }
    guard case .failed(let text, _) = await task.value.outcome else { Issue.record("Expected readiness failure"); return }
    #expect(text.isEmpty && h.transcriber.calls.isEmpty && h.points.count(.captureRelease) == 1)
  }

  // MARK: Provider readiness

  @Test("Dictation waits for transcription, opening no capture or transcriber",
    arguments: [ServiceState.waiting("Downloading speech model"), .unavailable("Not supported")])
  func blockedDictation(_ state: ServiceState) async {
    let h = Harness()
    h.readiness = ServiceReadiness(transcription: state, voice: .ready, cleanup: .ready)
    let result = await h.operation(cleanup: true).run()
    #expect((result.startupFailure as? NotReady)?.state == state && result.trace == nil)
    #expect(h.points.count(.captureStart) == 0 && h.points.count(.transcriberStart) == 0)
    #expect(h.insertions.isEmpty)
  }

  @Test("Cleanup is used only if ready at start; otherwise the dictation inserts unrevised and reports it",
    arguments: [ServiceState.ready, .waiting("Loading"), .unavailable("Not supported")])
  func cleanupReadiness(_ state: ServiceState) async {
    let h = Harness()
    h.readiness = ServiceReadiness(transcription: .ready, voice: .ready, cleanup: state)
    let operation = h.operation(cleanup: true)
    let task = await h.start(operation)
    let skipped = state != .ready
    #expect(h.presented.contains { $0.hints?.cleanupSkipped == true } == skipped)
    operation.commit()
    let result = await task.value
    #expect(result.startupFailure == nil && result.outcome == .insert("spoken words"))
    #expect(h.points.count(.revision) == (skipped ? 0 : 1))
  }

  @Test("Test waits for transcription only")
  func testReadiness() async {
    let blocked = Harness()
    blocked.readiness = ServiceReadiness(
      transcription: .waiting("Downloading speech model"), voice: .ready, cleanup: .ready)
    let failure = await blocked.operation(test: true).run().startupFailure
    #expect((failure as? NotReady)?.state == .waiting("Downloading speech model"))
    #expect(blocked.points.count(.captureStart) == 0)

    let h = Harness()
    h.readiness = ServiceReadiness(
      transcription: .ready, voice: .unavailable("No voice"), cleanup: .waiting("Loading"))
    let task = Task { await h.operation(test: true).run() }
    await h.points.reached(.captureStart)
    h.transcriber.emit(.ready)
    h.transcriber.say("test words")
    h.speak(Data([1]))
    await h.points.reached(.audioSend)
    await h.testClock.advance(5)
    #expect(await task.value.outcome == .insert("test words"))
  }

  // MARK: Finishing

  @Test("Stop, reply request and hard cap drain captured audio before finish()", arguments: Trigger.allCases)
  func drainsBeforeClosing(_ trigger: Trigger) async {
    let h = Harness()
    h.finalChunk = Data([2])
    let operation = h.operation()
    let task = await h.start(operation)
    // The first chunk is still on its way out when finishing begins.
    h.points.hold(.audioSend)
    h.speak(Data([1]))
    await h.points.reached(.audioSend)
    switch trigger {
    case .stop: operation.commit(); operation.commit() // A repeated stop finishes once.
    case .replyRequest: h.transcriber.say("Reply with EchoType")
    case .hardCap: Task { await h.clock.advance(operation.settings.hardCap) }
    }
    await h.points.reached(.captureStop)
    h.points.release(.audioSend)
    let result = await task.value
    #expect(h.transcriber.calls == ["audio 1", "audio 2", "finish"])
    let text = trigger == .replyRequest ? "spoken words Reply with EchoType" : "spoken words"
    #expect(result.outcome == .insert(text))
    #expect(h.insertions == [.init(text: text, sends: trigger == .replyRequest)])
    #expect(result.trace?.insertion == .attempted)
  }

  @Test("The finishing deadline starts when finishing begins and covers .finished", arguments: [false, true])
  func finishingDeadline(expires: Bool) async {
    let h = Harness()
    h.transcriber.withholdFinished()
    let operation = h.operation()
    let task = await h.start(operation)
    await h.clock.advance(9) // Listening time does not count against the deadline.
    operation.commit()
    await h.points.reached(.finished)
    let timeout = operation.settings.finalizeTimeout
    await h.clock.advance(expires ? timeout : timeout - 0.1)
    h.transcriber.emit(.finished)
    let outcome = await task.value.outcome
    if expires {
      guard case .failed(let text, _) = outcome else { Issue.record("Expected timeout"); return }
      #expect(text == "spoken words")
      #expect(h.insertions == [.init(text: "spoken words", sends: false)])
    } else {
      #expect(outcome == .insert("spoken words"))
    }
  }

  @Test("A stalled send or capture drain ends at the finishing deadline and releases capture",
    arguments: [Point.audioSend, .finish, .captureStop])
  func stalledFinishing(at point: Point) async {
    let h = Harness()
    let operation = h.operation()
    let task = await h.start(operation)
    h.points.hold(point)
    if point == .audioSend { h.speak(Data([1])) }
    operation.commit()
    // Stopping capture follows arming the deadline.
    await h.points.reached(.captureStop)
    await h.points.reached(point)
    await h.clock.advance(operation.settings.finalizeTimeout)
    guard case .failed(let text, _) = await task.value.outcome else { Issue.record("Expected timeout"); return }
    #expect(text == "spoken words" && h.insertions == [.init(text: "spoken words", sends: false)])
    #expect(h.points.count(.captureRelease) == 1)
  }

  @Test("A send failure preserves committed words and never sends Return", arguments: [Point.audioSend, .finish])
  func sendFailure(at point: Point) async {
    let h = Harness()
    h.transcriber.fail(at: point)
    h.finalChunk = Data([1])
    let operation = h.operation()
    let task = await h.start(operation, saying: "Reply with EchoType")
    guard case .failed(let text, .provider(.unavailable)) = await task.value.outcome else { Issue.record("Expected send failure"); return }
    #expect(text == "Reply with EchoType")
    #expect(h.insertions == [.init(text: "Reply with EchoType", sends: false)])
    #expect(h.points.count(.captureRelease) == 1)
  }

  @Test("Capture overflow releases a suspended send and preserves committed words")
  func captureOverflow() async {
    let h = Harness()
    let operation = h.operation()
    let task = await h.start(operation)
    h.points.hold(.audioSend)
    h.speak(Data([1]))
    await h.points.reached(.audioSend)
    operation.captureFailed(CaptureError("Audio capture backlog exceeded"))
    guard case .failed(let text, _) = await task.value.outcome else { Issue.record("Expected capture failure"); return }
    #expect(text == "spoken words" && h.insertions == [.init(text: "spoken words", sends: false)])
    #expect(h.points.count(.captureRelease) == 1)
  }

  @Test("An unrequested .finished or end of events while listening fails with the committed words",
    arguments: [false, true])
  func unrequestedEnd(disconnect: Bool) async {
    let h = Harness()
    let operation = h.operation()
    let task = await h.start(operation)
    if disconnect { h.transcriber.disconnect() } else { h.transcriber.emit(.finished) }
    guard case .failed(let text, .socket) = await task.value.outcome else { Issue.record("Expected closed"); return }
    #expect(text == "spoken words" && h.insertions == [.init(text: "spoken words", sends: false)])
    #expect(!h.transcriber.calls.contains("finish"))
  }

  @Test("Insertion targets the destination focused when finishing begins, not before or after", arguments: [true, false])
  func finishingDestinationIsFresh(available: Bool) async {
    let h = Harness()
    h.focusedDestination = destination()
    let operation = h.operation()
    let task = await h.start(operation)
    operation.microphoneReady() // The advisory probe sees the earlier focus.
    let atStop = available ? destination(target: 4) : nil
    let late = destination(target: 5)
    h.focusedDestination = atStop
    h.points.hold(.finish)
    operation.commit()
    await h.points.reached(.finish)
    h.focusedDestination = late
    h.points.release(.finish)
    _ = await task.value
    #expect(DestinationFocus(lookup: { atStop }).verify(h.insertedDestination) == (available ? .matching : .unavailable))
    #expect(DestinationFocus(lookup: { late }).verify(h.insertedDestination) == (available ? .changed : .unavailable))
  }

  // MARK: Revision and insertion

  @Test("Escape cancels through drain, closing and final revision", arguments: [Point.captureStop, .finish, .revision])
  func escapeWhileFinishing(at point: Point) async {
    let h = Harness()
    h.points.hold(point)
    let operation = h.operation(cleanup: true)
    let task = await h.start(operation)
    operation.commit()
    await h.points.reached(point)
    operation.cancel()
    let result = await task.value
    #expect(result.outcome == .nothing && h.insertions.isEmpty)
    #expect(result.trace?.outcome == .cancelled && result.trace?.finalText == "")
    #expect(h.points.count(.captureRelease) == 1)
  }

  @Test("Final revision deadline preserves available words")
  func finalRevisionDeadline() async {
    let h = Harness()
    h.points.hold(.revision)
    let operation = h.operation(cleanup: true)
    let task = await h.start(operation)
    operation.commit()
    await h.points.reached(.revision)
    await h.revisionClock.advance(Reviser.finalTimeout)
    #expect(await task.value.outcome == .insert("spoken words"))
    #expect(h.insertions == [.init(text: "spoken words", sends: false)])
  }

  @Test("Only an operation with a cleanup service revises; without one it inserts the committed text", arguments: [false, true])
  func cleanupService(cleanup: Bool) async {
    let h = Harness()
    let operation = h.operation(cleanup: cleanup)
    let task = await h.start(operation)
    operation.commit()
    let result = await task.value
    #expect(result.outcome == .insert("spoken words"))
    #expect(result.trace?.revisions.isEmpty == !cleanup)
    #expect(h.points.count(.revision) == (cleanup ? 1 : 0))
  }

  @Test("Escape wins before the clipboard boundary")
  func cancellationBeforeClipboard() async {
    let h = Harness()
    h.points.hold(.insertion)
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    await h.points.reached(.insertion)
    operation.cancel()
    h.points.release(.insertion)
    let result = await task.value
    #expect(result.outcome == .nothing && h.insertions.isEmpty)
    #expect(result.trace?.insertion == .cancelled)
  }

  @Test("Insertion owns completion after the clipboard boundary")
  func insertionOwnsCompletion() async {
    let h = Harness()
    h.points.hold(.clipboard)
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    await h.points.reached(.clipboard)
    #expect(!operation.canCancel)
    operation.cancel()
    h.points.release(.clipboard)
    let result = await task.value
    #expect(result.outcome == .insert("spoken words") && h.insertions == [.init(text: "spoken words", sends: false)])
    #expect(!operation.cancelled)
  }

  @Test("Destination recovery keeps available text in the trace")
  func recovery() async {
    let h = Harness()
    h.insertionResult = .init(insertion: .skipped(.changed), sending: .notRequested)
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    let result = await task.value
    #expect(result.trace?.finalText == "spoken words")
    #expect(result.trace?.insertion == .skipped(.changed))
  }

  // MARK: Test mode

  @Test("Test keeps its timer and ignores Escape without overlay, insertion or trace")
  func microphoneTest() async {
    let h = Harness()
    let operation = h.operation(test: true)
    let task = Task { await operation.run() }
    await h.points.reached(.captureStart)
    h.transcriber.emit(.ready)
    h.transcriber.say("test words")
    // The first binary send acknowledges that the operation installed its pump and Test timer.
    h.speak(Data([1]))
    await h.points.reached(.audioSend)
    operation.microphoneReady()
    await h.clock.advance(1)
    operation.microphoneReady()
    operation.cancel()
    #expect(!operation.cancelled)
    await h.testClock.advance(5)
    let result = await task.value
    #expect(result.outcome == .insert("test words"))
    #expect(result.trace == nil && h.insertions.isEmpty)
    #expect(h.points.count(.destination) == 0 && h.presented.isEmpty)
  }
}
