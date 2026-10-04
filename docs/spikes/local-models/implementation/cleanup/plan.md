# Local cleanup (slice 1) implementation plan

Status: draft; workstreams 1-2 accepted.

## Orchestration record

- Integration branch: `spike/local-models`
- Starting commit: `dac6a8906debed3fb7c140ea18176c926bb0f53e`
- Review command: `lead subagents`
- Specification approved at commit: `a8cabe1` (both specs approved 2026-10-03)
- Started: `2026-10-04`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Pinned model downloads](01-model-assets.md) | Approved spec | Accepted |
| 2 | [Local cleanup candidates](02-local-cleanup.md) | 1 | Accepted |
| 3 | [Bench measurement for local services](03-bench-measurement.md) | 2 | Not started |
| 4 | [Cleanup evaluation and results](04-cleanup-evaluation.md) | 3 | Not started |
| Final | [Whole-feature review](final-review.md) | 1-4 | Not started |

## Why these boundaries

1. **Pinned model downloads** is a self-contained store with its own failure modes
   (verification, partial files, interruption) and its own tests. Transcription and voice reuse
   it in later slices, so it stands on its own and nothing in it is thrown away.
2. **Local cleanup candidates** is the vertical slice that makes local cleanup run: the MLX
   dependency and its packaging, the provider skeleton, `LocalCandidates.swift`, the shared MLX
   cleanup implementation for both candidates, and the bench's way to reach them. These change
   together; none is reviewable alone.
3. **Bench measurement** adds what the spec's measurements need and the bench lacks: warm
   repeats, the memory and thermal sampler, readiness and cancellation timing, and deadline
   fallbacks. It is bench-only code, independently acceptable, and later slices reuse it.
4. **Cleanup evaluation and results** runs the comparison and writes the results record. It
   changes no product code, so its review checks method and conclusions.

Sequential throughout. Workstreams 2 and 3 both edit the bench's shared options, so they cannot
run in parallel.

## Cross-workstream contracts

- **Model store location.** Installed models live under
  `~/Library/Application Support/EchoType/Models/`, shared by the app and the bench. Files in
  progress live apart from installed ones, and nothing counts as installed until every file in
  its manifest is verified.
- **Manifest.** Each model's pinned file list records the repository, full commit revision,
  licence, and each required file's path, byte size and SHA-256. Workstream 2 supplies the real
  manifests; workstream 1 supplies the type and the store.
- **Store interface** (workstream 1, consumed by 2): ask a manifest's state (missing,
  downloading with bytes done and total, installed with its directory, or failed with a
  message), start its download (idempotent, at most one at a time per manifest, surviving a
  provider switch), and follow changes as an `AsyncStream` suitable for `Readiness.changes`.
  Tests can inject the download source.
- **Local provider.** Provider id `local`. Exposed as a public `Provider.local` built from the
  selection in `Sources/EchoTypeCore/Providers/Local/LocalCandidates.swift`, plus one public way
  to build it with a named cleanup candidate, used only by the bench. It is **not** in
  `Providers.all` during this slice. Its transcription and voice services report `.unavailable`
  with a message that they arrive in a later slice, and throw `ProviderError.unavailable` if
  called.
- **Candidate names.** `qwen3-4b-2507` (Qwen3-4B-Instruct-2507, MLX four-bit) and `smollm3-3b`
  (SmolLM3-3B, MLX four-bit, thinking disabled). The build's default selection is
  `qwen3-4b-2507`.
- **Bench arguments.** `--provider local` and `--candidate cleanup=<name>`; an unknown name fails
  with the list of known names. Every run's `run.json` records the provider and full candidate
  selection.

## Ownership handoffs

- `Sources/EchoTypeCore/Providers/Local/` is created by workstream 1 (the store) and extended by
  workstream 2. Workstream 2 may not change the store's behaviour; a defect in it is an
  escalation.
- `Sources/EchoTypeBench/RunOptions.swift` and `RunInfo.swift` pass from workstream 2 (candidate
  argument and selection record) to workstream 3 (repeats and timings).
- `docs/spikes/local-models/results.md` is created by workstream 4.

## Whole-feature acceptance

- Workstreams 1-4 accepted, with the xAI gate passed.
- `swift test` and `swift build -c release --product EchoTypeApp` pass.
- Pending outside this workflow, recorded in the completion report:
  - CI with the Metal toolchain step runs only when the branch is pushed.
  - Loading MLX inside the signed, installed app is first exercised in slice 2, when the app can
    select the local provider. This slice checks that the bundle is staged and signed.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| xAI cleanup baseline | Workstream 4 | After local and Apple runs, before writing results | Pending | `TBD` | Aidan's answer names a completed xAI cleanup run id |

## Escalations

None.

## Conventions learned

- `Readiness.check` calls `ModelStore.start` only when the state is `.missing`. `start` restarts a
  failed model and every state change yields on `changes()`, so starting a failed one would loop
  while offline. A failed model stays failed until relaunch. Hold one shared store per process.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-04 | The local provider stays out of `Providers.all` until local transcription exists. | The app should never list a provider that cannot dictate. | Aidan | 2 |
| 2026-10-04 | Include a paid xAI cleanup baseline, run by Aidan. | The spec uses xAI as the quality reference. The samples are hand-written, so nothing personal is sent. | Aidan | 4 |
| 2026-10-04 | EchoType downloads pinned files itself rather than using a runtime's downloader. | The spec requires an explicit file list, integrity checks and separate partial files. FluidAudio, WhisperKit and MLX each have their own downloader, and later slices need one store across runtimes. | Planning agent | 1, 2 |
| 2026-10-04 | The model store imports CryptoKit for SHA-256, beyond the packet's "Foundation and the standard library only". It also uses `Synchronization`, as the Apple adapter does. | Foundation has no SHA-256, and a hand-written one is worse. The criterion's intent is no third-party or EchoType dependency. | Lead (workstream 1) | 1 |
| 2026-10-04 | Store interface as built: internal `ModelStore` with synchronous `state(of:)`, `start(_:)` and `changes()`; manifest directory is `<name>-<revision>`, so a new revision never mixes with old files. `start` has no cancel and failures are in memory only, so a relaunch reports `.missing`. See the handoff in `01-model-assets.md`. | Smallest store meeting the packet. Workstream 2 consumes it unchanged. | Lead (workstream 1) | 2 |
| 2026-10-04 | The spec names MLX Swift LM as the cleanup dependency, but the library no longer bundles a tokenizer, so `swift-transformers` 1.3.4 is a third direct dependency of `EchoTypeCore`; `CleanupModel.swift` bridges its tokenizer to MLX Swift LM. MLX Swift LM `5e46681` has no tag, so it is pinned by revision (MLX Swift exactly 0.32.3). `build-app.sh` now stages three bundles (MLX, swift-crypto, swift-transformers Hub), not one. | Tokenization and the chat template need it; no other tokenizer is available. A reply that hits the output cap throws, because `Reviser` accepts any in-order subset and would insert text that lost its end. | Lead (workstream 2) | 3, 4 |
