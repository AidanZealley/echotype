# Workstream 1: Transcription adapter

Status: accepted.

## Task packet

### Outcome

`SessionMachine` runs a dictation session through the neutral `LiveTranscriber` contract and knows nothing about xAI. All xAI transcription code lives in `Sources/EchoTypeCore/Providers/XAI/`. Provider failures surface as `ProviderError`. Dictation with xAI behaves as on the starting commit.

### Scope

- Add the transcription contract from the specification's [Transcription](../provider-adapters.md#transcription) section: `TranscriptionService`, `TranscriptionRequest`, `LiveTranscriber`, `TranscriptionEvent` and `Transcript`.
- Move readiness holding (the 160,000-byte limit) and send ordering out of `STTClient` into the session, so the session gives adapters the guarantees in the specification.
- Express the session's readiness, silence, pause, hard cap, finishing and outcome rules only in terms of the four events. Keep [0024](../../decisions/0024-dictation-operation-lifetime.md)'s single `reschedule()`.
- `SessionMachine.Snapshot` carries `Transcript` instead of three loose text fields.
- Move `STTClient`, event decoding, `TranscriptAssembler`, the streaming URL, the keyterm length cap and the `isSpeech` rule into an xAI transcriber in `Providers/XAI/` that implements the translation table. Rename types where the old name implies they are shared.
- Expose the xAI transcription service as a value the app wires directly, such as `XAI.transcription`. Workstream 4 moves it into a `Provider`.
- Move the WebSocket transport to `Providers/HTTP/`.
- Build the neutral keyterm list (`EchoType` first, a saved `EchoType` dropped, cut to the limit) outside the adapter.
- Add `ProviderError` and the shared default HTTP status mapping in `Providers/HTTP/`, plus one xAI mapping that adds 400 as `rejectedCredential`. Use it for the WebSocket handshake, and replace the `STTError(httpStatus:)` lines in `RevisionRequest.swift` and `ReadingRequest.swift`. `STTError` becomes private to `Providers/XAI/`, and `SessionError.stt` becomes `.provider(ProviderError)`.
- `DictationOperation.Dependencies` takes a transcriber factory instead of a `WebSocketTransport`.
- `DictationController.describe(_:)` maps `ProviderError`, keeping today's exact "xAI …" wording. Workstream 4 replaces the literal with the provider's name.
- The Keyterms tab count reads the xAI transcription service's `keytermLimit`.
- Update decision records [0002](../../decisions/0002-speech-signal-from-observed-protocol.md) and [0003](../../decisions/0003-transcript-assembly.md) to say they describe the xAI adapter, and [0004](../../decisions/0004-session-lifecycle.md) and [0024](../../decisions/0024-dictation-operation-lifetime.md) where they describe the session's protocol handling.

### Non-goals

- No cleanup, read-aloud, Settings storage or Keychain changes, and no `Provider` or registry.
- No batch mode, `live` flag, reconnect or retry.
- No changes to transcript assembly rules, timing values or user-visible text.

### Initial ownership

- `Sources/EchoTypeCore/SessionMachine.swift`, `Sources/EchoTypeCore/STT/` (moved and removed), new files under `Sources/EchoTypeCore/Providers/` for the transcription contract, `ProviderError`, `HTTP/` and `XAI/`.
- `Sources/EchoTypeApp/DictationOperation.swift` (transcriber dependency), `DictationController.swift` (transcriber wiring and `describe(_:)`), `Views/SettingsView.swift` (Keyterms count only).
- The error mapping lines only in `Sources/EchoTypeCore/RevisionRequest.swift`, `Sources/EchoTypeApp/ReadingRequest.swift` and the comment in `Sources/EchoTypeCore/TTS/Speech.swift`.
- Tests: `SessionMachineTests`, `STTClientTests`, `STTConnectionTests`, `STTFixtures`, `TranscriptAssemblerTests`, `Support/ScriptedTransport.swift`, `Integration/LiveProtocolTests.swift`, `Tests/EchoTypeAppTests/DictationOperationTests.swift`, `SpeechAdmissionTests.swift`, and new focused tests.
- Decision records 0002, 0003, 0004, 0024, this record, row 1 and gate G1 in the plan.

### Required seams

- The handoff records the final declarations of the transcription contract, `ProviderError`, the shared and xAI status mappings, and the xAI transcription service value. Workstreams 2 to 4 consume them.
- `SessionMachine.Outcome` and the operation's presentation keep their meaning for the overlay, `Reviser`, the trace and Test.

