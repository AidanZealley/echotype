# Workstream 3: Read-aloud adapter

Status: not started.

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

- Gate and placement: G2, after closure before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: the G2 entry in the plan
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan reports every G2 check passing
