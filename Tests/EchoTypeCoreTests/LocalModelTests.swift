import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

@Suite struct LocalModelTests {
  @Test("Every pinned manifest names a full commit, a licence and a checksum per file")
  func manifestsArePinned() {
    let manifests =
      LocalCandidates.cleanup.map(\.manifest) + LocalCandidates.transcription.flatMap(\.manifests)
      + LocalCandidates.voice.flatMap(\.manifests)
    for manifest in manifests {
      #expect(manifest.revision.count == 40 && manifest.revision.allSatisfy(\.isHexDigit), "\(manifest.name)")
      #expect(!manifest.license.isEmpty)
      for file in manifest.files {
        #expect(file.size > 0 && file.sha256.count == 64 && file.sha256.allSatisfy(\.isHexDigit), "\(file.path)")
      }
    }
  }

  @Test("An unknown candidate fails with the names that exist")
  func unknownCandidate() {
    let cleanup = #expect(throws: (any Error).self) {
      try Provider.local(LocalSelection(cleanup: "nope"))
    }
    #expect(cleanup?.localizedDescription.contains("qwen3-4b-2507, smollm3-3b") == true)
    let transcription = #expect(throws: (any Error).self) {
      try Provider.local(LocalSelection(transcription: "nope"))
    }
    #expect(transcription?.localizedDescription.contains("parakeet-unified, parakeet-unified-keyterms") == true)
  }

  @Test("A service with no candidate is not offered")
  func unselectedServiceIsNotOffered() async throws {
    #expect(try Provider.local(LocalSelection(transcription: "parakeet-unified")).cleanup == nil)
    #expect(try Provider.local(LocalSelection(cleanup: "qwen3-4b-2507")).cleanup != nil)
    let readiness = try await Provider.local(LocalSelection()).readiness.check(
      ReadinessRequest(language: "en", voice: "bf_emma"))
    #expect(readiness.voice.status == .unavailable)
  }

  @Test("Readiness reports the download, then a failed one stays failed without starting again")
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
      manifests: [LocalCandidates.qwen3.manifest], loadingMessage: "Loading", store: store
    ) { _ in 0 }
    var changes = model.changes().makeAsyncIterator()

    #expect(model.check() == .waiting("Downloading models, 0.0 of 2.3 GB"))
    release.continuation.finish()
    var state = model.check()
    while state.status == .waiting, await changes.next() != nil { state = model.check() }

    #expect(state.status == .unavailable)
    #expect(state.message?.isEmpty == false)
    #expect(model.check() == state)
    #expect(fetches.withLock { $0 } == 1)
  }
}
