import CryptoKit
import Foundation
import Synchronization
import Testing
@testable import EchoTypeCore

private struct NeverSpeech: SpeechStream {
  func next() async throws -> SpeechAudio? { nil }
  func cancel() {}
}

@Suite struct LocalLifecycleTests {
  private func fixture(_ name: String = "tiny") -> ModelManifest {
    let data = Data([1, 2, 3])
    return ModelManifest(name: name, repository: "test/tiny", revision: "123", license: "MIT",
      files: [.init(path: "file", size: 3, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())])
  }

  @Test("Status and installed-only preparation never fetch missing assets")
  func reporting() async {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let fetches = Mutex(0)
    let loads = Mutex(0)
    let store = ModelStore(root: root, source: .init { _, _, _ in fetches.withLock { $0 += 1 } })
    let model = LocalModel(manifests: [fixture()], loadingMessage: "Loading", store: store) { _ in
      loads.withLock { $0 += 1 }; return 1
    }
    for _ in 0..<3 { #expect(model.check().status == .unavailable) }
    await #expect(throws: (any Error).self) { try await model.prepare() }
    #expect(fetches.withLock { $0 } == 0)
    #expect(loads.withLock { $0 } == 0)
    #expect(!FileManager.default.fileExists(atPath: root.path))
  }

  @Test("Concurrent preparation joins one loader and cancellation rejects late Ready")
  func preparation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ModelStore(root: root)
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let loads = Mutex(0)
    let model = LocalModel<Int>(manifests: [], loadingMessage: "Loading", store: store) { _ in
      loads.withLock { $0 += 1 }; entered.continuation.yield()
      for await _ in release.stream { break }
      return 42
    }
    #expect(model.check().status == .waiting)
    #expect(loads.withLock { $0 } == 0)
    let first = Task { try? await model.prepare() }
    for await _ in entered.stream { break }
    let second = Task { try? await model.prepare() }
    release.continuation.finish()
    await first.value; await second.value
    #expect(model.loaded == 42)
    #expect(loads.withLock { $0 } == 1)
    let cancellationEntered = AsyncStream.makeStream(of: Void.self)
    let cancellationRelease = AsyncStream.makeStream(of: Void.self)
    let cancelled = LocalModel<Int>(manifests: [], loadingMessage: "Loading", store: store) { _ in
      cancellationEntered.continuation.yield()
      for await _ in cancellationRelease.stream { break }
      return 99
    }
    let attempt = Task { try? await cancelled.prepare() }
    for await _ in cancellationEntered.stream { break }
    cancelled.cancel()
    cancellationRelease.continuation.finish()
    await attempt.value
    #expect(cancelled.loaded == nil)
    #expect(cancelled.check().status != .ready)
  }

