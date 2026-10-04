# Local cleanup (slice 1) whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 1 requirement in the spec's "Provider and candidate selection", "Native
  integration" (cleanup), "Model delivery experiment", "Evaluation" (cleanup) and "Build
  verification";
- seams between the store, the local provider and the bench, and that the plan's
  cross-workstream contracts hold;
- model and download lifecycle, cancellation and teardown;
- dependency direction: no candidate or model named outside `Providers/Local/` and the bench, and
  no local provider in `Providers.all`;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md`, the spec, the research and the test harness spec;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh debug .build/local-cleanup/EchoType.app
codesign --verify --deep --strict .build/local-cleanup/EchoType.app
```

## Initial whole-feature review

- Reviewer: fresh independent whole-feature reviewer (Claude Sonnet 5.5), read-only apart from this
  section. Read the README, this packet, `plan.md`, the spec, research, test harness spec, decision
  0025 and the four accepted handoffs, then reviewed the combined diff and the code around it
  without relying on the handoffs' conclusions.
- Branch, base, and reviewed head: `spike/local-models`; base (starting commit)
  `dac6a8906debed3fb7c140ea18176c926bb0f53e`; reviewed head
  `7a52ee1c792986356fcc3d4231760dbba9eb78d9`. The worktree was clean apart from the Final row edit
  in `plan.md`.
- Verification run: all four commands passed on the reviewed head, so nothing needed reproducing on
  the starting commit.
  - `swift test`: exit 0 (core 134 tests, bench 17, app 76).
  - `swift build -c release --product EchoTypeApp`: exit 0.
  - `scripts/build-app.sh debug .build/local-cleanup/EchoType.app`: exit 0. `Contents/Resources`
    holds `AppIcon.icns`, `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle` and
    `swift-transformers_Hub.bundle`.
  - `codesign --verify --deep --strict .build/local-cleanup/EchoType.app`: exit 0. The app is
    signed with Apple Development and the hardened runtime flag; the nested resource bundles keep
    SwiftPM's ad hoc signature and are sealed as resources. The app was not launched.
  - Only warning outside dependencies: SwiftPM's "missing creator for mutated node" for
    `mlx-swift_Cmlx.bundle`, which is benign.
  - Beyond the four commands: reran `EchoTypeBench report` on all 11 run ids `results.md` cites
    (every run exists; `run.json` carries provider, candidate, `6eb5351` and `sourceDirty: true`,
    which `results.md` discloses); every quoted `report` figure matched (quality totals, rejections,
    p50/p95/n, cold figures, preparation, footprint, pressure, offline totals). Recomputed from
    `cleanup.jsonl`: per-sample stop-to-insert medians (2198, 2006, 1636, 992 ms and 945 versus
    750 ms), longest stop-to-insert (1702, 1759, 2232, 2034 ms), longest final request, warm
    `clear-correction` medians (452 and 464 ms) and the missed-word totals per sample. All agree with
    the text. Hashed every installed model file against `LocalCandidates.swift` (all match) and
    checked both pinned revisions' card front matter on huggingface.co (`license: apache-2.0`). No
    xAI call and no credential was used.
