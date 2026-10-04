# Workstream 4: Cleanup evaluation and results

Status: accepted.

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
- Status: `Passed` (E1 answered 2026-10-04; run id `20261004T121048Z-xai`, verified by the resuming lead: `run.json` provider `xai`, command `cleanup`, `--repeat 15`, 180 result rows, no error rows, `report` prints with 0 fallbacks and no run-level errors)
- Candidate and instructions: the command in scope step 2.
- Required evidence: the run id of a completed `cleanup --provider xai` run with 15 repeats and no
  run-level errors.
- Attempts and lasting decisions: none yet.
- Resume condition: Aidan's answer, recorded in the plan's escalation entry, names the run id.

## Implementation handoff

- Base commit: `6eb5351`
- Outcome: Part 1 of 2, the evaluation runs only (scope step 1: Apple and both local candidates).
  All 10 runs completed, exit 0, with no run-level errors in `report` and no code change. Not
  done, by design: the xAI gate (scope step 2, opened by the lead; no Keychain read, no xAI run),
  and `results.md` (part 2).
- Run ids: all under `~/Library/Application Support/EchoTypeBench/runs/`, run one at a time from
  the repo root, `sourceRevision` `6eb5351` in every `run.json`. `swift build` was up to date
  before the runs (`.build/debug/EchoTypeBench` built 11:18 local). "Counts" are the totals line
  of `swift run EchoTypeBench report <id>`.

  | Run id | Purpose | Command |
  |---|---|---|
  | `20261004T105127Z-apple` | Apple quality | `swift run EchoTypeBench cleanup --provider apple --fast --repeat 3` |
  | `20261004T105222Z-local` | qwen3-4b-2507 quality | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast --repeat 3` |
  | `20261004T105256Z-local` | smollm3-3b quality | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b --fast --repeat 3` |
  | `20261004T105325Z-apple` | Apple paced: latency, deadline | `swift run EchoTypeBench cleanup --provider apple --repeat 15` |
  | `20261004T110130Z-local` | qwen3-4b-2507 paced: latency, memory, deadline | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --repeat 15` |
  | `20261004T110916Z-local` | smollm3-3b paced: latency, memory, deadline | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b --repeat 15` |
  | `20261004T111652Z-local` | qwen3-4b-2507 cold start (fresh process, installed) | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507` |
  | `20261004T111730Z-local` | smollm3-3b cold start (fresh process, installed) | `swift run EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b` |
  | `20261004T111803Z-local` | qwen3-4b-2507 offline quality | `sandbox-exec -p '(version 1)(allow default)(deny network*)' .build/debug/EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast` |
  | `20261004T111816Z-local` | smollm3-3b offline quality | `sandbox-exec -p '(version 1)(allow default)(deny network*)' .build/debug/EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b --fast` |

  Each run's `run.json` records `provider` and, for local, `candidates.cleanup`. Totals per run
  (`report`), as a check that each completed and not as the results:
  - `…105127Z-apple`: exact 15/33, fallbacks 9 (validation rejections 6), 0 deadline fallbacks
    and overruns.
  - `…105222Z-local` (qwen3): exact 24/33, wrong deletions 0, missed edits 39, fallbacks 3 (0
    rejections). `…105256Z-local` (smollm3): exact 24/33, wrong deletions 3, missed edits 33,
    fallbacks 6 (3 rejections).
  - `…105325Z-apple`: exact 75/165, fallbacks 45 (30), warm stop-to-insert p50 781 / p95 1627 ms
    (n=164), 0 deadline fallbacks and overruns.
  - `…110130Z-local` (qwen3): exact 120/165, fallbacks 15 (0), warm stop-to-insert p50 616 / p95
    2194 ms (n=164), warm revision p50 497 / p95 1766 ms (n=254), cancellation latency p50 151 /
    p95 417 ms, footprint peak 2573 MiB, ready 2381 MiB, 0 deadline fallbacks and overruns.
  - `…110916Z-local` (smollm3): exact 105/165, wrong deletions 15, fallbacks 75 (60), warm
    stop-to-insert p50 600 / p95 1989 ms (n=164), warm revision p50 479 / p95 1654 ms (n=254),
    cancellation latency p50 127 / p95 329 ms, footprint peak 2162 MiB, ready 1848 MiB, 0
    deadline fallbacks and overruns.
  - Cold runs (each n=1 repeat, so warm figures there are the other 11 samples): qwen3 cold
    stop-to-insert 539 ms, first revision 296 ms, preparation 2826 ms; smollm3 cold stop-to-insert
    488 ms, first revision 259 ms, preparation 3233 ms. Both preparations are only "Loading the
    cleanup model" (no download phase).
  - Offline runs: each identical in counts per repeat to its online `--fast` run (qwen3 exact 8/11,
    smollm3 exact 8/11 over the 11 counted samples); preparation 4206 ms and 3447 ms.
- Decisions: The xAI baseline is run `20261004T121048Z-xai` (E1, answered 2026-10-04): `cleanup
  --provider xai --repeat 15`, source revision `6eb5351`, 180 rows, no error rows, verified by the
  resuming lead with `report` (0 fallbacks). Aidan did not send the id (the orchestrator found it
  on disk) and did not say whether the machine was quiet, so `results.md` marks every xAI figure paid
  and its latency unverified-quiet. xAI has no `--fast` run; the same-mode comparison is the paced
  one. Cold-start runs use no `--repeat` (the packet says one paced run). The cleanup
  sample count is 12, 11 counted: `cleanup-ambiguous-correction` is ambiguous (manual) and sits
  outside every counted total, so `report` totals are over 11 samples per repeat (33, 165). Runs
  were driven by one sequential shell script writing to `/tmp/ws4-*.log`; nothing else was run
  concurrently.
- Verification:
  - Network denial. In the same sandbox profile, `curl https://huggingface.co` failed with
    `Could not resolve host` (exit 6); the same `curl` without it returned 200. Both offline runs
    went through `sandbox-exec` with the built debug binary, exit 0, all 12 samples completed,
    no download lines and no errors, preparation was a load only. The weights were installed, so
    the proof of "offline" is the sandbox check, not a download failing.
  - `report` was run on every id above (via `swift run` and, for the last four, the built binary);
    all print, and none shows a run-level error or a contract violation.
  - Machine quiet check. It was not quiet. The 1-minute load average before each run was: Apple
    quality 5.23, qwen3 quality 4.82, smollm3 quality 7.39, Apple paced 6.73, qwen3 paced 4.40,
    smollm3 paced 3.82, qwen3 cold 3.55, smollm3 cold 3.77, offline runs 4.23 and 4.12. `ps`
    showed WindowServer, photolibraryd, TextEdit and T3 Code busy; none were killed. `report`
    shows thermal state `nominal` in all ten runs. System memory pressure `warning` appeared in
    `…105222Z-local` and `…110130Z-local` (both qwen3); every other run reads `normal`. Treat
    latency figures as taken on a busy 16 GB machine.
  - `Models/Incomplete/` holds no files after the runs. `git status` shows only the orchestrator's
    `plan.md` edit plus this file; no code changed.
