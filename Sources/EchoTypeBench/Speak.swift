import EchoTypeCore
import Foundation

/// `speak`: pulls each reading sample through a provider's `VoiceService` the way `Reader` does
/// and records what the stream did, without making sound. A paced run models the app's
/// `SpeechPlayer`: it starts on the first chunk, holds at most 500 ms and drains in real time.
/// `--fast` pulls without waiting, for synthesis speed and first audio only.
///
/// Everything that can be wrong with the request is checked before the run directory exists.
/// Passages then run one at a time; a failing passage is recorded and the run goes on. A paced
/// pass ends with one cancellation trial.
func speak(_ options: RunOptions, in manifest: Manifest) async throws {
  guard !options.withCleanup else { throw BenchError("--cleanup only applies to transcribe") }
  guard !options.synthetic else { throw BenchError("--synthetic only applies to transcribe") }
  let provider = try options.provider(measuring: .voice)
  let voice = options.voice ?? provider.voice.voices[0].id
  guard provider.voice.voices.contains(where: { $0.id == voice }) else {
    throw BenchError("\(provider.name) has no voice \(voice). Its voices: \(provider.voice.voices.map(\.id).joined(separator: ", "))")
  }
  let speed = options.speed ?? 1
  guard provider.voice.speedRange.contains(speed) else {
    throw BenchError("--speed \(speed) is outside \(provider.name)'s range \(provider.voice.speedRange)")
  }
  let credential = try credential(for: provider)
  let readings = try readingTargets(options, in: manifest)
  let longest = readings.max { $0.text.count < $1.text.count }!
  let speech = Speech(provider: provider, voice: voice, speed: speed, credential: credential)

  let sampler = Sampler()
  let preparation = try await requireReady(provider, voice: voice, services: options.services(measuring: .voice))
  sampler.sampleNow()

  let directory = try RunInfo.begin(
    command: "speak", arguments: options.arguments, provider: provider.id.rawValue,
    candidates: options.recordedSelection(measuring: .voice), fast: options.fast, synthetic: false,
    speech: .init(voice: voice, speed: speed))
  try writeJSON(preparation, to: directory.appending(path: "preparation.json"))
  let readingLog = try ResultLog(directory.appending(path: "speak.jsonl"))
  let trialLog = try ResultLog(directory.appending(path: "cancellation.jsonl"))

  for repeatIndex in 0..<options.repeats {
    for reading in readings {
      let result = await speech.read(reading, repeatIndex: repeatIndex, fast: options.fast, saveTo: directory)
      try readingLog.append(result)
      print(summaryLine(for: result))
    }
    if !options.fast {
      let trial = await speech.cancellationTrial(on: longest, repeatIndex: repeatIndex)
      try trialLog.append(trial)
      print("cancellation trial: \(trial.latencyMs.map { "\(Int($0.rounded())) ms" } ?? "no latency") \(trial.violations.count) violations")
    }
  }
  try sampler.stop(writingTo: directory)
  print("\n" + directory.path)
}

/// The reading samples to run: the named ones, or all.
private func readingTargets(_ options: RunOptions, in manifest: Manifest) throws -> [Reading] {
  let all = manifest.samples.compactMap { sample -> Reading? in
    if case .reading(let reading) = sample { reading } else { nil }
  }
  guard !options.ids.isEmpty else { return all }
  return try options.ids.map { id in
    guard let reading = all.first(where: { $0.id == id }) else { throw BenchError("\(id) is not a reading sample") }
    return reading
  }
}

// MARK: Player model

/// The queue of `SpeechPlayer` in seconds on the run's clock, so its waits and gaps can be worked
/// out without playing anything. Times are seconds since the request.
struct PlayerModel {
  /// `SpeechPlayer` queues at most 500 ms, including what is playing.
  static let capacitySeconds = 0.5

  /// When the queued audio runs out. Nil until the first chunk starts playback.
  private var queueEnd: Double?
  /// Times the queue ran dry before the end, and for how long in all.
  private(set) var gaps = 0
  private(set) var gapSeconds = 0.0

  /// A chunk of `seconds` pulled at `pulledAt` waits for room in the queue. Returns when it is
  /// scheduled. A queue that ran dry before then is a gap.
  mutating func schedule(seconds: Double, pulledAt: Double) -> Double {
    guard let end = queueEnd else {
      queueEnd = pulledAt + seconds
      return pulledAt
    }
    if pulledAt > end {
      gaps += 1
      gapSeconds += pulledAt - end
    }
    let scheduledAt = max(pulledAt, end + seconds - Self.capacitySeconds)
    queueEnd = max(pulledAt, end) + seconds
    return scheduledAt
  }

