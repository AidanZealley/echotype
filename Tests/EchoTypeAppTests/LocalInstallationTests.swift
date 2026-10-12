import Foundation
import Synchronization
import Testing

@testable import EchoTypeApp
@testable import EchoTypeCore

@Suite @MainActor struct LocalInstallationTests {
  private func installation(
    install: @escaping @Sendable (ProviderFeature) async throws -> Void,
    files initial: [LocalFile] = []
  ) -> LocalInstallation {
    let files = Mutex(initial)
    return LocalInstallation(controls: LocalSetup(
      requirements: { _ in [] }, install: install, inventory: { files.withLock { $0 } },
      remove: { removed in files.withLock { $0.removeAll { removed.contains($0) } } },
      removalBlock: { _ in nil }, select: { _ in }, availableBytes: { nil }))
  }

  @Test("Features install one at a time in order, and cancel removes a waiting one or stops the running one")
  func queue() async {
    let entered = AsyncStream.makeStream(of: ProviderFeature.self)
    let dictation = AsyncStream.makeStream(of: Void.self)
    let reading = AsyncStream.makeStream(of: Void.self)
    let installation = installation { feature in
      entered.continuation.yield(feature)
      for await _ in feature == .dictation ? dictation.stream : reading.stream { break }
      try Task.checkCancellation()
    }
    var entries = entered.stream.makeAsyncIterator()
    installation.start(.dictation)
    #expect(await entries.next() == .dictation)
    installation.start(.readAloud)
    installation.start(.readAloud)
    #expect(installation.queue == [.dictation, .readAloud])
    installation.cancel(.readAloud)
    #expect(installation.queue == [.dictation])
    installation.start(.readAloud)
    installation.cancel(.dictation)
    #expect(await entries.next() == .readAloud)
    #expect(installation.queue == [.readAloud])
    let worker = installation.worker
    reading.continuation.finish()
    await worker?.value
    #expect(installation.queue.isEmpty)
    #expect(installation.messages[.dictation] == "Cancelled.")
    #expect(installation.messages[.readAloud] == nil)
  }

  @Test("A failed setup keeps its message while another feature installs and files are removed")
  func failure() async {
    let file = LocalFile(
      id: URL(fileURLWithPath: "/test/dictation"), name: "Dictation models",
      category: "Installed", bytes: 1, features: [.dictation])
    let error = ProviderError.failed("Speech preparation failed.")
    let installation = installation(install: { if $0 == .readAloud { throw error } }, files: [file])
    installation.start(.readAloud)
    installation.start(.dictation)
    await installation.worker?.value
    #expect(installation.messages[.readAloud] == error.localizedDescription)
    #expect(installation.messages[.dictation] == nil)
    #expect(installation.files == [file])
    await installation.remove([file])
    #expect(installation.files.isEmpty)
    #expect(installation.messages[.readAloud] == error.localizedDescription)
  }
}
