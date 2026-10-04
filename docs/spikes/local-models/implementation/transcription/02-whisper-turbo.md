# Workstream 2: Whisper Turbo transcription

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions (interval, settle rule, window bound, keyterms, speech evidence): `TBD`
- Dependency pins, model revisions and licence: `TBD`
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
