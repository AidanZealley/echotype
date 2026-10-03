import EchoTypeCore
@testable import EchoTypeApp
import Testing

/// Defined here rather than registered, so the wording is shown to come from the provider.
private let acme = Provider(
  id: "acme", name: "Acme", summary: "", credential: .apiKey(placeholder: "acme-…"),
  languages: [.english],
  transcription: TranscriptionService(keytermLimit: 1) { _ in fatalError("Not started") },
  voice: VoiceService(voices: [], speedRange: 1...1, maximumCharacters: 1) { _ in
    fatalError("Not spoken")
  },
  cleanup: nil)

@Test("Provider failures and a missing key are worded with the provider's name")
@MainActor func providerWording() {
  let cases: [(any Error, String)] = [
    (SessionError.provider(.rejectedCredential), "Acme rejected the API key"),
    (ProviderError.rateLimited, "Acme rate limit reached"),
    (SessionError.provider(.unavailable), "Acme is unavailable"),
    (ProviderError.failed("HTTP 418"), "Acme error: HTTP 418"),
    (MissingCredential(), "Add your Acme API key in EchoType Settings"),
    (NotReady(state: .waiting("Downloading speech model")), "Downloading speech model"),
    (NotReady(state: .unavailable("Not supported on this Mac")), "Not supported on this Mac"),
  ]
  for (error, message) in cases {
    #expect(DictationController.describe(error, provider: acme) == message)
  }
  // Today's text for the registered default, which gate G3 checks with a wrong key.
  #expect(
    DictationController.describe(ProviderError.rejectedCredential, provider: Providers.all[0])
      == "xAI rejected the API key")
}