- Acceptance-criteria audit:
  - **Provider and candidate selection.** Met. `Providers/Local/` holds the provider, both
    candidates and the store; `LocalCandidates.swift` holds the selection, both candidates'
    manifests and template context, and assembles `Provider.local`. No adapter protocol or factory.
    Only the selected candidate's `LocalCleanup` exists per provider, and only it loads. A grep for
    `qwen3`, `smollm`, `MLX`, `LocalSelection` and `Provider.local` outside `Providers/Local/` finds
    only the bench (`RunOptions.swift`, `RunInfo.swift`, `main.swift` usage text) and the new test.
    `Providers.all` is `[.xAI, .apple]`. Transcription and voice are `.unavailable` and throw
    `ProviderError.unavailable`. The spec's Settings entry and opt-in are absent by the approved
    drift (decision log, 2026-10-04).
  - **Native integration (cleanup).** Met. `Reviser` and its prompt are untouched (no change under
    `Sources/EchoTypeCore` outside `Providers/Local/`). Greedy sampling, output cap
    (`CleanupModel.swift:106`) that throws on `.length` rather than returning a truncated reply,
    SmolLM3 `enable_thinking: false`, prefix KV cache built once per loaded model and copied per
    request with a safe full-prefill fallback (`:74`), 128-token prefill steps with cancellation
    checks (read against the pinned `PrefillParameters.forEachChunk`, `LLMModel.prepare` and the
    token loop), loading in an owned task off the main actor, warm-up before `.ready`, no history
    between requests, and `Memory.cacheLimit` set. Cancellation latency is measured (p95 329 to
    417 ms). The three-second deadline was never reached in any run, so enforceability is
    established only by reading the code (see F1).
  - **Model delivery experiment.** Met with gaps. Explicit manifests with a full commit,
    licence, sizes and SHA-256; only listed files are fetched; models live in Application Support
    outside the bundle; the revision is in the directory name; nothing installs until every file
    verifies; `Incomplete/` is never read as a model; the second run does not download; readiness
    text follows "Downloading models, x of y GB"; failures are `.unavailable`. Offline inference was
    demonstrated under a `sandbox-exec` network deny. Gaps: transient disk usage and a measured
    download time are not recorded, and recovery after interruption is shown only with an injected
    source (F3).
  - **Evaluation (cleanup).** Met for what slice 1 can measure. 12 samples covering every row of the
    spec, 15 paced repeats, p50/p95/n, wrong deletions, missed edits, rejections, deadline
    fallbacks, stop-to-insert, revising share, cold apart from warm, `phys_footprint`, thermal state
    and memory pressure, Apple and a paid xAI baseline on the same samples, offline runs, and a
    recommendation that follows from the figures and states the remaining gap. Latency came from a
    busy machine and a debug build, which `results.md` says. Concurrent transcription, release-build
    latency and first load after reboot are outside this slice or disclosed.
  - **Build verification.** Met. `build-app.sh` stages every `*.bundle` before signing, CI installs
    the Metal toolchain, the README mentions it, and the signed debug bundle verifies. Loading MLX in
    the signed app and the CI step are not exercised (see F2, F6).
  - **Seams and contracts.** Hold. One `ModelStore` per process (`LocalCandidates.store`);
    `Readiness.check` starts a download only from `.missing`, so a failed model stays failed; the
    store's behaviour is unchanged from workstream 1; `Provider.local(_:)` is the single bench entry;
    `run.json` records provider and candidate; every run directory gets `preparation.json` and
    `sampler.json`; older runs still report.
  - **Lifecycle.** Downloads and loads run in tasks the store and `LocalCleanup` own, so a provider
    switch does not stop them. There is no cancel and no unload by design (idle residency was
    measured instead, 2.4 and 1.8 GiB). Request cancellation reaches prefill (between chunks) and the
    token loop, and a cancelled `generate` throws rather than returning partial text.
  - **Dependency direction, duplication, tests.** No finding that blocks. See F4, F5 and F8 for small
    simplifications.
  - **Agreement of documents.** `results.md` agrees with the artifacts on every checked figure. It
    differs from the research on two stale estimates (F7) and omits two facts the spec's expected
    output lists (F3).
- Required findings by owner: none. No correctness defect, unmet acceptance criterion, boundary
  violation, meaningful regression or unjustified complexity survived verification. All findings
  below are Optional or Questions.
  - Workstream 1 (store files): none.
  - Workstream 2 (provider, cleanup, packaging, `RunOptions`): none.
  - Workstream 3 (bench measurement): none.
  - Workstream 4 (`results.md`): none.