  /// Playback stops for `seconds` from `now`, so the queue outlasts it by as long. A queue that
  /// had already run dry has been in a gap until now.
  mutating func pause(at now: Double, for seconds: Double) {
    guard let end = queueEnd else { return }
    if end < now {
      gaps += 1
      gapSeconds += now - end
    }
    queueEnd = max(end, now) + seconds
  }
}

// MARK: One reading

/// What one reading needs from the run.
private struct Speech {
  let provider: Provider
  let voice: String
  let speed: Double
  let credential: String?

  /// The first third of the audio is estimated from the text, since the audio's length is not
  /// known until the stream ends.
  static let charactersPerSecond = 15.0
  static let pauseSeconds = 5.0
  /// A chunk that took less than this to pull was ready before it was asked for.
  static let readySeconds = 0.01

  func request(for reading: Reading) -> SpeechRequest {
    SpeechRequest(
      text: provider.voice.capped(reading.text), voice: voice, speed: speed, language: Language.english.tag,
      credential: credential)
  }

  func read(_ reading: Reading, repeatIndex: Int, fast: Bool, saveTo directory: URL) async -> SpeakResult {
    let request = request(for: reading)
    let clock = ContinuousClock()
    let start = clock.now
    let seconds = { (duration: Duration) in duration / .seconds(1) }
    let stream = provider.voice.speak(request)
    defer { stream.cancel() }

    var check = SpeechContractCheck()
    var player = PlayerModel()
    var samples: [Float] = []
    var sampleRate: Int?
    var chunks = 0
    var largest = 0
    var firstAudioMs: Double?
    var synthesis = Duration.zero
    var audioSeconds = 0.0
    let pausesAt = !fast && reading.tags.contains("pause-resume")
      ? Double(request.text.count) / Self.charactersPerSecond / 3 : nil
    var pause: SpeakResult.Pause?
    var resumed: ContinuousClock.Instant?
    var audioAfterResume = 0.0
    var error: String?

    do {
      while true {
        let pullStarted = clock.now
        guard let chunk = try await stream.next() else {
          check.streamEnded(spoken: request.text)
          break
        }
        let pulled = clock.now
        synthesis += pulled - pullStarted
        check.observe(chunk)
        sampleRate = sampleRate ?? chunk.sampleRate
        samples += chunk.samples
        chunks += 1
        largest = max(largest, chunk.samples.count)
        let chunkSeconds = Double(chunk.samples.count) / Double(chunk.sampleRate)
        audioSeconds += chunkSeconds
        firstAudioMs = firstAudioMs ?? seconds(pulled - start) * 1000
        guard !fast else { continue }

        if let resumed, pulled - resumed < .seconds(1), seconds(pulled - pullStarted) < Self.readySeconds {
          audioAfterResume += chunkSeconds
        }
        let scheduledAt = player.schedule(seconds: chunkSeconds, pulledAt: seconds(pulled - start))
        try await clock.sleep(until: start + .seconds(scheduledAt))
        if let pausesAt, pause == nil, audioSeconds >= pausesAt {
          let pausedAt = Date()
          player.pause(at: seconds(clock.now - start), for: Self.pauseSeconds)
          try await clock.sleep(for: .seconds(Self.pauseSeconds))
          resumed = clock.now
          pause = .init(pausedAt: pausedAt, resumedAt: Date(), audioAfterResumeSeconds: 0)
        }
      }
    } catch let thrown {
      check.threw(thrown)
      error = "\(thrown)"
    }
    pause?.audioAfterResumeSeconds = audioAfterResume

    if repeatIndex == 0, let sampleRate, error == nil {
      let pcm = samples.map { Int16(max(-1, min(1, $0)) * 32767) }
      do {
        try writeWAV(pcm, sampleRate: sampleRate, to: directory.appending(path: "\(reading.id).wav"))
      } catch let thrown {
        error = "could not write the WAV: \(thrown)"
      }
    }
    return SpeakResult(
      id: reading.id, repeatIndex: repeatIndex, firstAudioMs: firstAudioMs,
      gapCount: fast ? nil : player.gaps, gapMs: fast ? nil : player.gapSeconds * 1000,
      synthesisSeconds: seconds(synthesis), audioSeconds: audioSeconds,
      realTimeFactor: audioSeconds > 0 ? seconds(synthesis) / audioSeconds : nil,
      chunks: chunks, largestChunkMs: sampleRate.map { Double(largest) * 1000 / Double($0) },
      sampleRate: sampleRate, pause: pause, violations: check.violations, error: error)
  }

