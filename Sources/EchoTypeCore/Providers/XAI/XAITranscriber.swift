import Foundation

extension XAI {
  /// One xAI streaming session over a `WebSocketTransport`, translated into neutral events:
  ///
  /// | xAI                  | Event                                                  |
  /// |----------------------|--------------------------------------------------------|
  /// | `transcript.created` | `.ready`                                               |
  /// | `transcript.partial` | `.transcript` from the assembler, plus `.speech`       |
  /// | `transcript.done`    | `.transcript` with the committed tail, then `.finished` |
  /// | `error`              | throws `ProviderError.failed`                          |
  /// | `finish()`           | sends `finalize` then `audio.done`                     |
  ///
  /// The session holds audio until `.ready` and orders every send, so this type keeps only the
  /// protocol: decoding, assembly and the closing messages.
  final class Transcriber: LiveTranscriber {
    let events: AsyncThrowingStream<TranscriptionEvent, any Error>
    private let transport: any WebSocketTransport
    /// The one reader of the socket. A WebSocket message is delivered to exactly one reader.
    private let receiving: Task<Void, Never>

    init(transport: any WebSocketTransport) {
      self.transport = transport
      let (events, continuation) = AsyncThrowingStream.makeStream(of: TranscriptionEvent.self)
      self.events = events
      receiving = Task { await Self.translate(transport.messages(), into: continuation) }
    }

    func send(audio: Data) async throws {
      try await transport.send(binary: audio)
    }

    /// `finalize` resolves the tail into one more `speech_final`, and `audio.done` asks for
    /// `transcript.done` once it has.
    func finish() async throws {
      try await transport.send(text: #"{"type":"finalize"}"#)
      try await transport.send(text: #"{"type":"audio.done"}"#)
    }

    func close() {
      transport.close()
      receiving.cancel()
    }

    func waitForClose() async {
      await receiving.value
      await transport.waitForClose()
    }

    /// Reads the server stream until `transcript.done` or the socket closing. An `error` event
    /// throws `ProviderError.failed`, a frame that is not decodable JSON throws the decoder's
    /// error, and an unrecognised event `type` is ignored.
    private static func translate(
      _ messages: AsyncThrowingStream<String, any Error>,
      into events: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
    ) async {
      var assembler = TranscriptAssembler()
      do {
        for try await message in messages {
          guard let event = try Event.decode(message) else { continue }
          assembler.apply(event)
          switch event {
          case .created:
            events.yield(.ready)
          case .partial(let partial):
            events.yield(.transcript(assembler.transcript))
            if isSpeech(partial) { events.yield(.speech) }
          case .done:
            events.yield(.transcript(assembler.transcript))
            events.yield(.finished)
            events.finish()
            return
          case .error(let error):
            throw ProviderError.failed(error.message)
          }
        }
        events.finish()
      } catch {
        events.finish(throwing: error)
      }
    }

    /// Whether a partial says anyone is speaking (decision record 0002).
    ///
    /// The endpoint emits `transcript.partial` at about 1 Hz with empty text throughout a silence
    /// and emits nothing at all for two to three seconds while it decides where an utterance
    /// ended, so the arrival of a partial carries no signal. Text does, and so does the end of an
    /// utterance.
    static func isSpeech(_ partial: Event.Partial) -> Bool {
      partial.speechFinal
        || !partial.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The endpoint truncates longer keyterms rather than dropping them.
    private static let maximumKeytermLength = 50

    /// Configuration is entirely query parameters; there is no setup message. Endpointing is
    /// longer than the 400ms default so brief pauses stay in one utterance, while allowing live
    /// cleanup to start sooner than with the previous 2000ms setting.
    static func streamingURL(for request: TranscriptionRequest) -> URL {
      var components = URLComponents()
      components.scheme = "wss"
      components.host = "api.x.ai"
      components.path = "/v1/stt"
      components.queryItems =
        [
          URLQueryItem(name: "encoding", value: "pcm"),
          URLQueryItem(name: "sample_rate", value: "16000"),
          URLQueryItem(name: "interim_results", value: "true"),
          URLQueryItem(name: "endpointing", value: "1200"),
          URLQueryItem(name: "filler_words", value: "false"),
          URLQueryItem(name: "format", value: "true"),
          URLQueryItem(name: "language", value: request.language),
        ]
        + request.keyterms.map {
          URLQueryItem(name: "keyterm", value: String($0.prefix(maximumKeytermLength)))
        }
      guard let url = components.url else {
        preconditionFailure("The streaming URL is built from constants and cannot be invalid")
      }
      return url
    }

    /// The endpoint authenticates with a bearer token.
    static func urlRequest(for request: TranscriptionRequest) -> URLRequest {
      var urlRequest = URLRequest(url: streamingURL(for: request))
      if let credential = request.credential {
        urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
      }
      return urlRequest
    }
  }
}
