import Foundation

/// `report`: scores each run against the reviewed references (transcribe) or the expected
/// cleanups (cleanup), prints a table per run and writes the same as `report.md` in the run's
/// directory, with the word-level details added. The directory is outside git, which matters
/// because the transcripts are personal.
func report(_ runs: [String], in manifest: Manifest) throws {
  guard !runs.isEmpty else { throw BenchError("report needs at least one run id or path") }
  let references = try loadReferences()
  var scored: [any ScoredRun] = []
  for run in runs {
    let directory = runDirectory(run)
    let scoredRun = try scoredRun(in: directory, manifest: manifest, references: references)
    let terminal = scoredRun.table()
    print(terminal + "\n")
    try ("```\n" + terminal + "\n```" + scoredRun.detailSection()).write(
      to: directory.appending(path: "report.md"), atomically: true, encoding: .utf8)
    scored.append(scoredRun)
  }
  if scored.count > 1 { print(comparison(of: scored)) }
}

/// A run id names a directory under the bench's runs; anything else is taken as a path.
private func runDirectory(_ argument: String) -> URL {
  let path = URL(fileURLWithPath: argument)
  if argument.contains("/") { return path }
  return BenchData.directory.appending(path: "runs/\(argument)")
}

/// The part of `run.json` that scoring needs.
private struct RunSettings: Decodable {
  let provider: String
  let fast: Bool
  let synthetic: Bool
}

/// A run is a transcribe run or a cleanup run, by which log its directory holds.
private func scoredRun(in directory: URL, manifest: Manifest, references: [String: String]) throws -> any ScoredRun {
  let isCleanup = FileManager.default.fileExists(atPath: directory.appending(path: "cleanup.jsonl").path)
  return isCleanup
    ? try ScoredCleanupRun(directory: directory, manifest: manifest)
    : try ScoredTranscribeRun(directory: directory, manifest: manifest, references: references)
}

/// What `report` prints and writes for one run.
private protocol ScoredRun {
  var name: String { get }
  func table() -> String
  func totals() -> String
  /// Markdown after the table: per sample, the words that went wrong.
  func detailSection() -> String
}

/// One JSON line per sample, as `transcribe` and `cleanup` write them.
private func readLog<Result: Decodable>(_ file: String, in directory: URL, as type: Result.Type) throws -> [Result] {
  do {
    let lines = try String(contentsOf: directory.appending(path: file), encoding: .utf8).split(separator: "\n")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try lines.map { try decoder.decode(Result.self, from: Data($0.utf8)) }
  } catch {
    throw BenchError("\(directory.path) has no readable \(file): \(error.localizedDescription)")
  }
}

private func readSettings(of directory: URL) throws -> RunSettings {
  do {
    return try JSONDecoder().decode(RunSettings.self, from: Data(contentsOf: directory.appending(path: "run.json")))
  } catch {
    throw BenchError("\(directory.path) has no readable run.json: \(error.localizedDescription)")
  }
}

private struct ScoredTranscribeRun: ScoredRun {
  let name: String
  let provider: String
  /// Fast runs compress timings, so their latencies are not reported.
  let paced: Bool
  let samples: [(result: TranscribeResult, score: SampleScore)]
  let skipped: [String]

  init(directory: URL, manifest: Manifest, references: [String: String]) throws {
    let settings = try readSettings(of: directory)
    let results = try readLog("transcribe.jsonl", in: directory, as: TranscribeResult.self)
    name = directory.lastPathComponent
    provider = settings.provider
    paced = !settings.fast

    // Scoring never uses synthetic audio, which would only measure the voice that made it.
    guard !settings.synthetic else {
      samples = []
      skipped = ["whole run: synthetic audio is not scored"]
      return
    }
    var scored: [(TranscribeResult, SampleScore)] = []
    var skipped: [String] = []
    for result in results {
      if let reference = references[result.id] {
        scored.append((result, score(
          id: result.id, finalText: result.finalText, reference: reference, keyterms: manifest.keyterms)))
      } else {
        skipped.append("\(result.id): no reviewed reference")
      }
    }
    samples = scored
    self.skipped = skipped
  }

  // MARK: Totals

