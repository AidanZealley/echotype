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
      URLQueryItem(name: "endpointing", value: "2000"),
      URLQueryItem(name: "filler_words", value: "false"),
      URLQueryItem(name: "format", value: "true"),
      URLQueryItem(name: "language", value: "en-GB"),
    ]
  )
}

@Test("Keyterms are capped at 100 and 50 characters each")
func keytermsAreCapped() {
  let many = (0..<120).map { "term\($0)" }
  let terms = queryItems(Settings(keyterms: many)).filter { $0.name == "keyterm" }

  #expect(terms.count == 100)
  #expect(terms.first?.value == "term0")
  #expect(terms.last?.value == "term99")

  let long = queryItems(Settings(keyterms: [String(repeating: "x", count: 60)]))
  #expect(long.last?.value == String(repeating: "x", count: 50))
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
