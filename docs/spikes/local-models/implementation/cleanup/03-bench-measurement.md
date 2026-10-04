# Workstream 3: Bench measurement for local services

Status: accepted.

## Task packet

### Outcome

A cleanup bench run produces every measurement the spec's cleanup row and its cost
paragraphs ask for: warm latency distributions over repeats, cold preparation and first
request, process memory, thermal state and memory pressure, cancellation latency, and deadline
behaviour. `report` shows them with p50, p95 and sample counts. The same features work for
`transcribe`, so later slices reuse them.

### Scope

- **Repeats.** `--repeat <n>` runs the selected samples `n` times in one process, recording the
  repeat index on every result. The first request after the provider becomes ready is cold;
  `report` separates it from warm results and computes warm distributions from the rest.
- **Preparation timing.** Record how long the readiness wait took in the run directory. The
  readiness message sequence, such as downloading then loading, is recorded with times, so
  download and load can be told apart.
- **Sampler.** The test harness spec's background sampler, for every `transcribe` and `cleanup`
  run: the bench process's `phys_footprint`, `ProcessInfo.thermalState` and the system's memory
  pressure level, sampled at a fixed interval into the run directory. `report` shows peak
  footprint, footprint once ready and idle before the first request, the worst thermal state and
  the worst memory pressure.
- **Cancellation and deadline.** Record when `finish` was called. `report` shows:
  - cancellation latency: for a live revision cancelled by `finish`, the time from the `finish`
    call to that revision's end;
  - deadline fallbacks: final revisions cancelled by `Reviser`'s three-second timer, counted
    apart from validation rejections and other fallbacks;
  - deadline overruns: final revisions that ended more than 250 ms after the three-second
    deadline, which show that cancellation could not interrupt the model.
- **Report.** Add these to the terminal table, totals and `report.md`, keeping existing
  columns. A run without repeats or samples still reports as before.
- Focused tests for the new pure calculations: separating cold from warm, cancellation latency
  and deadline classification from recorded attempts.

### Non-goals

- `powermetrics` or energy measurement; the spec makes it a guided step.
- The `lifecycle` command, scenario driver or listening page.
- Running the evaluation or writing results; workstream 4 owns them.
- Any change to `Reviser`, providers or the cleanup prompt.

### Initial ownership

- `Sources/EchoTypeBench/` and `Tests/EchoTypeBenchTests/`.
- `docs/specs/test-harness.md`, only where what you build differs from its description.

### Required seams

- Consumes the plan's bench arguments contract and `run.json`'s candidate record from
  workstream 2 unchanged.
- Produces the measurements workstream 4 reports. Name each `report` field plainly so the
  results record can cite it.

### Acceptance criteria

1. `--repeat` works for `cleanup` and `transcribe`, and every result records its repeat index.
2. `report` gives warm p50, p95 and n for stop-to-insert and revision duration, apart from the
   cold first request.
3. Preparation time and the readiness message sequence are recorded for every run.
4. Every run directory has sampler output, and `report` shows peak and idle footprint, worst
   thermal state and worst memory pressure.
5. `report` shows cancellation latency, deadline fallbacks and deadline overruns, with deadline
   fallbacks separate from validation rejections.
6. Existing runs from before this workstream still produce a report.
7. Bench tests pass, including the new focused tests.

### Targeted verification

```bash
swift build
swift test --filter EchoTypeBenchTests
swift run EchoTypeBench cleanup --provider apple --repeat 3
swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 3
swift run EchoTypeBench transcribe --provider apple --fast --repeat 2 dictation-short-reply
```

Then run `swift run EchoTypeBench report` on each run id those commands print, and on
`20261004T083627Z-apple`, a run from before this workstream.

## Implementation handoff

- Base commit: `feb7764a7471d04b4b946b20238013a0a5f9aa96`
- Outcome: `transcribe` and `cleanup` take `--repeat <n>` and write `preparation.json` and
  `sampler.json` into every run directory. `report` shows warm and cold latency, preparation,
  footprint, thermal and memory pressure, and for cleanup cancellation latency and deadline
  behaviour. All acceptance criteria are met.
