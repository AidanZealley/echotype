# Workstream 2: Local cleanup candidates

Status: not started.

## Task packet

### Outcome

`swift run EchoTypeBench cleanup --provider local --candidate cleanup=<name>` downloads the
candidate's pinned weights on first use, loads and warms the model, and runs every cleanup sample
through the real `Reviser` with on-device MLX inference, for both `qwen3-4b-2507` and
`smollm3-3b`. A signed debug app bundle builds with MLX's resources staged.

### Scope

- **Dependencies.** Add MLX Swift LM (and through it MLX Swift) to `EchoTypeCore`, pinned to
  revisions that build with Swift 6.4 and the macOS 26 target. Research verified MLX Swift
  0.32.3 with MLX Swift LM at `5e46681`; start there. Record the pins and why in the handoff.
- **Packaging.** `scripts/build-app.sh` copies every `*.bundle` from the build's bin path into
  `Contents/Resources` before signing. CI downloads the Metal toolchain
  (`xcodebuild -downloadComponent MetalToolchain`) before building. See the spec's "Build
  verification".
- **Provider.** Under `Sources/EchoTypeCore/Providers/Local/`: the provider description, and
  `LocalCandidates.swift`, which holds both cleanup candidates' configuration and the build's
  selection and assembles the provider. Follow the plan's local provider contract, the spec's
  "Provider and candidate selection" and decision 0025's "Adding a provider". No new adapter
  protocol or factory framework.
- **Manifests.** One pinned manifest per candidate for the store from workstream 1. Resolve the
  full commit revision of `mlx-community/Qwen3-4B-Instruct-2507-4bit` and
  `mlx-community/SmolLM3-3B-4bit`, list only the files MLX Swift LM needs to load each, and
  record every file's size and SHA-256. Confirm and record each conversion's licence notice.
- **Readiness.** Cleanup is `.waiting` with download or loading progress in the message, such
  as "Downloading models, 1.2 of 3 GB" or "Loading the cleanup model", `.ready` only once the
  model is loaded and warmed, and `.unavailable` with the store's message on failure. A check
  starts setup by contract. Only the selected candidate is prepared.
- **Cleanup implementation,** shared by both candidates, following the spec's "Native
  integration" cleanup paragraph:
  - send `Reviser`'s prompt and window unchanged and return plain text;
  - greedy sampling, output capped near the window's token count;
  - SmolLM3's thinking disabled through its chat template's real flag;
  - the fixed prompt's KV cache prefilled once per loaded model and copied into each fresh
    request, with no history carried between requests;
  - cancellation checked between generation steps and during prompt prefill;
  - loaded weights reused across requests, inference kept off the main actor, and MLX's buffer
    cache limit set so cached buffers do not inflate the process footprint.
- **Bench.** `--provider local` and `--candidate cleanup=<name>` per the plan's bench arguments
  contract, with `run.json` recording the provider and candidate selection.
- Fixture tests only where logic is testable without a model, such as the output cap.

### Non-goals

- Registering the provider in `Providers.all`, Settings or any app UI.
- Local transcription or read aloud.
- Draft-model speculation, constrained decoding, or any cleanup prompt change.
- Measurement features (repeats, memory sampling, timing breakdowns); workstream 3 owns them.
- Changing the model store's behaviour; escalate a defect in it.

### Initial ownership

- `Package.swift` and `Package.resolved`.
- `Sources/EchoTypeCore/Providers/Local/`, except the workstream 1 store files.
- `scripts/build-app.sh` and `.github/workflows/ci.yml`.
- `Sources/EchoTypeBench/RunOptions.swift`, `RunInfo.swift` and `main.swift` (usage text).
- New focused tests under `Tests/EchoTypeCoreTests/`.

### Required seams

- Consumes workstream 1's store unchanged.
- Produces the plan's local provider, candidate names and bench arguments contracts, which
  workstreams 3 and 4 rely on.

### Acceptance criteria

1. The bench command in the outcome completes all 12 cleanup samples for each candidate with
   `--fast`, after downloading and verifying the weights on the first run.
2. A second run starts from the installed files without downloading.
3. Cleanup readiness reports download and loading progress, and reaches `.ready` only after the
   model is warmed.
4. Every manifest names a full commit revision, licence and per-file size and SHA-256, and lists
   only required files.
5. `run.json` for a local run records the provider and the cleanup candidate.
6. `Provider.local` is not in `Providers.all`; its transcription and voice report
   `.unavailable`.
7. Code outside `Providers/Local/` and the bench names no local candidate or model.
8. `scripts/build-app.sh debug` produces a bundle whose `Contents/Resources` holds MLX's resource
   bundle, and `codesign --verify` accepts it.
9. `swift test` and the release build of `EchoTypeApp` still pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast
swift run EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b --fast
scripts/build-app.sh debug .build/local-cleanup/EchoType.app
codesign --verify --deep --strict .build/local-cleanup/EchoType.app
ls .build/local-cleanup/EchoType.app/Contents/Resources
```

The first two bench runs download about 2.3 GB and 1.8 GB. Do not launch the built app.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Dependency pins and model revisions: `TBD`
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
