import CryptoKit
import FluidAudio
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
    case .sizeMismatch(let path, let expected, let actual):
      "\(path) is \(actual) bytes, expected \(expected)"
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
  /// Managed downloads and generated files owned by EchoType.
  static let defaultRoot = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appending(path: "EchoType/Models", directoryHint: .isDirectory)

  private struct Download {
    var generation: UUID
    var task: Task<Void, Never>
  }

  private struct Book {
    /// Only models downloading or failed in this process; the disk answers for the rest.
    var states: [String: ModelState] = [:]
    var tasks: [String: Download] = [:]
    var generations: [String: UUID] = [:]
    var followers: [UUID: AsyncStream<Void>.Continuation] = [:]

    func notify() { for follower in followers.values { follower.yield() } }
  }

  let root: URL
  private let source: ModelDownloadSource
  private let book = Mutex(Book())

  init(root: URL = defaultRoot, source: ModelDownloadSource = .live) {
    self.root = root
    self.source = source
  }

  func state(of manifest: ModelManifest) -> ModelState {
    if let state = book.withLock({ $0.states[manifest.directoryName] }) { return state }
    let directory = installedDirectory(manifest)
    return manifest.files.allSatisfy { file in
      let path = directory.appending(path: file.path)
      return (try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int64)
        == file.size
    } ? .installed(directory) : .missing
  }

  /// Joins one store-owned verification, recovery and download task per manifest.
  /// Caller cancellation is handled by the lifecycle, which knows which features still need it.
  @discardableResult func start(_ manifest: ModelManifest) -> Task<Void, Never> {
    let id = manifest.directoryName
    return book.withLock { book in
      let previous = book.tasks[id]?.task
      if let previous, !previous.isCancelled { return previous }
      let generation = UUID()
      book.generations[id] = generation
      book.states[id] = .downloading(done: 0, total: manifest.totalBytes)
      let task = Task {
        // A cancelled source may still write. Drain it before admitting another writer.
        await previous?.value
        do {
          try Task.checkCancellation()
          try recoverInstalled(manifest)
          try Task.checkCancellation()
          if case .installed = stateOnDisk(manifest) {
          } else {
            try await download(manifest, generation: generation)
          }
          finish(id, generation: generation, with: nil)
        } catch {
          finish(
            id, generation: generation,
            with: error is CancellationError ? nil : .failed(error.localizedDescription))
        }
      }
      book.tasks[id] = Download(generation: generation, task: task)
      book.notify()
      return task
    }
  }

  private func stateOnDisk(_ manifest: ModelManifest) -> ModelState {
    let directory = installedDirectory(manifest)
    return manifest.files.allSatisfy {
      (try? FileManager.default.attributesOfItem(atPath: directory.appending(path: $0.path).path)[
        .size] as? Int64) == $0.size
    } ? .installed(directory) : .missing
  }

  private func recoverInstalled(_ manifest: ModelManifest) throws {
    let directory = installedDirectory(manifest)
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    do {
      try verifyInstalled(manifest)
      return
    } catch {
      // Keep each extant manifest file, including an incomplete installed set. The download
      // loop verifies these individually and fetches only missing or invalid files.
      let incomplete = incompleteDirectory(manifest)
      try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
      for file in manifest.files {
        let source = directory.appending(path: file.path)
        let destination = incomplete.appending(path: file.path)
        guard FileManager.default.fileExists(atPath: source.path) else { continue }
        if FileManager.default.fileExists(atPath: destination.path) {
          if (try? verify(destination, against: file)) != nil { continue }
          try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(
          at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: destination)
      }
      try FileManager.default.removeItem(at: directory)
    }
  }

  func install(_ manifest: ModelManifest) async throws {
    try Task.checkCancellation()
    try await waitForInstallation(manifest, task: start(manifest))
  }

  func waitForInstallation(_ manifest: ModelManifest, task: Task<Void, Never>) async throws {
    await task.value
    try Task.checkCancellation()
    switch state(of: manifest) {
    case .installed: return
    case .failed(let message): throw ProviderError.failed(message)
    default: throw CancellationError()
    }
  }

  func cancel(_ manifest: ModelManifest) {
    book.withLock {
      $0.generations[manifest.directoryName] = nil
      $0.tasks[manifest.directoryName]?.task.cancel()
      // Keep the task registered until it has stopped writing retained files.
      $0.notify()
    }
  }

  /// A fresh stream for one follower, yielding whenever any model's state changes. The follower
  /// stops by ending iteration.
  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: Void.self, bufferingPolicy: .bufferingNewest(1))
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

  private func download(_ manifest: ModelManifest, generation: UUID) async throws {
    let id = manifest.directoryName
    let incomplete = incompleteDirectory(manifest)
    try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)

    var done: Int64 = 0
    for file in manifest.files {
      try Task.checkCancellation()
      let destination = incomplete.appending(path: file.path)
      // Recovered and retained files must verify before reuse.
      if (try? verify(destination, against: file)) == nil {
        try? FileManager.default.removeItem(at: destination)
        let partial = destination.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: partial)
        try FileManager.default.createDirectory(
          at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let before = done
        try await source.fetch(manifest.downloadURL(for: file), partial) { [self] written in
          report(id, generation: generation, done: before + written, total: manifest.totalBytes)
        }
        try Task.checkCancellation()
        do { try verify(partial, against: file) } catch {
          try? FileManager.default.removeItem(at: partial)
          throw error
        }
        try FileManager.default.moveItem(at: partial, to: destination)
      }
      done += file.size
      report(id, generation: generation, done: done, total: manifest.totalBytes)
    }
    try Task.checkCancellation()
    try book.withLock { book in
      guard book.generations[id] == generation else { throw CancellationError() }
      let installed = installedDirectory(manifest)
      if FileManager.default.fileExists(atPath: installed.path) {
        try FileManager.default.removeItem(at: installed)
      }
      try FileManager.default.moveItem(at: incomplete, to: installed)
    }
  }

  func verifyInstalled(_ manifest: ModelManifest) throws {
    for file in manifest.files {
      try verify(installedDirectory(manifest).appending(path: file.path), against: file)
    }
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
  private func report(_ id: String, generation: UUID, done: Int64, total: Int64) {
    book.withLock { book in
      guard book.generations[id] == generation,
        case .downloading(let previous, _) = book.states[id] else { return }
      guard done == total || done - previous >= max(total / 100, 1) else { return }
      book.states[id] = .downloading(done: done, total: total)
      book.notify()
    }
  }

  /// Ends the download. A nil state means installed, which the disk now answers.
  private func finish(_ id: String, generation: UUID, with state: ModelState?) {
    book.withLock { book in
      guard book.tasks[id]?.generation == generation else { return }
      book.tasks[id] = nil
      book.states[id] = book.generations[id] == generation ? state : nil
      book.generations[id] = nil
      book.notify()
    }
  }
}

