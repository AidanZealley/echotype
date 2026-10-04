# Workstream 3: Bench dictation with cleanup

Status: accepted.

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

- Base commit: `0beb10ba58155e9ded2a352313d8190bd167c5d1`
- Outcome: the existing `transcribe` loop supports paced dictation with real live cleanup.
  The local and Apple three-sample runs both complete without errors or contract violations.
  Reports show transcript scores, inserted text, stop-to-insert and its parts, revision duration,
  deadline behaviour, cancellation latency, revising share, footprint and load average.
- Files changed:
  - `Sources/EchoTypeBench/Transcribe.swift`: dictation validation, joint readiness, a fresh
    `Reviser` per sample, live submissions and final revision in the existing event reader,
    optional dictation records and split insertion timing. Existing audio feeding, event
    timing and contract checks remain the common path.
  - `RunOptions.swift`: `--cleanup` and both local candidates for a dictation run.
  - `Cleanup.swift`: rejects the transcribe-only `--cleanup` argument.
  - `RunInfo.swift`: records `buildConfiguration` using the compiler's `DEBUG` condition.
  - `Measurements.swift`: optional preparation service names, one-minute load average in every
    sampler reading, median/maximum reporting and `StopToInsert`.
  - `Report.swift`: optional build configuration, dictation rows and inserted text, split warm
    and cold timing, and the existing cleanup measurement functions applied to dictation traces.
  - `main.swift`: documents dictation syntax, load average, build configuration and Whisper.
  - `Tests/EchoTypeBenchTests/MeasurementsTests.swift`: two focused tests for total insertion
    timing and rejecting fast dictation or a provider without cleanup before setup.
  - `docs/specs/test-harness.md`: the bench section describes these additions.
- Command and report fields for workstream 5:
  - Run `swift run -c release EchoTypeBench transcribe --provider local --cleanup [<id>...]`.
    Select either model with repeatable `--candidate transcription=<name>` and
    `--candidate cleanup=<name>` arguments. Omitted candidates use the build's selection.
    `--repeat <n>` remains available. Apple uses the same command with `--provider apple`.
  - `run.json` still identifies the command as `transcribe`; `arguments` includes `--cleanup`,
    `candidates` contains both service names for local dictation, and `buildConfiguration` is
    `debug` or `release`. Reports show that configuration in the run heading.
  - `transcribe.jsonl` retains every previous transcription field. `finalText` remains the
    final committed transcript and is the sole input to WER, formatted WER and keyterm scoring.
  - New optional `dictation` is a `CleanupResult`: `input`, inserted `finalText`,
    `attempts` as `DictationTrace.Revision` records, `finishCalledAt`, `stopToInsertMs`,
    `revisingShare`, `fallbacks`, `error`, `id` and `repeatIndex`. Its `finishCalledAt` is when
    `Reviser.finish` starts after `.finished`, and its `stopToInsertMs` covers that final cleanup.
    Dates retain milliseconds through the existing encoder/decoder conventions.
  - New optional `stopToInsert` holds `transcriptionMs`, from audio feeding ending and the
    transcriber being told to finish until `.finished`, and `cleanupMs`, from `.finished` until
    the inserted text returns. Their sum is the end-to-end figure printed by `report`.
  - `preparation.json.services` lists `transcription` and `cleanup` for dictation. Readiness
    messages capture simultaneous preparation and the total wait ends only when both are ready.
    The sampler starts before preparation and takes a ready reading after both models load.
  - `sampler.json` adds optional `loadAverage` to each reading, from `getloadavg`'s one-minute
    value. Reports print `load average median` and `max`, alongside the existing footprint,
    thermal and pressure fields, for transcription, cleanup and dictation runs that recorded it.
  - Dictation report columns are `stop-to-insert`, `transcription`, `cleanup`, `cancel`,
    `deadline` and `revising`. Inserted text appears below the tables and is not scored.
    Totals add `deadline fallbacks`, `deadline overruns`, `warm stop-to-insert` with
    `transcription` and `cleanup` parts, `warm revision`, `cancellation latency`, and `revising`.
    `cold stop-to-insert`, its parts and `first revision` remain separate from warm figures.
