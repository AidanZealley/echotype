# Workstream 1: Transcription adapter

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Contract declarations for later workstreams: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`

## External validation

- Gate and placement: G1, after closure before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: the G1 entry in the plan
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan reports every G1 check passing