- Facts for `results.md` that `report` does not show:
  - Mac: MacBookPro18,3 (Apple M1 Pro), 16 GiB memory. macOS 27.2 (build 26B5091g). Xcode 27.0
    (27A266a), Apple Swift 6.4 (swiftlang-6.4.0.34.1), target arm64-apple-macosx27.2.0.
  - Candidates (from `LocalCandidates.swift`, store directory `<name>-<revision>`):

    | | qwen3-4b-2507 | smollm3-3b |
    |---|---|---|
    | Repository | `mlx-community/Qwen3-4B-Instruct-2507-4bit` | `mlx-community/SmolLM3-3B-4bit` |
    | Revision | `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b` | `d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce` |
    | Licence | Apache-2.0 | Apache-2.0 |
    | Files | 6 | 6 |
    | Download size (sum of manifest bytes) | 2,274,455,727 B (2.27 GB, 2.12 GiB) | 1,747,319,274 B (1.75 GB, 1.63 GiB) |
    | Installed (`du` of the model directory) | 2,224,400 KiB (2.1 GiB) | 1,721,748 KiB (1.6 GiB) |

    Largest file in each is `model.safetensors` (2,263,022,417 B and 1,730,051,993 B). The two
    directories total about 3.8 GB under `~/Library/Application Support/EchoType/Models/`.
    Thinking is disabled for SmolLM3 through its template's `enable_thinking: false`; Qwen3
    has no flag. Sampling is greedy.
  - Pinned dependencies (`Package.resolved`): mlx-swift 0.32.3 (`19601207e9a0de51e03ee6ec0c3c5f3784275075`),
    mlx-swift-lm no tag, revision `5e46681b2adcef2db158e7b949aeae3896778e23`, swift-transformers
    1.3.4 (`c21fdcde390313a6d98d8e33a346f2c3486c3ab0`), swift-jinja 2.5.1
    (`4588064a20f3fc093c95f2f7d3359999bf30cae5`), swift-huggingface 0.12.0
    (`0ece9a1ef443309d26a69af9897ee8ad82f43a9a`), swift-crypto 4.5.2
    (`da9d28d69ebe3894b18376c8f2395c2f37b8448f`), swift-syntax 603.0.2
    (`79e4b74a295b6eb74a8b585e3a39d29e70c1dbd1`), swift-collections 1.7.1
    (`98ef3c98609a1e31b7e157b5b619579001a789d6`), swift-numerics 1.1.1
    (`0c0290ff6b24942dadb83a929ffaaa1481df04a2`), swift-asn1 1.7.3
    (`3b6410f7dee09eb33cdd26260c5fd47fda19b0e2`), eventsource 1.5.1
    (`86b5096ac59ab46e66bd1f6377c604bc1dab0bc2`), yyjson 0.12.0
    (`8b4a38dc994a110abaec8a400615567bd996105f`).
  - Cleanup corpus (`Corpus/manifest.json`): 12 samples, hand-written. `cleanup-clear-correction`,
    `cleanup-correction-mid-sentence`, `cleanup-ambiguous-correction`,
    `cleanup-deliberate-repetition`, `cleanup-accidental-repetition`, `cleanup-false-starts`,
    `cleanup-fragments`, `cleanup-question-not-answered`, `cleanup-command-not-followed`,
    `cleanup-reply-request`, `cleanup-long-unpunctuated`, `cleanup-nothing-to-change`. All have an
    `expected`; one is ambiguous and goes to manual judgement: `cleanup-ambiguous-correction`
    (shown `(manual)` in `report`, left out of exact, deletion and latency totals). No sample was
    excluded.
  - Download not re-measured. Both models were already installed; first-download time (about a
    minute each) is only in workstream 2's handoff. The cold-start runs measure load plus warm
    in a fresh process, with the weight files likely in the OS page cache from the runs just
    before; they are not first load after reboot.
  - Apple's footprint figures (13 MiB peak) describe the bench process only, not Apple's
    out-of-process model, as workstream 3 noted. Cancellation latency includes live revisions
    cancelled before the model started (all of Apple's, 1 to 4 ms), so cite the local p95 only.
  - No run hit the three-second deadline: 0 deadline fallbacks and 0 overruns in every paced run,
    so whether it is enforceable during prefill rests on cancellation latency (qwen3 p95 417 ms,
    smollm3 p95 329 ms in the paced runs) and not on an observed timeout.
- Known limitations or external checks: The xAI run and `results.md` remain. The Mac was not
  quiet (above). Latency is on the debug build of the bench (`swift run` default configuration).
- Specification drift: none. No bench fix was needed and no code changed. `research.md` keeps its
  planning RAM estimates (3 to 4 GB qwen3, 2.5 to 3.5 GB smollm3) against measured peaks of 2.5 and
  2.1 GiB; `results.md` records the measurements.
- Part 2 note (results):
  - Created `docs/spikes/local-models/results.md` (cleanup section). No code, `spec.md`, `research.md`
    or `plan.md` change. `research.md` says 2.28 GB for qwen3 against 2.274 GB in the manifest and
    estimates 3 to 4 GB RAM against a 2.5 GiB measured peak; left as approximate planning figures.
  - Checks: reran `report` on all 11 cited run ids (with the built binary; the combined report on
    the four paced runs) and compared every quoted `report` figure with its output. Figures marked
    "derived" in the results (per-sample outcomes, longest request, per-sample medians, final
    fallback counts, cancellation latency by window, offline text equality) were computed from each
    run's `cleanup.jsonl`; they are not `report` fields. Outputs of all four paced runs were read per
    sample, including the manual `cleanup-ambiguous-correction`.
  - Findings that shape the results: qwen3 and xAI have the same final words on all 11 counted
    samples; both miss the same three; qwen3 differs in a length-cap failure on
    `cleanup-command-not-followed`. `--fast` and paced runs window text differently, so smollm3's
    long sample differs between them.
  - Not verified: the deadline timer was never exercised (0 fallbacks and overruns in every run);
    the enforceability bound (about 3.9 s) is an estimate from cancellation latency and the MLX
    Swift LM source (`PrefillParameters.forEachChunk`, per-token `Task.isCancelled`), and the token
    count of the longest window is approximate. The xAI machine state was not noted. The reply text
    of the qwen3 and smollm3 length-cap failures is not recorded. Latency is from a busy machine and
    a debug build. Concurrency with local transcription was not measured.

## Independent review

- Reviewer: fresh independent reviewer (read-only apart from this section).
- Verdict: Changes required. Two Required findings, both wording or traceability fixes in
  `results.md`. The figures are accurate, the recommendation follows from them, and no code,
  spec or research file was touched.
- Checks run:
  - `swift build` passes. `swift run EchoTypeBench report 20261004T083627Z-apple` prints (a
    transcription run, as the packet's smoke check). Reran `report` on all 11 cited cleanup run
    ids; every quoted `report` figure in `results.md` matches (quality, rejections and "other"
    fallbacks by subtraction, p50/p95/n, revising share, cold figures, preparation, footprint,
    thermal, pressure, deadline counts, offline totals). All 11 ids exist under the runs directory.
  - Recomputed the "derived" figures from each run's `cleanup.jsonl` with a script. All match:
    longest stop-to-insert (1702, 1759, 2232, 2034 ms), longest final request (1.70, 1.76, 1.85,
    1.78 s), per-sample medians for `long-unpunctuated` and `command-not-followed`, median revising
    share for the three multi-segment samples, final-revision fallback counts (45, 0, 15, 45),
    cancelled-before-start counts (38 of 165 and 20 of 165), per-run text stability (xAI varies only
    on the manual sample), offline final text equal to the online repeat 0, and the `--fast` versus
    paced difference on `long-unpunctuated`.
  - Read the final text and per-attempt results of every sample in the four paced runs against the
    sample-level outcomes table. Every cell is correct, including the Apple refusal on `fragments`,
    smollm3's "Paris" answer (reply `Certainly, the capital of France is Paris.`), Apple's
    `I cannot write a poem.`, the length-cap failures, and qwen3 equal to xAI in final words on all
    11 counted samples.
  - Re-ran the sandbox check: `curl` to huggingface.co fails in the profile with exit 6. Offline
    runs are `--fast`, one repeat, all 12 samples, load-only preparation.
  - Manifest bytes sum to the quoted download sizes, `du` matches the installed sizes, and the
    quoted `Package.resolved` pins match. Run ids are single-sourced in `run.json` (`6eb5351`,
    `sourceDirty` true, which the results disclose).
  - The diff is `results.md` (new), this packet and `plan.md`. `spec.md` and `research.md` are
    unchanged. No code changed. The xAI gate evidence (E1 and run `20261004T121048Z-xai`) is
    consistent with the run files.
- Required findings:
  1. **The deadline bound is stated more firmly than the evidence allows for longer windows**
     (`results.md`, Deadline section, last sentence of the third bullet: "Windows over 128 tokens
     are checked between chunks, so very long uncovered text should not make the bound worse").
     Evidence: `LLMModel.prepare` returns `.tokens` untouched when `total <= stepSize`, so a window
     of up to 128 tokens is one uninterruptible forward plus the first-token forward in
     `TokenIterator.prepare`. Above that, `forEachChunk` checks `Task.checkCancellation()` only
     between balanced chunks of up to 128 tokens, and each chunk is itself uninterruptible. The
     measured cancellation latency scales with window length (about 150 ms for 46 to 91 characters,
     417 ms for the 310-character window, so roughly 5 ms per token). A full 128-token chunk is
     therefore expected to take about 0.7 s, more than the 0.43 s "worst" the section uses, and
     `Reviser.split` plus `finish` do not cap the window (research.md notes the rolling window is
     not capped at 50 words). The "about 3.9 s" bound (0.42 + 3 + 0.42) holds for the corpus's longest
     window only; at one 128-token chunk it is nearer 4.4 s. The same sentence in the table row
     "enforceable with an overrun of about half a second" inherits this. Fix: scope the 3.9 s figure
     to windows of about 70 tokens, say the uninterruptible span grows with window length up to one
     128-token chunk (untested, estimated at about 0.7 s), and drop "should not make the bound
     worse". The conclusion (not demonstrated, bounded by about a chunk) survives.
  2. **Acceptance criterion 1 ("every figure names its run id") is not met in several places.**
     The sample-level outcomes table has no run id row (it is the central evidence for the
     recommendation) and neither do its "Reading the outputs" bullets. The `--fast` paragraph
     (smollm3's long sample, qwen3's 7 versus 4 missed words), the Warm latency bullets (per-sample
     medians, revising shares), the Deadline bullets (window-length cancellation latencies, 38 and 20
     cancelled before start, longest final request, final fallback counts) and the Recommendation
     table rows (616 versus 781 and 704, 2.23 s, 2.8 to 3.1 s, 2.5 GiB) quote figures without the
     run ids that produced them. The tables above some of these name them, but the bullets and
     rows do not. Fix by adding a run id row to the sample-level table and a run id after each
     figure or bullet, as the Gap to xAI section already does.
- Optional observations:
  1. `results.md` Constrained decoding: "they were common for smollm3 (60 of 165)" mixes units.
     The 60 rejections are requests (of 255 non-cancelled requests; 30 of 165 final requests;
     2 of 11 samples). The conclusion is unchanged. Use the right denominator.
  2. Paid marking. The tables are headed "xAI (paid)" and the top says every xAI figure is paid,
     which satisfies the spec. Prose figures in Gap to xAI ("matches xAI ... 120/165 ... 150"),
     the Warm latency bullets (xAI 992 ms) and the Recommendation rows (xAI 704, 1046, 992) do not
     repeat the tag. Tagging them costs a word each.
  3. Warm-latency bullet: "Other samples sit between 452 and 945 ms for qwen3". qwen3's other
     samples run 502 to 945 ms (medians); 452 is smollm3's `question-not-answered`.
  4. Deadline bullet: "338 to 417 ms (median) on the 310-character window" mixes runs. 417 is
     qwen3 on the 310-character window; 338 is smollm3 on its 324-character window. Also "about 150
     ms for windows of 46 to 91 characters" hides medians of 147 to 201 ms (51 and 81 characters
     are 175 and 201).
  5. The Deadline table gives Apple and xAI cancellation latency (1 to 4 ms). The handoff itself
     says to cite the local figures only, since a cancelled network call and a cancelled forward
     pass are not comparable. A one-line caveat would do.
  6. "Once ready, the first request is no slower than warm ones": the cold sample is the short
     `clear-correction`, whose warm median is 502 ms (qwen3) and 468 ms (smollm3) against cold 539
     and 488 ms, so it is about 8% slower, not equal. The paragraph compares against an overall p50
     that is dominated by other samples. Say "within about 10%" or compare sample to sample.
  7. Load time is quoted as 2.8 to 3.1 s in the Recommendation cost row and 2.8 to 3.3 s elsewhere;
     qwen3's preparation was 2826, 3101, 3225 (fast run) and 4206 ms (offline). State the range
     and the n once.
  8. `research.md` still carries "estimate 3-4 GB RAM" (qwen3) and "2.5-3.5 GB" (smollm3) against
     measured peaks of 2.5 GiB and 2.1 GiB. They are labelled planning estimates, so leaving them is
     within packet step 5, but a clause such as "measured 2.5 GiB peak in the bench, see
     results.md" would stop the two documents disagreeing. The unresolved "prefill may not be
     interruptible" sentence in research is now answered in part (Required 1), also optional.
  9. Memory pressure `warning` appeared twice, both qwen3 runs, never smollm3's. The results call it
     unattributable on a busy machine, which is fair, but the Recommendation table's cost row could
     mention it, since 16 GiB with transcription and read aloud later is the worry.
  10. "all 15 repeats agree within a run" in the sample-level table title is contradicted by its
     own last row (xAI 14 of 15). Change to "except xAI on the manual sample".
- Questions:
  1. Constrained decoding. The spec's trigger is "validation rejections prove common". qwen3 has no
     rejections but fails with a length-cap error on `command-not-followed` in 15 of 15 repeats (a
     reply that begins writing the poem), which is the same unfaithful-reply class caught by a
     different check, and a subsequence grammar would prevent exactly that. `results.md` says
     constrained decoding "would not touch qwen3's actual gap, under-editing", which overlooks this
     failure. Does the lead read the spec's condition as validation rejections only, or as
     unfaithful replies caught by any check? Either answer is defensible, but the section should
     say which, and the 945 ms median it costs on that sample is relevant to the decision.
  2. Draft-model speculation. The spec's trigger is "warm latency misses the budget". The
     results read the budget as the 3 s final deadline and find 2.23 s worst. Its research note says
     the window is uncapped and that warm inference must be measured while transcription runs, and
     neither was measured. "Not worth it now" is correct for what was measured; is that the
     wording the lead wants, or "not triggered, concurrent run still to decide"?
  3. The recommendation says "Adopt qwen3-4b-2507 ... for the next slice". On this corpus (11
     inputs, debug build, busy machine, no concurrency) that is a candidate selection for the next
     slice, not a product direction, and the section says so under "Conditions". Is "Adopt" strong
     enough to need softening to "Take forward", given the spec's completion criteria say product
     thresholds stay open until measured?

## Resolution

- Finding dispositions (all edits in `results.md`; no code, `plan.md`, `spec.md` or `research.md` change):
  - Required 1 (deadline bound): fixed. The 3.9 s figure is scoped to windows of about 70 tokens; the
    uninterruptible span is said to grow with window length (roughly 5 ms per token) up to one
    128-token chunk, untested, about 0.7 s, so nearer 4.4 s. "Should not make the bound worse" is
    gone; the Recommendation deadline row now says "an overrun of roughly half a second to a second,
    not demonstrated".
  - Required 2 (run ids): fixed. The sample-level table has a run id row, and a run id follows the
    "Reading the outputs" bullets, the `--fast` paragraph, the Warm latency bullets, the Deadline
    bullets and the Recommendation rows, in the existing `…suffix` form.
  - Promoted optionals, each checked against `cleanup.jsonl` and `report` before editing:
    - Optional 1: smollm3 rejections are 60 of 255 non-cancelled requests, 30 of 165 final
      requests, on 2 of 11 samples. qwen3's length-cap failures are 15 of 165 final requests (all
      final), which is the figure used rather than "15 of 165 requests".
    - Optional 2: xAI is tagged paid in the prose and Recommendation rows.
    - Optional 3: qwen3's other samples are 502 to 945 ms.
    - Optional 4: cancellation by window is now per-candidate medians: qwen3 147 to 201 ms
      (46 to 91 characters) and 417 ms (310 characters); smollm3 126 to 171 ms and 338 ms
      (324 characters).
    - Optional 6: cold is compared with the same sample's warm median (`clear-correction`: 539
      against 502 ms for qwen3, 488 against 468 ms for smollm3), so 4 to 7% slower, not the
      "roughly 8%" suggested.
    - Optional 7: load time is stated once, in Cold start, over four runs of each candidate:
      qwen3 2.8 to 4.2 s, smollm3 3.2 to 3.4 s (n=4). The cost row and the Offline section refer to
      it.
    - Optional 10: the sample-table title now says "except xAI on the manual sample".
    - Optional 5: one-line caveat that Apple's and xAI's 1 to 4 ms cancellation is not comparable
      with a local forward pass.
  - Optional 8 and 9: skipped (`research.md` edits and the memory pressure mention).
  - Questions:
    - Q1: kept the spec's reading (validation rejections proving common) and said so. The
      length-cap failures are named as a different check, the one thing that could change the verdict,
      not meeting the condition, at a 945 ms median on that sample.
    - Q2: speculation verdict is now "not triggered by anything measured"; the concurrent run with
      local transcription is still to decide.
    - Q3: "Adopt" is now "Take forward qwen3-4b-2507 as the local cleanup candidate".
