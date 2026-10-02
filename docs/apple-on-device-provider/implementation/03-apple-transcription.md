# Workstream 3: Transcribe on the Mac with SpeechTranscriber

Status: not started.

## Task packet

### Outcome

`Providers/Apple/` exists with an Apple transcription service and its readiness check, not yet registered. The service streams the app's 16 kHz audio through `SpeechTranscriber` and meets the `LiveTranscriber` contract. Its readiness check reports installed, downloading or unsupported speech assets, and starts at most one installation.

Specification: [Apple provider](../../specs/apple-on-device-provider.md#apple-provider), the Description, Readiness, Language, Transcription and Tests bullets. Measurements and pitfalls: [research, live transcription](../../research/apple-on-device-provider.md#live-transcription).

### Scope

- Create the internal Apple namespace, mirroring `XAI`'s visibility. Include:
  - language resolution from the app's tag to a supported regional `Locale`, with bare `en` → `en-GB`,
  - the internal change signal that 4 and 5 reuse.
- The transcriber:
  - final segments append to committed text, volatile results replace provisional text, and utterance stays empty,
  - nonempty recognised text emits `.speech`,
  - `start()` returns promptly, and `.ready` follows analyser preparation,
  - built-in and saved keyterms go through `AnalysisContext` with `keytermLimit` 100,
  - early finish, close and join work,
  - `RecogRejected` (Speech code 1) at finish with no recognised text becomes an empty finish,
  - framework errors map to `ProviderError`.
- The transcription readiness check:
  - installed assets for the resolved locale → `.ready`,
  - missing assets → `.waiting("Downloading speech model")`, starting one installation if none is running,
  - an unsupported locale or Mac → `.unavailable` with a short reason,
  - a failed installation reports its reason, and the next check retries,
  - completion or failure fires the change signal.
  
  Keep installation-request queries inside that single-setup path, since they reserve locales.
- Fixture tests for transcript assembly and event translation, using constructed results. Suggestion: separate a pure assembler from framework types, as `XAITranscriptAssembler` does, so fixtures need no framework objects.
- An opt-in live check, gated by `ECHOTYPE_APPLE_LIVE=1`, that runs a recording through the real `SessionMachine`. Reuse the spike's approach and `ECHOTYPE_FIXTURE_WAV`.

Use `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/Transcription/` as reference. Do not edit or delete it.

### Non-goals

- Registering Apple, `Provider.apple` and the composed `Readiness`; those belong to workstream 6.
- Voice and cleanup.
- Relying on `SpeechDetector`, or adding a silence policy beyond the `RecogRejected` mapping.
- Any change outside the ownership below.

### Initial ownership

- New files in `Sources/EchoTypeCore/Providers/Apple/`
- New Apple transcription tests in `Tests/EchoTypeCoreTests/`, with live checks under `Tests/EchoTypeCoreTests/Integration/`

### Required seams

- Consumes the readiness types from workstream 1 and the language list from workstream 2.
- Produces the Apple namespace, language resolution, the change signal, the transcription service value and an internal transcription readiness check. Record their names in the handoff.

### Acceptance criteria

- Fixture tests show:
  - committed text only grows and volatile text stays provisional,
  - the resolved tail arrives before `.finished`,
  - `.speech` follows nonempty recognised text,
  - `RecogRejected` with no text finishes empty without an error.
- Language resolution maps `en` to `en-GB` and keeps explicit supported regions.
- Readiness maps installed, missing, failed and unsupported states to the specified `ServiceState`s. Repeated checks during an installation start nothing new.
- The opt-in live check transcribes a recording through `SessionMachine` with a complete tail, when run with a fixture.
- Ordinary test runs skip live checks before any framework initialisation or asset request.

### Targeted verification

```bash
swift build
swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'
git diff --check
```

Live, when a WAV fixture is available. The research's [synthetic fixture](../../research/apple-on-device-provider.md#synthetic-transcription-fixture) shows how to make one with `say`:

```bash
ECHOTYPE_APPLE_LIVE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-synthetic/recording.wav swift test --disable-xctest --filter Apple
```

Do not remove installed speech assets to recreate a missing state.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
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
