# Workstream 1: Parakeet Unified transcription

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Interface for workstream 2 (where a transcription candidate goes and what it supplies): `TBD`
- Decisions: `TBD`
- Dependency pins, model revisions and licences: `TBD`
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
