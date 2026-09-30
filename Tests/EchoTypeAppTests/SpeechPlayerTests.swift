import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Testing

final class ReadingGate: Sendable {
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation
  init() { (stream, continuation) = AsyncStream.makeStream() }
  func wait() async { for await _ in stream { break } }
  func open() { continuation.finish() }
}

@MainActor final class PlaybackFixture {
  var callbacks: [@Sendable () -> Void] = []
  var started = 0
  var stops = 0
  var pauses = 0
  var resumes = 0
  var scheduled = 0
  var onSchedule: () -> Void = {}
  lazy var player = SpeechPlayer(output: .init(
    start: { self.started += 1 }, pause: { self.pauses += 1 }, resume: { self.resumes += 1 },
    schedule: { _, done in self.callbacks.append(done); self.scheduled += 1; self.onSchedule() },
    stop: { self.stops += 1 }))
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct SpeechPlayerTests {
  @Test func pausedQueueHasFiniteCapacityAndStopReleasesProducer() async throws {
    let fixture = PlaybackFixture()
    let player = fixture.player
    try player.start(); player.pause()
    let samples = Array(repeating: Float(0), count: Speech.sampleRate / 10)
    for _ in 0..<5 { try await player.schedule(samples) }
    #expect(player.queuedFrames == SpeechPlayer.maximumQueuedFrames)
    let entered = ReadingGate()
    let producer = Task { entered.open(); try await player.schedule(samples) }
    await entered.wait()
    #expect(fixture.scheduled == 5)
    player.stop(); player.stop()
    do { try await producer.value; Issue.record("Stopped producer succeeded") } catch is CancellationError {} catch { Issue.record(error) }
    #expect(player.queuedFrames == 0)
    #expect(fixture.stops == 1)
  }

  @Test func completionWaitResolvesOnPausedStopAndOldCallbackIsIgnored() async throws {
    let fixture = PlaybackFixture(); let player = fixture.player
    try player.start(); try await player.schedule([0, 1]); player.pause()
    let old = fixture.callbacks[0]
    let entered = ReadingGate()
    let finished = Task { entered.open(); try await player.finished() }
    await entered.wait(); player.stop()
    do { try await finished.value; Issue.record("Stopped completion succeeded") } catch is CancellationError {} catch { Issue.record(error) }
    old()
    #expect(player.queuedFrames == 0)
  }

  @Test func playedBuffersReleaseCapacityAndCompleteInOrder() async throws {
    let fixture = PlaybackFixture(); let player = fixture.player
    try player.start()
    for _ in 0..<5 { try await player.schedule(Array(repeating: 0, count: Speech.sampleRate / 10)) }
    let accepted = ReadingGate(); fixture.onSchedule = { accepted.open() }
    let producer = Task { try await player.schedule([1]) }
    fixture.callbacks[0]()
    await accepted.wait(); try await producer.value
    #expect(player.queuedFrames <= SpeechPlayer.maximumQueuedFrames)
    let entered = ReadingGate()
    let finished = Task { entered.open(); try await player.finished() }
    await entered.wait()
    for callback in fixture.callbacks.dropFirst() { callback() }
    try await finished.value
    #expect(player.queuedFrames == 0)
    player.stop()
  }
}


extension SpeechPlayerTests {
  @Test(arguments: [false, true])
  func taskCancellationReleasesCapacityAndCompletionWaits(_ capacity: Bool) async throws {
    let fixture = PlaybackFixture(); let player = fixture.player
    try player.start(); player.pause()
    try await player.schedule(Array(repeating: 0, count: SpeechPlayer.maximumQueuedFrames))
    let entered = ReadingGate()
    let waiter = Task {
      entered.open()
      if capacity { try await player.schedule([0]) }
      else { try await player.finished() }
    }
    await entered.wait()
    waiter.cancel()
    do { try await waiter.value; Issue.record("Cancelled playback await succeeded") }
    catch is CancellationError {} catch { Issue.record(error) }
    #expect(player.queuedFrames == 0 && fixture.stops == 1)
  }
}
