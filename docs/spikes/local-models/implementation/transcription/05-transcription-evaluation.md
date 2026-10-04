# Workstream 5: Transcription evaluation and results

Status: not started.

## Task packet

### Outcome

`docs/spikes/local-models/results.md` has a transcription section that compares Parakeet Unified
(with and without keyterm boosting) and Whisper Turbo with Apple and xAI on Aidan's corpus, and
measures cleanup running alongside the preferred transcriber. It ends with a recommendation. The
cleanup section gains release-build timing for Qwen3. Every figure cites the run it came from.

### Scope

Run everything from a release build of the bench (`swift run -c release EchoTypeBench ...`), on the
machine as it is; do not wait for it to be quiet. Record each run's load average from `report`.

1. **Standalone transcription,** one paced pass over every reviewed dictation sample for
   `parakeet-unified`, `parakeet-unified-keyterms` and `whisper-turbo`. One pass gives about 14
   warm samples per run: enough for accuracy and p50, while p95 is close to the slowest sample;
   say so beside the figures. The baselines are existing paced runs, both one pass from a debug
   build before the sampler existed, so they have no cold split, memory or load figures: Apple
   `20261004T083627Z-apple` (Apple's model runs outside the bench process, so the build barely
   affects it) and xAI `20261004T073341Z-xai`. Do not run xAI.
   If two candidates are too close to choose between on one pass, add `--repeat 3` runs for those
   candidates only, and record why.
2. **First download and cold start,** for each transcription candidate and for `qwen3-4b-2507`:
   move its installed directory aside under the README's download rule, then run one sample
   (`dictation-short-reply`, or a `cleanup` sample for Qwen3) to capture download and first load,
   then the same again in a fresh process to capture a load from installed files. Record download
   time and size, first-load time (and whether Core ML compiled anything), the cold load, and disk
   used including any compiled caches. For one transcription candidate, also kill the bench
   partway through its download and rerun: record that the partial files were not loaded and the
   model installed and verified (slice 1 tested this only with an injected source). A first load
   after a reboot or OS update is not measured; say so.
3. **Offline,** for each transcription candidate: a `--fast` run with network access denied
   (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built release binary),
   checked against its online run.
4. **Choose the preferred transcription candidate** from steps 1-3, with reasons, before step 5.
5. **Concurrent dictation,** one paced pass with the dictation run from workstream 3: the
   preferred candidate with `qwen3-4b-2507`, and Apple with Apple cleanup for comparison.
6. **Cleanup in release:** `cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 15`,
   paced, to set beside slice 1's debug run `20261004T110130Z-local`.
7. **Write results.** Add a transcription section to `results.md` in the cleanup section's style
   and add the release cleanup timing to the cleanup section without removing the debug figures.
   Update the file's status line and the conditions that limit the figures (debug or release, and
   load average, per run). Correct `research.md` where a measurement contradicts it, as slice 1
   did.

The transcription section covers:

- runs, candidates (repository, revision, licence and any licence conflict, download and disk
  size, keyterm limit, live-handling settings), dependency pins and integration changes;
- accuracy: word error rate, formatted word error rate, keyterm accuracy, silence insertions and
  changed committed text, overall and per sample where a sample explains a difference;
- the references' bias: they began as xAI drafts that Aidan corrected, so xAI's error rates are
  flattering. State it beside every comparison with xAI;
- keyterm boosting: what it changed in keyterm accuracy and error rate, and what it cost in commit
  lag (first committed text and the gap between speech and committed text);
- latency: first provisional, first committed and stop-to-final, warm p50/p95/n with the cold
  sample apart;
- cost: preparation, download, first load, cold load, footprint peak and ready, memory pressure
  and thermal state, noting that Core ML work on the Neural Engine may be charged to system
  processes, so process footprint can understate it;
- concurrent dictation: stop-to-insert and its parts, deadline fallbacks and overruns,
  cancellation latency, revising share and combined footprint, against slice 1's standalone
  cleanup figures and Apple's dictation run;
- the signed-app check's outcome, from [04-app-provider.md](04-app-provider.md)'s External
  validation section;
- a recommendation: the preferred transcription candidate and keyterm setting, whether the
  build's default selection should change, the remaining gap to xAI and Apple stated plainly, and
  whether any spec follow-up (Unified's offline re-decoding, Nemotron or Ultra) is triggered by a
  measurement, using the spec's conditions.

### Non-goals

- Product code changes. A bench defect that blocks a run is fixed with the smallest change and
  recorded in the handoff; anything larger is an escalation.
- Read aloud, the voice comparison build, energy, or new paid runs.
- Changing `LocalSelection.build`; recommend instead.

### Initial ownership

- `docs/spikes/local-models/results.md` and `docs/spikes/local-models/research.md`.
- `Sources/EchoTypeBench/` only for a blocking defect as above.

### Required seams

- Consumes the candidates and bench as workstreams 1-4 built them; read their handoffs for
  settings, report fields and the signed-app outcome.

### Acceptance criteria

1. Every run in scope exists and is cited by id, and every new run was a release build; every figure, bullet and
   table row in the new and changed sections names its run, including derived figures.
2. The transcription section covers every bullet above, including the reference bias, keyterm
   boosting's cost, concurrent dictation and the signed-app outcome.
3. Each recommendation follows from cited figures, and claims are scoped to what was measured.
4. Unmeasured items (first load after reboot, energy, read aloud) are named as not measured.
5. No recording, reference text or personal content beyond sample ids and short excerpts `report`
   prints appears in the documents.

### Targeted verification

```bash
swift build -c release --product EchoTypeBench
swift run -c release EchoTypeBench report <each cited run id>
```

Check that each figure in `results.md` matches its `report` output or, for derived figures, the
run's log.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Runs, with what each is for: `TBD`
- Preferred transcription candidate and why: `TBD`
- Decisions: `TBD`
- Bench fixes, if any: `TBD`
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
