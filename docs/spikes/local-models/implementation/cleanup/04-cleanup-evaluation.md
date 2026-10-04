# Workstream 4: Cleanup evaluation and results

Status: not started.

## Task packet

### Outcome

`docs/spikes/local-models/results.md` holds a cleanup section that compares `qwen3-4b-2507` and
`smollm3-3b` with Apple and xAI on the same samples, and recommends a cleanup candidate, a
narrower use, or rejection. Every figure traces to a bench run id.

### Scope

1. **Runs.** All runs from the repository root, on the M1 Pro, with nothing else heavy running.
   - Quality: `--fast --repeat 3` for Apple and each local candidate.
   - Latency, memory and deadline: paced `--repeat 15` for Apple and each local candidate.
   - Cold start: for each local candidate, one paced run in a fresh process after the model is
     installed, so preparation covers loading and warming without download.
   - Offline: each local candidate's quality run repeated with network access denied, using the
     built binary, after the model is installed:
     `sandbox-exec -p '(version 1)(allow default)(deny network*)' .build/debug/EchoTypeBench cleanup --provider local --candidate cleanup=<name> --fast`.
     `sandbox-exec` is deprecated but was verified to block network access on this Mac on
     2026-10-04.
2. **xAI gate.** After the runs above, open the external validation gate. Aidan runs:

   ```bash
   XAI_API_KEY=$(security find-generic-password -s com.aidanzealley.echotype -a xai -w) \
     swift run EchoTypeBench cleanup --provider xai --repeat 15
   ```

   from the repository root and sends back the run id it prints. Paced, so its latency is
   comparable. It sends only the hand-written cleanup samples to xAI.
3. **Report.** `swift run EchoTypeBench report` over every run, Apple, xAI and both candidates
   together where the comparison helps.
4. **Results.** Create `docs/spikes/local-models/results.md` with a cleanup section covering:
   - exact candidates, manifests' revisions, dependency pins, download and installed disk size;
   - quality against Apple and xAI: exact matches, wrong deletions, missed edits,
     not-a-deletion, validation rejections and other fallbacks, with ambiguous samples judged
     by reading their outputs;
   - warm latency: revision duration and stop-to-insert p50/p95/n, and the share of dictation
     time spent revising;
   - cold start: download, load and warm, and first request, kept apart from warm figures;
   - deadline behaviour: deadline fallbacks, overruns, cancellation latency, and whether the
     three-second final deadline is enforceable with this runtime, including during prefill;
   - memory: peak and idle `phys_footprint`, thermal state and memory pressure;
   - offline result;
   - recommendation, with the plain quality gap to xAI, and whether draft-model speculation or
     constrained decoding is worth a follow-up, per the spec's conditions. Propose; do not build.
   - Mark every xAI figure as a paid comparison, per the spec's "Evaluation".
5. Keep the spec and research in sync if a candidate or fact changed.

### Non-goals

- Any code change other than the smallest bench fix needed to complete a run; record one in the
  handoff and treat it as drift.
- Draft-model speculation, constrained decoding, prompt changes or extending the deadline.
- Transcription, read aloud, the app, or concurrent-service measurements.
- Comparing more candidates than the two named.

### Initial ownership

- `docs/spikes/local-models/results.md` (create it).
- `docs/spikes/local-models/spec.md` and `research.md`, only to keep them in sync.

### Required seams

Consumes workstream 2's candidates and workstream 3's report fields unchanged.

### Acceptance criteria

1. Every figure in the results names its run id, and the run ids exist under
   `~/Library/Application Support/EchoTypeBench/runs/`.
2. Each candidate has quality, warm latency, cold start, deadline, memory and offline results.
3. Apple and xAI baselines use the same samples and the same `report` fields.
4. Distributions give p50, p95 and n, and cold and warm figures are not mixed.
5. Both local candidates ran with network access denied.
6. The recommendation follows from the figures and states the remaining gap to xAI plainly.
   Poor results are a valid outcome.

### Targeted verification

```bash
swift build
swift run EchoTypeBench report 20261004T083627Z-apple
```

Then rerun `swift run EchoTypeBench report` on every run id the results cite, and check each
quoted figure against its output.

## External validation

- Gate and placement: xAI cleanup baseline, after the local and Apple runs and before writing
  results.
- Status: `Pending`
- Candidate and instructions: the command in scope step 2.
- Required evidence: the run id of a completed `cleanup --provider xai` run with 15 repeats and no
  run-level errors.
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan's answer, recorded in the plan's escalation entry, names the run id.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Run ids: `TBD`
- Decisions: `TBD`
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
