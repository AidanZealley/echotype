import Foundation

/// How to ask the xAI text to speech endpoint for a reading. Reading uses one REST request whose
/// response streams raw PCM; see decision 0018. The app sends the request and streams the bytes.
public enum Speech {
  /// The voice ids as the endpoint names them. The first is the default.
  public static let voices = ["ara", "altair"]

  /// The rate of the 16-bit mono PCM every request asks for, the endpoint's default.
  public static let sampleRate = 24_000

  /// The REST endpoint's limit on the text of one request.
  public static let maximumCharacters = 60_000

  /// The text cut to its first `maximumCharacters`, and whether it was cut.
  ///
  /// Counts Unicode scalars rather than `Character`s, so a selection full of multi-scalar
  /// emoji still fits a limit the endpoint may count in code points.
  public static func capped(_ text: String) -> (text: String, wasCut: Bool) {
    let scalars = text.unicodeScalars
    guard scalars.count > maximumCharacters else { return (text, false) }
    return (String(scalars.prefix(maximumCharacters)), true)
  }

  /// The `POST /v1/tts` request. It pins `optimize_streaming_latency` to 0 and
  /// `text_normalization` to false rather than omitting them, so a change to the endpoint's
  /// defaults can't change reading. The app maps a non-2xx status with `STTError(httpStatus:)`.
  public static func request(text: String, settings: Settings, apiKey: String) -> URLRequest {
    guard let url = URL(string: "https://api.x.ai/v1/tts") else {
      preconditionFailure("The speech URL is a constant and cannot be invalid")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    for (field, value) in STTConnection.headers(apiKey: apiKey) {
      request.setValue(value, forHTTPHeaderField: field)
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    // Strings, finite doubles and integers always encode.
    request.httpBody = try! encoder.encode(
      Body(
        text: text,
        voiceId: settings.voice,
        language: settings.language,
        speed: settings.speechSpeed,
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
}
