import FluidAudio
import Foundation

/// The loaded Kokoro-82M runtime, shared by every reading. FluidAudio runs the seven-stage
/// Core ML chain; the bundled eSpeak frontend supplies phonemes for each utterance.
final class KokoroModel: Sendable {
  /// Emma (UK) first, as the default, then Heart (US).
  static let voices = [Voice(id: "bf_emma", name: "Emma"), Voice(id: "af_heart", name: "Heart")]

  private let manager: KokoroAneManager

  private init(manager: KokoroAneManager) {
    self.manager = manager
  }

  /// Load only the installed Core ML chain and retained voices. The public model-store
  /// API bypasses manager.initialize(), which prepares unused English G2P assets.
  static func load(from directory: URL) async throws -> KokoroModel {
    // FluidAudio's store can download missing files. Reject incomplete installations
    // before entering it, including when a caller bypasses EchoType's setup checks.
    guard KokoroManifests.english.files.allSatisfy({
      FileManager.default.fileExists(atPath: directory.appending(path: $0.path).path)
    }) else { throw ProviderError.failed("The installed speech models are incomplete. Open Settings to prepare them.") }
    // FluidAudio appends this repository name and ANE to the supplied directory.
    let repository = directory.appending(path: "kokoro-82m-coreml")
    try linkFolder(at: repository, to: directory)
    guard repository.resolvingSymlinksInPath().standardizedFileURL.path
      == directory.resolvingSymlinksInPath().standardizedFileURL.path
    else {
      throw ProviderError.failed("The speech model folder contains a conflicting kokoro-82m-coreml directory. Resolve that folder conflict before preparing speech.")
    }
    try convertVoicePacks(in: directory)

    let store = KokoroAneModelStore(directory: directory)
    try await store.loadIfNeeded()
    for voice in voices { _ = try await store.voicePack(voice.id) }
    let manager = KokoroAneManager(modelStore: store)
    let ready = try await KokoroEnglishFrontend.shared.phonemes(for: "Ready.", voice: voices[0].id)
    _ = try await manager.synthesizeFromPhonemesDetailed(ready, voice: voices[0].id)
    return KokoroModel(manager: manager)
  }

  /// One reading of the request's text, synthesised an utterance at a time as it is pulled. A
  /// voice this model does not offer reads as the first, since FluidAudio would download it.
  func speak(_ request: SpeechRequest) -> any SpeechStream {
    let voice = Self.voices.contains { $0.id == request.voice } ? request.voice : Self.voices[0].id
    return KokoroSpeech(text: KokoroText.prepare(request.text)) { [manager] utterance in
      // Retain our written-form normalization, then use phrase-aware English G2P.
      let normalized = NemoTextNormalizer.normalize(utterance, language: .english)
      let phonemes = try await KokoroEnglishFrontend.shared.phonemes(for: normalized, voice: voice)
      var samples: [Float] = []
      var sampleRate = 24_000
      for chunk in KokoroEnglishFrontend.chunks(phonemes) {
        try Task.checkCancellation()
        let result = try await manager.synthesizeFromPhonemesDetailed(chunk, voice: voice, speed: Float(request.speed))
        samples.append(contentsOf: result.samples)
        sampleRate = result.sampleRate
      }
      return SpeechAudio(sampleRate: sampleRate, samples: samples)
    }
  }

  /// FluidAudio ships only Heart pre-converted. Other voices are pinned as their Kokoro-82M JSON
  /// packs and converted here, with FluidAudio's own converter, to the `.bin` it loads from
  /// `ANE/`. The converted file is written into the model's directory once and left there; the
  /// pinned JSON stays as verified.
  private static func convertVoicePacks(in directory: URL) throws {
    for voice in voices {
      let pack = directory.appending(path: "ANE/\(voice.id).bin")
      guard !FileManager.default.fileExists(atPath: pack.path) else { continue }
      let json = try Data(contentsOf: directory.appending(path: "voices/\(voice.id).json"))
      try KokoroAneVoicePack.load(fromJSON: json).binaryData.write(to: pack, options: .atomic)
    }
  }
}
