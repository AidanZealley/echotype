import AVFoundation
import FluidAudio
import Foundation

/// One dictation on the shared Parakeet models, translated into neutral events:
///
/// - `.ready` once the shared recogniser is reset for this session.
/// - `.speech` for each voice activity chunk above the model's threshold.
/// - `.transcript` whenever the committed or provisional text changes. Every uncommitted token
///   is provisional: keyterm rescoring may still rewrite it.
/// - Without boosting, an utterance's text is committed when the voice activity model ends it.
/// - With boosting, text is committed only once rescored: after 15 s of audio, or at `finish()`.
/// - `finish()` drains the recogniser, commits the tail, sends a last `.transcript` if it changed,
///   then `.finished`.
///
/// Unified's streaming manager has no end-of-utterance signal, so `VadManager` supplies utterance
/// boundaries and speech evidence. The manager's own boosting cannot say which text it has
/// released, so with boosting this rescores in the same segments, with the same
/// `VocabularyBoostingSession`, and commits exactly what it has rescored.
///
/// `send` queues audio and returns at once; a worker runs inference off the caller's executor.
final class ParakeetTranscriber: LiveTranscriber {
  let events: AsyncThrowingStream<TranscriptionEvent, any Error>
  private let output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  private let audio: AsyncStream<Data>.Continuation
  private let worker: Task<Void, Never>

  init(model: ParakeetModel, boosting: VocabularyBoostingSession?) {
    let (events, output) = AsyncThrowingStream<TranscriptionEvent, any Error>.makeStream()
    let (input, audio) = AsyncStream.makeStream(of: Data.self)
    let pipeline = Pipeline(asr: model.asr, vad: model.vad, boosting: boosting)
    self.events = events
    self.output = output
    self.audio = audio
    worker = Task { await Self.run(pipeline, hearing: input, into: output) }
  }

  func send(audio data: Data) async throws {
    audio.yield(data)
  }

  /// Ends the input. The worker drains what it holds, commits the tail and finishes the events.
  func finish() async throws {
    audio.finish()
  }

  func close() {
    worker.cancel()
    audio.finish()
    output.finish()
  }

  func waitForClose() async {
    close()
    await worker.value
  }

  private static func run(
    _ pipeline: Pipeline, hearing input: AsyncStream<Data>,
    into output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  ) async {
    var pipeline = pipeline
    do {
      try await pipeline.asr.reset()
      output.yield(.ready)
      for await data in input {
        try Task.checkCancellation()
        for event in try await pipeline.hear(Self.samples(from: data)) { output.yield(event) }
      }
      try Task.checkCancellation()
      for event in try await pipeline.finish() { output.yield(event) }
      output.yield(.finished)
      output.finish()
    } catch is CancellationError {
      output.finish()
    } catch {
      output.finish(throwing: error as? ProviderError ?? ProviderError.failed(error.localizedDescription))
    }
  }

  // MARK: Audio

