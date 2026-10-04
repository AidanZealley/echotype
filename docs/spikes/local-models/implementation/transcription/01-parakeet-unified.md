# Workstream 1: Parakeet Unified transcription

Status: accepted.

## Task packet

### Outcome

`swift run EchoTypeBench transcribe --provider local --candidate transcription=<name>` downloads
the candidate's pinned Core ML models on first use, loads and warms them, and runs every reviewed
dictation sample through a local `LiveTranscriber` with no contract violations, for both
`parakeet-unified` and `parakeet-unified-keyterms`. The run prepares no cleanup model. Local
cleanup still runs as it did.

### Scope

- **Dependency.** Add FluidAudio to `EchoTypeCore`, pinned to a release or revision that builds
  with Swift 6.4 and the macOS 26 target. Research checked FluidAudio at `0b1f462`; start there.
  Record the pin and why in the handoff.
- **Manifests,** one per pinned model, for slice 1's `ModelStore`:
  - the Unified streaming model at the 640 ms configuration (encoder `70_7_1`, INT8), with the
    decoder, joint and vocabulary it needs, from `FluidInference/parakeet-unified-en-0.6b-coreml`;
  - the voice activity model `VadManager` loads;
  - the CTC spotting model keyterm boosting needs (research names `parakeet-ctc-110m-coreml`),
    used only by `parakeet-unified-keyterms`.

  Resolve full commit revisions, list only the files FluidAudio reads (every file inside each
  `.mlmodelc`), and record sizes and SHA-256. Record each model's licence from the upstream
  model, not only the conversion card: Unified's upstream is NVIDIA's
  (`nvidia/parakeet-unified-en-0.6b`), and research found some conversion cards conflict with
  it. Record any conflict in the handoff; do not stop on it.
- **Loading.** Load from the store's directories, never through FluidAudio's own downloader.
  Record whether the first load compiles anything and where any compiled cache lives, with its
  size.
- **Transcriber,** one implementation for both candidates, following the spec's "Native
  integration" transcription paragraph and the plan's transcriber behaviour contract:
  - convert EchoType's 16 kHz mono Int16 PCM to the runtime's input;
  - derive utterance boundaries and `.speech` from FluidAudio's `VadManager` (Unified's
    streaming manager has no end-of-utterance signal);
  - show unsettled text as `provisional`; use `utterance` for text that is settled but not yet
    committed, if the runtime gives such a distinction (a suggestion, not a requirement);
  - `parakeet-unified` commits an utterance's text when the voice activity model ends the
    utterance. `parakeet-unified-keyterms` loads the CTC model, passes the request's keyterms to
    boosting and commits text only once its segment has been rescored (about 15 s, or at
    `finish`). Rescoring never rewrites committed text. Its `keytermLimit` is what boosting
    supports; record it and why;
  - on `finish()`, drain buffered audio, resolve and commit the tail, send a final `.transcript`
    if it changed, then `.finished`;
  - `close()` stops work promptly at any time, including during `finish()`, and
    `waitForClose()` joins it.
- **Provider.** In `Sources/EchoTypeCore/Providers/Local/`: a transcription candidate type
  alongside `CleanupCandidate`, both Unified candidates in `LocalCandidates.swift`,
  `LocalSelection.transcription`, and transcription readiness in `LocalProvider`, all per the
  plan's selection and readiness contracts. Make `LocalSelection`'s fields optional as the plan
  says, and `LocalSelection.build` name `parakeet-unified` and `qwen3-4b-2507`. Voice stays
  `.unavailable`. Only selected candidates are prepared. No new adapter protocol or factory.
- **Bench.** `--candidate <service>=<name>` per the plan's bench arguments contract, and the local
  selection each command uses: `transcribe` selects transcription only, `cleanup` cleanup only.
- Model-free tests only where logic is testable without a model and guards real behaviour, such
  as converting PCM or the commit rule over a scripted sequence of runtime outputs.

### Non-goals

- Whisper, read aloud, or any change to cleanup's behaviour.
- `Providers.all`, Settings or other app code (workstream 4).
- Offline re-decoding of settled utterances with Unified's batch encoder (a spec follow-up).
- Choosing between the two Unified candidates; workstream 5 measures them.
- Measurement features or reports (workstream 3). Changing the model store's behaviour.

