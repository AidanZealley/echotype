import Foundation

/// Just enough RIFF to read the recording supplied through `ECHOTYPE_FIXTURE_WAV`: 16-bit PCM,
/// any sample rate, any channel count. Anything else is rejected with a message saying what to
/// supply instead, because the point of this file is to get real speech to `AudioConverter`,
/// not to be an audio library.
struct WAVRecording {
  let sampleRate: Double
  let channelCount: Int
  /// Interleaved samples in [-1, 1], the shape `AudioConverter` consumes.
  let samples: [Float]

  init(contentsOf url: URL) throws {
    let bytes = [UInt8](try Data(contentsOf: url))
    guard bytes.count > 12, ascii(bytes, 0) == "RIFF", ascii(bytes, 8) == "WAVE" else {
      throw UnreadableWAV("\(url.path) is not a RIFF WAVE file")
    }

    var format: (tag: Int, channels: Int, rate: Int, bits: Int)?
    var audio: ArraySlice<UInt8>?
    var offset = 12
    while offset + 8 <= bytes.count {
      let id = ascii(bytes, offset)
      let size = min(integer(bytes, offset + 4, width: 4), bytes.count - offset - 8)
      let payload = offset + 8
      switch id {
      case "fmt ":
        guard size >= 16 else {
          throw UnreadableWAV("\(url.path) has a truncated fmt chunk")
        }
        format = (
          tag: integer(bytes, payload, width: 2),
          channels: integer(bytes, payload + 2, width: 2),
          rate: integer(bytes, payload + 4, width: 4),
          bits: integer(bytes, payload + 14, width: 2)
        )
      case "data":
        audio = bytes[payload..<(payload + size)]
      default:
        break
      }
      // Chunks are word-aligned, so an odd size is followed by a pad byte.
      offset = payload + size + (size % 2)
    }

    guard let format, let audio else {
      throw UnreadableWAV("\(url.path) has no fmt or data chunk")
    }
    // 1 is plain PCM and 0xFFFE is WAVE_FORMAT_EXTENSIBLE, which recorders write for ordinary
    // PCM as soon as the file is multichannel or high resolution. The sample width below is
    // what actually decides whether the samples can be read.
    guard format.tag == 1 || format.tag == 0xFFFE else {
      throw UnreadableWAV(
        "\(url.path) is not PCM (format tag \(format.tag)); export it as 16-bit PCM WAV"
      )
    }
    guard format.bits == 16 else {
      throw UnreadableWAV("\(url.path) is \(format.bits)-bit; export it as 16-bit PCM WAV")
    }
    guard format.channels > 0, format.rate > 0 else {
      throw UnreadableWAV("\(url.path) declares \(format.channels) channels at \(format.rate) Hz")
    }

    sampleRate = Double(format.rate)
    channelCount = format.channels
    samples = stride(from: audio.startIndex, to: audio.endIndex - 1, by: 2).map { index in
      let value = Int16(bitPattern: UInt16(audio[index]) | UInt16(audio[index + 1]) << 8)
      return Float(value) / 32768
    }
  }

  var duration: Double { duration(ofInterleaved: samples) }

  func duration(ofInterleaved samples: [Float]) -> Double {
    Double(samples.count / channelCount) / sampleRate
  }

  /// Interleaved chunks of roughly `seconds` each, which is how the macOS capture tap will hand
  /// audio over.
  func chunks(ofSeconds seconds: Double) -> [[Float]] {
    let size = max(1, Int(sampleRate * seconds)) * channelCount
    return stride(from: 0, to: samples.count, by: size).map { start in
      Array(samples[start..<min(start + size, samples.count)])
    }
  }

  var summary: String {
    let format = String(format: "%.1f", duration)
    return "\(format)s, \(Int(sampleRate)) Hz, \(channelCount) channel(s)"
  }
}

struct UnreadableWAV: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

private func ascii(_ bytes: [UInt8], _ offset: Int) -> String {
  guard offset + 4 <= bytes.count else { return "" }
  return String(decoding: bytes[offset..<(offset + 4)], as: UTF8.self)
}

private func integer(_ bytes: [UInt8], _ offset: Int, width: Int) -> Int {
  guard offset + width <= bytes.count else { return 0 }
  return (0..<width).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
}
