import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Synchronization
import Testing

/// A provider's readiness whose answer the test sets, and whose `changes` it yields.
private final class FakeReadiness: Sendable {
  let state = Mutex(ServiceState.waiting("Downloading speech model"))
  let changes: AsyncStream<Void>
  let continuation: AsyncStream<Void>.Continuation
  /// Opens once the follower stops reading `changes`.
  let dropped = ReadingGate()

  init() {
    (changes, continuation) = AsyncStream.makeStream()
    continuation.onTermination = { [dropped] _ in dropped.open() }
  }

  var provider: Provider {
    fakeProvider(readiness: Readiness(
      check: { _ in
        ServiceReadiness(transcription: self.state.withLock { $0 }, voice: .ready, cleanup: nil)
      }, changes: { [changes] in changes }))
  }
}

private func fakeProvider(readiness: Readiness?) -> Provider {
  Provider(
    id: "fake", name: "Fake", summary: "", credential: .none,
    transcription: TranscriptionService(keytermLimit: 1) { _ in fatalError("Not started") },
    voice: VoiceService(voices: [Voice(id: "default", name: "Default")], speedRange: 1...1,
      maximumCharacters: 1) { _ in fatalError("Not spoken") },
    cleanup: nil, readiness: readiness)
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct ProviderReadinessTests {
  private let controller = DictationController(store: SettingsStore(),
    clipboard: Clipboard(access: .init(count: { 0 }, save: { [] }, restore: { _ in },
      read: { nil }, write: { _ in }, post: { _, _ in }, wait: { _ in })),
    makeReader: { _, _, _, _, _ in fatalError("No reading expected") },
    focusedScreen: { nil }, showPanel: { _, _ in }, hidePanel: {})

  private func readiness(becomes expected: ServiceReadiness?) async {
    for await answer in Observations({ controller.readiness }) where answer == expected { return }
  }

  @Test("The controller checks again when the provider reports a change, and drops it on a switch")
  func followsChanges() async {
    let fake = FakeReadiness()
    controller.followReadiness(of: fake.provider)
    await readiness(becomes: ServiceReadiness(
      transcription: .waiting("Downloading speech model"), voice: .ready, cleanup: nil))

    fake.state.withLock { $0 = .ready }
    fake.continuation.yield()
    await readiness(becomes: ServiceReadiness(transcription: .ready, voice: .ready, cleanup: nil))

    controller.followReadiness(of: fakeProvider(readiness: nil))
    #expect(controller.readiness == nil)
    await fake.dropped.wait()
  }
}
