import AVFoundation
import CoreMedia
import Foundation
import Speech

extension Apple {
  /// One `SpeechAnalyzer` session, translated into neutral events:
  ///
  /// | Speech                         | Event                                              |
  /// |--------------------------------|----------------------------------------------------|
  /// | `prepareToAnalyze` returns     | `.ready`                                           |
  /// | a result                       | `.transcript` from the assembler, plus `.speech`   |
  /// | analysis ends after `finish()` | `.finished`, after every result                    |
  /// | `RecogRejected` at finish      | `.finished` when nothing was recognised            |
  /// | any other error                | throws `ProviderError.failed` as it occurs         |
  ///
  /// `launch()` returns at once; a worker prepares the analyser and then runs it, while a reader
  /// turns results into events. The app's 16 kHz mono Int16 audio is one of the formats the
  /// transcriber accepts, so it is fed as is.
  actor Transcriber: LiveTranscriber {
    nonisolated let events: AsyncThrowingStream<TranscriptionEvent, any Error>
    private let output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
    private let input: AsyncStream<AnalyzerInput>
    private let audio: AsyncStream<AnalyzerInput>.Continuation
    /// Ends when `finish()` or `close()` is called, releasing the worker.
    private let finishing: AsyncStream<Void>
    private let finishSignal: AsyncStream<Void>.Continuation
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let context = AnalysisContext()
    private var assembler = TranscriptAssembler()
    private var worker: Task<Void, Never>?
    private var reader: Task<Void, Never>?
    private var finishRequested = false
    private var closed = false
    /// Samples handed over so far, which time-stamp the next buffer.
    private var frames: Int64 = 0

    static let format = AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false)!

    /// The module every session and asset query uses, so they ask about the same model.
    static func module(for locale: Locale) -> SpeechTranscriber {
      SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    }

    static func supportedLocale(for tag: String) async -> Locale? {
      await SpeechTranscriber.supportedLocale(equivalentTo: Apple.locale(for: tag))
    }

    init(locale: Locale, keyterms: [String]) {
      (events, output) = AsyncThrowingStream.makeStream()
      (input, audio) = AsyncStream.makeStream()
      (finishing, finishSignal) = AsyncStream.makeStream()
      transcriber = Self.module(for: locale)
      analyzer = SpeechAnalyzer(modules: [transcriber])
      context.contextualStrings[.general] = keyterms
    }

    func launch() {
      reader = Task { await read() }
      worker = Task { await run() }
    }

    private func run() async {
      do {
        try await analyzer.setContext(context)
        try await analyzer.prepareToAnalyze(in: Self.format)
        try Task.checkCancellation()
        output.yield(.ready)
        try await analyzer.start(inputSequence: input)
        for await _ in finishing {}
        try Task.checkCancellation()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        // Every result, including the resolved tail, is out before `.finished`.
        await reader?.value
        output.yield(.finished)
        output.finish()
      } catch {
        await fail(error)
      }
    }

    /// Analysis failures arrive here as soon as they happen, not only after `finish()`.
    private func read() async {
      do {
        for try await result in transcriber.results {
          for event in assembler.apply(text: String(result.text.characters), isFinal: result.isFinal) {
            output.yield(event)
          }
        }
      } catch {
        await fail(error)
      }
    }

    /// Ends `events` when either side fails, mapping the error with what is known at that
    /// moment, then stops the session. The stream ignores any later ending.
    private func fail(_ error: any Error) async {
      if let failure = assembler.ending(after: error, finishing: finishRequested) {
        output.finish(throwing: failure)
      } else {
        output.yield(.finished)
        output.finish()
      }
      await stop()
    }

    func send(audio data: Data) async throws {
      let count = data.count / 2
      guard let buffer = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: AVAudioFrameCount(count)),
        let samples = buffer.int16ChannelData?[0]
      else { throw ProviderError.failed("Could not allocate audio for transcription") }
      buffer.frameLength = AVAudioFrameCount(count)
      data.copyBytes(to: UnsafeMutableRawBufferPointer(start: samples, count: count * 2))
      audio.yield(AnalyzerInput(buffer: buffer, bufferStartTime: CMTime(value: frames, timescale: 16_000)))
      frames += Int64(count)
    }

    /// Ends the input, so analysis finalises everything it was given. Accepted before `.ready`,
    /// which then finishes with nothing recognised.
    func finish() async throws {
      guard !finishRequested, !closed else { return }
      finishRequested = true
      audio.finish()
      finishSignal.finish()
    }

    nonisolated func close() {
      Task { await shutdown() }
    }

    func waitForClose() async {
      await shutdown()
      await worker?.value
    }

    private func shutdown() async {
      guard !closed else { return }
      closed = true
      output.finish()
      await stop()
    }

    /// Ends the input, releases and cancels the worker and reader, and stops the analyser.
    private func stop() async {
      audio.finish()
      finishSignal.finish()
      worker?.cancel()
      reader?.cancel()
      await analyzer.cancelAndFinishNow()
    }
  }
}
