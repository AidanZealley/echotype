import EchoTypeCore
import EchoTypeTestSupport
import Foundation

/// `transcribe`: feeds each dictation sample's audio through a provider's `LiveTranscriber`,
/// directly rather than through `SessionMachine`, and records what the provider did.
///
/// Everything that can be wrong with the request is checked before the run directory exists or
/// a transcriber starts. Samples then run one at a time; a failing sample is recorded and the
/// run goes on.
func transcribe(_ options: RunOptions, in manifest: Manifest) async throws {
  let provider = try options.provider(measuring: .transcription)
  try validateDictation(options, provider: provider)
  let credential = try credential(for: provider)
  let samples = try transcriptionTargets(options, in: manifest)
  let request = TranscriptionRequest(
    settings: Settings(provider: provider.id, keyterms: manifest.keyterms, language: Language.english.tag),
    provider: provider, credential: credential)
  let sampler = Sampler()
  var preparation = try await requireReady(provider, options.withCleanup ? "dictation" : "transcription") { states in
    guard options.withCleanup else { return states.transcription }
    guard let cleanup = states.cleanup else { return nil }
    let services = [states.transcription, cleanup]
    if let unavailable = services.first(where: { $0.status == .unavailable }) { return unavailable }
    let messages = services.filter { $0.status == .waiting }.compactMap(\.message)
    return messages.isEmpty ? .ready : .waiting(messages.joined(separator: "; "))
  }
  preparation.services = options.withCleanup ? ["transcription", "cleanup"] : ["transcription"]
  sampler.sampleNow()

  let directory = try RunInfo.begin(
    command: "transcribe", arguments: options.arguments, provider: provider.id.rawValue,
    candidates: try options.recordedSelection(measuring: .transcription), fast: options.fast,
    synthetic: options.synthetic)
  try writeJSON(preparation, to: directory.appending(path: "preparation.json"))
  let log = directory.appending(path: "transcribe.jsonl")
  FileManager.default.createFile(atPath: log.path, contents: nil)
  let logFile = try FileHandle(forWritingTo: log)
  defer { try? logFile.close() }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  encoder.dateEncodingStrategy = .milliseconds

  for repeatIndex in 0..<options.repeats {
    for sample in samples {
      let result = await transcribe(
        sample, repeatIndex: repeatIndex, provider: provider, request: request, fast: options.fast,
        synthetic: options.synthetic, withCleanup: options.withCleanup)
      try logFile.write(contentsOf: encoder.encode(result) + Data("\n".utf8))
      print(summaryLine(for: result))
    }
  }
  try sampler.stop(writingTo: directory)
  print("\n" + directory.path)
}

/// The samples to run, each with its audio: the named dictation samples, or every one that has
/// audio of the requested kind.
private func transcriptionTargets(
  _ options: RunOptions, in manifest: Manifest
) throws -> [(sample: Dictation, audio: URL)] {
  let dictations = manifest.samples.compactMap { sample -> Dictation? in
    if case .dictation(let dictation) = sample { dictation } else { nil }
  }
  let audio = options.synthetic ? BenchData.syntheticAudio : BenchData.recording
  let hasAudio = { (sample: Dictation) in FileManager.default.fileExists(atPath: audio(sample.id).path) }

  let chosen: [Dictation]
  if options.ids.isEmpty {
    chosen = dictations.filter(hasAudio)
  } else {
    chosen = try options.ids.map { id in
      guard let sample = dictations.first(where: { $0.id == id }) else {
        throw BenchError("\(id) is not a dictation sample")
      }
      guard hasAudio(sample) else {
        throw BenchError("\(id) has no \(options.synthetic ? "synthetic audio" : "recording")")
      }
      return sample
    }
  }
  guard !chosen.isEmpty else { throw BenchError("No dictation samples have audio to transcribe.") }
  return chosen.map { ($0, audio($0.id)) }
}

/// Validate dictation before credentials, readiness or run-directory creation.
func validateDictation(_ options: RunOptions, provider: Provider) throws {
  guard !options.withCleanup || !options.fast else { throw BenchError("--cleanup requires paced audio; remove --fast") }
  guard !options.withCleanup || provider.cleanup != nil else { throw BenchError("\(provider.name) has no cleanup.") }
}

// MARK: One sample

/// How long to wait for `.ready`, and for `.finished` after `finish()`, before closing the
/// transcriber and recording the failure instead of hanging.
private let phaseTimeout = Duration.seconds(30)

