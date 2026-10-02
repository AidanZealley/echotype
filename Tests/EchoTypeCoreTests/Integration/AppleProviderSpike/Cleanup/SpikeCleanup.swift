import EchoTypeCore
import FoundationModels

/// Each request owns a fresh session, with framework protections unchanged.
enum SpikeCleanup {
  static let service = CleanupService { request in
    try Task.checkCancellation()
    let session = LanguageModelSession(instructions: request.prompt)
    let response = try await session.respond(
      to: request.text, options: GenerationOptions(samplingMode: .greedy))
    try Task.checkCancellation()
    return response.content
  }
}
