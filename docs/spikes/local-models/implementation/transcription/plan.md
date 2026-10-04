# Local transcription (slice 2) implementation plan

Status: approved; implementation in progress.

## Orchestration record

- Integration branch: `spike/local-models`
- Starting commit: `79d5a900e3abbc49b8e1428d2b20675cd037dd4e`
- Review command: `lead subagents`
- Specification approved at commit: `a8cabe1` (both specs approved 2026-10-03)
- Started: `2026-10-04`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Parakeet Unified transcription](01-parakeet-unified.md) | Slice 1 | Accepted |
| 2 | [Whisper Turbo transcription](02-whisper-turbo.md) | 1 | Accepted |
| 3 | [Bench dictation with cleanup](03-bench-dictation.md) | 2 | Accepted |
| 4 | [Local provider in the app](04-app-provider.md) | 3 | Not started |
| 5 | [Transcription evaluation and results](05-transcription-evaluation.md) | 4 | Not started |
| Final | [Whole-feature review](final-review.md) | 1-5 | Not started |

## Why these boundaries

1. **Parakeet Unified** is the reference candidate and the first local transcriber. It adds
   FluidAudio and its pinned models, the shared shape for a transcription candidate in
   `LocalCandidates.swift`, and the bench's `--candidate transcription=`. Both keyterm variants
   share one implementation, so they belong together.
2. **Whisper Turbo** is a different runtime (WhisperKit) with different live handling: it
   re-decodes audio windows rather than streaming. It reuses the seams workstream 1 creates and is
   reviewable alone.
3. **Bench dictation with cleanup** adds the run the spec needs once both services exist locally:
   transcription feeding the real `Reviser` live, measuring end-to-end stop-to-insert, deadline
   behaviour and combined memory. It also records load average in every run. Bench-only code.
4. **Local provider in the app** lists the provider in Settings and proves it in the installed,
   signed app through Aidan's check. It comes after the bench work so the gate tests the
   adapters as they will be measured, and before the evaluation so any fix the gate forces is in
   the measured code.
5. **Evaluation and results** runs the comparison and writes the transcription section of
   `results.md`. It changes no product code.

Sequential throughout. Workstreams 1 and 2 both edit `Package.swift`, `LocalCandidates.swift` and
`RunOptions.swift`; workstreams 2 and 3 both edit the bench.

## Cross-workstream contracts

- **Model store.** Slice 1's `ModelStore` and `ModelManifest`, unchanged in behaviour: one store per
  process (`LocalCandidates.store`), installed models under
  `~/Library/Application Support/EchoType/Models/<name>-<revision>/`, each manifest with
  repository, full commit revision, licence and every file's path, size and SHA-256. Core ML
  models ship as directories (`.mlmodelc`), so a manifest lists every file inside them. Runtime
  downloaders (FluidAudio's, WhisperKit's) are never used: they load from the store's directory.
  A store defect is an escalation, not a fix.
- **Selection.** `LocalSelection` gains `transcription`. Each of its fields is optional: the build's
  selection (`LocalSelection.build`) names every service, and a nil field means the provider
  neither prepares nor offers that service (transcription and voice report `.unavailable`, cleanup
  is nil). `run.json` records the selection as it does now.
- **Transcription candidate names.** `parakeet-unified` (Unified EN 0.6B, 640 ms `70_7_1` INT8,
  keyterm boosting off, keyterm limit 1), `parakeet-unified-keyterms` (the same model with the CTC
  spotting model and boosting on), and `whisper-turbo` (large-v3-turbo, Argmax 626 MB Core ML).
  The build's default is `parakeet-unified`; workstream 5's recommendation may propose changing it,
  but no workstream changes it without an escalation.
- **Bench arguments.** `--candidate <service>=<name>`, repeatable, for `transcription` and
  `cleanup`; an unknown service or name fails with the known ones. `transcribe --provider local`
  prepares only the transcription candidate and `cleanup --provider local` only the cleanup
  candidate, so standalone memory and preparation figures belong to one service. The dictation run
  (workstream 3) prepares both.