/// One sample's record: one JSONL line. Times are milliseconds after the first audio was sent,
/// so `.ready` and anything before audio starts are negative.
struct TranscribeResult: Codable, RepeatedResult {
  struct Event: Codable {
    let ms: Double
    let event: String
    let committed: String?
    let utterance: String?
    let provisional: String?
  }

  let id: String
  /// Which run through the samples this was, from 0. Nil in runs from before `--repeat`.
  let repeatIndex: Int?
  let synthetic: Bool
  let audioSeconds: Double?
  let events: [Event]
  /// The last committed text, which is what a normal finish inserts. See `SessionMachine.conclude`.
  let finalText: String
  let firstProvisionalMs: Double?
  let firstCommittedMs: Double?
  /// From calling `finish()` to `.finished`.
  let stopToFinalMs: Double?
  let violations: [String]
  /// A thrown error, or a transcriber that never answered.
  let error: String?
  /// Present only for paced dictation runs. The nested record shares cleanup's trace and measures.
  let dictation: CleanupResult?
  let stopToInsert: StopToInsert?
}

/// What the event reader saw, with the time of each event.
private struct Observed {
  var events: [(at: ContinuousClock.Instant, event: TranscriptionEvent)] = []
  var check = ContractCheck()
  var error: String?
  var dictation: CleanupResult?
  var insertedAt: ContinuousClock.Instant?
}

private func transcribe(
  _ target: (sample: Dictation, audio: URL), repeatIndex: Int, provider: Provider, request: TranscriptionRequest,
  fast: Bool, synthetic: Bool, withCleanup: Bool
) async -> TranscribeResult {
  var origin: ContinuousClock.Instant?
  var finishCalledAt: ContinuousClock.Instant?
  var audioSeconds: Double?
  var error: String?
  var transcriber: (any LiveTranscriber)?
  var reader: Task<Observed, Never>?
  var observed: Observed?
  let reviser = withCleanup ? provider.cleanup.map { Reviser(cleanup: $0, credential: request.credential) } : nil

  do {
    let recording = try WAVRecording(contentsOf: target.audio)
    audioSeconds = recording.duration(ofInterleaved: recording.samples)
    let session = try await provider.transcription.start(request)
    transcriber = session
    let (events, ready) = readEvents(of: session, reviser: reviser, id: target.sample.id, repeatIndex: repeatIndex)
    reader = events

    try await waitForReady(ready, closing: session)
    origin = try await feed(recording, to: session, fast: fast)
    finishCalledAt = .now
    try await session.finish()
    observed = await drain(events, closing: session)
  } catch let thrown {
    error = "\(thrown)"
  }

  transcriber?.close()
  await transcriber?.waitForClose()
  await reviser?.stop()
  if observed == nil { observed = await reader?.value }
  var seen = observed ?? Observed()
  if finishCalledAt != nil && error == nil { seen.check.finishWasCalled() }
  error = error ?? seen.error

  return result(
    for: target.sample, repeatIndex: repeatIndex, synthetic: synthetic, audioSeconds: audioSeconds, observed: seen,
    origin: origin ?? finishCalledAt ?? .now, finishCalledAt: finishCalledAt, error: error)
}

/// Reads the event stream on its own task so events are stamped as they arrive, whatever the
/// sender is doing. The second value yields once on `.ready` and finishes when the stream ends.
private func readEvents(
  of transcriber: any LiveTranscriber, reviser: Reviser?, id: String, repeatIndex: Int
) -> (Task<Observed, Never>, AsyncStream<Void>) {
  let (ready, signal) = AsyncStream.makeStream(of: Void.self)
  let reader = Task {
    var observed = Observed()
    var committed = ""
    do {
      for try await event in transcriber.events {
        observed.events.append((.now, event))
        observed.check.observe(event)
        if event == .ready { signal.yield() }
        if case .transcript(let transcript) = event {
          committed = transcript.committed
          await reviser?.submit(committed: committed)
        }
        if event == .finished, let reviser {
          let finishCalledAt = Date()
          let clock = ContinuousClock.now
          let inserted = await reviser.finish(committed: committed)
          let end = ContinuousClock.now
          let attempts = await reviser.attempts
          let timeline = end - (observed.events.first?.at ?? clock)
          observed.insertedAt = end
          observed.dictation = CleanupResult(
            id: id, repeatIndex: repeatIndex, input: committed, finalText: inserted, attempts: attempts,
            finishCalledAt: finishCalledAt, stopToInsertMs: milliseconds(end - clock),
            revisingShare: attempts.map(\.duration).reduce(0, +) / max(timeline / .seconds(1), 0.001),
            fallbacks: attempts.filter(\.result.isFallback).count, error: nil)
        }
      }
    } catch {
      observed.error = "events failed: \(error)"
    }
    signal.finish()
    return observed
  }
  return (reader, ready)
}

