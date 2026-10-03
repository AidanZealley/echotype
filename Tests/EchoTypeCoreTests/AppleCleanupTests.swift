@testable import EchoTypeCore
import Foundation
import FoundationModels
import Testing

private let notEligible = "This Mac can't run Apple Intelligence, so dictation is not cleaned up."
private let unsupportedLanguage =
  "Apple Intelligence doesn't support this language, so dictation is not cleaned up."
private let turnedOff = ServiceState.unavailable(
  "Apple Intelligence is off, so dictation is not cleaned up. Turn it on in Apple Intelligence & Siri.",
  fix: Apple.SystemSettings.appleIntelligence)

@Suite struct AppleCleanupTests {
  @Test(
    "Each availability and language support maps to its readiness",
    arguments: [
      (.available, true, .ready),
      (.unavailable(.deviceNotEligible), true, .unavailable(notEligible)),
      (.unavailable(.appleIntelligenceNotEnabled), true, turnedOff),
      (.unavailable(.modelNotReady), true, .waiting("Preparing Apple Intelligence")),
      (.available, false, .unavailable(unsupportedLanguage)),
      (.unavailable(.modelNotReady), false, .unavailable(unsupportedLanguage)),
      (.unavailable(.appleIntelligenceNotEnabled), false, turnedOff),
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
