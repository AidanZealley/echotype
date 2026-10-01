import Foundation

extension XAI {
  /// Read aloud through the text to speech endpoint. Reading uses one REST request whose
  /// response streams raw 16-bit PCM; see decision 0018.
  enum Speech {
    static let voices = [Voice(id: "ara", name: "Ara"), Voice(id: "altair", name: "Altair")]
    static let speedRange = 0.7...1.5
    /// The REST endpoint's limit on the text of one request.
    static let maximumCharacters = 60_000
    /// The rate of the 16-bit mono PCM every request asks for, the endpoint's default.
    static let sampleRate = 24_000

    /// The `POST /v1/tts` request. It pins `optimize_streaming_latency` to 0 and
    /// `text_normalization` to false rather than omitting them, so a change to the endpoint's
    /// defaults can't change reading.
    static func urlRequest(for speech: SpeechRequest) -> URLRequest {
      var request = URLRequest(url: URL(string: "https://api.x.ai/v1/tts")!)
      request.httpMethod = "POST"
      if let credential = speech.credential {
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
      }
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      // Every field is a string, boolean, integer or the caller's validated speed.
      request.httpBody = try! encoder.encode(
        Body(
          text: speech.text,
          voiceId: speech.voice,
          language: speech.language,
          speed: speech.speed,
          outputFormat: .init(codec: "pcm", sampleRate: sampleRate),
          optimizeStreamingLatency: 0,
          textNormalization: false
        ))
      return request
    }

    /// Encoded with snake-case keys, the endpoint's names.
    private struct Body: Encodable {
      struct OutputFormat: Encodable {
        var codec: String
        var sampleRate: Int
      }

      var text: String
      var voiceId: String
      var language: String
      var speed: Double
      var outputFormat: OutputFormat
      var optimizeStreamingLatency: Int
      var textNormalization: Bool
    }

    /// Decodes the streamed body in 100 ms chunks. Being an actor keeps decoding off the UI
    /// actor. It takes another body piece only when the last one is used up, so the body's
    /// bounded queue still applies backpressure while the reader waits on paused playback.
    actor Stream: SpeechStream {
      private static let chunkBytes = sampleRate / 10 * 2
      private let body: StreamingResponse
      private var decoder = PCMDecoder()
      private var pending = Data()

      init(body: StreamingResponse) { self.body = body }

      func next() async throws -> SpeechAudio? {
        while pending.isEmpty {
          guard let data = try await body.next() else { return nil }
          pending = data
        }
        let chunk = pending.prefix(Self.chunkBytes)
        pending = pending.dropFirst(chunk.count)
        return SpeechAudio(sampleRate: sampleRate, samples: decoder.samples(from: chunk))
      }

      nonisolated func cancel() { body.cancel() }
    }
  }
}
