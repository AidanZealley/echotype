import EchoTypeCore
import Foundation
import Testing

private func queryItems(_ settings: Settings) -> [URLQueryItem] {
  let url = STTConnection.streamingURL(settings: settings)
  return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
}

@Test("The connection URL carries the documented parameters")
func connectionURLCarriesTheDocumentedParameters() {
  let url = STTConnection.streamingURL(settings: Settings(language: "en-GB"))

  #expect(url.scheme == "wss")
  #expect(url.host == "api.x.ai")
  #expect(url.path == "/v1/stt")
  #expect(
    queryItems(Settings(language: "en-GB")) == [
      URLQueryItem(name: "encoding", value: "pcm"),
      URLQueryItem(name: "sample_rate", value: "16000"),
      URLQueryItem(name: "interim_results", value: "true"),
      URLQueryItem(name: "endpointing", value: "1200"),
      URLQueryItem(name: "filler_words", value: "false"),
      URLQueryItem(name: "format", value: "true"),
      URLQueryItem(name: "language", value: "en-GB"),
      URLQueryItem(name: "keyterm", value: "EchoType"),
    ]
  )
}

@Test("EchoType is sent first, a saved copy is dropped, and 100 saved terms send 99")
func keytermsAreCapped() {
  let many = (0..<100).map { "term\($0)" }
  let terms = STTConnection.keyterms(settings: Settings(keyterms: ["echotype"] + many))

  #expect(terms.count == 100)
  #expect(terms.first == "EchoType")
  #expect(terms[1] == "term0")
  #expect(terms.last == "term98")

  let long = STTConnection.keyterms(settings: Settings(keyterms: [String(repeating: "x", count: 60)]))
  #expect(long.last == String(repeating: "x", count: 50))
}

@Test("A keyterm containing spaces is percent encoded")
func keytermsWithSpacesArePercentEncoded() {
  let url = STTConnection.streamingURL(settings: Settings(keyterms: ["TanStack Start", "pnpm"]))

  #expect(url.absoluteString.hasSuffix("&keyterm=TanStack%20Start&keyterm=pnpm"))
  #expect(queryItems(Settings(keyterms: ["TanStack Start"])).last?.value == "TanStack Start")
}

@Test("The API key travels as a bearer token")
func apiKeyIsABearerToken() {
  #expect(STTConnection.headers(apiKey: "xai-123") == ["Authorization": "Bearer xai-123"])
}
