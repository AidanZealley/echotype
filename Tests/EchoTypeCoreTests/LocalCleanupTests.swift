import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

@Suite struct LocalCleanupTests {
  @Test("Every pinned manifest names a full commit, a licence and a checksum per file")
  func manifestsArePinned() {
    for candidate in LocalCandidates.cleanup {
      let manifest = candidate.manifest
      #expect(manifest.revision.count == 40 && manifest.revision.allSatisfy(\.isHexDigit), "\(candidate.name)")
      #expect(!manifest.license.isEmpty)
      for file in manifest.files {
        #expect(file.size > 0 && file.sha256.count == 64 && file.sha256.allSatisfy(\.isHexDigit), "\(file.path)")
      }
    }
  }

  @Test("An unknown candidate fails with the names that exist")
  func unknownCandidate() {
    let error = #expect(throws: (any Error).self) {
      try Provider.local(LocalSelection(cleanup: "nope"))
    }
    #expect(error?.localizedDescription.contains("qwen3-4b-2507, smollm3-3b") == true)
  }

  @Test("A reply is allowed to be longer than its window")
  func outputLimit() {
    for tokens in [0, 1, 30, 400] { #expect(CleanupModel.outputLimit(windowTokens: tokens) > tokens) }
  }

  @Test("Readiness reports the download, then a failed one stays failed without starting again")
  func downloadProgressAndFailure() async {
    let root = FileManager.default.temporaryDirectory.appending(path: "LocalCleanupTests-\(UUID().uuidString)")
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
    let cleanup = LocalCleanup(LocalCandidates.qwen3, store: store)
    var changes = cleanup.changes().makeAsyncIterator()

    #expect(cleanup.check() == .waiting("Downloading models, 0.0 of 2.3 GB"))
    release.continuation.finish()
    var state = cleanup.check()
    while state.status == .waiting, await changes.next() != nil { state = cleanup.check() }

    #expect(state.status == .unavailable)
    #expect(state.message?.isEmpty == false)
    #expect(cleanup.check() == state)
    #expect(fetches.withLock { $0 } == 1)
  }
}
