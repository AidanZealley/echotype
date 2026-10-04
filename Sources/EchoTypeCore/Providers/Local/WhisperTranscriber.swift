import Foundation
import Synchronization

/// One dictation on the shared Whisper models, translated into neutral events:
///
/// - `.ready` once the session is open.
/// - `.speech` for each voice activity chunk above the model's threshold.
/// - `.transcript` whenever the committed or provisional text changes. Whatever is not committed
///   is provisional.
/// - Text is committed once settled: when two decodes in a row agree on it, when a pause follows
///   it, or when the audio reaches the 28 s bound.
/// - `finish()` decodes the remaining audio, commits it, sends a last `.transcript` if it changed,
///   then `.finished`.
///
/// Whisper decodes windows of audio rather than streaming. The unsettled audio is decoded again
/// each second of new audio, and what has been committed is dropped from it, so each decode stays
/// bounded however long the dictation runs. Audio is decoded only after the voice activity model
/// has heard speech in it, because Whisper writes text for silence.
///
/// `send` queues audio and returns at once; a worker runs inference off the caller's executor. A
/// decode can take longer than its cadence, so the worker combines queued audio rather than
/// decoding every piece separately.
final class WhisperTranscriber: LiveTranscriber {
  let events: AsyncThrowingStream<TranscriptionEvent, any Error>
  private let output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  private let inbox = Inbox()
  /// Yields when `inbox` has audio, and finishes when there will be no more.
  private let wake: AsyncStream<Void>.Continuation
  private let worker: Task<Void, Never>

  init(model: WhisperModel, language: String, prompt: [Int]) {
    let (events, output) = AsyncThrowingStream<TranscriptionEvent, any Error>.makeStream()
    let (wakes, wake) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
    let pipeline = Pipeline(model: model, language: language, prompt: prompt)
    self.events = events
    self.output = output
    self.wake = wake
    let inbox = inbox
    worker = Task { await Self.run(pipeline, taking: inbox, wakes: wakes, into: output) }
  }

  func send(audio data: Data) async throws {
    inbox.put(data)
    wake.yield()
  }

  /// Ends the input. The worker drains what it holds, commits the tail and finishes the events.
  func finish() async throws {
    wake.finish()
  }

  func close() {
    worker.cancel()
    wake.finish()
    output.finish()
  }

  func waitForClose() async {
    close()
    await worker.value
  }

  private static func run(
    _ pipeline: Pipeline, taking inbox: Inbox, wakes: AsyncStream<Void>,
    into output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  ) async {
    var pipeline = pipeline
    func take() -> [Float] {
      ParakeetTranscriber.samples(from: inbox.take())
    }
    do {
      output.yield(.ready)
      for await _ in wakes {
        try Task.checkCancellation()
        for event in try await pipeline.hear(take()) { output.yield(event) }
      }
      try Task.checkCancellation()
      for event in try await pipeline.hear(take()) { output.yield(event) }
      for event in try await pipeline.finish() { output.yield(event) }
      output.yield(.finished)
      output.finish()
    } catch is CancellationError {
      output.finish()
    } catch {
      output.finish(throwing: error as? ProviderError ?? ProviderError.failed(error.localizedDescription))
    }
  }

  /// Audio sent and not yet taken by the worker.
  private final class Inbox: Sendable {
    private let audio = Mutex(Data())

    func put(_ data: Data) {
      audio.withLock { $0 += data }
    }

    func take() -> Data {
      audio.withLock { held in
        defer { held = Data() }
        return held
      }
    }
  }

  // MARK: Pipeline

  /// The session's state, driven by the worker alone.
  private struct Pipeline {
    private static let rate = WhisperModel.sampleRate
    /// New audio that triggers a decode. Incoming audio accumulates during inference, so this
    /// cadence does not queue separate decodes for every second that passes.
    private static let intervalSamples = Self.rate
    /// Flush at 28 s, leaving room for one VAD chunk below Whisper's fixed 30 s window.
    /// The adapter commits that decode and starts a fresh window, even if it returned no text.
    private static let windowSamples = 28 * Self.rate
    /// Audio kept while nothing has been heard, so a word's onset is in the next decode: the
    /// voice activity model answers a chunk after it ends.
    private static let prerollSamples = Self.rate

    let model: WhisperModel
    let language: String
    let prompt: [Int]

    private var voice: WhisperVoiceWatcher
    private var transcript = WhisperTranscript()
    private var announced = Transcript()
    /// The audio behind the pending segments, and whatever follows.
    private var audio: [Float] = []
    /// Samples received since the last decode.
    private var undecoded = 0
    /// Whether `audio` holds speech the voice activity model heard.
    private var heardSpeech = false

    init(model: WhisperModel, language: String, prompt: [Int]) {
      self.model = model
      self.language = language
      self.prompt = prompt
      voice = WhisperVoiceWatcher(model.voice)
    }

    mutating func hear(_ samples: [Float]) async throws -> [TranscriptionEvent] {
      guard !samples.isEmpty else { return [] }
      var speech = false
      var ended = false
      // Process queued audio in VAD-sized chunks. A fast producer or a slow decode must not
      // collapse several utterances into one VAD result or bypass the window bound.
      for offset in stride(from: 0, to: samples.count, by: 4096) {
        try Task.checkCancellation()
        let chunk = Array(samples[offset..<min(offset + 4096, samples.count)])
        audio += chunk
        undecoded += chunk.count
        let heard = try await voice.hear(chunk)
        speech = speech || heard.speech
        heardSpeech = heardSpeech || heard.speech
        if heard.speech { ended = false }
        if heard.ended { ended = true }

        if !heardSpeech {
          keepPreroll()
        } else if audio.count >= Self.windowSamples {
          try await decode(.all)
          heardSpeech = false
          ended = false
        }
      }
      // Historical pauses in a queued batch need no separate decode. Settle at a pause only
      // if no later speech follows it; the window bound still applies throughout the batch.
      if heardSpeech && ended {
        try await decode(.all)
        heardSpeech = false
      } else if heardSpeech && undecoded >= Self.intervalSamples {
        try await decode(.agreed)
      }
      return events(speech: speech)
    }

    /// Decodes and commits what remains.
    mutating func finish() async throws -> [TranscriptionEvent] {
      // Let the VAD inspect a final partial chunk too. Padding is silence, never speech evidence.
      let tail = try await voice.finish()
      if heardSpeech || tail { try await decode(.all) }
      return events(speech: tail)
    }

    private mutating func decode(_ settle: WhisperTranscript.Settle) async throws {
      try Task.checkCancellation()
      let segments = try await model.decode(audio, language: language, prompt: prompt)
      try Task.checkCancellation()
      undecoded = 0
      let settledSeconds = transcript.update(with: segments, settle: settle)
      if settle == .all {
        audio.removeAll(keepingCapacity: true)
      } else if let settledSeconds {
        audio.removeFirst(min(Int(settledSeconds * Double(Self.rate)), audio.count))
      }
    }

    private mutating func keepPreroll() {
      audio.removeFirst(max(0, audio.count - Self.prerollSamples))
      undecoded = 0
    }

    /// `.speech` if heard, then the transcript if it changed.
    private mutating func events(speech: Bool) -> [TranscriptionEvent] {
      var events: [TranscriptionEvent] = speech ? [.speech] : []
      let current = transcript.transcript
      if current != announced {
        announced = current
        events.append(.transcript(current))
      }
      return events
    }
  }
}