- Optional observations:
  - **F3 (Optional), `docs/spikes/local-models/results.md:64`, spec "Model delivery experiment".**
    The spec asks to record transient disk usage and to show recovery after interruption; the
    results record neither. "Download time was about a minute per model" has no run id and rests on
    a handoff, though the doc's own rule is a run id on every figure. Interruption recovery is shown
    only with the injected source (`ModelStoreTests.interruption`); the live source has not been
    killed mid-file. Cheapest fix: reword the sentence to "not measured" and add one line that the
    live-source interruption and transient disk usage were not exercised, or measure them once by
    moving the installed models aside (not deleting them) and downloading again. The spec's
    "integration changes" (third direct dependency `swift-transformers`, three staged bundles, CI
    toolchain) are only in `plan.md`'s drift log, not in `results.md`; later slices can add them
    when the full results record is assembled.
  - **F4 (Optional), `Tests/EchoTypeCoreTests/LocalCleanupTests.swift:28-31`.** `outputLimit` only
    asserts that the cap exceeds the window for four inputs. It cannot fail for any plausible edit of
    the formula and the throw-on-cap behaviour needs a model. Delete it (the file's other three tests
    guard real risks: manifest shape, the failed-state loop, and the unknown-name message).
  - **F5 (Optional), `Sources/EchoTypeBench/RunOptions.swift:26-31`.** `--candidate cleanup=x` is
    accepted and silently ignored with `--provider apple|xai`; `run.json` then records no candidate,
    so nothing misleading is written, but `--provider xai --candidate cleanup=smollm3-3b` runs xAI
    without complaint. Two lines would reject it. Deferred earlier by workstream 2's lead; repeated
    here only because the bench argument is now the entry point for slice 2's transcription and
    voice candidates.
  - **F7 (Optional), `docs/spikes/local-models/research.md:118-119, 139`.** The research still
    estimates 3-4 GB (Qwen3) and 2.5-3.5 GB (SmolLM3) of RAM and says a long prefill "may not be
    interruptible". Measured peaks are 2.5 to 2.6 GiB and 2.1 GiB, and prefill is interruptible
    between 128-token chunks, with one chunk uninterruptible. The spec asks to keep research in sync
    when a fact changes; one clause each, pointing to `results.md`, would do. Also `results.md:272`
    quotes a 2.5 GiB peak from the paced run only; the `--fast` and offline qwen3 runs peaked at 2637
    and 2648 MiB (about 2.6 GiB), so the figure for the 16 GiB budget should be the maximum across
    runs.
  - **F8 (Optional), deadline scope, `results.md:271` and the Deadline section.** "Never hit" and
    "enforceable" hold for windows up to the corpus's longest (about 70 tokens). Final requests on
    that window took 1.85 s, which on a linear extrapolation puts the three-second budget near 110
    tokens (roughly 80 unpunctuated words) on the debug build. `Reviser.split` caps punctuated text
    near 50 words but not unpunctuated text, so a longer unpunctuated dictation would fall back to
    unrevised words. This is a limit of the model and the budget, not a defect; a sentence saying
    where the measured evidence ends would stop "Never hit" being read as a general result. It is an
    extrapolation, untested.
  - **F9 (Optional), traceability of environment claims.** The load averages and busy-process list in
    `results.md:15-17` come from `/tmp/ws4-*.log` files and shell checks that are not kept with the
    runs, so a later reader cannot verify them. They are stated honestly as upper-bound caveats and
    nothing depends on them. No change needed unless the bench should record load average in
    `run.json`, which would be new machinery.
  - Not raised on purpose: the duplicated follower bookkeeping in `ModelStore.changes` and
    `LocalCleanup.changes` and `Sampler`'s two mutexes (earlier reviewers judged them acceptable, and
    I agree), `Preparation.phases` parsing message text, and `UnknownCandidate.service` (one caller).
    The comparison machinery (`LocalSelection`, `LocalCandidates.cleanup`, `--candidate`) is small,
    confined to `Providers/Local/` and the bench, and the spec already schedules its removal.