  @Test("Cancelled downloads cannot publish even if their source ignores cancellation; retry reuses verified files")
  func downloadCancellation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = fixture()
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let store = ModelStore(root: root, source: .init { _, destination, _ in
      entered.continuation.yield()
      for await _ in release.stream { break }
      try Data([1, 2, 3]).write(to: destination)
    })
    let install = Task { try? await store.install(manifest) }
    for await _ in entered.stream { break }
    store.cancel(manifest)
    release.continuation.finish()
    await install.value
    #expect(store.state(of: manifest) == .missing)
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: manifest.directoryName).path))
    try await store.install(manifest)
    guard case .installed = store.state(of: manifest) else { Issue.record("Retry did not install"); return }
  }

  @Test("Complete retained files are not reported as an installed feature")
  func retainedRequirements() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = fixture()
    let incomplete = root.appending(path: "Incomplete/" + manifest.directoryName)
    try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: incomplete.appending(path: "file"))
    let store = ModelStore(root: root)
    let voice = LocalModel<KokoroModel.Speak>(manifests: [manifest], loadingMessage: "Loading", store: store) { _ in { _ in NeverSpeech() } }
    let lifecycle = LocalLifecycle(store: store, transcription: nil, cleanup: nil, voice: voice)
    let requirements = lifecycle.controls.requirements([.readAloud])
    #expect(requirements.count == 1)
    #expect(requirements[0].missingBytes == 0)
    #expect(requirements[0].installed == false)
    #expect(voice.check().status == .unavailable)
  }

  @Test("Explicit setup cancellation rejects late completion without cancelling its caller")
  func setupCancellation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ModelStore(root: root, source: .init { _, destination, _ in try Data([1, 2, 3]).write(to: destination) })
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let voice = LocalModel<KokoroModel.Speak>(manifests: [fixture()], loadingMessage: "Loading", store: store) { _ in
      entered.continuation.yield()
      for await _ in release.stream { break }
      return { _ in NeverSpeech() }
    }
    let lifecycle = LocalLifecycle(store: store, transcription: nil, cleanup: nil, voice: voice)
    let attempt = Task { () -> Bool in
      do { try await lifecycle.controls.install([.readAloud]); return true } catch { return false }
    }
    for await _ in entered.stream { break }
    lifecycle.controls.cancel([.readAloud])
    release.continuation.finish()
    #expect(await attempt.value == false)
    #expect(voice.loaded == nil)
    #expect(voice.check().status != .ready)
    guard case .installed = store.state(of: fixture()) else { Issue.record("Verified files were not retained"); return }
  }

  @Test("Feature lease protects its own files while another feature can be removed")
  func removal() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dictation = fixture("dictation"), speech = fixture("speech")
    let store = ModelStore(root: root, source: .init { _, destination, _ in try Data([1, 2, 3]).write(to: destination) })
    try await store.install(dictation); try await store.install(speech)
    let transcriber = LocalModel<ParakeetModel.Start>(manifests: [dictation], loadingMessage: "Loading", store: store) { _ in
      { _ in throw ProviderError.unavailable }
    }
    let voice = LocalModel<KokoroModel.Speak>(manifests: [speech], loadingMessage: "Loading", store: store) { _ in { _ in NeverSpeech() } }
    let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: nil, voice: voice)
    lifecycle.controls.select([.dictation])
    var lease: RuntimeLease? = try await lifecycle.prepare(.dictation)
    let inventory = try lifecycle.controls.inventory()
    let ownFiles = inventory.filter { $0.id.lastPathComponent == dictation.directoryName }
    let speechFiles = inventory.filter { $0.id.lastPathComponent == speech.directoryName }
    #expect(throws: (any Error).self) { try lifecycle.controls.remove(ownFiles) }
    try lifecycle.controls.remove(speechFiles)
    #expect(transcriber.loaded != nil)
    #expect(lease != nil)
    lease = nil
    try lifecycle.controls.remove(ownFiles)
    #expect(transcriber.loaded == nil)
    #expect(store.state(of: dictation) == .missing)
  }

  @Test("Switching away during setup releases the runtime after setup and operation leases settle")
  func selectionDuringSetup() async throws {
    for withOperation in [false, true] {
      let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: root) }
      let manifest = fixture("speech")
      let store = ModelStore(root: root, source: .init { _, destination, _ in try Data([1, 2, 3]).write(to: destination) })
      let entered = AsyncStream.makeStream(of: Void.self)
      let release = AsyncStream.makeStream(of: Void.self)
      let voice = LocalModel<KokoroModel.Speak>(manifests: [manifest], loadingMessage: "Loading", store: store) { _ in
        entered.continuation.yield()
        for await _ in release.stream { break }
        return { _ in NeverSpeech() }
      }
      let lifecycle = LocalLifecycle(store: store, transcription: nil, cleanup: nil, voice: voice)
      lifecycle.controls.select([.readAloud])
      if withOperation { try await store.install(manifest) }
      var operation = withOperation ? Task { try await lifecycle.prepare(.readAloud) } : nil
      if withOperation { for await _ in entered.stream { break } }
      let setup = Task { try await lifecycle.controls.install([.readAloud]) }
      if withOperation {
        let files = try lifecycle.controls.inventory()
        while lifecycle.controls.removalBlock(files)?.hasPrefix("Cancel setup") != true { await Task.yield() }
      } else { for await _ in entered.stream { break } }
      lifecycle.controls.select([])
      release.continuation.finish()
      var lease = try await operation?.value
      operation = nil
      try await setup.value
      if withOperation { #expect(voice.loaded != nil); #expect(lease != nil) }
      lease = nil
      #expect(voice.loaded == nil)
      #expect(voice.check().status == .waiting)
      guard case .installed = store.state(of: manifest) else { Issue.record("Switching providers removed installed files"); continue }
    }
  }

  @Test("Explicit setup prepares only its requested feature and installed reload never fetches")
  func featureIsolation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let fetches = Mutex(0), dictationLoads = Mutex(0), speechLoads = Mutex(0)
    let store = ModelStore(root: root, source: .init { _, destination, _ in
      fetches.withLock { $0 += 1 }; try Data([1, 2, 3]).write(to: destination)
    })
    let transcriber = LocalModel<ParakeetModel.Start>(manifests: [fixture("dictation")], loadingMessage: "Loading", store: store) { _ in
      dictationLoads.withLock { $0 += 1 }; return { _ in throw ProviderError.unavailable }
    }
    let voice = LocalModel<KokoroModel.Speak>(manifests: [fixture("speech")], loadingMessage: "Loading", store: store) { _ in
      speechLoads.withLock { $0 += 1 }; return { _ in NeverSpeech() }
    }
    let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: nil, voice: voice)
    try await lifecycle.controls.install([.readAloud])
    #expect(speechLoads.withLock { $0 } == 1)
    #expect(dictationLoads.withLock { $0 } == 0)
    #expect(fetches.withLock { $0 } == 1)
    #expect(voice.check().status == .ready)
    lifecycle.controls.select([.readAloud])
    var lease: RuntimeLease? = try await lifecycle.prepare(.readAloud)
    lifecycle.controls.select([])
    #expect(voice.loaded != nil)
    #expect(lease != nil)
    lease = nil
    #expect(voice.loaded == nil)
    lease = try await lifecycle.prepare(.readAloud)
    #expect(speechLoads.withLock { $0 } == 2)
    #expect(fetches.withLock { $0 } == 1)
    lease = nil
  }

  @Test("Inventory counts only supported models' bytes without following links")
  func inventory() throws {
    let parent = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: parent) }
    let root = parent.appending(path: "Models")
    let unrelated = parent.appending(path: "OtherCache")
    try FileManager.default.createDirectory(at: root.appending(path: "Incomplete/" + fixture().directoryName), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 17).write(to: unrelated.appending(path: "keep"))
    try Data(repeating: 2, count: 9).write(to: root.appending(path: "Incomplete/" + fixture().directoryName + "/partial"))
    try FileManager.default.createSymbolicLink(at: root.appending(path: fixture().directoryName), withDestinationURL: unrelated)
    try Data([9]).write(to: root.appending(path: "unrelated-notes.txt"))
    let retired = root.appending(path: "tiny-" + String(repeating: "a", count: 40))
    try FileManager.default.createDirectory(at: retired, withIntermediateDirectories: true)
    let store = ModelStore(root: root)
    let inventory = try store.inventory(manifests: [fixture()])
    #expect(inventory.reduce(0) { $0 + $1.bytes } == 9)
    #expect(!inventory.contains { $0.id == retired })
    try store.remove(inventory, manifests: [fixture()])
    #expect(try Data(contentsOf: unrelated.appending(path: "keep")).count == 17)
    #expect(try Data(contentsOf: root.appending(path: "unrelated-notes.txt")) == Data([9]))
  }
  @Test("Overlapping feature downloads join one asset and cancelling Dictation retains Read Aloud")
  func overlappingSetupCancellation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = fixture("shared"), speech = fixture("speech")
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let fetches = Mutex(0), dictationLoads = Mutex(0)
    let store = ModelStore(root: root, source: .init { _, destination, _ in
      fetches.withLock { $0 += 1 }
      if destination.path.contains(shared.directoryName) {
        entered.continuation.yield()
        for await _ in release.stream { break }
      }
      try Data([1, 2, 3]).write(to: destination)
    })
    let transcriber = LocalModel<ParakeetModel.Start>(manifests: [shared], loadingMessage: "Loading", store: store) { _ in
      dictationLoads.withLock { $0 += 1 }
      return { _ in throw ProviderError.unavailable }
    }
    let voice = LocalModel<KokoroModel.Speak>(manifests: [shared, speech], loadingMessage: "Loading", store: store) { _ in { _ in NeverSpeech() } }
    let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: nil, voice: voice)
    let dictation = Task { () -> Bool in
      do { try await lifecycle.controls.install([.dictation]); return true } catch { return false }
    }
    for await _ in entered.stream { break }
    let reading = Task { try await lifecycle.controls.install([.readAloud]) }
    let speechFile = LocalFile(id: root.appending(path: speech.directoryName), name: "speech", category: "Installed", bytes: 3)
    while lifecycle.controls.removalBlock([speechFile])?.hasPrefix("Cancel setup") != true { await Task.yield() }
    lifecycle.controls.cancel([.dictation])
    release.continuation.finish()
    #expect(await dictation.value == false)
    try await reading.value
    #expect(fetches.withLock { $0 } == 2)
    #expect(dictationLoads.withLock { $0 } == 0)
    #expect(transcriber.check().status != .ready)
    #expect(voice.check().status == .ready)
    try store.verifyInstalled(shared)
    try store.verifyInstalled(speech)
  }

  @Test("Read Aloud admitted after Dictation cancellation drains the shared writer before retrying")
  func cancelledSharedWriterAdmission() async throws {
    for cancelReading in [false, true] {
      let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: root) }
      let shared = fixture("shared"), speech = fixture("speech")
      let entered = AsyncStream.makeStream(of: Void.self)
      let readingEntered = AsyncStream.makeStream(of: Void.self)
      let held = Mutex<CheckedContinuation<Void, Never>?>(nil)
      let writers = Mutex((fetches: 0, active: 0, maximum: 0))
      let dictationLoads = Mutex(0), speechLoads = Mutex(0)
      let store = ModelStore(root: root, source: .init { _, destination, _ in
        if destination.path.contains(shared.directoryName) {
          let attempt = writers.withLock {
            $0.fetches += 1
            $0.active += 1
            $0.maximum = max($0.maximum, $0.active)
            return $0.fetches
          }
          defer { writers.withLock { $0.active -= 1 } }
          if attempt == 1 {
            // Checked continuation deliberately ignores task cancellation until the test drains it.
            await withCheckedContinuation { continuation in
              held.withLock { $0 = continuation }
              entered.continuation.yield()
            }
          }
          try Data([1, 2, 3]).write(to: destination)
        } else {
          try Data([1, 2, 3]).write(to: destination)
          readingEntered.continuation.yield()
        }
      })
      let transcriber = LocalModel<ParakeetModel.Start>(manifests: [shared], loadingMessage: "Loading", store: store) { _ in
        dictationLoads.withLock { $0 += 1 }
        return { _ in throw ProviderError.unavailable }
      }
      let voice = LocalModel<KokoroModel.Speak>(manifests: [shared, speech], loadingMessage: "Loading", store: store) { _ in
        speechLoads.withLock { $0 += 1 }
        return { _ in NeverSpeech() }
      }
      let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: nil, voice: voice)
      let dictation = Task { () -> Bool in
        do { try await lifecycle.controls.install([.dictation]); return true } catch { return false }
      }
      for await _ in entered.stream { break }
      lifecycle.controls.cancel([.dictation])
      let reading = Task { () -> Bool in
        do { try await lifecycle.controls.install([.readAloud]); return true } catch { return false }
      }
      // This independent speech fetch proves Read Aloud admission while the shared writer is held.
      for await _ in readingEntered.stream { break }
      #expect(writers.withLock { $0.fetches } == 1)
      #expect(writers.withLock { $0.active } == 1)
      let retained = [LocalFile(
        id: root.appending(path: "Incomplete/" + shared.directoryName),
        name: "shared", category: "Retained download", bytes: 0)]
      #expect(throws: (any Error).self) { try store.remove(retained, manifests: [shared, speech]) }
      if cancelReading { lifecycle.controls.cancel([.readAloud]) }
      held.withLock { $0?.resume(); $0 = nil }
      #expect(await dictation.value == false)
      #expect(await reading.value == !cancelReading)
      #expect(writers.withLock { $0.maximum } == 1)
      #expect(writers.withLock { $0.fetches } == (cancelReading ? 1 : 2))
      #expect(dictationLoads.withLock { $0 } == 0)
      #expect(speechLoads.withLock { $0 } == (cancelReading ? 0 : 1))
      #expect(transcriber.check().status != .ready)
      if cancelReading {
        #expect(store.state(of: shared) == .missing)
        #expect(voice.check().status != .ready)
      } else {
        try store.verifyInstalled(shared)
        try store.verifyInstalled(speech)
        #expect(voice.check().status == .ready)
      }
    }
  }

  @Test("A suspended Dictation download does not prevent Read Aloud finishing")
  func concurrentIndependentSetup() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dictationManifest = fixture("dictation"), speech = fixture("speech")
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let store = ModelStore(root: root, source: .init { _, destination, _ in
      if destination.path.contains(dictationManifest.directoryName) {
        entered.continuation.yield()
        for await _ in release.stream { break }
      }
      try Data([1, 2, 3]).write(to: destination)
    })
    let transcriber = LocalModel<ParakeetModel.Start>(manifests: [dictationManifest], loadingMessage: "Loading", store: store) { _ in { _ in throw ProviderError.unavailable } }
    let voice = LocalModel<KokoroModel.Speak>(manifests: [speech], loadingMessage: "Loading", store: store) { _ in { _ in NeverSpeech() } }
    let lifecycle = LocalLifecycle(store: store, transcription: transcriber, cleanup: nil, voice: voice)
    let dictation = Task { try? await lifecycle.controls.install([.dictation]) }
    for await _ in entered.stream { break }
    try await lifecycle.controls.install([.readAloud])
    #expect(voice.check().status == .ready)
    #expect(transcriber.check().status != .ready)
    lifecycle.controls.cancel([.dictation])
    release.continuation.finish()
    await dictation.value
    #expect(voice.check().status == .ready)
  }

}
