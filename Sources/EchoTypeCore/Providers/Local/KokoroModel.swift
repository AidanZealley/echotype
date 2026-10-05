import FluidAudio
import Foundation

/// The loaded Kokoro-82M runtime, shared by every reading: FluidAudio's seven-stage Core ML chain
/// and its English frontend. Readings share the weights and nothing else; each synthesis call is
/// independent.
final class KokoroModel: Sendable {
  /// Emma (UK) first, as the default, then Heart (US).
  static let voices = [Voice(id: "bf_emma", name: "Emma"), Voice(id: "af_heart", name: "Heart")]

  private let manager: KokoroAneManager

  private init(manager: KokoroAneManager) {
    self.manager = manager
  }

  /// Loads the models from the installed directory, never through FluidAudio's downloader, then
  /// reads one word so the first reading does not pay for compiling.
  ///
  /// FluidAudio finds every file by existence alone, so with the links below in place it fetches
  /// nothing. It looks for the chain in `<directory>/kokoro-82m-coreml/ANE`, so the directory gets
  /// a link to itself under that name. Its English G2P model and lexicon are read from its own
  /// cache folder whatever directory the chain came from, so that folder is linked to the store's
  /// copy, as Parakeet's tokenizer is.
  static func load(from directory: URL) async throws -> KokoroModel {
    try linkFolder(at: directory.appending(path: "kokoro-82m-coreml"), to: directory)
    try linkFolder(
      at: TtsCacheDirectory.ensure().appending(path: KokoroAneResourceDownloader.modelsSubdirectory)
        .appending(path: Repo.kokoro.folderName),
      to: directory)
    try convertVoicePacks(in: directory)

    let manager = KokoroAneManager(directory: directory)
    try await manager.initialize(preloadVoices: Set(voices.map(\.id)))
    _ = try await manager.synthesizeDetailed(text: "Ready.", voice: voices[0].id)
    return KokoroModel(manager: manager)
  }

  /// One reading of the request's text, synthesised an utterance at a time as it is pulled. A
  /// voice this model does not offer reads as the first, since FluidAudio would download it.
  func speak(_ request: SpeechRequest) -> any SpeechStream {
    let voice = Self.voices.contains { $0.id == request.voice } ? request.voice : Self.voices[0].id
    return KokoroSpeech(text: request.text) { [manager] utterance in
      let result = try await manager.synthesizeDetailed(text: utterance, voice: voice, speed: Float(request.speed))
      return SpeechAudio(sampleRate: result.sampleRate, samples: result.samples)
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
