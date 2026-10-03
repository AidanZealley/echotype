import AVFoundation
import Foundation
import FoundationModels
import Synchronization

extension Provider {
  /// The app reaches Apple only through this description and its services.
  public static let apple = Provider(
    id: "apple", name: "Apple", summary: "Free. Runs on this Mac.", credential: .none,
    languages: [.english],
    transcription: Apple.transcription, voice: Apple.voice, cleanup: Apple.cleanup,
    readiness: Readiness(
      check: { request in
        ServiceReadiness(
          transcription: await Apple.speechAssets.check(language: request.language),
          voice: Apple.Speech.check(language: request.language, voice: request.voice),
          cleanup: Apple.Intelligence.check(language: request.language))
      },
      changes: { Apple.changes.stream() }))
}

/// The Apple provider's services, composed into `Provider.apple`, which run on this Mac through
/// Apple's frameworks. Each service has a readiness check, since the Mac, its settings or a
/// missing download can rule it out.
enum Apple {
  /// Live transcription through `SpeechTranscriber`. The framework takes any number of
  /// contextual strings; 100 is a provisional cap, since 1,000 were accepted but no recognition
  /// benefit or usable maximum has been measured.
  static let transcription = TranscriptionService(keytermLimit: 100) { request in
    guard let locale = await Transcriber.supportedLocale(for: request.language) else {
      throw ProviderError.failed("Transcription does not support this language")
    }
    let transcriber = Transcriber(locale: locale, keyterms: request.keyterms)
    await transcriber.launch()
    return transcriber
  }

  /// Yields whenever any Apple service's setup starts, finishes or fails, when the installed
  /// voices change, such as after a download in System Settings, and when Apple Intelligence's
  /// availability changes.
  static let changes: Changes = {
    let changes = Changes()
    // Both observe for the life of the app, so the token and task are never ended.
    _ = NotificationCenter.default.addObserver(
      forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: nil
    ) { _ in changes.send() }
    Task {
      for await _ in Observations({ SystemLanguageModel.default.availability }) { changes.send() }
    }
    return changes
  }()

  /// The transcription readiness check is `speechAssets.check(language:)`.
  static let speechAssets = SpeechAssets(system: .live, changes: changes)

  /// The regional locale for each tag in `Provider.apple.languages`. The frameworks' own
  /// matching of a bare tag varies between processes, so it is chosen here once.
  private static let locales = ["en": "en-GB"]

  /// The locale every Apple service uses for the app's language tag; each service then checks it
  /// supports the result.
  static func locale(for tag: String) -> Locale {
    Locale(identifier: locales[tag] ?? tag)
  }

  /// The System Settings panes a readiness message sends the user to.
  enum SystemSettings {
    static let readAndSpeak = URL(
      string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent")!
    static let appleIntelligence = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
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