- Simplification/deletion pass: removed the "bound should not get worse" sentence, the "first
  request is no slower than warm ones" claim, the duplicated load-time figures (cold-start paragraph,
  Offline section, cost row) and the speculation revisit threshold. The deadline passage is one
  bullet again. The section has about the same length, with the added run ids and caveat.
- Final verification: passed. Rebuilt and reran `report` on the run ids whose figures were touched
  (`…110130Z-local`, `…110916Z-local`, `…111652Z-local`, `…111730Z-local`, `…105222Z-local`,
  `…105256Z-local`, `…111803Z-local`, `…111816Z-local`): preparation 2826, 3101, 3225, 4206 ms
  (qwen3) and 3185, 3233, 3334, 3447 ms (smollm3), and the p50/p95 and cancellation figures match the
  text. The derived figures (rejection denominators, warm medians per sample, cancellation by window,
  38 and 20 cancelled before start) were recomputed from each `cleanup.jsonl`.

## Closure review

- Verdict: `Changes required` at the time of review; closed by the lead (see Lead disposition). Both Required findings are fixed, but a figure added by the
  remediation (Optional 6) was wrong. It is a one-sentence fix in `results.md`; the conclusions
  still follow.
- Checks run:
  - `swift build` passes. `swift run EchoTypeBench report 20261004T083627Z-apple` prints. `report`
    reran on all 11 cited cleanup run ids; every quoted `report` figure matches, including the
    figures the remediation touched (preparation 2826, 3101, 3225, 4206 ms for qwen3 and 3233, 3334,
    3185, 3447 ms for smollm3, so the 2.8 to 4.2 s and 3.2 to 3.4 s ranges hold; p50/p95/n;
    cancellation latency; footprint; pressure `warning` only in the two qwen3 runs; offline totals).
  - Recomputed from `cleanup.jsonl`: rejection denominators (smollm3 60 of 255 non-cancelled
    requests, 30 of 165 final), qwen3 length-cap failures (15, all final), final-fallback counts
    (45, 0, 15, 45), cancelled-before-start (38 and 20 over the 11 counted samples), longest final
    request (1.70, 1.76, 1.85, 1.78 s), longest stop-to-insert, `long-unpunctuated` medians (2198,
    2006, 1636, 992 ms), `command-not-followed` medians (945 and 750 ms), and cancellation latency
    by window length (qwen3 149 to 205 ms on 46 to 91 characters, 426 ms on 310; smollm3 126 to
    182 ms, 343 ms on 324). The by-window medians differ by a few ms from the text (for example
    147 to 201 against 149 to 205); this is within the 10 ms-level method differences and does
    not change any statement.
