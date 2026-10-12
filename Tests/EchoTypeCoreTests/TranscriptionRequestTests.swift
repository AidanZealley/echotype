import EchoTypeCore
import Testing

@Suite struct TranscriptionRequestTests {
  @Test("Saved keyterms are sent in order, cut to the limit, with no built-in term")
  func keytermsAreCapped() {
    let many = (0..<100).map { "term\($0)" }
    var provider = Providers.all[0]
    provider.transcription.keytermLimit = 100
    let request = TranscriptionRequest(
      settings: Settings(keyterms: many + ["extra"], language: "en-GB"), provider: provider,
      credential: "key")

    #expect(request.keyterms.count == 100)
    #expect(request.keyterms.first == "term0")
    #expect(request.keyterms.last == "term99")
    #expect(TranscriptionRequest(settings: Settings(), provider: provider, credential: nil).keyterms.isEmpty)
    #expect(request.language == "en" && request.credential == "key")
  }
}
