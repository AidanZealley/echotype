import EchoTypeCore
import Foundation

/// `cleanup`: replays each cleanup sample's committed-text timeline through a real `Reviser`
/// and records what it did.
///
/// Everything that can be wrong with the request is checked before the run directory exists.
/// Samples then run one at a time, each with a fresh `Reviser`.
func cleanup(_ options: RunOptions, in manifest: Manifest) async throws {
  guard !options.synthetic else { throw BenchError("--synthetic only applies to transcribe") }
  let provider = try options.provider()
  guard let service = provider.cleanup else { throw BenchError("\(provider.name) has no cleanup.") }
  let credential = try credential(for: provider)
  let samples = try cleanupTargets(options, in: manifest)
  try await requireReady(provider, "cleanup", state: \.cleanup)

  let directory = try RunInfo.begin(
    command: "cleanup", arguments: options.arguments, provider: provider.id.rawValue,
    fast: options.fast, synthetic: false)
  let log = directory.appending(path: "cleanup.jsonl")
  FileManager.default.createFile(atPath: log.path, contents: nil)
  let logFile = try FileHandle(forWritingTo: log)
  defer { try? logFile.close() }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  encoder.dateEncodingStrategy = .iso8601

  for sample in samples {
    let reviser = Reviser(cleanup: service, credential: credential)
    let result = await replay(sample, through: reviser, fast: options.fast)
    try logFile.write(contentsOf: encoder.encode(result) + Data("\n".utf8))
    print(summaryLine(for: result))
  }
  print("\n" + directory.path)
}

/// One sample's record: one JSONL line.
struct CleanupResult: Codable {
  let id: String
  /// The full committed text, as it stood when `finish` was called.
  let input: String
  /// What `finish` returned, which is what a dictation inserts.
  let finalText: String
  let attempts: [DictationTrace.Revision]
  /// From calling `finish` to its return.
  let stopToInsertMs: Double
  /// Time spent in revision requests over the timeline: the last segment's time plus stop-to-insert.
  let revisingShare: Double
  /// Requests whose words were kept unrevised: failed, empty, unfaithful or dropping a reply request.
  let fallbacks: Int
  let error: String?
}

private func cleanupTargets(_ options: RunOptions, in manifest: Manifest) throws -> [Cleanup] {
  let all = manifest.samples.compactMap { sample -> Cleanup? in
    if case .cleanup(let cleanup) = sample { cleanup } else { nil }
  }
  guard !options.ids.isEmpty else { return all }
  return try options.ids.map { id in
    guard let sample = all.first(where: { $0.id == id }) else { throw BenchError("\(id) is not a cleanup sample") }
    return sample
  }
}

/// Grows the committed text segment by segment as the app does, then finishes. Segments are
/// joined by a space: the speech assembler appends each final segment with its own leading
/// whitespace, and the corpus segments have none.
private func replay(_ sample: Cleanup, through reviser: Reviser, fast: Bool) async -> CleanupResult {
  let start = ContinuousClock.now
  var committed = ""
  var error: String?
  do {
    for segment in sample.segments {
      if !fast { try await ContinuousClock().sleep(until: start + .seconds(segment.at)) }
      committed += committed.isEmpty ? segment.text : " " + segment.text
      await reviser.submit(committed: committed)
    }
  } catch let thrown {
    error = "\(thrown)"
  }

  let finishCalledAt = ContinuousClock.now
  let finalText = await reviser.finish(committed: committed)
  let stopToInsert = ContinuousClock.now - finishCalledAt
  let attempts = await reviser.attempts

  let timeline = (sample.segments.last?.at ?? 0) + stopToInsert / .seconds(1)
  return CleanupResult(
    id: sample.id, input: committed, finalText: finalText, attempts: attempts,
    stopToInsertMs: (stopToInsert / .milliseconds(1) * 10).rounded() / 10,
    revisingShare: timeline > 0 ? attempts.map(\.duration).reduce(0, +) / timeline : 0,
    fallbacks: attempts.filter(\.result.isFallback).count, error: error)
}

extension DictationTrace.Result {
  /// The results after which `Reviser` keeps the streamed words instead of the reply.
  var isFallback: Bool {
    switch self {
    case .rejected, .replyRequestRemoved, .empty, .failed: true
    case .accepted, .unchanged, .cancelled, .superseded: false
    }
  }
}

private func summaryLine(for result: CleanupResult) -> String {
  let text = result.finalText.count > 70 ? result.finalText.prefix(70) + "..." : Substring(result.finalText)
  let outcome = result.error.map { "FAILED: \($0)" } ?? "\"\(text)\""
  return "\(result.id): \(outcome)  stop-to-insert \(Int(result.stopToInsertMs.rounded())) ms  \(result.fallbacks) fallbacks"
}
