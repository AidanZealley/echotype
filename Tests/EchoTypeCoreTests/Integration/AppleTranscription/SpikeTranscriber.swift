@testable import EchoTypeCore
import AVFoundation
import CoreMedia
import Foundation
import Speech

/// Deliberately test-only. Final segments append; volatile segments replace the provisional
/// tail. No settled utterance is inferred until the recording establishes that distinction.
actor AppleSpikeTranscriber: LiveTranscriber {
  nonisolated let events: AsyncThrowingStream<TranscriptionEvent, any Error>
  private let output: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  private let input: AsyncStream<AnalyzerInput>
  private let audio: AsyncStream<AnalyzerInput>.Continuation
  private let finishing: AsyncStream<Void>
  private let finishSignal: AsyncStream<Void>.Continuation
  private let transcriber: SpeechTranscriber
  private let detector: SpeechDetector
  private let analyzer: SpeechAnalyzer
  private let context: AnalysisContext
  private var worker: Task<Void, Never>?
  private var closed = false
  private var didFinish = false
  private var frames: Int64 = 0
  private var committed = ""
  private let started = ProcessInfo.processInfo.systemUptime
  private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
    channels: 1, interleaved: false)!

  init(locale: Locale, terms: [String]) {
    (events, output) = AsyncThrowingStream.makeStream()
    (input, audio) = AsyncStream.makeStream()
    (finishing, finishSignal) = AsyncStream.makeStream()
    transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    detector = SpeechDetector(detectionOptions: .init(sensitivityLevel: .medium), reportResults: true)
    context = AnalysisContext()
    context.contextualStrings[.general] = terms
    analyzer = SpeechAnalyzer(modules: [transcriber, detector])
  }

  func launch() { worker = Task { await self.run() } }

  private func note(_ text: String) {
    print(String(format: "Apple +%.3fs ", ProcessInfo.processInfo.systemUptime - started) + text)
  }

  private func run() async {
    let reading = Task {
      for try await result in transcriber.results { self.record(result) }
    }
    let detecting = Task {
      for try await result in detector.results {
        self.note("detector speech=\(result.speechDetected) final=\(result.isFinal) range=\(result.range)")
        if result.speechDetected { output.yield(.speech) }
      }
    }
    do {
      note("prepare start; assets=\(await AssetInventory.status(forModules: [transcriber, detector]))")
      try await analyzer.setContext(context)
      try await analyzer.prepareToAnalyze(in: format)
      try Task.checkCancellation()
      note("ready; input=16kHz mono Int16; context count=\(await analyzer.context.contextualStrings[.general]?.count ?? 0)")
      output.yield(.ready)
      try await analyzer.start(inputSequence: input)
      for await _ in finishing { break }
      try Task.checkCancellation()
      note("finalize start")
      try await analyzer.finalizeAndFinishThroughEndOfInput()
      try await reading.value
      try await detecting.value
      note("finished; committed=\(committed.debugDescription)")
      output.yield(.finished)
      output.finish()
    } catch {
      note("failure: \(error)")
      await analyzer.cancelAndFinishNow()
      reading.cancel()
      detecting.cancel()
      _ = try? await reading.value
      _ = try? await detecting.value
      output.finish(throwing: error is CancellationError ? error : ProviderError.failed(String(describing: error)))
    }
  }

  private func record(_ result: SpeechTranscriber.Result) {
    let text = String(result.text.characters)
    // The paired detector has emitted no results on this Mac. Nonempty recognition is
    // direct speech evidence, including before a segment becomes final.
    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { output.yield(.speech) }
    note("result final=\(result.isFinal) range=\(result.range) text=\(text.debugDescription)")
    if result.isFinal {
      committed += text
      output.yield(.transcript(Transcript(committed: committed)))
    } else {
      output.yield(.transcript(Transcript(committed: committed, provisional: text)))
    }
  }

  func send(audio data: Data) async throws {
    guard !closed, !didFinish else { throw CancellationError() }
    let count = data.count / 2
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
      let samples = buffer.int16ChannelData?[0] else { throw ProviderError.failed("Cannot allocate input") }
    buffer.frameLength = AVAudioFrameCount(count)
    data.copyBytes(to: UnsafeMutableRawBufferPointer(start: samples, count: count * 2))
    audio.yield(AnalyzerInput(buffer: buffer, bufferStartTime: CMTime(value: frames, timescale: 16_000)))
    frames += Int64(count)
  }

  func finish() async throws {
    guard !didFinish, !closed else { return }
    didFinish = true
    note("finish requested at \(Double(frames) / 16_000)s audio")
    audio.finish()
    finishSignal.yield(())
    finishSignal.finish()
  }

  nonisolated func close() { Task { await self.shutdown() } }

  private func shutdown() async {
    guard !closed else { return }
    closed = true
    audio.finish()
    finishSignal.finish()
    worker?.cancel()
    await analyzer.cancelAndFinishNow()
    output.finish()
  }

  func waitForClose() async {
    await shutdown()
    await worker?.value
  }
}
