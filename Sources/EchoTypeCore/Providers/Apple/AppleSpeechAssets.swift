import Foundation
import Speech

extension Apple {
  /// Transcription readiness: the speech model for the resolved locale must be installed, and
  /// this runs the one installation that gets it there.
  ///
  /// Asking for an installation request reserves the locale even when nothing needs
  /// downloading, and the asset status alone can say `supported` for a model that is in fact
  /// usable. So a locale that is not reported installed goes through one setup, which asks for
  /// the request and downloads only if there is one; its success is remembered.
  actor SpeechAssets {
    /// The framework calls, replaced in tests.
    struct System: Sendable {
      var isAvailable: @Sendable () -> Bool
      /// The supported locale for the app's language tag, or nil.
      var locale: @Sendable (String) async -> Locale?
      var isInstalled: @Sendable (Locale) async -> Bool
      /// Asks for an installation request and runs it when there is one.
      var install: @Sendable (Locale) async throws -> Void
    }

    static let downloading = "Downloading speech model"
    static let failed = "Speech model download failed. Dictate or reopen Settings to try again."

    private let system: System
    private let changes: Changes
    /// The one installation running, which may outlive a provider switch.
    private var installation: Task<Void, Never>?
    /// Locales whose setup finished, so their models are usable.
    private var prepared: Set<Locale> = []
    /// The locale whose last installation failed. The next check reports it once, then retries.
    private var failure: Locale?

    init(system: System, changes: Changes) {
      self.system = system
      self.changes = changes
    }

    /// Whether transcription can run in this language now. Starts the installation it needs
    /// without waiting for it.
    func check(language: String) async -> ServiceState {
      guard system.isAvailable() else { return .unavailable("This Mac can't transcribe on device") }
      guard let locale = await system.locale(language) else {
        return .unavailable("On-device transcription doesn't support this language")
      }
      let installed = await system.isInstalled(locale)
      // Read after the awaits, so a setup that ended meanwhile counts and is not repeated.
      if installed || prepared.contains(locale) { return .ready }
      if installation != nil { return .waiting(Self.downloading) }
      if failure == locale {
        failure = nil
        return .unavailable(Self.failed)
      }
      install(locale)
      return .waiting(Self.downloading)
    }

    /// Runs in its own task, so a caller's cancelled check leaves it running.
    private func install(_ locale: Locale) {
      installation = Task { [system] in
        let succeeded = (try? await system.install(locale)) != nil
        finish(locale, succeeded: succeeded)
      }
      changes.send()
    }

    private func finish(_ locale: Locale, succeeded: Bool) {
      installation = nil
      if succeeded { prepared.insert(locale) } else { failure = locale }
      changes.send()
    }
  }
}

extension Apple.SpeechAssets.System {
  static let live = Self(
    isAvailable: { SpeechTranscriber.isAvailable },
    locale: { await Apple.Transcriber.supportedLocale(for: $0) },
    isInstalled: { locale in
      await AssetInventory.status(forModules: [Apple.Transcriber.module(for: locale)]) == .installed
    },
    install: { locale in
      let request = try await AssetInventory.assetInstallationRequest(
        supporting: [Apple.Transcriber.module(for: locale)])
      try await request?.downloadAndInstall()
    })
}
