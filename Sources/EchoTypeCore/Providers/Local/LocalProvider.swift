import Foundation

/// The experimental local provider: models that run on this Mac with no key or account.
/// A service with no candidate is neither prepared nor offered.
enum LocalProvider {
  static func make(
    transcription: TranscriptionCandidate?, cleanup: CleanupCandidate?, voice: VoiceCandidate?
  ) -> Provider {
    let store = LocalCandidates.store
    let transcriber = transcription.map {
      LocalModel(
        manifests: $0.manifests, loadingMessage: "Loading the transcription model", store: store,
        load: $0.load)
    }
    let reviser = cleanup.map { candidate in
      LocalModel(
        manifests: [candidate.manifest], loadingMessage: "Loading the cleanup model", store: store
      ) { directories in
        try await CleanupModel.load(from: directories[0], templateContext: candidate.templateContext)
      }
    }
    let speaker = voice.map {
      LocalModel(manifests: $0.manifests, loadingMessage: "Loading the voice model", store: store, load: $0.load)
    }
    return Provider(
      id: "local", name: "Local", summary: "Experimental. Runs models on this Mac.",
      credential: .none, languages: [.english],
      transcription: TranscriptionService(keytermLimit: transcription?.keytermLimit ?? 1) { request in
        guard let start = transcriber?.loaded else { throw ProviderError.unavailable }
        return try await start(request)
      },
      voice: voice.map { candidate in
        VoiceService(
          voices: candidate.voices, speedRange: candidate.speedRange, maximumCharacters: candidate.maximumCharacters
        ) { request in
          guard let speak = speaker?.loaded else { return Unavailable() }
          return speak(request)
        }
      } ?? unavailableVoice,
      cleanup: reviser.map { reviser in
        CleanupService { request in
          guard let model = reviser.loaded else { throw ProviderError.unavailable }
          return try await model.revise(request)
        }
      },
      readiness: Readiness(
        check: { _ in
          ServiceReadiness(
            transcription: transcriber?.check() ?? .unavailable("No transcription model is selected."),
            voice: speaker?.check() ?? .unavailable("No voice model is selected."),
            cleanup: reviser?.check())
        },
        changes: { merged([transcriber?.changes(), reviser?.changes(), speaker?.changes()].compactMap { $0 }) }))
  }

  /// One stream that yields when any of `streams` does.
  private static func merged(_ streams: [AsyncStream<Void>]) -> AsyncStream<Void> {
    let (merged, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let followers = streams.map { stream in Task { for await _ in stream { continuation.yield() } } }
    continuation.onTermination = { _ in followers.forEach { $0.cancel() } }
    return merged
  }

  private static let unavailableVoice = VoiceService(
    voices: [Voice(id: "unavailable", name: "Not available")], speedRange: 1...1,
    maximumCharacters: 1
  ) { _ in Unavailable() }

  private struct Unavailable: SpeechStream {
    func next() async throws -> SpeechAudio? { throw ProviderError.unavailable }
    func cancel() {}
  }
}
