import Foundation
import Synchronization

/// The body of one HTTP response, pulled piece by piece as it arrives.
///
/// A serial delegate delivers fixed-size pieces through a finite queue. Capacity blocks
/// this callback before another piece is copied, so a consumer that stops pulling backpressures
/// application intake. URLSession owns callback delivery and its internal buffering; callback
/// size is not a limit. See decision 0018.
final class StreamingResponse: NSObject, URLSessionDataDelegate, Sendable {
  static let maximumBufferedBytes = 256 * 1024
  static let chunkBytes = 64 * 1024
  private let capacity = DispatchSemaphore(value: maximumBufferedBytes / chunkBytes)
  private let errorForStatus: @Sendable (Int) -> ProviderError
  private struct State {
    var chunks: [Data] = []
    var waiter: CheckedContinuation<Data?, any Error>?
    var ended = false
    var error: (any Error)?
    var task: URLSessionDataTask?
    var session: URLSession?
  }
  private let state = Mutex(State())

  /// Sends the request immediately. A non-2xx status throws the provider's mapping of it.
  init(
    _ request: URLRequest, errorForStatus: @escaping @Sendable (Int) -> ProviderError,
    configuration: URLSessionConfiguration = .ephemeral
  ) {
    self.errorForStatus = errorForStatus
    super.init()
    let delegateQueue = OperationQueue()
    delegateQueue.maxConcurrentOperationCount = 1
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    let task = session.dataTask(with: request)
    state.withLock { $0.session = session; $0.task = task }
    task.resume()
  }

  /// The next piece of at most `chunkBytes`, or nil at the end of the body.
  func next() async throws -> Data? {
    try Task.checkCancellation()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { waiter in
        state.withLock { state in
          if !state.chunks.isEmpty {
            let chunk = state.chunks.removeFirst()
            capacity.signal()
            waiter.resume(returning: chunk)
          } else if state.ended {
            if let error = state.error { waiter.resume(throwing: error) } else { waiter.resume(returning: nil) }
          } else {
            state.waiter = waiter
          }
        }
      }
    } onCancel: { self.cancel() }
  }
  func cancel() { end(CancellationError()) }
  private func end(_ error: (any Error)?) {
    state.withLock { state in
      guard !state.ended else { return }
      state.ended = true; state.error = error
      // Only the serial delegate can wait on capacity. Wake it on Stop/error.
      for _ in 0...state.chunks.count { capacity.signal() }
      if error != nil { state.chunks.removeAll() }
      if let waiter = state.waiter {
        state.waiter = nil
        if let error { waiter.resume(throwing: error) } else { waiter.resume(returning: nil) }
      }
      state.task?.cancel(); state.task = nil
      state.session?.invalidateAndCancel(); state.session = nil
    }
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
    didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      completionHandler(.cancel); end(errorForStatus(status)); return
    }
    completionHandler(.allow)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    for start in stride(from: 0, to: data.count, by: Self.chunkBytes) {
      capacity.wait()
      let delivered = state.withLock { state -> Bool in
        guard !state.ended else { capacity.signal(); return false }
        let chunk = data.subdata(in: start..<min(start + Self.chunkBytes, data.count))
        if let waiter = state.waiter {
          state.waiter = nil
          capacity.signal()
          waiter.resume(returning: chunk)
        } else {
          state.chunks.append(chunk)
        }
        return true
      }
      if !delivered { return }
    }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) { end(error) }
}
