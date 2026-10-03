@testable import EchoTypeCore
import Foundation
import Speech
import Testing

/// Real `SpeechTranscriber` sessions, including recorded speech through `SessionMachine`.
/// Skipped unless
/// `ECHOTYPE_APPLE_LIVE=1`, so an ordinary run touches no Apple framework or speech assets:
///
/// ```bash
/// ECHOTYPE_APPLE_LIVE=1 ECHOTYPE_FIXTURE_WAV=/path/to/recording.wav \
///   swift test --disable-xctest --filter Apple
/// ```
///
/// The recording check wants a 16-bit PCM WAV of speech with pauses of a few seconds. A missing
/// speech model for English is installed first. This makes the synthetic fixture, whose path
/// turns on the pause and tail checks; it spells EchoType, Zustand and TanStack wrong even
/// with them as keyterms:
///
/// ```bash
/// dir=/tmp/echotype-s1-synthetic; mkdir -p $dir
/// say -o $dir/first.aiff 'EchoType lets me dictate notes. I use Zustand and TanStack in my projects.'
/// say -o $dir/last.aiff 'The final words must survive when I stop recording.'
/// for name in first last; do afconvert -f WAVE -d LEI16 -r 16000 $dir/$name.aiff $dir/$name.wav; done
/// python3 -c "import wave
/// out = wave.open('$dir/recording.wav', 'wb'); out.setparams((1, 2, 16000, 0, 'NONE', ''))
/// for name in ['first', 'last']:
///   src = wave.open(f'$dir/{name}.wav'); out.writeframes(src.readframes(src.getnframes()))
///   out.writeframes(bytes(3 * 16000 * 2))"
/// ```
@Suite(
  .serialized,
  .enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_LIVE"] == "1", "Set ECHOTYPE_APPLE_LIVE=1."))
struct AppleTranscriptionLiveTests {
  @Test("Speech assets for English become ready")
  func englishBecomesReady() async {
    let changes = Apple.changes.stream()
    var state = await Apple.speechAssets.check(language: "en")
    if state.status == .waiting {
      for await _ in changes {
        state = await Apple.speechAssets.check(language: "en")
        if state.status == .waiting { continue }
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

  @Test("With installed English assets, a transcriber is ready within five seconds", .timeLimit(.minutes(1)))
  func installedTranscriberStartsWithinFiveSeconds() async throws {
    let locale = try #require(await Apple.Transcriber.supportedLocale(for: "en"))
    try #require(await AssetInventory.status(forModules: [Apple.Transcriber.module(for: locale)]) == .installed,
      "This timing check requires installed English speech assets.")

    // Run this test alone to measure a fresh process, before another session warms the analyser.
    let started = ContinuousClock.now
    let transcriber = try await Apple.transcription.start(TranscriptionRequest(
      settings: Settings(language: "en"), provider: .apple, credential: nil))
    let seconds: Double?
    do {
      let ready = try await transcriber.events.first(where: { $0 == .ready })
      seconds = ready == nil ? nil : (ContinuousClock.now - started) / .seconds(1)
    } catch {
      await transcriber.waitForClose()
      throw error
    }
    await transcriber.waitForClose()
    let elapsed = try #require(seconds, "The transcriber ended before becoming ready.")
    print("Apple transcriber ready: \(elapsed) s")
    #expect(elapsed < 5, "\(elapsed) s")
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
      var states: [SessionMachine.State] = []
      for await snapshot in machine.snapshots {
        #expect(snapshot.transcript.committed.hasPrefix(committed))
        committed = snapshot.transcript.committed
        if states.last != snapshot.state { states.append(snapshot.state) }
      }
      return states
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
    let states = await observing.value
    transcriber.close()
    await transcriber.waitForClose()

    print("Apple transcription outcome: \(outcome)")
    guard case .insert(let text) = outcome else {
      Issue.record("The recording produced no insertable text: \(outcome)")
      return
    }
    // The synthetic fixture has three-second pauses and a tail that resolves only after finish.
    if path.contains("echotype-s1-synthetic") {
      #expect(text.lowercased().contains("when i stop recording"))
      let paused = try #require(states.firstIndex(of: .paused), "The recording should pause the session.")
      #expect(states.dropFirst(paused + 1).contains(.listening), "Speech after the pause should resume listening.")
    }
  }

  private func session(_ settings: Settings) async throws -> (SessionMachine, any LiveTranscriber) {
    let request = TranscriptionRequest(
      settings: settings, provider: .apple, credential: nil)
    let transcriber = try await Apple.transcription.start(request)
    return (SessionMachine(transcriber: transcriber, settings: settings, clock: SystemClock()), transcriber)
  }
}
