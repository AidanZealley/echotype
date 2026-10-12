import EchoTypeCore
@testable import EchoTypeApp
import Foundation
import Testing

private final class ProviderGate: Sendable {
  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation
  init() { (stream, continuation) = AsyncStream.makeStream() }
  func wait() async { for await _ in stream { break } }
  func open() { continuation.finish() }
}

private final class CompletedProviderTranscriber: LiveTranscriber {
  let events: AsyncThrowingStream<TranscriptionEvent, any Error>
  private let publisher: AsyncThrowingStream<TranscriptionEvent, any Error>.Continuation
  init() {
    (events, publisher) = AsyncThrowingStream.makeStream()
    publisher.yield(.ready)
    publisher.yield(.transcript(.init(committed: "Captured dictation")))
  }
  func send(audio: Data) async throws {}
  func finish() async throws { publisher.yield(.finished) }
  func close() { publisher.finish() }
  func waitForClose() async {}
}

private final class EmptyProviderSpeech: SpeechStream {
  func next() async throws -> SpeechAudio? { nil }
  func cancel() {}
}

@MainActor private final class FeatureProviderFixture {
  let store = SettingsStore(defaults: nil, providers: [])
  let entered = ProviderGate(), release = ProviderGate()
  var readingProviders: [ProviderID] = []
  var dictationProviders: [ProviderID] = []
  var readingSettings: [Settings] = []
  var dictationSettings: [Settings] = []
  var testFlags: [Bool] = []
  var succeeds = false
  var keys: [ProviderID: String] = [:]
  var operation: DictationOperation?
  var speechRequests: [SpeechRequest] = []
  var transcriptionRequests: [TranscriptionRequest] = []
  var captureStarts = 0
  var readinessChecks = 0
  var controller: DictationController!

  init() {
    let clipboard = Clipboard(access: .init(count: { 0 }, save: { [] }, restore: { _ in },
      read: { nil }, write: { _ in }, post: { _, _ in }, wait: { _ in }))
    controller = DictationController(store: store, clipboard: clipboard,
      makeReader: { source, id, settings, provider, present, _ in
        self.readingProviders.append(provider.id); self.readingSettings.append(settings)
        let captured = self.fake(provider)
        return Reader(source, id: id, settings: settings, dependencies: .init(
          selection: { _ in "Selection" }, cleanup: {}, provider: captured,
          key: { self.entered.open(); await self.release.wait(); return await MainActor.run { self.keys[provider.id] } },
          player: PlaybackFixture().player), onPresentation: present)
      }, focusedScreen: { nil }, showPanel: { _, _ in }, hidePanel: {}, key: { _ in nil },
      makeDictation: { isTest, settings, provider in
        self.dictationProviders.append(provider.id); self.dictationSettings.append(settings)
        self.testFlags.append(isTest)
        let operation = DictationOperation(settings: settings, isTest: isTest, dependencies: .init(
          startCapture: { _ in self.captureStarts += 1; return AsyncThrowingStream { $0.finish() } },
          stopCapture: {}, releaseCapture: {}, provider: self.fake(provider),
          key: { self.entered.open(); await self.release.wait(); return await MainActor.run { self.keys[provider.id] } },
          captureDestination: { nil },
          insert: { _, _, _, _, _ in .init(insertion: .notAttempted, sending: .notRequested) },
          clock: SystemClock(), testClock: SystemClock(), revisionClock: SystemClock()),
          onPresentation: { presentation, _, _ in
            if self.succeeds, case .capturing = presentation { self.operation?.commit() }
          })
        self.operation = operation
        return operation
      })
  }

  private func fake(_ provider: Provider) -> Provider {
    var captured = provider
    captured.name = "Captured \(provider.name)"
    captured.transcription = TranscriptionService(keytermLimit: 100) { request in
      await MainActor.run { self.transcriptionRequests.append(request) }
      if await MainActor.run(body: { self.succeeds }) { return CompletedProviderTranscriber() }
      throw ProviderError.unavailable
    }
    captured.voice = VoiceService(voices: provider.voice.voices, speedRange: provider.voice.speedRange,
      maximumCharacters: provider.voice.maximumCharacters) { request in
      MainActor.assumeIsolated { self.speechRequests.append(request) }
      return EmptyProviderSpeech()
    }
    captured.cleanup = nil
    captured.readiness = Readiness(check: { _ in
      await MainActor.run { self.readinessChecks += 1 }
      return ServiceReadiness(
        transcription: .ready, voice: .ready, cleanup: nil)
    }, changes: { AsyncStream { $0.finish() } })
    return captured
  }
}

