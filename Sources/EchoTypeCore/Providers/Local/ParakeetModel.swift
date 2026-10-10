@preconcurrency import CoreML
import FluidAudio
import Foundation
import Synchronization

/// The loaded Parakeet Unified runtime, shared by every session: the streaming recogniser, the
/// voice activity model that marks utterances and, for keyterm boosting, the CTC spotting model.
/// Sessions share the weights and nothing else: each starts from a reset recogniser.
final class ParakeetModel: Sendable {
  static let sampleRate = 16_000

  let asr: StreamingUnifiedAsrManager
  let vad: VadManager
  /// Nil when keyterm boosting is off.
  private let ctc: CtcModels?
  private let session = Mutex<ParakeetTranscriber?>(nil)

  private init(asr: StreamingUnifiedAsrManager, vad: VadManager, ctc: CtcModels?) {
    self.asr = asr
    self.vad = vad
    self.ctc = ctc
  }

  /// Loads the models from their installed directories, never through FluidAudio's downloader,
  /// then runs a little silence through each so the first dictation does not pay for compiling.
  static func load(unified: URL, voiceActivity: URL, keywordSpotting: URL?) async throws -> ParakeetModel {
    // The 640 ms configuration: 70 frames of left context, 560 ms chunks, 80 ms of look-ahead.
    let asr = StreamingUnifiedAsrManager(
      config: UnifiedConfig(leftFrames: 70, chunkFrames: 7, rightFrames: 1), encoderPrecision: .int8)
    try await asr.loadModels(from: unified)

    let vadConfiguration = MLModelConfiguration()
    vadConfiguration.computeUnits = VadConfig.default.computeUnits
    let vadModel = try await MLModel.load(
      contentsOf: voiceActivity.appending(path: ModelNames.VAD.sileroVadFile), configuration: vadConfiguration)
    let vad = VadManager(config: .default, vadModel: vadModel)

    var ctc: CtcModels?
    if let keywordSpotting {
      // Keyterm boosting reads the CTC model's `tokenizer.json` from FluidAudio's own cache
      // folder, whichever way the model was loaded, so that folder points at the store's copy.
      let tokenizerCache = CtcModels.defaultCacheDirectory()
      try linkFolder(at: tokenizerCache, to: keywordSpotting)
      guard tokenizerCache.resolvingSymlinksInPath().standardizedFileURL == keywordSpotting.resolvingSymlinksInPath().standardizedFileURL
      else { throw ProviderError.failed("The Parakeet tokenizer cache belongs to another installation. Resolve the cache conflict before preparing Dictation.") }
      ctc = try await CtcModels.loadDirect(from: keywordSpotting)
    }
    let model = ParakeetModel(asr: asr, vad: vad, ctc: ctc)
    try await model.warm()
    return model
  }

  /// Opens a session on the shared models, after stopping the last one: the recogniser holds one
  /// session's state, so two cannot run at once.
  func start(_ request: TranscriptionRequest) async throws -> any LiveTranscriber {
    if let previous = session.withLock({ $0 }) {
      previous.close()
      await previous.waitForClose()
    }
    var boosting: VocabularyBoostingSession?
    if let ctc { boosting = try await Self.boosting(request.keyterms, models: ctc) }
    let transcriber = ParakeetTranscriber(model: self, boosting: boosting)
    session.withLock { $0 = transcriber }
    return transcriber
  }

  private static func boosting(_ keyterms: [String], models: CtcModels) async throws -> VocabularyBoostingSession {
    try await VocabularyBoostingSession(
      vocabulary: CustomVocabularyContext(terms: keyterms.map { CustomVocabularyTerm(text: $0) }),
      ctcModels: models, config: VocabularyBoostingSession.itnDefaultConfig)
  }

  private func warm() async throws {
    let silence = [Float](repeating: 0, count: 2 * Self.sampleRate)
    try await asr.appendAudio(ParakeetTranscriber.buffer(of: silence))
    try await asr.processBufferedAudio()
    _ = try await asr.finish()
    try await asr.reset()
    _ = try await vad.processStreamingChunk(
      Array(silence.prefix(VadManager.chunkSize)), state: vad.makeStreamState())
    if let ctc {
      let word = TokenTiming(token: " echo", tokenId: 0, startTime: 0.2, endTime: 0.6, confidence: 1)
      let boosting = try await Self.boosting(["EchoType"], models: ctc)
      _ = await boosting.rescore(text: " echo", tokenTimings: [word], audioSamples: silence)
    }
  }
}
