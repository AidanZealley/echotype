import EchoTypeCore
import Foundation
import Testing

@Test("The speech request posts the reading's settings as JSON, with the spike's choices pinned")
func speechRequestFields() throws {
  let settings = Settings(language: "en-GB", voice: "altair", speechSpeed: 1.25)
  let request = Speech.request(text: "Hello there.", settings: settings, apiKey: "xai-123")

  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://api.x.ai/v1/tts")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer xai-123")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

  let json = try JSONSerialization.jsonObject(with: try #require(request.httpBody))
  let body = try #require(json as? [String: Any])
  #expect(body["text"] as? String == "Hello there.")
  #expect(body["voice_id"] as? String == "altair")
  #expect(body["language"] as? String == "en-GB")
  #expect(body["speed"] as? Double == 1.25)
  let format = try #require(body["output_format"] as? [String: Any])
  #expect(format["codec"] as? String == "pcm")
  #expect(format["sample_rate"] as? Int == 24000)
  // Both are sent explicitly; see decision 0018.
  #expect(body["optimize_streaming_latency"] as? Int == 0)
  #expect(body["text_normalization"] as? Bool == false)
  #expect(body.count == 7)
}

@Test("The cap keeps text within the limit and cuts longer text to its first 60,000 characters")
func speechCap() {
  let limit = String(repeating: "a", count: 60_000)
  #expect(Speech.capped(limit) == (limit, false))
  #expect(Speech.capped(limit + "bc") == (limit, true))
  #expect(Speech.capped("") == ("", false))
}
