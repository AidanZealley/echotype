import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Synchronization
import Testing

private final class FakeSpeechRequest: ReadingRequest, Sendable {
  private struct State {
    var data: [Data]
    var pending: CheckedContinuation<Data?, any Error>?
    var cancelled = false
    var finished = false
  }
  private let state: Mutex<State>
  let entered = ReadingGate()
  init(_ data: [Data] = [], finished: Bool = false) { state = Mutex(State(data: data, finished: finished)) }
  func next() async throws -> Data? {
    entered.open()
    return try await withCheckedThrowingContinuation { continuation in
      state.withLock {
        if $0.cancelled { continuation.resume(throwing: CancellationError()) }
        else if !$0.data.isEmpty { continuation.resume(returning: $0.data.removeFirst()) }
        else if $0.finished { continuation.resume(returning: nil) }
        else { $0.pending = continuation }
      }
    }
  }
  func cancel() {
    state.withLock { $0.cancelled = true; $0.pending?.resume(throwing: CancellationError()); $0.pending = nil }
  }
}

@MainActor private final class ReadingFixture {
  let playback = PlaybackFixture()
  let request: FakeSpeechRequest
  let selectionEntered = ReadingGate()
  let selectionRelease = ReadingGate()
  let keyEntered = ReadingGate()
  let keyRelease = ReadingGate()
  let scheduled = ReadingGate()
  var suspendSelection = false
  var suspendKey = false
  var selection: String? = "Selected text"
  var requests: [URLRequest] = []
  let cleanupEntered = ReadingGate()
  let cleanupRelease = ReadingGate()
  var suspendCleanup = false
  var cleanup = 0
  var keys = 0
  init(_ request: FakeSpeechRequest = FakeSpeechRequest()) { self.request = request }
  func reader(_ source: Reader.Source = .text("Hello"), id: UUID = UUID(),
    settings: Settings = Settings(), onPresentation: @escaping @MainActor (Reader) -> Void = { _ in }
  ) -> Reader {
    playback.onSchedule = { self.scheduled.open() }
    return Reader(source, id: id, settings: settings, dependencies: .init(
      selection: { _ in
        self.selectionEntered.open()
        if self.suspendSelection { await self.selectionRelease.wait() }
        return self.selection
      }, cleanup: {
        self.cleanup += 1; self.cleanupEntered.open()
        if self.suspendCleanup { await self.cleanupRelease.wait() }
      }, key: {
        self.keys += 1; self.keyEntered.open()
        if self.suspendKey { await self.keyRelease.wait() }
        return "fake"
      }, request: { self.requests.append($0); return self.request }, player: playback.player), onPresentation: onPresentation)
  }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct ReadingOperationTests {
  @Test func creationDoesNotAcquireResourcesAndStopDuringCopyJoinsCleanup() async {
    let fixture = ReadingFixture(); fixture.suspendSelection = true
    let reader = fixture.reader(.selection)
    #expect(fixture.keys == 0 && fixture.requests.isEmpty)
    #expect(reader.presentation == .starting)
    let task = Task { await reader.run() }
    await fixture.selectionEntered.wait(); reader.stop(); reader.stop()
    fixture.selectionRelease.open()
    #expect(await task.value == nil)
    #expect(fixture.keys == 0 && fixture.cleanup == 1)
  }

  @Test func stopDuringKeyDoesNotOpenRequest() async {
    let fixture = ReadingFixture(); fixture.suspendKey = true
    let reader = fixture.reader(); let task = Task { await reader.run() }
    await fixture.keyEntered.wait(); reader.stop(); fixture.keyRelease.open()
    #expect(await task.value == nil)
    #expect(fixture.requests.isEmpty)
  }

  @Test func stopDuringRequestResolvesAndClearsLevels() async {
    let fixture = ReadingFixture(); let reader = fixture.reader()
    let task = Task { await reader.run() }
    await fixture.request.entered.wait(); reader.stop()
    #expect(await task.value == nil)
    reader.receiveLevel(1)
    #expect(reader.level == 0 && reader.presentation == .stopped)
  }

  @Test func startupPauseSurvivesFirstAudioAndPausedStopResolvesCompletion() async {
    let request = FakeSpeechRequest([Data([0, 0, 1, 0])], finished: true)
    let fixture = ReadingFixture(request); let reader = fixture.reader()
    reader.togglePause()
    #expect(reader.presentation == .paused)
    let task = Task { await reader.run() }
    await fixture.scheduled.wait()
    #expect(fixture.playback.pauses == 1 && reader.presentation == .paused)
    reader.stop()
    #expect(await task.value == nil)
    #expect(fixture.playback.player.queuedFrames == 0)
  }

  @Test func emptySelectionFailsVisiblyBeforeKeyOrRequest() async {
    let fixture = ReadingFixture(); fixture.selection = nil
    let reader = fixture.reader(.selection)
    #expect(await reader.run() is Reader.Failure)
    if case .failed = reader.presentation {} else { Issue.record("Failure presentation missing") }
    #expect(fixture.keys == 0 && fixture.requests.isEmpty && fixture.cleanup == 1)
  }

  @Test func fasterThanPlaybackResponseStopsAtQueueLimit() async {
    let request = FakeSpeechRequest([Data(repeating: 0, count: Speech.sampleRate * 2)])
    let fixture = ReadingFixture(request); let reader = fixture.reader()
    let full = ReadingGate()
    fixture.playback.onSchedule = { if fixture.playback.scheduled == 5 { full.open() } }
    let task = Task { await reader.run() }
    await full.wait()
    #expect(fixture.playback.player.queuedFrames == SpeechPlayer.maximumQueuedFrames)
    reader.togglePause(); reader.stop()
    #expect(await task.value == nil)
    #expect(fixture.playback.scheduled == 5)
  }
}


@MainActor private final class ReadingCoordinatorFixture {
  let first: ReadingFixture
  let next = ReadingFixture()
  let third = ReadingFixture()
  var readers: [Reader] = []
  var levels: [@MainActor (Double) -> Void] = []
  var presentations: [Pill] = []
  var visiblePill: Pill?
  var hides = 0
  let clipboard = Clipboard(access: .init(count: { 0 }, save: { [] }, restore: { _ in },
    read: { nil }, write: { _ in }, post: { _, _ in }, wait: { _ in }))
  init(first: ReadingFixture) { self.first = first }
  lazy var controller = DictationController(store: SettingsStore(), clipboard: clipboard,
    makeReader: { source, id, settings, present, level in
      let fixture = self.readers.isEmpty ? self.first : self.readers.count == 1 ? self.next : self.third
      let reader = fixture.reader(source, id: id, settings: settings, onPresentation: present)
      self.readers.append(reader); self.levels.append(level)
      return reader
    }, focusedScreen: { nil }, showPanel: { pill, _ in
      self.presentations.append(pill); self.visiblePill = pill
    }, hidePanel: { self.visiblePill = nil; self.hides += 1 })
}

extension ReadingOperationTests {
  enum Boundary: CaseIterable { case selection, request, playing, paused, completion }