  /// 16 kHz mono little-endian Int16 PCM, as capture produces it, as Float32 in -1...1. A trailing
  /// odd byte is dropped.
  static func samples(from pcm: Data) -> [Float] {
    pcm.withUnsafeBytes { bytes in
      (0..<bytes.count / 2).map { index in
        Float(Int16(littleEndian: bytes.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))) / 32768
      }
    }
  }

  /// The recogniser's input: the same samples as a mono Float32 buffer, which it takes as is.
  static func buffer(of samples: [Float]) throws -> AVAudioPCMBuffer {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32, sampleRate: Double(ParakeetModel.sampleRate), channels: 1,
      interleaved: false)
    guard let format,
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
      let channel = buffer.floatChannelData?[0]
    else { throw ProviderError.failed("Could not allocate audio for transcription") }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    channel.update(from: samples, count: samples.count)
    return buffer
  }

  // MARK: Pipeline

  /// The session's state, driven by the worker alone.
  private struct Pipeline {
    /// Un-rescored audio that triggers a segment rescore, as in FluidAudio's own boosting.
    private static let segmentSamples = 15 * ParakeetModel.sampleRate
    /// Audio kept before the first pending token, so the spotter hears the word's onset.
    private static let prerollSamples = ParakeetModel.sampleRate
    /// Audio kept while nothing is pending: tokens arrive up to about a second after their audio.
    private static let idleSamples = 3 * ParakeetModel.sampleRate

    let asr: StreamingUnifiedAsrManager
    let vad: VadManager
    let boosting: VocabularyBoostingSession?

    private var transcript = ParakeetTranscript()
    private var announced = Transcript()
    private var voiceState = VadStreamState.initial()
    /// Samples the voice activity model has not seen, which takes 4096 at a time.
    private var voiceBacklog: [Float] = []
    /// The audio behind the pending tokens, kept only for rescoring. `audio[0]` is the sample at
    /// `audioStart` since the session began.
    private var audio: [Float] = []
    private var audioStart = 0

    init(asr: StreamingUnifiedAsrManager, vad: VadManager, boosting: VocabularyBoostingSession?) {
      self.asr = asr
      self.vad = vad
      self.boosting = boosting
    }

    mutating func hear(_ samples: [Float]) async throws -> [TranscriptionEvent] {
      guard !samples.isEmpty else { return [] }
      try await asr.appendAudio(ParakeetTranscriber.buffer(of: samples))
      try await asr.processBufferedAudio()
      transcript.append(await asr.consumeTokenTimings())

      let voice = try await watchVoice(samples)
      if boosting == nil {
        if voice.ended { transcript.commit(first: transcript.pending.count) }
      } else {
        audio += samples
        if audio.count >= Self.segmentSamples { await rescore(upTo: transcript.settledCount) }
        trimAudio()
      }
      return events(speech: voice.speech)
    }

    /// Drains the audio the recogniser holds back, and commits the tail: rescored first when
    /// boosting.
    mutating func finish() async throws -> [TranscriptionEvent] {
      _ = try await asr.finish()
      try Task.checkCancellation()
      transcript.append(await asr.consumeTokenTimings())
      if boosting == nil {
        transcript.commit(first: transcript.pending.count)
      } else {
        await rescore(upTo: transcript.pending.count)
      }
      return events(speech: false)
    }

    private mutating func watchVoice(_ samples: [Float]) async throws -> (speech: Bool, ended: Bool) {
      voiceBacklog += samples
      let threshold = await vad.config.defaultThreshold
      var speech = false
      var ended = false
      while voiceBacklog.count >= VadManager.chunkSize {
        let chunk = Array(voiceBacklog.prefix(VadManager.chunkSize))
        voiceBacklog.removeFirst(VadManager.chunkSize)
        let result = try await vad.processStreamingChunk(chunk, state: voiceState)
        voiceState = result.state
        speech = speech || result.probability >= threshold
        ended = ended || result.event?.isEnd == true
      }
      return (speech, ended)
    }

    /// Rescores the first `count` pending tokens against the audio behind them and commits the
    /// result. Without a detected keyterm the words are committed as decoded.
    private mutating func rescore(upTo count: Int?) async {
      guard let boosting, let count, count > 0 else { return }
      let run = transcript.pending.prefix(count)
      let origin = Double(audioStart) / Double(ParakeetModel.sampleRate)
      let local = run.map {
        TokenTiming(
          token: $0.token, tokenId: $0.tokenId, startTime: $0.startTime - origin,
          endTime: max(0, $0.endTime - origin), confidence: $0.confidence)
      }
      let rescored = await boosting.rescore(
        text: run.map(\.token).joined(), tokenTimings: local, audioSamples: audio)
      transcript.commit(first: count, as: rescored?.text)
    }

    private mutating func trimAudio() {
      let keepFrom =
        transcript.pending.first.map { Int($0.startTime * Double(ParakeetModel.sampleRate)) - Self.prerollSamples }
        ?? audioStart + audio.count - Self.idleSamples
      let drop = min(max(keepFrom - audioStart, 0), audio.count)
      audio.removeFirst(drop)
      audioStart += drop
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
