# Workstream 4: Read aloud on the Mac with AVSpeechSynthesizer

Status: accepted.

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

- Base commit: `f43f0d1575cdccca2370abe8c3c75cc9e9540de3`
- Outcome: `Apple.voice`, an unregistered `VoiceService` on `AVSpeechSynthesizer.write`, plus the synchronous voice readiness check `Apple.Speech.check(language:voice:)`. The voices-changed notification fires `Apple.changes`. Fixture tests and opt-in live checks pass.
- Files changed:
  - `Sources/EchoTypeCore/Providers/Apple/AppleVoice.swift` (new): `Apple.voice`, `enum Apple.Speech` with `voices`, `speedRange`, `maximumCharacters`, `utteranceLimit`, `missingVoice`, `InstalledVoice`, `installedVoices()`, `check(language:voice:installed:)`, `resolve(_:language:among:)`, `rate(speed:voice:)`, `nextUtterance(in:)`, `samples(from:)`, `Chunks` and `Stream`.
  - `Sources/EchoTypeCore/Providers/Apple/Apple.swift`: `Apple.changes` is now built in a closure that observes `AVSpeechSynthesizer.availableVoicesDidChangeNotification` for the life of the app and calls `send()`. Imports `AVFoundation`.
  - `Tests/EchoTypeCoreTests/AppleVoiceTests.swift` (new): fixture tests.
  - `Tests/EchoTypeCoreTests/Integration/AppleVoiceLiveTests.swift` (new): live checks gated by `ECHOTYPE_APPLE_LIVE=1`.
