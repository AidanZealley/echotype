import Foundation
import Synchronization

/// One cleanup candidate's life in the process: its download, its loading and the service that
/// uses the loaded model. Only the candidate the provider was built with is ever prepared.
final class LocalCleanup: Sendable {
  private enum Load {
    case notLoaded
    case loading
    case loaded(CleanupModel)
    case failed(String)
  }

  private let candidate: CleanupCandidate
  private let store: ModelStore
  private let state = Mutex(Load.notLoaded)
  private let followers = Mutex<[UUID: AsyncStream<Void>.Continuation]>([:])

  init(_ candidate: CleanupCandidate, store: ModelStore) {
    self.candidate = candidate
    self.store = store
  }

  var service: CleanupService {
    CleanupService { [self] request in
      guard case .loaded(let model) = state.withLock({ $0 }) else { throw ProviderError.unavailable }
      return try await model.revise(request)
    }
  }

  /// The service's state, starting setup the first time it is needed. `.ready` only once the
  /// model is loaded and warmed. A failed download stays failed, since starting it again on every
  /// check would loop while offline: `ModelStore.start` restarts failures and every state change
  /// yields on `changes()`.
  func check() -> ServiceState {
    let manifest = candidate.manifest
    var state = store.state(of: manifest)
    if case .missing = state {
      store.start(manifest)
      state = store.state(of: manifest)
    }
    switch state {
    case .missing: return downloading(done: 0, total: manifest.totalBytes)
    case .downloading(let done, let total): return downloading(done: done, total: total)
    case .failed(let message): return .unavailable(message)
    case .installed(let directory): return startLoading(from: directory)
    }
  }

  /// A fresh stream that yields when the download or the load moves on.
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

  /// Loads and warms the model in a task this object owns, so a provider switch does not stop it.
  private func startLoading(from directory: URL) -> ServiceState {
    let (result, begins): (ServiceState, Bool) = state.withLock { load in
      switch load {
      case .notLoaded:
        load = .loading
        return (.waiting("Loading the cleanup model"), true)
      case .loading: return (.waiting("Loading the cleanup model"), false)
      case .loaded: return (.ready, false)
      case .failed(let message): return (.unavailable(message), false)
      }
    }
    guard begins else { return result }
    let templateContext = candidate.templateContext
    Task {
      do {
        let loaded = try await CleanupModel.load(from: directory, templateContext: templateContext)
        state.withLock { $0 = .loaded(loaded) }
      } catch {
        state.withLock { $0 = .failed(error.localizedDescription) }
      }
      followers.withLock { for follower in $0.values { follower.yield() } }
    }
    return result
  }
}