  /// Errors are summed over every sample before dividing, so long samples weigh more than short
  /// ones. Insertions into silence count as errors, though that sample has no rate of its own.
  var wer: Double? { rate(samples.map(\.score.words), over: samples.map(\.score.referenceWords)) }
  var formattedWER: Double? {
    rate(samples.map(\.score.formatted), over: samples.map(\.score.referenceTokens))
  }
  var keytermAccuracy: Double? {
    let total = samples.map(\.score.keytermTotal).reduce(0, +)
    return total == 0 ? nil : Double(samples.map(\.score.keytermHits).reduce(0, +)) / Double(total)
  }
  var hallucinations: Int { samples.filter(\.score.hallucinated).count }
  var stopToFinal: [Double] { paced ? samples.compactMap(\.result.stopToFinalMs) : [] }
  var firstCommitted: [Double] { paced ? samples.compactMap(\.result.firstCommittedMs) : [] }

  private func rate(_ alignments: [Alignment], over counts: [Int]) -> Double? {
    let total = counts.reduce(0, +)
    return total == 0 ? nil : Double(alignments.map(\.errors).reduce(0, +)) / Double(total)
  }

  // MARK: Rendering

  func table() -> String {
    var lines = ["\(name)  (\(provider), \(paced ? "paced" : "fast: latency not reported"))", ""]
    var rows = [["sample", "WER", "formatted WER", "keyterms", "stop-to-final", "violations"]]
    for (result, score) in samples {
      rows.append([
        score.id, werText(score.words, score.referenceWords), werText(score.formatted, score.referenceTokens),
        score.keytermTotal == 0 ? "—" : "\(score.keytermHits)/\(score.keytermTotal)",
        paced ? result.stopToFinalMs.map { "\(Int($0.rounded())) ms" } ?? "no final" : "—",
        result.error == nil ? "\(result.violations.count)" : "ERROR: \(result.error ?? "")",
      ])
    }
    lines += pad(rows)
    lines += ["", "totals: \(totals())"]
    lines += skipped.map { "skipped \($0)" }
    return lines.joined(separator: "\n")
  }

  func totals() -> String {
    var parts = [
      "WER \(percent(wer))", "formatted WER \(percent(formattedWER))",
      "keyterms \(percent(keytermAccuracy))", "hallucinations \(hallucinations)",
    ]
    if paced {
      parts.append("stop-to-final \(percentiles(stopToFinal))")
      parts.append("first committed \(percentiles(firstCommitted))")
    }
    return parts.joined(separator: ", ")
  }