- **Transcriber behaviour.** Every local `LiveTranscriber` meets the contract in
  `Provider.swift`, which the bench's contract check enforces: `.ready` once and first, committed
  text only grows, keyterm rescoring never rewrites committed text, `.speech` only on speech
  evidence, the tail drained and resolved before `.finished`, `finish()` accepted before `.ready`,
  `close()` safe at any time and joined by `waitForClose()`. Inference runs off the main actor
  and loaded models are reused across sessions with fresh session state.
- **Readiness.** A service's readiness is `.waiting` with progress ("Downloading models, 0.4 of
  0.7 GB", "Loading the transcription model") until its model is loaded and warmed, `.ready`
  after, and `.unavailable` with the store's message on failure. `check` starts setup only for a
  model whose state is `.missing` (slice 1's convention below).

## Ownership handoffs

- `Package.swift`, `Package.resolved`, `Sources/EchoTypeCore/Providers/Local/LocalCandidates.swift`
  and `LocalProvider.swift` pass from workstream 1 to 2, then to 4.
- `Sources/EchoTypeBench/RunOptions.swift` passes from workstream 1 to 2 to 3, then to 4 for
  removing the local provider's special case.
- `Sources/EchoTypeBench/Measurements.swift`, `Report.swift` and `main.swift` belong to
  workstream 3 within this slice.
- `Sources/EchoTypeCore/Providers/Providers.swift` belongs to workstream 4.
- `docs/spikes/local-models/results.md` is extended by workstream 5 only. `research.md` is
  corrected where a measurement contradicts it, by workstream 5.

## Whole-feature acceptance

- Workstreams 1-5 accepted, with the signed-app gate passed.
- `swift test` and `swift build -c release --product EchoTypeApp` pass.
- Pending outside this workflow, recorded in the completion report:
  - CI runs only when the branch is pushed; FluidAudio and WhisperKit change its build time.
  - First model load after a reboot or OS update (an evicted Core ML cache) is not measured.
  - Energy (`powermetrics` needs root) is not measured.
  - Nested dependency bundles keep SwiftPM's ad hoc signatures; Developer ID notarisation of
    them is untested (carried from slice 1).
  - Read aloud, and therefore the voice comparison build and its worst-case memory, is slice 3.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| Signed-app check | Workstream 4 | After closure, before acceptance | Pending | `TBD` | Aidan's answer gives a verdict for every checklist item, and every item has passed |

## Escalations

None.

## Conventions learned

Carried from slice 1:

- `Readiness.check` calls `ModelStore.start` only when the state is `.missing`. `start` restarts a
  failed model and every state change yields on `changes()`, so starting a failed one would loop
  while offline. A failed model stays failed until relaunch. Hold one shared store per process.
- Derive paired figures (cold versus warm, counted versus excluded) from one filtered list in one
  pure function, not from two differently filtered reads, and test it with a subset run whose
  first attempt is a cancelled request.
- A runtime that hard-codes a cache path (FluidAudio's CTC tokenizer folder) is reached by a
  symlink to the store's verified directory, written only when missing or stale, tolerant of a
  concurrent writer and never over a real folder. Never rewrite another tool's folder on every
  load. Check which candidate writes it before telling workstream 4 what the app does.
- Cite the runs made on the final source: a run whose `run.json` says `sourceDirty` before a
  later edit is not evidence for the finished code; rerun it.
- In `results.md`, put a run id on every figure, bullet and table row, including derived ones, and
  scope runtime claims to the sizes actually measured; derive "warm" figures with the cold request
  excluded, as `report` does.

- Runtime downloader switches may leave tokenizer Hub fallback enabled. Load the pinned local tokenizer explicitly and propagate local errors, so failed preparation cannot fetch outside the store.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-04 | Latency figures come from a release build of the bench (`swift run -c release EchoTypeBench`). Slice 1's qwen3 cleanup timing is re-measured in release. | Slice 1's debug build understates local inference speed. | Aidan | 5 |
| 2026-10-04 | No quiet-machine requirement. Every run records load average instead. | EchoType runs on a busy machine; typical load is the honest condition. | Aidan | 3, 5 |
| 2026-10-04 | The local provider joins `Providers.all` in this slice, after xAI and Apple. | It can now dictate; slice 1 kept it out until it could. | Aidan | 4 |
| 2026-10-04 | Transcription and dictation runs are one paced pass each, with repeats only for candidates too close to call. Apple's transcription baseline reuses `20261004T083627Z-apple`. | About 14 warm samples per run is enough to choose a candidate; three repeats would double the evaluation's time for little change in the decision. | Aidan | 5 |
| 2026-10-04 | No new paid xAI run. The transcription baseline is `20261004T073341Z-xai`. | It exists and ran the same corpus; `report` scores it against the current references, so later reference corrections apply to it. | Planning agent | 5 |
| 2026-10-04 | Keyterm boosting on and off are two Unified candidates sharing one implementation. Boosted text commits only after its segment is rescored; unboosted text commits at utterance end. | The spec asks for commit lag with boosting on and off before choosing; two candidates make that a measurement, not an implementation-time decision. | Planning agent | 1, 5 |
| 2026-10-04 | The app's signed-app check is a short guided checklist Aidan follows, not the harness's app driver or `bench session`. | Neither exists yet, and building them is the harness's own later step. | Planning agent | 4 |
| 2026-10-04 | `parakeet-unified-keyterms` loads FluidAudio's CTC model from the store and symlinks FluidAudio's hard-coded cache folder (`~/Library/Application Support/FluidAudio/Models/parakeet-ctc-110m-coreml`) to it, because `VocabularyBoostingSession` reads `tokenizer.json` only from there. Only that candidate writes it; `parakeet-unified` never touches the folder. Workstream 4 should list it in the app's check. | No directory parameter exists; the alternative duplicates FluidAudio's rescoring internals. It is not a download. | Lead (workstream 1) | 4 |
| 2026-10-04 | Keyterm boosting uses the public `VocabularyBoostingSession.rescore` on the 15 s cadence with a local commit rule, not FluidAudio's built-in hook. Utterance boundaries and `.speech` use `VadManager` defaults (unboosted text commits only after about a 1 s pause). `utterance` is unused. `keytermLimit` is 1 (`parakeet-unified`) and 100 (`parakeet-unified-keyterms`). | FluidAudio's hook cannot say what is rescored; the spec's commit rule needs it. Details in the workstream 1 handoff. | Lead (workstream 1) | 2, 3, 5 |
| 2026-10-04 | The Unified conversion card says CC-BY-4.0; the manifest records the NVIDIA Open Model License of the upstream `nvidia/parakeet-unified-en-0.6b`. Unresolved, not a stop. | The packet says to record a conflict, not stop. | Lead (workstream 1) | 5 |
| 2026-10-04 | Workstream 1 edited the bench's `main.swift` usage text, which the plan assigns to workstream 3. Local slice's `LocalCleanup` is now `LocalModel`. | The usage text would otherwise document only `--candidate cleanup=`. | Lead (workstream 1) | 2, 3 |
| 2026-10-04 | Whisper uses one-second decode cadence, agreement or pause commitment, a 28-second unsettled-audio bound, Silero speech evidence and a 64-token keyterm prompt with limit 12. A local tokenizer adapter prevents WhisperKit's Hub fallback. | The public wrapper initializer is internal in pinned WhisperKit 1.1.0; local failures must propagate. Final paced and offline runs pass without contract violations. No specification drift. Speech events wait for batch inference; observe pause behaviour in the app check. | Lead (workstream 2) | 3, 4, 5 |
| 2026-10-04 | Bench dictation is `transcribe --cleanup`, prepares both selected services, scores only the transcript and reports inserted text and split stop-to-insert. Load average and debug/release metadata are recorded with backward-compatible reports. No specification drift. | Three-sample local and Apple evidence, legacy reports, independent review and focused closure all pass. | Lead (workstream 3) | 4, 5 |
