import Foundation

/// The experimental local provider: models that run on this Mac with no key or account. Only
/// cleanup exists so far; transcription and read aloud arrive in later slices, so the provider
/// stays out of `Providers.all` until they do.
enum LocalProvider {
  static func make(cleanup candidate: CleanupCandidate) -> Provider {
    let cleanup = LocalCleanup(candidate, store: LocalCandidates.store)
    return Provider(
      id: "local", name: "Local", summary: "Experimental. Runs models on this Mac.",
      credential: .none, languages: [.english],
      transcription: transcription, voice: voice, cleanup: cleanup.service,
      readiness: Readiness(
        check: { _ in
          ServiceReadiness(
            transcription: .unavailable(laterSlice), voice: .unavailable(laterSlice),
            cleanup: cleanup.check())
        },
        changes: { cleanup.changes() }))
  }

  private static let laterSlice = "Local models for this arrive in a later release."

  private static let transcription = TranscriptionService(keytermLimit: 1) { _ in
    throw ProviderError.unavailable
  }

  private static let voice = VoiceService(
    voices: [Voice(id: "unavailable", name: "Not available yet")], speedRange: 1...1,
    maximumCharacters: 1
  ) { _ in Unavailable() }

  private struct Unavailable: SpeechStream {
    func next() async throws -> SpeechAudio? { throw ProviderError.unavailable }
    func cancel() {}
  }
}
