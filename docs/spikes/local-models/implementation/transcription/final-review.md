# Local transcription (slice 2) whole-feature review

Status: accepted, 2026-10-05. All workstreams and whole-feature closure passed.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 2 requirement in the spec's "Provider and candidate selection", "Native
  integration" (transcription), "Model delivery experiment", "Evaluation" (transcription and the
  concurrent check) and "Build verification";
- the plan's cross-workstream contracts, especially the transcriber behaviour contract in both
  adapters: committed text only grows, rescoring never rewrites it, the tail resolves before
  `.finished`, and `close()` and `waitForClose()` are safe at any time;
- model and download lifecycle, loaded-model reuse, teardown, and that only selected candidates
  are prepared;
- dependency direction: no candidate or model named outside `Providers/Local/` and the bench,
  and app code that treats Local as any other provider;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md`, the spec, the research and the test harness spec,
  including every run id `results.md` cites;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-transcription/EchoType.app
codesign --verify --deep --strict .build/local-transcription/EchoType.app
```

Do not launch the app or run xAI.

## Initial whole-feature review

- Reviewer: fresh Codex whole-feature reviewer, 2026-10-05. Applied `unslop`.
- Branch, base, and reviewed head: `spike/local-models`, base
  `79d5a900e3abbc49b8e1428d2b20675cd037dd4e`, head
  `abfa64f978ae35b17689faa0f9b98e58676110d1`. The only initial dirty file was the lead's
  `plan.md` Review transition. Reviewed the combined diff, surrounding code, source documents,
  accepted handoffs and their resolutions. Edited only this section.
- Verification run: all four packet commands rerun and passed.
  - `swift test`: 140 core, 19 bench and 76 app tests passed.
  - `swift build -c release --product EchoTypeApp`: passed.
  - `scripts/build-app.sh release .build/local-transcription/EchoType.app`: passed.
  - `codesign --verify --deep --strict .build/local-transcription/EchoType.app`: passed.
    Resources contain the icon and all four dependency bundles, including FluidAudio and MLX.
  - Command logs are `/tmp/echotype-whole-review-tests.log`,
    `/tmp/echotype-whole-review-release.log` and `/tmp/echotype-whole-review-bundle.log`.
    `git diff --check` also passed. Long builds used persistent command sessions and completion
    waits. No app was launched, model moved, MCP client started or xAI call made.
  - Regenerated reports for all 34 run ids cited in `results.md`, including expanded shortened
    cleanup ids, with `swift run -c release EchoTypeBench report <ids>`; exit 0. Every run and
    its report exists. Output is `/tmp/echotype-whole-review-reports.log`, outside git.
    New evaluation runs record release configuration and source `6c779359fe0035fed7fcc127dac606c37b7594e0`.
    Sources, tests, packages and scripts are unchanged from that revision. Reused their accepted
    download, installed-file integrity, paced and network-denied evidence rather than repeat
    those experiments.
