import Foundation

/// The live transport, backed by `URLSessionWebSocketTask`.
///
/// Nothing in the unit tests reaches this type: it exists so that the same protocol logic that
/// is tested against recorded events can be pointed at the real endpoint.
public final class URLSessionWebSocketTransport: WebSocketTransport, @unchecked Sendable {
  private let task: URLSessionWebSocketTask

  /// Opens the socket immediately, since the specification opens it on trigger rather than at
  /// launch: an idle open socket bills streaming time.
  public init(url: URL, apiKey: String, session: URLSession = .shared) {
    var request = URLRequest(url: url)
    for (field, value) in STTConnection.headers(apiKey: apiKey) {
      request.setValue(value, forHTTPHeaderField: field)
    }
    task = session.webSocketTask(with: request)
    task.resume()
  }

  public func send(binary: Data) async throws {
    try await send(.data(binary))
  }

  public func send(text: String) async throws {
    try await send(.string(text))
  }

  public func messages() -> AsyncThrowingStream<String, any Error> {
    AsyncThrowingStream { continuation in
      let receiving = Task {
        do {
          while true {
            switch try await self.task.receive() {
            case .string(let text):
              continuation.yield(text)
            case .data(let data):
              // The endpoint documents JSON text frames only; decode anything else as UTF-8
              // rather than dropping a message silently.
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
          default:
            continuation.finish()
          }
        }
      }
      continuation.onTermination = { _ in receiving.cancel() }
    }
  }

  public func close() {
    task.cancel(with: .normalClosure, reason: nil)
  }

  private func send(_ message: URLSessionWebSocketTask.Message) async throws {
    do {
      try await task.send(message)
    } catch {
      throw sessionError(from: error)
    }
  }

  /// A rejected handshake leaves its status on the task's response, which is where the
  /// documented error statuses come from. Confirmed live: a rejected upgrade populates
  /// `task.response` and leaves `closeCode` at `.invalid`, so the status does reach here.
  ///
  /// The status is not the one the specification predicts for a bad key. `api.x.ai` answers a
  /// well-formed but incorrect key with 400 and `"Incorrect API key provided"`, reserving 401
  /// for a request carrying no credentials at all. So a wrong key surfaces as
  /// `STTError.badRequest` and only a missing one as `.unauthorized`.
  private func sessionError(from error: any Error) -> any Error {
    guard let status = (task.response as? HTTPURLResponse)?.statusCode, status >= 400 else {
      return error
    }
    return STTError(httpStatus: status)
  }
}
