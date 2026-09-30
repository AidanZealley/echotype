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
    finalText: "I'm never sure why it fails",
    outcome: .completed
  )
  #expect(trace.marks.map(\.word) == ["I", "I'm", "never", "sure.", "Why", "it", "fails"])
  #expect(trace.marks.map(\.kind) == [
    .deleted, .kept, .kept, .changed(revised: "sure"), .changed(revised: "why"), .kept, .kept,
  ])
  #expect(trace.marks.map(\.commit) == [nil, nil, nil, nil, 1, nil, nil])
  let skipped = ["Hello", "…", "world"].map { DictationTrace.Commit(at: start, text: $0) }
  #expect(DictationTrace(startedAt: start, cleanUp: false, commits: skipped, streamed: "Hello … world").marks.map(\.commit) == [nil, 2])
  #expect(try JSONDecoder().decode(DictationTrace.self, from: JSONEncoder().encode(trace)) == trace)
}

@Test("Recovery marks compare final text even when paste was skipped")
func dictationTraceMarksRecovery() throws {
  let trace = DictationTrace(startedAt: .now, cleanUp: true, streamed: "Hello world.",
    finalText: "Hello world", insertion: .skipped(.changed), sending: .notRequested,
    outcome: .completed)
  #expect(trace.marks.map(\.kind) == [.kept, .changed(revised: "world")])
  #expect(try JSONDecoder().decode(DictationTrace.self, from: JSONEncoder().encode(trace)) == trace)
}
