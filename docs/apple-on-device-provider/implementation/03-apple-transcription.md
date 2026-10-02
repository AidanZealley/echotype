# Workstream 3: Transcribe on the Mac with SpeechTranscriber

Status: accepted.

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

- Base commit: `4190666b71d42184aee5459a7859853d2f3e61c0`
- Outcome: `Providers/Apple/` holds the internal `Apple` namespace with language resolution, the shared change signal, an unregistered transcription service on `SpeechAnalyzer`/`SpeechTranscriber`, and the transcription readiness check. Fixture tests and an opt-in live check through the real `SessionMachine` pass.
- Files changed (all new):
  - `Sources/EchoTypeCore/Providers/Apple/Apple.swift`: `enum Apple` (internal), `Apple.transcription`, `Apple.changes`, `Apple.speechAssets`, `Apple.locale(for:)`, `Apple.Changes`.
  - `Sources/EchoTypeCore/Providers/Apple/AppleTranscriber.swift`: `Apple.Transcriber` (actor, `LiveTranscriber`), `Transcriber.module(for:)`, `Transcriber.supportedLocale(for:)`.
  - `Sources/EchoTypeCore/Providers/Apple/AppleTranscriptAssembler.swift`: `Apple.TranscriptAssembler`, pure, no framework types.
  - `Sources/EchoTypeCore/Providers/Apple/AppleSpeechAssets.swift`: `Apple.SpeechAssets` (actor) and its injectable `System`, with `System.live`.
  - `Tests/EchoTypeCoreTests/AppleTranscriptionTests.swift`: fixture tests (assembler, ending mapping, language, readiness with a fake `System`).
  - `Tests/EchoTypeCoreTests/Integration/AppleTranscriptionLiveTests.swift`: live checks gated by `ECHOTYPE_APPLE_LIVE=1`.
