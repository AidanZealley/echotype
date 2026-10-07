import EchoTypeCore
import Foundation
import Testing

@testable import EchoTypeBench

/// Revisions have no public initialiser, so build them the way the bench reads them.
private func revision(final: Bool, result: String, start: Double, duration: Double) throws -> DictationTrace.Revision {
  let json = """
    {"at": \(start), "isFinal": \(final), "window": "w", "reply": null, "duration": \(duration),
     "result": {"\(result)": \(result == "rejected" ? "{\"word\": \"x\"}" : "{}")}}
    """
  return try JSONDecoder().decode(DictationTrace.Revision.self, from: Data(json.utf8))
}

private struct Result: RepeatedResult { let repeatIndex: Int? }

@Test("Only the first result of a run with repeats is cold; older runs have none")
func firstResultIsColdOnlyWhenRepeatsAreRecorded() {
  let recorded = splitCold([Result(repeatIndex: 0), Result(repeatIndex: 0), Result(repeatIndex: 1)])
  #expect(recorded.cold != nil)
  #expect(recorded.warm.count == 2)

  let older = splitCold([Result(repeatIndex: nil), Result(repeatIndex: nil)])
  #expect(older.cold == nil)
  #expect(older.warm.count == 2)
}

@Test("The cold request is the cold sample's first served request, not a live revision finish cancelled")
func coldRequestSkipsCancelledLiveRevisions() throws {
  let coldSample = [
    try revision(final: false, result: "cancelled", start: 0, duration: 0.002),
    try revision(final: true, result: "accepted", start: 0.1, duration: 1.8),
  ]
  let warmSample = [
    try revision(final: false, result: "cancelled", start: 0, duration: 0.003),
    try revision(final: true, result: "accepted", start: 0.1, duration: 0.5),
  ]
  let split = requestDurations(cold: coldSample, warm: [warmSample])
  #expect(split.cold == 1.8)
  #expect(split.warm == [0.5])
}

@Test("Cancellation latency runs from finish to the end of the live revision it cancelled")
func cancellationLatencyIsMeasuredFromFinish() throws {
  let attempts = [
    try revision(final: false, result: "accepted", start: 100, duration: 0.4),
    try revision(final: false, result: "cancelled", start: 101, duration: 0.6),
    try revision(final: true, result: "accepted", start: 101.7, duration: 0.5),
  ]
  // finish was called at 101.2, and the live revision ended at 101.6.
  let latency = try #require(cancellationLatencyMs(of: attempts, finishCalledAt: Date(timeIntervalSinceReferenceDate: 101.2)))
  #expect(abs(latency - 400) < 0.1)

  #expect(cancellationLatencyMs(of: [attempts[0]], finishCalledAt: Date(timeIntervalSinceReferenceDate: 101.2)) == nil)
}

@Test("A cancelled final revision is a deadline fallback, and one that ran long is an overrun")
func deadlineOutcomeComesFromTheFinalRevision() throws {
  let fallbackOnTime = [try revision(final: true, result: "cancelled", start: 0, duration: 3.1)]
  #expect(deadlineOutcome(of: fallbackOnTime) == DeadlineOutcome(fellBack: true, overran: false))

  let overran = [try revision(final: true, result: "cancelled", start: 0, duration: 3.4)]
  #expect(deadlineOutcome(of: overran) == DeadlineOutcome(fellBack: true, overran: true))

  // A rejection is a validation fallback, not a deadline one, and a live cancellation is neither.
  let rejected = [
    try revision(final: false, result: "cancelled", start: 0, duration: 5),
    try revision(final: true, result: "rejected", start: 5, duration: 1),
  ]
  #expect(deadlineOutcome(of: rejected) == DeadlineOutcome(fellBack: false, overran: false))
}

@Test("Preparation phases split download progress from loading and span the wait")
func preparationPhasesGroupMessagesByTheirText() {
  let start = Date(timeIntervalSinceReferenceDate: 0)
  let preparation = Preparation(
    startedAt: start, readyAt: start.addingTimeInterval(2),
    messages: [
      .init(ms: 0, message: "Downloading models, 0.1 of 2.3 GB"),
      .init(ms: 500, message: "Downloading models, 1.2 of 2.3 GB"),
      .init(ms: 1200, message: "Loading the cleanup model"),
    ])
  let phases = preparation.phases
  #expect(phases.map(\.name) == ["Downloading models", "Loading the cleanup model"])
  #expect(phases.map(\.ms) == [1200, 800])
}