- Questions:
  - **F1 (Question), `docs/spikes/local-models/results.md` Deadline section; spec "Evaluation".** The
    spec says to "establish whether the existing three-second final deadline is enforceable by the
    chosen runtime". No run reached the timer (0 deadline fallbacks and overruns everywhere), so
    `DeadlineOutcome` and the 250 ms overrun threshold are verified by unit test only, and the
    answer is reasoned from cancellation latency and the MLX source. `results.md` says so plainly.
    Does the lead accept that for slice 1, or should one run exercise it? `Reviser` already takes an
    injected `finalClock`, so a bench or test run with a window past 128 tokens, or a shortened
    clock, would observe cancellation during prefill and the overrun classification end to end. I
    would accept the current wording for a spike and carry this to the concurrent-load check in
    slice 2.
  - **F2 (Question), `scripts/build-app.sh:24`, release packaging.** The three staged bundles keep
    SwiftPM's ad hoc signature inside an app signed with Apple Development, and `codesign --verify
    --deep --strict` accepts it. `package-release.sh` goes through the same script with a Developer
    ID identity. Whether the notary service accepts nested resource bundles with an ad hoc signature
    is unverified. The metallib is not a Mach-O, so I expect it to pass; slice 2 or the first
    notarised release should confirm. No action in this workflow.
  - **F6 (Question), `.github/workflows/ci.yml:16, 28-30`.** The job's `timeout-minutes: 15` now covers
    a Metal toolchain download, a debug build of MLX and its dependencies for `swift test`, and a
    second release build. Locally the release step took 93 s after the debug products existed, but a
    clean runner is unmeasured, and it is unknown whether `xcodebuild -downloadComponent
    MetalToolchain` succeeds when the image already has the component. Both are already listed as
    pending in the plan (CI runs on push only). Raise the timeout pre-emptively, or wait for the first
    pushed run?
- Verdict: Accept. No Required findings. The feature meets the slice 1 requirements within the
  approved drift; all four verification commands pass; every checked figure in `results.md` agrees
  with the run artifacts; the recommendation (take forward `qwen3-4b-2507`, reject `smollm3-3b`)
  follows from them and is scoped to 11 inputs, a debug build and a busy machine. F3 to F5, F7 to F9
  are optional edits to the docs and one test; F1, F2 and F6 are decisions for the lead. External
  behaviour still unverified: the CI step, MLX loading inside the signed installed app, notarised
  packaging, the three-second timer firing, release-build and quiet-machine latency, first load
  after reboot, concurrent transcription, and a live-source download interrupted by a real kill.

## Lead triage

- Accepted findings and owners:
  - F3, F7, F8 (`results.md`, `research.md`): accepted. Each breaks a stated convention or leaves a
    stale or unscoped claim in a record the spec requires to agree with the measurements (run id on
    every figure; runtime claims scoped to measured window sizes; research kept in sync). Owner: a
    fresh documentation agent owning `docs/spikes/local-models/results.md` and
    `docs/spikes/local-models/research.md`. Corrections check against the sampler and preparation
    artifacts. Peaks use the highest across cited runs (qwen3 2649 MiB, smollm3 2171 MiB).
  - F4 (`Tests/EchoTypeCoreTests/LocalCleanupTests.swift`): accepted as an unjustified, ceremonial
    test. Owner: a fresh implementation agent owning that file. `outputLimit` stays because
    `CleanupModel` uses it.
- Rejected findings and reasons:
  - F1 (Question): no extra run. The spike's record already says plainly that the timer was never
    reached and that enforceability is reasoned from cancellation latency; slice 2's concurrent-load
    check is the place to exercise it. Wording now scopes it (F8).
  - F6 (Question): do not raise `timeout-minutes` pre-emptively; wait for the first pushed run, as
    `plan.md` already records.
- Deferred optional observations:
  - F5: `--candidate` ignored with `--provider apple|xai`. Harmless now (`run.json` records no
    candidate); revisit when slice 2 adds transcription and voice candidates to the same argument.
  - F9: load-average and busy-process evidence is not kept with the runs. Stated as an upper-bound
    caveat; recording it would be new machinery.
  - F2 (Question): nested ad hoc bundle signatures under Developer ID notarisation. Unverified;
    first notarised release or slice 2.
- Drift requiring user decision: none.

## Focused closure

- Reviewed head: `7a52ee1c792986356fcc3d4231760dbba9eb78d9` plus the uncommitted corrections to
  `docs/spikes/local-models/results.md`, `docs/spikes/local-models/research.md` and
  `Tests/EchoTypeCoreTests/LocalCleanupTests.swift` (reviewer: fresh closure reviewer, Claude Sonnet
  5.5; `plan.md` and this file read only). Verification on that tree: `swift test` exit 0;
  `swift build -c release --product EchoTypeApp` complete; `scripts/build-app.sh debug
  .build/local-cleanup/EchoType.app` complete; `codesign --verify --deep --strict` exit 0. Nothing
  failed, so nothing needed reproducing on the starting commit. No xAI call, no credential.
- Finding outcomes:
  - **F3: fixed.** `results.md` no longer claims "about a minute per model"; it states that download
    time and transient disk usage were not measured, which holds because every cited run's
    `preparation.json` shows only "Loading the cleanup model" (checked all 11 ids), and that
    interruption recovery was exercised only with the injected source. The integration changes the
    spec lists (third direct dependency `swift-transformers`, three staged bundles, CI Metal
    toolchain) are now recorded. No remaining figure lacks a run id.
  - **F4: fixed.** `outputLimit` test deleted; the file's other tests are untouched and the suite
    passes. `CleanupModel.outputLimit` stays because `CleanupModel` uses it.
  - **F7: fixed.** `research.md` carries the measured peaks (2.6 and 2.1 GiB) and the measured
    prefill interruptibility, each pointing to `results.md`. `results.md` now uses the maximum peak
    across cited runs. Recomputed from each run's `sampler.json`: qwen3 2649 MiB (`…111803Z-local`),
    2638 (`…105222Z-local`), 2573 (`…110130Z-local`), 2571 (cold); smollm3 2171 MiB
    (`…105256Z-local`), 2169, 2162. The cost row (2.6 GiB, 2649 MiB) and the gap paragraph (about
    2.6 GiB) agree with the memory section; no "2.5 GiB" remains in any document. The paced-run table
    keeps its own run's figures (2573, 2162), labelled by run id.
  - **F8: fixed.** The Deadline section, the longest-request bullet and the recommendation row now
    scope "never hit" to windows up to about 70 tokens on the debug build and label the roughly 110
    token figure as an untested linear extrapolation (1.85 s at 70 tokens reaches 3 s near 113). This
    does not contradict the earlier 3.9 to 4.4 s bound, which concerns the overrun once the budget is
    reached.
- Final simplification assessment: nothing further to delete. The deleted test was the only
  ceremonial one; the comparison machinery (`LocalSelection`, `--candidate`) is small, confined to
  `Providers/Local/` and the bench, and already scheduled for removal by the spec. The doc
  corrections add sentences, not structure. Cosmetic only, not a blocker: the new research clause
  makes line 139 of `research.md` long.
- Remaining blockers: none.
- Verdict: Accept. F3, F4, F7 and F8 are fixed, the corrected figures match the run artifacts, the
  corrections contradict nothing else in `results.md`, and all four verification commands pass.

## Completion record

- Final verification: `swift test`, `swift build -c release --product EchoTypeApp`,
  `scripts/build-app.sh debug .build/local-cleanup/EchoType.app` and
  `codesign --verify --deep --strict .build/local-cleanup/EchoType.app` all passed, in the initial
  review on `7a52ee1` and again in closure on that head plus the corrections. Nothing failed, so
  nothing was compared with the starting commit.
- External validation pending: CI with the Metal toolchain step and its 15 minute timeout (runs only
  when the branch is pushed); loading MLX inside the signed, installed app (slice 2); nested ad hoc
  bundle signatures under Developer ID notarisation; the three-second timer firing end to end;
  release-build and quiet-machine latency; first load after reboot; concurrent transcription and
  memory; a live download interrupted by a real kill; download time and transient disk usage.
- Specification drift: none new. The approved drifts stay in `plan.md`'s decision and drift log
  (local provider outside `Providers.all`, `swift-transformers` as a third dependency and three
  staged bundles, paid xAI baseline).
