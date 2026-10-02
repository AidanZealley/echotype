# Workstream 4: Read aloud on the Mac with AVSpeechSynthesizer

Status: not started.

## Task packet

### Outcome

The Apple namespace has a voice service and its readiness check, not yet registered. It offers Zoe Premium (default) and Jamie Premium, falls back to an installed voice for the language, maps speed through per-voice rate anchors, and delivers bounded audio that meets the `SpeechStream` contract.

Specification: [Apple provider](../../specs/apple-on-device-provider.md#apple-provider), the Voice and Tests bullets. Measurements and pitfalls: [research, read aloud](../../research/apple-on-device-provider.md#read-aloud).

### Scope

- Voices: `com.apple.voice.premium.en-US.Zoe` shown as "Zoe", then `com.apple.voice.premium.en-GB.Malcolm` shown as "Jamie".
- Voice resolution:
  - use the saved voice when it is installed and suits the language,
  - otherwise fall back to an installed voice for the language without changing the saved choice.
- Voice readiness:
  - a resolvable voice → `.ready`,
  - none → `.unavailable` with guidance to download one in System Settings > Accessibility > Read & Speak,
  - the voices-changed notification fires the Apple change signal from workstream 3.
- Speed: fixed per-voice rate anchors with interpolation. Reuse Zoe's measured anchors. Measure Jamie's silently with an opt-in check, as the spike did, without playing audio. Choose a provisional `speedRange` that includes 1, such as 0.8...1.3; Aidan tunes it at gate G2.
- Streaming:
  - the maximum is 60,000 Unicode scalars,
  - one utterance of at most 250 scalars at a time, preferring the last complete sentence within the bound, with a word or hard split for longer sentences,
  - start the next utterance only after the previous one's PCM is consumed,
  - finish on `didFinish`, not on the first zero-frame callback,
  - the sample rate comes from the synthesiser's buffers, mono Float32, at most 100 ms per chunk,
  - `cancel()` makes a pending `next()` throw and stops synthesis.
- Fixture tests for utterance splitting, chunking, rate mapping and voice resolution, using constructed inputs.
- Opt-in live checks, gated by `ECHOTYPE_APPLE_LIVE=1`, for PCM format, bounded read-ahead while not pulling, and cancellation.

Use `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/Voice/` as reference. Do not edit or delete it.

### Non-goals

- Registering Apple, transcription and cleanup.
- Downloading voices, a dynamic voice list, Siri voices, or runtime rate calibration.
- Playing audio aloud.

### Initial ownership

- New voice files in `Sources/EchoTypeCore/Providers/Apple/`, and the change-signal file from workstream 3 only to connect the voices notification
- New Apple voice tests in `Tests/EchoTypeCoreTests/`, with live checks under `Tests/EchoTypeCoreTests/Integration/`

### Required seams

- Consumes the readiness types, the language list, and the Apple namespace and change signal.
- Produces the voice service value and an internal voice readiness check. Record their names and the provisional speed range in the handoff.

### Acceptance criteria

- Fixture tests show:
  - sentence-preferring splits within 250 scalars,
  - chunks of at most 100 ms at one sample rate,
  - 1x maps to the default rate,
  - fallback leaves the saved voice unchanged,
  - no installed voice for the language gives `.unavailable`.
- Live checks, when enabled, show:
  - complete mono Float32 output for Zoe and Jamie,
  - no new submissions while the caller stops pulling,
  - prompt cancellation of a pending pull, after which another reading works.
- Jamie's rate anchors are recorded with the measurement method.

### Targeted verification

```bash
swift build
swift test --disable-xctest --filter 'Apple|ReadingOperationTests|SpeechPlayerTests'
ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice
git diff --check
```

Adjust the live filter to the suite names you create.

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
