import CryptoKit
import Foundation
import Synchronization
import Testing
@testable import EchoTypeCore

private struct NeverSpeech: SpeechStream {
  func next() async throws -> SpeechAudio? { nil }
  func cancel() {}
}

private actor LocalLoadGate {
  private var opened = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    if !opened { await withCheckedContinuation { waiters.append($0) } }
  }

  func open() {
    opened = true
    for waiter in waiters { waiter.resume() }
    waiters.removeAll()
  }
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

  @Test("A cancelled wait returns at once while the load continues for the next caller")
  func cancelledWait() async throws {
    let release = AsyncStream.makeStream(of: Void.self)
    let model = LocalModel<Int>(manifests: [], loadingMessage: "Loading", store: ModelStore(root: URL(filePath: "/nonexistent"))) { _ in
      for await _ in release.stream { break }
      return 1
    }
    try model.beginPreparation()
    let waiter = Task { try await model.waitForPreparation() }
    waiter.cancel()
    await #expect(throws: CancellationError.self) { try await waiter.value }
    #expect(model.preparing)
    release.continuation.finish()
    try await model.prepare()
    #expect(model.loaded == 1)
  }

  @Test("Cancelling a load makes the next preparation load again")
  func cancelledLoad() async throws {
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let loads = Mutex(0)
    let model = LocalModel<Int>(manifests: [], loadingMessage: "Loading", store: ModelStore(root: URL(filePath: "/nonexistent"))) { _ in
      let count = loads.withLock { $0 += 1; return $0 }
      if count == 1 {
        entered.continuation.yield()
        for await _ in release.stream { break }
      }
      return count
    }
    try model.beginPreparation()
    // The first load is running before it is cancelled, so the next one cannot take its place.
    for await _ in entered.stream { break }
    model.cancel()
    release.continuation.finish()
    try await model.prepare()
    #expect(model.loaded == 2)
  }

  @Test("Cancelled loaders block removal and replacement loading until they exit")
  func cancelledLoadRemoval() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let manifest = fixture("speech")
    let store = ModelStore(root: root, source: .init { _, destination, _ in try Data([1, 2, 3]).write(to: destination) })
    try await store.install(manifest)
    let firstEntered = LocalLoadGate(), firstRelease = LocalLoadGate()
    let secondEntered = LocalLoadGate(), secondRelease = LocalLoadGate()
    let loads = Mutex(0), firstExited = Mutex(false)
    let voice = LocalModel<KokoroModel.Speak>(manifests: [manifest], loadingMessage: "Loading", store: store) { _ in
      let count = loads.withLock { $0 += 1; return $0 }
      if count == 1 {
        await firstEntered.open()
        await firstRelease.wait()
        firstExited.withLock { $0 = true }
      } else {
        #expect(firstExited.withLock { $0 })
        await secondEntered.open()
        await secondRelease.wait()
      }
      return { _ in NeverSpeech() }
    }
    let lifecycle = LocalLifecycle(store: store, transcription: nil, cleanup: nil, voice: voice)
    let files = try lifecycle.controls.inventory().filter { $0.id.lastPathComponent == manifest.directoryName }
    #expect(!files.isEmpty)
    lifecycle.controls.select([.readAloud])
    await firstEntered.wait()
    lifecycle.controls.select([])
    #expect(voice.preparing)
    #expect(voice.loaded == nil)
    #expect(voice.check().status == .waiting)
    #expect(lifecycle.controls.removalBlock(files) == "Wait for Read Aloud preparation to finish.")
    #expect(throws: (any Error).self) { try lifecycle.controls.remove(files) }
    lifecycle.controls.select([.readAloud])
    #expect(loads.withLock { $0 } == 1)
    #expect(voice.preparing)
    await firstRelease.open()
    await secondEntered.wait()
    #expect(loads.withLock { $0 } == 2)
    #expect(voice.loaded == nil)
    await secondRelease.open()
    try await voice.waitForPreparation()
    #expect(!voice.preparing)
    #expect(lifecycle.controls.removalBlock(files) == nil)
    try lifecycle.controls.remove(files)
    #expect(store.state(of: manifest) == .missing)
  }

  @Test("A failed load is remembered until setup retries it")
  func rememberedFailure() async throws {
    let loads = Mutex(0)
    let model = LocalModel<Int>(manifests: [], loadingMessage: "Loading", store: ModelStore(root: URL(filePath: "/nonexistent"))) { _ in
      let count = loads.withLock { $0 += 1; return $0 }
      if count == 1 { throw ProviderError.failed("Broken") }
      return count
    }
    await #expect(throws: (any Error).self) { try await model.prepare() }
    await #expect(throws: (any Error).self) { try await model.prepare() }
    #expect(loads.withLock { $0 } == 1)
    try model.beginPreparation(retrying: true)
    try await model.waitForPreparation()
    #expect(model.loaded == 2)
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

  @Test("Cancelling setup rejects late completion and keeps verified files")
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
    let attempt = Task { try await lifecycle.controls.install(.readAloud) }
    for await _ in entered.stream { break }
    attempt.cancel()
    release.continuation.finish()
    await #expect(throws: (any Error).self) { try await attempt.value }
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

  @Test("Switching away during setup releases the runtime once setup ends")
  func selectionDuringSetup() async throws {
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
    let setup = Task { try await lifecycle.controls.install(.readAloud) }
    for await _ in entered.stream { break }
    lifecycle.controls.select([])
    release.continuation.finish()
    try await setup.value
    #expect(voice.loaded == nil)
    #expect(voice.check().status == .waiting)
    guard case .installed = store.state(of: manifest) else { Issue.record("Switching providers removed installed files"); return }
  }

  @Test("Setup prepares only its requested feature and installed reloads never fetch")
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
    try await lifecycle.controls.install(.readAloud)
    #expect(speechLoads.withLock { $0 } == 1)
    #expect(dictationLoads.withLock { $0 } == 0)
    #expect(fetches.withLock { $0 } == 1)
    // Read Aloud is not selected, so setup releases what it loaded.
    #expect(voice.loaded == nil)
    lifecycle.controls.select([.readAloud])
    var lease: RuntimeLease? = try await lifecycle.prepare(.readAloud)
    #expect(speechLoads.withLock { $0 } == 2)
    lifecycle.controls.select([])
    #expect(voice.loaded != nil)
    #expect(lease != nil)
    lease = nil
    #expect(voice.loaded == nil)
    lease = try await lifecycle.prepare(.readAloud)
    #expect(speechLoads.withLock { $0 } == 3)
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
}