  /// Plays the passage at the paced pace until about 2 s of audio were pulled, then pulls on
  /// without pacing until a `next()` waits on the model, cancels it there and times how long it
  /// takes to end. A stream that keeps audio ready, as a local one does, would otherwise answer at
  /// once and leave nothing pending. A stream that ends or throws first was not pending.
  func cancellationTrial(on reading: Reading, repeatIndex: Int) async -> CancellationTrial {
    let request = request(for: reading)
    let clock = ContinuousClock()
    let start = clock.now
    let stream = provider.voice.speak(request)
    defer { stream.cancel() }
    var check = SpeechContractCheck()
    var player = PlayerModel()
    var pulledSeconds = 0.0
    var pending = false
    var latency: Double?

    pulling: while true {
      let draining = pulledSeconds >= 2
      let pull = Task { () -> (endedAt: ContinuousClock.Instant, result: Result<SpeechAudio?, any Error>) in
        do { return (clock.now, .success(try await stream.next())) } catch { return (clock.now, .failure(error)) }
      }
      // Still waiting after 50 ms means it waits on the model: cancel there.
      if draining, await value(of: pull, within: .milliseconds(50)) == nil {
        let cancelledAt = clock.now
        stream.cancel()
        let ended = await value(of: pull, within: .seconds(SpeechContractCheck.maximumCancelSeconds))?.endedAt
        pending = ended.map { $0 >= cancelledAt } ?? true
        latency = pending ? ended.map { ($0 - cancelledAt) / .milliseconds(1) } : nil
        break
      }
      switch await pull.value.result {
      case .failure(let thrown):
        check.threw(thrown)
        break pulling
      case .success(nil):
        break pulling
      case .success(let chunk?):
        check.observe(chunk)
        let chunkSeconds = Double(chunk.samples.count) / Double(chunk.sampleRate)
        pulledSeconds += chunkSeconds
        guard !draining else { continue }
        let scheduledAt = player.schedule(seconds: chunkSeconds, pulledAt: (clock.now - start) / .seconds(1))
        try? await clock.sleep(until: start + .seconds(scheduledAt))
      }
    }

    check.cancellationTook(seconds: pending ? latency.map { $0 / 1000 } : 0)
    return CancellationTrial(
      id: reading.id, repeatIndex: repeatIndex, audioSeconds: pulledSeconds, pending: pending,
      latencyMs: latency, violations: check.violations)
  }
}

/// The task's value, or nil if it has not finished within `limit`. The task keeps running.
private func value<T: Sendable>(of task: Task<T, Never>, within limit: Duration) async -> T? {
  let (first, signal) = AsyncStream.makeStream(of: T?.self)
  let waiter = Task { signal.yield(await task.value) }
  let timer = Task {
    try? await Task.sleep(for: limit)
    signal.yield(nil)
  }
  defer {
    waiter.cancel()
    timer.cancel()
  }
  return await first.first { _ in true } ?? nil
}

// MARK: Records

/// One reading's record: one JSONL line.
struct SpeakResult: Codable, RepeatedResult {
  /// A pause partway through, for passages tagged `pause-resume` in a paced run.
  struct Pause: Codable {
    let pausedAt: Date
    let resumedAt: Date
    /// Audio that came back without waiting in the first second after resuming, which the stream
    /// generated while the player was paused.
    var audioAfterResumeSeconds: Double
  }

  let id: String
  let repeatIndex: Int?
  /// From the request to the first chunk, which is when the modelled player starts.
  let firstAudioMs: Double?
  /// Times the player's queue ran dry before the end, and for how long in all. Nil in fast runs.
  let gapCount: Int?
  let gapMs: Double?
  /// Time spent inside `next()`. In a paced run the stream may have worked ahead meanwhile, so
  /// only a fast run measures synthesis speed.
  let synthesisSeconds: Double
  let audioSeconds: Double
  let realTimeFactor: Double?
  let chunks: Int
  let largestChunkMs: Double?
  let sampleRate: Int?
  let pause: Pause?
  let violations: [String]
  let error: String?
}

/// One pass's cancellation trial: one line of `cancellation.jsonl`.
struct CancellationTrial: Codable {
  let id: String
  let repeatIndex: Int
  /// Audio pulled before cancelling.
  let audioSeconds: Double
  /// Whether `next()` was still waiting when `cancel()` was called.
  let pending: Bool
  /// From `cancel()` to the end of `next()`. Nil when `next()` had already ended, or never did.
  let latencyMs: Double?
  let violations: [String]
}

private func summaryLine(for result: SpeakResult) -> String {
  let outcome = result.error.map { "FAILED: \($0)" }
    ?? String(format: "%.1f s of audio, real-time factor %.2f", result.audioSeconds, result.realTimeFactor ?? 0)
  let first = result.firstAudioMs.map { "\(Int($0.rounded())) ms" } ?? "none"
  let gaps = result.gapCount.map { "  \($0) gaps" } ?? ""
  return "\(result.id): \(outcome)  first audio \(first)\(gaps)  \(result.violations.count) violations"
}
