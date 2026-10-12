import Foundation

/// Converts Float32 audio into the format the xAI streaming endpoint expects: 16 kHz, mono,
/// little-endian Int16.
///
/// A test fixture helper, not production code. The app converts captured audio with
/// `AVAudioConverter`, which resamples properly; this exists only to feed a recorded WAV to the
/// live protocol tests, where what is being validated is event ordering rather than transcription
/// accuracy. It was written by hand when `EchoTypeCore` had to build on Linux, and moved here
/// when it no longer did, so that nothing in the app has two resamplers to choose between.
///
/// It resamples by linear interpolation with no anti-alias filter, so downsampling folds content
/// above 8 kHz back into the band. That is audible on fricatives and is the reason this is not
/// the production path.
///
/// It is a stream, not a one-shot function. Call `convert` with each buffer and the resampler
/// continues from where the previous call ended, so no sample is dropped or repeated at a buffer
/// boundary.
///
/// Interpolating an output sample needs the input frame after it, so the last frame of the
/// stream is held back rather than extrapolated. A stream of `frames` mono frames therefore
/// yields `ceil((frames - 1) / ratio)` samples, where `ratio` is the input rate divided by
/// 16 kHz. At 48 kHz that is exactly one third of the input.
struct AudioConverter: Sendable {
  /// The rate the endpoint is configured with, via `sample_rate=16000`.
  static let outputSampleRate: Double = 16_000

  let inputSampleRate: Double
  let channelCount: Int

  /// Input frames per output sample.
  private let ratio: Double

  /// Output samples emitted so far. Position is derived from this rather than accumulated, so
  /// a long session cannot drift at a non-integer rate ratio such as 44.1 kHz.
  private var producedSamples = 0

  /// Mono frames consumed from the stream so far.
  private var consumedFrames = 0

  /// The final frame of the previous call, kept so interpolation can span a buffer boundary.
  private var carriedFrame: Float?

  init(inputSampleRate: Double, channelCount: Int = 1) {
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
  mutating func convert(_ samples: [Float]) -> Data {
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
