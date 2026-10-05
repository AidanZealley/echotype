import Foundation

/// The candidates one build of the local provider uses, by name. This is the spike's only
/// selection point: change `build` and rebuild to try another combination. The bench can
/// override it per run with `--candidate`. A nil field means the provider neither prepares nor
/// offers that service.
public struct LocalSelection: Codable, Equatable, Sendable {
  public var transcription: String?
  public var cleanup: String?
  public var voice: String?

  public init(transcription: String? = nil, cleanup: String? = nil, voice: String? = nil) {
    self.transcription = transcription
    self.cleanup = cleanup
    self.voice = voice
  }

  public static let build = LocalSelection(transcription: "parakeet-unified", cleanup: "qwen3-4b-2507", voice: "kokoro")
}

/// A transcription model: the pinned files it loads from and the runtime that loads them. A new
/// runtime adds a candidate here, with its manifests and a loader.
struct TranscriptionCandidate: Sendable {
  /// Opens one session on the loaded models.
  typealias Start = @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber

  let name: String
  /// Every model the candidate needs, downloaded together and passed to `load` in this order.
  let manifests: [ModelManifest]
  /// What the model's keyterm boosting supports.
  let keytermLimit: Int
  /// Loads and warms the models from their installed directories.
  let load: @Sendable ([URL]) async throws -> Start
}

/// A cleanup model: the pinned files MLX Swift LM loads it from, and how its chat template is
/// driven. Both candidates share one implementation.
struct CleanupCandidate: Sendable {
  let name: String
  let manifest: ModelManifest
  /// Extra variables for the chat template, such as the flag that turns thinking off.
  let templateContext: [String: any Sendable]
}

/// A read-aloud model: the pinned files it loads from, what its voice service offers, and the
/// runtime that loads them.
struct VoiceCandidate: Sendable {
  /// Starts one reading on the loaded model.
  typealias Speak = @Sendable (SpeechRequest) -> any SpeechStream

  let name: String
  /// Every model the candidate needs, downloaded together and passed to `load` in this order.
  let manifests: [ModelManifest]
  /// The first is the default.
  let voices: [Voice]
  let speedRange: ClosedRange<Double>
  let maximumCharacters: Int
  /// Loads and warms the models from their installed directories.
  let load: @Sendable ([URL]) async throws -> Speak
}

enum LocalCandidates {
  /// Parakeet Unified EN 0.6B, 640 ms, without keyterm boosting, so its limit is the built-in term
  /// alone. Text commits when the voice activity model ends an utterance.
  static let parakeetUnified = TranscriptionCandidate(
    name: "parakeet-unified",
    manifests: [ParakeetManifests.unified, ParakeetManifests.voiceActivity], keytermLimit: 1
  ) { directories in
    try await ParakeetModel.load(
      unified: directories[0], voiceActivity: directories[1], keywordSpotting: nil
    ).start
  }

  /// The same model with the CTC spotting model rescoring each segment against the request's
  /// keyterms, and text committed only once rescored. FluidAudio sets no limit: its rescorer
  /// tightens its thresholds above 10 terms and again above 100 and scans the terms linearly,
  /// so 100 is the most that keeps the tuned thresholds and matches what Apple and xAI accept.
  static let parakeetUnifiedKeyterms = TranscriptionCandidate(
    name: "parakeet-unified-keyterms",
    manifests: [ParakeetManifests.unified, ParakeetManifests.voiceActivity, ParakeetManifests.keywordSpotting],
    keytermLimit: 100
  ) { directories in
    try await ParakeetModel.load(
      unified: directories[0], voiceActivity: directories[1], keywordSpotting: directories[2]
    ).start
  }

  /// Whisper large-v3-turbo, 626 MB Core ML, decoding windows of audio again as they grow.
  /// Keyterms go in as Whisper's prompt, which fits about a dozen.
  static let whisperTurbo = TranscriptionCandidate(
    name: "whisper-turbo",
    manifests: [WhisperManifests.turbo, WhisperManifests.tokenizer, ParakeetManifests.voiceActivity],
    keytermLimit: 12
  ) { directories in
    try await WhisperModel.load(models: directories[0], tokenizer: directories[1], voiceActivity: directories[2]).start
  }

  static let transcription = [parakeetUnified, parakeetUnifiedKeyterms, whisperTurbo]

