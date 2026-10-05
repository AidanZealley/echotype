import EchoTypeCore
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
func runDirectory(_ argument: String) -> URL {
  let path = URL(fileURLWithPath: argument)
  if argument.contains("/") { return path }
  return BenchData.directory.appending(path: "runs/\(argument)")
}

/// The part of `run.json` that scoring needs.
private struct RunSettings: Decodable {
  let provider: String
  let fast: Bool
  let synthetic: Bool
  let buildConfiguration: String?
  let speech: Speech?

  struct Speech: Decodable {
    let voice: String
    let speed: Double
  }
}

/// A run is a speak, cleanup or transcribe run, by which log its directory holds.
private func scoredRun(in directory: URL, manifest: Manifest, references: [String: String]) throws -> any ScoredRun {
  let has = { (log: String) in FileManager.default.fileExists(atPath: directory.appending(path: log).path) }
  if has("speak.jsonl") { return try ScoredSpeakRun(directory: directory, manifest: manifest) }
  if has("cleanup.jsonl") { return try ScoredCleanupRun(directory: directory, manifest: manifest) }
  return try ScoredTranscribeRun(directory: directory, manifest: manifest, references: references)
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
    decoder.dateDecodingStrategy = .secondsOrMilliseconds
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
  let buildConfiguration: String?
  /// Fast runs compress timings, so their latencies are not reported.
  let paced: Bool
  let samples: [(result: TranscribeResult, score: SampleScore)]
  let skipped: [String]
  let measurements: RunMeasurements
  /// The run's first request, apart from the warm results that follow it. Both only cover
  /// samples that were scored.
  let cold: TranscribeResult?
  let warm: [TranscribeResult]
  let repeated: Bool

  init(directory: URL, manifest: Manifest, references: [String: String]) throws {
    let settings = try readSettings(of: directory)
    let results = try readLog("transcribe.jsonl", in: directory, as: TranscribeResult.self)
    name = directory.lastPathComponent
    provider = settings.provider
    buildConfiguration = settings.buildConfiguration
    paced = !settings.fast
    measurements = RunMeasurements(directory: directory)
    repeated = results.contains { ($0.repeatIndex ?? 0) > 0 }

    // Scoring never uses synthetic audio, which would only measure the voice that made it.
    guard !settings.synthetic else {
      samples = []
      skipped = ["whole run: synthetic audio is not scored"]
      (cold, warm) = (nil, [])
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
    let (first, rest) = splitCold(results)
    let isScored = { (result: TranscribeResult) in references[result.id] != nil }
    cold = first.flatMap { isScored($0) ? $0 : nil }
    warm = rest.filter(isScored)
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
  var stopToFinal: [Double] { paced ? warm.compactMap(\.stopToFinalMs) : [] }
  var firstCommitted: [Double] { paced ? warm.compactMap(\.firstCommittedMs) : [] }

  private func rate(_ alignments: [Alignment], over counts: [Int]) -> Double? {
    let total = counts.reduce(0, +)
    return total == 0 ? nil : Double(alignments.map(\.errors).reduce(0, +)) / Double(total)
  }

  // MARK: Rendering

  func table() -> String {
    var lines = ["\(name)  (\(provider)\(buildConfiguration.map { ", \($0) build" } ?? ""), \(paced ? "paced" : "fast: latency not reported"))", ""]
    var rows = [["sample", "WER", "formatted WER", "keyterms", "stop-to-final", "violations"]]
    for (result, score) in samples {
      rows.append([
        label(score.id, result.repeatIndex, repeated), werText(score.words, score.referenceWords), werText(score.formatted, score.referenceTokens),
        score.keytermTotal == 0 ? "—" : "\(score.keytermHits)/\(score.keytermTotal)",
        paced ? result.stopToFinalMs.map { "\(Int($0.rounded())) ms" } ?? "no final" : "—",
        result.error == nil ? "\(result.violations.count)" : "ERROR: \(result.error ?? "")",
      ])
    }
    lines += pad(rows)
    let dictations = samples.compactMap { sample -> (TranscribeResult, CleanupResult)? in
      sample.result.dictation.map { (sample.result, $0) }
    }
    if !dictations.isEmpty {
      var revisionRows = [["sample", "stop-to-insert", "transcription", "cleanup", "cancel", "deadline", "revising"]]
      for (result, revision) in dictations {
        let deadline = deadlineOutcome(of: revision.attempts)
        revisionRows.append([
          label(result.id, result.repeatIndex, repeated), milliseconds(result.stopToInsert?.totalMs),
          milliseconds(result.stopToInsert?.transcriptionMs), milliseconds(result.stopToInsert?.cleanupMs),
          milliseconds(revision.finishCalledAt.flatMap { cancellationLatencyMs(of: revision.attempts, finishCalledAt: $0) }),
          [deadline.fellBack ? "fallback" : nil, deadline.overran ? "overrun" : nil].compactMap { $0 }.joined(separator: ", ").nonEmpty ?? "—",
          percent(revision.revisingShare),
        ])
      }
      lines += [""] + pad(revisionRows)
      for (result, revision) in dictations { lines += ["", "\(label(result.id, result.repeatIndex, repeated)) inserted: \(revision.finalText)"] }
    }
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
      parts.append("warm stop-to-final \(percentiles(stopToFinal))")
      parts.append("warm first committed \(percentiles(firstCommitted))")
      if let cold {
        parts.append("cold stop-to-final \(milliseconds(cold.stopToFinalMs)), first committed \(milliseconds(cold.firstCommittedMs))")
      }
    }
    return ([parts.joined(separator: ", ")] + dictationLines() + measurementLines(measurements)).joined(separator: "\n  ")
  }

  private func dictationLines() -> [String] {
    let counted = samples.compactMap { sample in sample.result.error == nil ? sample.result.dictation : nil }
    guard !counted.isEmpty else { return [] }
    let deadlines = counted.map { deadlineOutcome(of: $0.attempts) }
    let revisions = requestDurations(cold: cold?.dictation?.attempts ?? [], warm: warm.compactMap { $0.dictation?.attempts })
    let cancellations = counted.compactMap { result in
      result.finishCalledAt.flatMap { cancellationLatencyMs(of: result.attempts, finishCalledAt: $0) }
    }
    let shares = counted.map(\.revisingShare)
    var lines = [
      "deadline fallbacks \(deadlines.filter(\.fellBack).count), deadline overruns \(deadlines.filter(\.overran).count)",
      "warm stop-to-insert \(percentiles(warm.compactMap { $0.stopToInsert?.totalMs })), transcription \(percentiles(warm.compactMap { $0.stopToInsert?.transcriptionMs })), cleanup \(percentiles(warm.compactMap { $0.stopToInsert?.cleanupMs }))",
      "warm revision \(percentiles(revisions.warm.map { $0 * 1000 })), cancellation latency \(percentiles(cancellations)), revising \(percent(shares.reduce(0, +) / Double(shares.count))) of the time",
    ]
    if let timing = cold?.stopToInsert {
      lines.append("cold stop-to-insert \(milliseconds(timing.totalMs)), transcription \(milliseconds(timing.transcriptionMs)), cleanup \(milliseconds(timing.cleanupMs)), first revision \(milliseconds(revisions.cold.map { $0 * 1000 }))")
    }
    return lines
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
  let buildConfiguration: String?
  /// Fast runs compress timings, so their latencies are not reported.
  let paced: Bool
  let samples: [(result: CleanupResult, score: CleanupScore)]
  let skipped: [String]
  let measurements: RunMeasurements
  /// The run's first request, apart from the warm results that follow it. Both leave out
  /// samples that are ambiguous or errored, like every total.
  let cold: CleanupResult?
  let warm: [CleanupResult]
  let repeated: Bool

  init(directory: URL, manifest: Manifest) throws {
    let settings = try readSettings(of: directory)
    let results = try readLog("cleanup.jsonl", in: directory, as: CleanupResult.self)
    name = directory.lastPathComponent
    provider = settings.provider
    buildConfiguration = settings.buildConfiguration
    paced = !settings.fast
    measurements = RunMeasurements(directory: directory)
    repeated = results.contains { ($0.repeatIndex ?? 0) > 0 }

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
    let counted = Set(scored.filter { !$0.1.ambiguous }.map(\.0.id))
    let (first, rest) = splitCold(results)
    cold = first.flatMap { counted.contains($0.id) && $0.error == nil ? $0 : nil }
    warm = rest.filter { counted.contains($0.id) && $0.error == nil }
  }

  // MARK: Totals

  /// Ambiguous samples are judged by hand, so they stay out of every total.
  private var counted: [(result: CleanupResult, score: CleanupScore)] { samples.filter { !$0.score.ambiguous } }

  func totals() -> String {
    let counted = counted
    let deadlines = counted.map { deadlineOutcome(of: $0.result.attempts) }
    let rejections = counted.flatMap(\.result.attempts).filter { $0.result.isValidationRejection }.count
    var parts = [
      "exact \(counted.filter(\.score.exact).count)/\(counted.count)",
      "wrong deletions \(counted.map(\.score.wrongDeletions.count).reduce(0, +))",
      "missed edits \(counted.map(\.score.missedEdits.count).reduce(0, +))",
      "not a deletion \(counted.filter(\.score.notADeletion).count)",
      "fallbacks \(counted.map(\.result.fallbacks).reduce(0, +)) (validation rejections \(rejections))",
      "deadline fallbacks \(deadlines.filter(\.fellBack).count)",
      "deadline overruns \(deadlines.filter(\.overran).count)",
    ]
    var lines = [parts.joined(separator: ", ")]
    if paced {
      let shares = counted.map(\.result.revisingShare)
      let revisions = requestDurations(cold: cold?.attempts ?? [], warm: warm.map(\.attempts))
      let cancellations = counted.compactMap { sample in
        sample.result.finishCalledAt.flatMap { cancellationLatencyMs(of: sample.result.attempts, finishCalledAt: $0) }
      }
      parts = [
        "warm stop-to-insert \(percentiles(warm.map(\.stopToInsertMs)))",
        "warm revision \(percentiles(revisions.warm.map { $0 * 1000 }))",
        "cancellation latency \(percentiles(cancellations))",
        "revising \(percent(shares.isEmpty ? nil : shares.reduce(0, +) / Double(shares.count))) of the time",
      ]
      if let cold {
        parts.append("cold stop-to-insert \(milliseconds(cold.stopToInsertMs)), first revision \(milliseconds(revisions.cold.map { $0 * 1000 }))")
      }
      lines.append(parts.joined(separator: ", "))
    }
    return (lines + measurementLines(measurements)).joined(separator: "\n  ")
  }

  // MARK: Rendering

  func table() -> String {
    var lines = ["\(name)  (\(provider)\(buildConfiguration.map { ", \($0) build" } ?? ""), \(paced ? "paced" : "fast: timing not reported"))", ""]
    var rows = [["sample", "exact", "wrong deletions", "missed edits", "stop-to-insert", "revising", "fallbacks", "cancel", "deadline"]]
    for (result, score) in samples {
      let cancellation = result.finishCalledAt.flatMap { cancellationLatencyMs(of: result.attempts, finishCalledAt: $0) }
      let deadline = deadlineOutcome(of: result.attempts)
      rows.append([
        label(score.ambiguous ? "\(score.id) (manual)" : score.id, result.repeatIndex, repeated),
        score.exact ? "yes" : "no",
        score.notADeletion ? "not a deletion" : "\(score.wrongDeletions.count)",
        score.notADeletion ? "—" : "\(score.missedEdits.count)",
        paced ? "\(Int(result.stopToInsertMs.rounded())) ms" : "—",
        paced ? percent(result.revisingShare) : "—",
        "\(result.fallbacks)",
        paced ? milliseconds(cancellation) : "—",
        [deadline.fellBack ? "fallback" : nil, deadline.overran ? "overrun" : nil].compactMap { $0 }.joined(separator: ", ")
          .nonEmpty ?? "—",
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

/// The first audio target for short passages, in milliseconds.
private let firstAudioTargetMs = 500.0

private struct ScoredSpeakRun: ScoredRun {
  let name: String
  let provider: String
  let buildConfiguration: String?
  let voice: String
  let speed: Double
  /// Fast runs do not model the player, so they have no gaps, pause or cancellation.
  let paced: Bool
  let results: [SpeakResult]
  let trials: [CancellationTrial]
  let measurements: RunMeasurements
  /// The run's first reading, apart from the warm ones after it. Both leave out failed readings.
  let cold: SpeakResult?
  let warm: [SpeakResult]
  /// The passages tagged `short`, which the first audio target applies to.
  let shortIDs: Set<String>
  let repeated: Bool

  init(directory: URL, manifest: Manifest) throws {
    let settings = try readSettings(of: directory)
    results = try readLog("speak.jsonl", in: directory, as: SpeakResult.self)
    let hasTrials = FileManager.default.fileExists(atPath: directory.appending(path: "cancellation.jsonl").path)
    trials = hasTrials ? try readLog("cancellation.jsonl", in: directory, as: CancellationTrial.self) : []
    name = directory.lastPathComponent
    provider = settings.provider
    buildConfiguration = settings.buildConfiguration
    voice = settings.speech?.voice ?? "unknown voice"
    speed = settings.speech?.speed ?? 1
    paced = !settings.fast
    measurements = RunMeasurements(directory: directory)
    repeated = results.contains { ($0.repeatIndex ?? 0) > 0 }
    shortIDs = Set(manifest.samples.compactMap { sample in
      if case .reading(let reading) = sample, reading.tags.contains("short") { reading.id } else { nil }
    })
    let (first, rest) = splitCold(results)
    cold = first.flatMap { $0.error == nil ? $0 : nil }
    warm = rest.filter { $0.error == nil }
  }

  private var violations: Int { results.map(\.violations.count).reduce(0, +) + trials.map(\.violations.count).reduce(0, +) }

  func totals() -> String {
    var lines = [
      "voice \(voice) at \(speed)x, \(results.count) readings, \(results.filter { $0.error != nil }.count) failed, violations \(violations)",
      "warm first audio \(percentiles(warm.compactMap(\.firstAudioMs))), cold first audio \(milliseconds(cold?.firstAudioMs))",
      "short passages, warm first audio \(percentiles(warm.filter { shortIDs.contains($0.id) }.compactMap(\.firstAudioMs))) (target \(Int(firstAudioTargetMs)) ms)",
      "warm real-time factor \(ratioPercentiles(warm.compactMap(\.realTimeFactor)))",
    ]
    if paced {
      let gapped = results.filter { ($0.gapCount ?? 0) > 0 }
      lines.append(
        "gaps \(results.compactMap(\.gapCount).reduce(0, +)) totalling \(Int(results.compactMap(\.gapMs).reduce(0, +).rounded())) ms in \(gapped.count) of \(results.count) readings")
      lines += results.compactMap { result in
        result.pause.map { "pause in \(result.id): audio after resume \(String(format: "%.1f", $0.audioAfterResumeSeconds)) s, \(footprintText(across: $0))" }
      }
      let latencies = trials.compactMap(\.latencyMs)
      lines.append("cancellation latency \(percentiles(latencies)), next() already ended in \(trials.filter { !$0.pending }.count) of \(trials.count) trials")
    }
    return (lines + measurementLines(measurements)).joined(separator: "\n  ")
  }

  /// The footprint when the pause began and when it ended, which shows whether the stream kept
  /// generating while the player was paused.
  private func footprintText(across pause: SpeakResult.Pause) -> String {
    let samples = measurements.samples.filter { $0.at >= pause.pausedAt && $0.at <= pause.resumedAt }
    guard let first = samples.first, let last = samples.last else { return "no footprint sampled" }
    return "footprint \(first.footprintBytes / 1_048_576) to \(last.footprintBytes / 1_048_576) MiB across the pause"
  }

  func table() -> String {
    var lines = ["\(name)  (\(provider)\(buildConfiguration.map { ", \($0) build" } ?? ""), \(paced ? "paced" : "fast: gaps, pause and cancellation not recorded"))", ""]
    var rows = [["sample", "first audio", "gaps", "synthesis", "audio", "real-time", "chunks", "largest", "rate", "after resume", "violations"]]
    for result in results {
      rows.append([
        label(result.id, result.repeatIndex, repeated), milliseconds(result.firstAudioMs),
        result.gapCount.map { "\($0) (\(Int((result.gapMs ?? 0).rounded())) ms)" } ?? "—",
        String(format: "%.1f s", result.synthesisSeconds), String(format: "%.1f s", result.audioSeconds),
        result.realTimeFactor.map { String(format: "%.2f", $0) } ?? "—", "\(result.chunks)",
        milliseconds(result.largestChunkMs), result.sampleRate.map { "\($0) Hz" } ?? "—",
        result.pause.map { String(format: "%.1f s", $0.audioAfterResumeSeconds) } ?? "—",
        result.error == nil ? "\(result.violations.count)" : "ERROR: \(result.error ?? "")",
      ])
    }
    lines += pad(rows)
    if !trials.isEmpty {
      var trialRows = [["cancellation trial", "audio before", "pending", "latency", "violations"]]
      for trial in trials {
        trialRows.append([
          label(trial.id, trial.repeatIndex, repeated), String(format: "%.1f s", trial.audioSeconds),
          trial.pending ? "yes" : "no", milliseconds(trial.latencyMs), "\(trial.violations.count)",
        ])
      }
      lines += [""] + pad(trialRows)
    }
    lines += ["", "totals: \(totals())"]
    return lines.joined(separator: "\n")
  }

  func detailSection() -> String {
    let problems = results.filter { !$0.violations.isEmpty }.map { ($0.id, $0.violations) }
      + trials.filter { !$0.violations.isEmpty }.map { ("cancellation trial on \($0.id)", $0.violations) }
    var lines = ["", "", "## Contract violations"]
    for (id, violations) in problems { lines += ["", "### \(id)"] + violations.map { "- \($0)" } }
    if problems.isEmpty { lines += ["", "None."] }
    return lines.joined(separator: "\n") + "\n"
  }
}

extension DictationTrace.Result {
  /// A reply `Reviser` refused because it added, reordered or lost words.
  var isValidationRejection: Bool {
    switch self {
    case .rejected, .replyRequestRemoved: true
    default: false
    }
  }
}

private extension String {
  var nonEmpty: String? { isEmpty ? nil : self }
}

/// The sample id, numbered by repeat when the run has any.
private func label(_ id: String, _ repeatIndex: Int?, _ repeated: Bool) -> String {
  repeated ? "\(id) #\((repeatIndex ?? 0) + 1)" : id
}

/// Run-level lines after the totals: preparation, then memory and thermal state.
private func measurementLines(_ measurements: RunMeasurements) -> [String] {
  [measurements.preparationText, measurements.machineText].compactMap { $0 }
}

private func milliseconds(_ value: Double?) -> String {
  value.map { "\(Int($0.rounded())) ms" } ?? "—"
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
  guard let (p50, p95) = nearestRanks(values) else { return "—" }
  return "p50 \(Int(p50.rounded())) / p95 \(Int(p95.rounded())) ms (n=\(values.count))"
}

/// Nearest-rank p50 and p95 of a ratio.
private func ratioPercentiles(_ values: [Double]) -> String {
  guard let (p50, p95) = nearestRanks(values) else { return "—" }
  return String(format: "p50 %.2f / p95 %.2f (n=%d)", p50, p95, values.count)
}

private func nearestRanks(_ values: [Double]) -> (p50: Double, p95: Double)? {
  guard !values.isEmpty else { return nil }
  let sorted = values.sorted()
  let at = { (p: Double) in sorted[Int((p * Double(sorted.count)).rounded(.up)) - 1] }
  return (at(0.5), at(0.95))
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
