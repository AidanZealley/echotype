import Foundation
import MLX
import MLXAudioTTS
import MLXLMCommon

/// A loaded Qwen3-TTS CustomVoice model, shared by every reading. MLX Audio Swift gives each
/// generation a fresh key-value cache and codec state over the loaded weights, so readings share
/// the weights and nothing else.
final class QwenTTSModel: Sendable {
  /// The fixed style prompt each styled voice adds, as CustomVoice's instruction.
  static let stylePrompt = "Read clearly and naturally, in a calm, warm narration style, at an even pace."
  private static let styledSuffix = "-styled"

  /// The model's nine presets, by the names its configuration uses, English-native first, then in
  /// the order of the model card. Each preset reads plain, and with `stylePrompt` when `styled`.
  /// The 0.6B model has no instruction control, so it offers the plain presets only.
  static func voices(styled: Bool) -> [Voice] {
    let presets = ["Ryan", "Aiden", "Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric", "Ono_Anna", "Sohee"]
    return presets.flatMap { name in
      let plain = Voice(id: name.lowercased(), name: name)
      return styled ? [plain, Voice(id: plain.id + styledSuffix, name: "\(name), styled")] : [plain]
    }
  }

  /// Utterances group whole sentences up to this many Unicode scalars. Generation streams within
  /// an utterance, so the bound sets how much is produced ahead of the reader, not first audio.
  /// See the workstream 3 handoff for how it was chosen.
  private static let utteranceLimit = 250
  /// Audio comes back every this many seconds of speech, four codec steps at 12.5 Hz.
  private static let streamingInterval = 0.32
  /// Cached buffers beyond this are freed, so they do not inflate the process footprint, as for
  /// cleanup. MLX's limit is process-wide.
  private static let bufferCacheLimit = 64 * 1024 * 1024
  /// The conversions' `generation_config.json`, for the talker and the code predictor alike.
  private static let parameters = GenerateParameters(
    maxTokens: 4096, temperature: 0.9, topP: 1, topK: 50, repetitionPenalty: 1.05)

  private let model: Qwen3TTSModel
  private let voices: [Voice]

  private init(model: Qwen3TTSModel, voices: [Voice]) {
    self.model = model
    self.voices = voices
  }

  /// Loads the model from its installed directory, never through MLX Audio Swift's downloader,
  /// then reads one word so the first reading does not pay for compiling kernels.
  ///
  /// The conversion ships only the slow tokenizer files, so on first load MLX Audio Swift writes
  /// `tokenizer.json` beside them and later loads read it. It swallows a tokenizer failure, which
  /// the warm-up then reports.
  static func load(from directory: URL, voices: [Voice]) async throws -> QwenTTSModel {
    Memory.cacheLimit = bufferCacheLimit
    let loaded = QwenTTSModel(model: try await Qwen3TTSModel.fromModelDirectory(directory), voices: voices)
    _ = try await loaded.model.generate(
      text: "Ready.", voice: loaded.prompt(for: voices[0].id), refAudio: nil, refText: nil, language: "English",
      generationParameters: parameters)
    return loaded
  }

  /// One reading of the request's text, generated an utterance at a time as it is pulled. A voice
  /// this model does not offer reads as the first.
  func speak(_ request: SpeechRequest) -> any SpeechStream {
    let prompt = prompt(for: request.voice)
    return QwenTTSSpeech(
      utterances: QwenTTSSpeech.utterances(in: request.text, limit: Self.utteranceLimit),
      sampleRate: model.sampleRate
    ) { [model] utterance in
      let events = model.generateStream(
        text: utterance, voice: prompt, refAudio: nil, refText: nil, language: "English",
        generationParameters: Self.parameters, streamingInterval: Self.streamingInterval)
      return events.compactMap { event in
        if case .audio(let audio) = event { audio.asArray(Float.self) } else { nil }
      }
    }
  }

  /// CustomVoice takes the preset and its instruction as one string, "preset, instruction". It
  /// matches presets case-insensitively.
  private func prompt(for id: String) -> String {
    let voice = voices.first { $0.id == id } ?? voices[0]
    guard voice.id.hasSuffix(Self.styledSuffix) else { return voice.id }
    return "\(voice.id.dropLast(Self.styledSuffix.count)), \(Self.stylePrompt)"
  }
}