extension ModelStore {
  func signal() { book.withLock { $0.notify() } }

  func missingBytes(_ manifest: ModelManifest) -> Int64 {
    if case .installed = state(of: manifest) { return 0 }
    return manifest.files.reduce(0) { total, file in
      let retained = incompleteDirectory(manifest).appending(path: file.path)
      let installed = installedDirectory(manifest).appending(path: file.path)
      let complete = [retained, installed].contains { path in
        (try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? Int64) == file.size
      }
      return total + (complete ? 0 : file.size)
    }
  }

  func availableBytes() -> Int64? {
    var existing = root
    while !FileManager.default.fileExists(atPath: existing.path), existing.path != "/" {
      existing.deleteLastPathComponent()
    }
    return (try? existing.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
      .volumeAvailableCapacityForImportantUsage
  }

  private var externalLinks: [URL] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    return [
      CtcModels.defaultCacheDirectory(), home.appending(path: ".cache/fluidaudio/Models/kokoro"),
    ]
  }

  /// Enumerates without following symlinks, including generated, retained and obsolete files.
  func inventory(manifests: [ModelManifest]) throws -> [LocalFile] {
    let files = FileManager.default
    let supported = Set(manifests.map(\.directoryName))
    // Preserve these ownership names after experimental runtimes are pruned.
    let historicalNames: Set<String> = [
      "parakeet-unified-en-0.6b-640ms-int8", "silero-vad-256ms-v6.2.1", "parakeet-ctc-110m",
      "whisper-large-v3-turbo-626mb", "whisper-large-v3-tokenizer", "qwen3-4b-instruct-2507-4bit",
      "smollm3-3b-4bit", "kokoro-82m-ane-en", "qwen3-tts-12hz-1.7b-customvoice-4bit",
      "qwen3-tts-12hz-0.6b-customvoice-4bit",
    ]
    func owned(_ name: String) -> Bool {
      if supported.contains(name) || name == "espeak-english-trial-fd28f646" { return true }
      guard name.count > 41, name.suffix(40).allSatisfy(\.isHexDigit), name.dropLast(40).last == "-"
      else { return false }
      return historicalNames.contains(String(name.dropLast(41)))
    }
    var result: [LocalFile] = []
    func bytes(_ path: URL) throws -> Int64 {
      let attributes = try files.attributesOfItem(atPath: path.path)
      if attributes[.type] as? FileAttributeType == .typeSymbolicLink { return 0 }
      if attributes[.type] as? FileAttributeType != .typeDirectory {
        return (attributes[.size] as? Int64) ?? 0
      }
      return try files.contentsOfDirectory(at: path, includingPropertiesForKeys: nil).reduce(0) {
        try $0 + bytes($1)
      }
    }
    if files.fileExists(atPath: root.path) {
      for path in try files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
        if path.lastPathComponent == "Incomplete" {
          for retained in try files.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
          where owned(retained.lastPathComponent) {
            result.append(
              LocalFile(
                id: retained, name: retained.lastPathComponent, category: "Retained download",
                bytes: try bytes(retained)))
          }
        } else if owned(path.lastPathComponent) {
          let oldFrontendNames = [
            "G2PEncoder.mlmodelc", "G2PDecoder.mlmodelc", "g2p_vocab.json", "us_lexicon_cache.json",
          ]
          var legacy: [LocalFile] = []
          if path.lastPathComponent.hasPrefix("kokoro-") {
            for name in oldFrontendNames {
              let obsolete = path.appending(path: name)
              if files.fileExists(atPath: obsolete.path) {
                legacy.append(
                  LocalFile(
                    id: obsolete, name: name, category: "Obsolete speech frontend",
                    bytes: try bytes(obsolete)))
              }
            }
          }
          result.append(
            LocalFile(
              id: path, name: path.lastPathComponent,
              category: supported.contains(path.lastPathComponent)
                ? "Installed and generated" : "Obsolete",
              bytes: max(0, try bytes(path) - legacy.reduce(0) { $0 + $1.bytes })))
          result += legacy
        }
      }
    }
    // Only links whose destinations belong to this store are EchoType-owned.
    for link in externalLinks {
      guard let target = try? files.destinationOfSymbolicLink(atPath: link.path) else { continue }
      let resolved = URL(fileURLWithPath: target, relativeTo: link.deletingLastPathComponent())
        .standardizedFileURL
      guard resolved.path.hasPrefix(root.standardizedFileURL.path + "/"),
        owned(resolved.lastPathComponent)
      else { continue }
      result.append(
        LocalFile(
          id: link, name: link.lastPathComponent + " cache link", category: "Runtime link", bytes: 0
        ))
    }
    return result.sorted { $0.id.path < $1.id.path }
  }

  func remove(_ requested: [LocalFile], manifests: [ModelManifest]) throws {
    try book.withLock { book in
      guard requested.allSatisfy({ book.tasks[$0.id.lastPathComponent] == nil }) else {
        throw ProviderError.failed("Wait for these downloads to stop before removing files.")
      }
      let owned = Set(try inventory(manifests: manifests).map(\.id))
      guard requested.allSatisfy({ owned.contains($0.id) }) else {
        throw ProviderError.failed("The file list changed. Refresh it before removing files.")
      }
      for file in requested.sorted(by: { $0.id.path.count > $1.id.path.count }) {
        try FileManager.default.removeItem(at: file.id)
        book.states[file.id.lastPathComponent] = nil
      }
      // Remove only links still targeting a deleted owned installation.
      for link in externalLinks {
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path),
          requested.contains(where: { $0.id.path == target })
        else { continue }
        try FileManager.default.removeItem(at: link)
      }
      book.notify()
    }
  }
}
