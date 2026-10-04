# Workstream 2: Whisper Turbo transcription

Status: accepted.

## Task packet

### Outcome

`swift run EchoTypeBench transcribe --provider local --candidate transcription=whisper-turbo`
downloads Whisper large-v3-turbo's pinned Core ML models and tokenizer on first use, loads and
warms them, and runs every reviewed dictation sample through a local `LiveTranscriber` with no
contract violations. Both Unified candidates and local cleanup still run as before.

### Scope

- **Dependency.** Add WhisperKit (a product of Argmax's Swift runtime, `argmax-oss-swift`) to
  `EchoTypeCore`, pinned to a release that builds with Swift 6.4 and the macOS 26 target. It is
  likely to depend on `swift-transformers`, which slice 1 pins exactly at 1.3.4 for the cleanup
  tokenizer. If they cannot resolve together, moving the `swift-transformers` pin is allowed when
  local cleanup still builds, its tests pass and a cleanup bench run's final text is unchanged;
  record the move as drift. Changing cleanup code to accommodate it is an escalation.
- **Manifest.** One pinned manifest for `argmaxinc/whisperkit-coreml` folder
  `openai_whisper-large-v3-v20240930_626MB`, listing every file inside its `.mlmodelc`
  directories and the configuration WhisperKit reads, plus the tokenizer files WhisperKit would
  otherwise fetch from the Hugging Face hub at load time. Nothing may be fetched outside the
  store: the model must load with network access denied. Record revisions, sizes, SHA-256 and the
  licence (MIT weights per research; confirm).
- **Loading.** Load from the store's directory through WhisperKit's configuration, with its
  downloader off. Record whether the first load compiles or specialises anything for the Neural
  Engine, where that cache lives and its size.
- **Transcriber,** following the spec's "Native integration" transcription paragraph and the
  plan's transcriber behaviour contract. Whisper decodes windows of audio rather than streaming,
  so the adapter owns live handling:
  - buffer pushed audio (WhisperKit's own stream transcriber reads the microphone itself, so it
    cannot be used as is) and re-decode the unsettled audio at a steady interval;
  - commit a segment once it is settled, for example once later decodes agree on it or a pause
    follows it, and trim committed audio from the next decode so work stays bounded however long
    the dictation runs;
  - show the rest as `provisional`;
  - supply `.speech` from genuine speech evidence and keep decoding silence from producing text.
    Reusing workstream 1's voice activity model is a suggestion: it is pinned already and keeps
    speech evidence consistent across candidates;
  - pass keyterms as Whisper's prompt if the pinned WhisperKit supports a prompt on this decode
    path, and set `keytermLimit` to fit it; otherwise `keytermLimit` is 1. Record which;
  - on `finish()`, decode and commit the remaining audio, send a final `.transcript` if it
    changed, then `.finished`; `close()` stops work promptly at any time and `waitForClose()`
    joins it.

  Record the interval, settle rule and window bound chosen, and why.
- **Provider.** Add `whisper-turbo` to `LocalCandidates.swift` through the shape workstream 1's
  handoff describes. The build's selection stays `parakeet-unified`.
- Model-free tests only where logic is testable without a model and guards real behaviour, such as
  the settle rule over scripted decode results.

### Non-goals

- Changing the Unified candidates, cleanup, the model store, or the plan's contracts.
- `Providers.all` or app code. Measurement features (workstream 3).
- Distil-Whisper, other Whisper sizes, or tuning beyond a working, recorded configuration.

### Initial ownership

- `Package.swift` and `Package.resolved`.
- New Whisper files under `Sources/EchoTypeCore/Providers/Local/`, and `LocalCandidates.swift`.
- `Sources/EchoTypeBench/RunOptions.swift` only if a candidate name needs it.
- `scripts/build-app.sh` only if WhisperKit's resources need more than the existing `*.bundle`
  copy.
- New focused tests under `Tests/EchoTypeCoreTests/`.

### Required seams

- Consumes workstream 1's transcription candidate shape, selection and readiness (see its
  handoff) and slice 1's store, unchanged.