- Required 1 (deadline bound): fixed. The 3.9 s figure is scoped to about 70 tokens, the span is
  said to grow to one 128-token chunk (untested, about 4.4 s), "should not make the bound worse" is
  gone, and the Recommendation row says "roughly half a second to a second, not demonstrated".
- Required 2 (run ids): fixed. The sample-level table has a run id row, and the bullets, `--fast`
  paragraph, Warm latency, Deadline and Recommendation rows carry run ids.
- Promoted optionals and question resolutions 1, 2, 3, 4, 5, 7, 10: verified in `results.md`. Q1,
  Q2 and Q3 wording matches the Resolution.
- Remaining required findings:
  1. **Wrong "warm" clear-correction medians** (`results.md`, Warm latency "Qwen3's other samples sit
     between 502 and 945 ms" and Cold start "whose warm median in the paced runs is 502 ms for qwen3
     and 468 ms for smollm3, so cold is 4 to 7% slower"). 502 and 468 are medians over all 15
     `clear-correction` repeats, which include the cold request (549 and 490 ms in the paced runs).
     Warm only (the 14 repeats after the first request, the `report` definition) the medians are
     452 ms (qwen3) and 464 ms (smollm3), so the cold request is about 20% slower for qwen3
     (549 against 452 ms) and about 5% for smollm3, not "4 to 7%". qwen3's other samples then span
     452 to 945 ms, not 502 to 945. The paragraph's conclusion (the cost of cold is preparation, not
     the first request) still holds at a difference of about 100 ms; fix the two figures and the
     percentage, or compare with the all-repeat spread (377 to 557 ms for qwen3), and drop the
     percentage claim.

- Lead disposition: the one remaining finding was valid. I recomputed the warm-only (first request
  excluded) `clear-correction` medians from `cleanup.jsonl` in `…110130Z-local` and
  `…110916Z-local` (452 and 464 ms), corrected the two figures and the percentage in `results.md`
  (cold about 19% and 5% slower; qwen3's other samples 452 to 945 ms) and found no other use of
  502 or 468 there. It is a one-sentence number fix that does not change a conclusion, so I made it
  directly rather than order a third pass. Accepted.
