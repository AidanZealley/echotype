import Foundation

/// Converts streamed 16-bit little-endian PCM to Float32 samples.
///
/// The network splits the stream wherever it likes, so a sample can straddle two chunks. An
/// odd trailing byte is held until the next chunk. Use one decoder per reading.
public struct PCMDecoder: Sendable {
  private var carried: UInt8?

  public init() {}

  public mutating func samples(from chunk: Data) -> [Float] {
    var bytes = carried.map { [$0] } ?? []
    bytes.append(contentsOf: chunk)
    carried = bytes.count.isMultiple(of: 2) ? nil : bytes.removeLast()
    return stride(from: 0, to: bytes.count, by: 2).map { index in
      let sample = Int16(bitPattern: UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8)
      return Float(sample) / 32768
    }
  }
}