### Acceptance criteria

1. The outcome's command completes every reviewed dictation sample, paced, with no contract
   violations in `report`, after downloading and verifying the models on the first run.
2. With the models installed, a `--fast` run under
   `sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built bench binary loads
   and transcribes without errors.
3. A second run starts from the installed files without downloading.
4. No committed text changed in the paced run. The silence sample commits no words, or the
   handoff records what it committed and why speech gating cannot prevent it.
5. Both Unified candidates still pass a `--fast` transcribe run, and local cleanup a `--fast`
   cleanup run.
6. The manifest names a full commit revision, licence and per-file size and SHA-256, and lists
   only required files.
7. `scripts/build-app.sh debug` produces a bundle that holds every dependency resource bundle, and
   `codesign --verify` accepts it.
8. `swift test` and the release build of `EchoTypeApp` pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench transcribe --provider local --candidate transcription=whisper-turbo
swift run EchoTypeBench transcribe --provider local --candidate transcription=parakeet-unified --fast
swift run EchoTypeBench transcribe --provider local --candidate transcription=parakeet-unified-keyterms --fast
swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast
sandbox-exec -p '(version 1)(allow default)(deny network*)' "$(swift build --show-bin-path)/EchoTypeBench" transcribe --provider local --candidate transcription=whisper-turbo --fast
scripts/build-app.sh debug .build/local-transcription/EchoType.app
codesign --verify --deep --strict .build/local-transcription/EchoType.app
ls .build/local-transcription/EchoType.app/Contents/Resources
```

Then `swift run EchoTypeBench report <run id>` for the paced run. Do not launch the built app.

## Implementation handoff

- Base commit: `9059508f0cc9f159c4a3a561c9b81cfa322c7584` on `spike/local-models`.
- Outcome: all eight acceptance criteria passed on the M1 Pro, 16 GiB, macOS 27.2,
  Xcode 27.0 and Swift 6.4. The packet's debug bench commands were used. The build selection
  remains `parakeet-unified`; app registration is unchanged.
- Files changed:
  - `Package.swift` and `Package.resolved`: WhisperKit and its resolved dependency pins.
  - `LocalCandidates.swift`: the `whisper-turbo` candidate, its three manifests and keyterm limit.
  - New in `Sources/EchoTypeCore/Providers/Local/`: `WhisperManifests.swift`, `WhisperModel.swift`,
    `WhisperTranscriber.swift`, `WhisperTranscript.swift`, `WhisperVoiceWatcher.swift` and
    `WhisperLocalTokenizer.swift`.
  - New `Tests/EchoTypeCoreTests/WhisperTranscriptTests.swift`: two model-free tests protecting
    agreement, provisional replacement, immutable committed prefixes and final-tail commitment.
    `WhisperLocalTokenizerTests.swift` protects preparation failure for malformed local tokenizer files.
  - This handoff. The plan's status edit belongs to the lead.
