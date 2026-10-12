import Foundation
import Synchronization

final class LocalLifecycle: Sendable {
  private struct State {
    var selected: Set<ProviderFeature> = []
    var operations: [ProviderFeature: Int] = [:]
    var setup: ProviderFeature?
  }
  private let state = Mutex(State())
  private let store: ModelStore
  private let transcription: LocalModel<ParakeetModel.Start>?
  private let cleanup: LocalModel<CleanupModel>?
  private let voice: LocalModel<KokoroModel.Speak>?
  private let memoryPressure = DispatchSource.makeMemoryPressureSource(eventMask: .critical)

  init(
    store: ModelStore, transcription: LocalModel<ParakeetModel.Start>?,
    cleanup: LocalModel<CleanupModel>?, voice: LocalModel<KokoroModel.Speak>?
  ) {
    self.store = store
    self.transcription = transcription
    self.cleanup = cleanup
    self.voice = voice
    // Cleanup is the largest model and the only one a dictation can start without, so it
    // goes first. The next dictation loads it again in the background. A 16 GB Mac reaches
    // warning pressure with every model loaded, so only critical pressure releases it.
    memoryPressure.setEventHandler { [weak self] in
      guard let self, cleanup?.loaded != nil,
        state.withLock({ $0.operations[.dictation, default: 0] == 0 })
      else { return }
      cleanup?.cancel()
    }
    memoryPressure.activate()
  }

  deinit { memoryPressure.cancel() }

  private func manifests(_ features: Set<ProviderFeature>) -> [ModelManifest] {
    var seen: Set<String> = []
    let requested =
      (features.contains(.dictation)
        ? (transcription?.manifests ?? []) + (cleanup?.manifests ?? []) : [])
      + (features.contains(.readAloud) ? voice?.manifests ?? [] : [])
    return requested.filter { seen.insert($0.directoryName).inserted }
  }

  func prepare(_ feature: ProviderFeature) async throws -> RuntimeLease {
    state.withLock { $0.operations[feature, default: 0] += 1 }
    store.signal()
    let lease = RuntimeLease { [self] in
      state.withLock { $0.operations[feature, default: 0] -= 1 }
      releaseUnused()
      store.signal()
    }
    if feature == .dictation {
      guard let transcription else { throw ProviderError.unavailable }
      // Cleanup loads in the background; a dictation that starts first skips cleanup.
      try? cleanup?.beginPreparation()
      try await transcription.prepare()
    } else {
      guard let voice else { throw ProviderError.unavailable }
      try await voice.prepare()
    }
    return lease
  }

  private func releaseUnused() {
    state.withLock { releaseUnused(&$0, features: Set(ProviderFeature.allCases)) }
  }

  private func releaseUnused(_ state: inout State, features: Set<ProviderFeature>) {
    for feature in features
    where !state.selected.contains(feature) && state.setup != feature
      && state.operations[feature, default: 0] == 0
    {
      release(feature)
    }
  }

  private func release(_ feature: ProviderFeature) {
    if feature == .dictation {
      transcription?.cancel()
      cleanup?.cancel()
    } else {
      voice?.cancel()
    }
  }