- Files changed:
  - New `Sources/EchoTypeBench/Measurements.swift`: `Preparation`, `Sampler`, `MachineSample`,
    `cancellationLatencyMs`, `deadlineOutcome`, `splitCold`, date coding with milliseconds and
    `RunMeasurements` (reads the two new files for `report`).
  - Edited `Cleanup.swift`, `Transcribe.swift`, `RunOptions.swift` (`--repeat`; `requireReady`
    now returns the `Preparation`), `Report.swift`, `main.swift` (usage).
  - New `Tests/EchoTypeBenchTests/MeasurementsTests.swift` (4 tests: cold split, cancellation
    latency, deadline classification, preparation phases).
  - `docs/specs/test-harness.md`: one paragraph describing the sampler, preparation, repeats and
    deadline measures as built.
- Decisions:
  - **Cold.** The run's first logged result is cold (its repeat index is 0 and it is first).
    For cleanup, "first revision" is the cold sample's first request the model served (its first
    attempt that is not a live revision cancelled by `finish`), and that sample's other served
    requests count as warm for revision duration; the whole sample is left out of warm
    stop-to-insert. `requestDurations` in `Measurements.swift` derives both from one filter. Results without `repeatIndex` (runs from before this workstream) are all
    warm and show no cold figures.
  - **Quality totals span repeats.** With `--repeat 3`, `exact`, wrong deletions and the like are
    summed over all repeats (`exact 24/33`). Rows are numbered `<sample> #<repeat + 1>` only when
    the run has repeats.
  - **Timing totals use counted samples**: ambiguous (manual) and errored cleanup samples, and
    unscored transcribe samples, stay out of every latency and deadline figure, as they did.
  - **Sampler.** Starts before `requireReady`, so a download or model load is in the peak. Samples
    are held in memory and written once, as `sampler.json`, when the run ends; an interrupted run
    has none. The ready footprint is the first sample at or after `readyAt`; the bench takes one
    right when the provider becomes ready.
  - **Dates.** `.iso8601` drops milliseconds, which revision times need, so `cleanup.jsonl` and
    the two new files encode ISO 8601 with milliseconds (`.milliseconds`). `report` reads both
    forms (`.secondsOrMilliseconds`).
  - **Deadline.** A final revision whose result is `cancelled` is a deadline fallback; one with
    `duration` over `Reviser.finalTimeout + 0.25` s is an overrun. Cancelled final revisions are
    not in the existing `fallbacks` count, which is unchanged.
- Report fields added (names as printed; cleanup unless noted):
  - Totals line `fallbacks N (validation rejections M)`: M counts requests `Reviser` refused as
    `rejected` or `replyRequestRemoved`, a subset of `fallbacks`.
  - `deadline fallbacks`: counted samples whose final revision the three-second timer cancelled.
  - `deadline overruns`: counted samples whose final revision ran over 3.25 s.
  - `warm stop-to-insert` (transcribe: `warm stop-to-final` and `warm first committed`): p50, p95
    and n over warm samples.
  - `warm revision`: p50, p95 and n of request durations, excluding live revisions cancelled by
    `finish`.
  - `cancellation latency`: p50, p95 and n of the time from `finish` to the end of the live
    revision it cancelled, over counted samples that had one.
  - `cold stop-to-insert` and `first revision` (transcribe: `cold stop-to-final` and
    `first committed`): the run's first sample and its first served request.
  - `preparation N ms (<phase> N ms, ...)`: readiness wait, split by message text before its
    numbers ("Downloading models", "Loading the cleanup model").
  - `footprint peak`, `ready` (footprint once ready, before the first request), `thermal worst`,
    `memory pressure worst`.
  - Per-sample columns `cancel` (ms) and `deadline` (`fallback` and/or `overrun`).
  - Totals are now several lines (indented continuation lines); the multi-run comparison prints
    them the same way. Latency lines appear only for paced runs; counts and machine lines always.
  - New files in a run directory: `preparation.json` (`startedAt`, `readyAt`, `messages` of
    `ms` and `message`), `sampler.json` (array of `at`, `footprintBytes`, `thermalState`,
    `memoryPressure`). New result fields: `repeatIndex` (both logs), `finishCalledAt` (cleanup).
