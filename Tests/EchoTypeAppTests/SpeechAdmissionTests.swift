import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Testing

private final class AdmissionGate: Sendable {
  private let stream: AsyncStream<Void>
  private let release: AsyncStream<Void>.Continuation
  init() { (stream, release) = AsyncStream.makeStream() }
  func wait() async { for await _ in stream { break } }
  func open() { release.finish() }
}

private final class AdmissionTransport: WebSocketTransport, Sendable {
  let incoming: AsyncThrowingStream<String, any Error>
  let publisher: AsyncThrowingStream<String, any Error>.Continuation
  let opened = AdmissionGate()
  init() { (incoming, publisher) = AsyncThrowingStream.makeStream() }
  func send(binary: Data) async throws {}
  func send(text: String) async throws {
    if text.contains("audio.done") { publisher.yield(#"{"type":"transcript.done"}"#) }
  }
  func messages() -> AsyncThrowingStream<String, any Error> { opened.open(); return incoming }
  func close() { publisher.finish() }
}

@MainActor private final class AdmissionFixture {
  let captureEntered = AdmissionGate(), captureRelease = AdmissionGate()
  let revisionEntered = AdmissionGate(), revisionRelease = AdmissionGate()
  let insertionEntered = AdmissionGate(), insertionRelease = AdmissionGate()
  let transport = AdmissionTransport()
  let audio: AsyncThrowingStream<Data, any Error>
  let chunks: AsyncThrowingStream<Data, any Error>.Continuation
  let wordsReceived = AdmissionGate()
  let testCaptureEntered = AdmissionGate(), testCaptureRelease = AdmissionGate()
  var insertions = 0
  var operation: DictationOperation?
  var readers: [Reader] = []
  let readingEntered = AdmissionGate(), readingRelease = AdmissionGate()
  var controller: DictationController!
  init() {
    (audio, chunks) = AsyncThrowingStream.makeStream()
    controller = DictationController(store: SettingsStore(),
    clipboard: Clipboard(access: .init(count: { 0 }, save: { [] }, restore: { _ in }, read: { nil },
      write: { _ in }, post: { _, _ in }, wait: { _ in })),
    makeReader: { source, id, settings, present, _ in
      let reader = Reader(source, id: id, settings: settings, dependencies: .init(
        selection: { _ in nil }, cleanup: {}, key: {
          self.readingEntered.open(); await self.readingRelease.wait(); return nil
        }, request: { _ in fatalError("No network expected") }, player: SpeechPlayer(onLevel: { _ in })), onPresentation: present)
      self.readers.append(reader); return reader
    }, focusedScreen: { nil }, showPanel: { _, _ in }, hidePanel: {},
    makeDictation: { test in
      let operation = DictationOperation(settings: Settings(cleanUp: true), isTest: test, dependencies: .init(
        startCapture: { _ in
          self.captureEntered.open()
          if test {
            self.testCaptureEntered.open(); await self.testCaptureRelease.wait()
          } else { await self.captureRelease.wait() }
          return self.audio
        },
        stopCapture: { self.chunks.finish() }, releaseCapture: {}, key: { "fake" },
        transport: { _, _ in self.transport }, captureDestination: { nil },
        insert: { _, _, _, _, begin in
          self.insertions += 1
          begin(); self.insertionEntered.open(); await self.insertionRelease.wait()
          return .init(insertion: .attempted, sending: .notRequested)
        }, revise: { _ in Reviser(request: { $0 }, finalRequest: { text in
          self.revisionEntered.open(); await self.revisionRelease.wait(); return text
        }) }, clock: SystemClock(), testClock: SystemClock()), onPresentation: { _, settled, _ in
          if settled == "Hello" { self.wordsReceived.open() }
        })
      self.operation = operation
      return operation
    })
  }
  func release() {
    captureRelease.open(); testCaptureRelease.open()
    revisionRelease.open(); insertionRelease.open(); readingRelease.open()
    chunks.finish(); transport.close()
    operation?.cancel()
    _ = controller.escapePressed()
  }
  func admit() -> String? {
    let request = SpeechDelivery.Request(id: UUID(), target: 42,
      expiry: 15, text: "Hello")
    return SpeechAdmission.receive(.init(request.fields), pid: 42, now: 10,
      admit: controller.speak)?["outcome"] as? String
  }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct SpeechAdmissionTests {
  @Test func idleStartupAndPausedReadingReserveReplacementImmediately() async {
    let fixture = AdmissionFixture()
    defer { fixture.release() }
    #expect(fixture.admit() == "accepted")
    #expect(fixture.controller.state == .starting && fixture.readers.count == 1)
    await fixture.readingEntered.wait()
    #expect(fixture.admit() == "accepted")
    #expect(fixture.readers.count == 2 && fixture.readers[0].presentation == .stopped)
    #expect(fixture.controller.spacePressed(repeated: false))
    #expect(fixture.controller.state == .paused)
    #expect(fixture.admit() == "accepted")
    #expect(fixture.readers.count == 3 && fixture.readers[1].presentation == .stopped)
    #expect(fixture.controller.state == .starting)
    #expect(fixture.controller.escapePressed())
    fixture.readingRelease.open()
    await fixture.controller.waitForCompletion()
    #expect(fixture.controller.isIdle)
  }

  @Test func dictationRemainsBusyThroughStartupFinalRevisionAndInsertion() async throws {
    let fixture = AdmissionFixture()
    defer { fixture.release() }
    fixture.controller.hotkeyPressed()
    await fixture.captureEntered.wait()
    let operation = try #require(fixture.operation)
    #expect(fixture.admit() == "busy" && !operation.cancelled)
    fixture.captureRelease.open()
    await fixture.transport.opened.wait()
    fixture.transport.publisher.yield(#"{"type":"transcript.created"}"#)
    fixture.transport.publisher.yield(#"{"type":"transcript.partial","text":"Hello","is_final":true,"speech_final":true}"#)
    // Admission is busy before capture readiness and throughout the same operation's finish.
    #expect(fixture.admit() == "busy")
    await fixture.wordsReceived.wait()
    operation.commit()
    await fixture.revisionEntered.wait()
    #expect(fixture.controller.state == .finishing)
    #expect(fixture.admit() == "busy" && !operation.cancelled)
    fixture.revisionRelease.open()
    await fixture.insertionEntered.wait()
    #expect(fixture.controller.state == .inserting)
    #expect(fixture.admit() == "busy" && !operation.cancelled)
    fixture.insertionRelease.open()
    await fixture.controller.waitForCompletion()
    #expect(fixture.readers.isEmpty && fixture.controller.isIdle)
  }

  @Test func microphoneTestIsBusyAndUntouched() async throws {
    let fixture = AdmissionFixture()
    defer { fixture.release() }
    let task = Task { await fixture.controller.test() }
    await fixture.captureEntered.wait()
    let operation = try #require(fixture.operation)
    #expect(operation.isTest)
    #expect(fixture.admit() == "busy" && !operation.cancelled)
    // Finish the fake Test through capture failure, without real capture or waiting five seconds.
    operation.captureFailed(STTError.unavailable)
    fixture.testCaptureRelease.open()
    _ = await task.value
    #expect(fixture.readers.isEmpty && fixture.controller.isIdle && fixture.controller.lastTrace == nil)
  }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct CoordinatorTests {
  @Test func microphoneTestRetainsLastDictationAndIgnoresCommands() async throws {
    let fixture = AdmissionFixture()
    defer { fixture.release() }
    let controller = fixture.controller!
    controller.hotkeyPressed()
    await fixture.captureEntered.wait()
    fixture.captureRelease.open()
    await fixture.transport.opened.wait()
    fixture.transport.publisher.yield(#"{"type":"transcript.created"}"#)
    fixture.transport.publisher.yield(#"{"type":"transcript.partial","text":"Hello","is_final":true,"speech_final":true}"#)
    await fixture.wordsReceived.wait()
    controller.hotkeyPressed()
    await fixture.revisionEntered.wait()
    fixture.revisionRelease.open()
    await fixture.insertionEntered.wait()
    fixture.insertionRelease.open()
    await controller.waitForCompletion()
    let trace = try #require(controller.lastTrace)
    #expect(trace.finalText == "Hello" && fixture.insertions == 1)

    let task = Task { await controller.test() }
    await fixture.testCaptureEntered.wait()
    let operation = try #require(fixture.operation)
    #expect(operation.isTest && !controller.isIdle)
    controller.hotkeyPressed()
    controller.readAloudPressed()
    #expect(!controller.escapePressed() && !controller.spacePressed(repeated: false))
    #expect(!controller.speak("Ignored") && !operation.cancelled)
    #expect(await controller.test() == nil)
    operation.captureFailed(STTError.unavailable)
    fixture.testCaptureRelease.open()
    _ = await task.value
    #expect(controller.isIdle && fixture.readers.isEmpty && fixture.insertions == 1)
    #expect(controller.lastTrace == trace)
  }
}
