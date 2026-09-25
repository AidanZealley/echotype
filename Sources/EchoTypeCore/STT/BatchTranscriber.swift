import Foundation

/// Transcribes a whole recording in one request to the xAI batch endpoint. The batch pass hears
/// the recording end to end, so it punctuates across the pauses that split the streamed text.
public enum BatchTranscriber {
  /// A one-minute dictation takes a second or two, so this only comes into play when something
  /// has gone wrong.
  static let timeout: TimeInterval = 5

  /// Wraps PCM in a 44-byte RIFF header. `pcm` is 16 kHz mono Int16 little-endian, the format
  /// `AudioChunker` produces.
  public static func wav(pcm: Data) -> Data {
    let sampleRate: UInt32 = 16000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let blockAlign = channels * bitsPerSample / 8

    var header = Data()
    header.append(contentsOf: Array("RIFF".utf8))
    header.appendLittleEndian(UInt32(36 + pcm.count))
    header.append(contentsOf: Array("WAVEfmt ".utf8))
    header.appendLittleEndian(UInt32(16))
    header.appendLittleEndian(UInt16(1))  // PCM
    header.appendLittleEndian(channels)
    header.appendLittleEndian(sampleRate)
    header.appendLittleEndian(sampleRate * UInt32(blockAlign))
    header.appendLittleEndian(blockAlign)
    header.appendLittleEndian(bitsPerSample)
    header.append(contentsOf: Array("data".utf8))
    header.appendLittleEndian(UInt32(pcm.count))
    return header + pcm
  }

  /// The multipart `POST /v1/stt` request. It sends the streaming URL's formatting parameters
  /// and keyterms, and `file` last, because the endpoint requires it to be the last field.
  public static func request(wav: Data, settings: Settings, apiKey: String) -> URLRequest {
    let boundary = "echotype-\(UUID().uuidString)"
    let fields =
      [("format", "true"), ("filler_words", "false"), ("language", settings.language)]
      + STTConnection.keyterms(settings: settings).map { ("keyterm", $0) }

    func disposition(_ parameters: String) -> String {
      "--\(boundary)\r\nContent-Disposition: form-data; \(parameters)\r\n"
    }
    let head =
      fields.map { disposition("name=\"\($0)\"") + "\r\n\($1)\r\n" }.joined()
      + disposition("name=\"file\"; filename=\"audio.wav\"") + "Content-Type: audio/wav\r\n\r\n"
    let body = Data(head.utf8) + wav + Data("\r\n--\(boundary)--\r\n".utf8)

    guard let url = URL(string: "https://api.x.ai/v1/stt") else {
      preconditionFailure("The batch URL is a constant and cannot be invalid")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    for (field, value) in STTConnection.headers(apiKey: apiKey) {
      request.setValue(value, forHTTPHeaderField: field)
    }
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return request
  }

  /// Returns the response's `text` unchanged, which may be empty. Throws on a timeout, a
  /// transport failure, a non-2xx status as `STTError(httpStatus:)`, or an undecodable body.
  public static func transcribe(pcm: Data, settings: Settings, apiKey: String) async throws
    -> String
  {
    // `timeoutIntervalForResource` limits the whole request; `URLRequest.timeoutInterval`
    // would only limit the gap between packets.
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForResource = timeout
    let session = URLSession(configuration: configuration)
    defer { session.finishTasksAndInvalidate() }

    let (data, response) = try await session.data(
      for: request(wav: wav(pcm: pcm), settings: settings, apiKey: apiKey))
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      throw STTError(httpStatus: status)
    }
    return try JSONDecoder().decode(Response.self, from: data).text
  }

  private struct Response: Decodable {
    var text: String
  }
}

extension Data {
  fileprivate mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
  }
}
