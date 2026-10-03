import Foundation
import FoundationModels

extension Apple {
  /// Cleanup through the on-device `SystemLanguageModel`. Each request gets a fresh session, so
  /// no history carries between revisions, with greedy generation and the framework's default
  /// protections. Context overflow and every other framework failure throw, and `Reviser` keeps
  /// the dictated text; nothing is truncated or chunked here.
  static let cleanup = CleanupService { request in
    try Task.checkCancellation()
    do {
      let session = LanguageModelSession(instructions: request.prompt)
      let response = try await session.respond(
        to: request.text, options: GenerationOptions(samplingMode: .greedy))
      try Task.checkCancellation()
      return response.content
    } catch {
      try Task.checkCancellation()
      throw Intelligence.failure(error)
    }
  }

  enum Intelligence {
    /// Cleanup readiness, which needs Apple Intelligence available and supporting the language.
    /// The system downloads and loads the model itself, so there is no setup to start;
    /// `Apple.changes` yields when the model's availability changes.
    static func check(language: String) -> ServiceState {
      let model = SystemLanguageModel.default
      return state(
        model.availability, supportsLanguage: model.supportsLocale(Apple.locale(for: language)))
    }

    static func state(_ availability: SystemLanguageModel.Availability, supportsLanguage: Bool)
      -> ServiceState
    {
      switch availability {
      case .unavailable(.deviceNotEligible):
        .unavailable("This Mac can't run Apple Intelligence, so dictation is not cleaned up.")
      case .unavailable(.appleIntelligenceNotEnabled):
        .unavailable(
          "Apple Intelligence is off, so dictation is not cleaned up. Turn it on in Apple Intelligence & Siri.",
          fix: Apple.SystemSettings.appleIntelligence)
      case _ where !supportsLanguage:
        .unavailable("Apple Intelligence doesn't support this language, so dictation is not cleaned up.")
      case .unavailable(.modelNotReady):
        .waiting("Preparing Apple Intelligence")
      case .unavailable:
        .unavailable("Apple Intelligence is unavailable, so dictation is not cleaned up.")
      case .available:
        .ready
      }
    }

    /// Framework errors, such as context overflow or a guardrail, as provider failures.
    /// Cancellation passes through.
    static func failure(_ error: any Error) -> any Error {
      if error is CancellationError { return error }
      return ProviderError.failed(error.localizedDescription)
    }
  }
}
