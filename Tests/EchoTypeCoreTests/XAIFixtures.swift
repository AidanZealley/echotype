@testable import EchoTypeCore
import Foundation

/// Recorded-shape server messages, as the endpoint sends them: JSON text frames with the event
/// name in `type` and the payload beside it.
enum Fixture {
  static let created = #"{"type":"transcript.created","request_id":"req_123"}"#
  static let done = #"{"type":"transcript.done"}"#

  /// The endpoint sends `words` on every `is_final` frame, naming the word itself `text`.
  static func partial(
    _ text: String,
    words: [(text: String, start: Double, end: Double)] = [],
    isFinal: Bool = false,
    speechFinal: Bool = false
  ) -> String {
    let words =
      words
      .map { #"{"text":"\#($0.text)","start":\#($0.start),"end":\#($0.end)}"# }
      .joined(separator: ",")
    return """
      {"type":"transcript.partial","text":"\(text)","words":[\(words)],\
      "is_final":\(isFinal),"speech_final":\(speechFinal)}
      """
  }

  static func error(code: String, message: String) -> String {
    #"{"type":"error","code":"\#(code)","message":"\#(message)"}"#
  }
}

/// Decodes a fixture and applies it, so the assembler tests run through the same decoding path
/// a live session would.
func apply(_ messages: [String], to assembler: inout XAI.TranscriptAssembler) throws {
  for message in messages {
    guard let event = try XAI.Event.decode(message) else { continue }
    assembler.apply(event)
  }
}

/// A transport the test drives directly. Messages emitted before anything reads them are
/// buffered by the stream, so a scripted session needs no task interleaving.
final class FakeWebSocketTransport: WebSocketTransport, @unchecked Sendable {
  private let lock = NSLock()
  private var sentBinary: [Data] = []
  private var sentText: [String] = []
  private let stream: AsyncThrowingStream<String, any Error>
  private let continuation: AsyncThrowingStream<String, any Error>.Continuation

  init() {
    (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
  }

  /// Queues one server message.
  func emit(_ message: String) {
    continuation.yield(message)
  }

  /// Fails the server stream, as a transport error does.
  func fail(with error: any Error) {
    continuation.finish(throwing: error)
  }

  var binaryFrames: [Data] {
    lock.withLock { sentBinary }
  }

  var textFrames: [String] {
    lock.withLock { sentText }
  }

  func send(binary: Data) async throws {
    lock.withLock { sentBinary.append(binary) }
  }

  func send(text: String) async throws {
    lock.withLock { sentText.append(text) }
  }

  func messages() -> AsyncThrowingStream<String, any Error> {
    stream
  }

  func close() {
    continuation.finish()
  }
}
