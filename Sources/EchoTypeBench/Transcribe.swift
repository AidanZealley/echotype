import EchoTypeCore
import EchoTypeTestSupport
import Foundation

/// `transcribe`: feeds each dictation sample's audio through a provider's `LiveTranscriber`,
/// directly rather than through `SessionMachine`, and records what the provider did.
///
/// Everything that can be wrong with the request is checked before the run directory exists or
/// a transcriber starts. Samples then run one at a time; a failing sample is recorded and the
/// run goes on.
func transcribe(_ options: TranscribeOptions, in manifest: Manifest) async throws {
  let provider = try options.provider()
  let credential = try credential(for: provider)
  let samples = try transcriptionTargets(options, in: manifest)
  let request = TranscriptionRequest(
    settings: Settings(provider: provider.id, keyterms: manifest.keyterms, language: Language.english.tag),
    provider: provider, credential: credential)
  try await requireReady(provider, language: request.language)

  let directory = try RunInfo.begin(
    command: "transcribe", arguments: options.arguments, provider: provider.id.rawValue,
    fast: options.fast, synthetic: options.synthetic)
  let log = directory.appending(path: "transcribe.jsonl")
  FileManager.default.createFile(atPath: log.path, contents: nil)
  let logFile = try FileHandle(forWritingTo: log)
  defer { try? logFile.close() }
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

  for sample in samples {
    let result = await transcribe(sample, provider: provider, request: request, fast: options.fast, synthetic: options.synthetic)
    try logFile.write(contentsOf: encoder.encode(result) + Data("\n".utf8))
    print(summaryLine(for: result))
  }
  print("\n" + directory.path)
}

/// Command-line options, parsed by hand like the rest of the bench.
struct TranscribeOptions {
  let arguments: [String]
  var providerID: String?
  var fast = false
  var synthetic = false
  var ids: [String] = []

  init(parsing arguments: [String]) throws {
    self.arguments = arguments
    var rest = arguments[...]
    while let argument = rest.popFirst() {
      switch argument {
      case "--provider":
        guard let value = rest.popFirst() else { throw BenchError("--provider needs a value") }
        providerID = value
      case "--fast": fast = true
      case "--synthetic": synthetic = true
      case _ where argument.hasPrefix("--"): throw BenchError("unknown option \(argument)")
      default: ids.append(argument)
      }
    }
  }

  func provider() throws -> Provider {
    let known = Providers.all.map(\.id.rawValue)
    guard let providerID, let provider = Providers.all.first(where: { $0.id.rawValue == providerID })
    else { throw BenchError("--provider must be one of: \(known.joined(separator: ", "))") }
    return provider
  }
}

/// A key provider's credential comes from the environment, as in `LiveProtocolTests`, rather than
/// the app's Keychain item.
private func credential(for provider: Provider) throws -> String? {
  guard case .apiKey = provider.credential else { return nil }
  let name = "\(provider.id.rawValue.uppercased())_API_KEY"
  guard let key = ProcessInfo.processInfo.environment[name], !key.isEmpty else {
    throw BenchError("\(name) is not set; \(provider.name) transcription needs it.")
  }
  return key
}

/// The samples to run, each with its audio: the named dictation samples, or every one that has
/// audio of the requested kind.
private func transcriptionTargets(
  _ options: TranscribeOptions, in manifest: Manifest
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

/// Waits while the provider is setting up transcription, such as downloading a speech model.
private func requireReady(_ provider: Provider, language: String) async throws {
  let request = ReadinessRequest(language: language, voice: provider.voice.voices[0].id)
  // Subscribed before the first check, so a change in between is not missed.
  let changes = provider.readiness.changes()
  var state = await provider.readiness.check(request).transcription
  var updates = changes.makeAsyncIterator()
  while state.status == .waiting {
    print("Waiting: \(state.message ?? "transcription is setting up")")
    guard await updates.next() != nil else { break }
    state = await provider.readiness.check(request).transcription
  }
  guard state.status == .ready else {
    throw BenchError("\(provider.name) transcription is not ready: \(state.message ?? "unavailable")")
  }
}

// MARK: One sample

/// How long to wait for `.ready`, and for `.finished` after `finish()`, before closing the
/// transcriber and recording the failure instead of hanging.
private let phaseTimeout = Duration.seconds(30)

/// One sample's record: one JSONL line. Times are milliseconds after the first audio was sent,
/// so `.ready` and anything before audio starts are negative.
struct TranscribeResult: Encodable {
  struct Event: Encodable {
    let ms: Double
    let event: String
    let committed: String?
    let utterance: String?
    let provisional: String?
  }

  let id: String
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
}

/// What the event reader saw, with the time of each event.
private struct Observed {
  var events: [(at: ContinuousClock.Instant, event: TranscriptionEvent)] = []
  var check = ContractCheck()
  var error: String?
}

private func transcribe(
  _ target: (sample: Dictation, audio: URL), provider: Provider, request: TranscriptionRequest,
  fast: Bool, synthetic: Bool
) async -> TranscribeResult {
  var origin: ContinuousClock.Instant?
  var finishCalledAt: ContinuousClock.Instant?
  var audioSeconds: Double?
  var error: String?
  var transcriber: (any LiveTranscriber)?
  var reader: Task<Observed, Never>?
  var observed: Observed?

  do {
    let recording = try WAVRecording(contentsOf: target.audio)
    audioSeconds = recording.duration(ofInterleaved: recording.samples)
    let session = try await provider.transcription.start(request)
    transcriber = session
    let (events, ready) = readEvents(of: session)
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
  if observed == nil { observed = await reader?.value }
  var seen = observed ?? Observed()
  if finishCalledAt != nil && error == nil { seen.check.finishWasCalled() }
  error = error ?? seen.error

  return result(
    for: target.sample, synthetic: synthetic, audioSeconds: audioSeconds, observed: seen,
    origin: origin ?? finishCalledAt ?? .now, finishCalledAt: finishCalledAt, error: error)
}

/// Reads the event stream on its own task so events are stamped as they arrive, whatever the
/// sender is doing. The second value yields once on `.ready` and finishes when the stream ends.
private func readEvents(
  of transcriber: any LiveTranscriber
) -> (Task<Observed, Never>, AsyncStream<Void>) {
  let (ready, signal) = AsyncStream.makeStream(of: Void.self)
  let reader = Task {
    var observed = Observed()
    do {
      for try await event in transcriber.events {
        observed.events.append((.now, event))
        observed.check.observe(event)
        if event == .ready { signal.yield() }
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
  for sample: Dictation, synthetic: Bool, audioSeconds: Double?, observed: Observed,
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
    id: sample.id, synthetic: synthetic, audioSeconds: audioSeconds, events: events,
    finalText: transcripts.last?.committed ?? "",
    firstProvisionalMs: transcripts.first { $0.provisional?.isEmpty == false }?.ms,
    firstCommittedMs: transcripts.first { $0.committed?.isEmpty == false }?.ms,
    stopToFinalMs: finishCalledAt.flatMap { stop in finished.map { milliseconds($0.at - stop) } },
    violations: observed.check.violations, error: error)
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
