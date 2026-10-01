import Foundation

extension XAI {
  /// A decoded server event from the xAI streaming endpoint.
  ///
  /// The endpoint sends JSON text frames. `transcript.created` means the session is ready and
  /// audio may start, `transcript.partial` carries transcript text that may still be rewritten,
  /// `transcript.done` arrives after `audio.done` and closes the connection, and `error` reports
  /// a server-side failure.
  enum Event: Equatable, Sendable {
    case created
    case partial(Partial)
    case done
    case error(ServerError)

    /// One `transcript.partial` payload.
    ///
    /// `speechFinal` marks the end of an utterance, and those segments are the only ones the
    /// assembler commits. `isFinal` marks text the model will not revise further within the
    /// current segment, so it is settled but not yet committed.
    struct Partial: Equatable, Sendable {
      var text: String
      var words: [Word]
      var isFinal: Bool
      var speechFinal: Bool

      init(text: String, words: [Word] = [], isFinal: Bool = false, speechFinal: Bool = false)
      {
        self.text = text
        self.words = words
        self.isFinal = isFinal
        self.speechFinal = speechFinal
      }
    }

    /// One word of a partial, with its timing. The endpoint names the word itself `text`, and
    /// the timings are optional, since nothing here depends on them and the endpoint is free to
    /// omit them. Unknown keys decode away, so a field the endpoint adds later costs nothing
    /// until something needs it.
    struct Word: Equatable, Sendable, Decodable {
      var text: String
      var start: Double?
      var end: Double?

      init(text: String, start: Double? = nil, end: Double? = nil) {
        self.text = text
        self.start = start
        self.end = end
      }
    }

    struct ServerError: Equatable, Sendable {
      var code: String?
      var message: String

      init(code: String? = nil, message: String) {
        self.code = code
        self.message = message
      }
    }

    /// Decodes one server message.
    ///
    /// Returns `nil` for a well-formed message whose `type` is not one of the four documented
    /// events, so that an endpoint that grows a new event does not fail a session. Throws when
    /// the message is not decodable JSON at all.
    static func decode(_ message: String) throws -> Event? {
      guard let data = message.data(using: .utf8) else { return nil }
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      let envelope = try decoder.decode(Envelope.self, from: data)

      switch envelope.type {
      case "transcript.created":
        return .created
      case "transcript.partial":
        return .partial(
          Partial(
            text: envelope.text ?? "",
            words: envelope.words ?? [],
            isFinal: envelope.isFinal ?? false,
            speechFinal: envelope.speechFinal ?? false
          )
        )
      case "transcript.done":
        return .done
      case "error":
        return .error(ServerError(code: envelope.code, message: envelope.message ?? ""))
      default:
        return nil
      }
    }

    /// The union of the four event payloads. The endpoint has no setup message and no envelope
    /// nesting, so every field sits at the top level beside `type`.
    private struct Envelope: Decodable {
      var type: String
      var text: String?
      var words: [Word]?
      var isFinal: Bool?
      var speechFinal: Bool?
      var code: String?
      var message: String?
    }
  }
}
