import Foundation

/// The live transport, backed by `URLSessionWebSocketTask`.
///
/// Nothing in the unit tests reaches this type: it exists so that the same protocol logic that
/// is tested against recorded events can be pointed at the real endpoint.
final class URLSessionWebSocketTransport: WebSocketTransport, @unchecked Sendable {
  private let task: URLSessionWebSocketTask
  private let errorForStatus: @Sendable (Int) -> ProviderError
  private let receiveLock = NSLock()
  private var receiving: Task<Void, Never>?

  /// Opens the socket immediately, since a session opens it on trigger rather than at
  /// launch: an idle open socket bills streaming time. A rejected handshake throws the
  /// provider's mapping of its HTTP status.
  init(
    request: URLRequest, errorForStatus: @escaping @Sendable (Int) -> ProviderError,
    session: URLSession = .shared
  ) {
    self.errorForStatus = errorForStatus
    task = session.webSocketTask(with: request)
    task.resume()
  }

  func send(binary: Data) async throws {
    try await send(.data(binary))
  }

  func send(text: String) async throws {
    try await send(.string(text))
  }

  func messages() -> AsyncThrowingStream<String, any Error> {
    AsyncThrowingStream { continuation in
      let receiving = Task {
        do {
          while true {
            switch try await self.task.receive() {
            case .string(let text):
              continuation.yield(text)
            case .data(let data):
              // Decode anything binary as UTF-8 rather than dropping a message silently.
              continuation.yield(String(decoding: data, as: UTF8.self))
            @unknown default:
              break
            }
          }
        } catch {
          // A close initiated by either side surfaces as a receive failure, and an orderly one
          // is the end of the stream rather than a session error.
          switch self.task.closeCode {
          case .invalid:
            continuation.finish(throwing: self.sessionError(from: error))
          case .normalClosure, .goingAway:
            continuation.finish()
          default:
            continuation.finish(throwing: SessionError.socket("Abnormal WebSocket closure: \(self.task.closeCode.rawValue)"))
          }
        }
      }
      receiveLock.withLock { self.receiving = receiving }
      continuation.onTermination = { _ in receiving.cancel() }
    }
  }

  func close() {
    task.cancel(with: .normalClosure, reason: nil)
  }

  func waitForClose() async {
    let receiving = receiveLock.withLock { self.receiving }
    await receiving?.value
  }

  private func send(_ message: URLSessionWebSocketTask.Message) async throws {
    do {
      try await task.send(message)
    } catch {
      throw sessionError(from: error)
    }
  }

  /// A rejected handshake leaves its status on the task's response. Confirmed live: a rejected
  /// upgrade populates `task.response` and leaves `closeCode` at `.invalid`, so the status does
  /// reach here.
  private func sessionError(from error: any Error) -> any Error {
    guard let status = (task.response as? HTTPURLResponse)?.statusCode, status >= 400 else {
      return error
    }
    return errorForStatus(status)
  }
}