- Acceptance-criteria audit:
  - Provider and selection: met. Local is third in the registry; xAI remains the default.
    `LocalCandidates.swift` selects the build's unboosted Unified and Qwen. Only selected
    services receive `LocalModel` instances, and construction alone starts no setup. Standalone
    bench commands prepare only their measured service; dictation prepares both. App code
    contains no candidate names or Local-specific control path. Read Aloud hides unavailable
    controls using readiness and avoids a fixed-range Slider.
  - Transcription integration and contracts: met by source inspection and recorded events.
    Both adapters use queued input with inference in worker tasks and fresh session state over
    reused loaded weights. Committed text only appends; Unified rescoring changes pending tokens
    before committing them. Whisper replaces provisional segments and trims committed audio,
    with a bounded decode window. Finish drains input and resolves the tail before `.finished`.
    Finish before readiness is accepted. Close ends input and events, cancels work and can repeat;
    `waitForClose()` joins it. New sessions join the previous one before using shared runtime state.
    Core ML work stops between predictions rather than midway through one. Overlapping starts
    remain outside the app coordinator's single-dictation contract.
  - Independently checked all event prefixes in the three release paced transcription runs and
    the concurrent local run. Each has 15 results, zero errors or violations, no rewritten
    committed prefix and no inserted silence words. Offline comparison reproduces 15/15 equal
    final texts for each Unified selection and 12/15 for Whisper, as `results.md` states.
    Speech evidence comes from Silero; Whisper may deliver it after batch inference.
  - Delivery: pinned manifests, selected files, verification before installation, local runtime
    loading, readiness progress and offline use are supported. Store implementation is unchanged
    from slice 1. The local Whisper tokenizer fix prevents its dependency's Hub fallback.
    Fresh and paired delivery records exist for all three transcription selections and Qwen;
    the interrupted Unified record shows no installed directory and retained incomplete files,
    followed by a verified successful recovery. Cache specialization is recorded without claiming
    isolated compilation duration. Peak transient disk use needs the lead's decision in Question 1.
  - Evaluation and concurrent check: met. Results compare both Unified modes, Whisper, Apple and
    the existing paid xAI baseline, qualify the reference bias and small warm counts, separate
    cold preparation from warm operation, and record load, footprint, pressure and thermal state.
    The concurrent boosted Unified/Qwen run reports zero deadline fallbacks and overruns,
    warm insertion p50/p95 1240/2716 ms with n=14. This does not prove an over-budget request's
    cancellation. Recommendation stays recorded without changing the build, per Aidan's decision.
  - Build and signed app: automated builds and strict verification passed. Accepted workstream 4
    evidence covers installed unboosted Unified/Qwen and Whisper/Qwen, cleanup, tail insertion,
    quick stop and offline use. Checklist item 4, switching during download, is explicitly waived.
    The recommendation does not authorize another boosted signed build or gate.
  - Complexity and tests: no release-blocking complexity found. `LocalModel` replaces the old
    cleanup lifecycle class; the bench reuses the Reviser and cleanup measurements. No comparison
    app logic, runtime picker, capability flags or model-management framework was added. Transcript,
    tokenizer-failure, readiness and option-validation tests protect real risks. Optional 2 notes
    one low-value arithmetic test. Loaded models remain resident by the spike's measured reuse
    choice; no speculative unloading policy is needed.
  - External behaviour still unverified: CI after push, first load after reboot or OS update,
    energy, Developer ID notarisation of nested bundles, signed-app switching during download,
    local read aloud and the voice combination's memory. A separate boosted signed build was not
    part of the passed gate. Original harness MCP stdio transports still require reconnection or
    a new session; GUI restoration and standalone protocol verification do not prove reconnect.
- Required findings by owner: none established.
- Optional observations:
  1. Existing Whisper speech-event latency and fast-run variation remain deferred. The paced
     and offline runs pass, but batch timing can delay silence bookkeeping; no new regression
     was demonstrated. Do not add tuning or another runtime in this review.
  2. `Tests/EchoTypeBenchTests/MeasurementsTests.swift`'s
     `stopToInsertIncludesBothParts` directly tests addition in `StopToInsert.totalMs` and a zero
     case. It offers little confidence beyond the real concurrent trace. Removing it is an
     optional simplification, not a release blocker.
  3. The documented Unified conversion/upstream licence conflict remains unresolved. The frozen
     workstream explicitly allowed recording it without stopping the spike; distribution readiness
     belongs to productionising, which Aidan deferred.
- Questions:
  1. Owner: evaluation documentation and final lead. The product spec's Model delivery experiment
     says to record transient disk usage. Workstream 5's frozen packet asks for disk used including
     compiled caches. `evaluation-delivery.json` records allocated disk after completion, and the
     interruption record captures retained incomplete bytes; neither samples a peak transient
     total including URLSession's temporary download location. `results.md` qualifies installed
     disk and shared cache snapshots but does not explicitly list slice 2's transient peak as
     unmeasured. Decide whether to record this limitation and drift, or require measurement.
     I favour stating the limit explicitly and deferring another delivery experiment, given the
     completed accepted evaluation. That does not make a snapshot a transient-peak measurement.
