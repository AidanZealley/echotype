import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

@Suite struct LocalModelTests {
  @Test("Every pinned manifest names a full commit, a licence and a checksum per file")
  func manifestsArePinned() {
    let manifests = LocalModels.transcription + [LocalModels.cleanup] + LocalModels.speech
    for manifest in manifests {
      #expect(manifest.revision.count == 40 && manifest.revision.allSatisfy(\.isHexDigit), "\(manifest.name)")
      #expect(!manifest.license.isEmpty)
      for file in manifest.files {
        #expect(file.size > 0 && file.sha256.count == 64 && file.sha256.allSatisfy(\.isHexDigit), "\(file.path)")
      }
    }
  }

  @Test("Readiness has no setup side effects; explicit failed downloads stay failed")
  func downloadProgressAndFailure() async {
    let root = FileManager.default.temporaryDirectory.appending(path: "LocalModelTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let fetches = Mutex(0)
    let release = AsyncStream.makeStream(of: Void.self)
    let store = ModelStore(
      root: root,
      source: ModelDownloadSource { _, _, _ in
        fetches.withLock { $0 += 1 }
        for await _ in release.stream { break }
        throw CocoaError(.fileReadUnknown)
      })
    let model = LocalModel(
      manifests: [LocalModels.cleanup], loadingMessage: "Loading", store: store
    ) { _ in 0 }
    var changes = model.changes().makeAsyncIterator()

    #expect(model.check().status == .unavailable)
    #expect(fetches.withLock { $0 } == 0)
    store.start(LocalModels.cleanup)
    #expect(model.check() == .waiting("Downloading models, 0.0 of 2.3 GB"))
    #expect(model.downloading(done: 12_400_000, total: 97_489_362) == .waiting("Downloading models, 12 of 97 MB"))
    release.continuation.finish()
    var state = model.check()
    while state.status == .waiting, await changes.next() != nil { state = model.check() }

    #expect(state.status == .unavailable)
    #expect(state.message?.isEmpty == false)
    #expect(model.check() == state)
    #expect(fetches.withLock { $0 } == 1)
  }
}
