@testable import EchoTypeCore
import Foundation
import Testing

/// Real on-device cleanup through `Reviser`. Skipped unless `ECHOTYPE_APPLE_LIVE=1`, so an
/// ordinary run touches no language model:
///
/// ```bash
/// ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleCleanup
/// ```
///
/// Apple Intelligence must be turned on and its model ready.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_LIVE"] == "1", "Set ECHOTYPE_APPLE_LIVE=1."))
struct AppleCleanupLiveTests {
  /// About 9,000 tokens against a 4,096-token context.
  private let oversized = String(repeating: "microphone settings window ", count: 3000)
    .trimmingCharacters(in: .whitespaces)

  @Test("Cleanup for English is ready")
  func englishIsReady() {
    #expect(Apple.Intelligence.check(language: "en") == .ready)
  }

  @Test("A short revision returns a reply")
  func shortRevisionReplies() async throws {
    let reply = try await Apple.cleanup.revise(
      CleanupRequest(prompt: Reviser.prompt, text: "I I want to ship the update today.", final: false, credential: nil))
    #expect(!reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  @Test("An oversized request fails as a provider error")
  func oversizedRequestFails() async {
    await #expect(throws: ProviderError.self) {
      try await Apple.cleanup.revise(
        CleanupRequest(prompt: Reviser.prompt, text: oversized, final: true, credential: nil))
    }
  }

  @Test("An oversized final keeps the dictated text within the final budget")
  func oversizedFinalPreservesText() async {
    let reviser = Reviser(cleanup: Apple.cleanup, credential: nil)
    let started = ContinuousClock.now
    let text = await reviser.finish(committed: oversized)
    let seconds = (ContinuousClock.now - started) / .seconds(1)
    #expect(text == oversized)
    // The research measured 3.02 to 3.21 s; cancellation may land just after the budget.
    #expect(seconds < Reviser.finalTimeout + 1, "\(seconds) s")
  }
}
