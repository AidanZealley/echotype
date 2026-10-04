import Foundation
import Testing

@testable import EchoTypeCore

@Suite struct WhisperLocalTokenizerTests {
  @Test("An unreadable local tokenizer fails preparation before loading models")
  func invalidTokenizerFailsPreparation() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("invalid JSON".utf8).write(to: folder.appending(path: "tokenizer_config.json"))
    try Data("invalid JSON".utf8).write(to: folder.appending(path: "tokenizer.json"))
    await #expect(throws: (any Error).self) {
      try await WhisperModel.load(models: folder, tokenizer: folder, voiceActivity: folder)
    }
  }
}