  /// Per sample, what the alignments disagree on, so a human can see what went wrong.
  func detailSection() -> String {
    var lines = ["", "", "## Misaligned words (reference → transcript)"]
    for (_, score) in samples where score.words.errors + score.formatted.errors + score.missedKeyterms.count > 0 {
      lines += ["", "### \(score.id)"]
      if !score.words.mismatches.isEmpty { lines.append("- words: \(pairs(score.words))") }
      if !score.formatted.mismatches.isEmpty { lines.append("- formatted: \(pairs(score.formatted))") }
      if !score.missedKeyterms.isEmpty { lines.append("- missed keyterms: \(score.missedKeyterms.joined(separator: ", "))") }
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

private struct ScoredCleanupRun: ScoredRun {
  let name: String
  let provider: String
  /// Fast runs compress timings, so their latencies are not reported.
  let paced: Bool
  let samples: [(result: CleanupResult, score: CleanupScore)]
  let skipped: [String]

  init(directory: URL, manifest: Manifest) throws {
    let settings = try readSettings(of: directory)
    let results = try readLog("cleanup.jsonl", in: directory, as: CleanupResult.self)
    name = directory.lastPathComponent
    provider = settings.provider
    paced = !settings.fast

    let cleanups = manifest.samples.compactMap { sample -> Cleanup? in
      if case .cleanup(let cleanup) = sample { cleanup } else { nil }
    }
    var scored: [(CleanupResult, CleanupScore)] = []
    var skipped: [String] = []
    for result in results {
      if let error = result.error {
        skipped.append("\(result.id): ERROR \(error)")
      } else if let sample = cleanups.first(where: { $0.id == result.id }) {
        scored.append((result, scoreCleanup(
          id: result.id, input: result.input, finalText: result.finalText, expected: sample.expected,
          ambiguous: sample.ambiguous)))
      } else {
        skipped.append("\(result.id): not a cleanup sample in the manifest")
      }
    }
    samples = scored
    self.skipped = skipped
  }

  // MARK: Totals

  /// Ambiguous samples are judged by hand, so they stay out of every total.
  private var counted: [(result: CleanupResult, score: CleanupScore)] { samples.filter { !$0.score.ambiguous } }

  func totals() -> String {
    let counted = counted
    var parts = [
      "exact \(counted.filter(\.score.exact).count)/\(counted.count)",
      "wrong deletions \(counted.map(\.score.wrongDeletions.count).reduce(0, +))",
      "missed edits \(counted.map(\.score.missedEdits.count).reduce(0, +))",
      "not a deletion \(counted.filter(\.score.notADeletion).count)",
      "fallbacks \(counted.map(\.result.fallbacks).reduce(0, +))",
    ]
    if paced {
      let shares = counted.map(\.result.revisingShare)
      parts.append("stop-to-insert \(percentiles(counted.map(\.result.stopToInsertMs)))")
      parts.append("revising \(percent(shares.isEmpty ? nil : shares.reduce(0, +) / Double(shares.count))) of the time")
    }
    return parts.joined(separator: ", ")
  }

  // MARK: Rendering

  func table() -> String {
    var lines = ["\(name)  (\(provider), \(paced ? "paced" : "fast: timing not reported"))", ""]
    var rows = [["sample", "exact", "wrong deletions", "missed edits", "stop-to-insert", "revising", "fallbacks"]]
    for (result, score) in samples {
      rows.append([
        score.ambiguous ? "\(score.id) (manual)" : score.id,
        score.exact ? "yes" : "no",
        score.notADeletion ? "not a deletion" : "\(score.wrongDeletions.count)",
        score.notADeletion ? "—" : "\(score.missedEdits.count)",
        paced ? "\(Int(result.stopToInsertMs.rounded())) ms" : "—",
        paced ? percent(result.revisingShare) : "—",
        "\(result.fallbacks)",
      ])
    }
    lines += pad(rows)
    lines += ["", "totals: \(totals())"]
    lines += skipped.map { "skipped \($0)" }
    return lines.joined(separator: "\n")
  }

  func detailSection() -> String {
    var lines = ["", "", "## Wrong deletions and missed edits"]
    for (result, score) in samples where !score.exact {
      lines += ["", "### \(score.id)\(score.ambiguous ? " (manual)" : "")"]
      if score.notADeletion { lines.append("- not a deletion: the reply added or reordered words") }
      if !score.wrongDeletions.isEmpty { lines.append("- wrongly deleted: \(score.wrongDeletions.joined(separator: " "))") }
      if !score.missedEdits.isEmpty { lines.append("- missed: \(score.missedEdits.joined(separator: " "))") }
      lines.append("- final: \(result.finalText)")
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

private func pairs(_ alignment: Alignment) -> String {
  alignment.mismatches.map { "\($0.reference ?? "∅") → \($0.hypothesis ?? "∅")" }.joined(separator: "; ")
}

/// A rate, or the insertions alone when the reference is empty and there is nothing to divide by.
private func werText(_ alignment: Alignment, _ referenceCount: Int) -> String {
  referenceCount == 0 ? "\(alignment.insertions) inserted" : percent(Double(alignment.errors) / Double(referenceCount))
}

private func percent(_ value: Double?) -> String {
  value.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
}

/// Nearest-rank p50 and p95 in milliseconds.
private func percentiles(_ values: [Double]) -> String {
  guard !values.isEmpty else { return "—" }
  let sorted = values.sorted()
  let at = { (p: Double) in Int(sorted[Int((p * Double(sorted.count)).rounded(.up)) - 1].rounded()) }
  return "p50 \(at(0.5)) / p95 \(at(0.95)) ms (n=\(sorted.count))"
}

/// Left-aligned columns, with the header underlined.
private func pad(_ rows: [[String]]) -> [String] {
  let widths = rows[0].indices.map { column in rows.map { $0[column].count }.max() ?? 0 }
  let lines = rows.map { row in
    row.enumerated().map { $1.padding(toLength: widths[$0], withPad: " ", startingAt: 0) }.joined(separator: "  ")
  }
  return [lines[0], String(repeating: "-", count: lines[0].count)] + lines.dropFirst()
}

private func comparison(of runs: [any ScoredRun]) -> String {
  (["comparison"] + runs.map { "\($0.name): \($0.totals())" }).joined(separator: "\n")
}
