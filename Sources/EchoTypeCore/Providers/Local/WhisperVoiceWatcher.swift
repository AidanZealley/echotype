@preconcurrency import CoreML
import FluidAudio
import Foundation

/// Speech evidence and utterance ends for one session, from the Silero voice activity model that
/// `VadManager` runs. FluidAudio's defaults apply: voice at probability 0.85, and an utterance
/// ends after 0.75 s below the lower threshold.
struct WhisperVoiceWatcher {
  /// Loads the model from its installed directory, never through FluidAudio's downloader.
  static func load(from directory: URL) async throws -> VadManager {
    let configuration = MLModelConfiguration()
    configuration.computeUnits = VadConfig.default.computeUnits
    let model = try await MLModel.load(
      contentsOf: directory.appending(path: ModelNames.VAD.sileroVadFile), configuration: configuration)
    return VadManager(config: .default, vadModel: model)
  }

  private let vad: VadManager
  private var state = VadStreamState.initial()
  /// Samples the model has not seen, which takes `VadManager.chunkSize` at a time.
  private var backlog: [Float] = []

  init(_ vad: VadManager) {
    self.vad = vad
  }

  /// Inspects the tail left below the model's chunk size before the session ends.
  mutating func finish() async throws -> Bool {
    guard !backlog.isEmpty else { return false }
    return try await hear([Float](repeating: 0, count: VadManager.chunkSize - backlog.count)).speech
  }

  /// Whether any chunk in `samples` was voice, and whether any ended an utterance.
  mutating func hear(_ samples: [Float]) async throws -> (speech: Bool, ended: Bool) {
    backlog += samples
    let threshold = await vad.config.defaultThreshold
    var speech = false
    var ended = false
    while backlog.count >= VadManager.chunkSize {
      let chunk = Array(backlog.prefix(VadManager.chunkSize))
      backlog.removeFirst(VadManager.chunkSize)
      let result = try await vad.processStreamingChunk(chunk, state: state)
      state = result.state
      speech = speech || result.probability >= threshold
      ended = ended || result.event?.isEnd == true
    }
    return (speech, ended)
  }
}
