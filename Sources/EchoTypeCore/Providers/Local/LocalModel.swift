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
  func beginPreparation() throws -> Task<Void, Never>? {
    let directories = try manifests.map { manifest in
      guard case .installed(let directory) = store.state(of: manifest) else {
        throw ProviderError.failed("Download models in Settings > Local.")
      }
      return directory
    }
    let task = state.withLock { state -> Task<Void, Never>? in
      if state.loaded != nil { return nil }
      if let task = state.task { return task }
      let generation = UUID()
      state.generation = generation; state.failure = nil
      let task = Task.detached { [self] in
        do {
          for manifest in manifests { try store.verifyInstalled(manifest) }
          try Task.checkCancellation()
          let result = try await load(directories)
          try Task.checkCancellation()
          self.state.withLock {
            guard $0.generation == generation else { return }
            $0.loaded = result
          }
        } catch {
          self.state.withLock {
            guard $0.generation == generation else { return }
            $0.failure = error is CancellationError ? nil : error.localizedDescription
          }
        }
        self.state.withLock { $0.task = nil }
        notify()
      }
      state.task = task
      return task
    }
    notify()
    return task
  }

  func prepare() async throws {
    try Task.checkCancellation()
    try await waitForPreparation(beginPreparation())
  }

  func waitForPreparation(_ task: Task<Void, Never>?) async throws {
    await task?.value
    try Task.checkCancellation()
    guard loaded != nil else { throw ProviderError.failed(check().message ?? "Preparation cancelled.") }
  }

  func cancel() {
    state.withLock { $0.generation = nil; $0.task?.cancel(); $0.loaded = nil; $0.failure = nil }
    notify()
  }

  func release() { cancel() }
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

/// Points `link`, a folder a runtime reads from a fixed path, at a model's verified `directory`,
/// so the runtime finds the store's copy instead of downloading its own. A link already there is
/// left alone, and a real folder, from another tool using the same runtime, is never touched. Only
/// a missing or stale link is written, so two processes loading at once do not fight over it:
/// whoever loses finds the link already right.
func linkFolder(at link: URL, to directory: URL) throws {
  let files = FileManager.default
  func pointsAtStore() -> Bool {
    (try? files.destinationOfSymbolicLink(atPath: link.path)) == directory.path
  }
  if let type = try? files.attributesOfItem(atPath: link.path)[.type] as? FileAttributeType {
    guard type == .typeSymbolicLink, !pointsAtStore() else { return }
    try? files.removeItem(at: link)
  }
  try files.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
  do {
    try files.createSymbolicLink(at: link, withDestinationURL: directory)
  } catch where pointsAtStore() {}
}
