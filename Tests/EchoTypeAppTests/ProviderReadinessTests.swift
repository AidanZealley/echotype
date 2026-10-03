import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1))) @MainActor struct ProviderReadinessTests {
  private let request = ReadinessRequest(language: "en", voice: "default")

  @Test("Following checks again when the provider reports a change, and drops it when cancelled")
  func followsChanges() async {
    let state = Mutex(ServiceState.waiting("Downloading speech model"))
    let (changes, continuation) = AsyncStream<Void>.makeStream()
    let dropped = ReadingGate()
    continuation.onTermination = { _ in dropped.open() }
    let readiness = Readiness(
      check: { _ in
        ServiceReadiness(transcription: state.withLock { $0 }, voice: .ready, cleanup: nil)
      }, changes: { changes })

    let (answers, answered) = AsyncStream<ServiceReadiness>.makeStream()
    let following = Task { @MainActor in
      await readiness.follow(request) { answered.yield($0) }
    }
    var iterator = answers.makeAsyncIterator()
    #expect(await iterator.next()?.transcription == .waiting("Downloading speech model"))

    state.withLock { $0 = .ready }
    continuation.yield()
    #expect(await iterator.next()?.transcription == .ready)

    following.cancel()
    await dropped.wait()
  }
}