@Suite(.timeLimit(.minutes(1))) @MainActor struct FeatureProviderTests {
  @Test("Each feature runs its own provider, settings snapshot and key",
    arguments: [(ProviderID(rawValue: "xai"), ProviderID(rawValue: "local")),
      (ProviderID(rawValue: "local"), ProviderID(rawValue: "xai"))])
  func featuresUseTheirOwnProviders(choices: (ProviderID, ProviderID)) async {
    let f = FeatureProviderFixture()
    f.succeeds = true; f.keys = ["xai": "xai-key"]
    f.store.settings = Settings(dictationProvider: choices.0, readAloudProvider: choices.1,
      keyterms: ["Captured"], reading: ["xai": .init(voice: "altair", speed: 1.2)])
    f.controller.hotkeyPressed()
    await f.entered.wait()
    f.store.settings.dictationProvider = "apple"
    f.store.settings.keyterms = ["Changed"]
    f.release.open()
    await f.controller.waitForCompletion()
    #expect(f.controller.lastError == nil)
    #expect(f.dictationProviders == [choices.0])
    #expect(f.transcriptionRequests.map(\.credential) == [f.keys[choices.0]])
    #expect(f.transcriptionRequests[0].keyterms.contains("Captured"))
    #expect(!f.transcriptionRequests[0].keyterms.contains("Changed"))

    #expect(f.controller.speak("MCP reply"))
    f.store.settings.readAloudProvider = "apple"
    await f.controller.waitForCompletion()
    #expect(f.controller.lastError == nil)
    #expect(f.readingProviders == [choices.1])
    #expect(f.speechRequests.map(\.text) == ["MCP reply"])
    #expect(f.speechRequests[0].credential == f.keys[choices.1])
    let expected = f.readingSettings[0].readingChoice(for: Providers[choices.1])
    #expect(f.speechRequests[0].voice == expected.voice)
    #expect(f.speechRequests[0].speed == expected.speed)
  }

  @Test func microphoneTestUsesDictationProviderAndCapturedError() async {
    let f = FeatureProviderFixture()
    f.store.settings = Settings(dictationProvider: "xai", readAloudProvider: "local")
    let task = Task { await f.controller.test() }
    await f.entered.wait()
    f.store.settings.dictationProvider = "apple"
    f.release.open()
    guard case .failed(let message) = await task.value else { Issue.record("Expected missing key"); return }
    #expect(message == "Add your Captured xAI API key in EchoType Settings")
    #expect(f.dictationProviders == ["xai"] && f.testFlags == [true])
    #expect(f.captureStarts == 0 && f.readingProviders.isEmpty)
  }

  @Test func hotkeyReadingUsesReadAloudProvider() async {
    let f = FeatureProviderFixture()
    f.store.settings = Settings(dictationProvider: "local", readAloudProvider: "xai")
    f.controller.readAloudPressed()
    await f.entered.wait()
    f.store.settings.readAloudProvider = "apple"
    f.release.open()
    await f.controller.waitForCompletion()
    #expect(f.readingProviders == ["xai"] && f.dictationProviders.isEmpty)
    #expect(f.controller.lastError == "Add your Captured xAI API key in EchoType Settings")
  }

  @Test(arguments: [true, false])
  func missingCredentialBlocksOnlyItsFeature(dictation: Bool) async {
    let f = FeatureProviderFixture()
    f.store.settings = Settings(dictationProvider: dictation ? "xai" : "local",
      readAloudProvider: dictation ? "local" : "xai")
    await f.controller.refreshCredentialStatus()
    #expect(f.controller.dictationHasCredential == !dictation)
    #expect(f.controller.readAloudHasCredential == dictation)
    #expect(f.controller.credentialStatusMessage ==
      "\(dictation ? "Dictation" : "Read Aloud") needs a xAI API key. Open Settings")
    #expect(f.readinessChecks == 0 && f.captureStarts == 0)
  }
}
