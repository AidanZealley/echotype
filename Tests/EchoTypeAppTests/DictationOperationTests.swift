import AppKit
import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Synchronization
import Testing

private final class Gate: Sendable {
  private let stream: AsyncStream<Void>
  private let release: AsyncStream<Void>.Continuation
  init() { (stream, release) = AsyncStream.makeStream() }
  func wait() async { for await _ in stream { break } }
  func open() { release.finish() }
}

private final class ManualClock: SessionClock, Sendable {
  private struct State {
    var now: TimeInterval = 0
    var action: (@Sendable () async -> Void)?
    var deadline: TimeInterval?
  }
  private let state = Mutex(State())
  var now: TimeInterval { state.withLock { $0.now } }
  func schedule(at deadline: TimeInterval, fire: @escaping @Sendable () async -> Void) {
    state.withLock { $0.deadline = deadline; $0.action = fire }
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

private final class OperationTransport: WebSocketTransport, Sendable {
  enum Mode: Sendable { case normal, binaryFailure, binaryStall, closingStall }
  let mode: Mode
  let sendEntered = Gate()
  let sendRelease = Gate()
  let closingEntered = Gate()
  private let incoming: AsyncThrowingStream<String, any Error>
  private let publisher: AsyncThrowingStream<String, any Error>.Continuation
  private let frames = Mutex<[String]>([])
  init(_ mode: Mode = .normal) {
    self.mode = mode
    (incoming, publisher) = AsyncThrowingStream.makeStream()
  }
  var sent: [String] { frames.withLock { $0 } }
  func emit(_ text: String) { publisher.yield(text) }
  func send(binary: Data) async throws {
    sendEntered.open()
    if mode == .binaryFailure { throw STTError.unavailable }
    if mode == .binaryStall { await sendRelease.wait(); try Task.checkCancellation() }
    frames.withLock { $0.append("audio") }
  }
  func send(text: String) async throws {
    closingEntered.open()
    if mode == .closingStall { await sendRelease.wait(); try Task.checkCancellation() }
    frames.withLock { $0.append(text) }
    if text.contains("audio.done") { emit(#"{"type":"transcript.done"}"#) }
  }
  func messages() -> AsyncThrowingStream<String, any Error> { incoming }
  func close() { sendRelease.open(); publisher.finish() }
}

@MainActor private final class Harness {
  let transport: OperationTransport
  let clock = ManualClock()
  let testClock = ManualClock()
  let revisionClock = ManualClock()
  let captureEntered = Gate()
  let captureRelease = Gate()
  let keyEntered = Gate()
  let keyRelease = Gate()
  let revisionEntered = Gate()
  let revisionRelease = Gate()
  let running = Gate()
  let paused = Gate()
  let wordsReceived = Gate()
  let finished = Gate()
  let drainEntered = Gate()
  let insertionEntered = Gate()
  let insertionRelease = Gate()
  let audio: AsyncThrowingStream<Data, any Error>
  let chunks: AsyncThrowingStream<Data, any Error>.Continuation
  var suspendCapture = false
  var suspendKey = false
  var suspendRevision = false
  var suspendDrain = false
  var suspendInsertion = false
  var tail: Data?
  var captures = 0
  var keys = 0
  var opened = 0
  var stopped = 0
  var released = 0
  var destinations = 0
  var focusedDestination: Destination?
  var insertedDestination: Destination?
  var insertions: [(String, Bool)] = []
  var presentations = 0
  var presented: [DictationOperation.Presentation] = []
  var insertionResult = Clipboard.InsertionResult(insertion: .attempted, sending: .notRequested)
  var beforeInsertion: (@MainActor () -> Void)?
  init(_ mode: OperationTransport.Mode = .normal) {
    transport = OperationTransport(mode)
    (audio, chunks) = AsyncThrowingStream.makeStream()
  }
  func operation(test: Bool = false, cleanup: Bool = false) -> DictationOperation {
    DictationOperation(settings: Settings(cleanUp: cleanup, sendReplyRequests: true), isTest: test,
      dependencies: .init(
        startCapture: { _ in
          self.captures += 1
          self.captureEntered.open()
          if self.suspendCapture { await self.captureRelease.wait() }
          return self.audio
        },
        stopCapture: {
          self.stopped += 1
          if let tail = self.tail { self.chunks.yield(tail); self.tail = nil }
          if !self.suspendDrain { self.chunks.finish() }
          self.drainEntered.open()
        },
        releaseCapture: { self.released += 1 },
        key: { [self] in
          await MainActor.run { keys += 1; keyEntered.open() }
          if await suspendKey { await keyRelease.wait() }
          return "fake-key"
        },
        transport: { _, _ in self.opened += 1; return self.transport },
        captureDestination: { self.destinations += 1; return self.focusedDestination },
        insert: { text, destination, sends, cancelled, begin in
          self.insertedDestination = destination
          self.beforeInsertion?()
          if cancelled() { return .init(insertion: .cancelled, sending: .notRequested) }
          if text.isEmpty { return .init(insertion: .notAttempted, sending: .notRequested) }
          begin()
          self.insertionEntered.open()
          if self.suspendInsertion { await self.insertionRelease.wait() }
          self.insertions.append((text, sends))
          return self.insertionResult
        },
        revise: { _ in
          Reviser(request: { $0 }, finalRequest: { [self] text in
            revisionEntered.open()
            if await suspendRevision { await revisionRelease.wait() }
            try Task.checkCancellation()
            return text
          }, finalClock: self.revisionClock)
        }, clock: clock, testClock: testClock),
      onPresentation: { phase, _, _ in
        self.presentations += 1
        self.presented.append(phase)
        if phase == .finishing { self.finished.open() }
        if case .capturing(let snapshot, _) = phase {
          self.running.open()
          if snapshot.state == .paused { self.paused.open() }
          if !snapshot.committed.isEmpty { self.wordsReceived.open() }
        }
      })
  }
  func start(_ operation: DictationOperation, words: String = "spoken words") async -> Task<DictationOperation.Result, Never> {
    let task = Task { await operation.run() }
    await running.wait()
    transport.emit(#"{"type":"transcript.created"}"#)
    transport.emit("{\"type\":\"transcript.partial\",\"text\":\"\(words)\",\"is_final\":true,\"speech_final\":true}")
    await wordsReceived.wait()
    return task
  }
  func close() {
    captureRelease.open(); keyRelease.open(); revisionRelease.open()
    insertionRelease.open(); chunks.finish(); transport.close()
  }
}

@Suite(.timeLimit(.minutes(1))) @MainActor
struct DictationOperationTests {
  private func destination(target: pid_t = 3) -> Destination {
    Destination(application: AXUIElementCreateApplication(1),
      window: AXUIElementCreateApplication(2), target: AXUIElementCreateApplication(target), pid: 1)
  }

  @Test("Destination readiness follows focus during silent buffers and cannot revive finishing")
  func destinationReadiness() async {
    let h = Harness()
    defer { h.close() }
    let operation = h.operation()
    let task = await h.start(operation)
    #expect(operation.presentation.pillPhase == .starting)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.destinations == 1)
    h.focusedDestination = destination()
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.destinations == 1)
    await h.clock.advance(0.5)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .listening)
    #expect(h.destinations == 2)
    await h.clock.advance(10)
    await h.paused.wait()
    #expect(operation.presentation.pillPhase == .paused)
    // Silent buffers keep reporting levels after the session pauses.
    h.focusedDestination = nil
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .selectInput)
    #expect(h.destinations == 3)
    operation.commit()
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .transcribing)
    #expect(h.destinations == 3)
    _ = await task.value
    #expect(h.destinations == 4 && h.captures == 1 && h.opened == 1)
  }

  @Test("Ready focus preserves microphone startup; cancellation stops advisory probes")
  func microphoneReadinessPrecedence() async {
    let h = Harness()
    defer { h.close() }
    h.focusedDestination = destination()
    h.suspendCapture = true
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.captureEntered.wait()
    #expect(operation.presentation.pillPhase == .starting)
    operation.microphoneReady()
    #expect(operation.presentation.pillPhase == .listening)
    operation.cancel()
    await h.clock.advance(1)
    operation.microphoneReady()
    #expect(operation.presentation == .cancelled && h.destinations == 1)
    h.captureRelease.open()
    _ = await task.value
  }

  @Test("Finishing captures a new destination instead of retaining advisory identity", arguments: [true, false])
  func finishingDestinationIsFresh(available: Bool) async {
    let h = Harness()
    defer { h.close() }
    let early = destination()
    let final = available ? destination(target: 4) : nil
    h.focusedDestination = early
    let operation = h.operation()
    let task = await h.start(operation)
    operation.microphoneReady()
    h.focusedDestination = final
    operation.commit()
    _ = await task.value
    let finalFocus = DestinationFocus(lookup: { final })
    let earlyFocus = DestinationFocus(lookup: { early })
    #expect(finalFocus.verify(h.insertedDestination) == (available ? .matching : .unavailable))
    #expect(earlyFocus.verify(h.insertedDestination) == (available ? .changed : .unavailable))
    #expect(h.destinations == 2 && h.insertions.count == 1)
  }

  @Test("Cancellation before run acquires no capture, key or socket")
  func cancelledBeforeRun() async {
    let h = Harness()
    defer { h.close() }
    let operation = h.operation()
    operation.cancel()
    let result = await operation.run()
    #expect(result.outcome == .nothing && result.startupFailure == nil && result.trace == nil)
    #expect(h.captures == 0 && h.keys == 0 && h.opened == 0)
    #expect(h.insertions.isEmpty && h.released == 1)
    #expect(h.presented == [.cancelled])
  }

  @Test("Deferred clipboard cleanup cannot revive cancelled startup presentation")
  func cancelledDuringCleanup() async {
    let h = Harness()
    defer { h.close() }
    let cleanupEntered = Gate()
    let cleanupRelease = Gate()
    let operation = h.operation()
    // The coordinator retains the operation while the previous clipboard owner cleans up.
    // Startup presentation now comes from run, so resuming this wait cannot create a pill.
    let task = Task {
      cleanupEntered.open()
      await cleanupRelease.wait()
      return await operation.run()
    }
    await cleanupEntered.wait()
    operation.cancel()
    #expect(h.presented == [.cancelled])
    cleanupRelease.open()
    let result = await task.value
    #expect(result.outcome == .nothing && result.startupFailure == nil && result.trace == nil)
    #expect(h.captures == 0 && h.keys == 0 && h.opened == 0 && h.released == 1)
    #expect(h.insertions.isEmpty && h.presented == [.cancelled])
  }

  @Test("Capture failure during key setup prevents a later socket open")
  func captureFailureDuringStartup() async {
    let h = Harness()
    defer { h.close() }
    h.suspendKey = true
    let operation = h.operation()
    let task = Task { await operation.run() }
    await h.keyEntered.wait()
    operation.captureFailed(CaptureError("Microphone stopped"))
    h.keyRelease.open()
    let result = await task.value
    guard case .failed = result.outcome else { Issue.record("Expected startup failure"); return }
    #expect(h.opened == 0 && h.insertions.isEmpty && h.released == 1)
    #expect(result.startupFailure != nil && result.trace == nil)
  }

  @Test("Cancellation during capture or key setup never opens a socket", arguments: [false, true])
  func cancelledStartup(key: Bool) async {
    let h = Harness()
    defer { h.close() }
    h.suspendCapture = !key
    h.suspendKey = key
    let operation = h.operation()
    let task = Task { await operation.run() }
    if key { await h.keyEntered.wait() } else { await h.captureEntered.wait() }
    operation.cancel()
    h.captureRelease.open(); h.keyRelease.open()
    let result = await task.value
    #expect(result.outcome == .nothing)
    #expect(h.opened == 0 && h.insertions.isEmpty && h.released == 1)
    #expect(result.trace == nil)
  }

  @Test("One operation drains audio before closing and inserts once")
  func orderedCompletion() async {
    let h = Harness(.binaryStall)
    defer { h.close() }
    let operation = h.operation()
    let task = await h.start(operation)
    h.chunks.yield(Data([1]))
    await h.transport.sendEntered.wait()
    operation.commit(); operation.commit()
    await h.finished.wait()
    #expect(h.transport.sent.isEmpty)
    h.transport.sendRelease.open()
    let result = await task.value
    #expect(result.outcome == .insert("spoken words"))
    #expect(h.transport.sent == ["audio", #"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])
    #expect(h.insertions.count == 1 && h.destinations == 2 && h.released == 1)
    #expect(result.trace?.insertion == .attempted)
  }

  @Test("Binary failure preserves committed words and never automatically sends")
  func binaryFailure() async {
    let h = Harness(.binaryFailure)
    defer { h.close() }
    let operation = h.operation()
    h.tail = Data([1])
    let task = await h.start(operation, words: "Reply with EchoType")
    let result = await task.value
    guard case .failed(let text, .stt(.unavailable)) = result.outcome else { Issue.record("Expected send failure"); return }
    #expect(text == "Reply with EchoType")
    #expect(h.insertions.count == 1 && h.insertions[0].1 == false)
    #expect(h.destinations == 2)
  }

  @Test("Finishing budget covers a stalled binary or closing send", arguments: [false, true])
  func stalledSends(closing: Bool) async {
    let h = Harness(closing ? .closingStall : .binaryStall)
    defer { h.close() }
    let operation = h.operation()
    let task = await h.start(operation)
    if !closing { h.chunks.yield(Data([1])); await h.transport.sendEntered.wait() }
    operation.commit()
    // SessionMachine arms the finishing deadline before requesting capture drain.
    await h.drainEntered.wait()
    if closing { await h.transport.closingEntered.wait() }
    await h.clock.advance(8)
    let result = await task.value
    guard case .failed(let text, _) = result.outcome else { Issue.record("Expected timeout"); return }
    #expect(text == "spoken words" && h.released == 1)
    #expect(h.insertions.first?.1 == false)
  }

  @Test("Capture overflow releases a suspended send and preserves committed words")
  func captureFailureWhileSending() async {
    let h = Harness(.binaryStall)
    defer { h.close() }
    let operation = h.operation()
    let task = await h.start(operation)
    h.chunks.yield(Data([1]))
    await h.transport.sendEntered.wait()
    operation.captureFailed(CaptureError("Audio capture backlog exceeded"))
    guard case .failed(let text, _) = await task.value.outcome else { Issue.record("Expected capture failure"); return }
    #expect(text == "spoken words" && h.released == 1)
    #expect(h.insertions.first?.1 == false)
  }

  @Test("A stalled capture drain terminates within the finishing budget")
  func stalledDrain() async {
    let h = Harness()
    defer { h.close() }
    h.suspendDrain = true
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    await h.drainEntered.wait()
    await h.clock.advance(8)
    guard case .failed(let text, _) = await task.value.outcome else { Issue.record("Expected drain timeout"); return }
    #expect(text == "spoken words" && h.released == 1)
  }

  @Test("Hard cap flushes the final capture chunk before protocol closure")
  func hardCapFlushesTail() async {
    let h = Harness()
    defer { h.close() }
    h.tail = Data([1])
    let operation = h.operation()
    let task = await h.start(operation)
    await h.clock.advance(300)
    #expect(await task.value.outcome == .insert("spoken words"))
    #expect(h.transport.sent == ["audio", #"{"type":"finalize"}"#, #"{"type":"audio.done"}"#])
  }

  @Test("Escape cancels finalisation and final revision", arguments: [false, true])
  func escapeWhileFinishing(revision: Bool) async {
    let h = Harness(revision ? .normal : .closingStall)
    defer { h.close() }
    h.suspendRevision = revision
    let operation = h.operation(cleanup: revision)
    let task = await h.start(operation)
    operation.commit()
    if revision { await h.revisionEntered.wait() } else { await h.transport.closingEntered.wait() }
    operation.cancel()
    let result = await task.value
    #expect(result.outcome == .nothing && h.insertions.isEmpty)
    #expect(result.trace?.outcome == .cancelled && result.trace?.finalText == "")
  }

  @Test("Final revision deadline preserves available words")
  func finalRevisionDeadline() async {
    let h = Harness()
    defer { h.close() }
    h.suspendRevision = true
    let operation = h.operation(cleanup: true)
    let task = await h.start(operation)
    operation.commit()
    await h.revisionEntered.wait()
    await h.revisionClock.advance(Reviser.finalTimeout)
    let result = await task.value
    #expect(result.outcome == .insert("spoken words"))
    #expect(h.insertions.first?.0 == "spoken words")
  }

  @Test("Cancellation wins at the insertion boundary after queued success")
  func cancellationAtBoundary() async {
    let h = Harness()
    defer { h.close() }
    let operation = h.operation()
    h.beforeInsertion = { operation.cancel() }
    let task = await h.start(operation)
    operation.commit()
    let result = await task.value
    #expect(result.outcome == .nothing && h.insertions.isEmpty)
    #expect(result.trace?.insertion == .cancelled)
  }

  @Test("Insertion owns completion after its boundary")
  func insertionCannotBeCancelled() async {
    let h = Harness()
    defer { h.close() }
    h.suspendInsertion = true
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    await h.insertionEntered.wait()
    #expect(!operation.canCancel)
    operation.cancel()
    h.insertionRelease.open()
    let result = await task.value
    #expect(result.outcome == .insert("spoken words") && h.insertions.count == 1)
    #expect(!operation.cancelled)
  }

  @Test("Destination recovery keeps available text in the trace")
  func recovery() async {
    let h = Harness()
    defer { h.close() }
    h.insertionResult = .init(insertion: .skipped(.changed), sending: .notRequested)
    let operation = h.operation()
    let task = await h.start(operation)
    operation.commit()
    let result = await task.value
    #expect(result.trace?.finalText == "spoken words")
    #expect(result.trace?.insertion == .skipped(.changed))
  }

  @Test("Test keeps its timer and ignores Escape without overlay, insertion or trace")
  func microphoneTest() async {
    let h = Harness()
    defer { h.close() }
    let operation = h.operation(test: true)
    let task = Task { await operation.run() }
    await h.captureEntered.wait()
    h.transport.emit(#"{"type":"transcript.created"}"#)
    h.transport.emit(#"{"type":"transcript.partial","text":"test words","is_final":true,"speech_final":true}"#)
    // The first binary send acknowledges that the operation installed its pump and Test timer.
    h.chunks.yield(Data([1]))
    await h.transport.sendEntered.wait()
    operation.microphoneReady()
    await h.clock.advance(1)
    operation.microphoneReady()
    #expect(h.destinations == 0 && h.presentations == 0)
    operation.cancel()
    #expect(!operation.cancelled)
    await h.testClock.advance(5)
    let result = await task.value
    #expect(result.outcome == .insert("test words"))
    #expect(result.trace == nil && h.insertions.isEmpty && h.destinations == 0 && h.presentations == 0)
  }
}
