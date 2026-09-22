import Foundation

/// A decoded server event from the xAI streaming endpoint.
///
/// The endpoint sends JSON text frames. `transcript.created` means the session is ready and
/// audio may start, `transcript.partial` carries transcript text that may still be rewritten,
/// `transcript.done` arrives after `audio.done` and closes the connection, and `error` reports
/// a server-side failure.
public enum STTEvent: Equatable, Sendable {
  case created
  case partial(Partial)
  case done
  case error(ServerError)

  /// One `transcript.partial` payload.
  ///
  /// `speechFinal` marks the end of an utterance, and those segments are the only ones the
  /// assembler commits. `isFinal` marks text the model will not revise further within the
  /// current segment, so it is settled but not yet committed.
  public struct Partial: Equatable, Sendable {
    public var text: String
    public var words: [Word]
    public var isFinal: Bool
    public var speechFinal: Bool

    public init(text: String, words: [Word] = [], isFinal: Bool = false, speechFinal: Bool = false)
    {
      self.text = text
      self.words = words
      self.isFinal = isFinal
      self.speechFinal = speechFinal
    }
  }

  /// One word of a partial, with its timing. The endpoint names the word itself `text`, and
  /// every other field is optional, since nothing here depends on timings and the endpoint is
  /// free to omit them.
  public struct Word: Equatable, Sendable, Decodable {
    public var text: String
    public var start: Double?
    public var end: Double?
    public var confidence: Double?

    public init(
      text: String,
      start: Double? = nil,
      end: Double? = nil,
      confidence: Double? = nil
    ) {
      self.text = text
      self.start = start
      self.end = end
      self.confidence = confidence
    }
  }

  public struct ServerError: Equatable, Sendable {
    public var code: String?
    public var message: String

    public init(code: String? = nil, message: String) {
      self.code = code
      self.message = message
    }
  }

  /// Decodes one server message.
  ///
  /// Returns `nil` for a well-formed message whose `type` is not one of the four documented
  /// events, so that an endpoint that grows a new event does not fail a session. Throws when
  /// the message is not decodable JSON at all.
  public static func decode(_ message: String) throws -> STTEvent? {
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

/// A failure surfaced by the transport or by the endpoint.
public enum STTError: Error, Equatable, Sendable {
  /// 400
  case badRequest
  /// 401
  case unauthorized
  /// 413, audio over 500 MB
  case payloadTooLarge
  /// 429
  case rateLimited
  /// 502, the endpoint failed to download a URL
  case downloadFailed
  /// 503
  case unavailable
  /// Any other HTTP status the handshake rejected the connection with.
  case unexpectedStatus(Int)
  /// An `error` event on an otherwise healthy socket.
  case server(STTEvent.ServerError)

  /// Maps the statuses the specification documents onto distinguishable cases.
  public init(httpStatus: Int) {
    switch httpStatus {
    case 400: self = .badRequest
    case 401: self = .unauthorized
    case 413: self = .payloadTooLarge
    case 429: self = .rateLimited
    case 502: self = .downloadFailed
    case 503: self = .unavailable
    default: self = .unexpectedStatus(httpStatus)
    }
  }
}
