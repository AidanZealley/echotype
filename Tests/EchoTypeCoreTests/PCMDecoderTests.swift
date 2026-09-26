import EchoTypeCore
import Foundation
import Testing

private let values: [Int16] = [0, 1, -1, 16384, -16384, .max, .min]
private let pcm = values.withUnsafeBufferPointer { Data(buffer: $0) }
private let expected = values.map { Float($0) / 32768 }

@Test("A split at any offset, mid-sample included, gives the same samples as the whole buffer")
func pcmSplitAnywhere() {
  for offset in 0...pcm.count {
    var decoder = PCMDecoder()
    let samples =
      decoder.samples(from: pcm.prefix(offset)) + decoder.samples(from: pcm.dropFirst(offset))
    #expect(samples == expected, "split at \(offset)")
  }
}

@Test("Single-byte chunks and empty chunks give the same samples")
func pcmByteByByte() {
  var decoder = PCMDecoder()
  #expect(decoder.samples(from: Data()) == [])
  let samples = pcm.flatMap { decoder.samples(from: Data([$0])) + decoder.samples(from: Data()) }
  #expect(samples == expected)
}