- Verification: all passed on the M1 Pro.
  - `swift build`, `swift test --filter EchoTypeBenchTests` (16 tests).
  - `cleanup --provider apple --repeat 3` (`20261004T100618Z-apple`),
    `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 3`
    (`20261004T100814Z-local`, no download, preparation 3003 ms, footprint peak 2573 MiB, ready
    2364 MiB, cancellation latency p50 147 / p95 196 ms),
    `transcribe --provider apple --fast --repeat 2 dictation-short-reply`
    (`20261004T100954Z-apple`), and `report` on each and on `20261004T083627Z-apple` (older run,
    reports with all results warm). Also a paced transcribe
    (`20261004T101014Z-apple`) to see cold figures.
- Known limitations or external checks:
  - Cancellation latency mixes wall-clock `Date` (revision start, `finish` call) with a monotonic
    duration; the error is far under a millisecond over seconds.
  - Apple's cleanup runs outside the bench process, so its footprint says little; the process
    footprint is meaningful for the local provider.
  - Fast runs report no latencies, as before. No run in this workstream hit the deadline, so the
    deadline fallback and overrun counts were verified by tests only.
  - The `Waiting:` line is still printed once per progress change during a download.
- Specification drift: none (the harness spec gained a paragraph describing what was built).

## Independent review

- Reviewer: fresh independent review session (Claude Sonnet 5.5), against base `feb7764` and the
  uncommitted tree.
- Verdict: Changes required. One Required finding (cold first revision is wrong when a sample's
  first request is cancelled by `finish`); everything else meets the packet.
- Checks run:
  - `swift build` and `swift test --filter EchoTypeBenchTests` (16 tests) pass.
  - Reran `cleanup --provider apple --repeat 3` (`20261004T101156Z-apple`),
    `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 3`
    (`20261004T101339Z-local`) and `transcribe --provider apple --fast --repeat 2
    dictation-short-reply` (`20261004T101516Z-apple`), then `report` on each, on
    `20261004T083627Z-apple` (older transcribe run), on two older cleanup runs
    (`20261004T095458Z-apple`, `20261004T095406Z-local`, no new fields) and the two-run comparison.
    All report. Older runs show all results warm, no cold or cancellation figures and `—` in the
    new columns.
  - Read the raw `cleanup.jsonl`, `preparation.json` and `sampler.json` of the local run to check
    the figures by hand. Core, providers and `Reviser` are untouched (`git diff` on
    `Sources/EchoTypeCore` is empty).
- Acceptance criteria:
  1. Met. `--repeat` is parsed once in `RunOptions` (rejects 0 and non-numbers), both commands loop
     over repeats, and both result types record `repeatIndex`.
  2. Met for transcribe and for cleanup's `warm stop-to-insert` / `warm revision` with p50, p95 and
     n, apart from the cold figure. The cold *revision* figure is wrong in one case (finding 1).
  3. Met. `preparation.json` is written for every run, with the message sequence and times. Phases
     split "Downloading models" from "Loading the cleanup model" (tested; a real download was not
     exercised, the models were installed).
  4. Met for completed runs. `sampler.json` exists in every completed run directory and `report`
     prints peak, ready, worst thermal state and worst memory pressure. An interrupted run has none
     (Optional 3).
  5. Met. Deadline fallbacks and overruns print apart from `validation rejections`, which is
     `rejected` plus `replyRequestRemoved`. I confirmed in `Reviser` that `finish` is the only
     thing that cancels a live revision in the bench, and that the three-second timer is the only
     thing that cancels a final one, so `cancelled` classifies correctly. Not exercised on a real
     deadline hit; covered by the unit test only, as the handoff says.
  6. Met. Old cleanup and transcribe runs report; `finishCalledAt` and `repeatIndex` decode as nil,
     and `.secondsOrMilliseconds` reads the old whole-second dates.
  7. Met.