### Acceptance criteria

- Session tests drive a scripted `LiveTranscriber` with neutral events. They cover readiness and its timeout, holding audio before `.ready` and overflow, silence and pause, hard cap, finishing deadline, `.finished` before and after closing began, a stream ending early, cancellation and failure outcomes.
- The xAI adapter's tests cover the translation table, `finish()` sending `finalize` then `audio.done` after all audio, the speech rule, and status mapping, including 400 as `rejectedCredential`. The existing protocol and assembler fixtures pass unchanged in meaning.
- No file outside `Providers/XAI/` references `STTClient`, `STTEvent`, `TranscriptAssembler`, `STTError`, an xAI URL or `WebSocketTransport` except the HTTP helper. `STT/` is gone.
- Error pills show the same text as before for a rejected key, rate limit, unavailable service and server error.
- Gate G1 passes.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine|STT|Transcript|XAI|DictationOperation|SpeechAdmission'
swift build --product EchoTypeApp
git diff --check
```

Adjust the filter to the identifiers `swift test list` shows after renaming, and record the exact command and test count. Build the G1 candidate with `./scripts/build-app.sh debug .build/EchoType-workflow.app`.

## Implementation handoff

- Base commit: `f55bfad`. All work is uncommitted; source and test changes are staged so renames show. Review with `git diff HEAD` (plan.md is the lead's).
- Outcome: complete within scope. `SessionMachine` drives a neutral `LiveTranscriber` and names no provider. It holds audio before `.ready` (160,000 bytes, overflow fails), chains every send and the one `finish()`, and expresses readiness, silence, pause, hard cap, finishing deadline and outcomes only in the four events, keeping 0024's single `reschedule()`. `Snapshot` carries `Transcript`. `Sources/EchoTypeCore/STT/` is gone. The xAI protocol, decoding, assembler, streaming URL, 50-character keyterm cap and `isSpeech` rule live in `Providers/XAI/`. The WebSocket transport is in `Providers/HTTP/`. `DictationOperation.Dependencies.transcription` takes a `TranscriptionService`. The controller wires `XAI.transcription` and words `ProviderError` with today's "xAI …" text. The Keyterms count reads `XAI.transcription.keytermLimit - 1`.
- Files changed:
  - Core: `SessionMachine.swift`; new `Providers/Provider.swift`, `Providers/HTTP/HTTPStatus.swift`; `Providers/HTTP/WebSocketTransport.swift` and `URLSessionWebSocketTransport.swift` (moved from `STT/`); `Providers/XAI/XAI.swift` (new), `XAITranscriber.swift` (was `STTClient.swift`, absorbs `STTConnection.swift`), `XAIEvent.swift` (was `STTEvent.swift`, without `STTError`) and `XAITranscriptAssembler.swift`. One error line in `RevisionRequest.swift`.
  - App: `DictationOperation.swift`, `DictationController.swift`, `Views/SettingsView.swift` (count only), one error line in `ReadingRequest.swift`.
  - Tests: `SessionMachineTests`, `Support/ScriptedTranscriber.swift` (replaces `ScriptedTransport`), `XAITranscriberTests` (replaces `STTClientTests` and `STTConnectionTests`), `XAITranscriptAssemblerTests` and `XAIFixtures` (renamed, fixtures unchanged), new `TranscriptionRequestTests`, `Integration/LiveProtocolTests` (renames only), `DictationOperationTests`, `SpeechAdmissionTests`.
  - Docs: decision records 0002, 0003, 0004 and 0024.
  - Outside the listed ownership, forced by removed names: `Speech.swift` inlines its bearer header instead of `STTConnection.headers` (plus the owned comment); `Settings.swift` gets a one-line doc comment fix; `ReadingOperationTests.swift` gets one assertion changed from `STTError` to `ProviderError`.
- Contract declarations for later workstreams:

  ```swift
  // Providers/Provider.swift
  public enum ProviderError: Error, Equatable, Sendable {
    case rejectedCredential, rateLimited, unavailable
    case failed(String)
  }
  public struct TranscriptionService: Sendable {
    public var keytermLimit: Int
    public var start: @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber
    public init(keytermLimit: Int, start: @escaping @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber)
  }
  public struct TranscriptionRequest: Equatable, Sendable {
    public var language: String
    public var keyterms: [String]
    public var credential: String?
    public init(language: String, keyterms: [String], credential: String?)
    /// "EchoType" first, a saved EchoType dropped, cut to keytermLimit.
    public init(settings: Settings, keytermLimit: Int, credential: String?)
  }
  public protocol LiveTranscriber: Sendable {
    var events: AsyncThrowingStream<TranscriptionEvent, any Error> { get }
    func send(audio: Data) async throws
    func finish() async throws
    func close()
    func waitForClose() async
  }
  public enum TranscriptionEvent: Equatable, Sendable { case ready, transcript(Transcript), speech, finished }
  public struct Transcript: Equatable, Sendable {
    public var committed, utterance, provisional: String  // init defaults each to ""
  }

  // Providers/HTTP/HTTPStatus.swift: shared default
  extension ProviderError { public init(httpStatus: Int) }  // 401, 403 → rejectedCredential; 429 → rateLimited; 5xx → unavailable; else .failed("HTTP <status>")

  // Providers/XAI/XAI.swift
  public enum XAI {
    public static let transcription: TranscriptionService       // keytermLimit 100
    public static func error(httpStatus: Int) -> ProviderError  // 400 → rejectedCredential, else the shared default
  }

  // SessionMachine
  public enum SessionError { case provider(ProviderError), socket(String) }  // non-ProviderError → .socket
  SessionMachine(transcriber: any LiveTranscriber, settings: Settings, clock: any SessionClock)
  SessionMachine.Snapshot(state: State, transcript: Transcript)
  SessionMachine.heldAudioLimit  // 160_000, was STTClient.preHandshakeBytes
  ```

  `WebSocketTransport`, `URLSessionWebSocketTransport(request:errorForStatus:session:)` and everything under `XAI` other than `transcription` and `error(httpStatus:)` are internal. Tests reach them with `@testable import EchoTypeCore`. `RevisionRequest` and `ReadingRequest` now throw `XAI.error(httpStatus:)`; workstreams 2 and 3 own those files from here.
- Decisions:
  - `STTError` is deleted rather than made private. The handshake maps through `XAI.error(httpStatus:)`, injected into the shared transport, and an xAI `error` event throws `ProviderError.failed(message)`, so nothing needed a private error type. The server error `code` is no longer carried in the thrown error; it is still decoded and the live test still reports it.
  - `Dependencies.transcription` is a `TranscriptionService`, whose `start` is the transcriber factory. The operation builds the neutral `TranscriptionRequest` from settings, the key and the service's `keytermLimit`. If Escape or a capture failure lands while `start` is suspended, the operation closes and joins the new transcriber before throwing. One new operation test covers this.
  - The session calls `finish()` before `.ready` only when no audio is held. This keeps today's xAI behaviour (closing frames go out at once when nothing is held). With held audio it waits for `.ready` and sends the held audio first, as `STTClient` did.
  - The session's event loop awaits the held-audio flush when `.ready` arrives, as `STTClient`'s receive loop did. `ready` is set first, so later sends chain behind the flush.
  - The xAI adapter yields `.transcript` and then `.speech` for a speaking partial. Resuming from paused therefore publishes one extra snapshot (paused with the new text) just before the listening snapshot. Nothing visible changes beyond that frame.
  - xAI types are nested under `XAI` (`XAI.Transcriber`, `XAI.Event`, `XAI.TranscriptAssembler`) instead of `STT`-prefixed names. The assembler tests are wrapped in a suite so a name filter selects them; their fixtures and assertions are unchanged.
  - The user-visible session messages (`Connection failed: …` texts, including "the endpoint never answered the finalize request") are unchanged.
  - Gate G1 passed (2026-10-01, Aidan, escalation E1): the signed candidate built from this uncommitted state on `f55bfad` passed normal dictation, stopping mid-sentence, Escape during Transcribing and the Settings Test button.
- Verification:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine|XAI|TranscriptionRequest|DictationOperation|SpeechAdmission|ReadingOperation'`: passed, 44 core and 41 app tests. This was run three times with no flakes.
  - `swift build --product EchoTypeApp`: passed.
  - `git diff --check` and `git diff --cached --check`: clean.
  - The full deterministic suite `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test` also ran once: 81 core and 62 app tests passed, and both live tests were skipped.
  - Grepping `Sources/` outside `Providers/XAI/` for `STTClient|STTEvent|STTError|STTConnection|TranscriptAssembler|wss://|/v1/stt` finds nothing. `WebSocketTransport` appears only in `Providers/HTTP/`.