- Decisions:
  - Seams for 6:
    ```swift
    extension Apple {
      static let voice: VoiceService   // voices Zoe, Jamie; speedRange 0.8...1.3; maximumCharacters 60_000
      enum Speech {
        static func check(language: String, voice: String, installed: [InstalledVoice] = installedVoices()) -> ServiceState
      }
    }
    ```
    Workstream 6 composes `voice: Apple.Speech.check(language: request.language, voice: request.voice)` into `Provider.apple.readiness`. It is synchronous and has no setup, so it never waits; it is `.ready` or `.unavailable("Download a voice in System Settings > Accessibility > Read & Speak")`.
  - Provisional `speedRange` is `0.8...1.3`, for Aidan to tune at G2. Anchors cover 0.7...1.5, so widening needs no new measurement.
  - Voice ids: `com.apple.voice.premium.en-US.Zoe` "Zoe" (default), `com.apple.voice.premium.en-GB.Malcolm` "Jamie".
  - Resolution: a voice suits the language when its language subtag matches the request tag's (no region or script comparison; regions are irrelevant since Zoe is en-US and bare `en` resolves to en-GB elsewhere). The saved voice wins when installed and suitable. Otherwise, among suitable installed voices: offered voices in list order, then higher quality, then `com.apple.voice.*` ids before novelty/Eloquence ones, then id. Resolution happens per reading in `speak`; nothing writes settings.
  - Rate anchors at speeds `[0.7, 0.85, 1, 1.25, 1.5]`, linearly interpolated and clamped to that span. Zoe: the research's `[0.1626, 0.3426, 0.5, 0.5414, 0.5849]` unchanged. Jamie: `[0.1571, 0.3259, 0.5, 0.5418, 0.5837]`. A voice without anchors (a fallback) uses Zoe's.
  - Jamie's measurement method: a temporary opt-in test (deleted afterwards) rendered the research's 104-scalar sentence ("EchoType reads this sentence on the Mac. We can pause the reading and continue without losing any words.") through `Apple.Speech.Stream`, silently, at raw rates `0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.52, 0.54, 0.56, 0.58, 0.6`. Relative speed = frames at 0.5 / frames at the rate. Each anchor is the linear interpolation of rate where relative speed crosses the target. Re-deriving Zoe the same way gave `0.1620, 0.3360, 0.5412, 0.5846`, within 0.007 of the recorded anchors. With the final anchors, Jamie's sentence measured 0.694/0.788/0.844/1/1.070/1.238/1.279/1.510 at requested 0.7/0.8/0.85/1/1.1/1.25/1.3/1.5, and the research's 448-scalar paragraph 0.694/0.786/1.285/1.496 at 0.7/0.8/1.3/1.5. Jamie's rate curve is convex between 0.5 and 0.54, so 1.1x reads about 1.07x.
  - Streaming: `Stream` is a `@MainActor` `NSObject` like the spike, with a `nonisolated init` so the synchronous `speak` closure can build it; the synthesiser is created with the first utterance. Write callbacks convert to mono Float32 on the synthesiser's thread and hop to main with `DispatchQueue.main.async`, as does `didFinish`, which keeps them in order; only `didFinish` ends an utterance. The next utterance is submitted only when a pull finds no buffered audio and no utterance speaking. Utterances skip leading whitespace, so whitespace-only remainders submit nothing. A missing voice at speak time, a non-Float32 buffer or a sample-rate change fails the stream with `ProviderError.failed`. `cancel()` (and task cancellation of a pending `next()`) stops synthesis, clears buffered audio and makes every later pull throw `CancellationError`.
  - `Stream.remaining` is `private(set)` so the live check can observe that a paused reading submits nothing more; there is no other instrumentation.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'Apple|ReadingOperationTests|SpeechPlayerTests'`: 38 core tests in 7 suites (live and spike suites skip), 23 app tests in 2 suites.
  - `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice`: 18 tests in 3 suites (the spike suite still skips). Zoe and Jamie each read the 448-scalar paragraph to the end at one sample rate, chunks at most 100 ms, samples finite in -1...1, 18-35 s of audio; a paused reading keeps the same unsubmitted text over 2 s after submitting at most 250 scalars; a pending pull throws `CancellationError` within 100 ms of `cancel()`, and another reading then completes.
  - `swift test --disable-xctest`: 132 core tests, 71 app tests.
  - `git diff --check`, and no trailing whitespace in the new files.
- Known limitations or external checks:
  - Whether `availableVoicesDidChangeNotification` posts in the signed app after a System Settings download is unobserved; app activation also re-checks readiness. G2 covers "Downloading a voice in System Settings is picked up".
  - Not exercised live: a full 60,000-scalar reading, fallback to a non-offered voice, a voice removed mid-reading, and the reading through the real `Reader` and `SpeechPlayer` (workstream 6 registers Apple).
  - The speed range and the feel of both voices need Aidan's ears at G2. No audio was played.
- Specification drift: none.

## Independent review

- Reviewer: independent reviewer, fresh session (Claude Opus 5.5).
- Verdict: Accept. No Required findings. Every acceptance criterion is met and every targeted verification command passes.
  - Verification rerun on the uncommitted tree: `swift build` passes. `swift test --disable-xctest --filter 'Apple|ReadingOperationTests|SpeechPlayerTests'` passes 38 core tests in 7 suites and 23 app tests in 2 suites, with the live and spike suites skipped. `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice` passes 18 tests in 3 suites, rendering silently in about 7 s. `git diff --check` is clean.
  - Ownership: the changes are limited to the new `Providers/Apple/AppleVoice.swift`, the voices-notification hookup in `Apple.swift:19-28`, the two new test files, and the lead's plan row. The spike folder is untouched, and nothing outside `Providers/Apple/` or the tests changes.
  - Contract: `Stream` follows `SpeechStream` (`Provider.swift:309-316`):
    - one consumer, enforced at `AppleVoice.swift:199`,
    - mono Float32 chunks of at most 100 ms at one rate (`AppleVoice.swift:138-164`, `144`),
    - the next utterance is submitted only when a pull finds no buffered audio and nothing speaking (`AppleVoice.swift:226-229`),
    - the end comes only from `didFinish` (`AppleVoice.swift:210-216`),
    - `cancel()` is idempotent and makes pending and later pulls throw (`AppleVoice.swift:206-208`, `268-275`), and task cancellation of `next()` routes to it (`AppleVoice.swift:203`).
  - Lifecycle: the synthesiser's delegate is weak, and the write and finish callbacks capture `self` weakly (`AppleVoice.swift:211`, `248-253`). `Reader` always cancels the stream when a run ends (`Reader.swift:85`), so a finished reading's final `cancel()` only stops an idle synthesiser.
  - Extra checks, run outside the repository and copying `nextUtterance` exactly: multibyte Latin text, ZWJ emoji, CJK sentences, and a single grapheme with 300 combining marks. Every case split without losing text, kept each utterance within 250 scalars, and never produced an empty utterance or a loop.
  - Extra checks, silent `write` rendering: every English voice family on this Mac produced Float32 buffers, including the zero-frame buffers. This covered premium, enhanced, compact, super-compact, Eloquence (16 kHz) and legacy `com.apple.speech.synthesis.voice.Albert`. Fallback to any of them therefore cannot hit the unsupported-format failure at `AppleVoice.swift:261`.
- Required findings: none.
- Optional observations:
  - O1. The live pause check (`AppleVoiceLiveTests.swift:42-51`) observes only `remaining`. By construction, `remaining` changes only inside `deliver()` on a pull (`AppleVoice.swift:227-228`), so the check confirms that a paused stream submits no text. It does not confirm that the synthesiser goes idle after the first utterance. That is enough for the acceptance criterion, and adding instrumentation would cost more than it is worth.
  - O2. `received` fails the stream for a non-Float32 buffer even when it has zero frames (`AppleVoice.swift:250`, `261-262`). The spike ignored the format of zero-frame buffers (`AppleSpikeSpeechStream.swift:143-151`). The silent probe above found no voice where this differs, so this is not a defect, only a stricter divergence from the reference.
  - O3. Jamie's anchors and their measurement method are recorded in the handoff (line 101) and summarised in the comment at `AppleVoice.swift:79-82`. The measuring test itself was deleted, which matches YAGNI. Re-measuring after workstream 6 deletes the spike would mean rebuilding a small opt-in render loop. The anchors cover 0.7...1.5, so G2 tuning inside that span needs no new measurement.
  - O4. For workstream 6: the voices-changed observer is registered lazily, the first time `Apple.changes` is touched (`Apple.swift:21-28`). Composing `Provider.apple.readiness.changes` from `Apple.changes` touches it before Settings follows, so no action is needed. Just do not replace that composition with a separate `Changes` instance.
- Questions: none.

## Resolution

- Finding dispositions: no Required findings, so no remediation pass ran. O1 and O2 accepted as they stand: the pause check meets the criterion, and the stricter format check matched every installed English voice in the reviewer's probe. O3 accepted: the calibration test stays deleted and the method is recorded above. `rate(speed:voice:)` clamps to the measured span 0.7...1.5, so if G2 tunes the range beyond it, workstream 6 must measure wider anchors with the recorded method rather than widen `speedRange` alone. O4 passed to workstream 6: compose `Provider.apple.readiness.changes` from `Apple.changes`, which also starts the voices-changed observer.
- Simplification/deletion pass: the implementation agent deleted its temporary calibration test; the lead found nothing further to remove. The only testing seam is `Stream.remaining` being `private(set)`.
- Final verification: lead reran `swift build`, `swift test --disable-xctest --filter 'Apple|ReadingOperationTests|SpeechPlayerTests'` (38 core tests, 23 app tests), `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice` (18 tests, silent render) and `git diff --check`; all pass.

## Closure review

- Reviewer: closure reviewer, fresh session (Claude Opus 5.5).
- Verdict: Accept. There were no accepted findings to resolve and no remediation pass, so this closure checks the uncommitted tree as the independent review saw it.
  - Tree: the same as reviewed. It contains `AppleVoice.swift`, the two voice test files (all new), the voices-notification hookup in `Apple.swift`, this packet and the plan row. The spike folder is unchanged.
  - Release-blocking check: none found. A re-read of `Stream` confirms these points:
    - only `didFinish` ends an utterance,
    - the next utterance is submitted only when a pull finds no buffered audio and nothing speaking,
    - `end` is idempotent, stops the synthesiser, clears buffered audio and resumes a pending pull with the error,
    - task cancellation of `next()` routes to `cancel()`,
    - callbacks capture `self` weakly.
  - Verification rerun:
    - `swift build`: passes.
    - `swift test --disable-xctest --filter 'Apple|ReadingOperationTests|SpeechPlayerTests'`: 38 core tests in 7 suites and 23 app tests in 2 suites pass.
    - `ECHOTYPE_APPLE_LIVE=1 swift test --disable-xctest --filter AppleVoice`: 18 tests in 3 suites pass, rendered silently in about 6.5 s.
    - `git diff --check`: clean, and the new files have no trailing whitespace.
- Remaining required findings: none. Optional observations O1 to O4 stay optional and were not promoted.
