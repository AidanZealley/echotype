@testable import EchoTypeBench
import Foundation
import Testing

@Test("The committed corpus manifest decodes and validates")
func committedManifestIsValid() throws {
  let manifest = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "Corpus/manifest.json")

  let loaded = try Manifest.load(from: manifest)

  #expect(!loaded.samples.isEmpty)
}

@Test("An expected cleanup may only delete words from its segments")
func expectedCleanupMustBeSubsequence() {
  func cleanup(expected: String) -> Cleanup {
    Cleanup(
      id: "c", segments: [.init(at: 0, text: "Let's meet on Tuesday."),
                          .init(at: 2, text: "No, sorry, Wednesday at ten.")],
      expected: expected, tags: [], ambiguous: false)
  }

  #expect(cleanup(expected: "Let's meet on Wednesday at ten.").expectedOnlyDeletesWords)
  #expect(!cleanup(expected: "Let's meet on Wednesday at ten sharp.").expectedOnlyDeletesWords)
  #expect(!cleanup(expected: "Wednesday let's meet at ten.").expectedOnlyDeletesWords)
}

@Test("Duplicate ids are reported with the id")
func duplicateIDsAreReported() throws {
  let json = """
    {"version": 1, "keyterms": [], "samples": [
      {"id": "a", "kind": "reading", "text": "x", "checks": [], "tags": []},
      {"id": "a", "kind": "reading", "text": "y", "checks": [], "tags": []}
    ]}
    """
  let manifest = try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))

  #expect(manifest.problems == ["a: duplicate id"])
}
