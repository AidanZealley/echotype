import EchoTypeCore
import Foundation
import Testing

@Test("Marks show deletions, changed words and commit boundaries")
func dictationTraceMarks() throws {
  let start = Date(timeIntervalSince1970: 0)
  let trace = DictationTrace(
    startedAt: start,
    cleanUp: true,
    commits: [
      .init(at: start, text: "I-I'm never sure."),
      .init(at: start.addingTimeInterval(2), text: "Why it fails"),
    ],
    streamed: "I-I'm never sure. Why it fails",
    inserted: "I'm never sure why it fails",
    outcome: .inserted
  )
  #expect(trace.marks.map(\.word) == ["I", "I'm", "never", "sure.", "Why", "it", "fails"])
  #expect(trace.marks.map(\.kind) == [
    .deleted, .kept, .kept, .changed(inserted: "sure"), .changed(inserted: "why"), .kept, .kept,
  ])
  #expect(trace.marks.map(\.commit) == [nil, nil, nil, nil, 1, nil, nil])
  let skipped = ["Hello", "…", "world"].map { DictationTrace.Commit(at: start, text: $0) }
  #expect(DictationTrace(startedAt: start, cleanUp: false, commits: skipped, streamed: "Hello … world").marks.map(\.commit) == [nil, 2])
  #expect(try JSONDecoder().decode(DictationTrace.self, from: JSONEncoder().encode(trace)) == trace)
}
