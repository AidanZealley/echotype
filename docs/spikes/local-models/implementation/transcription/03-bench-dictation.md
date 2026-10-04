# Workstream 3: Bench dictation with cleanup

Status: not started.

## Task packet

### Outcome

The bench can run a whole dictation the way the app does: a sample's audio streams through a
provider's `LiveTranscriber` at real-time pace while a real `Reviser` revises its committed text
live, and `finish` produces the inserted text. A run records transcription and cleanup together,
so `report` gives end-to-end stop-to-insert, deadline behaviour, cancellation latency, revising
share and combined memory, for any provider with cleanup. Every `transcribe`, `cleanup` and
dictation run also records the machine's load average and whether the bench was a debug or
release build.

### Scope

- **Dictation run.** Suggested as `transcribe --cleanup`, reusing `transcribe`'s sample loop,
  audio feeding, event reading and contract check rather than a parallel copy. Drive the
  `Reviser` as `Sources/EchoTypeApp/DictationOperation.swift` does: `submit(committed:)` with each
  transcript's committed text, then on the transcriber's `.finished`,
  `finish(committed:)` with the final committed text. Paced only; reject `--fast`, whose timing
  means nothing here. A provider without cleanup is an error before the run starts.
- **Selection.** A local dictation run prepares the selected transcription and cleanup candidates
  (`--candidate` for either, the build's selection otherwise), per the plan's bench arguments
  contract. `run.json` records both.
- **Records,** per sample: everything `transcribe` records now, plus the revision trace,
  `finish` time, inserted text, stop-to-insert (end of audio to the inserted text) and its parts
  (end of audio to `.finished`, then `.finished` to the inserted text). Reuse cleanup's
  `DictationTrace` revision records and measurement functions so deadline fallbacks, overruns,
  cancellation latency and revising share mean exactly what they mean for `cleanup`.
- **Report.** Word error rate and keyterms score the transcript (the final committed text), as
  `transcribe` does; the inserted text is shown, not scored. Latency lines as for both commands,
  with stop-to-insert split into its parts, and the cold sample kept apart as now.
- **Load average.** The sampler records the one-minute load average with every sample
  (`getloadavg`), and `report` prints its median and maximum for every run that has it. Runs
  recorded before this change still report.
- **Build configuration.** `run.json` records whether the bench was built for debug or release,
  and `report` shows it, so a cited latency figure states which it came from.
- Update the harness spec's bench section to describe the dictation run, load average and build
  configuration as built, in a sentence or two each.
- Focused tests only for new pure logic, such as splitting stop-to-insert.

### Non-goals

- Any provider, `Reviser` or app code change.
- Lifecycle scenarios, the app driver, guided sessions, `speak` or the listening page.
- Energy measurement, or any change to how existing figures are computed.

### Initial ownership

- `Sources/EchoTypeBench/` (all files) and `Tests/EchoTypeBenchTests/`.
- `docs/specs/test-harness.md`, bench section only.

### Required seams

- Consumes the selection and candidate contracts as workstreams 1 and 2 built them (see their
  handoffs) and slice 1's measurements (handoff in
  [cleanup/03-bench-measurement.md](../cleanup/03-bench-measurement.md)).
- Produces the dictation run and report fields workstream 5 cites; name each in the handoff.

### Acceptance criteria

1. A local dictation run with the build's selection (Parakeet Unified and Qwen3) completes three
   named dictation samples, including `dictation-long-continuous`, with no contract violations,
   and `report` shows stop-to-insert with its parts, deadline fallbacks and overruns,
   cancellation latency, revising share, footprint and load average.
2. The same run with `--provider apple` completes, showing the run is provider-agnostic.
3. In the local run, `preparation.json` shows both services preparing and the footprint covers
   both models.
4. `--fast` with the dictation run, and a provider without cleanup, each fail before a run
   directory is created.
5. `run.json` for a run from `swift run -c release EchoTypeBench` records a release build, and
   one from `swift run EchoTypeBench` a debug build.
6. `report` on a slice 1 run (such as `20261004T110130Z-local`) and on a `transcribe` run from
   workstream 1 still works, with load average only where recorded.
7. Existing `transcribe` and `cleanup` figures are unchanged for the same run.
8. `swift test` passes.

### Targeted verification

```bash
swift build
swift test --filter EchoTypeBenchTests
swift run EchoTypeBench transcribe --provider local --cleanup dictation-short-reply dictation-self-correction dictation-long-continuous
swift run EchoTypeBench transcribe --provider apple --cleanup dictation-short-reply dictation-self-correction dictation-long-continuous
swift run EchoTypeBench report 20261004T110130Z-local
swift run -c release EchoTypeBench transcribe --provider apple --fast dictation-short-reply
```

Adjust the dictation command to the syntax you built, then `report` each new run. Do not run xAI.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Command and report fields for workstream 5: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations: `TBD`
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
