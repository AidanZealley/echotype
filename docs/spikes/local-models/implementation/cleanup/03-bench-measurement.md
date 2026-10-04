# Workstream 3: Bench measurement for local services

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Report fields added: `TBD`
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
