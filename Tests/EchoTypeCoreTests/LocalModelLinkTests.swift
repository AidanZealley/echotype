import Foundation
import Testing

@testable import EchoTypeCore

@Suite struct LocalModelLinkTests {
  @Test("A foreign CTC cache is preserved and loading fails")
  func foreignCache() throws {
    let files = FileManager.default
    let fixture = files.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? files.removeItem(at: fixture) }
    let store = fixture.appending(path: "Models")
    let destination = store.appending(path: "parakeet-ctc-110m-" + String(repeating: "a", count: 40))
    let cache = fixture.appending(path: "cache/parakeet-ctc-110m-coreml")
    try files.createDirectory(at: destination, withIntermediateDirectories: true)
    try files.createDirectory(at: cache, withIntermediateDirectories: true)
    try Data("preserve".utf8).write(to: cache.appending(path: "sentinel"))
    #expect(throws: ProviderError.self) { try link(cache, to: destination, store: store) }
    #expect(try Data(contentsOf: cache.appending(path: "sentinel")) == Data("preserve".utf8))
  }
}