- Known limitations or external checks:
  - Gate G1 is pending; the lead builds the candidate.
  - The live xAI tests were not run.
  - Decision records outside this packet still name removed types: 0006 and 0018 mention `STTError(httpStatus:)`, and 0017 mentions `STTConnection.keyterms`. They belong to their later owners (0006 and 0018 are listed for update in the specification).
  - `ProviderError.failed` from an unexpected status reads "xAI error: HTTP <status>". Before, it read "xAI error: unexpectedStatus(<status>)" or a case name, and 5xx other than 503 now reads "xAI is unavailable", as the specification's mapping requires.
- Specification drift: none.

## Independent review

- Reviewer: independent review agent, fresh session
- Verdict: acceptable with no Required findings. Reviewed `git diff HEAD -M` against `f55bfad` and the surrounding code. Checks: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine|XAI|TranscriptionRequest|DictationOperation|SpeechAdmission|ReadingOperation'` passed with 44 core and 41 app tests; `swift build --product EchoTypeApp` passed; `git diff HEAD --check` was clean. By inspection:
  - Lifecycle holds. Enqueueing in `inOrder` is synchronous before the first suspension. `observe(.ready)` sets `ready` and enqueues the flush before the waiting `sendClosing()` can resume. `closingStarted` blocks sends after `finish()`. Cancel, fail and timeout each release the readiness wait through `conclude` → `closeTranscriber()`, and `guard ending == nil` stops `finish()` from following. Overflow fails with the same `.socket` text as before.
  - Pill text matches the base for 400/401, 429, 503 and server `error` events.
  - `STT/` is gone. No source outside `Providers/` names a removed type or the streaming URL.
  - Dependency direction is neutral → `Providers/` → `XAI`, with `HTTP/` naming no provider.
