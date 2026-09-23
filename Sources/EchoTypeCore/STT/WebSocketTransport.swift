import Foundation

/// The socket seam `STTClient` talks to, so that protocol logic can be driven by recorded event
/// streams instead of a live connection.
public protocol WebSocketTransport: Sendable {
  /// Sends one binary frame of raw audio.
  func send(binary: Data) async throws

  /// Sends one text frame, which is how the client messages are encoded.
  func send(text: String) async throws

  /// Server messages in arrival order. The stream finishes when the socket closes and throws
  /// when it fails. Binary frames from the server are not part of this protocol; the endpoint
  /// only sends JSON.
  func messages() -> AsyncThrowingStream<String, any Error>

  /// Closes the socket. Safe to call more than once.
  func close()
}
