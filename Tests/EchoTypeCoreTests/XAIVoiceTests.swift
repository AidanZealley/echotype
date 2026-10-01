@testable import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct XAIVoiceTests {
  @Test("The speech request posts the reading as JSON, with the spike's choices pinned")
  func requestBody() throws {
    let request = XAI.Speech.urlRequest(for: SpeechRequest(
      text: "Hello there.", voice: "altair", speed: 1.25, language: "en-GB", credential: "xai-123"))

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

  @Test("The service offers Ara then Altair, 0.7 to 1.5, and caps text at 60,000 characters")
  func service() {
    let voice = XAI.voice
    #expect(voice.voices == [Voice(id: "ara", name: "Ara"), Voice(id: "altair", name: "Altair")])
    #expect(voice.speedRange == 0.7...1.5)
    let limit = String(repeating: "a", count: 60_000)
    #expect(voice.capped(limit) == limit)
    #expect(voice.capped(limit + "bc") == limit)
    #expect(voice.capped("") == "")
  }

  @Test("The stream decodes the body into 24 kHz chunks of at most 100 ms, across odd splits")
  func decodesIntoSpeechAudio() async throws {
    let values = (0..<6_001).map { Int16(truncatingIfNeeded: $0 &* 37) }
    let pcm = values.withUnsafeBufferPointer { Data(buffer: $0) }
    let body = SilentResponse()
    let stream = XAI.Speech.Stream(body: body.response)
    // Odd piece sizes put sample boundaries inside pieces and inside 100 ms chunks.
    body.receive(pcm.prefix(4_801)); body.receive(Data(pcm.dropFirst(4_801))); body.complete()

    var samples: [Float] = []
    while let audio = try await stream.next() {
      #expect(audio.sampleRate == 24_000)
      #expect(audio.samples.count <= 2_400)
      samples += audio.samples
    }
    #expect(samples == values.map { Float($0) / 32768 })
  }
}
