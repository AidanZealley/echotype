import EchoTypeCore
import Foundation

/// Recorded-shape server messages, as the endpoint sends them: JSON text frames with the event
/// name in `type` and the payload beside it.
enum Fixture {
  static let created = #"{"type":"transcript.created","request_id":"req_123"}"#
  static let done = #"{"type":"transcript.done"}"#

  /// The endpoint sends `words` on every `is_final` frame, naming the word itself `text` and
  /// omitting `confidence`.
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
func apply(_ messages: [String], to assembler: inout TranscriptAssembler) throws {
  for message in messages {
    guard let event = try STTEvent.decode(message) else { continue }
    assembler.apply(event)
  }
}

/// A transport the test drives directly. Messages emitted before `run()` are buffered by the
/// stream, so a scripted session needs no task interleaving.
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

  /// Ends the server stream, as a socket closing does.
  func endStream() {
    continuation.finish()
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

/// A transport whose first binary send suspends until the test releases it, so a test can hand
/// the client more audio while a send is in flight.
actor BlockingWebSocketTransport: WebSocketTransport {
  private var frames: [Data] = []
  private var log: [String] = []
  private var firstSendArrived = false
  private var isReleased = false
  private var gate: CheckedContinuation<Void, Never>?
  private var arrival: CheckedContinuation<Void, Never>?
  private let stream: AsyncThrowingStream<String, any Error>
  private let continuation: AsyncThrowingStream<String, any Error>.Continuation

  init() {
    (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
  }

  /// Frames in the order their sends completed.
  var binaryFrames: [Data] { frames }

  /// Binary and text frames interleaved in the order they reached the socket, as `"audio"` and
  /// the text itself.
  var frameLog: [String] { log }

  /// Suspends until the client's first binary send is in flight.
  func waitForFirstSend() async {
    guard !firstSendArrived else { return }
    await withCheckedContinuation { arrival = $0 }
  }

  func releaseFirstSend() {
    isReleased = true
    gate?.resume()
    gate = nil
  }

  nonisolated func emit(_ message: String) {
    continuation.yield(message)
  }

  func send(binary: Data) async throws {
    if !firstSendArrived {
      firstSendArrived = true
      arrival?.resume()
      arrival = nil
      if !isReleased {
        await withCheckedContinuation { gate = $0 }
      }
    }
    frames.append(binary)
    log.append("audio")
  }

  func send(text: String) async throws {
    log.append(text)
  }

  nonisolated func messages() -> AsyncThrowingStream<String, any Error> {
    stream
  }

  nonisolated func close() {
    continuation.finish()
  }
}
