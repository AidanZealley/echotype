import Foundation
import Synchronization

public enum ProviderFeature: String, CaseIterable, Identifiable, Sendable, Hashable {
  case dictation, readAloud
  public var id: String { rawValue }
  public var title: String { self == .dictation ? "Dictation" : "Read Aloud" }
}

/// Keeps a prepared feature alive until its operation has finished teardown.
public final class RuntimeLease: Sendable {
  private let end: @Sendable () -> Void
  public init(end: @escaping @Sendable () -> Void = {}) { self.end = end }
  deinit { end() }
}

public struct LocalRequirement: Identifiable, Sendable {
  public var id: String
  public var name: String
  public var purpose: String
  public var bytes: Int64
  public var missingBytes: Int64
  public var installed: Bool
  public var source: URL
  public var license: String
}

public struct LocalFile: Identifiable, Sendable, Hashable {
  public var id: URL
  public var name: String
  public var category: String
  public var bytes: Int64
  public var features: Set<ProviderFeature> = []
}

/// Explicit setup and storage controls. Reporting and operation preparation use separate APIs.
public struct LocalSetup: Sendable {
  public var requirements: @Sendable (Set<ProviderFeature>) -> [LocalRequirement]
  public var install: @Sendable (Set<ProviderFeature>) async throws -> Void
  public var cancel: @Sendable (Set<ProviderFeature>) -> Void
  public var inventory: @Sendable () throws -> [LocalFile]
  public var remove: @Sendable ([LocalFile]) throws -> Void
  public var removalBlock: @Sendable ([LocalFile]) -> String?
  public var select: @Sendable (Set<ProviderFeature>) -> Void
  public var availableBytes: @Sendable () -> Int64?
}

final class LocalLifecycle: Sendable {
  private struct State {
    var selected: Set<ProviderFeature> = []
    var operations: [ProviderFeature: Int] = [:]
    var setup: Set<ProviderFeature> = []
    var setupGenerations: [ProviderFeature: UUID] = [:]
    var releaseAfterSetup: Set<ProviderFeature> = []
    var removing = false
    var removingFeatures: Set<ProviderFeature> = []
  }
  private let state = Mutex(State())
  private let store: ModelStore
  private let transcription: LocalModel<TranscriptionCandidate.Start>?
  private let cleanup: LocalModel<CleanupModel>?
  private let voice: LocalModel<VoiceCandidate.Speak>?

  init(
    store: ModelStore, transcription: LocalModel<TranscriptionCandidate.Start>?,
    cleanup: LocalModel<CleanupModel>?, voice: LocalModel<VoiceCandidate.Speak>?
  ) {
    self.store = store
    self.transcription = transcription
    self.cleanup = cleanup
    self.voice = voice
  }

  private func manifests(_ features: Set<ProviderFeature>) -> [ModelManifest] {
    var seen: Set<String> = []
    let requested =
      (features.contains(.dictation)
        ? (transcription?.manifests ?? []) + (cleanup?.manifests ?? []) : [])
      + (features.contains(.readAloud) ? voice?.manifests ?? [] : [])
    return requested.filter { seen.insert($0.directoryName).inserted }
  }