  private func affectedFeatures(_ files: [InstalledFile]) -> Set<ProviderFeature> {
    return Set(
      ProviderFeature.allCases.filter { feature in
        let names = Set(manifests([feature]).map(\.directoryName))
        return files.contains { file in
          if names.contains(file.id.lastPathComponent)
            || names.contains(file.id.deletingLastPathComponent().lastPathComponent)
          {
            return true
          }
          if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: file.id.path) {
            return names.contains(URL(fileURLWithPath: target).lastPathComponent)
          }
          return false
        }
      })
  }

  private func removalBlock(_ files: [InstalledFile], state: State) -> String? {
    let affected = affectedFeatures(files)
    if let setup = state.setup, affected.contains(setup) {
      return "Cancel setup and wait for it to finish before removing these files."
    }
    for feature in affected {
      if state.operations[feature, default: 0] > 0 {
        return "Stop \(feature.title) before removing its files."
      }
      if feature == .dictation
        ? transcription?.preparing == true || cleanup?.preparing == true : voice?.preparing == true
      {
        return "Wait for \(feature.title) preparation to finish."
      }
    }
    return nil
  }

  /// Starting the load and setup's cancellation take the same lock, so a cancelled setup never
  /// starts a load that would outlive it.
  private func load<Loaded>(_ model: LocalModel<Loaded>?) async throws {
    guard let model else { return }
    try state.withLock { _ in
      try Task.checkCancellation()
      try model.beginPreparation(retrying: true)
    }
    try await model.waitForPreparation()
  }

  var controls: ProviderSetup {
    ProviderSetup(
      requirements: { [self] features in
        manifests(features).map { manifest in
          let installed: Bool
          if case .installed = store.state(of: manifest) {
            installed = true
          } else {
            installed = false
          }
          return SetupRequirement(
            id: manifest.directoryName, name: manifest.name,
            purpose: [
              transcription?.manifests.contains(manifest) == true ? "Transcription" : nil,
              cleanup?.manifests.contains(manifest) == true ? "Cleanup" : nil,
              voice?.manifests.contains(manifest) == true ? "Speech" : nil,
            ].compactMap { $0 }.joined(separator: " and "),
            bytes: manifest.totalBytes, missingBytes: installed ? 0 : store.missingBytes(manifest),
            installed: installed,
            source: URL(
              string: "https://huggingface.co/\(manifest.repository)/tree/\(manifest.revision)")!,
            license: manifest.license)
        }
      },
      install: { [self] feature in
        let requested = manifests([feature])
        try state.withLock {
          guard $0.setup == nil else { throw ProviderError.failed("Wait for the current setup to finish.") }
          let missing = requested.reduce(Int64(0)) { $0 + store.missingBytes($1) }
          if let free = store.availableBytes(), free < missing {
            throw ProviderError.failed(
              "Not enough disk space. Free \(ByteCountFormatter.string(fromByteCount: missing - free, countStyle: .file)) and retry."
            )
          }
          $0.setup = feature
        }
        defer {
          state.withLock {
            $0.setup = nil
            releaseUnused(&$0, features: [feature])
          }
          store.signal()
        }
        try await withTaskCancellationHandler {
          for manifest in requested { try await store.install(manifest) }
          if feature == .dictation {
            try await load(transcription)
            try await load(cleanup)
          } else {
            try await load(voice)
          }
        } onCancel: {
          for manifest in requested { store.cancel(manifest) }
          state.withLock { if $0.operations[feature, default: 0] == 0 { release(feature) } }
        }
      },
      progress: { [self] feature in
        let manifests = manifests([feature])
        var downloading = false
        let done = manifests.reduce(Int64(0)) { total, manifest in
          switch store.state(of: manifest) {
          case .installed: return total + manifest.totalBytes
          case .downloading(let bytes, _): downloading = true; return total + bytes
          default: return total
          }
        }
        let total = manifests.reduce(Int64(0)) { $0 + $1.totalBytes }
        return downloading && total > 0 ? Double(done) / Double(total) : nil
      },
      inventory: { [self] in
        try store.inventory(manifests: manifests(Set(ProviderFeature.allCases))).map { file in
          var file = file
          file.features = affectedFeatures([file])
          return file
        }
      },
      remove: { [self] files in
        try state.withLock {
          if let reason = removalBlock(files, state: $0) { throw ProviderError.failed(reason) }
          for feature in affectedFeatures(files) { release(feature) }
          try store.remove(files, manifests: manifests(Set(ProviderFeature.allCases)))
        }
      }, removalBlock: { [self] files in state.withLock { removalBlock(files, state: $0) } },
      select: { [self] selected in
        let added = state.withLock {
          let added = selected.subtracting($0.selected)
          $0.selected = selected
          releaseUnused(&$0, features: Set(ProviderFeature.allCases))
          return added
        }
        // Load what is installed so the first operation does not wait. This never downloads.
        if added.contains(.dictation) {
          try? transcription?.beginPreparation()
          try? cleanup?.beginPreparation()
        }
        if added.contains(.readAloud) { try? voice?.beginPreparation() }
      },
      availableBytes: { [store] in store.availableBytes() })
  }
}
