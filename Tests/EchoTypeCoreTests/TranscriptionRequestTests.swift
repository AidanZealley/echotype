import EchoTypeCore
import Testing

@Suite struct TranscriptionRequestTests {
  @Test("EchoType is sent first, a saved copy is dropped, and the list is cut to the limit")
  func keytermsAreCapped() {
    let many = (0..<100).map { "term\($0)" }
    let request = TranscriptionRequest(
      settings: Settings(keyterms: ["echotype"] + many, language: "en-GB"), keytermLimit: 100,
      credential: "key")

    #expect(request.keyterms.count == 100)
    #expect(request.keyterms.first == "EchoType")
    #expect(request.keyterms[1] == "term0")
    #expect(request.keyterms.last == "term98")
    #expect(request.language == "en-GB" && request.credential == "key")
  }
}