  func prepare(_ feature: ProviderFeature) async throws -> RuntimeLease {
    try state.withLock {
      guard !$0.removing || !$0.removingFeatures.contains(feature) else {
        throw ProviderError.failed("Models are being removed. Retry after removal finishes.")
      }
      $0.operations[feature, default: 0] += 1
    }
    store.signal()
    let lease = RuntimeLease { [self] in
      state.withLock { $0.operations[feature, default: 0] -= 1 }
      releaseUnused()
      store.signal()
    }
    if feature == .dictation {
      guard let transcription else { throw ProviderError.unavailable }
      try await transcription.prepare()
      // The existing policy permits transcription if cleanup cannot prepare.
      try? await cleanup?.prepare()
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
    where !state.selected.contains(feature) && !state.setup.contains(feature)
      && state.operations[feature, default: 0] == 0
    {
      if feature == .dictation {
        transcription?.release()
        cleanup?.release()
      } else {
        voice?.release()
      }
      state.releaseAfterSetup.remove(feature)
    }
  }

  private func affectedFeatures(_ files: [LocalFile]) -> Set<ProviderFeature> {
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

  private func removalBlock(_ files: [LocalFile], state: State) -> String? {
    let affected = affectedFeatures(files)
    if state.removing { return "Wait for the current removal to finish." }
    if !state.setup.isDisjoint(with: affected) {
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

  private func checkSetup(_ generation: UUID, features: Set<ProviderFeature>) throws {
    try Task.checkCancellation()
    guard
      state.withLock({ state in features.allSatisfy { state.setupGenerations[$0] == generation } })
    else { throw CancellationError() }
  }

  private func prepareSetup<Loaded>(
    _ model: LocalModel<Loaded>?, generation: UUID,
    features: Set<ProviderFeature>
  ) async throws {
    guard let model else { return }
    try Task.checkCancellation()
    let task = try state.withLock { state in
      guard features.allSatisfy({ state.setupGenerations[$0] == generation }) else {
        throw CancellationError()
      }
      return try model.beginPreparation()
    }
    try await model.waitForPreparation(task)
  }

  var controls: LocalSetup {
    LocalSetup(
      requirements: { [self] features in
        manifests(features).map { manifest in
          let installed: Bool
          if case .installed = store.state(of: manifest) {
            installed = true
          } else {
            installed = false
          }
          return LocalRequirement(
            id: manifest.directoryName, name: manifest.name,
            purpose: [
              transcription?.manifests.contains(manifest) == true ? "Dictation transcription" : nil,
              cleanup?.manifests.contains(manifest) == true ? "Dictation cleanup" : nil,
              voice?.manifests.contains(manifest) == true ? "Read Aloud" : nil,
            ].compactMap { $0 }.joined(separator: " and "),
            bytes: manifest.totalBytes, missingBytes: installed ? 0 : store.missingBytes(manifest),
            installed: installed,
            source: URL(
              string: "https://huggingface.co/\(manifest.repository)/tree/\(manifest.revision)")!,
            license: manifest.license)
        }
      },
      install: { [self] features in
        guard !features.isEmpty else { return }
        let requested = manifests(features)
        let generation = UUID()
        let downloads = try state.withLock {
          guard !$0.removing || $0.removingFeatures.isDisjoint(with: features),
            $0.setup.isDisjoint(with: features)
          else { throw ProviderError.failed("Wait for this feature's setup or removal to finish.") }
          let missing = requested.reduce(Int64(0)) { $0 + store.missingBytes($1) }
          if let free = store.availableBytes(), free < missing {
            throw ProviderError.failed(
              "Not enough disk space. Free \(ByteCountFormatter.string(fromByteCount: missing - free, countStyle: .file)) and retry."
            )
          }
          $0.setup.formUnion(features)
          for feature in features { $0.setupGenerations[feature] = generation }
          return requested.map { store.start($0) }
        }
        defer {
          state.withLock {
            $0.setup.subtract(features)
            for feature in features { $0.setupGenerations[feature] = nil }
            releaseUnused(&$0, features: $0.releaseAfterSetup)
          }
          store.signal()
        }
        try await withTaskCancellationHandler {
          for (manifest, task) in zip(requested, downloads) {
            try checkSetup(generation, features: features)
            try await store.waitForInstallation(manifest, task: task)
          }
          for feature in ProviderFeature.allCases where features.contains(feature) {
            try checkSetup(generation, features: features)
            if feature == .dictation {
              try await prepareSetup(transcription, generation: generation, features: features)
              try await prepareSetup(cleanup, generation: generation, features: features)
            } else {
              try await prepareSetup(voice, generation: generation, features: features)
            }
          }
          try checkSetup(generation, features: features)
        } onCancel: {
          controls.cancel(features)
        }
      },
      cancel: { [self] features in
        state.withLock {
          for feature in features { $0.setupGenerations[feature] = nil }
          let retained = Set(manifests(Set($0.setupGenerations.keys)).map(\.directoryName))
          for manifest in manifests(features) where !retained.contains(manifest.directoryName) {
            store.cancel(manifest)
          }
          if features.contains(.dictation), $0.operations[.dictation, default: 0] == 0 {
            transcription?.cancel()
            cleanup?.cancel()
          }
          if features.contains(.readAloud), $0.operations[.readAloud, default: 0] == 0 {
            voice?.cancel()
          }
        }
      },
      inventory: { [self] in
        try store.inventory(manifests: manifests(Set(ProviderFeature.allCases))).map { file in
          var file = file
          file.features = affectedFeatures([file])
          return file
        }
      },
      remove: { [self] files in
        let affected = affectedFeatures(files)
        try state.withLock {
          if let reason = removalBlock(files, state: $0) { throw ProviderError.failed(reason) }
          $0.removing = true
          $0.removingFeatures = affected
          if affected.contains(.dictation) {
            transcription?.release()
            cleanup?.release()
          }
          if affected.contains(.readAloud) { voice?.release() }
        }
        defer {
          state.withLock {
            $0.removing = false
            $0.removingFeatures = []
          }
        }
        try store.remove(files, manifests: manifests(Set(ProviderFeature.allCases)))
      }, removalBlock: { [self] files in state.withLock { removalBlock(files, state: $0) } },
      select: { [self] selected in
        state.withLock {
          $0.releaseAfterSetup.formUnion($0.selected.subtracting(selected).intersection($0.setup))
          $0.releaseAfterSetup.subtract(selected)
          $0.selected = selected
          releaseUnused(&$0, features: Set(ProviderFeature.allCases))
        }
      },
      availableBytes: { [store] in store.availableBytes() })
  }
}
