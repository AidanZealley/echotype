@testable import EchoTypeCore
import Foundation
import FoundationModels
import Testing

@Suite struct AppleCleanupTests {
  @Test(
    "Each availability and language support maps to its readiness",
    arguments: [
      (.available, true, .ready),
      (.unavailable(.deviceNotEligible), true, .unavailable("Apple Intelligence is not supported on this Mac")),
      (.unavailable(.appleIntelligenceNotEnabled), true, .unavailable("Needs Apple Intelligence")),
      (.unavailable(.modelNotReady), true, .waiting("Preparing Apple Intelligence")),
      (.available, false, .unavailable("Cleanup does not support this language")),
      (.unavailable(.modelNotReady), false, .unavailable("Cleanup does not support this language")),
      (.unavailable(.appleIntelligenceNotEnabled), false, .unavailable("Needs Apple Intelligence")),
    ] as [(SystemLanguageModel.Availability, Bool, ServiceState)])
  func readiness(availability: SystemLanguageModel.Availability, supportsLanguage: Bool, expected: ServiceState) {
    #expect(Apple.Intelligence.state(availability, supportsLanguage: supportsLanguage) == expected)
  }

  @Test("Framework errors become provider failures and cancellation passes through")
  func errorsMapToProviderError() {
    let context = LanguageModelSession.GenerationError.Context(debugDescription: "test")
    for error: LanguageModelSession.GenerationError in [
      .exceededContextWindowSize(context), .guardrailViolation(context), .assetsUnavailable(context),
    ] {
      #expect(Apple.Intelligence.failure(error) as? ProviderError == .failed(error.localizedDescription))
    }
    #expect(Apple.Intelligence.failure(CancellationError()) is CancellationError)
  }
}
