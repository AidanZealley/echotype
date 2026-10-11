import Foundation
import Synchronization
import Testing

@testable import EchoTypeApp
@testable import EchoTypeCore

@Suite @MainActor struct LocalInstallationTests {
  @Test("Page setup tracks both features independently and cancellation preserves the other task")
  func independentTasks() async {
    let entered = AsyncStream.makeStream(of: ProviderFeature.self)
    let dictation = AsyncStream.makeStream(of: Void.self)
    let reading = AsyncStream.makeStream(of: Void.self)
    let cancellations = Mutex<Set<ProviderFeature>>([])
    let controls = LocalSetup(
      requirements: { _ in [] },
      install: { features in
        let feature = features.first!
        entered.continuation.yield(feature)
        let stream = feature == .dictation ? dictation.stream : reading.stream
        for await _ in stream { break }
      }, cancel: { features in cancellations.withLock { $0.formUnion(features) } },
      inventory: { [] },
      remove: { _ in }, removalBlock: { _ in nil }, select: { _ in }, availableBytes: { nil })
    let installation = LocalInstallation(controls: controls)
    var entries = entered.stream.makeAsyncIterator()
    installation.start([.dictation])
    #expect(await entries.next() == .dictation)
    installation.start([.readAloud])
    #expect(await entries.next() == .readAloud)
    #expect(installation.requested == [.dictation, .readAloud])
    installation.cancel(.dictation)
    dictation.continuation.finish()
    while installation.requested.contains(.dictation) { await Task.yield() }
    #expect(installation.requested == [.readAloud])
    #expect(cancellations.withLock { $0 } == [.dictation])
    reading.continuation.finish()
    while installation.running { await Task.yield() }
    #expect(installation.messages[.dictation]?.hasPrefix("Cancelled") == true)
    #expect(installation.messages[.readAloud] == nil)
  }

  @Test("Successful setup leaves readiness to report status and preserves another feature's failure")
  func successUsesReadiness() async {
    let file = LocalFile(
      id: URL(fileURLWithPath: "/test/dictation"), name: "Dictation models",
      category: "Installed", bytes: 1, features: [.dictation])
    let files = Mutex([file])
    let error = ProviderError.failed("Speech preparation failed.")
    let controls = LocalSetup(
      requirements: { _ in [] },
      install: { features in
        if features.contains(.readAloud) { throw error }
      }, cancel: { _ in }, inventory: { files.withLock { $0 } },
      remove: { removed in files.withLock { $0.removeAll { removed.contains($0) } } },
      removalBlock: { _ in nil }, select: { _ in }, availableBytes: { nil })
    let installation = LocalInstallation(controls: controls)
    await installation.refreshFiles()
    installation.start([.readAloud])
    while installation.running { await Task.yield() }
    let failure = installation.messages[.readAloud]
    #expect(failure == error.localizedDescription)

    installation.start([.dictation])
    while installation.running { await Task.yield() }
    #expect(installation.messages[.dictation] == nil)
    #expect(installation.messages[.readAloud] == failure)
    #expect(installation.files == [file])

    await installation.remove([file])
    #expect(installation.files.isEmpty)
    #expect(installation.messages[.dictation] == nil)
    #expect(installation.messages[.readAloud] == failure)
  }
}