### Initial ownership

- `Package.swift` and `Package.resolved`.
- `Sources/EchoTypeCore/Providers/Local/`, except the store files (`ModelStore.swift`,
  `ModelManifest.swift`, `ModelDownloadSource.swift`) and `CleanupModel.swift`.
- `Sources/EchoTypeBench/RunOptions.swift`, and the one-line call sites in `Transcribe.swift` and
  `Cleanup.swift` that pass the selection.
- `scripts/build-app.sh` only if FluidAudio's resources need more than the existing `*.bundle`
  copy.
- New focused tests under `Tests/EchoTypeCoreTests/` and `Tests/EchoTypeBenchTests/`.

### Required seams

- Consumes slice 1's store unchanged (handoff in [cleanup/01-model-assets.md](../cleanup/01-model-assets.md))
  and keeps local cleanup as built (handoff in [cleanup/02-local-cleanup.md](../cleanup/02-local-cleanup.md)).
- Produces the plan's selection, candidate names, bench arguments, transcriber behaviour and
  readiness contracts. Workstream 2 adds a candidate through the same shape, so the handoff names
  exactly where and how.

### Acceptance criteria

1. The outcome's command completes every reviewed dictation sample, paced, for each Unified
   candidate, with no contract violations in `report`. The first run of each downloaded and
   verified its models.
2. A second run starts from the installed files without downloading.
3. In a `transcribe` run, `preparation.json` shows only transcription setup and no cleanup model
   is loaded; in a `cleanup` run, no transcription model is loaded.
4. `parakeet-unified-keyterms` passes the sample's keyterms to boosting, and no committed text in
   either candidate's run ever changed (the bench records changed committed text).
5. Transcription readiness reports download and loading progress and reaches `.ready` only after
   the model is warmed.
6. Every manifest names a full commit revision, upstream licence and per-file size and SHA-256,
   and lists only required files.
7. `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast` still completes all 12
   samples.
8. Code outside `Providers/Local/` and the bench names no local candidate or model.
9. `scripts/build-app.sh debug` produces a bundle that holds every dependency resource bundle, and
   `codesign --verify` accepts it.
