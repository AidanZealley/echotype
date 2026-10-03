@testable import EchoTypeBench
import EchoTypeTestSupport
import Foundation
import Testing

@Test("A recording written by the bench reads back as 16 kHz mono with the same samples")
func writtenWAVReadsBack() throws {
  let url = FileManager.default.temporaryDirectory
    .appending(path: "echotype-\(UUID().uuidString)/take.wav")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let samples: [Int16] = (0..<1_600).map { Int16(10_000 * sin(Double($0) / 20)) }

  try writeWAV(samples, to: url)
  try writeWAV(samples, to: url)  // Replacing an existing recording works too.
  let recording = try WAVRecording(contentsOf: url)

  #expect(recording.sampleRate == 16_000)
  #expect(recording.channelCount == 1)
  #expect(recording.samples.count == samples.count)
  for (read, written) in zip(recording.samples, samples) {
    #expect(abs(read - Float(written) / 32768) < 0.001)
  }
  #expect(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path) == ["take.wav"])
}