- Required findings: none.
- Optional observations:
  1. **Resuming from pause publishes an extra paused frame with the new text.** `XAITranscriber.swift:66-67` yields `.transcript` before `.speech`. As a result, `SessionMachine.swift:235-244` first publishes `paused` with the new words, then `listening`. The operation (`DictationOperation.swift:322`) presents that frame and calls `reviser.submit` one extra time. The impact is one visual frame. Yielding `.speech` first would instead publish `listening` with the old text and then the new text, so no paused frame would appear. The specification doesn't fix the order. If this changes, the expected order in `translationTable` changes with it.
  2. **No session test covers a stop that waits for readiness and never gets it.** The new readiness wait in `sendClosing()` (`SessionMachine.swift:169-172`) has no test where the finishing deadline or Escape releases it. One test would cover it: hold audio, `finish()`, advance `finalizeTimeout`, then expect `.failed(_, .socket)` with `calls` empty. The path is correct by inspection.
  3. **The translation table has an undocumented extra event.** On `transcript.done` the adapter yields `.transcript` (the assembler's committed tail) before `.finished` (`XAITranscriber.swift:68-70`). The specification's table lists only `.finished`. Parity requires the extra event and the adapter's doc table records it. The handoff says "Specification drift: none", so the lead may want to note this as an intended adapter detail.
  4. **The Keyterms count hard-codes the built-in slot.** `SettingsView.swift:437` computes `keytermLimit - 1` in the view, while `TranscriptionRequest.init(settings:keytermLimit:credential:)` owns the built-in rule. Workstream 5 rewrites this tab, so leave it for now.
  5. **Cosmetic.** The reflowed `Outcome.failed` comment at `SessionMachine.swift:53-55` runs past the file's line width.
- Questions:
  1. **Does the "xAI URL" acceptance criterion cover cleanup and read-aloud?** `RevisionRequest.swift:29` (`https://api.x.ai/v1/chat/completions`) and `TTS/Speech.swift:29` (`https://api.x.ai/v1/tts`) still sit outside `Providers/XAI/`. This packet's ownership limits those files to the error line and comment, and workstreams 2 and 3 move them. I read the criterion as covering the transcription URL, which is satisfied. The lead should confirm.
  2. **Should the contract say `finish()` can precede `.ready`?** With nothing held, `sendClosing()` calls `finish()` before `.ready` (`SessionMachine.swift:169`). This keeps base-commit xAI behaviour, and the specification doesn't forbid it. However, the `LiveTranscriber` guarantees in `Provider.swift:60-66` don't tell adapters it can happen. A later adapter, such as Apple on-device, might assume readiness. Should one line be added there, or the case left implicit?

## Resolution

- Finding dispositions:
  - Optional 1 (extra paused frame on resume): rejected. Base published one frame; either event order now publishes two, and the paused frame lasts one actor hop. Swapping the order trades it for a listening frame with old text, so neither is parity and neither is visible.
  - Optional 2 (no test for a stop waiting on `.ready` that never comes): promoted to Required. The readiness wait in `sendClosing()` is new machinery this workstream added, and a hang there would lose a dictation. One session test covers the finishing deadline releasing it.
  - Optional 3 (`.transcript` before `.finished`) and Question 2 (`finish()` before `.ready`): accepted as contract documentation. `LiveTranscriber`'s guarantees state both, and the decision and drift log records them for later adapters.
  - Optional 4 (Keyterms count computes `keytermLimit - 1` in the view): deferred to workstream 5, which owns the tab layout and the specification's "n of (keytermLimit − 1)" wording.
  - Optional 5 (comment width): accepted, cosmetic, fixed in the same pass.
  - Question 1 (xAI URLs in `RevisionRequest.swift` and `Speech.swift`): the criterion covers transcription. Those files belong to workstreams 2 and 3, which move their URLs; the whole-feature provider-name search checks the end state.
  - Implementer's out-of-ownership edits (`Speech.swift` bearer header, `Settings.swift` comment, one `ReadingOperationTests` assertion) are accepted as forced by removed names. Deleting `STTError` rather than making it private is accepted: it meets "not visible outside `Providers/XAI/`" with less code.
- Simplification/deletion pass: the remediation adds one `SessionMachineTests` case (`finishWaitingOnReadinessTimesOut`: held audio, stop, no `.ready`, finishing deadline ends the session `.failed(text: "", .socket("the endpoint never answered the finalize request"))` with no `send` or `finish()` reaching the transcriber and `sendClosing()` returning), two contract lines in `LiveTranscriber`'s guarantees (`finish()` before `.ready` with no audio sent; a final `.transcript` before `.finished`), and a rewrap of the `Outcome.failed` comment. No production code changed: the new test passed against the existing readiness release in `closeTranscriber()`, so it exposed no defect. The xAI event table in `XAITranscriber.swift` already shows the final transcript before `.finished` and needed no change. Nothing further to delete.
- Final verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine|XAI|TranscriptionRequest|DictationOperation|SpeechAdmission|ReadingOperation'` passed: 45 tests in 4 suites (EchoTypeCoreTests) and 41 tests in 4 suites (EchoTypeAppTests), 86 total, no failures. `swift build --product EchoTypeApp` succeeded. `git diff HEAD --check` reported nothing.

## Closure review

- Verdict: closed. The accepted findings are resolved and the fixes introduce no release-blocking defect.
  - `finishWaitingOnReadinessTimesOut` holds audio, stops without `.ready` and advances `finalizeTimeout`. It expects `.failed(text: "", .socket("the endpoint never answered the finalize request"))`, an empty `calls` and `sendClosing()` returning. That matches the release path: `closeTranscriber()` finishes `readinessPublisher`, and `guard ending == nil` then skips `finish()`. No production code changed.
  - `LiveTranscriber`'s guarantees in `Provider.swift` now state that `finish()` may come before `.ready` when no audio was sent, and that a final `.transcript` may come just before `.finished`. Both match `sendClosing()` and the xAI adapter.
  - The `Outcome.failed` comment is rewrapped within the file's width.
  - Checks: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine|XAI|TranscriptionRequest|DictationOperation|SpeechAdmission|ReadingOperation'` passed with 45 core and 41 app tests. `swift build --product EchoTypeApp` passed. `git diff HEAD --check` was clean.
- Remaining required findings: none.

## External validation

- Gate and placement: G1, after closure before acceptance
- Status: `Passed`
- Candidate and instructions: `.build/EchoType-workflow.app`, built with `./scripts/build-app.sh debug .build/EchoType-workflow.app` after closure from workstream 1's uncommitted state on `f55bfad`. No source or test file changed after the build. Signed with the installed app's identifier; this workstream does not change stored settings.
- Required evidence: Aidan reported Pass on 2026-10-01: normal dictation, stopping mid-sentence keeps the final words, Escape during Transcribing inserts nothing, and the Settings Test button shows what it heard.
- Attempts and lasting decisions: one attempt, passed. No correction was needed.
- Acceptance check: the targeted filter rerun at acceptance passed (45 core, 41 app tests) and `git diff HEAD --check` was clean.
