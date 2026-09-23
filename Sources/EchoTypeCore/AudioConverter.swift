import Foundation

/// Converts device-rate Float32 audio into the format the xAI streaming endpoint expects:
/// 16 kHz, mono, little-endian Int16.
///
/// It is a stream, not a one-shot function. Call `convert` with each buffer the capture tap
/// hands over and the resampler continues from where the previous call ended, so no sample is
/// dropped or repeated at a buffer boundary. Each call returns everything ready for the frames
/// it was given, so the size of a chunk is the size of the caller's buffer; the capture layer
/// owns the roughly 100ms cadence the endpoint is fed at.
///
/// Interpolating an output sample needs the input frame after it, so the last frame of the
/// stream is held back rather than extrapolated. A stream of `frames` mono frames therefore
/// yields `ceil((frames - 1) / ratio)` samples, where `ratio` is the input rate divided by
/// 16 kHz. At 48 kHz that is exactly one third of the input.
public struct AudioConverter: Sendable {
  /// The rate the endpoint is configured with, via `sample_rate=16000`.
  public static let outputSampleRate: Double = 16_000

  public let inputSampleRate: Double
  public let channelCount: Int

  /// Input frames per output sample.
  private let ratio: Double

  /// Output samples emitted so far. Position is derived from this rather than accumulated, so
  /// a long session cannot drift at a non-integer rate ratio such as 44.1 kHz.
  private var producedSamples = 0

  /// Mono frames consumed from the stream so far.
  private var consumedFrames = 0

  /// The final frame of the previous call, kept so interpolation can span a buffer boundary.
  private var carriedFrame: Float?

  public init(inputSampleRate: Double, channelCount: Int = 1) {
    // A zero rate would leave the output position pinned at zero and loop forever.
    precondition(inputSampleRate > 0, "input sample rate must be positive")
    precondition(channelCount > 0, "channel count must be positive")
    self.inputSampleRate = inputSampleRate
    self.channelCount = channelCount
    self.ratio = inputSampleRate / Self.outputSampleRate
  }

  /// Converts one buffer of samples, continuing the stream.
  ///
  /// Multi-channel input must be interleaved and whole-framed: `samples.count` a multiple of
  /// `channelCount`. Producing an interleaved buffer is the capture layer's job, since
  /// `AVAudioEngine`'s input node is non-interleaved by default. A buffer ending mid-frame
  /// drops the orphan sample, which pairs the wrong channels together for the rest of the
  /// session.
  public mutating func convert(_ samples: [Float]) -> Data {
    let frames = downmixToMono(samples)
    guard !frames.isEmpty else { return Data() }

    // Interpolation reads from the carried frame followed by this buffer, indexed in stream
    // coordinates: `window[i - windowStart]` is the frame at stream index `i`.
    let window = carriedFrame.map { [$0] + frames } ?? frames
    let windowStart = consumedFrames - (carriedFrame == nil ? 0 : 1)
    let lastAvailable = consumedFrames + frames.count - 1

    var data = Data()
    data.reserveCapacity(Int(Double(frames.count) / ratio + 1) * 2)
    while true {
      let position = Double(producedSamples) * ratio
      let lower = Int(position.rounded(.down))
      guard lower + 1 <= lastAvailable else { break }

      let fraction = Float(position - Double(lower))
      let earlier = clipped(window[lower - windowStart])
      let later = clipped(window[lower + 1 - windowStart])
      data.append(littleEndianInt16(earlier + (later - earlier) * fraction))
      producedSamples += 1
    }

    consumedFrames += frames.count
    carriedFrame = frames.last
    return data
  }

  /// Averages the channels of an interleaved buffer. A trailing partial frame is ignored; see
  /// the precondition on `convert`.
  private func downmixToMono(_ samples: [Float]) -> [Float] {
    guard channelCount > 1 else { return samples }
    let frameCount = samples.count / channelCount
    return (0..<frameCount).map { frame in
      let start = frame * channelCount
      var sum: Float = 0
      for channel in 0..<channelCount { sum += samples[start + channel] }
      return sum / Float(channelCount)
    }
  }

  /// Brings a sample into full scale before any arithmetic touches it, so a hot sample cannot
  /// wrap sign and a non-finite one cannot trap the Int16 conversion or poison the
  /// interpolation. NaN has no sensible amplitude, so it becomes silence.
  private func clipped(_ sample: Float) -> Float {
    guard sample.isFinite else { return sample.isNaN ? 0 : (sample < 0 ? -1 : 1) }
    return min(max(sample, -1), 1)
  }

  private func littleEndianInt16(_ sample: Float) -> Data {
    let value = Int16((sample * 32767).rounded())
    return withUnsafeBytes(of: value.littleEndian) { Data($0) }
  }
}
