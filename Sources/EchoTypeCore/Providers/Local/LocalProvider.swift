import Foundation

/// Fixed offline transcription, cleanup and speech with explicit per-feature setup.
enum LocalProvider {
  static func make() -> Provider {
    let store = LocalModels.store
    let transcriber = LocalModel<ParakeetModel.Start>(
      manifests: LocalModels.transcription, loadingMessage: "Loading the transcription model", store: store
    ) { directories in
      try await ParakeetModel.load(unified: directories[0], voiceActivity: directories[1], keywordSpotting: directories[2]).start
    }
    let reviser = LocalModel(
      manifests: [LocalModels.cleanup], loadingMessage: "Loading the cleanup model", store: store
    ) { directories in try await CleanupModel.load(from: directories[0]) }
    let speaker = LocalModel<KokoroModel.Speak>(
      manifests: LocalModels.speech, loadingMessage: "Loading the voice model", store: store
    ) { directories in try await KokoroModel.load(from: directories[0]).speak }
    let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: reviser, voice: speaker)
    return Provider(
      id: "local", name: "Local", summary: "Runs English models on this Mac. Works offline after setup.",
      credential: .none, languages: [.english],
      transcription: TranscriptionService(keytermLimit: 100) { request in
        guard let start = transcriber.loaded else { throw ProviderError.unavailable }
        return try await start(request)
      },
      voice: VoiceService(voices: KokoroModel.voices, speedRange: 0.5...2, maximumCharacters: 60_000) { request in
        guard let speak = speaker.loaded else { return Unavailable() }
        return speak(request)
      },
      cleanup: CleanupService { request in
        guard let model = reviser.loaded else { throw ProviderError.unavailable }
        return try await model.revise(request)
      },
      readiness: Readiness(
        check: { _ in
          ServiceReadiness(
            transcription: transcriber.check(),
            voice: speaker.check(),
            cleanup: reviser.check())
        },
        changes: { merged([transcriber.changes(), reviser.changes(), speaker.changes()]) },
        prepare: { try await lifecycle.prepare($0) }), localSetup: lifecycle.controls)
  }

  /// One stream that yields when any of `streams` does.
  private static func merged(_ streams: [AsyncStream<Void>]) -> AsyncStream<Void> {
    let (merged, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let followers = streams.map { stream in Task { for await _ in stream { continuation.yield() } } }
    continuation.onTermination = { _ in followers.forEach { $0.cancel() } }
    return merged
  }

  private struct Unavailable: SpeechStream {
    func next() async throws -> SpeechAudio? { throw ProviderError.unavailable }
    func cancel() {}
  }
}
