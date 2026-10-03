import Foundation

extension Provider {
  /// The app reaches xAI only through this description and its services.
  public static let xAI = Provider(
    id: "xai", name: "xAI", summary: "Paid. Uses your xAI API key.",
    credential: .apiKey(placeholder: "xai-…"), languages: [.english],
    transcription: XAI.transcription, voice: XAI.voice, cleanup: XAI.cleanup)
}

/// The xAI provider's services, composed into `Provider.xAI`.
enum XAI {
  /// Live transcription over `wss://api.x.ai/v1/stt`. The endpoint accepts at most 100
  /// keyterms.
  static let transcription = TranscriptionService(keytermLimit: 100) { request in
    Transcriber(
      transport: URLSessionWebSocketTransport(
        request: Transcriber.urlRequest(for: request), errorForStatus: error(httpStatus:)))
  }

  /// Read aloud through one streamed `POST /v1/tts` request per reading.
  static let voice = VoiceService(
    voices: Speech.voices, speedRange: Speech.speedRange,
    maximumCharacters: Speech.maximumCharacters
  ) { request in
    Speech.Stream(body: StreamingResponse(Speech.urlRequest(for: request), errorForStatus: error(httpStatus:)))
  }

  /// Cleanup through the chat completions endpoint.
  static let cleanup = CleanupService(revise: Cleanup.revise)

  /// Every xAI endpoint maps a failed status through the shared default, plus one observed
  /// convention: `api.x.ai` answers a well-formed but incorrect key with 400 and
  /// `"Incorrect API key provided"`, reserving 401 for a request carrying no credentials at all.
  static func error(httpStatus: Int) -> ProviderError {
    httpStatus == 400 ? .rejectedCredential : ProviderError(httpStatus: httpStatus)
  }
}
