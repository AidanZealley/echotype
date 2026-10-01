import AVFoundation
import EchoTypeCore

@MainActor protocol ReadingPlayback: AnyObject {
  /// Configures playback for the stream's rate. Every scheduled chunk has that rate.
  func start(sampleRate: Int) throws
  func pause()
  func resume()
  func schedule(_ samples: [Float]) async throws
  func finished() async throws
  func stop()
}

/// One reading's playback queue. Completion callbacks carry buffer identities so callbacks
/// delivered after Stop cannot decrement a new queue or resume an obsolete waiter.
@MainActor final class SpeechPlayer: ReadingPlayback {
  struct Output {
    var start: (_ sampleRate: Int) throws -> Void
    var pause: () -> Void
    var resume: () -> Void
    var schedule: ([Float], @escaping @Sendable () -> Void) -> Void
    var stop: () -> Void
  }
  private let output: Output
  private var stopped = true
  private var buffers: [UUID: Int] = [:]
  private(set) var queuedFrames = 0
  /// 500 ms at the stream's rate, including playing audio. Set by `start`.
  private(set) var maximumQueuedFrames = 0
  private var capacity: CheckedContinuation<Void, any Error>?
  private var completion: CheckedContinuation<Void, any Error>?

  init(output: Output) { self.output = output }

  convenience init(onLevel: @escaping @MainActor (Double) -> Void) {
    let audio = PlaybackAudio(onLevel: onLevel)
    self.init(output: .init(start: { try audio.start(sampleRate: $0) }, pause: { audio.pause() },
      resume: { audio.resume() }, schedule: { audio.schedule($0, completion: $1) },
      stop: { audio.stop() }))
  }

  func start(sampleRate: Int) throws {
    try output.start(sampleRate)
    maximumQueuedFrames = sampleRate / 2
    stopped = false
  }
  func pause() { if !stopped { output.pause() } }
  func resume() { if !stopped { output.resume() } }

  func schedule(_ samples: [Float]) async throws {
    guard !samples.isEmpty else { return }
    precondition(stopped || samples.count <= maximumQueuedFrames)
    while !stopped, queuedFrames + samples.count > maximumQueuedFrames {
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { capacity = $0 }
      } onCancel: { Task { @MainActor in self.stop() } }
    }
    try Task.checkCancellation()
    guard !stopped else { throw CancellationError() }
    let id = UUID()
    buffers[id] = samples.count
    queuedFrames += samples.count
    output.schedule(samples) { [weak self] in
      Task { @MainActor in self?.played(id) }
    }
  }

  private func played(_ id: UUID) {
    guard let count = buffers.removeValue(forKey: id), !stopped else { return }
    queuedFrames -= count
    capacity?.resume(); capacity = nil
    if buffers.isEmpty { completion?.resume(); completion = nil }
  }

  func finished() async throws {
    guard !stopped else { throw CancellationError() }
    if !buffers.isEmpty {
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { completion = $0 }
      } onCancel: { Task { @MainActor in self.stop() } }
    }
    try Task.checkCancellation()
  }

  func stop() {
    guard !stopped else { return }
    stopped = true
    output.stop()
    buffers.removeAll(); queuedFrames = 0
    capacity?.resume(throwing: CancellationError()); capacity = nil
    completion?.resume(throwing: CancellationError()); completion = nil
  }
}

@MainActor private final class PlaybackAudio {
  private lazy var engine = AVAudioEngine()
  private lazy var node = AVAudioPlayerNode()
  private var format: AVAudioFormat?
  private var generation = 0
  private var active = false
  private let onLevel: @MainActor (Double) -> Void
  init(onLevel: @escaping @MainActor (Double) -> Void) {
    self.onLevel = onLevel
  }
  func start(sampleRate: Int) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
    self.format = format
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    generation += 1
    let generation = generation
    node.installTap(onBus: 0, bufferSize: AVAudioFrameCount(sampleRate / 10), format: format,
      block: Self.levelTap { [weak self] level in
        guard let self, self.active, self.generation == generation, self.node.isPlaying else { return }
        self.onLevel(level)
      })
    do { try engine.start() } catch { node.removeTap(onBus: 0); engine.stop(); throw error }
    active = true
    node.play()
  }
  func pause() { node.pause() }
  func resume() { node.play() }
  func stop() {
    guard active else { return }
    active = false; generation += 1
    node.stop(); node.removeTap(onBus: 0); engine.stop()
  }
  func schedule(_ samples: [Float], completion: @escaping @Sendable () -> Void) {
    guard let format, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
      completion(); return
    }
    buffer.frameLength = buffer.frameCapacity
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
    node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in completion() }
  }
  private nonisolated static func levelTap(_ deliver: @escaping @MainActor (Double) -> Void) -> AVAudioNodeTapBlock {
    { buffer, _ in
      let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
      let rms = samples.isEmpty ? 0 : (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
      let level = Overlay.level(rms: rms)
      Task { @MainActor in deliver(level) }
    }
  }
}