private func waitForReady(_ ready: AsyncStream<Void>, closing transcriber: any LiveTranscriber) async throws {
  let watchdog = closeAfterTimeout(transcriber)
  defer { watchdog.cancel() }
  guard await ready.first(where: { _ in true }) != nil else {
    throw BenchError("the transcriber never became ready")
  }
}

/// Sends the recording in 100 ms chunks, each awaited, at real-time pace unless `fast`. Returns
/// when the first chunk was sent.
private func feed(
  _ recording: WAVRecording, to transcriber: any LiveTranscriber, fast: Bool
) async throws -> ContinuousClock.Instant {
  var converter = AudioConverter(inputSampleRate: recording.sampleRate, channelCount: recording.channelCount)
  let start = ContinuousClock.now
  for (index, chunk) in recording.chunks(ofSeconds: 0.1).enumerated() {
    try await transcriber.send(audio: converter.convert(chunk))
    if !fast { try await ContinuousClock().sleep(until: start + .milliseconds((index + 1) * 100)) }
  }
  return start
}

private func drain(_ reader: Task<Observed, Never>, closing transcriber: any LiveTranscriber) async -> Observed {
  let watchdog = closeAfterTimeout(transcriber)
  defer { watchdog.cancel() }
  return await reader.value
}

/// Closing a transcriber ends its event stream, which is what releases a stuck wait.
private func closeAfterTimeout(_ transcriber: any LiveTranscriber) -> Task<Void, Never> {
  Task {
    guard (try? await Task.sleep(for: phaseTimeout)) != nil else { return }
    transcriber.close()
  }
}

private func result(
  for sample: Dictation, repeatIndex: Int, synthetic: Bool, audioSeconds: Double?, observed: Observed,
  origin: ContinuousClock.Instant, finishCalledAt: ContinuousClock.Instant?, error: String?
) -> TranscribeResult {
  let ms = { (instant: ContinuousClock.Instant) in milliseconds(instant - origin) }
  let events = observed.events.map { entry -> TranscribeResult.Event in
    switch entry.event {
    case .ready: .init(ms: ms(entry.at), event: "ready", committed: nil, utterance: nil, provisional: nil)
    case .speech: .init(ms: ms(entry.at), event: "speech", committed: nil, utterance: nil, provisional: nil)
    case .finished: .init(ms: ms(entry.at), event: "finished", committed: nil, utterance: nil, provisional: nil)
    case .transcript(let transcript):
      .init(
        ms: ms(entry.at), event: "transcript", committed: transcript.committed,
        utterance: transcript.utterance, provisional: transcript.provisional)
    }
  }
  let transcripts = events.filter { $0.event == "transcript" }
  let finished = observed.events.first { $0.event == .finished }
  return TranscribeResult(
    id: sample.id, repeatIndex: repeatIndex, synthetic: synthetic, audioSeconds: audioSeconds, events: events,
    finalText: transcripts.last?.committed ?? "",
    firstProvisionalMs: transcripts.first { $0.provisional?.isEmpty == false }?.ms,
    firstCommittedMs: transcripts.first { $0.committed?.isEmpty == false }?.ms,
    stopToFinalMs: finishCalledAt.flatMap { stop in finished.map { milliseconds($0.at - stop) } },
    violations: observed.check.violations, error: error, dictation: observed.dictation,
    stopToInsert: finishCalledAt.flatMap { stop in
      finished.flatMap { final in
        observed.insertedAt.map { StopToInsert(transcriptionMs: milliseconds(final.at - stop), cleanupMs: milliseconds($0 - final.at)) }
      }
    })
}

private func milliseconds(_ duration: Duration) -> Double {
  let ms = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
  return (ms * 10).rounded() / 10
}

private func summaryLine(for result: TranscribeResult) -> String {
  let text = result.finalText.count > 70 ? result.finalText.prefix(70) + "..." : Substring(result.finalText)
  let outcome = result.error.map { "FAILED: \($0)" } ?? "\"\(text)\""
  let stop = result.stopToFinalMs.map { String(format: "%.0f ms", $0) } ?? "no final"
  return "\(result.id): \(outcome)  stop-to-final \(stop)  \(result.violations.count) violations"
}