- Decisions:
  - Seams for 4-6:
    ```swift
    enum Apple {
      static let transcription: TranscriptionService      // keytermLimit 100
      static let changes: Changes                          // Readiness.changes = { Apple.changes.stream() }
      static let speechAssets: SpeechAssets                // transcription readiness
      static func locale(for tag: String) -> Locale        // bare tag -> deliberate region; regional tag kept
      final class Changes: Sendable { func stream() -> AsyncStream<Void>; func send() }
    }
    actor Apple.SpeechAssets { func check(language: String) async -> ServiceState }
    ```
    `Changes.stream()` returns a fresh stream per call (newest-one buffering) and drops the follower on termination; 4 and 5 call `Apple.changes.send()` when their setup starts, finishes or fails.
  - Language: `Apple.locale(for:)` maps bare tags through a fixed table (`en` -> `en-GB`) and keeps any tag with a region; an unmapped bare tag passes through unchanged. Each service checks support itself; transcription uses `SpeechTranscriber.supportedLocale(equivalentTo:)` on the result. Adding a language to the picker needs a region in `Apple.regions`.
  - Transcript: final segments append (the first one's leading whitespace dropped, later ones keep their own); volatile text replaces `provisional`, trimmed because the pill adds its own gap; utterance stays empty. Nonempty recognised text yields `.speech` after the transcript. No `SpeechDetector` module.
  - `.finished` is yielded only after `finalizeAndFinishThroughEndOfInput()` and after the results reader has drained, so the resolved tail precedes it.
  - `RecogRejected` is `SFSpeechErrorDomain` code 1 (observed in the spike's silence run). It becomes an empty `.finished` only when `finish()` was requested and committed text is empty; otherwise, and for every other error, `ProviderError.failed(localizedDescription)`. `CancellationError` passes through.
  - Readiness (`SpeechAssets.check`): `SpeechTranscriber.isAvailable` false -> `.unavailable("Transcription is not supported on this Mac")`; no supported locale -> `.unavailable("Transcription does not support this language")`; asset status `.installed`, or a setup that already succeeded this process -> `.ready`; an installation running (any locale) -> `.waiting("Downloading speech model")`; a failed setup for this locale -> `.unavailable("Speech model download failed")` once, then the next check retries; otherwise start the setup and return `.waiting`. Setup is one actor-owned `Task` (not the caller's, so it survives cancelled checks and provider switches) that calls `assetInstallationRequest` and runs `downloadAndInstall()` if a request exists. The change signal fires on setup start and end. Installation-request queries happen only there.
  - Successful setups are remembered because the research saw status say `supported` for a usable model until a request query ran; without it a status that never flips would loop setup on every change.
  - `Apple.transcription.start` throws `ProviderError.failed("Transcription does not support this language")` if the locale is unsupported; readiness normally prevents reaching it.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'`: 51 tests in 7 suites; live and spike suites skip.
  - `swift test --disable-xctest`: 120 core tests, 71 app tests.
  - `git diff --check`
  - Live: `ECHOTYPE_APPLE_LIVE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-synthetic/recording.wav swift test --disable-xctest --filter Apple`: 26 tests pass. English readiness `.ready` (installed); finish before ready and finish after 3 s of zero PCM both end `.nothing`; the synthetic recording inserts `"echo type lets me dictate notes. I use zust and and tan stack in my projects. The final words must survive when I stop recording."`, with committed text only growing across snapshots. The fixture was made with the research's commands; `afconvert` there does not resample, so the 22.05 kHz `say` audio is relabelled 16 kHz (16.568 s, as the research recorded).
- Known limitations or external checks:
  - Without `SpeechDetector` in the analyser, three seconds of zero PCM finished cleanly with no `RecogRejected` here; the spike (with the detector) still throws it. The rejection mapping is covered only by fixtures.
  - Not exercised: a real download, a failed download, an unsupported Mac or locale on a live run, cancellation during speech, and Test's five-second finalisation (the transcriber has no Test-specific path; spike measurements apply).
  - The live recording check asserts the final sentence only for the `echotype-s1-synthetic` fixture path; other recordings only need insertable text.
  - Speech authorisation on the signed build remains workstream 6's.
- Specification drift: none.
- Remediation (R1, O1; Q1 accepted as live evidence by the lead, no `SpeechAnalyzer` seam):
  - R1, `AppleTranscriber.swift`: results are read by a separate `reader` task started in `launch()`. A results error calls `fail(_:)` at once, which maps it through `ending(after:finishing:)` with `finishRequested` as it is at that moment, ends `events`, then `stop()`s: ends input and `finishing`, cancels worker and reader, and calls `cancelAndFinishNow()`. The worker therefore leaves `for await _ in finishing` and exits through `checkCancellation`, so it cannot hang. Worker errors take the same `fail(_:)` path. Whichever side fails first decides the ending; `AsyncThrowingStream` ignores later yields and finishes. The success path still awaits `reader` after `finalizeAndFinishThroughEndOfInput()` before `.finished`. `shutdown()` (close, `waitForClose`) finishes `events` without `.finished` and shares `stop()`. The local `reading` task and the duplicated teardown are gone.
  - O1, `AppleSpeechAssets.swift`: `check` reads `prepared` after `isInstalled`'s await, so a setup that ended during the awaits reports `.ready` and no second setup starts. This adds a status query for prepared locales, not an installation-request query.
  - Verification: `swift build`; `swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'` (51 tests pass, live suite skipped); `git diff --check` clean; live command with `/tmp/echotype-s1-synthetic/recording.wav` (26 tests pass, tail present, both "ends with nothing" cases pass).
  - Not tested: a mid-session results error (needs a `SpeechAnalyzer` seam, declined with Q1) and the O1 interleaving (needs a fake with a gated status query). The mapping itself remains covered by the `ending(after:finishing:)` fixtures.

## Independent review

- Reviewer: fresh independent review session (Claude Opus 5.5).
- Verdict: changes required (R1). Ownership is contained: only new files under `Providers/Apple/`, the two new test files, and this record and `plan.md`; the spike is untouched. Language, readiness, assembly, keyterms, early finish, close and join otherwise meet the packet. Verification rerun: `swift build`, `swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'` (51 tests pass, live suite skipped), `git diff --check` clean, and the live command with the synthetic fixture (18 tests pass; same inserted text as the handoff, tail present).
- Required findings:
  - **R1. A transcription failure during dictation is not reported until stop.** `AppleTranscriber.swift:63-69` reads `transcriber.results` in an unstructured task whose error is observed only at `try await reading.value` (line 80), which runs after `finish()`. `analyzer.start(inputSequence:)` (line 75) returns at once, so analysis failures arrive through `results`. A failure mid-dictation therefore ends transcripts silently: if nothing was heard, `SessionMachine`'s silence handling cancels quietly with no error; otherwise the session pauses and the failure surfaces only when the user stops. This breaks "framework errors map to `ProviderError`" and the contract's "Failures throw `ProviderError`" (`Provider.swift:201`). The late observation also makes `ending(after:finishing:)` read `finishRequested` (line 87) at catch time rather than when the error occurred, so a Code 1 raised before stop is classed as an empty finish if the user later stops. Fix: let a `results` error end `events` when it happens, through the same `ending(after:finishing:)` mapping, rather than waiting for the finish path.
- Optional observations:
  - **O1. A check can start a redundant setup.** `AppleSpeechAssets.swift:47-54` tests `prepared` before awaiting `system.locale` and `system.isInstalled`. A setup that finishes during those awaits leaves `installation` nil and `prepared` set, so the resumed check starts a second setup and its installation-request query. It is harmless in practice (the second request is nil), but checking `prepared` after the awaits avoids it at no cost.
- Questions:
  - **Q1. "Fixture tests show the resolved tail arrives before `.finished`" is met only by the live check.** The ordering lives in `AppleTranscriber.swift:78-81` and is exercised by `AppleTranscriptionLiveTests.swift:93`; `AppleTranscriptionTests.swift` covers assembly and error mapping but never `.finished`. Making it fixture-testable needs a seam over `SpeechAnalyzer` and its results, which is more machinery than the property warrants. Recommendation: accept the live evidence and record the deviation in Resolution, unless R1's fix naturally yields a testable seam.

## Resolution

- Finding dispositions: R1 accepted and fixed in the one remediation pass: a separate reader task ends `events` as soon as `results` throws, mapped with `finishRequested` as it stands then. O1 promoted to Required, since it bears on "starts at most one installation", and fixed by reading `prepared` after the awaits. Q1 resolved by the lead: "the resolved tail arrives before `.finished`" is evidenced by the live check rather than a fixture, because a fixture would need a seam over `SpeechAnalyzer` that the property does not justify. The mid-session error path and the O1 timing are covered by review, not tests, for the same reason. Closure's note that `waitForClose()` does not join the cancelled reader is accepted as harmless.
- Simplification/deletion pass: the worker's local reading task and the duplicated teardown in `run()`'s catch and `shutdown()` were replaced by one `fail(_:)` and one `stop()`.
- Final verification: lead reran `swift build`, `swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'` (51 tests), `git diff --check`, and the live command with `/tmp/echotype-s1-synthetic/recording.wav` (26 tests); all pass.

## Closure review

- Verdict: accepted. R1 is resolved: `AppleTranscriber.swift:61-62` starts a separate `reader`, whose results error calls `fail(_:)` at once (lines 92-94); `fail` maps it through `ending(after:finishing:)` with `finishRequested` as it stands then (line 100), ends `events` and `stop()`s (lines 146-152). `stop()` ends `finishing` and cancels the worker, so the worker leaves line 72 and exits through `checkCancellation` (line 73) rather than hanging, and its own `CancellationError` reaches an already finished stream. No await cycle: the worker awaits the reader only on the success path (line 76), and the reader never awaits the worker. The success path still drains results before `.finished` (lines 74-77). O1 is resolved: `AppleSpeechAssets.swift:47-49` reads `prepared` after both awaits; the extra cost is a status query, and installation-request queries stay in `install` (lines 60-66, 83-86). Verification rerun: `swift build`, `swift test --disable-xctest --filter 'Apple|SessionMachineTests|TranscriptionRequestTests'` (51 tests pass), `git diff --check` clean, and the live command with `/tmp/echotype-s1-synthetic/recording.wav` (26 tests pass, tail present, both "ends with nothing" cases pass). Not release-blocking: `waitForClose()` (lines 133-136) joins the worker but not the cancelled reader. After `close()` the reader can only touch the actor's assembler and an already finished `events`, so it has no visible effect.
- Remaining required findings: none.