  @Test(arguments: Boundary.allCases)
  func replacementReservesThenJoinsCleanupAndRejectsOldCallbacks(_ boundary: Boundary) async {
    let audio = boundary == .playing || boundary == .paused || boundary == .completion
    let first = ReadingFixture(FakeSpeechRequest(audio ? [Data([0, 0])] : [], finished: boundary == .completion))
    first.suspendSelection = boundary == .selection
    first.suspendCleanup = true
    let fixture = ReadingCoordinatorFixture(first: first)
    let controller = fixture.controller
    if boundary == .selection { controller.readAloudPressed(); await first.selectionEntered.wait() }
    else { controller.speak("First"); await first.request.entered.wait() }
    if audio { await first.scheduled.wait() }
    if boundary == .paused { #expect(controller.spacePressed(repeated: false)) }
    if boundary == .completion {
      first.playback.callbacks[0]()
      await first.cleanupEntered.wait()
    }
    #expect(controller.speak("Replacement"))
    #expect(fixture.readers.count == 2 && !controller.isIdle)
    #expect(controller.state == .starting)
    #expect(fixture.next.keys == 0)
    fixture.levels[0](1)
    fixture.readers[0].receiveLevel(1)
    first.selectionRelease.open()
    await first.cleanupEntered.wait()
    #expect(fixture.next.keys == 0)
    first.cleanupRelease.open()
    await fixture.next.request.entered.wait()
    #expect(fixture.presentations.last?.phase == .readingStarting)
    #expect(fixture.presentations.last?.level == 0 && fixture.readers[1].pausedAt == nil)
    controller.readAloudPressed()
    await controller.waitForCompletion()
    #expect(controller.isIdle && fixture.next.cleanup == 1)
    #expect(controller.lastTrace == nil)
  }

  @Test(arguments: [false, true])
  func startupSpaceRepeatsAndDictationTakeoverDuringCopy(_ playing: Bool) async {
    let first = ReadingFixture(FakeSpeechRequest(playing ? [Data([0, 0])] : [], finished: playing))
    first.suspendSelection = !playing; first.suspendCleanup = true
    let fixture = ReadingCoordinatorFixture(first: first)
    let controller = fixture.controller
    controller.readAloudPressed()
    #expect(controller.state == .starting)
    #expect(controller.spacePressed(repeated: false))
    #expect(controller.spacePressed(repeated: true))
    #expect(controller.spacePressed(repeated: true))
    #expect(controller.state == .paused)
    await first.selectionEntered.wait()
    if playing {
      await first.scheduled.wait()
      #expect(controller.spacePressed(repeated: false))
      fixture.levels[0](0.8)
      #expect(fixture.visiblePill?.phase == .reading && fixture.visiblePill?.level == 0.8)
    } else {
      #expect(fixture.visiblePill?.phase == .readingPaused)
    }
    let hides = fixture.hides
    controller.hotkeyPressed()
    #expect(controller.state == .starting && !controller.isIdle)
    #expect(fixture.hides == hides + 1 && fixture.visiblePill == nil)
    #expect(!controller.spacePressed(repeated: false))
    #expect(!controller.speak("Busy"))
    controller.readAloudPressed()
    #expect(fixture.readers.count == 1)
    first.selectionRelease.open()
    await first.cleanupEntered.wait()
    // The outgoing level and reading hints stay absent while dictation waits for cleanup.
    fixture.levels[0](1)
    fixture.readers[0].receiveLevel(1)
    #expect(fixture.visiblePill == nil && fixture.hides == hides + 1)
    #expect(first.playback.player.queuedFrames == 0 && !controller.isIdle)
    // Cancel the reserved dictation before releasing cleanup, so the real operation never
    // opens capture, reads a key or probes focus in this coordinator test.
    #expect(controller.escapePressed())
    first.cleanupRelease.open()
    await controller.waitForCompletion()
    #expect(controller.isIdle && first.keys == (playing ? 1 : 0) && controller.lastTrace == nil)
    #expect(!controller.spacePressed(repeated: false) && !controller.escapePressed())
  }

  @Test func taskCancellationWhileAwaitingPlaybackStopsResources() async {
    let fixture = ReadingFixture(FakeSpeechRequest([Data([0, 0])], finished: true))
    let reader = fixture.reader()
    let task = Task { await reader.run() }
    await fixture.scheduled.wait()
    task.cancel()
    #expect(await task.value == nil)
    #expect(fixture.playback.player.queuedFrames == 0 && fixture.cleanup == 1)
  }
}

/// Holds URLSession open without a socket. Tests drive its delegate with deterministic data,
/// including a framework callback larger than the application queue.
private final class SilentSpeechProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {}
  override func stopLoading() {}
}

extension ReadingOperationTests {
  private func requestFixture() -> (SpeechRequest, URLSession, URLSessionDataTask) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SilentSpeechProtocol.self]
    let request = URLRequest(url: URL(string: "https://speech.invalid")!)
    let session = URLSession(configuration: configuration)
    return (SpeechRequest(request, configuration: configuration), session, session.dataTask(with: request))
  }

  @Test func largeResponseCallbackDeliversBoundedChunksInOrder() async throws {
    let (request, session, task) = requestFixture()
    defer { request.cancel(); session.invalidateAndCancel() }
    let data = Data((0..<(SpeechRequest.maximumBufferedBytes * 3 + 17)).map { UInt8($0 % 251) })
    let producer = Task.detached {
      request.urlSession(session, dataTask: task, didReceive: data)
      request.urlSession(session, task: task, didCompleteWithError: nil)
    }
    var received = Data()
    while let chunk = try await request.next() {
      #expect(chunk.count <= SpeechRequest.chunkBytes)
      received.append(chunk)
    }
    await producer.value
    #expect(received == data)
  }

  @Test func stopReleasesResponseCallbackWaitingForQueueCapacity() async {
    let (request, session, task) = requestFixture()
    defer { request.cancel(); session.invalidateAndCancel() }
    request.urlSession(session, dataTask: task,
      didReceive: Data(repeating: 0, count: SpeechRequest.maximumBufferedBytes))
    let entered = ReadingGate()
    let producer = Task.detached {
      entered.open()
      request.urlSession(session, dataTask: task, didReceive: Data([1]))
    }
    await entered.wait()
    request.cancel()
    await producer.value
    do { _ = try await request.next(); Issue.record("Stop retained queued bytes") }
    catch is CancellationError {} catch { Issue.record(error) }
  }

  @Test func responseQueuePreservesChunksAndEOF() async throws {
    let (request, session, task) = requestFixture()
    defer { request.cancel(); session.invalidateAndCancel() }
    request.urlSession(session, dataTask: task, didReceive: Data([1]))
    request.urlSession(session, dataTask: task, didReceive: Data([2, 3]))
    request.urlSession(session, task: task, didCompleteWithError: nil)
    #expect(try await request.next() == Data([1]))
    #expect(try await request.next() == Data([2, 3]))
    #expect(try await request.next() == nil)
  }

  @Test func nonSuccessStatusAndNetworkFailureReachReadingOutcome() async {
    for code: URLError.Code? in [nil, .networkConnectionLost, .timedOut] {
      let (request, session, task) = requestFixture()
      defer { request.cancel(); session.invalidateAndCancel() }
      if let code {
        request.urlSession(session, task: task, didCompleteWithError: URLError(code))
      } else {
        let response = HTTPURLResponse(url: task.originalRequest!.url!, statusCode: 429,
          httpVersion: nil, headerFields: nil)!
        request.urlSession(session, dataTask: task, didReceive: response) { _ in }
      }
      let playback = PlaybackFixture()
      let reader = Reader(.text("Hello"), settings: Settings(), dependencies: .init(
        selection: { _ in nil }, cleanup: {}, key: { "fake" }, request: { _ in request }, player: playback.player))
      let failure = await reader.run()
      if let code { #expect((failure as? URLError)?.code == code) }
      else { #expect(failure as? STTError == .rateLimited) }
      if case .failed = reader.presentation {} else { Issue.record("Missing failure presentation") }
      #expect(playback.started == 0)
    }
  }

  @Test func cancellingAnEmptyResponseQueueResolvesItsAwait() async {
    let (request, session, _) = requestFixture()
    defer { request.cancel(); session.invalidateAndCancel() }
    let next = Task { try await request.next() }
    next.cancel()
    do { _ = try await next.value; Issue.record("Cancelled request succeeded") }
    catch is CancellationError {} catch { Issue.record(error) }
  }
}


extension ReadingOperationTests {
  @Test func backToBackReplacementsKeepTheOriginalCleanupJoin() async {
    let first = ReadingFixture(); first.suspendSelection = true; first.suspendCleanup = true
    let fixture = ReadingCoordinatorFixture(first: first)
    let controller = fixture.controller
    controller.readAloudPressed()
    await first.selectionEntered.wait()
    controller.speak("Second")
    controller.speak("Third")
    #expect(fixture.readers.count == 3)
    first.selectionRelease.open()
    await first.cleanupEntered.wait()
    #expect(fixture.next.keys == 0 && fixture.third.keys == 0)
    first.cleanupRelease.open()
    await fixture.third.request.entered.wait()
    #expect(fixture.next.keys == 0 && fixture.third.keys == 1)
    #expect(fixture.readers[1].presentation == .stopped)
    controller.readAloudPressed()
    await controller.waitForCompletion()
    #expect(controller.isIdle)
  }
}

extension ReadingOperationTests {
  @Test func selectionFailureReachesTheCoordinatorErrorPath() async {
    let first = ReadingFixture(); first.selection = nil
    let fixture = ReadingCoordinatorFixture(first: first)
    let controller = fixture.controller
    controller.readAloudPressed()
    await controller.waitForCompletion()
    #expect(controller.isIdle && controller.lastError == "Nothing selected")
    #expect(fixture.presentations.last?.phase == .error("Nothing selected"))
    #expect(controller.lastTrace == nil && first.requests.isEmpty)
  }
}

extension ReadingOperationTests {
  @Test func stopDuringFailureCleanupDoesNotReviveAnError() async {
    let fixture = ReadingFixture(); fixture.selection = nil; fixture.suspendCleanup = true
    let reader = fixture.reader(.selection)
    let task = Task { await reader.run() }
    await fixture.cleanupEntered.wait()
    reader.stop()
    fixture.cleanupRelease.open()
    #expect(await task.value == nil && reader.presentation == .stopped)
  }
}
