import EchoTypeCore
import Testing

@Suite struct TranscriptionRequestTests {
  @Test("EchoType is sent first, a saved copy is dropped, and the list is cut to the limit")
  func keytermsAreCapped() {
    let many = (0..<100).map { "term\($0)" }
    var provider = Providers.all[0]
    provider.transcription.keytermLimit = 100
    let request = TranscriptionRequest(
      settings: Settings(keyterms: ["echotype"] + many, language: "en-GB"), provider: provider,
      credential: "key")

    #expect(request.keyterms.count == 100)
    #expect(request.keyterms.first == "EchoType")
    #expect(request.keyterms[1] == "term0")
    #expect(request.keyterms.last == "term98")
    #expect(request.language == "en" && request.credential == "key")
  }
}
