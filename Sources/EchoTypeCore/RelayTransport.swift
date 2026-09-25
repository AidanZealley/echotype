import Foundation

/// The transport `STTClient` sees: messages the session has already read, and sends passed
/// straight through to the real socket.
final class RelayTransport: WebSocketTransport {
  private let base: any WebSocketTransport
  private let stream: AsyncThrowingStream<String, any Error>
  private let continuation: AsyncThrowingStream<String, any Error>.Continuation

  init(base: any WebSocketTransport) {
    self.base = base
    (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
  }

  func deliver(_ message: String) {
    continuation.yield(message)
  }

  func finish() {
    continuation.finish()
  }

  func send(binary: Data) async throws {
    try await base.send(binary: binary)
  }

  func send(text: String) async throws {
    try await base.send(text: text)
  }

  func messages() -> AsyncThrowingStream<String, any Error> {
    stream
  }

  /// The session owns the socket's lifetime, so a client teardown is not one.
  func close() {}
}
