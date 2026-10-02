import Foundation
import Synchronization

/// The Apple provider's services, which run on this Mac through Apple's frameworks. Each service
/// has a readiness check, since the Mac, its settings or a missing download can rule it out.
enum Apple {
  /// Live transcription through `SpeechTranscriber`. The framework takes any number of
  /// contextual strings; 100 matches xAI until real dictation shows a better limit.
  static let transcription = TranscriptionService(keytermLimit: 100) { request in
    guard let locale = await Transcriber.supportedLocale(for: request.language) else {
      throw ProviderError.failed("Transcription does not support this language")
    }
    let transcriber = Transcriber(locale: locale, keyterms: request.keyterms)
    await transcriber.launch()
    return transcriber
  }

  /// Yields whenever any Apple service's setup starts, finishes or fails.
  static let changes = Changes()

  /// The transcription readiness check is `speechAssets.check(language:)`.
  static let speechAssets = SpeechAssets(system: .live, changes: changes)

  /// The region each bare tag in `Settings.Language.all` resolves to. The frameworks' own
  /// matching of a bare tag varies between processes, so it is chosen here once.
  private static let regions = ["en": "GB"]

  /// The regional locale every Apple service uses for the app's language tag. A tag with a
  /// region keeps it; each service then checks it supports the result.
  static func locale(for tag: String) -> Locale {
    let language = Locale.Language(identifier: tag)
    guard language.region == nil, let code = language.languageCode?.identifier,
      let region = regions[code]
    else { return Locale(identifier: tag) }
    return Locale(identifier: "\(code)-\(region)")
  }

  /// Tells every follower of `Readiness.changes` that an earlier answer may be out of date.
  final class Changes: Sendable {
    private let followers = Mutex<[UUID: AsyncStream<Void>.Continuation]>([:])

    /// A fresh stream for one follower, which stops following by ending iteration.
    func stream() -> AsyncStream<Void> {
      let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
      let id = UUID()
      continuation.onTermination = { [weak self] _ in
        self?.followers.withLock { _ = $0.removeValue(forKey: id) }
      }
      followers.withLock { $0[id] = continuation }
      return stream
    }

    func send() {
      followers.withLock { followers in
        for follower in followers.values { follower.yield() }
      }
    }
  }
}