- Boundaries and ownership: within `Sources/EchoTypeBench/`, `Tests/EchoTypeBenchTests/` and a
  paragraph in `docs/specs/test-harness.md` that matches what was built. The `plan.md` row change
  is the lead's. No change to `Reviser`, providers or the prompt. Consumes `run.json` and the
  candidate arguments unchanged.
- Required findings:
  1. **Cold first revision is wrong when the cold sample's first request is the live one that
     `finish` cancels.** `Report.swift` (`ScoredCleanupRun.totals`) takes
     `coldRevision = cold?.attempts.first.duration` without the filter it applies to warm
     revisions, and then removes the cold sample's first *non-cancelled* attempt from the warm set
     with `.dropFirst()`. When `attempts.first` is a live revision cancelled by `finish`, which is
     what every single-segment sample produces, the two disagree: the cancelled attempt is reported
     as "first revision" and the real cold request (the final revision) is silently dropped from
     warm too, so it appears in neither. Evidence: `cleanup --provider apple --repeat 2
     cleanup-question-not-answered cleanup-nothing-to-change` (`20261004T101631Z-apple`). The first
     sample's attempts are `cancelled live 0.002 s`, then `rejected final 1.815 s`; `report` prints
     `first revision 2 ms` and `warm revision ... (n=3)`, where the cold final request of 1815 ms
     is lost. With the default full-corpus order the first sample happens to have a completed live
     request first, so the headline run looks right, but workstream 4 can run subsets and the cold
     first-request figure is one of the measures the packet names. Fix by deriving cold and warm
     revisions from one definition: take the cold request as the first non-cancelled attempt of the
     cold sample (the same predicate used for warm revisions), and warm revisions as every other
     non-cancelled attempt. That removes the `dropFirst` special case. Add a focused test with a
     cold sample whose first attempt is a cancelled live revision.
- Optional observations:
  1. Cancellation latency includes live revisions cancelled before the model started, which
     contribute 0 to 3 ms (4 of 33 in the local run, 33 of 33 on Apple where cancellation is
     near-instant). They do not move p50 or p95 for the local run but say nothing about
     interruptibility. Counting only revisions with `duration > 0`, or noting the share, would
     make the figure more honest for workstream 4. Not blocking: the packet defines the figure as
     finish-to-end of the cancelled live revision.
  2. `Sampler` holds two `Mutex`es and a self-capturing task for what is one list and one loop.
     One `Mutex` over a small state struct, or an actor, would be simpler. Not blocking.
  3. A run interrupted with Ctrl-C or killed after the run directory exists leaves no
     `sampler.json`, though `preparation.json` and the partial log remain. The handoff states this.
     Writing the sampler file from a `defer` would close it cheaply; accepting it is also fine for
     a bench the user watches.
  4. `RunMeasurements` swallows decode errors with `try?`, so a corrupt `sampler.json` quietly
     removes the machine line. Acceptable for a bench, but a one-line "unreadable" note would stop
     a missing line being mistaken for an old run.
  5. `memoryPressureName` returns "normal" when the sysctl fails, so a failed read looks like the
     best case. The sysctl worked here (a real `warning` was recorded).
- Questions:
  1. For cleanup, the cold sample's later requests count as warm revisions while the whole sample
     is excluded from warm stop-to-insert. This is documented and defensible; the lead should
     confirm it is what the results record should cite, since stop-to-insert and revision
     durations then cover different populations (n=32 against n=50).

## Resolution

