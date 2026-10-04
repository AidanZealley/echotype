import CryptoKit
import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

/// Serves file contents by path and counts fetches. Can fail one path, as an interrupted
/// download would, and can hold a path half-written until released.
private final class FakeSource: Sendable {
  let contents: [String: Data]
  private let failing: Mutex<String?>
  private let fetches = Mutex(0)
  let release = AsyncStream.makeStream(of: Void.self)
  private let holding: String?

  init(_ contents: [String: Data], failing: String? = nil, holding: String? = nil) {
    self.contents = contents
    self.failing = Mutex(failing)
    self.holding = holding
  }

  var fetchCount: Int { fetches.withLock { $0 } }
  func repair() { failing.withLock { $0 = nil } }

  var source: ModelDownloadSource {
    ModelDownloadSource { [self] url, destination, progress in
      fetches.withLock { $0 += 1 }
      let path = url.lastPathComponent
      if failing.withLock({ $0 }) == path { throw CocoaError(.fileReadUnknown) }
      let data = contents[path]!
      if holding == path {
        try data.prefix(data.count / 2).write(to: destination)
        progress(Int64(data.count / 2))
        for await _ in release.stream { break }
      }
      try data.write(to: destination)
    }
  }
}

private func manifest(_ contents: [String: Data]) -> ModelManifest {
  let files = contents.sorted { $0.key < $1.key }.map { path, data in
    ModelManifest.File(
      path: path, size: Int64(data.count),
      sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
  }
  return ModelManifest(name: "test", repository: "owner/test", revision: "abc123", license: "MIT", files: files)
}

/// Follows changes until the state satisfies `done`, so tests never poll or sleep.
private func settle(
  _ store: ModelStore, _ manifest: ModelManifest, until done: (ModelState) -> Bool
) async -> ModelState {
  let changes = store.changes()
  var iterator = changes.makeAsyncIterator()
  var state = store.state(of: manifest)
  while !done(state), await iterator.next() != nil { state = store.state(of: manifest) }
  return state
}

private func isSettled(_ state: ModelState) -> Bool {
  if case .downloading = state { return false }
  return true
}

@Suite struct ModelStoreTests {
  let root = FileManager.default.temporaryDirectory.appending(path: "ModelStoreTests-\(UUID().uuidString)")
  let contents = ["a.bin": Data(repeating: 1, count: 100), "b.json": Data(repeating: 2, count: 50)]

  private func cleanUp() { try? FileManager.default.removeItem(at: root) }

  @Test("Concurrent starts run one download, report progress and install every file")
  func install() async throws {
    defer { cleanUp() }
    let fake = FakeSource(contents, holding: "a.bin")
    let store = ModelStore(root: root, source: fake.source)
    let model = manifest(contents)

    #expect(store.state(of: model) == .missing)
    for _ in 0..<3 { store.start(model) }

    let halfway = await settle(store, model) { $0 == .downloading(done: 50, total: 150) }
    #expect(halfway == .downloading(done: 50, total: 150))
    fake.release.continuation.yield()

    let state = await settle(store, model, until: isSettled)
    let directory = try #require(state.installedDirectory)
    #expect(try Data(contentsOf: directory.appending(path: "a.bin")) == contents["a.bin"])
    #expect(try Data(contentsOf: directory.appending(path: "b.json")) == contents["b.json"])
    #expect(fake.fetchCount == 2)
  }

  @Test("A checksum mismatch fails the model and installs nothing")
  func mismatch() async {
    defer { cleanUp() }
    var corrupted = contents
    corrupted["b.json"] = Data(repeating: 9, count: 50)
    let store = ModelStore(root: root, source: FakeSource(corrupted).source)
    let model = manifest(contents)

    store.start(model)
    let state = await settle(store, model, until: isSettled)

    #expect(state == .failed("b.json does not match its checksum"))
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: model.directoryName).path))
  }

  @Test("An interrupted download is never installed, even after a relaunch, and a retry succeeds")
  func interruption() async {
    defer { cleanUp() }
    let fake = FakeSource(contents, failing: "b.json")
    let model = manifest(contents)
    let first = ModelStore(root: root, source: fake.source)

    first.start(model)
    guard case .failed = await settle(first, model, until: isSettled) else {
      Issue.record("The interrupted download should fail")
      return
    }

    // A relaunch only has the disk to go on.
    let relaunched = ModelStore(root: root, source: fake.source)
    #expect(relaunched.state(of: model) == .missing)

    fake.repair()
    relaunched.start(model)
    let state = await settle(relaunched, model, until: isSettled)
    #expect(state.installedDirectory != nil)
  }
}

extension ModelState {
  fileprivate var installedDirectory: URL? {
    if case .installed(let directory) = self { directory } else { nil }
  }
}
