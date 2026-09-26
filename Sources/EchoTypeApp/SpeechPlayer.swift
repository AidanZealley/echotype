import AVFoundation
import EchoTypeCore

/// Plays one reading's Float32 samples at `Speech.sampleRate` through an `AVAudioEngine`,
/// scheduling each buffer as it arrives, and reports the level of the audio as it plays. Use
/// one player per reading.
@MainActor final class SpeechPlayer {
  private let engine = AVAudioEngine()
  private let node = AVAudioPlayerNode()
  private let format = AVAudioFormat(
    standardFormatWithSampleRate: Double(Speech.sampleRate), channels: 1)!

  /// `onLevel` receives the level of each roughly 100ms of audio as it plays, scaled as
  /// dictation scales the microphone's. It stops with the player.
  init(onLevel: @escaping @MainActor (Double) -> Void) {
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    // The tap sees the node's output as it renders, so levels follow playback, not the
    // response, which arrives several times faster than real time.
    node.installTap(
      onBus: 0, bufferSize: AVAudioFrameCount(Speech.sampleRate / 10), format: format,
      block: Self.levelTap { [weak self] level in
        // A level already on its way when the player stopped is dropped.
        if self?.node.isPlaying == true { onLevel(level) }
      })
  }

  func start() throws {
    try engine.start()
    node.play()
  }

  /// Queues samples to play after those already scheduled.
  func schedule(_ samples: [Float]) {
    guard let buffer = buffer(samples) else { return }
    node.scheduleBuffer(buffer)
  }

  /// Returns once every scheduled buffer has played, or at once when the player is stopped.
  func finished() async {
    // Buffers play in order, so one silent frame queued last finishes after all the audio.
    // `stop()` completes it early. A stopped node would never complete it, so don't wait.
    guard node.isPlaying, let silence = buffer([0]) else { return }
    await node.scheduleBuffer(silence, completionCallbackType: .dataPlayedBack)
  }

  /// Cuts the audio off at once and releases the output.
  func stop() {
    node.stop()
    engine.stop()
  }

  /// Built outside the main actor: the tap runs on the audio engine's own thread.
  private nonisolated static func levelTap(
    _ deliver: @escaping @MainActor (Double) -> Void
  ) -> AVAudioNodeTapBlock {
    { buffer, _ in
      let samples = UnsafeBufferPointer(
        start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
      let rms = samples.isEmpty
        ? 0 : (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
      let level = Overlay.level(rms: rms)
      Task { @MainActor in deliver(level) }
    }
  }

  private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
    guard !samples.isEmpty,
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else { return nil }
    buffer.frameLength = buffer.frameCapacity
    samples.withUnsafeBufferPointer { source in
      buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
    }
    return buffer
  }
}