- Decisions:
  - Decode after one second of new audio, combining audio queued during inference. Process that
    queue in 4096-sample VAD chunks so a burst cannot bypass the window bound. A leading segment
    commits when consecutive decodes agree on its text, excluding the last segment. A pause at
    the end of the queued batch commits the whole decode. Historical pauses followed by more
    queued speech do not cause separate decodes.
  - Flush and commit at 28 seconds of unsettled audio, then clear it even when Whisper returned
    no segments. The largest decode input is below 28.256 seconds, leaving room below Whisper's
    fixed 30-second encoder window. This bounds work without extra overlap or merge machinery.
    The forced boundary can commit a still-growing word; agreement and pause commitment remain
    preferable when they happen first. Agreement trims through the committed segment's timestamp.
  - Keep one second of preroll before speech. `.speech` comes from Silero VAD evidence, once per
    processed batch that contains a chunk at or above FluidAudio's default 0.85 threshold. A
    pause uses its default 0.75 seconds below the lower threshold. Decode only audio that has
    speech evidence. Pad a final partial VAD chunk with silence so short trailing speech can
    receive evidence before the final decode.
  - `finish()` drains queued audio, decodes and commits the tail, emits any changed transcript,
    then `.finished`. `close()` cancels the worker, closes its wake and event streams, and
    `waitForClose()` joins it. Cancellation is checked between VAD chunks and before and after
    decoding. WhisperKit also checks before feature, encoder and decoder predictions.
  - WhisperKit's `promptTokens` path supports keyterms. Supply the comma-separated terms with a
    64-token cap and advertise `keytermLimit: 12`; long terms can exhaust the token budget before
    all twelve fit. Use the request's language and greedy decoding. Disable temperature fallback
    retries and the first-token confidence rejection, which otherwise dropped uncertain window
    starts in the recovered runs. Inputs shorter than 1.5 seconds receive silence padding because
    WhisperKit skips seek windows shorter than one second.
  - Load the tokenizer through the local-only `WhisperLocalTokenizer` adapter before constructing
    WhisperKit. A local error propagates and cannot enter the runtime's Hub fallback. The pinned
    runtime wrapper initializer is internal; the small dependency adapter delegates tokenization
    and preserves its special tokens and word splitting. See Resolution for decoder setup.
    Load from the store's explicit model directory with `download: false`, then
    warm with two seconds of silence. Use WhisperKit's default compute units: CPU/GPU for the mel
    model and CPU/Neural Engine for encoder and decoder. Share the loaded runtime but stop and
    join the previous session before a new one, because WhisperKit mutates shared decoder and
    progress state. Each session owns fresh VAD and transcript state.
  - Recovery retained the sound manifests, dependency setup, loader and transcript assembler.
    Restored `ParakeetModel.swift` and `ParakeetTranscriber.swift` byte-for-byte to the base rather
    than accepting the interrupted shared-watcher extraction. Whisper owns its small VAD watcher.
    The simplification pass removed the unused `leavingLast` commit mode and redundant post-clear
    preroll logic. No new factory, protocol, flag or compatibility alias was added.
