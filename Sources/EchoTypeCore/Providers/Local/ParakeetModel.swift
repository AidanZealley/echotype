@preconcurrency import CoreML
import FluidAudio
import Foundation
import OSLog
import Synchronization

/// The loaded Parakeet Unified runtime, shared by every session: the streaming recogniser, the
/// voice activity model that marks utterances and, for keyterm boosting, the CTC spotting model.
/// Sessions share the weights and nothing else: each starts from a reset recogniser. The CTC
/// model always loads with the rest, so every session behaves the same, but it boosts only a
/// session with saved keyterms, since boosting slows finalising.
final class ParakeetModel: Sendable {
  typealias Start = @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber
  static let sampleRate = 16_000
  private static let logger = Logger(subsystem: "com.aidanzealley.echotype", category: "ParakeetModel")

  let asr: StreamingUnifiedAsrManager
  let vad: VadManager
  /// Nil when keyterm boosting is unavailable.
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
    var phaseStart = ProcessInfo.processInfo.systemUptime
    // The 640 ms configuration: 70 frames of left context, 560 ms chunks, 80 ms of look-ahead.
    let asr = StreamingUnifiedAsrManager(
      config: UnifiedConfig(leftFrames: 70, chunkFrames: 7, rightFrames: 1), encoderPrecision: .int8)
    try await asr.loadModels(from: unified)
    logLoadPhase("unified-load", since: phaseStart)

    phaseStart = ProcessInfo.processInfo.systemUptime
    let vadConfiguration = MLModelConfiguration()
    vadConfiguration.computeUnits = VadConfig.default.computeUnits
    let vadModel = try await MLModel.load(
      contentsOf: voiceActivity.appending(path: ModelNames.VAD.sileroVadFile), configuration: vadConfiguration)
    let vad = VadManager(config: .default, vadModel: vadModel)
    logLoadPhase("vad-load", since: phaseStart)

    var ctc: CtcModels?
    if let keywordSpotting {
      phaseStart = ProcessInfo.processInfo.systemUptime
      // Keyterm boosting reads the CTC model's `tokenizer.json` from FluidAudio's own cache
      // folder, whichever way the model was loaded, so that folder points at the store's copy.
      try link(CtcModels.defaultCacheDirectory(), to: keywordSpotting)
      ctc = try await CtcModels.loadDirect(from: keywordSpotting)
      logLoadPhase("ctc-load", since: phaseStart)
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
    if !request.keyterms.isEmpty, let ctc {
      boosting = try await Self.boosting(request.keyterms, models: ctc)
    }
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
    var phaseStart = ProcessInfo.processInfo.systemUptime
    let silence = [Float](repeating: 0, count: 2 * Self.sampleRate)
    try await asr.appendAudio(ParakeetTranscriber.buffer(of: silence))
    try await asr.processBufferedAudio()
    _ = try await asr.finish()
    try await asr.reset()
    Self.logLoadPhase("unified-warm", since: phaseStart)
    phaseStart = ProcessInfo.processInfo.systemUptime
    _ = try await vad.processStreamingChunk(
      Array(silence.prefix(VadManager.chunkSize)), state: vad.makeStreamState())
    Self.logLoadPhase("vad-warm", since: phaseStart)
    if let ctc {
      phaseStart = ProcessInfo.processInfo.systemUptime
      // Any word compiles the model; this one is not a keyterm.
      let word = TokenTiming(token: " warm", tokenId: 0, startTime: 0.2, endTime: 0.6, confidence: 1)
      let boosting = try await Self.boosting(["warm"], models: ctc)
      _ = await boosting.rescore(text: " warm", tokenTimings: [word], audioSamples: silence)
      Self.logLoadPhase("ctc-warm", since: phaseStart)
    }
  }

  // Keep loading and first inference separate: CoreML can build its execution plan during
  // either phase, and a total readiness time cannot tell us which stage needs attention.
  private static func logLoadPhase(_ phase: String, since start: TimeInterval) {
    let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
    logger.info("phase=\(phase, privacy: .public) duration_ms=\(milliseconds, privacy: .public)")
  }
}
