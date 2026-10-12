import Foundation
import Synchronization

/// One service's life in the process: the download of its pinned models, loading them, and the
/// loaded runtime. Its manifests and loader describe the supported model set; status checks
/// report readiness without installing or preparing it.
final class LocalModel<Loaded: Sendable>: Sendable {
  private struct State {
    var loaded: Loaded?
    var task: Task<Void, Never>?
    var generation: UUID?
    var failure: String?
  }
  let manifests: [ModelManifest]
  private let loadingMessage: String
  private let load: @Sendable ([URL]) async throws -> Loaded
  private let store: ModelStore
  private let state = Mutex(State())
  private let followers = Mutex<[UUID: AsyncStream<Void>.Continuation]>([:])

  init(manifests: [ModelManifest], loadingMessage: String, store: ModelStore,
    load: @escaping @Sendable ([URL]) async throws -> Loaded) {
    self.manifests = manifests; self.loadingMessage = loadingMessage
    self.store = store; self.load = load
  }

  var loaded: Loaded? { state.withLock { $0.loaded } }

  /// Reports status. It never starts a download or loads a runtime.
  func check() -> ServiceState {
    var done: Int64 = 0
    var installed = 0
    for manifest in manifests {
      switch store.state(of: manifest) {
      case .installed: installed += 1; done += manifest.totalBytes
      case .downloading(let bytes, _):
        done += bytes
        return downloading(done: done, total: manifests.reduce(0) { $0 + $1.totalBytes })
      case .failed(let message): return .unavailable(message)
      case .missing: return .unavailable("Download models in Settings > Local.")
      }
    }
    guard installed == manifests.count else { return .unavailable("Download models in Settings > Local.") }
    return state.withLock {
      if $0.loaded != nil { return .ready }
      if $0.task != nil { return .waiting(loadingMessage) }
      if let failure = $0.failure { return .unavailable(failure) }
      return .waiting("Installed. Prepare in Settings > Local, or start this feature.")
    }
  }

  /// Concurrent callers join one installed-only load. A cancelled setup cannot publish Ready.
  /// A failed load stays failed until `retrying` is set, which only setup in Settings does.
  func beginPreparation(retrying: Bool = false) throws {
    let directories = try manifests.map { manifest in
      guard case .installed(let directory) = store.state(of: manifest) else {
        throw ProviderError.failed("Download models in Settings > Local.")
      }
      return directory
    }
    let started = try state.withLock { state -> Bool in
      if state.loaded != nil || state.task != nil { return false }
      if let failure = state.failure, !retrying { throw ProviderError.failed(failure) }
      let generation = UUID()
      state.generation = generation; state.failure = nil
      let task = Task.detached { [self] in
        var loaded: Loaded?
        var failure: String?
        do {
          loaded = try await load(directories)
        } catch {
          failure = error is CancellationError ? nil : error.localizedDescription
        }
        self.state.withLock {
          guard $0.generation == generation else { return }
          $0.loaded = loaded; $0.failure = failure; $0.task = nil
        }
        notify()
      }
      state.task = task
      return true
    }
    if started { notify() }
  }

  func prepare() async throws {
    try Task.checkCancellation()
    try beginPreparation()
    try await waitForPreparation()
  }

  /// Returns when the current load ends, or at once when the caller is cancelled. The load
  /// itself keeps running for the next caller.
  func waitForPreparation() async throws {
    var updates = changes().makeAsyncIterator()
    while preparing, await updates.next() != nil {}
    try Task.checkCancellation()
    guard loaded != nil else { throw ProviderError.failed(check().message ?? "Preparation cancelled.") }
  }

  func cancel() {
    state.withLock {
      $0.generation = nil; $0.task?.cancel(); $0.task = nil; $0.loaded = nil; $0.failure = nil
    }
    notify()
  }

  var preparing: Bool { state.withLock { $0.task != nil } }

  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    let upstream = store.changes()
    let downloads = Task { for await _ in upstream { continuation.yield() } }
    continuation.onTermination = { [weak self] _ in
      downloads.cancel()
      self?.followers.withLock { _ = $0.removeValue(forKey: id) }
    }
    followers.withLock { $0[id] = continuation }
    return stream
  }

  private func notify() { followers.withLock { for follower in $0.values { follower.yield() } } }

  func downloading(done: Int64, total: Int64) -> ServiceState {
    let (scale, decimals, unit) = total < 1_000_000_000 ? (1e6, 0, "MB") : (1e9, 1, "GB")
    func size(_ bytes: Int64) -> String {
      (Double(bytes) / scale).formatted(.number.precision(.fractionLength(decimals)))
    }
    return .waiting("Downloading models, \(size(done)) of \(size(total)) \(unit)")
  }
}

/// Points a runtime's fixed path at a model directory. A link into EchoType's store, such as
/// one to an earlier revision, is replaced. Anything else there belongs to another install, so
/// it is left alone and loading fails.
func link(_ link: URL, to directory: URL, store: URL = ModelStore.defaultRoot) throws {
  let files = FileManager.default
  if let path = try? files.destinationOfSymbolicLink(atPath: link.path) {
    let target = URL(fileURLWithPath: path, relativeTo: link.deletingLastPathComponent())
    if target.resolvingSymlinksInPath().path == directory.resolvingSymlinksInPath().path { return }
    guard target.deletingLastPathComponent().resolvingSymlinksInPath().path == store.resolvingSymlinksInPath().path
    else { throw ProviderError.failed("\(link.path) belongs to another app. Move it and try again.") }
    try files.removeItem(at: link)
  } else if files.fileExists(atPath: link.path) {
    throw ProviderError.failed("\(link.path) belongs to another app. Move it and try again.")
  }
  try files.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
  try files.createSymbolicLink(at: link, withDestinationURL: directory)
}
