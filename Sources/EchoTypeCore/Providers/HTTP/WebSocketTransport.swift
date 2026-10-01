import Foundation

/// The socket seam a WebSocket adapter talks to, so that its protocol logic can be driven by
/// recorded event streams instead of a live connection.
protocol WebSocketTransport: Sendable {
  /// Sends one binary frame of raw audio.
  func send(binary: Data) async throws

  /// Sends one text frame.
  func send(text: String) async throws

  /// Server text messages in arrival order. The stream finishes when the socket closes and
  /// throws when it fails.
  func messages() -> AsyncThrowingStream<String, any Error>

  /// Closes the socket and releases suspended sends/receives. Safe to call more than once.
  func close()

  /// Joins transport work after close. Synchronous test transports need no additional join.
  func waitForClose() async
}

extension WebSocketTransport {
  func waitForClose() async {}
}