- Decisions:
  - Dictation is an option on transcription, not a second sample loop or a new command.
    The event reader submits each transcript's committed text and finishes the reviser on
    `.finished`. Session teardown joins the transcriber and stops the reviser.
  - Reuse `CleanupResult` and the existing `requestDurations`, `deadlineOutcome`,
    `cancellationLatencyMs`, fallback classification and cold-sample filtering. No provider,
    reviser, app, model-store or build-selection code changes.
  - Joint readiness combines waiting messages, so the preparation record can show both models
    loading concurrently. These are elapsed phases of joint setup, not separate service timers.
  - Simplification pass removed a separate inserted-text detail rendering and force-unwrapping
    of dictation records in totals. There is no parallel dictation runner, new service enum,
    compatibility alias or generic lifecycle machinery.
- Verification: all passed on the M1 Pro, on the source changes listed above before evidence runs.
  - `swift build`; `swift test --filter EchoTypeBenchTests`, 19 tests; `swift test`, with the
    core, bench and app test runners passing 140, 19 and 76 tests respectively; `git diff --check`.
  - Local paced dictation, three named samples from the packet: `20261004T194828Z-local`,
    debug build, `parakeet-unified` plus `qwen3-4b-2507`, zero errors and violations.
    Its preparation messages contain both model-loading services and its sampler spans their
    preparation and concurrent use. Reported peak footprint is 2672 MiB, ready 2380 MiB,
    load average median 6.71 and maximum 8.45. Warm stop-to-insert p50/p95 is 1549/2655 ms,
    transcription 92/112 ms and cleanup 1438/2563 ms, each n=2. Cold insertion is 1193 ms.
    Deadline fallbacks/overruns are 0/0, cancellation p50/p95 1/22 ms, n=3, and revising 27.0%.
  - Apple paced dictation, the same samples: `20261004T195053Z-apple`, debug build, zero errors
    and violations. Warm insertion p50/p95 is 1381/1961 ms, transcription 229/234 ms and
    cleanup 1152/1727 ms, each n=2. The cold short reply exercises a deadline fallback with
    cleanup 3013 ms and total insertion 3155 ms. Deadline fallbacks/overruns are 1/0,
    cancellation p50/p95 0/1 ms, n=2, and revising 40.9%. Peak footprint is 35 MiB;
    load median/maximum is 5.81/6.88.
  - `report` on both new dictation runs passes and shows all fields above plus inserted text.
  - `swift run -c release EchoTypeBench transcribe --provider apple --fast dictation-short-reply`
    produces `20261004T195457Z-apple`, zero errors and violations, with `buildConfiguration`
    equal to `release`. Its report passes and explicitly suppresses fast-run latencies.
  - `report 20261004T110130Z-local` and `report 20261004T160810Z-local` pass. Each regenerated
    `report.md` is byte-identical to its saved pre-change report, proving existing cleanup and
    transcription figures remain unchanged. Neither displays a load field it did not record.
  - The fast dictation CLI exits 1 with the paced-audio error and creates zero run directories.
    `swift test --skip-build --filter dictationRequiresPacedAudioAndCleanup` passes with an
    Apple-derived provider whose cleanup is nil and creates zero run directories. Every
    registered provider currently has cleanup, so this fixture checks the unsupported-provider
    validation used by the command without introducing another production provider.
  - No xAI call was made. Recordings, transcripts and run directories remain outside git.
- Known limitations:
  - These three-sample debug runs verify the bench, not candidate selection or representative
    release latency. Workstream 5 should make its release evidence runs using the command above.
  - `phys_footprint` measures the whole bench process with both local models prepared and used,
    not separate model allocations. Core ML/ANE memory may be attributed to system processes
    and understated, as the spike spec and workstream 1 already note. Apple's model work also
    runs outside the bench process. The sampler's measurement method is unchanged.
  - The local run did not hit a final deadline; Apple exercised one fallback, and existing pure
    tests verify overrun classification. A busy machine is allowed and the recorded load
    accompanies each run's timing.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent Codex agent, workstream 3.
