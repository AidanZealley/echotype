import Foundation

/// How to reach the xAI streaming endpoint. Configuration is entirely query parameters; there
/// is no setup message.
public enum STTConnection {
  /// The endpoint accepts at most this many keyterms, and longer ones are truncated rather
  /// than dropped.
  public static let maximumKeyterms = 100
  private static let maximumKeytermLength = 50

  /// The settings' keyterms under the endpoint's caps. The streaming URL and the batch request
  /// both send these.
  public static func keyterms(settings: Settings) -> [String] {
    settings.keyterms.prefix(maximumKeyterms).map { String($0.prefix(maximumKeytermLength)) }
  }

  /// `endpointing` is deliberately far above the 400ms default: utterance boundaries are
  /// controlled by the hotkey, and the default would chop a prompt into fragments every time
  /// the speaker pauses to think. `format=true` punctuates each utterance on its own, so every
  /// boundary also tends to end a sentence with a full stop. 5000 keeps ordinary thinking
  /// pauses inside one utterance while staying under the 10s silence timeout.
  public static func streamingURL(settings: Settings) -> URL {
    var components = URLComponents()
    components.scheme = "wss"
    components.host = "api.x.ai"
    components.path = "/v1/stt"
    components.queryItems =
      [
        URLQueryItem(name: "encoding", value: "pcm"),
        URLQueryItem(name: "sample_rate", value: "16000"),
        URLQueryItem(name: "interim_results", value: "true"),
        URLQueryItem(name: "endpointing", value: "5000"),
        URLQueryItem(name: "filler_words", value: "false"),
        URLQueryItem(name: "format", value: "true"),
        URLQueryItem(name: "language", value: settings.language),
      ]
      + keyterms(settings: settings).map { URLQueryItem(name: "keyterm", value: $0) }
    guard let url = components.url else {
      preconditionFailure("The streaming URL is built from constants and cannot be invalid")
    }
    return url
  }

  /// The endpoint authenticates with a bearer token. The key is not part of `Settings`; it
  /// lives in the Keychain and is passed in by the macOS layer.
  public static func headers(apiKey: String) -> [String: String] {
    ["Authorization": "Bearer \(apiKey)"]
  }
}