- Dependency pins, model revisions and licence:
  - `argmax-oss-swift` exactly 1.1.0, revision `1e2a163736dfa5a198e637ae44c114e1c6d5cc2d`,
    product `WhisperKit`. Its resolved `swift-argument-parser` is 1.8.2 at
    `6a52f3251125d74daf04fcbd5e6f08a75d074382`. WhisperKit vendors its tokenizer and Hub code;
    the existing `swift-transformers` 1.3.4 pin did not move.
  - Weights: `argmaxinc/whisperkit-coreml` at
    `0f63a7800b00dd0226abd051b906c246e1907482`, folder
    `openai_whisper-large-v3-v20240930_626MB`, 15 files and 626,714,322 bytes.
    The [pinned conversion card](https://huggingface.co/argmaxinc/whisperkit-coreml/blob/0f63a7800b00dd0226abd051b906c246e1907482/README.md)
    and [upstream turbo card](https://huggingface.co/openai/whisper-large-v3-turbo) declare MIT.
    Every file in the three `.mlmodelc` directories is included. WhisperKit does not read this
    artifact's `config.json` or `generation_config.json`, so both are excluded.
  - Tokenizer: `openai/whisper-large-v3` at `06f233fe06e710322aca913c1bc4249a0d71fce1`,
    `tokenizer.json` and `tokenizer_config.json`, 2,763,460 bytes.
    The [pinned card](https://huggingface.co/openai/whisper-large-v3/blob/06f233fe06e710322aca913c1bc4249a0d71fce1/README.md)
    declares Apache-2.0. This is the large-v3 tokenizer WhisperKit selects for these weights.
  - Sizes and SHA-256 values are recorded per file in `WhisperManifests.swift`. Compared the
    pinned repository's file list with the manifest and independently rechecked all 17 installed
    files after the final fresh download. The existing Silero manifest is reused unchanged.
- Verification before remediation, retained for fresh-download and cache evidence. Final accepted
  source verification is in Resolution and Closure review:
  - `swift build`, `swift test` with 139 core, 17 bench and 76 app tests, and
    `swift build -c release --product EchoTypeApp` passed.
  - Fresh-download paced Whisper: `20261004T185421Z-local`, all 15 reviewed samples, 0 errors and
    0 contract violations. `report` gives WER 3.6%, formatted WER 13.7%, keyterms 94.7%,
    hallucinations 0 and no silence insertions. The trailing-words sample has WER 0.0%.
    Committed text never changed. Warm stop-to-final p50/p95 is 3527/4925 ms, n=14; warm first
    committed p50/p95 is 11539/26852 ms, n=13. These are debug verification figures, not the
    release evaluation in workstream 5.
  - First-download proof: moved only the two Whisper installed directories aside before that
    paced command. Its `preparation.json` records download progress followed by loading, with
    52,559 ms downloading and 128,985 ms loading/warming. The store verified the fresh files;
    independent size and SHA-256 verification also passed. Removed only the verified set-aside
    Whisper copies afterward. No run directory was deleted.
  - Installed, network-denied Whisper: `20261004T185949Z-local`, the exact packet sandbox profile
    and built bench binary, all 15 samples, 0 errors and 0 violations. Preparation records only
    loading, 3.209 seconds, proving the second run used installed files without downloading.
  - Unified `--fast`: `20261004T190142Z-local`; Unified keyterms `--fast`:
    `20261004T190254Z-local`. Both completed all 15 samples with 0 errors and 0 violations.
  - Qwen3 cleanup `--fast`: `20261004T190359Z-local`, all 12 samples. Its final text is identical
    for every sample to slice 1's `20261004T105222Z-local`, repeat 0.
  - `scripts/build-app.sh debug .build/local-transcription/EchoType.app` and
    `codesign --verify --deep --strict` passed. Resources contain `AppIcon.icns`,
    `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle` and
    `swift-transformers_Hub.bundle`. The existing bundle-copy script covers every dependency;
    WhisperKit adds no separate resource bundle. The app was not launched.
  - Earlier run `20261004T183939Z-local` is retained but failed the long sample's 30-second final
    deadline because a queued clip decoded every historical pause. It is not acceptance evidence.
    Coalescing pauses and using the 28-second bound fixed this; the focused network-denied probe
    `20261004T184706Z-local` completed the long sample in 12.778 seconds with 0 violations before
    the final full reruns.
- Core ML cache:
  - The supplied models are already `.mlmodelc`; loading still generates runtime specialization
    files. During the final fresh load, a new entry under
    `~/Library/Caches/EchoTypeBench/com.apple.e5rt.e5bundlecache/26B5091g/` occupied 135,110,921
    logical bytes. Its directory is
    `DAF128C0AA9AD68C5F62B80DA93219E3360C8E4E9616D4FE21DE9AACF34769E8`, containing an `H13S.bundle`
    with `main_ane/model.anehash`, `main_bnns/bnns_program.bnnsir` and `H13S.e5`.
  - At that snapshot the complete process cache was 286,176,435 logical bytes, 279,544 KiB
    allocated. It includes earlier candidates and cache entries, so this is not Whisper's
    exclusive disk cost. Core ML can remove or replace these entries. System-wide ANE caches
    and transient peak disk use were not measured.
- Known limitations or external checks:
  - Forcing a window boundary and the VAD threshold can affect recognition; the recorded corpus
    is the verification evidence, not a guarantee for arbitrary speech. The remaining text is
    always provisional, and `utterance` is unused.
  - A Core ML prediction cannot be interrupted midway. Cancellation stops between predictions;
    physical cancellation latency and the signed app's cache were not measured here.
  - Signed-app microphone, Settings, dictation and offline relaunch checks belong to workstream 4.
    First load after reboot or cache eviction, energy and Developer ID notarisation remain
    untested as the plan records. No app was launched and no paid xAI run was made.
- Specification drift: none. Unified and cleanup code, the model store, the build selection,
  provider registry and app code are unchanged.

- Lead acceptance: the required local-tokenizer fallback fix is closed. Final paced run
  `20261004T192341Z-local` and closure offline run `20261004T193806Z-local` complete all 15
  samples with no errors, violations, changed committed prefixes or silence insertions. Builds,
  tests, regressions and bundle verification passed. Optional speech-event latency remains for
  workstream 4 to observe; overlapping starts are outside the coordinator's single-caller use.

## Independent review

- Reviewer: fresh Codex independent reviewer, against base
  `9059508f0cc9f159c4a3a561c9b81cfa322c7584` on `spike/local-models`. Applied the unslop skill.
- Verdict: Accept. No Required findings. Two Optional observations and one Question for the lead.
- Verification:
  - Reran `swift build`, `swift test` and `swift build -c release --product EchoTypeApp`; all
    passed. Reran the packet's exact network-denied built-binary command, producing
    `20261004T191226Z-local`: all 15 samples, no errors or contract violations, empty silence.
    Preparation recorded loading only. This proves installed-file reuse without downloading.
  - Reran `swift run EchoTypeBench report 20261004T185421Z-local`; it matches the handoff's
    paced results. Independently inspected every event in that run and the recorded offline and
    two Unified fast runs: all have 15 results, no errors or violations, immutable committed
    prefixes and empty silence. Compared the 12 cleanup final texts in `20261004T190359Z-local`
    with repeat 0 of slice 1's `20261004T105222Z-local`; every text matches.
  - Reused the implementation's fresh-download paced and Unified/cleanup fast commands rather
    than repeat those experiments. Source modification times precede the cited commands, and
    the full uncommitted diff matches the handoff's final implementation. The fresh run's
    preparation file records download followed by loading. No model or run was deleted.
  - Independently hashed and size-checked all 17 installed Whisper files against the manifests.
    Compared the pinned remote repository's complete compiled-model file list with the manifest;
    all 15 model files match exactly. Confirmed MIT in the pinned conversion card and Apache-2.0
    in the pinned tokenizer card. Checked WhisperKit's actual loading path, prompt processing,
    greedy defaults and cancellation checks in the pinned checkout.
  - Reran `scripts/build-app.sh debug .build/local-transcription/EchoType.app`, then
    `codesign --verify --deep --strict` and the resource listing. All passed; all four dependency
    resource bundles listed in the handoff are present. `git diff --check` passed.
- Acceptance criteria, individually:
  1. Met. The fresh-download paced run completes every reviewed sample; its independently rerun
     report has zero violations and the preparation record shows downloading and warming.
  2. Met. The review's own network-denied fast run loads and transcribes all 15 samples.
  3. Met. Both recorded and review offline runs show loading only, with installed files verified.
  4. Met. Paced event inspection finds no changed committed prefix; silence commits nothing.
  5. Met. Both recorded Unified fast runs have zero errors/violations; cleanup matches slice 1.
  6. Met. Full revisions, licences, sizes and hashes are explicit. WhisperKit loads the three
     compiled models and two local tokenizer files; it does not read the omitted model configs.
  7. Met. Rebuilt bundle contains all dependency resources and passes strict signature checks.
  8. Met. Tests and release app build pass on the reviewed source.
- Boundaries and ownership: the complete tracked diff and every untracked source/test file are
  within this packet. The only plan edit is the lead's Review status. Unified, cleanup, model
  store, app code and provider registry are unchanged. The build selects `parakeet-unified`.
- Lifecycle and simplicity: `finish()` can precede readiness and drains the inbox and VAD tail
  before final commitment and `.finished`. Repeated close cancels and finishes streams, and
  `waitForClose()` joins the worker. Cancellation checks surround decode and run between VAD
  chunks, with upstream checks before Core ML predictions. Session state is fresh and the prior
  session is joined before sequential reuse. Decode input stays below 28.256 seconds even for
  fast delivery. Agreement leaves the growing segment provisional and trims only committed
  audio. The focused transcript tests protect observable settle behaviour. No added abstraction
  or speculative configuration warrants deletion.
- Required findings: none.
- Optional observations:
  1. Speech events wait for the batch's decodes. `Pipeline.hear` accumulates VAD evidence but
     returns `.speech` only after `decode` completes. This delays the session's speech and pause
     bookkeeping by inference time. The paced verification's largest gap between speech events
     is 6339 ms, below the default 10-second silence timeout, so no failure is demonstrated.
     Workstream 4 should watch pause behaviour while speaking, especially under concurrent load.
  2. `WhisperModel.start` inherits the existing single-caller assumption: overlapping starts
     could both join the same previous session and then create sessions sharing WhisperKit.
     The coordinator does not start concurrent dictations, as workstream 1's review already
     records, so additional serialization is unnecessary for this spike.
- Questions:
  1. Does the prohibition on runtime downloads include recovery from an unreadable installed
     tokenizer? In pinned WhisperKit, `ModelUtilities.loadTokenizer` catches a local tokenizer
     load error and falls back to the Hub independently of `WhisperKitConfig.download: false`.
     The valid, verified pinned tokenizer always loads locally, including the review's denied
     network run, so the tested configuration meets the acceptance criteria. This fallback could
     fetch outside the store if an installed tokenizer becomes unreadable. If the rule is meant
     to cover that failure too, load the tokenizer explicitly before model initialization and
     propagate its error, avoiding WhisperKit's fallback. No corruption experiment was run.

## Resolution

- Lead triage: Question 1 is Required. The packet says nothing may be fetched outside the store; the pinned runtime catches local tokenizer failures and invokes the Hub despite `download: false`. Use a direct local tokenizer load that propagates failure. Optional observations 1 and 2 remain deferred, with pause behaviour to watch in workstream 4.
- Fix: `WhisperModel.load` first loads the store tokenizer through the pinned runtime's public
  `AutoTokenizerWrapper.from(modelFolder:)`. Local read, parse and vocabulary failures propagate
  before model initialization. It creates WhisperKit with `load: false`, supplies that tokenizer,
  then loads the models. `loadTokenizerIfNeeded` returns immediately, so its Hub fallback is
  unreachable. No preflight followed by fallback-capable loading is used.
- Dependency adapter: WhisperKit 1.1.0 makes `WhisperTokenizerWrapper.init` internal, and its
  public `ModelUtilities.loadTokenizer` accepts no injected Hub or offline policy. The contained
  `WhisperLocalTokenizer` conformance delegates encoding, decoding and vocabulary access to
  `TokenizerWrapper`, derives the pinned special/language tokens, and preserves upstream Unicode,
  language, space and punctuation word splitting. Required vocabulary tokens must exist.
  Word timestamps remain off. No runtime fork or dependency change was needed.
- Decoder setup: supplying a tokenizer also skips WhisperKit's variant detection. After loading,
  the adapter verifies the pinned decoder's 51866-token large-v3 vocabulary and restores
  `textDecoder.isModelMultilingual = true`, preserving language/task prompting and logits filters.
  WhisperKit's private-set `modelVariant` remains its initial `.tiny`; inspection of every use in
  the pinned checkout confirms it affects tokenizer selection and logging only. Tokenizer selection
  is supplied explicitly and logging is disabled, so this does not affect inference.
- Simplification/deletion pass: the adapter is the only added dependency boundary. Removed the
  tokenizer search-folder configuration, since loading now names the store directory directly.
  No extra factory protocol, retry, flag, fallback or generic model configuration was introduced.
  Word splitting omits upstream's unused offset and unused punctuation helper. The one model-free
  test protects failed preparation with malformed local tokenizer files, before model loading.
- Final verification, all on the remediated source:
  - `swift build`, `swift test` with 140 core, 17 bench and 76 app tests, and
    `swift build -c release --product EchoTypeApp` passed. The malformed local-tokenizer test
    passed; its local error propagates without constructing WhisperKit.
  - Packet paced Whisper run `20261004T192341Z-local` completed all 15 samples with 0 errors,
    0 violations and no changed committed prefix. `report` passed and gives WER 2.9%, formatted
    WER 13.5%, keyterms 94.7%, hallucinations 0 and no silence insertions. Warm stop-to-final
    p50/p95 is 3252/4780 ms, n=14; warm first committed p50/p95 is 11386/31182 ms, n=13.
    These are debug verification figures. Preparation records loading only.
  - Exact packet network-denied built-binary run `20261004T192905Z-local` completed all 15
    samples with 0 errors, 0 violations, immutable committed prefixes and empty silence.
    Preparation contains loading only, taking 3.239 seconds, proving installed-file reuse.
  - Both packet Unified `--fast` reruns passed all 15 samples with 0 errors and violations:
    `20261004T193114Z-local` unboosted and `20261004T193221Z-local` keyterms.
    Qwen3 cleanup `--fast` run `20261004T193325Z-local` completed all 12 samples; every final text
    matches repeat 0 of slice 1's `20261004T105222Z-local`.
  - `scripts/build-app.sh debug .build/local-transcription/EchoType.app`,
    `codesign --verify --deep --strict` and the packet resource listing passed. Resources contain
    `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`,
    `swift-crypto_Crypto.bundle` and `swift-transformers_Hub.bundle`. `git diff --check` passed.
  - Prior fresh-download and independent manifest/hash evidence remains applicable: manifests,
    dependency pins, model store and download path are unchanged. No model redownload was needed.
    No app was launched, no paid xAI run was made and no run directory was deleted.

## Closure review

- Verdict: Accept. The accepted Required finding is fixed; the remediation introduces no
  release-blocking defect. Applied the unslop skill.
- Required finding closure: traced `WhisperLocalTokenizer.load` through the pinned public local
  factory to file reads and configuration parsing. This path propagates local errors and contains
  no Hub snapshot or fallback. `WhisperModel.load` completes it before constructing WhisperKit.
  The supplied tokenizer makes `loadTokenizerIfNeeded` return before its fallback; `load: false`
  and `download: false` prevent earlier runtime loading or downloading. The malformed local
  tokenizer preparation test passed in the full test rerun.
- Decoder preservation: compared every special-token mapping and language-token filter with
  pinned `WhisperTokenizerWrapper`. Unicode grouping, language normalization, space splitting
  and punctuation splitting match upstream, with only its unused offset/helper omitted.
  Encoding, decoding and vocabulary lookup delegate to the same runtime wrapper. Supplying the
  tokenizer also synchronizes it to the decoder. The 51866-logit guard and restored multilingual
  flag preserve large-v3 language/task prompting and logits filters. Checked all pinned
  `modelVariant` uses; the unchanged initial value affects tokenizer selection and logging only,
  both already handled by the explicit tokenizer and disabled logging. Word timestamps are off.
- Verification rerun:
  - `swift build`, `swift test` and `swift build -c release --product EchoTypeApp` passed.
  - The exact packet network-denied built-binary command produced `20261004T193806Z-local`.
    All 15 samples completed with zero errors or contract violations, immutable committed
    prefixes and empty silence. Preparation records loading only, taking 3.449 seconds.
  - Reran the paced report for `20261004T192341Z-local`; its WER 2.9%, formatted WER 13.5%,
    keyterms 94.7%, zero hallucinations and zero silence insertions match the Resolution.
  - Rebuilt the debug app, verified it with `codesign --verify --deep --strict`, and listed its
    resources. All four dependency bundles and `AppIcon.icns` are present. `git diff --check`
    passed. The app was not launched.
- Reused final-source experiments: all Whisper source modification times precede the remediated
  paced, offline and regression runs. Independently inspected all events in
  `20261004T192341Z-local`, `20261004T192905Z-local`, `20261004T193114Z-local` and
  `20261004T193221Z-local`; each has 15 results, no errors/violations, immutable committed
  prefixes and empty silence. All 12 final texts in cleanup `20261004T193325Z-local` match
  slice 1's `20261004T105222Z-local`, repeat 0. The prior fresh-download evidence remains valid
  because manifests, dependency pins, store and download path are unchanged. No redundant
  download or paced repeat was needed. No paid xAI run or run deletion was performed.
- Remaining required findings: none. The two Optional observations remain deferred as triaged.
