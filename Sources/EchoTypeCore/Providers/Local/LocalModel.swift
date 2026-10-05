import Foundation
import Synchronization

/// One service's life in the process: the download of its pinned models, loading them, and the
/// loaded runtime. A service's candidate supplies the manifests and the loader; this reports
/// readiness. Only the candidates the provider was built with are ever prepared.
final class LocalModel<Loaded: Sendable>: Sendable {
  private enum Load {
    case notLoaded
    case loading
    case loaded(Loaded)
    case failed(String)
  }

  private let manifests: [ModelManifest]
  /// Said while loading, such as "Loading the cleanup model".
  private let loadingMessage: String
  /// Loads and warms the runtime from the installed directories, in the manifests' order.
  private let load: @Sendable ([URL]) async throws -> Loaded
  private let store: ModelStore
  private let state = Mutex(Load.notLoaded)
  private let followers = Mutex<[UUID: AsyncStream<Void>.Continuation]>([:])

  init(
    manifests: [ModelManifest], loadingMessage: String, store: ModelStore,
    load: @escaping @Sendable ([URL]) async throws -> Loaded
  ) {
    self.manifests = manifests
    self.loadingMessage = loadingMessage
    self.store = store
    self.load = load
  }

  /// The runtime once it is loaded and warmed.
  var loaded: Loaded? {
    state.withLock { if case .loaded(let loaded) = $0 { loaded } else { nil } }
  }

  /// The service's state, starting setup the first time it is needed. `.ready` only once the
  /// models are loaded and warmed. A failed download stays failed, since starting it again on every
  /// check would loop while offline: `ModelStore.start` restarts failures and every state change
  /// yields on `changes()`.
  func check() -> ServiceState {
    let states = manifests.map { manifest in
      var state = store.state(of: manifest)
      if case .missing = state {
        store.start(manifest)
        state = store.state(of: manifest)
      }
      return state
    }
    var directories: [URL] = []
    var done: Int64 = 0
    for (manifest, state) in zip(manifests, states) {
      switch state {
      case .failed(let message): return .unavailable(message)
      case .installed(let directory):
        directories.append(directory)
        done += manifest.totalBytes
      case .downloading(let bytes, _): done += bytes
      case .missing: break
      }
    }
    if directories.count == manifests.count { return startLoading(from: directories) }
    return downloading(done: done, total: manifests.reduce(0) { $0 + $1.totalBytes })
  }

  /// A fresh stream that yields when a download or the load moves on.
  func changes() -> AsyncStream<Void> {
    let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    // Subscribed now, not in the task, so a change before the task starts is not missed.
    let upstream = store.changes()
    let downloads = Task { for await _ in upstream { continuation.yield() } }
    continuation.onTermination = { [weak self] _ in
      downloads.cancel()
      self?.followers.withLock { _ = $0.removeValue(forKey: id) }
    }
    followers.withLock { $0[id] = continuation }
    return stream
  }

  private func downloading(done: Int64, total: Int64) -> ServiceState {
    func gigabytes(_ bytes: Int64) -> String {
      (Double(bytes) / 1e9).formatted(.number.precision(.fractionLength(1)))
    }
    return .waiting("Downloading models, \(gigabytes(done)) of \(gigabytes(total)) GB")
  }

  /// Loads and warms the runtime in a task this object owns, so a provider switch does not stop it.
  private func startLoading(from directories: [URL]) -> ServiceState {
    let (result, begins): (ServiceState, Bool) = state.withLock { load in
      switch load {
      case .notLoaded:
        load = .loading
        return (.waiting(loadingMessage), true)
      case .loading: return (.waiting(loadingMessage), false)
      case .loaded: return (.ready, false)
      case .failed(let message): return (.unavailable(message), false)
      }
    }
    guard begins else { return result }
    Task {
      do {
        let loaded = try await load(directories)
        state.withLock { $0 = .loaded(loaded) }
      } catch {
        state.withLock { $0 = .failed(error.localizedDescription) }
      }
      followers.withLock { for follower in $0.values { follower.yield() } }
    }
    return result
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
