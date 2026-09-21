import EchoTypeCore
import Foundation
import Testing

/// Reads converted output back as the Int16 samples the endpoint would see, assuming the
/// little-endian byte order the tests below pin down separately.
private func samples(of data: Data) -> [Int16] {
  stride(from: 0, to: data.count, by: 2).map { index in
    Int16(littleEndian: Int16(data[index]) | Int16(data[index + 1]) << 8)
  }
}

private func sine(frames: Int, frequency: Double, sampleRate: Double) -> [Float] {
  (0..<frames).map { frame in
    Float(sin(2 * .pi * frequency * Double(frame) / sampleRate))
  }
}

@Test("48 kHz input converts to a third as many samples")
func downsamplesByRateRatio() {
  var converter = AudioConverter(inputSampleRate: 48_000)
  let output = converter.convert(sine(frames: 48_000, frequency: 440, sampleRate: 48_000))
  // One second in, one second out. The held-back final frame costs no sample here because
  // 48000 / 3 lands exactly on a frame the converter can still interpolate.
  #expect(samples(of: output).count == 16_000)
}

@Test("Streaming in chunks matches converting in one call")
func chunkBoundariesNeitherDropNorRepeatSamples() {
  let signal = sine(frames: 26_301, frequency: 440, sampleRate: 44_100)

  var wholeConverter = AudioConverter(inputSampleRate: 44_100)
  let whole = wholeConverter.convert(signal)

  var streamConverter = AudioConverter(inputSampleRate: 44_100)
  var streamed = Data()
  var offset = 0
  // Deliberately uneven and including a single-frame buffer, since a resampler that resets its
  // phase per call, or that cannot span a boundary, fails on exactly those.
  for size in [512, 1, 4_410, 37, 2_048, 19_293] {
    streamed += streamConverter.convert(Array(signal[offset..<(offset + size)]))
    offset += size
  }
  #expect(offset == signal.count)

  #expect(streamed == whole)
}

@Test("Stereo is downmixed to mono")
func stereoIsAveragedToMono() {
  var stereo = AudioConverter(inputSampleRate: 16_000, channelCount: 2)
  // Left and right are opposite, so an average cancels to silence while picking one channel
  // or interleaving would not.
  let opposed = stereo.convert([0.5, -0.5, 0.5, -0.5, 0.5, -0.5])
  #expect(samples(of: opposed).allSatisfy { $0 == 0 })

  var mono = AudioConverter(inputSampleRate: 16_000)
  var matching = AudioConverter(inputSampleRate: 16_000, channelCount: 2)
  #expect(
    matching.convert([0.25, 0.25, 0.25, 0.25, 0.25, 0.25])
      == mono.convert([0.25, 0.25, 0.25])
  )
}

@Test("Out-of-range and non-finite samples clip instead of wrapping or trapping")
func overloadedSamplesClip() {
  var converter = AudioConverter(inputSampleRate: 16_000)
  let overloaded = samples(of: converter.convert([2, 2, 2, -3, -3, -3]))
  #expect(overloaded.allSatisfy { abs($0) == 32_767 })
  #expect(overloaded.contains(32_767))
  #expect(overloaded.contains(-32_767))

  // A non-finite sample must not abort the process mid-dictation, and must not reach the
  // interpolator, where `inf - inf` would manufacture NaN.
  var extremes = AudioConverter(inputSampleRate: 16_000)
  let nonFinite = samples(of: extremes.convert([.infinity, -.infinity, .nan, 0]))
  #expect(nonFinite == [32_767, -32_767, 0])
}

@Test("Output samples track the input waveform")
func resampledValuesFollowTheInput() {
  // A ramp in units of 1/32767, so input frame `i` is exactly Int16 `i` and a correctly
  // phased 48 kHz downsample reads frames 0, 3, 6 and so on. Catches nearest-sample
  // picking, interpolating the wrong pair, and being a frame out of phase.
  var converter = AudioConverter(inputSampleRate: 48_000)
  let ramp = (0..<300).map { Float($0) / 32_767 }
  let output = samples(of: converter.convert(ramp))
  #expect(output == (0..<100).map { Int16($0 * 3) })
}

@Test("Output is little-endian Int16")
func outputIsLittleEndian() {
  var converter = AudioConverter(inputSampleRate: 16_000)
  let output = converter.convert([0.5, 0.5, 0.5])
  // 0.5 * 32767 rounds to 16384, which is 0x4000: low byte first.
  #expect(Array(output) == [0x00, 0x40, 0x00, 0x40])
}
