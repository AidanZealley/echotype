@testable import EchoTypeCore
import AVFoundation
import Foundation
import FoundationModels
import Speech
import Testing

private let appleSpikeEnabled = ProcessInfo.processInfo.environment["ECHOTYPE_APPLE_SPIKE"] == "1"

@Suite(.serialized, .enabled(if: appleSpikeEnabled, "Set ECHOTYPE_APPLE_SPIKE=1; no Apple service starts otherwise."))
struct AppleTranscriptionSpike {
  @Test func inventoryAppleTranscriptionSpike() async throws {
    print("OS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Apple Intelligence model availability: \(SystemLanguageModel.default.availability)")
    print("hardware availability: \(SpeechTranscriber.isAvailable)")
    print("supported: \(await SpeechTranscriber.supportedLocales.map(\.identifier).sorted())")
    print("installed: \(await SpeechTranscriber.installedLocales.map(\.identifier).sorted())")
    print("reserved: \(await AssetInventory.reservedLocales.map(\.identifier).sorted())")
    print("Speech authorization before any request: \(SFSpeechRecognizer.authorizationStatus().rawValue)")
    for tag in ["en", "en-GB", "en-US", "fr", "de", "ja", "zh-Hant", "xx-ZZ"] {
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: tag))
      print("locale \(tag): \(locale?.identifier ?? "unsupported")")
    }
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en")) else { return }
    let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    print("default assets: \(await AssetInventory.status(forModules: [module]))")
    print("compatible formats: \(await module.availableCompatibleAudioFormats)")
    for tag in ["en-GB", "fr-FR"] {
      let module = SpeechTranscriber(locale: Locale(identifier: tag), preset: .progressiveTranscription)
      let status = await AssetInventory.status(forModules: [module])
      let request = try await AssetInventory.assetInstallationRequest(supporting: [module])
      print("setup \(tag): status=\(status); installation request=\(request == nil ? "none" : "available"); no download started")
    }
  }
  @Test func lifecycleAppleTranscriptionSpike() async throws {
    let locale = try #require(await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en")))
    for mode in ["immediate finish", "cancel loading", "silence", "warm silence"] {
      print("CASE \(mode)")
      let start = ProcessInfo.processInfo.systemUptime
      let adapter = AppleSpikeTranscriber(locale: locale, terms: ["EchoType", "Zustand"])
      await adapter.launch()
      defer { adapter.close() }
      print("start returned after \(ProcessInfo.processInfo.systemUptime - start)s")
      let machine = SessionMachine(transcriber: adapter, settings: Settings(), clock: SystemClock())
      let run = Task { await machine.run() }
      let observe = Task {
        for await snapshot in machine.snapshots { print("snapshot \(snapshot)") }
      }
      // Give run its initial turn, then exercise stop while preparation is still pending.
      try await Task.sleep(for: .milliseconds(10))
      if mode == "cancel loading" {
        await machine.cancel()
      } else {
        if mode.contains("silence") {
          for _ in 0..<30 {
            try await machine.send(audio: Data(repeating: 0, count: 3200))
            try await Task.sleep(for: .milliseconds(100))
          }
        }
        await machine.beginFinishing()
        await machine.sendClosing()
      }
      let outcome = await run.value
      await observe.value
      adapter.close()
      adapter.close()
      await adapter.waitForClose()
      print("outcome \(outcome); total \(ProcessInfo.processInfo.systemUptime - start)s; speech authorization=\(SFSpeechRecognizer.authorizationStatus().rawValue)")
      if mode.contains("silence") {
        // RecogRejected on all-zero PCM is observed framework behavior, kept visible.
        if case .failed(let text, _) = outcome { #expect(text.isEmpty) }
        else { #expect(outcome == .nothing) }
      } else { #expect(outcome == .nothing) }
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_FIXTURE_WAV"] != nil,
    "Supply a local 16-bit PCM WAV with two pauses of at least three seconds."))
  func recordingAppleTranscriptionSpike() async throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try #require(environment["ECHOTYPE_FIXTURE_WAV"])
    let recording = try WAVRecording(contentsOf: URL(fileURLWithPath: path))
    let language = environment["ECHOTYPE_SPIKE_LANGUAGE"] ?? "en-GB"
    let locale = try #require(await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)))
    print("recording \(recording.summary); requested \(language); resolved \(locale.identifier)")
    // Make the contextual list through the request constructor, as DictationOperation does.
    var settings = Settings(language: language)
    settings.keyterms = ["Zustand", "TanStack", "shadcn", "BCP-47"]
    if let seconds = environment["ECHOTYPE_SPIKE_SILENCE_TIMEOUT"].flatMap(Double.init) {
      settings.silenceTimeout = seconds
      print("spike silence timeout \(seconds)s")
    }
    let request = TranscriptionRequest(settings: settings, keytermLimit: 100, credential: nil)
    for terms in [[], request.keyterms] {
      print("CASE recording; contextual terms=\(terms)")
      let adapter = AppleSpikeTranscriber(locale: locale, terms: terms)
      await adapter.launch()
      defer { adapter.close() }
      let machine = SessionMachine(transcriber: adapter, settings: settings, clock: SystemClock())
      let running = Task { await machine.run() }
      let observing = Task {
        var previous = ""
        for await snapshot in machine.snapshots {
          #expect(snapshot.transcript.committed.hasPrefix(previous))
          previous = snapshot.transcript.committed
          print("snapshot \(snapshot)")
        }
      }
      try await Task.sleep(for: .milliseconds(10))
      var converter = AudioConverter(inputSampleRate: recording.sampleRate,
        channelCount: recording.channelCount)
      let started = ProcessInfo.processInfo.systemUptime
      for (index, chunk) in recording.chunks(ofSeconds: 0.1).enumerated() {
        try await machine.send(audio: converter.convert(chunk))
        let delay = started + Double(index + 1) * 0.1 - ProcessInfo.processInfo.systemUptime
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
      }
      let stopped = ProcessInfo.processInfo.systemUptime
      await machine.beginFinishing()
      await machine.sendClosing()
      let outcome = await running.value
      await observing.value
      adapter.close()
      await adapter.waitForClose()
      print("stop-to-outcome \(ProcessInfo.processInfo.systemUptime - stopped)s; outcome \(outcome)")
      if case .insert(let text) = outcome { #expect(!text.isEmpty) }
      else { Issue.record("Recording did not produce insertable text: \(outcome)") }
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_FIXTURE_WAV"] != nil,
    "Supply a local human PCM WAV to cancel during speech."))
  func recordingCancellationAppleTranscriptionSpike() async throws {
    let environment = ProcessInfo.processInfo.environment
    let path = try #require(environment["ECHOTYPE_FIXTURE_WAV"])
    let recording = try WAVRecording(contentsOf: URL(fileURLWithPath: path))
    let language = environment["ECHOTYPE_SPIKE_LANGUAGE"] ?? "en-GB"
    let locale = try #require(await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)))
    let adapter = AppleSpikeTranscriber(locale: locale, terms: ["EchoType"])
    await adapter.launch()
    defer { adapter.close() }
    let machine = SessionMachine(transcriber: adapter, settings: Settings(language: language), clock: SystemClock())
    let running = Task { await machine.run() }
    var converter = AudioConverter(inputSampleRate: recording.sampleRate, channelCount: recording.channelCount)
    let started = ProcessInfo.processInfo.systemUptime
    for (index, chunk) in recording.chunks(ofSeconds: 0.1).prefix(50).enumerated() {
      try await machine.send(audio: converter.convert(chunk))
      let delay = started + Double(index + 1) * 0.1 - ProcessInfo.processInfo.systemUptime
      if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
    }
    let cancelled = ProcessInfo.processInfo.systemUptime
    await machine.cancel()
    let outcome = await running.value
    adapter.close()
    adapter.close()
    await adapter.waitForClose()
    print("human cancel-to-join \(ProcessInfo.processInfo.systemUptime - cancelled)s; outcome \(outcome)")
    #expect(outcome == .nothing)
  }

  @Test func keytermsAppleTranscriptionSpike() async throws {
    let locale = try #require(await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB")))
    for count in [1, 100, 1000] {
      let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
      let analyzer = SpeechAnalyzer(modules: [module])
      let context = AnalysisContext()
      context.contextualStrings[.general] = ["EchoType"] + (1..<count).map { "SavedTerm\($0)" }
      do {
        try await analyzer.setContext(context)
        let received = await analyzer.context.contextualStrings[.general]?.count
        print("context supplied \(count); readback \(received ?? 0); recognition limit remains unmeasured")
        #expect(received == count)
      } catch {
        print("context supplied \(count) failed: \(error)")
        throw error
      }
      await analyzer.cancelAndFinishNow()
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["ECHOTYPE_SPIKE_INSTALL_LANGUAGE"] != nil,
    "Explicitly opt into an additional model download with ECHOTYPE_SPIKE_INSTALL_LANGUAGE."))
  func installationAppleTranscriptionSpike() async throws {
    let tag = try #require(ProcessInfo.processInfo.environment["ECHOTYPE_SPIKE_INSTALL_LANGUAGE"])
    let locale = try #require(await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: tag)))
    let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    print("installation requested for \(locale.identifier); existing assets will not be removed")
    guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
      print("already installed; download, cancellation and retry remain unmeasured")
      return
    }
    let started = ProcessInfo.processInfo.systemUptime
    let downloading = Task { try await request.downloadAndInstall() }
    try await Task.sleep(for: .milliseconds(100))
    let cancelled = ProcessInfo.processInfo.systemUptime
    downloading.cancel()
    do { try await downloading.value; print("installation completed despite task cancellation") }
    catch { print("installation cancellation error: \(error)") }
    print("download elapsed \(ProcessInfo.processInfo.systemUptime - started)s; cancel-to-join \(ProcessInfo.processInfo.systemUptime - cancelled)s")
    print("post-cancel status \(await AssetInventory.status(forModules: [module]))")
    if let retry = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
      let started = ProcessInfo.processInfo.systemUptime
      try await retry.downloadAndInstall()
      print("retry installed after \(ProcessInfo.processInfo.systemUptime - started)s")
    } else { print("retry request absent; first request installed the model") }
    print("final status \(await AssetInventory.status(forModules: [module]))")
  }

}
