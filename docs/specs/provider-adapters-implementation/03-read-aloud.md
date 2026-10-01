# Workstream 3: Read-aloud adapter

Status: accepted.

## Task packet

### Outcome

Read aloud and MCP `speak` play audio from a neutral `VoiceService` and `SpeechStream`. The xAI request and PCM decoding live in `Providers/XAI/`, and playback takes its format from the stream. Reading with xAI behaves as on the starting commit.

### Scope

- Add `VoiceService`, `Voice`, `SpeechRequest`, `SpeechStream` and `SpeechAudio`, as in the specification's [Read aloud](../provider-adapters.md#read-aloud) section.
- Move the streamed HTTP body with its bounded queue (today's `SpeechRequest` class in `ReadingRequest.swift`) into `Providers/HTTP/`.
- Move the xAI TTS request, voices, speed range, character limit and PCM decoding into an xAI voice adapter, exposed as a value the app wires directly, such as `XAI.voice`. Give voices display names.
- `Reader` caps text with the service's `maximumCharacters`, pulls `SpeechAudio` and no longer builds requests or decodes PCM.
- `SpeechPlayer` and its audio output take the sample rate and the 500 ms queue limit from the stream.
- The Read Aloud tab lists the xAI voice service's voices by display name. `Settings.voice` and `speechSpeed` stay as they are; workstream 5 replaces them.
- Update [0018](../../decisions/0018-read-aloud-audio-fetch.md).

### Non-goals

- No per-provider voice storage, speed-range move or migration; those belong to workstream 5.
- No change to selection copying, pause and replacement rules, MCP admission or the coordinator's arbitration.

### Initial ownership

- `Sources/EchoTypeCore/TTS/` (moved and removed), new read-aloud files under `Providers/`, `Providers/HTTP/` and `Providers/XAI/`.
- `Sources/EchoTypeApp/Reader.swift`, `ReadingRequest.swift` (moved or removed), `SpeechPlayer.swift`, `DictationController.swift` (reader wiring only), `Views/SettingsView.swift` (voice list source only).
- Tests: `SpeechTests`, `PCMDecoderTests`, `Tests/EchoTypeAppTests/ReadingOperationTests.swift`, `SpeechPlayerTests.swift`, `MCPDeliveryTests.swift` if affected, and new focused tests.
- Decision record 0018, this record, row 3 and gate G2.

### Required seams

- Consume workstream 1's `ProviderError` and xAI status mapping.
- The handoff records the final read-aloud declarations and the xAI voice service value for workstream 4, and notes that `Settings.speechSpeedRange` temporarily duplicates the xAI speed range until workstream 5.

### Acceptance criteria

- The player configures its format and queue limit from the stream's sample rate. A test proves a non-24 kHz stream plays at its own rate.
- Pausing still applies backpressure: the HTTP body reads no further than its bounded queue while playback waits.
- The xAI adapter's tests cover the request body, the voices, and decoding into `SpeechAudio`.
- Nothing outside `Providers/XAI/` references the xAI TTS URL, `Speech.voices`, `Speech.sampleRate` or `PCMDecoder`. `TTS/` is gone.
- Gate G2 passes.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Speech|PCMDecoder|ReadingOperation|SpeechPlayer|MCPDelivery'
swift build --product EchoTypeApp
git diff --check
```

Adjust the filter to the identifiers `swift test list` shows, and record the exact command and test count. Build the G2 candidate with `./scripts/build-app.sh debug .build/EchoType-workflow.app`.

## Implementation handoff

- Base commit: `a889284` (workstream 2 accepted). All work is uncommitted; source, test and decision-record changes are staged. Review with `git diff --cached HEAD` (plan.md is the lead's).
- Outcome: complete within scope. `Reader` takes a `VoiceService`, caps text with `capped(_:)` (the service's `maximumCharacters` in Unicode scalars), builds a neutral `SpeechRequest` and pulls `SpeechAudio`; it no longer builds requests or decodes PCM. `SpeechPlayer` and `PlaybackAudio` take the format, the 100 ms level tap and the 500 ms queue limit from the first chunk's sample rate. The bounded streaming body moved from the app's `ReadingRequest.swift` (`SpeechRequest` class) to `Providers/HTTP/StreamingResponse.swift`, unchanged apart from an injected status mapping. The xAI TTS request, voices, speed range, character limit, 24 kHz rate and PCM decoding live in `Providers/XAI/`, exposed as `XAI.voice`. The controller wires `XAI.voice`; the Read Aloud tab lists `XAI.voice.voices` by display name. `Sources/EchoTypeCore/TTS/` is gone.
- Files changed:
  - Core: `Providers/Provider.swift` (read-aloud contract), `Providers/XAI/XAI.swift` (`voice`), new `Providers/XAI/XAIVoice.swift` (was `TTS/Speech.swift`; request plus the `Stream` actor), new `Providers/XAI/XAIPCMDecoder.swift` (was `TTS/PCMDecoder.swift`, now internal `XAI.PCMDecoder`), `Providers/HTTP/StreamingResponse.swift` (renamed from `EchoTypeApp/ReadingRequest.swift`; the `ReadingRequest` protocol and `ReadingDecoder` actor are deleted).
  - App: `Reader.swift`, `SpeechPlayer.swift`, `DictationController.swift` (reader wiring only), `Views/SettingsView.swift` (voice list only).
  - Tests: `XAIVoiceTests` (was `SpeechTests`; request body, voices, range and cap, decoding into `SpeechAudio`), `PCMDecoderTests` (now `@testable`), new `StreamingResponseTests` and `Support/SilentResponse.swift` (the URLSession body tests moved from `ReadingOperationTests`), `ReadingOperationTests` (fake `SpeechStream`; new tests for the request reaching the service and a stream failure reaching the outcome), `SpeechPlayerTests` (start takes a rate; new 16 kHz test), `SpeechAdmissionTests` (dependency shape only).
  - Docs: decision record 0018 (Decision bullet updated, new "Provider adapters, 2026-10-01" section).
  - Outside the listed ownership, forced by removed names: `Settings.swift` gets doc comment fixes on `voice`, `speechSpeed` and `speechSpeedRange`; `SettingsValidationTests.swift` checks the speed through the neutral `SpeechRequest(text:settings:credential:)` instead of the removed `Speech.request`.
- Contract declarations for later workstreams:

  ```swift
  // Providers/Provider.swift
  public struct VoiceService: Sendable {
    public var voices: [Voice]                  // first is the default
    public var speedRange: ClosedRange<Double>
    public var maximumCharacters: Int           // Unicode scalars
    public var speak: @Sendable (SpeechRequest) -> any SpeechStream
    public init(voices:speedRange:maximumCharacters:speak:)
    public func capped(_ text: String) -> String
  }
  public struct Voice: Hashable, Identifiable, Sendable {
    public var id: String     // stored in Settings.voice
    public var name: String   // display name
    public init(id: String, name: String)
  }
  public struct SpeechRequest: Equatable, Sendable {
    public var text: String, voice: String, speed: Double, language: String
    public var credential: String?
    public init(text:voice:speed:language:credential:)
    /// settings.voice, settings.validatedSpeechSpeed, settings.language
    public init(text: String, settings: Settings, credential: String?)
  }
  public protocol SpeechStream: Sendable {
    func next() async throws -> SpeechAudio?   // nil at the end; one rate, chunks of at most 100 ms
    func cancel()
  }
  public struct SpeechAudio: Equatable, Sendable {
    public var sampleRate: Int
    public var samples: [Float]
    public init(sampleRate: Int, samples: [Float])
  }

  // Providers/XAI/XAI.swift
  public static let voice: VoiceService   // XAI.voice: ara/Ara, altair/Altair; 0.7...1.5; 60,000

  // Reader.Dependencies (app)
  var voice: VoiceService                  // replaces request: (URLRequest) -> any ReadingRequest

  // ReadingPlayback / SpeechPlayer (app)
  func start(sampleRate: Int) throws
  private(set) var maximumQueuedFrames: Int   // sampleRate / 2, set by start; was a static
  ```

  `StreamingResponse(_:errorForStatus:configuration:)`, `XAI.Speech` and `XAI.PCMDecoder` are internal; tests reach them with `@testable import EchoTypeCore`. Workstream 4 replaces `voice: XAI.voice` in the controller's reader factory and `XAI.voice.voices` in the Read Aloud tab with the selected provider's service. `Settings.speechSpeedRange` (0.7...1.5) temporarily duplicates `XAI.voice.speedRange` until workstream 5, and `Settings.voice` still defaults to `"ara"`.
- Decisions:
  - A stream promises chunks of at most 100 ms with one sample rate, stated on `SpeechStream`. The xAI stream yields 100 ms slices of each 64 KiB body piece and takes the next piece only when the last is used up, so the copied-buffer bound, the 100 ms decode working set and pause backpressure in 0018 are unchanged. The player keeps its precondition that a chunk fits the queue.
  - The xAI stream is an actor with a `nonisolated cancel()`, which keeps decoding off the UI actor and replaces the app's `ReadingDecoder` actor.
  - The player configures from the first chunk's rate; later chunks are assumed to share it rather than reconfiguring mid-reading.
  - `SpeechRequest(text:settings:credential:)` mirrors `TranscriptionRequest(settings:…)`. Speed still uses `Settings.validatedSpeechSpeed`; the service's `speedRange` is not yet used for validation (workstream 5).
  - The xAI request sends no `Authorization` header when the credential is nil, matching transcription and cleanup. `Reader` still fails with `noAPIKey` before speaking, so it always sends one today.
  - `capped(_:)` lives on `VoiceService` so `Reader` and the tests share one Unicode-scalar rule.
- Verification:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'XAIVoice|pcm|StreamingResponse|SettingsValidation|ReadingOperation|SpeechPlayer|MCPDelivery|SpeechAdmission'`: passed, 13 core tests in 3 suites and 27 app tests in 5 suites. This is the filter that selects the moved tests; the packet's suggested `Speech` and `PCMDecoder` match neither `XAIVoiceTests` nor the PCM tests, which are top-level functions named `pcm…`; the filter also matches `CoordinatorTests/microphoneTestRetainsLastDictationAndIgnoresCommands`.
  - Full deterministic suite `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test`: 89 core and 61 app tests passed; both live tests skipped.
  - `swift build --product EchoTypeApp`: passed. `git diff --check` and `git diff --cached --check`: clean.
  - Grepping `Sources` and `Tests` outside `Providers/XAI/` for `api.x.ai/v1/tts`, `Speech.voices`, `Speech.sampleRate`, `PCMDecoder`, `ReadingRequest`, `ReadingDecoder` and `TTS/` finds only the xAI adapter tests (`XAIVoiceTests`, `PCMDecoderTests`). `Sources` outside `Providers/XAI/` names xAI for reading only in the controller wiring and the Read Aloud tab's voice list, as the packet scopes.
- Known limitations or external checks:
  - Gate G2 is pending; the lead builds the candidate. The live xAI tests were not run.
  - The 16 kHz player test drives the fake output; the real `AVAudioEngine` path at a non-24 kHz rate is only exercised by a future provider.
  - `docs/decisions/0006` still mentions `STTError(httpStatus:)`; it belongs to workstream 4.
- Specification drift: none.
- Gate G2 (escalation E2, answered by Aidan on 2026-10-01): Pass. Aidan read selections with Ara and Altair, paused and resumed with Space and stopped with the hotkey on the signed candidate; an MCP `speak` call from the orchestrator was read aloud. No correction was needed after closure, so the reviewed diff is the accepted one.

## Independent review

- Reviewer: fresh independent review agent. Reviewed the staged diff against `a889284` (`git diff HEAD`, plan.md excluded) and the code around it.
- Verdict: changes required, one small contract fix (R1). Everything else meets the packet. The read-aloud contract matches the specification, `TTS/` is gone, `Reader` no longer builds requests or decodes PCM, the player takes its format, level tap and 500 ms limit from the stream's rate, and the dependency direction is right: `StreamingResponse` is internal to Core and the app names xAI only in the two places the packet allows.
  - Verification run by the reviewer: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'XAIVoice|pcm|StreamingResponse|SettingsValidation|ReadingOperation|SpeechPlayer|MCPDelivery|SpeechAdmission'` passed with 13 core tests in 3 suites and 27 app tests in 5 suites. `swift build --product EchoTypeApp` passed. `git diff --check HEAD` and `git diff --cached --check` are clean. Grepping `Sources` and `Tests` outside `Providers/XAI/` for the TTS URL, `Speech.voices`, `Speech.sampleRate`, `PCMDecoder`, `ReadingRequest`, `ReadingDecoder` and `TTS/` finds only the xAI adapter tests.
  - Pause backpressure holds (from reading the code; no test covers it end to end). `XAI.Speech.Stream.next()` calls `body.next()` only when `pending` is empty. `Reader` pulls again only after `player.schedule` returns, and `schedule` waits while 500 ms is queued. While paused, the stream therefore holds at most one 64 KiB piece, and the body's four slots block the delegate callback. That is the 327,680-byte copied bound from 0018, as before, where `Reader` held the piece itself.
  - Cancellation and lifecycle are sound. `Reader.stop()` and the end of `run()` both call `stream.cancel()`, which ends the body. A suspended `next()` is woken through the body's waiter, and task cancellation reaches it through the actor call and `withTaskCancellationHandler`. `Reader` calls `checkStopped()` after every `next()`, so a chunk returned after Stop is never scheduled. Every reading gets a new `Stream`, decoder and `SpeechPlayer`, so per-reading format state is safe.
  - The new `SpeechStream` guarantees are justified. Promising chunks of at most 100 ms keeps the player's existing precondition (one chunk fits the 500 ms queue) and 0018's 100 ms decode working set without adding slicing to `Reader`. The xAI adapter has to slice anyway, because the decoder lives in the adapter now. Promising one rate per stream is what lets the player configure once on the first chunk. A rate change mid-reading would need a second engine format, which no provider needs. Both promises are one sentence on the protocol, with no extra machinery.
- Required findings:
  - **R1. `SpeechStream.cancel()` promises more than the xAI stream does.** `Provider.swift` says cancel "fails a pending or later `next()` with `CancellationError`". `XAI.Speech.Stream.next()` checks for cancellation only through `body.next()`, which it calls only when `pending` is empty. After `cancel()`, later calls to `next()` still return 100 ms chunks from the piece the stream already holds, up to about 1.4 s of audio (64 KiB of 24 kHz PCM). `Reader` is not affected, because it checks `stopped` after every `next()`. The doc comment is still a public contract that workstream 4 and the next provider will code against, and the only implementation breaks it. Smallest fix: narrow the doc to what callers need, for example "Stops the request. A pending `next()` throws; the caller must not rely on later results." The alternative is to add cancellation state that a `nonisolated` `cancel()` can set, but nothing needs it.
- Optional observations:
  - O1. Pause backpressure at the adapter level (the stream doesn't drain the body ahead of the consumer) has no test. It is clear from the code, and 0018's localhost probe covers the body. Adding a timing-based test is probably not worth it.
  - O2. `XAI.voice`'s use of `XAI.error(httpStatus:)` (400 maps to `rejectedCredential`) isn't tested through the voice path. The deleted reader-level test used the shared mapping too, and the wiring is one argument. Low value.
  - O3. `PlaybackAudio.start(sampleRate:)` force-unwraps `AVAudioFormat(standardFormatWithSampleRate:channels:)`. With a constant rate this couldn't fail. It now depends on the adapter's rate. A nonsensical rate is an adapter bug that would crash either way (`maximumQueuedFrames` would be 0), so this is acceptable as an invariant.
  - O4. The packet's suggested filter names `Speech` and `PCMDecoder`. Neither matches the moved tests (`XAIVoiceTests`, top-level `pcm…`). The filter above and the handoff's filter are the correct ones to record.
- Questions: none.

## Resolution

- Finding dispositions:
  - R1 accepted (lead verified: `XAI.Speech.Stream.next()` keeps returning its held piece after `cancel()`). Fix by narrowing the `SpeechStream.cancel()` contract, not by adding cancelled state to the adapter: cancel stops the request and makes a pending `next()` throw; callers stop pulling after cancel and must not rely on later results. `Reader` already does this.
  - O1, O2, O3 rejected as optional: backpressure is evident from the pull loop and unchanged from 0018; the status mapping is one argument shared with tested paths; the force-unwrap guards an invariant.
  - O4 accepted as a record fix only: the handoff records the filter that selects the moved tests.
- Simplification/deletion pass: R1 was fixed by narrowing the `SpeechStream.cancel()` doc comment in `Provider.swift` only; no cancelled state, wrapper or test was added. Decision record 0018 and the handoff's declarations never restated the old promise, so they needed no change. Nothing else became obsolete.
- Final verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'XAIVoice|pcm|StreamingResponse|SettingsValidation|ReadingOperation|SpeechPlayer|MCPDelivery|SpeechAdmission'` passed, 13 core tests in 3 suites and 27 app tests in 5 suites. `swift build --product EchoTypeApp` passed. `git diff --check` and `git diff --cached --check` are clean.

## Closure review

- Verdict: closed. R1 is fixed: the `SpeechStream.cancel()` doc in `Provider.swift` now promises only that cancel stops the request and makes a pending `next()` throw, and that callers stop pulling and must not rely on later results. `XAI.Speech.Stream` keeps that promise, because a `next()` suspends only inside `body.next()`, which `body.cancel()` ends. `Reader` already stops pulling after cancel. The old "pending or later" wording survives only in the review text that quotes it. O4 is fixed: the handoff records the filter that selects the moved tests and explains why the packet's suggested filter does not. The fix adds no state, wrapper or test, so it introduces no new defects. Re-run: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'XAIVoice|pcm|StreamingResponse|SettingsValidation|ReadingOperation|SpeechPlayer|MCPDelivery|SpeechAdmission'` passed with 13 core tests in 3 suites and 27 app tests in 5 suites. `git diff --check` and `git diff --cached --check` are clean.
- Remaining required findings: none.

## External validation

- Gate and placement: G2, after closure before acceptance
- Status: `Passed`
- Candidate and instructions: `.build/EchoType-workflow.app`, a signed debug build (`com.aidanzealley.echotype`, team LJHNNE925Q) from workstream 3's staged, uncommitted state on `refactor/provider-adapters` at `a889284`, after closure. Aidan quits the installed EchoType, opens the candidate (`open .build/EchoType-workflow.app`; it shares the installed app's Keychain key and settings and does not migrate settings), then checks: reading a selection with Ara and with Altair; Space pauses and resumes; the read-aloud hotkey stops a reading; an agent's MCP `speak` call is read aloud. Afterwards he quits the candidate and reopens `/Applications/EchoType.app`.
- Required evidence: Aidan's G2 answer, recorded under Attempts below (the escalation entry is removed)
- Attempts and lasting decisions: one attempt, passed on 2026-10-01 (Aidan checked reading with Ara and Altair, Space pause and resume, and the hotkey stop; an orchestrator MCP `speak` call was read aloud). No lasting decision. On resume the lead re-ran the targeted filter (13 core, 27 app tests passed), `swift build --product EchoTypeApp` and both diff checks, all clean.
- Resume condition: Aidan reports every G2 check passing
