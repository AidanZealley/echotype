@testable import EchoTypeCore
import Foundation
import Testing

/// Real `SpeechTranscriber` sessions through `SessionMachine`. Skipped unless
/// `ECHOTYPE_APPLE_LIVE=1`, so an ordinary run touches no Apple framework or speech assets:
///
/// ```bash
/// ECHOTYPE_APPLE_LIVE=1 ECHOTYPE_FIXTURE_WAV=/path/to/recording.wav \
///   swift test --disable-xctest --filter Apple
/// ```
///
/// The recording check wants a 16-bit PCM WAV of speech with pauses of a few seconds, such as
/// the research's synthetic fixture. A missing speech model for English is installed first.
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_LIVE"] == "1", "Set ECHOTYPE_APPLE_LIVE=1."))
struct AppleTranscriptionLiveTests {
  @Test("Speech assets for English become ready")
  func englishBecomesReady() async {
    let changes = Apple.changes.stream()
    var state = await Apple.speechAssets.check(language: "en")
    if case .waiting = state {
      for await _ in changes {
        state = await Apple.speechAssets.check(language: "en")
        if case .waiting = state { continue }
        break
      }
    }
    #expect(state == .ready)
  }

  @Test("The registered provider is ready for English with its default voice")
  func providerIsReady() async throws {
    let readiness = Provider.apple.readiness
    let request = ReadinessRequest(settings: Settings(provider: Provider.apple.id), provider: .apple)
    #expect(await readiness.check(request) == ServiceReadiness(transcription: .ready, voice: .ready, cleanup: .ready))
  }

  @Test("Finishing before ready, or after only silence, ends with nothing")
  func earlyFinishAndSilenceEndEmpty() async throws {
    for silence in [0, 30] {
      let (machine, transcriber) = try await session(Settings(language: "en"))
      let running = Task { await machine.run() }
      // Gives `run` its first turn, so the finish lands while the analyser is still preparing.
      try await Task.sleep(for: .milliseconds(10))
      for _ in 0..<silence {
        try await machine.send(audio: Data(repeating: 0, count: 3200))
        try await Task.sleep(for: .milliseconds(100))
      }
      await machine.beginFinishing()
      await machine.sendClosing()
      let outcome = await running.value
      transcriber.close()
      transcriber.close()
      await transcriber.waitForClose()
      #expect(outcome == .nothing, "after \(silence) chunks of silence")
    }
  }

  @Test(
    "A recording transcribes with its complete tail",
    .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_FIXTURE_WAV"] != nil, "Set ECHOTYPE_FIXTURE_WAV."))
  func recordingTranscribes() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["ECHOTYPE_FIXTURE_WAV"])
    let recording = try WAVRecording(contentsOf: URL(fileURLWithPath: path))
    var settings = Settings(language: "en")
    settings.keyterms = ["Zustand", "TanStack"]
    settings.silenceTimeout = 2
    let (machine, transcriber) = try await session(settings)
    let running = Task { await machine.run() }
    let observing = Task {
      var committed = ""
      for await snapshot in machine.snapshots {
        #expect(snapshot.transcript.committed.hasPrefix(committed))
        committed = snapshot.transcript.committed
      }
    }

    var converter = AudioConverter(inputSampleRate: recording.sampleRate, channelCount: recording.channelCount)
    let started = ProcessInfo.processInfo.systemUptime
    for (index, chunk) in recording.chunks(ofSeconds: 0.1).enumerated() {
      try await machine.send(audio: converter.convert(chunk))
      let delay = started + Double(index + 1) * 0.1 - ProcessInfo.processInfo.systemUptime
      if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
    }
    await machine.beginFinishing()
    await machine.sendClosing()
    let outcome = await running.value
    await observing.value
    transcriber.close()
    await transcriber.waitForClose()

    print("Apple transcription outcome: \(outcome)")
    guard case .insert(let text) = outcome else {
      Issue.record("The recording produced no insertable text: \(outcome)")
      return
    }
    // The research fixture ends with this sentence, which resolves only after finish.
    if path.contains("echotype-s1-synthetic") { #expect(text.lowercased().contains("when i stop recording")) }
  }

  private func session(_ settings: Settings) async throws -> (SessionMachine, any LiveTranscriber) {
    let request = TranscriptionRequest(
      settings: settings, provider: .apple, credential: nil)
    let transcriber = try await Apple.transcription.start(request)
    return (SessionMachine(transcriber: transcriber, settings: settings, clock: SystemClock()), transcriber)
  }
}
