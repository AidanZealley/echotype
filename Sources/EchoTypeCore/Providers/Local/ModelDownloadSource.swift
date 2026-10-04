import Foundation
import Synchronization

/// Fetches one file to a path, reporting the bytes written so far. Replaced in tests.
struct ModelDownloadSource: Sendable {
  var fetch: @Sendable (_ url: URL, _ destination: URL, _ progress: @escaping @Sendable (Int64) -> Void) async throws -> Void
}

extension ModelDownloadSource {
  static let live = Self { url, destination, progress in
    try await Download(destination: destination, progress: progress).run(url)
  }

  /// One download task and its session. A session delegate is what reports progress: the async
  /// `URLSession.download` calls never do.
  private final class Download: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct Outcome {
      var continuation: CheckedContinuation<Void, any Error>?
      /// Set when the body arrived but could not be used, and thrown once the task completes.
      var failure: (any Error)?
    }

    private let destination: URL
    private let progress: @Sendable (Int64) -> Void
    private let outcome = Mutex(Outcome())

    init(destination: URL, progress: @escaping @Sendable (Int64) -> Void) {
      self.destination = destination
      self.progress = progress
    }

    func run(_ url: URL) async throws {
      let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
      defer { session.finishTasksAndInvalidate() }
      try await withCheckedThrowingContinuation { continuation in
        outcome.withLock { $0.continuation = continuation }
        session.downloadTask(with: url).resume()
      }
    }

    func urlSession(
      _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
      totalBytesWritten: Int64, totalBytesExpectedToWrite _: Int64
    ) {
      progress(totalBytesWritten)
    }

    // The system deletes the file when this returns, so it moves here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
      let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
      do {
        guard status == 200 else { throw ModelStoreError.badStatus(status, downloadTask.originalRequest?.url) }
        try FileManager.default.moveItem(at: location, to: destination)
      } catch {
        outcome.withLock { $0.failure = error }
      }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
      let (continuation, failure) = outcome.withLock { ($0.continuation, $0.failure) }
      if let error = error ?? failure { continuation?.resume(throwing: error) } else { continuation?.resume() }
    }
  }
}
