@testable import EchoTypeCore
import Foundation
import Testing

@Suite struct AppleTranscriptionTests {
  // MARK: Transcript

  @Test("Final segments append to committed text and volatile results stay provisional")
  func finalSegmentsCommit() {
    var assembler = Apple.TranscriptAssembler()
    var transcripts: [Transcript] = []
    for (text, isFinal) in [
      ("Echo", false), ("EchoType lets", false), (" EchoType lets me dictate.", true),
      (" I use", false), (" I use Zustand.", true),
    ] {
      for case .transcript(let transcript) in assembler.apply(text: text, isFinal: isFinal) {
        transcripts.append(transcript)
      }
    }

    #expect(
      transcripts == [
        Transcript(provisional: "Echo"),
        Transcript(provisional: "EchoType lets"),
        Transcript(committed: "EchoType lets me dictate."),
        Transcript(committed: "EchoType lets me dictate.", provisional: "I use"),
        Transcript(committed: "EchoType lets me dictate. I use Zustand."),
      ])
  }

  @Test("Recognised text is speech and empty results are not")
  func speechFollowsText() {
    var assembler = Apple.TranscriptAssembler()
    #expect(assembler.apply(text: "", isFinal: false) == [.transcript(Transcript())])
    #expect(assembler.apply(text: " ", isFinal: true) == [.transcript(Transcript())])
    #expect(
      assembler.apply(text: "hello", isFinal: false)
        == [.transcript(Transcript(provisional: "hello")), .speech])
  }

  @Test("A rejected recognition at finish with nothing recognised is an empty finish")
  func rejectionWithoutTextFinishes() {
    let rejection = NSError(domain: "SFSpeechErrorDomain", code: 1)
    var assembler = Apple.TranscriptAssembler()
    #expect(assembler.ending(after: rejection, finishing: true) == nil)
    // Before finish, or after provisional or committed text, it is a failure like any other.
    #expect(assembler.ending(after: rejection, finishing: false) is ProviderError)
    _ = assembler.apply(text: "hello", isFinal: false)
    #expect(assembler.ending(after: rejection, finishing: true) is ProviderError)
    _ = assembler.apply(text: "hello", isFinal: true)
    #expect(assembler.ending(after: rejection, finishing: true) is ProviderError)
  }

  @Test("Framework errors become provider failures and cancellation passes through")
  func errorsMapToProviderError() {
    let assembler = Apple.TranscriptAssembler()
    let error = NSError(domain: "SFSpeechErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio read failed"])
    #expect(assembler.ending(after: error, finishing: true) as? ProviderError == .failed("Audio read failed"))
    #expect(assembler.ending(after: CancellationError(), finishing: true) is CancellationError)
  }

  // MARK: Language

  @Test(
    "English resolves to British English and an unlisted tag passes through",
    arguments: [("en", "en-GB"), ("fr", "fr")])
  func languageResolution(tag: String, expected: String) {
    #expect(Apple.locale(for: tag).identifier(.bcp47) == expected)
  }

  // MARK: Readiness

  @Test("Installed assets are ready without an installation")
  func installedIsReady() async {
    let system = FakeSpeechSystem(installed: true)
    let assets = Apple.SpeechAssets(system: system.system, changes: Apple.Changes())
    #expect(await assets.check(language: "en") == .ready)
    #expect(await system.installs == 0)
  }

  @Test("Missing assets wait on one installation, then are ready")
  func missingStartsOneInstallation() async {
    let system = FakeSpeechSystem(installed: false)
    let changes = Apple.Changes()
    let assets = Apple.SpeechAssets(system: system.system, changes: changes)
    let followed = changes.stream()

    for _ in 0..<3 {
      #expect(await assets.check(language: "en") == .waiting("Downloading speech model"))
    }

    await system.open()
    // The status may still not say installed; the finished setup is what counts.
    #expect(await state(after: followed, of: assets) == .ready)
    #expect(await system.installs == 1)
  }

  @Test("A failed installation reports once and the next check retries")
  func failureReportsThenRetries() async {
    let system = FakeSpeechSystem(installed: false, fails: true)
    let changes = Apple.Changes()
    let assets = Apple.SpeechAssets(system: system.system, changes: changes)
    let followed = changes.stream()

    await system.open()
    #expect(await assets.check(language: "en") == .waiting("Downloading speech model"))
    #expect(await state(after: followed, of: assets) == .unavailable("Speech model download failed"))
    #expect(await assets.check(language: "en") == .waiting("Downloading speech model"))
    #expect(await state(after: followed, of: assets) == .unavailable("Speech model download failed"))
    #expect(await system.installs == 2)
  }

  @Test("An unsupported Mac or language is unavailable and installs nothing")
  func unsupportedIsUnavailable() async {
    let mac = FakeSpeechSystem(installed: false, available: false)
    #expect(
      await Apple.SpeechAssets(system: mac.system, changes: Apple.Changes()).check(language: "en")
        == .unavailable("Transcription is not supported on this Mac"))
    let language = FakeSpeechSystem(installed: false)
    #expect(
      await Apple.SpeechAssets(system: language.system, changes: Apple.Changes()).check(language: "xx")
        == .unavailable("Transcription does not support this language"))
    #expect(await mac.installs + language.installs == 0)
  }

  /// Re-checks on each change, as the settings window does, until setup has ended.
  private func state(after changes: AsyncStream<Void>, of assets: Apple.SpeechAssets) async -> ServiceState? {
    for await _ in changes {
      let state = await assets.check(language: "en")
      if state != .waiting("Downloading speech model") { return state }
    }
    return nil
  }
}

/// Speech assets that support only `en`, with installations held until `open()`.
private actor FakeSpeechSystem {
  private(set) var installs = 0
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private nonisolated let installed: Bool
  private nonisolated let available: Bool
  private nonisolated let fails: Bool

  init(installed: Bool, available: Bool = true, fails: Bool = false) {
    self.installed = installed
    self.available = available
    self.fails = fails
  }

  nonisolated var system: Apple.SpeechAssets.System {
    .init(
      isAvailable: { [available] in available },
      locale: { $0 == "en" ? Locale(identifier: "en-GB") : nil },
      isInstalled: { [installed] _ in installed },
      install: { [self] _ in
        await install()
        if fails { throw ProviderError.failed("download failed") }
      })
  }

  func open() {
    isOpen = true
    for waiter in waiters { waiter.resume() }
    waiters = []
  }

  private func install() async {
    installs += 1
    if isOpen { return }
    await withCheckedContinuation { waiters.append($0) }
  }
}