  /// Qwen3-4B-Instruct-2507 is nonthinking by design, so its template needs no flag. Apache 2.0:
  /// the conversion's card and the upstream repository both say so, and upstream ships a LICENSE.
  static let qwen3 = CleanupCandidate(
    name: "qwen3-4b-2507",
    manifest: ModelManifest(
      name: "qwen3-4b-instruct-2507-4bit", repository: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
      revision: "50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b", license: "Apache-2.0",
      files: [
        .init(
          path: "config.json", size: 938,
          sha256: "574349e5a343236546fda55e4744a76e181f534182d7dc60ff1bad7e7a502849"),
        .init(
          path: "generation_config.json", size: 238,
          sha256: "835fffe355c9438e7a25be099b3fccaa98350b83451f9fd2d99512e74f1ade48"),
        .init(
          path: "tokenizer_config.json", size: 5440,
          sha256: "4397cc477eb6d79715ccd2000accd6b3531928f30029665832fa1b255f24d2b9"),
        .init(
          path: "chat_template.jinja", size: 4040,
          sha256: "40c21f34cf67d8c760ef72f8ad3ae5afad514299d4b06e91dd9a8d705af7b541"),
        .init(
          path: "tokenizer.json", size: 11_422_654,
          sha256: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"),
        .init(
          path: "model.safetensors", size: 2_263_022_417,
          sha256: "2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f"),
      ]),
    templateContext: [:])

  /// SmolLM3 thinks unless its template's `enable_thinking` is false. Apache 2.0, as the
  /// conversion's card says and the upstream card confirms (upstream has no LICENSE file).
  static let smollm3 = CleanupCandidate(
    name: "smollm3-3b",
    manifest: ModelManifest(
      name: "smollm3-3b-4bit", repository: "mlx-community/SmolLM3-3B-4bit",
      revision: "d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce", license: "Apache-2.0",
      files: [
        .init(
          path: "config.json", size: 2394,
          sha256: "6d0046fc9fc07c74601b25107b8ff96077dc9c63941492f2856743eabc2a3d99"),
        .init(
          path: "generation_config.json", size: 182,
          sha256: "3458d62b3f9654f4bbe285223b0f4e5a1e67cae61c92bb6aeaadf04468bf9e01"),
        .init(
          path: "tokenizer_config.json", size: 50387,
          sha256: "59a64b39f05ee0acf7479bbccf99a44d9e481c1a4a494eb03838ae3c35eb29be"),
        .init(
          path: "chat_template.jinja", size: 5499,
          sha256: "0dab472abbdc499c8d82acae3ad6e8404f672d2d50d9df582181daf062f66eb7"),
        .init(
          path: "tokenizer.json", size: 17_208_819,
          sha256: "7b6a500b662a34eb3f0374db856ba4ad7de4c81040571d78dc0d357238930005"),
        .init(
          path: "model.safetensors", size: 1_730_051_993,
          sha256: "d501e6193d7eb84e10d3c377007d1fc4b4b2fa08799dd10fa4f6a75033334a70"),
      ]),
    templateContext: ["enable_thinking": false])

  static let cleanup = [qwen3, smollm3]

  /// Kokoro-82M v1.0 through FluidAudio's Core ML chain. The speed range is the one Kokoro's own
  /// demo offers. Text is synthesised as it is pulled, so the limit only guards against a runaway
  /// selection, matching the other providers'.
  static let kokoro = VoiceCandidate(
    name: "kokoro", manifests: [KokoroManifests.english], voices: KokoroModel.voices, speedRange: 0.5...2,
    maximumCharacters: 60_000
  ) { directories in
    try await KokoroModel.load(from: directories[0]).speak
  }

  /// Qwen3-TTS-12Hz-1.7B-CustomVoice, MLX four-bit, through MLX Audio Swift: every preset, plain
  /// and with the fixed style prompt. It has no speed control, and time-stretching would change
  /// the voice being judged, so it reads at normal speed only.
  static let qwen3TTS = qwenTTS(name: "qwen3-tts", manifest: QwenTTSManifests.large, styled: true)

  /// The same implementation with the 0.6B weights, which have no instruction control, so its
  /// presets read plain only.
  static let qwen3TTSSmall = qwenTTS(name: "qwen3-tts-0.6b", manifest: QwenTTSManifests.small, styled: false)

  private static func qwenTTS(name: String, manifest: ModelManifest, styled: Bool) -> VoiceCandidate {
    let voices = QwenTTSModel.voices(styled: styled)
    return VoiceCandidate(
      name: name, manifests: [manifest], voices: voices, speedRange: 1...1, maximumCharacters: 60_000
    ) { directories in
      try await QwenTTSModel.load(from: directories[0], voices: voices).speak
    }
  }

  static let voice = [kokoro, qwen3TTS, qwen3TTSSmall]

  /// The one store in the process, so a download is never started twice.
  static let store = ModelStore()
}

private struct UnknownCandidate: LocalizedError {
  let service: String
  let name: String
  let known: [String]

  var errorDescription: String? {
    "Unknown \(service) candidate \(name). Known: \(known.joined(separator: ", "))."
  }
}

extension Provider {
  /// The experimental local provider with the build's candidates.
  public static let local = try! local(.build)  // The build's names are candidates.

  /// The local provider with `selection`'s candidates, which only the bench uses. Throws when a
  /// name is not a candidate, listing those that are.
  public static func local(_ selection: LocalSelection) throws -> Provider {
    func find<Candidate>(
      _ service: String, _ name: String?, in candidates: [Candidate], named: KeyPath<Candidate, String>
    ) throws -> Candidate? {
      guard let name else { return nil }
      guard let candidate = candidates.first(where: { $0[keyPath: named] == name }) else {
        throw UnknownCandidate(service: service, name: name, known: candidates.map { $0[keyPath: named] })
      }
      return candidate
    }
    return LocalProvider.make(
      transcription: try find(
        "transcription", selection.transcription, in: LocalCandidates.transcription, named: \.name),
      cleanup: try find("cleanup", selection.cleanup, in: LocalCandidates.cleanup, named: \.name),
      voice: try find("voice", selection.voice, in: LocalCandidates.voice, named: \.name))
  }
}
