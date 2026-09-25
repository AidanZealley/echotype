import EchoTypeCore
import Foundation
import Testing

@Test("The WAV header describes 16 kHz mono 16-bit PCM and keeps the samples")
func wavReadsBack() throws {
  let values: [Int16] = [0, 1, -1, 16384, -16384, .max, .min]
  let pcm = values.withUnsafeBufferPointer { Data(buffer: $0) }
  let wav = BatchTranscriber.wav(pcm: pcm)

  #expect(wav.count == 44 + pcm.count)
  #expect(wav.suffix(pcm.count) == pcm)

  let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
  try wav.write(to: url)
  defer { try? FileManager.default.removeItem(at: url) }
  let recording = try WAVRecording(contentsOf: url)

  #expect(recording.sampleRate == 16000)
  #expect(recording.channelCount == 1)
  #expect(recording.samples == values.map { Float($0) / 32768 })
}

@Test("The batch request posts the formatting fields and capped keyterms, with the file last")
func batchRequestFields() throws {
  let wav = BatchTranscriber.wav(pcm: Data([1, 2, 3, 4]))
  let keyterms = ["TanStack Start", String(repeating: "x", count: 60)] + (0..<120).map { "t\($0)" }
  let request = BatchTranscriber.request(
    wav: wav, settings: Settings(keyterms: keyterms, language: "en-GB"), apiKey: "xai-123")

  #expect(request.httpMethod == "POST")
  #expect(request.url?.absoluteString == "https://api.x.ai/v1/stt")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer xai-123")

  let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
  let prefix = "multipart/form-data; boundary="
  #expect(contentType.hasPrefix(prefix))
  let parts = try multipartParts(
    try #require(request.httpBody), boundary: String(contentType.dropFirst(prefix.count)))

  let fields = parts.dropLast().map { ($0.name, String(decoding: $0.content, as: UTF8.self)) }
  #expect(fields.prefix(4).map(\.0) == ["format", "filler_words", "language", "keyterm"])
  #expect(fields.prefix(4).map(\.1) == ["true", "false", "en-GB", "TanStack Start"])
  let sentKeyterms = fields.filter { $0.0 == "keyterm" }.map(\.1)
  #expect(sentKeyterms.count == 100)
  #expect(sentKeyterms[1] == String(repeating: "x", count: 50))
  #expect(sentKeyterms.last == "t97")

  #expect(parts.last?.name == "file")
  #expect(parts.last?.content == wav)
}

/// Splits a `multipart/form-data` body into its parts' names and contents.
private func multipartParts(_ body: Data, boundary: String) throws -> [(
  name: String, content: Data
)] {
  let delimiter = Data("--\(boundary)".utf8)
  var parts: [(name: String, content: Data)] = []
  var cursor = try #require(body.range(of: delimiter)).upperBound
  while body[cursor..<(cursor + 2)] != Data("--".utf8) {
    let next = try #require(body.range(of: delimiter, in: cursor..<body.endIndex))
    // Each part is "\r\n<headers>\r\n\r\n<content>\r\n" between delimiters.
    let part = body[(cursor + 2)..<(next.lowerBound - 2)]
    let separator = try #require(part.range(of: Data("\r\n\r\n".utf8)))
    let headers = String(decoding: part[..<separator.lowerBound], as: UTF8.self)
    let name = try #require(headers.firstMatch(of: /name="([^"]*)"/)).1
    parts.append((String(name), Data(part[separator.upperBound...])))
    cursor = next.upperBound
  }
  return parts
}