10. `swift test` and the release build of `EchoTypeApp` pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench transcribe --provider local --candidate transcription=parakeet-unified
swift run EchoTypeBench transcribe --provider local --candidate transcription=parakeet-unified-keyterms
swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast
scripts/build-app.sh debug .build/local-transcription/EchoType.app
codesign --verify --deep --strict .build/local-transcription/EchoType.app
ls .build/local-transcription/EchoType.app/Contents/Resources
```

Then `swift run EchoTypeBench report <run id>` for each transcribe run. Each paced run takes about
five minutes; use `--fast` while developing. Do not launch the built app.

## Implementation handoff

- Base commit: `79d5a900e3abbc49b8e1428d2b20675cd037dd4e`
- Outcome: all acceptance criteria met on the M1 Pro (Xcode 27.0, Swift 6.4, macOS 27.2), with the
  bench built in debug as the packet's commands do.
  - Criteria 1 and 2. First runs of each candidate downloaded and verified their models:
    `20261004T160153Z-local` (`parakeet-unified`, `--fast`, downloaded Unified and the voice model)
    and `20261004T160328Z-local` (`parakeet-unified-keyterms`, `--fast`, downloaded the CTC model).
    Paced runs over all 15 dictation samples, from installed files with no download line:
    `20261004T160810Z-local` (`parakeet-unified`: WER 6.9%, formatted WER 18.8%, keyterms 57.9%,
    0 violations, 0 errors) and `20261004T161305Z-local` (`parakeet-unified-keyterms`: WER 6.1%,
    formatted WER 16.5%, keyterms 84.2%, 0 violations, 0 errors).
  - Criterion 3. `preparation.json` of both transcribe runs holds only "Loading the transcription
    model"; `20261004T161747Z-local` (cleanup, `--fast`) holds only "Loading the cleanup model".
  - Criterion 4. Zero contract violations in both paced runs, and the check flags any committed text
    that did not only grow. Keyterms reach `VocabularyBoostingSession` as the request's list.
  - Criterion 7. `20261004T161747Z-local` completed all 12 cleanup samples (exact 8/11 scored, as
    slice 1).
  - Criteria 9 and 10. `scripts/build-app.sh debug` staged `FluidAudio_FluidAudio.bundle` with the
    three bundles that were already there (the existing `*.bundle` copy covers it; the script is
    unchanged) and `codesign --verify --deep --strict` accepted it. `swift test` and the release
    build of `EchoTypeApp` passed.
- Files changed:
  - `Package.swift`, `Package.resolved`: FluidAudio.
  - `Sources/EchoTypeCore/Providers/Local/`:
    - `LocalCandidates.swift`: `LocalSelection` with optional `transcription` and `cleanup` (and a
      public memberwise init), `TranscriptionCandidate`, both Unified candidates,
      `LocalCandidates.transcription`, and `Provider.local(_:)` resolving both names.
    - `LocalModel.swift` (was `LocalCleanup.swift`): the download, load and readiness lifecycle,
      generalised over the loaded runtime and any number of manifests. Cleanup uses it unchanged in
      behaviour, as does transcription.
    - `LocalProvider.swift`: `make(transcription:cleanup:)`; an unselected service is nil or
      `.unavailable`, voice stays `.unavailable`; `changes` merges both services' streams.
    - New: `ParakeetManifests.swift`, `ParakeetModel.swift` (load, warm, one session at a time),
      `ParakeetTranscriber.swift` (`LiveTranscriber` and its pipeline), `ParakeetTranscript.swift`
      (the pure commit rule).
  - `Sources/EchoTypeBench/RunOptions.swift` (per-service `--candidate`), one-line call sites in
    `Transcribe.swift` and `Cleanup.swift`, and the usage text in `main.swift`, which is outside the
    packet's ownership but would otherwise document `--candidate cleanup=` alone.
  - Tests: `LocalCleanupTests.swift` became `LocalModelTests.swift` (manifests of every candidate,
    unknown names, an unselected service, the download-failure readiness test over `LocalModel`);
    new `ParakeetTranscriptTests.swift` (commit rule, segment cut, PCM conversion).
- Interface for workstream 2:
  - A transcription candidate is one `TranscriptionCandidate` in `LocalCandidates.swift`:
    `name`, `manifests` (every model it needs, in the order its loader expects), `keytermLimit`,
    and `load: ([URL]) async throws -> Start`, where `Start` opens a session
    (`(TranscriptionRequest) async throws -> any LiveTranscriber`). Append it to
    `LocalCandidates.transcription`.
  - Nothing else changes for the provider: `Provider.local(_:)` resolves the name,
    `LocalProvider.make` wraps it in `LocalModel` (download progress summed over the manifests,
    "Loading the transcription model", `.ready` only after `load` returns), and the bench accepts
    `--candidate transcription=<name>` and lists the known names on a mistake.
  - `ParakeetTranscriber` is the template for a session: `send` only queues audio on an
    `AsyncStream`, a worker task owns all inference and yields every event, `finish()` ends the
    input, `close()` cancels the worker and finishes `events`, `waitForClose()` joins it.
    `ParakeetModel.start` stops and joins the previous session first, because the shared recogniser
    holds one session's state; a Whisper runtime that is stateless between sessions needs none of
    that.
  - Whisper adds WhisperKit to `Package.swift` (this workstream's pin stays), its manifests (the
    handoff's `ParakeetManifests` shows the format: every file of each `.mlmodelc`, size and SHA-256,
    from a resolved commit) and, for the app's build, nothing in `build-app.sh` unless WhisperKit
    ships a resource bundle the glob misses.
- Decisions:
  - Keyterm commit. FluidAudio's own boosting in `StreamingUnifiedAsrManager` cannot say which
    text it has rescored (`rescoredTranscript` is private, and a rescore that changes nothing
    emits nothing), so a commit rule built on it would either commit text it may still rewrite or
    wait for `finish()`. The transcriber instead runs the manager unboosted and rescores with the
    public `VocabularyBoostingSession.rescore` on the manager's cadence: once 15 s of audio sit
    behind the pending tokens, up to the last word boundary (the growing word is held back), and
    the rest at `finish()`. It commits exactly the rescored text. The cut and segment-local timings
    are re-implemented from FluidAudio's private helpers (about 25 lines).
  - Every uncommitted token is `provisional`; `utterance` is unused. Unified's tokens do not change
    once emitted, but with boosting they may be rewritten, and one rule for both candidates keeps
    the bench's first-provisional figure meaningful. Committed segments are joined with one space,
    as xAI's assembler does.
  - Utterance boundaries and `.speech` come from `VadManager.processStreamingChunk` at FluidAudio's
    defaults (voice at probability 0.85, an utterance ends after 0.75 s below the lower threshold).
    `.speech` is emitted for every 256 ms chunk at or above 0.85. Neither number is tuned. Without
    boosting, text therefore commits only at a pause of about a second; continuous speech commits
    nothing until the pause or `finish()`.
  - `keytermLimit`: 1 for `parakeet-unified` (the built-in term; boosting is off). 100 for
    `parakeet-unified-keyterms`. FluidAudio sets no limit; its rescorer changes thresholds above 10
    and above 100 terms and scans the terms linearly, so 100 keeps the tuned threshold tier and
    equals what Apple and xAI accept, so a saved list is not cut differently.
  - FluidAudio's boosting reads the CTC `tokenizer.json` from its own cache folder whatever loaded
    the model (`VocabularyBoostingSession` and `VocabularyRescorer.create` hard-code
    `CtcModels.defaultCacheDirectory`). `ParakeetModel` therefore links
    `~/Library/Application Support/FluidAudio/Models/parakeet-ctc-110m-coreml` to the store's
    verified directory when it loads the CTC model. An existing real folder there is left alone; a
    link already pointing at the store is left alone; a missing link is created and a link pointing
    elsewhere is repointed. This link now exists on this Mac. Workstream 4 should know the installed
    app writes it only when the selected candidate is `parakeet-unified-keyterms`, the only one that
    loads the CTC model; the build default `parakeet-unified` never touches the FluidAudio folder
    (no sandbox, so the keyterms candidate can).
  - `LocalCleanup` became the generic `LocalModel` rather than a second copy for transcription.
    The packet's "no new adapter protocol or factory" holds: it is one class, not a protocol.
  - Each bench command selects only its own service. A `--candidate` for the other service fails
    rather than being ignored. Workstream 3's dictation run prepares both and will extend
    `RunOptions.localSelection(measuring:)`.
- Dependency pins, model revisions and licences:
  - FluidAudio `0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7` (a revision: the newest tag predates
    Parakeet Unified). It builds with Swift 6.4 on the macOS 26 target, in debug and release.
  - `ParakeetManifests.unified`: `FluidInference/parakeet-unified-en-0.6b-coreml` at
    `d32e972dd4315f1dc3f6be28fb2aab0ab3e80358`: streaming encoder `70_7_1` INT8, decoder, single-step
    joint decision and `vocab.json`; 13 files, 608,529,377 bytes. Licence recorded as the NVIDIA Open
    Model License, which governs the upstream `nvidia/parakeet-unified-en-0.6b`. **Conflict:** the
    conversion's card says CC-BY-4.0. Not resolved here.
  - `ParakeetManifests.voiceActivity`: `FluidInference/silero-vad-coreml` at
    `b419383c55c110e2c9271fa6ee0ea83d03c70d96`, `silero-vad-unified-256ms-v6.2.1.mlmodelc`; 5 files,
    1,063,425 bytes. MIT (conversion and upstream `snakers4/silero-vad` agree).
  - `ParakeetManifests.keywordSpotting`: `FluidInference/parakeet-ctc-110m-coreml` at
    `accdafd8cf8a2ff1cabe3c11e54416b405d409aa`: `AudioEncoder.mlmodelc`, `MelSpectrogram.mlmodelc`,
    `vocab.json`, `tokenizer.json`; 12 files, 102,802,455 bytes. CC-BY-4.0 (conversion and upstream
    `nvidia/parakeet-tdt_ctc-110m` agree; attribution applies).
  - Sizes and hashes were taken by downloading each file at its revision and checking them against
    the repository's listing and LFS hashes.
  - First load compiles. Core ML compiles each model for the Neural Engine the first time a given
    executable loads it: about 20 s for the Unified encoder and 22 s for the CTC encoder in the debug
    bench (`20261004T160153Z-local` and `20261004T160328Z-local` preparation; the paced runs
    `20261004T160810Z-local` and `20261004T161305Z-local` paid it again because the binary had been
    rebuilt). The result is cached under `~/Library/Caches/<process name or bundle id>/
    com.apple.e5rt.e5bundlecache/<OS build>/`, about 19.6 MB for both candidates here. With an
    unchanged binary a load is about 1.1 s (`20261004T161904Z-local`). The installed app will pay the
    compile once per app build, so the first dictation after installing needs readiness to be
    honest about "Loading the transcription model" taking about 40 s with keyterms.
- Verification:
  - Passed: `swift build`; `swift test`; `swift build -c release --product EchoTypeApp`; both
    paced `transcribe` runs above; the `cleanup` run; `scripts/build-app.sh debug
    .build/local-transcription/EchoType.app`; `codesign --verify --deep --strict` on it; the
    `Contents/Resources` listing holds `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`,
    `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle` and `swift-transformers_Hub.bundle`.
  - `report` on each run prints no violations. Warm stop-to-final from the paced reports:
    p50 109 ms (`20261004T160810Z-local`) and 567 ms (`20261004T161305Z-local`, which rescores at
    `finish`). Warm first committed: p50 6819 ms unboosted and 8664 ms boosted (same runs). These are
    debug-build figures for orientation, not measurements.
- Known limitations or external checks:
  - Cancellation during `finish()` is not exercised by a test or a run; it follows from the worker
    being cancelled and checking between phases (`asr.finish()` and a rescore are not cancellable
    mid-call, each takes at most about a second).
  - Boosting can damage text: `dictation-question-command` went from WER 0.0% to 5.6% between
    the two paced runs, where a correct word was replaced by a keyterm. That is FluidAudio's rescorer
    on the corpus's keyterms; workstream 5 measures it.
  - The sampler's footprint (57 to 59 MiB peak in both paced runs, against 645 MiB in the first
    `--fast` run `20261004T160153Z-local`) does not reflect Core ML's resident weights reliably, so
    workstream 3 should check how memory is measured before relying on it for local transcription.
  - FluidAudio logs verbosely to stdout in debug builds, interleaved with the bench's lines.
  - Nested dependency bundles keep SwiftPM's ad hoc signatures (carried from slice 1).
- Specification drift: none. The spec's "keyterm boosting rescores in segments of about 15 seconds"
  is implemented with FluidAudio's rescorer on the same cadence rather than the manager's built-in
  hook, for the reason under Decisions.

## Independent review

- Reviewer: fresh independent review agent (Claude Sonnet 5.5), against base `79d5a90` and the
  uncommitted tree.
- Verdict: **Accept, no Required findings.** Every acceptance criterion holds; two Questions and
  a few Optional items follow.
- How it was checked:
  - Read the whole diff, the untracked files, FluidAudio's `StreamingUnifiedAsrManager`,
    `VocabularyBoostingSession`, `CtcModels` and `CtcTokenizer` at the pinned revision, and
    `Provider.swift`'s contract.
  - `swift build` and `swift test` (76 tests, 10 suites) pass. `codesign --verify --deep --strict`
    accepts the existing `.build/local-transcription/EchoType.app`, whose `Contents/Resources`
    holds `FluidAudio_FluidAudio.bundle` beside the three existing bundles. I did not rebuild it or
    the release app.
  - Paced runs: the implementation's runs predate its last edit to `ParakeetTranscriber.swift`
    (file times 17:05 against runs at 16:13 to 16:18, and `run.json` says `sourceDirty`), so I
    reran both candidates paced rather than trust the recorded ids. They reproduce the recorded
    results exactly: `20261004T164518Z-local` (`parakeet-unified-keyterms`: WER 6.1%, formatted
    WER 16.5%, keyterms 84.2%, 0 violations, warm stop-to-final p50 553 ms) and
    `20261004T164958Z-local` (`parakeet-unified`: WER 6.9%, formatted WER 18.8%, keyterms 57.9%,
    0 violations, p50 100 ms). Neither log has a download line, and `preparation.json` holds only
    "Loading the transcription model" (criteria 2 and 3). The recorded cleanup run
    `20261004T161747Z-local` (`--fast`) confirmed through `report`: all 12 samples, exact 8/11,
    as slice 1; I did not rerun it, because `LocalModel`'s check and load logic reads as the old
    `LocalCleanup` for one manifest and the run exists.
  - `20261004T162406Z-local` is my first keyterms attempt, which the harness killed after 3
    samples. It is incomplete, deliberately left in place and should not be cited.
- Acceptance criteria:
  1. Met (runs above). 2. Met. 3. Met for transcribe; the cleanup run holds only the cleanup
     message, and each command's selection leaves the other service nil.
  4. Met by construction and by the bench check: `ParakeetTranscript` only ever appends to
     `committed`, and a rescore replaces only pending tokens. Keyterms reach
     `VocabularyBoostingSession` as `request.keyterms`.
  5. Met: progress is summed over the manifests and `.ready` follows `warm()`.
  6. Met by reading the manifests: 40-hex revisions, licences, size and SHA-256 per file. I did not
     re-download to recheck hashes; the handoff says it did.
  7. Met (recorded run). 8. Met: `grep` finds candidate names only in `Providers/Local/`, the
     bench's `main.swift` usage text and tests. 9 and 10. Met as above, release build not rerun.
- Required findings: none.
- Optional observations:
  1. `ParakeetModel.linkTokenizer` is not idempotent. It removes and recreates the symlink on every
     load even when it already points at the right directory. Two processes loading at once
     (the bench while the app runs) can race between `removeItem` and `createSymbolicLink`, which
     throws and leaves that load `.failed` until relaunch. Returning early when the link already
     resolves to `directory` removes the race and the churn. It also repoints a symlink someone
     else made on purpose; refusing anything that is not already this store's link would be safer,
     at the cost of a visible failure.
  2. The handoff says the installed app "now writes" the link. It does so only when the selected
     candidate is `parakeet-unified-keyterms`, since only that candidate loads the CTC model; the
     build default `parakeet-unified` never touches `~/Library/Application Support/FluidAudio`.
     Workstream 4 should hear it that way.
  3. A failure building the boosting session in `ParakeetModel.start` (a missing or different
     `tokenizer.json` in a real folder left in FluidAudio's cache, per the "leave a real folder
     alone" rule) throws FluidAudio's own error. `Provider.swift` treats any non-`ProviderError`
     as a connection failure. Wrap it as `ProviderError.failed`. Warm-up already exercises this
     path, so it surfaces at readiness first and this is unlikely in practice.
  4. `ParakeetModel.start` serialises one session at a time by closing the one it remembers. Two
     overlapping `start` calls would both pass that check and share the recogniser. The
     coordinator never does this, so no change is needed now; Whisper's workstream should not copy
     the pattern if its runtime holds no per-session state. The model also keeps the last
     transcriber (and its up-to-3 s audio tail) alive until the next start.
  5. The model-free tests guard real behaviour: the join and grow rule, the word-boundary cut
     that holds back the growing word, PCM scaling and the odd trailing byte, manifest shape for
     every candidate, unknown names, an unselected service and the failed-download-stays-failed
     readiness path. The part most likely to be wrong, rebasing token times onto the retained
     audio and the 15 s trigger inside `Pipeline`, is private and untested, and only the paced
     keyterms run covers it (4/6, 5/5, 3/3 keyterms on the three keyterm samples). Extracting the
     rebase into `ParakeetTranscript` and testing it would be cheap but is not required.
  6. `Provider.local(_:)`'s nested generic `find` with a key path is heavier than two direct
     lookups would be, since `CleanupCandidate` and `TranscriptionCandidate` are the only two
     users. Taste only.
  7. `ParakeetManifests.swift` indents its `files:` entries four spaces further than
     `LocalCandidates.swift` does. Cosmetic.
  8. Edits to `Sources/EchoTypeBench/main.swift` are outside the stated ownership (plan.md gives
     the file to workstream 3 within this slice), but they are the usage text only, disclosed in
     the handoff, and without them the bench would document `--candidate cleanup=` alone. Accept;
     workstream 3 will edit the same text.
- Questions:
  1. The symlink in `~/Library/Application Support/FluidAudio/Models/parakeet-ctc-110m-coreml`.
     - Justified: `VocabularyBoostingSession.init` hard-codes `CtcModels.defaultCacheDirectory`
       for both `CtcTokenizer.load` and `VocabularyRescorer.create`, and offers no directory
       parameter. Without it, boosting finds no `tokenizer.json` and throws at session start.
     - Within the packet: it is not a download. The models still load through
       `CtcModels.loadDirect(from:)` from the store's verified directory, and `CtcTokenizer.load`
       does not fetch, it throws `tokenizerNotFound`. Nothing is downloaded and nothing is
       written into the store.
     - Safety: `removeItem` on a symlink removes only the link; `attributesOfItem` does not follow
       it, so a real folder is never touched; the target is the store's directory and is a
       read-only use. Residual risks are observation 1 and a dangling link if the store directory
       is later replaced by a revision bump (repointed on the next load, and another FluidAudio
       tool would see `modelsExist` fail until then).
     - The alternative is to stop using `VocabularyBoostingSession` and compose
       `CtcKeywordSpotter`, `VocabularyRescorer.create(ctcModelDirectory:)`, pre-tokenised terms
       and `ctcTokenRescore` ourselves, about 30 lines copied from the session's `rescore`. It
       would write nothing outside EchoType's directories, at the price of tracking more FluidAudio
       internals on each bump. I lean towards keeping the link with observation 1, but writing
       into another tool's cache is a product call the lead should make; it does change what
       workstream 4's installed app does on a keyterms build.
  2. The re-implemented rescoring cut and commit rule against "rescoring never rewrites committed
     text". The decision looks sound. `rescoredTranscript` is private and the manager emits a
     partial only when a rescore changes text, so its own hook cannot say what is final; and
     `ParakeetTranscript` can only grow `committed`, with rescored text replacing pending tokens
     before they commit. The re-implementation matches FluidAudio's `vocabSegmentCut` (cut before
     the last word start, nil for one word, everything at finish), `segmentLocalTimings` (rebase,
     clamped end), the 15 s trigger, the 1 s preroll and the single-space join, and drops only its
     "tokens without retained audio" guard, which cannot trigger here because audio is retained
     from session start. Two differences to know about: the idle audio window is 3 s here against
     one encoder window there, and a rescore result with empty text would drop those tokens
     (`commit(first:as:)` removes them either way), which I could not make happen. The
     question is whether the lead accepts about 25 lines of duplicated FluidAudio logic as the
     price of an honest commit rule; I would, and the handoff already records why.
- Boundaries, lifecycle and complexity:
  - Boundaries hold. Code outside `Providers/Local/` and the bench names no candidate (criterion
    8). The store files, `CleanupModel.swift` and `Providers.swift` are untouched, and
    `utterance` is deliberately unused with a stated reason.
  - `LocalCleanup` to `LocalModel` is a faithful generalisation. For one manifest `check()` returns
    the same states in the same order (missing starts then reports 0 of the total, downloading
    reports progress, failed is final and never restarted, installed starts the load once). The
    cleanup closure and `CleanupModel.load(from:templateContext:)` call are unchanged, and
    `LocalProvider.merged` cancels its followers on termination. Slice 1's behaviour is unchanged.
    The new multi-manifest path starts every missing manifest before it inspects any, so one
    failure leaves its siblings downloading. That is harmless and still honest.
  - `close()` during `finish()`: `close()` cancels the worker, ends the input and finishes `events`
    at once, so the consumer sees no more events; the worker leaves at the next `checkCancellation`
    (after `asr.finish()` and between sends). `asr.finish()` and a rescore are not cancellable
    mid-call, which is bounded by about a second here (stop-to-final p95 of 997 ms in
    `20261004T164518Z-local` with boosting). `waitForClose()` calls `close()` then joins the worker,
    and the next session's `start` closes and joins this one before resetting the shared
    recogniser. No leak or double-use found. It is untested, as the handoff says; a model-free test
    is not possible without a runtime seam, so I would not add machinery for one.
  - Unjustified complexity: none. The one new class (`LocalModel`) replaced a class; there is no new
    protocol or factory. The pipeline is a short worker with three named phases.
  - Behaviour to carry to workstream 5, not a defect: unboosted text commits only at a pause of
    about a second (warm first committed p50 6821 ms, p95 16412 ms in `20261004T164958Z-local`), and
    boosted text only at 15 s or `finish` (p50 8654 ms, p95 16921 ms in `20261004T164518Z-local`).
    Boosting also changed `dictation-question-command` from WER 0.0% to 5.6% in both pairs of runs.

## Resolution

- Finding dispositions:
  - Optional observation 1, promoted to Required by the lead: fixed. `linkTokenizer` returns when
    the link already resolves to the store's directory, so a normal load writes nothing; it removes
    and recreates only a link pointing elsewhere, and still leaves a real folder alone. If another
    process wins the race to create the link, a failed `createSymbolicLink` counts as success when
    the link then points at the store's directory (the removal of a stale link is `try?` for the
    same reason). Two processes disagreeing about the target is not handled: the loser throws.
  - Optional observation 2: the handoff wording is corrected (only `parakeet-unified-keyterms`
    writes the link).
  - All other findings and questions: not addressed in this pass.
- Lead triage: no Required finding from the independent review. The lead promoted Optional
  observation 1 (the symlink's non-idempotent rewrite and cross-process race) because it fails a
  load until relaunch and rewrites another tool's folder on every load. Accepted as is: the
  symlink into FluidAudio's cache (Question 1: a hard-coded path with no parameter, not a
  download, a read-only use of the store's directory; the alternative of recomposing FluidAudio's
  rescoring internals costs more to maintain), the re-implemented cut (Question 2), `main.swift`
  usage text (outside ownership but disclosed and workstream 3 edits it next), and the rest of
  the Optional items (3 to 7), which are deferred. Optional 4 matters to workstream 2: do not copy
  `ParakeetModel.start`'s one-session-at-a-time pattern if WhisperKit holds no per-session state.
- Simplification/deletion pass: `LocalCleanup` became the generic `LocalModel` instead of a second
  copy for transcription, and no protocol or factory was added; `utterance` stays unused. Nothing
  further removed.
- Final verification: the first paced runs recorded in the handoff predate a last edit to
  `ParakeetTranscriber.swift`, so the independent review's reruns on the final source are the
  runs to cite: `20261004T164518Z-local` (`parakeet-unified-keyterms`, paced: WER 6.1%, formatted
  WER 16.5%, keyterms 84.2%, 0 violations) and `20261004T164958Z-local` (`parakeet-unified`,
  paced: WER 6.9%, formatted WER 18.8%, keyterms 57.9%, 0 violations). `20261004T162406Z-local` is
  an incomplete run killed by the harness during review, left in place and not to be cited. The
  remediation pass: `swift build` and `swift test` (76 tests) pass.
  Keyterms `--fast` runs load without a download line: `20261004T165727Z-local` with the link
  already present (its modification time unchanged, so nothing was rewritten) and
  `20261004T165830Z-local` after `rm` of the symlink only, which recreated it pointing at the
  store's directory. Release build and the signed app were not rerun in this pass.

## Closure review

- Verdict: **Accept.** The accepted finding is fixed and the fix introduces no release-blocking
  defect.
- Remaining required findings: none.
- Accepted finding, checked by reading `ParakeetModel.linkTokenizer` (Optional observation 1,
  promoted to Required):
  - Idempotent: an existing symlink that already resolves to the store's directory returns before
    any write, so a normal load neither removes nor recreates it. Confirmed on this Mac: the link's
    modification time (17:58) did not change across the closure `--fast` keyterms run.
  - A real folder (any non-symlink) returns untouched, as before. `attributesOfItem` does not
    follow links, so a dangling link is still classed as a link and repointed.
  - Only a missing or stale link is written. The stale-link removal is `try?` and a failed
    `createSymbolicLink` counts as success when the link then points at the store's directory, so
    the two-process race the finding described no longer throws. Two processes with different
    targets still make the loser throw, as the Resolution states; that is not a release blocker.
  - No new defect found: the path comparison matches what `createSymbolicLink` stores
    (`directory.path`), the early return cannot skip creating a missing link (it is reached only
    when something exists at the path), and no code outside `linkTokenizer` changed.
- Verification rerun, all on the current tree:
  - `swift build` and `swift test` (76 tests, 10 suites) pass.
  - `swift build -c release --product EchoTypeApp` completes.
  - `swift run EchoTypeBench transcribe --provider local --candidate
    transcription=parakeet-unified-keyterms --fast`: run `20261004T170243Z-local` completes with 0
    contract violations, no download line, `preparation.json` holding only "Loading the
    transcription model", and `report` totals of WER 6.1%, formatted WER 16.5%, keyterms 84.2%
    (matching the paced figures).
  - Not rerun, as instructed: the paced runs, the cleanup run, and the signed app build.