- Verdict: pass. No Required findings.
- Required findings: none.
- Optional observations: none.
- Questions: none.
- Scope and correctness: inspected the complete uncommitted diff and status, including the
  absence of untracked files, against base `0beb10ba58155e9ded2a352313d8190bd167c5d1`.
  Implementation changes stay within bench, bench tests and the harness spec's bench section;
  the packet handoff and the lead's plan status are the expected workflow records. The existing
  transcription loop remains shared. Each sample gets a fresh real `Reviser`, submits committed
  text, finishes after the final transcript and `.finished`, and stops cleanup after closing and
  joining transcription. Candidate selection prepares and records both local services. No app,
  provider, model-store or build-selection code changed; no parallel runner or speculative
  machinery was added.
- Acceptance checks:
  - Criteria 1-3: independently read the on-disk records for `20261004T194828Z-local` and
    `20261004T195053Z-apple` and regenerated their reports. Both contain exactly the three
    required named samples with no errors or contract violations. Local selection records
    `parakeet-unified` and `qwen3-4b-2507`; preparation names both services and records both
    loading together, and the sampler spans preparation and use. Reports show the insertion
    split, deadline outcomes, cancellation, revising share, footprint and load average.
  - Criterion 4: the debug CLI rejects fast dictation with exit 1 and creates zero run
    directories, checked with before/after directory sets. The focused unsupported-cleanup
    fixture passes, and the validation call precedes credentials, readiness and run creation.
  - Criterion 5: inspected debug metadata in both paced runs and release metadata in
    `20261004T195457Z-apple`. Also reran the required release fast Apple command, producing
    `20261004T200200Z-apple`, with no errors or violations and `buildConfiguration: release`.
    Its report passes and suppresses fast-run latencies.
  - Criteria 6-7: regenerated reports for `20261004T110130Z-local` and
    `20261004T160810Z-local`. Old records decode without load or build configuration; load
    appears only in the new runs. Reviewed that standalone scoring and timing calculations
    are untouched; the handoff's pre-change byte comparisons provide additional evidence.
  - Criterion 8: independently reran `swift build`,
    `swift test --filter EchoTypeBenchTests`, and `swift test`; all pass. Bench has 19 tests;
    core and app runners pass 140 and 76 tests. `git diff --check` passes.
- Evidence reuse: the handoff's paced runs exist, their recorded results match their reports,
  and every bench source file predates the first run. No source change followed those runs,
  so repeating the two paced passes would add no needed verification. The independent review
  reran builds, tests, reporting, release transcription and early-rejection checks instead.
  No xAI call was made. Personal recordings, transcripts and runs remain outside git.

## Resolution

- Finding dispositions: independent review reports no Required, Optional or Question findings.
  Lead agrees; no remediation pass is needed.
- Simplification/deletion pass: lead verified one transcription loop, reuse of cleanup records
  and measurement functions, and no changes outside bench ownership. No further deletion needed.
- Final verification: independent review repeated build, bench tests, full tests, reports,
  release transcription and early rejection. All passed. Fresh focused closure repeated the
  required checks on unchanged code and passed with no release-blocking findings.

## Closure review

- Verdict: pass. No release-blocking defect found in the completed candidate.
- Remaining required findings: none. The independent review accepted no findings, and no
  remediation or bench source changes followed implementation.
- Verification: independently reran `swift build`, `swift test --filter EchoTypeBenchTests`,
  `swift test` and `git diff --check`; all passed. The bench runner passes 19 tests, including
  unsupported cleanup and fast-dictation validation. The core and app runners also pass.
- Reused paced evidence `20261004T194828Z-local` and `20261004T195053Z-apple` after checking
  every bench source file predates both runs. Both contain exactly the required three samples,
  zero errors and zero contract violations. Local metadata records both selected candidates
  and both preparation services. Regenerated reports match the saved reports byte for byte and
  include insertion timing and its parts, deadline outcomes, cancellation, revising share,
  footprint and load average. No repeated paced pass was needed on unchanged source.
- Regenerated legacy cleanup `20261004T110130Z-local` and transcription
  `20261004T160810Z-local` reports. Both remain byte-identical and omit unrecorded load.
- Reran the required release fast Apple command, producing `20261004T200612Z-apple` with
  release metadata, zero errors and zero violations. Its report passes and suppresses fast-run
  latency. The debug fast-dictation command exits 1 before creating any run directory, verified
  against before/after directory sets. No xAI calls were made.
