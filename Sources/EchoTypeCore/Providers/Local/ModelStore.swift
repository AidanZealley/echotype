import CryptoKit
import Foundation
import Synchronization

enum ModelState: Sendable, Equatable {
  case missing
  case downloading(done: Int64, total: Int64)
  /// The directory holding every file of the manifest, all verified.
  case installed(URL)
  case failed(String)
}

enum ModelStoreError: LocalizedError {
  case badStatus(Int, URL?)
  case sizeMismatch(path: String, expected: Int64, actual: Int64)
  case checksumMismatch(path: String)

  var errorDescription: String? {
    switch self {
    case .badStatus(let status, let url): "HTTP \(status) from \(url?.host() ?? "the server")"
    case .sizeMismatch(let path, let expected, let actual): "\(path) is \(actual) bytes, expected \(expected)"
    case .checksumMismatch(let path): "\(path) does not match its checksum"
    }
  }
}

/// Downloads pinned models into one directory and says which are usable.
///
/// A model's files are fetched and verified one by one into `Incomplete/`, then the whole
/// directory is renamed into place. So an installed directory always holds every verified file,
/// whatever interrupted an earlier download. A file that verified stays in `Incomplete/`, so a
/// retry resumes after the last such file; nothing there is ever read as a model.
final class ModelStore: Sendable {
  /// Shared by the app and the bench.
  static let defaultRoot = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appending(path: "EchoType/Models", directoryHint: .isDirectory)

  private struct Book {
    /// Only models downloading or failed in this process; the disk answers for the rest.
    var states: [String: ModelState] = [:]
    var followers: [UUID: AsyncStream<Void>.Continuation] = [:]

    func notify() { for follower in followers.values { follower.yield() } }
  }

  private let root: URL
  private let source: ModelDownloadSource
  private let book = Mutex(Book())

  init(root: URL = defaultRoot, source: ModelDownloadSource = .live) {
    self.root = root
    self.source = source
  }

  func state(of manifest: ModelManifest) -> ModelState {
    if let state = book.withLock({ $0.states[manifest.directoryName] }) { return state }
    let directory = installedDirectory(manifest)
    return FileManager.default.fileExists(atPath: directory.path) ? .installed(directory) : .missing
  }

  /// Starts the download unless the model is installed or already downloading, so repeated calls
  /// run one. A failed model starts again. The download runs in a task the store owns, so it
  /// carries on whatever happens to the caller.
  func start(_ manifest: ModelManifest) {
    let id = manifest.directoryName
    let begins = book.withLock { book in
      if case .downloading = book.states[id] { return false }
      if FileManager.default.fileExists(atPath: installedDirectory(manifest).path) { return false }
      book.states[id] = .downloading(done: 0, total: manifest.totalBytes)
      book.notify()
      return true
    }
    guard begins else { return }
    Task {
      do {
        try await download(manifest)
        finish(id, with: nil)
      } catch {
        finish(id, with: .failed(error.localizedDescription))
      }
    }
  }

  /// A fresh stream for one follower, yielding whenever any model's state changes. The follower
  /// stops by ending iteration.
  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    continuation.onTermination = { [weak self] _ in
      self?.book.withLock { _ = $0.followers.removeValue(forKey: id) }
    }
    book.withLock { $0.followers[id] = continuation }
    return stream
  }

  private func installedDirectory(_ manifest: ModelManifest) -> URL {
    root.appending(path: manifest.directoryName, directoryHint: .isDirectory)
  }

  private func incompleteDirectory(_ manifest: ModelManifest) -> URL {
    root.appending(path: "Incomplete/\(manifest.directoryName)", directoryHint: .isDirectory)
  }

  private func download(_ manifest: ModelManifest) async throws {
    let id = manifest.directoryName
    let incomplete = incompleteDirectory(manifest)
    try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)

    var done: Int64 = 0
    for file in manifest.files {
      let destination = incomplete.appending(path: file.path)
      // Only a verified file is ever named like this, so it needs no second look.
      if !FileManager.default.fileExists(atPath: destination.path) {
        let partial = destination.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: partial)
        try FileManager.default.createDirectory(
          at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let before = done
        try await source.fetch(manifest.downloadURL(for: file), partial) { [self] written in
          report(id, done: before + written, total: manifest.totalBytes)
        }
        do { try verify(partial, against: file) } catch {
          try? FileManager.default.removeItem(at: partial)
          throw error
        }
        try FileManager.default.moveItem(at: partial, to: destination)
      }
      done += file.size
      report(id, done: done, total: manifest.totalBytes)
    }
    try FileManager.default.moveItem(at: incomplete, to: installedDirectory(manifest))
  }

  private func verify(_ url: URL, against file: ModelManifest.File) throws {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    var size: Int64 = 0
    while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
      hash.update(data: chunk)
      size += Int64(chunk.count)
    }
    guard size == file.size else {
      throw ModelStoreError.sizeMismatch(path: file.path, expected: file.size, actual: size)
    }
    let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
    guard digest == file.sha256 else { throw ModelStoreError.checksumMismatch(path: file.path) }
  }

  /// Tells followers about progress at about one percent steps, so they are not flooded.
  private func report(_ id: String, done: Int64, total: Int64) {
    book.withLock { book in
      guard case .downloading(let previous, _) = book.states[id] else { return }
      guard done == total || done - previous >= max(total / 100, 1) else { return }
      book.states[id] = .downloading(done: done, total: total)
      book.notify()
    }
  }

  /// Ends the download. A nil state means installed, which the disk now answers.
  private func finish(_ id: String, with state: ModelState?) {
    book.withLock { book in
      book.states[id] = state
      book.notify()
    }
  }
}