- Verdict: code, evidence checks and all four verification commands pass. No Required code defect;
  Question 1 needs lead judgement before whole-feature acceptance.

## Lead triage

- Accepted findings and owners: Question 1 becomes a documentation correction owned by a fresh implementation agent. State the observed transient incomplete-file snapshot and the unmeasured whole-download peak in `results.md`. Reuse the existing interruption record; no new delivery experiment is needed.
- Rejected findings and reasons: a peak-total experiment is not required by the approved spec, which asks to record transient disk usage without specifying a sampled maximum. The interruption provides an observed transient snapshot. Its limits must be explicit; post-install disk totals are not a peak measurement.
- Deferred optional observations: retain Whisper speech-event timing and fast-run variation, the small arithmetic test and the recorded Unified licence conflict. None establishes an unmet slice 2 criterion or justifies productionising in this workflow.
- Drift requiring user decision: none. The existing signed-app waiver and recorded recommendation with the build unchanged remain authoritative.

## Focused closure

- Reviewer: fresh Codex closure reviewer, 2026-10-05. Applied `unslop`. Reviewed head
  `abfa64f978ae35b17689faa0f9b98e58676110d1` against the recorded base
  `79d5a900e3abbc49b8e1428d2b20675cd037dd4e`, with the documentation correction and lead
  records uncommitted. Runtime code, tests, packages and scripts are unchanged since the initial
  whole-feature review.
- Finding outcomes: Question 1 is resolved. `results.md` now names the observed five-file
  interruption snapshot, totaling 14444100 logical bytes, and explicitly states that the
  whole-download peak including URLSession temporary storage was not sampled. It distinguishes
  installed and shared-cache snapshots from peak measurements. Checked both saved JSON records
  for `20261005T072301Z-local`; the interrupted installation is absent and recovery exits 0.
  The correction preserves the initial review's valid runtime and run evidence and introduces no
  release-blocking defect.
- Verification: all four packet commands rerun and passed. `swift test` passed 140 core,
  19 bench and 76 app tests; release product build, signed bundle build and strict codesign
  verification passed. Logs are `/tmp/echotype-closure-tests.log`,
  `/tmp/echotype-closure-release.log`, `/tmp/echotype-closure-bundle.log` and
  `/tmp/echotype-closure-codesign.log`. Long commands used persistent sessions and completion
  waits. `git diff --check` passed. No app launch, xAI call, new evaluation run or MCP client.
- Final simplification assessment: the accepted correction changes documentation only and adds
  no machinery. Existing optional observations remain deferred. The unboosted build, passed
  signed-app gate and item 4 waiver remain authoritative; productionising and local read aloud
  remain separate work.
- Remaining blockers: none. External limits recorded in the initial review still apply.
- Verdict: passed. The accepted correction is complete and whole-feature acceptance can proceed.

## Completion record

- Final verification: initial review and fresh focused closure each passed all four packet commands. Closure passed 235 tests, comprising 140 core, 19 bench and 76 app tests, the release app build, signed bundle staging and strict signature verification. All 34 cited runs exist and their regenerated reports pass. Only a documentation qualification changed after initial review; runtime evidence remains valid.
- External validation pending: CI after push, first load after reboot or OS update, energy and Developer ID notarisation of nested bundles remain untested. Signed-app switching during download is explicitly waived. Whole-download peak disk usage was not sampled; the interrupted-download transient snapshot is recorded. Local read aloud and the voice combination memory belong to slice 3. GUI restored; original harness MCP stdio needs reconnection or a new session. Standalone protocol verification does not establish reconnection.
- Specification drift: none introduced by final review. The spec asks to record transient disk usage; the saved interruption snapshot records observed retained logical bytes without claiming an allocated peak. Existing approved slice boundaries, gate waiver and recommendation decision remain recorded in the plan.
