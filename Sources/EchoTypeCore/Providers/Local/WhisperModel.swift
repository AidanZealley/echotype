import FluidAudio
import Foundation
import Synchronization
@preconcurrency import WhisperKit

/// The loaded Whisper runtime, shared by every session. WhisperKit mutates shared decoder
/// filters and progress during calls, so one session decodes at a time: starting another stops and joins the last.
final class WhisperModel: @unchecked Sendable {
  static let sampleRate = WhisperKit.sampleRate

  /// WhisperKit skips seek windows shorter than one second, so short input is padded with silence.
  private static let minimumSamples = 3 * sampleRate / 2
  /// Prompt tokens for keyterms. WhisperKit allows 111 and the decoder's 224-token context is
  /// shared with the text, so this leaves room for about 30 s of speech.
  private static let promptTokens = 64

  private let kit: WhisperKit
  /// The voice activity model that gates decoding, shared with the Parakeet candidates.
  let voice: VadManager
  private let session = Mutex<WhisperTranscriber?>(nil)

  private init(kit: WhisperKit, voice: VadManager) {
    self.kit = kit
    self.voice = voice
  }

  /// Loads the models from their installed directories, never through WhisperKit's downloader or
  /// the hub, then decodes a little silence so the first dictation does not pay for warming.
  static func load(models: URL, tokenizer: URL, voiceActivity: URL) async throws -> WhisperModel {
    let localTokenizer = try await WhisperLocalTokenizer.load(from: tokenizer)
    let kit = try await WhisperKit(
      WhisperKitConfig(
        modelFolder: models.appending(path: WhisperManifests.folder).path,
        verbose: false, logLevel: .none, load: false, download: false))
    kit.tokenizer = localTokenizer
    try await kit.loadModels()
    // Supplying a tokenizer skips WhisperKit's variant setup as well as its Hub fallback.
    // This candidate is large-v3, whose 51866-token vocabulary is multilingual.
    guard kit.textDecoder.logitsSize == 51866 else {
      throw WhisperError.tokenizerUnavailable()
    }
    kit.textDecoder.isModelMultilingual = true
    let model = WhisperModel(kit: kit, voice: try await WhisperVoiceWatcher.load(from: voiceActivity))
    _ = try await model.decode([Float](repeating: 0, count: 2 * sampleRate), language: "en", prompt: [])
    return model
  }

  /// Opens a session on the shared models, after stopping the last one.
  func start(_ request: TranscriptionRequest) async throws -> any LiveTranscriber {
    if let previous = session.withLock({ $0 }) {
      previous.close()
      await previous.waitForClose()
    }
    let transcriber = WhisperTranscriber(
      model: self, language: request.language, prompt: prompt(for: request.keyterms))
    session.withLock { $0 = transcriber }
    return transcriber
  }

  /// Decodes `audio` and returns its non-empty segments. `prompt` conditions the decoder on
  /// vocabulary, and is empty for none.
  ///
  /// Two of WhisperKit's defaults are off. Its first-token confidence check ends a window with
  /// no text when the first word is uncertain, which a window cut mid-sentence often is: with it
  /// on, spans of speech were lost from the long dictation samples. Its temperature fallback
  /// retries a failed window up to five times, which took up to ten seconds in a debug build and
  /// mostly returned nothing again. Audio is decoded again every second anyway, so the next
  /// decode is the retry.
  func decode(_ audio: [Float], language: String, prompt: [Int]) async throws -> [WhisperSegment] {
    let padded = audio + [Float](repeating: 0, count: max(0, Self.minimumSamples - audio.count))
    let options = DecodingOptions(
      language: language, temperatureFallbackCount: 0, skipSpecialTokens: true,
      promptTokens: prompt.isEmpty ? nil : prompt, firstTokenLogProbThreshold: nil)
    let results = try await kit.transcribe(audioArray: padded, decodeOptions: options)
    return results.flatMap(\.segments).compactMap { segment in
      let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.isEmpty ? nil : WhisperSegment(text: text, end: Double(segment.end))
    }
  }

  /// The keyterms as a comma-separated list, the form Whisper's own prompts take, cut to the
  /// token budget.
  private func prompt(for keyterms: [String]) -> [Int] {
    guard let tokenizer = kit.tokenizer, !keyterms.isEmpty else { return [] }
    return Array(tokenizer.encode(text: " " + keyterms.joined(separator: ", ")).prefix(Self.promptTokens))
  }
}