- Finding dispositions:
  1. Fixed. `ScoredCleanupRun.totals` now calls `requestDurations(cold:warm:)` in
     `Measurements.swift`, which filters attempts once (every final revision and every live
     revision not cancelled by `finish`): the cold sample's first such request is the cold request
     and every other one is warm. The `attempts.first` read and the separate `dropFirst` on a
     differently filtered list are gone. New test
     `coldRequestSkipsCancelledLiveRevisions` has a cold sample whose first attempt is a cancelled
     live revision. The handoff's Decisions text on "Cold" and the `first revision` field now say
     "first served request".
  - Optional observations 1-5: not addressed; the lead deferred them.
  - Question 1 (cold sample counts as warm for revision duration but not for stop-to-insert, so
    n differs): accepted as documented, no change.
- Lead triage: finding 1 accepted as Required (a measure the packet names was wrong for subset
  runs). Optional observations 1-5 deferred. For workstream 4: cancellation latency includes live
  revisions cancelled before the model started (0 to 3 ms; all of Apple's), so cite the local
  run's p95 rather than treating the figure as model interruptibility alone. Question 1 accepted.
- Simplification/deletion pass: removed the two inline `revisions` closures, `coldRevision` and
  `warmRevisions` from `Report.swift` in favour of one pure function and one result. No wrapper,
  flag or new type was added; the function's single `dropFirst` is inside the one definition
  rather than a second special case. The spec paragraph in `docs/specs/test-harness.md` stays
  accurate ("the run's first result is the cold request"), so it is unchanged.
- Final verification: passed.
  - `swift build` and `swift test --filter EchoTypeBenchTests` (17 tests).
  - `cleanup --provider apple --repeat 2 cleanup-question-not-answered cleanup-nothing-to-change`
    (`20261004T101828Z-apple`) and `report` on it: `first revision 1626 ms` (the cold final
    request, rejected, 1.626 s; the cancelled live attempt of 2 ms is no longer reported) and
    `warm revision p50 749 / p95 762 ms (n=3)`, so all four served requests appear exactly once.
  - `report` on `20261004T083627Z-apple` (older transcribe run) prints as before, all results
    warm.
  - The packet's `--provider local` and transcribe runs were not rerun; this pass touched only
    the cleanup revision split in `report`.

## Closure review

- Verdict: Accepted. The one Required finding is fixed and the fix introduces no
  release-blocking defect.
- Remaining required findings: none.
- Finding 1 (cold first revision): `requestDurations(cold:warm:)` in `Measurements.swift` filters
  attempts once (every final revision, and every live revision not cancelled by `finish`). The
  cold sample's first such request is the cold request and every other served request is warm.
  `ScoredCleanupRun.totals` in `Report.swift` calls it, and the old `attempts.first` read and the
  separate `dropFirst` are gone. `coldRequestSkipsCancelledLiveRevisions` covers a cold sample whose
  first attempt is a cancelled live revision. When the cold sample is ambiguous or errored, `cold`
  is nil and the sample is in no figure, so nothing is counted twice or lost.
- Verification, all passing on the working tree:
  - `swift build` and `swift test --filter EchoTypeBenchTests` (17 tests).
  - `cleanup --provider apple --repeat 3` (`20261004T101924Z-apple`): exact 15/33, validation
    rejections 6 of 9 fallbacks, no deadline fallbacks or overruns, warm revision n=50, cold first
    revision 1629 ms, preparation 186 ms, machine line present.
  - `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 3`
    (`20261004T102109Z-local`): exact 24/33, warm stop-to-insert n=32, warm revision n=50,
    cancellation latency p50 148 / p95 422 ms, first revision 288 ms, preparation 2838 ms (Loading
    the cleanup model), footprint peak 2573 MiB, ready 2374 MiB.
  - `transcribe --provider apple --fast --repeat 2 dictation-short-reply`
    (`20261004T102245Z-apple`): rows `#1` and `#2`, preparation and machine lines, no latency
    figures as before for fast runs.
  - `report` on each of those three run ids and on `20261004T083627Z-apple` (older run): reports
    as before, all results warm, no cold figures.
- The cold revision on both cleanup runs is a served request (not the 1 to 4 ms cancelled live
  attempt), and the warm and cold counts add up to the same requests the first review counted.
- Optional observations 1 to 5 and Question 1 stay deferred, as the lead decided. They are not
  promoted.
