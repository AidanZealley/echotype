# Local models spike results

Status: cleanup measured in debug and release; transcription measured in release, including fresh
downloads and recovery. Read aloud is not measured.

Every figure is from `swift run EchoTypeBench report <run id>` and was rechecked against its
output. Figures marked "derived" come from the run's raw logs and the derived logs named in each section.
Runs are under `~/Library/Application Support/EchoTypeBench/runs/`. Slice 1 runs are from source revision
`6eb5351` (dirty tree, documentation edits only per the workstream handoff), on a MacBookPro18,3 (M1 Pro, 16 GiB),
macOS 27.2 (26B5091g), Xcode 27.0, Swift 6.4, **debug build** of the bench.

## Cleanup

### Conditions that limit the figures

- **Local and Apple runs were taken on a busy machine.** One-minute load average before each run
  was 3.55 to 7.39 (WindowServer, photolibraryd, TextEdit and T3 Code busy). Latency is an upper
  bound, not a quiet-machine figure.
- **The xAI run was not noted as taken on a quiet machine.** Treat its latency the same way. It also
  includes the network. **Every xAI figure is a paid comparison** (`20261004T121048Z-xai` sent the
  12 hand-written cleanup samples to xAI, 15 times each).
- The corpus has 12 hand-written samples; 11 are counted. `cleanup-ambiguous-correction` is manual
  and outside every total. None was excluded. Apple and local final text was identical across the
  repeats of a run, and xAI's varied only on the manual sample (derived), so 15 repeats are 11
  distinct inputs, not 165 independent samples. Treat counts as a probe, not a measurement of
  general speech.
- Quality is word-level (`Prose.words`): punctuation and case are not scored.
- `fallbacks` counts requests, not samples. `validation rejections` are a subset of it; the rest
  are failed requests ("other").

### Runs

| Run id | Provider | Mode |
|---|---|---|
| `20261004T105127Z-apple` | Apple | `--fast --repeat 3` |
| `20261004T105222Z-local` | qwen3-4b-2507 | `--fast --repeat 3` |
| `20261004T105256Z-local` | smollm3-3b | `--fast --repeat 3` |
| `20261004T105325Z-apple` | Apple | paced `--repeat 15` |
| `20261004T110130Z-local` | qwen3-4b-2507 | paced `--repeat 15` |
| `20261004T110916Z-local` | smollm3-3b | paced `--repeat 15` |
| `20261004T121048Z-xai` | xAI (paid) | paced `--repeat 15` |
| `20261004T111652Z-local` | qwen3-4b-2507 | cold start, fresh process, installed |
| `20261004T111730Z-local` | smollm3-3b | cold start, fresh process, installed |
| `20261004T111803Z-local` | qwen3-4b-2507 | offline (network denied), `--fast` |
| `20261004T111816Z-local` | smollm3-3b | offline (network denied), `--fast` |

xAI has no `--fast` run, so the same-mode comparison across all four is the paced one. Tables
below shorten ids to their suffix (`…110130Z-local` is `20261004T110130Z-local`).

### Candidates

| | qwen3-4b-2507 | smollm3-3b |
|---|---|---|
| Repository | `mlx-community/Qwen3-4B-Instruct-2507-4bit` | `mlx-community/SmolLM3-3B-4bit` |
| Revision | `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b` | `d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce` |
| Licence, files | Apache-2.0, 6 | Apache-2.0, 6 |
| Download (manifest bytes) | 2,274,455,727 B (2.27 GB) | 1,747,319,274 B (1.75 GB) |
| Installed (`du`) | 2.1 GiB | 1.6 GiB |
| Settings | greedy, output capped near the window; no thinking flag | greedy, `enable_thinking: false` |

Pins (`Package.resolved`): mlx-swift 0.32.3 (`19601207e9a0de51e03ee6ec0c3c5f3784275075`),
mlx-swift-lm revision `5e46681b2adcef2db158e7b949aeae3896778e23` (no tag), swift-transformers 1.3.4
(`c21fdcde390313a6d98d8e33a346f2c3486c3ab0`), swift-jinja 2.5.1
(`4588064a20f3fc093c95f2f7d3359999bf30cae5`). The rest of the resolved set is in `Package.resolved`
at `6eb5351`.

Download time and transient disk usage were not measured in this slice: no cited run's
`preparation.json` records a download (every one shows only "Loading the cleanup model"). Recovery
after an interrupted download was exercised only with the injected download source
(`ModelStoreTests`), not by killing a live download. Slice 2 now measures Qwen delivery and a real
Unified interruption below, without replacing these slice 1 observations.

Integration changes the spec expects recorded: `swift-transformers` 1.3.4 is a third direct
dependency of `EchoTypeCore` (the MLX Swift LM revision no longer bundles a tokenizer; plan.md
decision log, 2026-10-04), `build-app.sh` stages three resource bundles (MLX, swift-crypto,
swift-transformers Hub), and CI installs the Metal toolchain.

### Quality, paced runs (same mode, 11 counted samples x 15 repeats = 165)

| | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Run id | `…105325Z-apple` | `…121048Z-xai` | `…110130Z-local` | `…110916Z-local` |
| Exact | 75/165 | 120/165 | 120/165 | 105/165 |
| Wrong deletions (words) | 300 | 0 | 0 | 15 |
| Missed edits (words) | 195 | 150 | 150 | 270 |
| Not a deletion | 0 | 0 | 0 | 0 |
| Validation rejections | 30 | 0 | 0 | 60 |
| Other fallbacks | 15 | 0 | 15 | 15 |
| Final revision fell back to input (derived) | 45 | 0 | 15 | 45 |

### Quality, `--fast --repeat 3` (the packet's quality runs; 33) and offline (11)

| | Apple | qwen3-4b-2507 | smollm3-3b | qwen3 offline | smollm3 offline |
|---|---|---|---|---|---|
| Run id | `…105127Z-apple` | `…105222Z-local` | `…105256Z-local` | `…111803Z-local` | `…111816Z-local` |
| Exact | 15/33 | 24/33 | 24/33 | 8/11 | 8/11 |
| Wrong deletions | 45 | 0 | 3 | 0 | 1 |
| Missed edits | 42 | 39 | 33 | 13 | 11 |
| Not a deletion | 0 | 0 | 0 | 0 | 0 |
| Validation rejections | 6 | 0 | 3 | 0 | 1 |
| Other fallbacks | 3 | 3 | 3 | 1 | 1 |

`--fast` delivers all text at once, so `Reviser` forms different windows than a paced run. That
changes sample outcomes (derived): smollm3's long sample is exact in the fast run and a rejection in
the paced one, and qwen3 misses 7 words there against 4 paced (`…105256Z-local` and `…105222Z-local`
against `…110916Z-local` and `…110130Z-local`). Greedy decoding is stable only for
a given window sequence.

### Sample-level outcomes (paced runs; all 15 repeats agree within a run, except xAI on the manual sample; derived from `cleanup.jsonl`)

| Sample | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Run id | `…105325Z-apple` | `…121048Z-xai` | `…110130Z-local` | `…110916Z-local` |
| clear-correction | wrong: kept Tuesday, deleted Wednesday | exact | exact | exact |
| correction-mid-sentence | removed "actually no" only, missed 6 | exact | exact | removed "no" only, missed 7 |
| deliberate-repetition | wrong: dropped "very" and "again and" | exact | exact | exact |
| accidental-repetition | exact | exact | exact | exact |
| false-starts | wrong deletions 2, missed 4 | missed 4 | missed 4 | wrong deletion 1, missed 2 |
| fragments | exact words; final call refused ("unsafe") | exact | exact | exact words, sentence break kept |
| question-not-answered | rejected (reworded) | unchanged | unchanged | rejected (answered "Paris") |
| command-not-followed | rejected ("I cannot write a poem.") | unchanged | failed: reply hit length cap | failed: reply hit length cap |
| reply-request | missed 2 | missed 2 | missed 2 | missed 2 |
| long-unpunctuated | wrong: deleted 14 words | missed 4 | missed 4 | rejected (reworded), missed 7 |
| nothing-to-change | exact | exact | exact | exact |
| ambiguous-correction (manual) | removed "actually" | removed "actually" (14/15); once dropped "Zustand" | unchanged | unchanged |

Reading the outputs:

- **qwen3 and xAI (paid) produce the same final words on all 11 counted samples** (derived;
  `…110130Z-local`, `…121048Z-xai`). Both under-edit
  rather than over-edit: they miss the false start in `false-starts`, the abandoned "the build" in
  `reply-request` and "I'd rather it didn't" in `long-unpunctuated`. All three misses delete
  nothing wrong. They differ only in how `command-not-followed` ends (below) and on the manual
  sample.
- **qwen3 on `command-not-followed`:** the reply ran past its length cap, so the request failed and
  the input words were kept. The reply text is not recorded; the cap suggests the model began
  writing the poem. The safety net worked and the inserted text is correct, but it costs 945 ms
  median stop-to-insert against 750 ms for xAI (paid) (derived; `…110130Z-local`, `…121048Z-xai`), and it
  is a real instruction-following failure. smollm3 fails the same way and also answers the question
  (`…110916Z-local`).
- **Ambiguous sample (manual):** the corpus expects the sentence unchanged. qwen3 and smollm3 left it
  unchanged, the conservative reading. Apple and xAI (paid) deleted "actually" and kept both options,
  which loses the speaker's hesitation cue but no content. xAI once chose "TanStack Store" and
  dropped "Zustand", a defensible correction reading. I judge none of these a clear error; unchanged
  is safest (all four paced runs).
- **Apple** deletes wrong words on four counted samples (300 words) and its on-device guardrail refused one
  harmless sample (`fragments`) every time (`…105325Z-apple`).
- **smollm3** is the most conservative on corrections but fails on faithfulness: it answers a
  question, rewords the long sample and misses the mid-sentence correction (`…110916Z-local`).
- Word-level scoring counts smollm3's `fragments` as exact although it left "window. So that"
  split, which a reader would count as a missed join (`…110916Z-local`).

### Gap to xAI

On this corpus qwen3-4b-2507 matches xAI (paid) on every counted word-level figure (exact 120/165, 0
wrong deletions, 150 missed edit words) from runs `…110130Z-local` and `…121048Z-xai`. It
differs in the outcome of one counted sample (`command-not-followed`: a fallback after a length-cap
failure, where xAI returns the input), on the manual sample, and on latency and cost below. Both leave 3 of 11
samples under-edited. The corpus cannot separate the two, so it shows neither that qwen3 equals xAI on
general speech nor that it lags. smollm3-3b has 15 fewer exact than xAI, 15 wrong-deleted words, 120 more missed
edit words and 60 validation rejections.

### Warm latency (paced runs; cold request excluded; p50 / p95 / n)

| | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Run id | `…105325Z-apple` | `…121048Z-xai` | `…110130Z-local` | `…110916Z-local` |
| Stop-to-insert, ms | 781 / 1627 / 164 | 704 / 1046 / 164 | 616 / 2194 / 164 | 600 / 1989 / 164 |
| Revision duration, ms | 800 / 1606 / 254 | 716 / 1042 / 254 | 497 / 1766 / 254 | 479 / 1654 / 254 |
| Share of time revising (report) | 83.8% | 81.8% | 80.3% | 79.9% |
| Longest stop-to-insert, ms (derived) | 1702 | 1759 | 2232 | 2034 |

- The p95 comes from `long-unpunctuated` (about 60 words). Its median stop-to-insert is 2198 ms for qwen3,
  2006 ms for smollm3, 1636 ms for Apple and 992 ms for xAI (paid) (derived; the four paced runs in the
  table). Qwen3's other samples sit between 452 and 945 ms. The local models are faster than xAI at p50
  and slower at p95, so latency grows with window length where a hosted model's does not.
- The revising share is about 100% by construction for single-segment samples (text arrives at the
  end). The three multi-segment samples are the informative ones; median share for
  clear-correction / fragments / long-unpunctuated (derived; the four paced runs): qwen3 27.6 / 23.0 /
  34.8%, smollm3 25.3 / 21.0 / 33.2%, Apple 45.0 / 39.3 / 35.4%, xAI (paid) 41.0 / 33.3 / 25.1%. The local model is
  generating about a quarter to a third of a multi-segment dictation, and this was measured alone.
  Running alongside local transcription was not measured.

### Cold start (kept apart from warm; each n=1)

| | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Cold-start run id | n/a | n/a | `…111652Z-local` | `…111730Z-local` |
| Preparation (load and warm, no download) | 228 ms (`…105325Z-apple`) | 0 ms (`…121048Z-xai`) | 2826 ms | 3233 ms |
| First revision (first served request) | 1840 ms (`…105325Z-apple`) | 673 ms (`…121048Z-xai`) | 296 ms | 259 ms |
| Cold stop-to-insert | 853 ms (`…105325Z-apple`) | 715 ms (`…121048Z-xai`) | 539 ms | 488 ms |

The paced local runs agree: first revision 303 and 263 ms, cold stop-to-insert 549 and 490 ms
(`…110130Z-local`, `…110916Z-local`). The local cold figures are loads in a fresh process with weights
probably in the OS page cache. They are not a first load after reboot or an OS update, and download is
not included.

Like for like, the cold request is the short `clear-correction` sample, whose warm median in the paced
runs (first, cold request excluded) is 452 ms for qwen3 and 464 ms for smollm3, so cold is about 19%
and 5% slower (`…110130Z-local`,
`…110916Z-local`). The cost of "cold" is preparation. Over the four runs of each candidate (n=4: cold,
paced, `--fast`, offline; `…111652Z-local`, `…110130Z-local`, `…105222Z-local`, `…111803Z-local` and
`…111730Z-local`, `…110916Z-local`, `…105256Z-local`, `…111816Z-local`) it is 2.8 to 4.2 s for qwen3 and
3.2 to 3.4 s for smollm3.

### Deadline

| | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Run id | `…105325Z-apple` | `…121048Z-xai` | `…110130Z-local` | `…110916Z-local` |
| Deadline fallbacks / overruns | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Cancellation latency, ms p50 / p95 / n | 1 / 4 / 165 | 1 / 3 / 165 | 151 / 417 / 165 | 127 / 329 / 165 |
| Longest final request, s (derived) | 1.70 | 1.76 | 1.85 | 1.78 |

Apple's and xAI's 1 to 4 ms cancels a request, not a local forward pass, so it is not comparable with
the local figures.

**No run hit the three-second deadline**, so the timer was never exercised and nothing here shows
it enforced. This holds for windows up to the corpus's longest (about 70 tokens); longer unpunctuated
windows were not measured. Enforceability is reasoning from cancellation latency and the code:

- `Reviser.finish` cancels the live revision and awaits it before the three-second timer starts, so
  cancellation latency is added to the wait. For the local models it is 127 to 151 ms at p50 and
  329 to 417 ms at p95. By window, the per-candidate medians (derived) are 147 to 201 ms for qwen3 on
  windows of 46 to 91 characters and 417 ms on its 310-character window, and 126 to 171 ms and 338 ms
  (324 characters) for smollm3. 38 of qwen3's 165 and 20 of smollm3's requests were cancelled before
  the model started (about 0 ms; `…110130Z-local`, `…110916Z-local`).
- `CleanupModel.generate` checks `Task.checkCancellation()` first, then prefills the window in
  128-token chunks and MLX Swift LM checks cancellation between chunks
  (`PrefillParameters.forEachChunk`) and before each generated token (`Evaluate.swift`). A chunk's
  forward pass cannot be interrupted, and the fixed prompt is already cached, so a window under 128 tokens
  (the longest here, 310 characters, is roughly 70) is a single chunk, and the final forward is also unchecked. The observed
  latencies, which grow with window length, are consistent with this (an inference, not separately
  measured).
- So the timer can stop a final revision only after one uninterruptible forward pass. For windows of
  about 70 tokens (the corpus's longest) that is the 0.42 s measured, so the bound is about 0.42 s for
  `finish` to await the live revision, 3 s, and 0.42 s for the final request to stop: near 3.9 s from
  stop (an estimate, not observed). The span grows with window length, at roughly 5 ms per token, up to
  one 128-token chunk (untested; about 0.7 s, so nearer 4.4 s). The bench's 250 ms overrun threshold
  would flag a late stop.
- The longest observed final request was 1.85 s and the longest stop-to-insert 2.23 s (derived,
  n=164; `…110130Z-local`), so no sample came within 0.7 s of the deadline. That is the debug build on a
  window of about 70 tokens. Longer unpunctuated windows were not measured, and by linear
  extrapolation from 1.85 s at 70 tokens (untested) the budget could be reached beyond roughly 110
  tokens. Local transcription running at the same time may change this and is unmeasured.
- The user saw unrevised words after a final fallback on 15 of 165 final revisions for qwen3
  (`…110130Z-local`), 45 of 165 for smollm3 (`…110916Z-local`) and Apple (`…105325Z-apple`), 0 for xAI
  (paid; `…121048Z-xai`) (derived). Those were failures or rejections, not timeouts.

### Memory (`phys_footprint`, bench process)

| | Apple | xAI (paid) | qwen3-4b-2507 | smollm3-3b |
|---|---|---|---|---|
| Run id | `…105325Z-apple` | `…121048Z-xai` | `…110130Z-local` | `…110916Z-local` |
| Peak | 13 MiB | 7 MiB | 2573 MiB | 2162 MiB |
| Idle once ready | 8 MiB | 3 MiB | 2381 MiB | 1848 MiB |
| Thermal worst | nominal | nominal | nominal | nominal |
| Memory pressure worst | normal | normal | warning | normal |

Across slice 1's qwen3 runs the highest peak is 2649 MiB (about 2.6 GiB, `…111803Z-local`, offline
`--fast`), with 2638 MiB in `…105222Z-local` (`--fast`); smollm3's highest is 2171 MiB
(`…105256Z-local`). The cold-start runs peak at 2571 MiB and 2169 MiB, ready 2381 and 1829 MiB, with pressure normal
(`…111652Z-local`, `…111730Z-local`). Memory pressure `warning` also appeared in `…105222Z-local`
(qwen3 `--fast`) but in no other run, on a busy 16 GiB machine; I cannot attribute it to the
model alone. Apple's and xAI's footprints describe the bench only, not Apple's out-of-process
model. The planning estimate of 3 to 4 GB for qwen3 in `research.md` is high against the 2649 MiB
peak (`…111803Z-local`) for this window size; the buffer cache limit was 64 MiB. Concurrent
transcription memory is now recorded below (`20261005T064539Z-local`); read aloud memory remains
unmeasured.

### Offline

Both candidates ran all 12 samples with network access denied (`sandbox-exec` deny `network*` on the
built binary, models installed; `curl` to huggingface.co failed in the same profile). Results are
identical to the online `--fast` runs per repeat: qwen3 8/11 exact, 0 wrong deletions, 13 missed
(`…111803Z-local`); smollm3 8/11, 1, 11 (`…111816Z-local`). Final text matched the online run's first
repeat on all 12 samples for both (derived). No download lines, no errors. Preparation was a load
only, within the load-time ranges under Cold start.

### Recommendation

**Take forward qwen3-4b-2507 as the local cleanup candidate; reject smollm3-3b.**

| Measure | Result |
|---|---|
| Quality vs Apple | Better: 120 vs 75 of 165 exact, 0 vs 300 wrong-deleted words (`…110130Z-local`, `…105325Z-apple`) |
| Quality vs xAI (paid) | Equal on counted samples (120/165, 0, 150), including the same three misses (`…110130Z-local`, `…121048Z-xai`). One instruction-following failure xAI lacks |
| Warm latency | p50 616 ms beats Apple (781) and xAI (paid, 704); p95 2194 ms is worse than both (1627, 1046) (`…110130Z-local`, `…105325Z-apple`, `…121048Z-xai`) |
| Deadline | Never hit on windows up to about 70 tokens; longest stop-to-insert 2.23 s, longest final request 1.85 s on the debug build (`…110130Z-local`); longer unpunctuated windows not measured (budget reachable beyond roughly 110 tokens only by untested extrapolation); enforceable with an overrun of roughly half a second to a second, not demonstrated |
| Cost | 2.27 GB download, 2.1 GiB installed, 2.6 GiB peak process footprint (2649 MiB, `…111803Z-local`; 2573 MiB in `…110130Z-local`), 2.8 to 4.2 s load (n=4, see Cold start) |

Remaining gap to xAI, stated plainly: no measurable difference in word-level quality on 11 samples that
cannot tell them apart, a tail latency roughly twice xAI's on long windows (2198 vs 992 ms for xAI (paid) on the
long sample; `…110130Z-local`, `…121048Z-xai`), one command-following failure that falls back
safely, and a local cost of about 2.6 GiB
of memory and a 3 s load that xAI does not have. smollm3-3b is rejected: 60 validation rejections, 15
wrong-deleted words and the most missed edits, for 0.5 GiB less memory (`…110916Z-local`).

Both candidates under-edit false starts and the abandoned "the build"; that is a prompt and model
limit under the spec's rule of sending Reviser's prompt unchanged, and it is the same limit xAI (paid) shows.
It is not a reason to reject Qwen but means "cleanup" here is conservative tidying, not full
disfluency removal.

Release and concurrent figures are now recorded below and in Transcription (`20261005T063709Z-local`,
`20261005T064539Z-local`). No quiet-machine requirement applies. Grow the cleanup corpus beyond the
hand-written inputs before treating this as general dictation quality.

**Follow-ups, proposed and not built:**

- **Draft-model speculation: not triggered by anything measured.** The spec's condition is that warm
  latency misses the budget. It never did alone: longest stop-to-insert 2.23 s, longest final request
  1.85 s against a 3 s budget (`…110130Z-local`). The release concurrent dictation pass also records no deadline fallback or overrun (`20261005T064539Z-local`).
- **Constrained decoding: not worth it for qwen3.** The spec's condition is that validation rejections
  prove common, and I read it that way. qwen3 had 0 rejections in 255 non-cancelled requests
  (`…110130Z-local`). smollm3 had 60 of 255 non-cancelled requests (30 of 165 final requests, on 2 of 11
  samples; `…110916Z-local`) and is rejected anyway. It would not touch qwen3's actual gap,
  under-editing, since a subsequence grammar permits keeping every word. One thing could change the
  verdict: qwen3's 15 length-cap failures on `command-not-followed` (15 of 165 final requests) are a
  different check (the output cap), safe fallbacks on one sample, and constrained decoding would arguably
  prevent them. They do not meet the spec's condition, and cost a 945 ms median stop-to-insert on that
  sample.

### Release cleanup timing

The release paced `--repeat 15` run `20261005T063709Z-local` retains the debug run
`20261004T110130Z-local` above. Both use the same conservative prompt and Qwen weights.
Their machine loads differ, so this comparison does not isolate compiler configuration.
The ambiguous sample stays outside quality and timing totals.

- exact 120/165, wrong deletions 0, missed edits 150, not a deletion 0, fallbacks 15 (validation rejections 0), deadline fallbacks 0, deadline overruns 0 (`20261005T063709Z-local`).
- warm stop-to-insert p50 561 / p95 1699 ms (n=164), warm revision p50 452 / p95 1626 ms (n=254), cancellation latency p50 143 / p95 213 ms (n=165), revising 79.9% of the time, cold stop-to-insert 516 ms, first revision 265 ms (`20261005T063709Z-local`).
- preparation 4043 ms (Loading the cleanup model 4043 ms) (`20261005T063709Z-local`).
- footprint peak 2591 MiB, ready 2397 MiB, thermal worst nominal, memory pressure worst warning, load average median 3.23, max 9.92 (`20261005T063709Z-local`).

Warm revision p50/p95 changes from 497/1766 ms in debug to 452/1626 ms in release;
warm stop-to-insert changes from 616/2194 ms to 561/1699 ms. These are separate runs on a busy Mac,
not a paired compiler benchmark (`20261004T110130Z-local`, `20261005T063709Z-local`).

## Transcription

### Conditions and evidence

The release evaluation covers standalone performance, offline use, fresh downloads, paired installed
loads and interrupted-download recovery. The recommendation remains a proposal; the build selection
is unchanged.

The new runs below use `swift run -c release EchoTypeBench` at source
`6c779359fe0035fed7fcc127dac606c37b7594e0`, with documentation-only changes in the tree.
Network-denied runs use the built release binary under `sandbox-exec` with `deny network*`.
All reviewed recordings were included. Load average is measured per run; the machine was used as
it was, without a quiet-machine requirement.

Apple and xAI reuse the existing paced debug runs. They predate cold splitting and the sampler,
so their rows have no preparation, footprint or load measurements. Apple's recogniser runs
outside the bench process. xAI includes network latency and was paid when the existing run was
made. No new xAI call was made.

The references began as xAI drafts that Aidan corrected. That flatters xAI's error rates.
Treat every quality comparison with xAI below as a comparison against those biased references.

Each paced local pass has a cold first sample and about fourteen warm samples. The first-text
figures omit silence, so their warm n is thirteen. Their p95 is the slowest observation, not a
stable estimate of rare delays. The candidates have a clear quality-versus-latency tradeoff,
so no extra repeat runs were needed. The paced evidence is `20261005T061114Z-local`,
`20261005T061642Z-local` and `20261005T062416Z-local`.

Derived first-provisional and speech-to-commit figures use nearest-rank percentiles from
`transcribe.jsonl`, with the cold row excluded for new runs. The derivations are saved beside each
run in `evaluation-derived.json`. Asset sizes are in `evaluation-assets.json` and the final disk
snapshot, including the shared
compiled cache, is in `evaluation-disk.json`;
paired offline checks are in the offline run's `evaluation-offline-comparison.json`.

### Runs, load and process cost

Preparation is a load from installed files in these runs. Footprint is `phys_footprint` for the
bench process. Core ML work on the Neural Engine can be charged to system processes, so these
small transcription figures can understate total model cost. Thermal state and pressure are reported per row.
Pressure is system-wide and cannot be attributed to a candidate on this busy Mac. Apple's footprint
covers the bench, not its out-of-process models
(`20261005T065030Z-apple`).

| Run id | Purpose | Preparation ms | Peak / ready MiB | Load average median / max | Thermal / pressure |
|---|---|---:|---:|---:|---|
| `20261005T061114Z-local` | parakeet-unified-paced | 23157 | 59 / 43 | 5.39 / 8.86 | nominal / warning |
| `20261005T061546Z-local` | parakeet-unified-online-fast | 325 | 53 / 43 | 2.39 / 2.65 | nominal / warning |
| `20261005T061600Z-local` | parakeet-unified-offline | 310 | 50 / 43 | 2.18 / 2.20 | nominal / warning |
| `20261005T061642Z-local` | parakeet-unified-keyterms-paced | 24295 | 59 / 56 | 5.76 / 8.83 | nominal / warning |
| `20261005T062117Z-local` | parakeet-unified-keyterms-online-fast | 806 | 60 / 56 | 3.82 / 4.15 | nominal / warning |
| `20261005T062139Z-local` | parakeet-unified-keyterms-offline | 728 | 61 / 57 | 3.27 / 3.50 | nominal / warning |
| `20261005T062416Z-local` | whisper-turbo-paced | 132191 | 119 / 94 | 2.70 / 4.22 | nominal / warning |
| `20261005T063149Z-local` | whisper-turbo-online-fast | 131921 | 120 / 98 | 3.60 / 6.31 | nominal / warning |
| `20261005T063537Z-local` | whisper-turbo-offline | 139485 | 124 / 97 | 4.17 / 7.15 | nominal / warning |
| `20261005T063709Z-local` | qwen-release | 4043 | 2591 / 2397 | 3.23 / 9.92 | nominal / warning |
| `20261005T064539Z-local` | local-dictation | 48096 | 2781 / 2478 | 4.66 / 6.88 | nominal / warning |
| `20261005T065030Z-apple` | apple-dictation | 272 | 35 / 8 | 3.93 / 5.77 | nominal / normal |

### Models and integration

The measured build uses the same adapters as the signed app. FluidAudio is pinned to
`0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7`; WhisperKit, product of argmax-oss-swift 1.1.0,
is pinned to `1e2a163736dfa5a198e637ae44c114e1c6d5cc2d`. Cleanup uses MLX Swift 0.32.3 at
`19601207e9a0de51e03ee6ec0c3c5f3784275075`, MLX Swift LM at
`5e46681b2adcef2db158e7b949aeae3896778e23`, and swift-transformers 1.3.4 at
`c21fdcde390313a6d98d8e33a346f2c3486c3ab0`. `Package.resolved` holds the transitive pins.
The run source revision and dependency handoffs identify these configurations for
`20261005T061114Z-local`, `20261005T061642Z-local`, `20261005T062416Z-local`
and `20261005T063709Z-local`.

| Candidate | Pinned assets and licence | Transfer payload / installed disk bytes | Keyterm limit | Evidence |
|---|---|---:|---:|---|
| Unified, boosting off | `FluidInference/parakeet-unified-en-0.6b-coreml@d32e972dd4315f1dc3f6be28fb2aab0ab3e80358`, NVIDIA Open Model License; conversion card conflicts with CC-BY-4.0. Silero below is included. | 609592802 / 625172480 | 1, built-in term only | `20261005T061114Z-local`, asset log |
| Unified, boosting on | Same Unified and Silero, plus `FluidInference/parakeet-ctc-110m-coreml@accdafd8cf8a2ff1cabe3c11e54416b405d409aa`, CC-BY-4.0 | 712395257 / 728006656 | 100 | `20261005T061642Z-local`, asset log |
| Whisper Turbo | `argmaxinc/whisperkit-coreml@0f63a7800b00dd0226abd051b906c246e1907482`, `openai_whisper-large-v3-v20240930_626MB`, MIT; tokenizer `openai/whisper-large-v3@06f233fe06e710322aca913c1bc4249a0d71fce1`, Apache-2.0; Silero included | 630541207 / 645521408 | 12, prompt token budget can cut the list earlier | `20261005T062416Z-local`, asset log |

Every candidate uses `FluidInference/silero-vad-coreml@b419383c55c110e2c9271fa6ee0ea83d03c70d96`,
MIT. The transfer column sums the pinned required files, not an observed fresh transfer. Disk is
allocated disk use at the verified installed snapshot, including runtime-created files inside
the model directories. The separate bench Core ML cache used 20172800 bytes at that snapshot;
it is shared across candidates and cannot be assigned to one model. See
`20261005T061114Z-local` and its asset and disk logs.

Unified uses the INT8 `70_7_1` encoder, with 560 ms chunks and 80 ms lookahead. Silero's defaults
provide speech evidence and end an utterance after 0.75 s below its threshold. Unboosted text
commits on utterance end; boosted text commits only after rescoring segments on the 15 s cadence,
with a final tail rescore. The CTC tokenizer symlink is written only for boosting. These are the
configurations behind `20261005T061114Z-local` and
`20261005T061642Z-local`, not tuning from this evaluation.

Whisper decodes after one second of new audio and settles leading segments by agreement or
pause. It flushes unsettled audio at 28 seconds, uses one second of preroll and pads short final
inputs. Keyterms are a 64-token prompt; decoding is greedy without temperature fallback.
The pinned local tokenizer prevents Hub fallback. This configuration produced
`20261005T062416Z-local`. Loaded models are reused within each run; fresh sessions
retain no preceding transcript or cleanup conversation.

### Accuracy

xAI's references began as its own drafts and were corrected by Aidan, so its error rates below
are flattering. These are corpus results, not a general accuracy ranking.

| Candidate | WER | Formatted WER | Keyterms | Silence insertions | Contract violations / errors | Run |
|---|---:|---:|---:|---:|---:|---|
| Unified, boosting off | 6.9% | 18.8% | 57.9% | 0 | 0 / 0 | `20261005T061114Z-local` |
| Unified, boosting on | 6.1% | 16.5% | 84.2% | 0 | 0 / 0 | `20261005T061642Z-local` |
| Whisper Turbo | 2.7% | 12.5% | 94.7% | 0 | 0 / 0 | `20261005T062416Z-local` |
| Apple, legacy debug | 10.0% | 19.0% | 31.6% | 0 | 0 / 0 | `20261004T083627Z-apple` |
| xAI, paid legacy debug, biased references | 0.4% | 12.9% | 100.0% | 0 | 0 / 0 | `20261004T073341Z-xai` |

Boosting improves the coding vocabulary but can replace correct ordinary words. On
`dictation-keyterms-apple`, WER falls from 15.0% to 0.0% and keyterms rise from 1/3 to 3/3;
on `dictation-keyterms-models`, they rise from 4/5 to 5/5. On `dictation-question-command`,
WER rises from 0.0% to 5.6%; on `dictation-background-noise`, from 6.2% to 9.4%.
See `20261005T061114Z-local` and `20261005T061642Z-local`.

Whisper is the strongest local recogniser here, but its live handling is slow. The accuracy
advantage is material. On `dictation-keyterms-stack`, Whisper has WER 0.0% and keyterms 6/6,
versus boosted Unified's 6.9% and 4/6. Its latency cost is also clear enough that more repeat
runs would not settle a close decision. See `20261005T062416Z-local`
and `20261005T061642Z-local`.

All rows above have zero changed committed prefixes, checked by the grow-only contract
and the saved event logs for those cited runs.

### Latency and the cost of boosting

Milliseconds are p50 / p95 / n. Apple and xAI have no cold split. xAI's quality references are
biased in its favour; this timing comparison also uses its older debug run and includes network.
First provisional is derived from the event log; committed and tail figures are from `report`.

| Candidate | First provisional | First committed | Stop-to-final | Cold stop-to-final / first committed ms | Run |
|---|---:|---:|---:|---:|---|
| Unified, boosting off | 1299 / 2415 / 13 | p50 6742 / p95 16361 ms (n=13) | p50 47 / p95 54 ms (n=14) | 41 / 9847 | `20261005T061114Z-local` |
| Unified, boosting on | 1267 / 2350 / 13 | p50 8397 / p95 16471 ms (n=13) | p50 283 / p95 307 ms (n=14) | 315 / 10126 | `20261005T061642Z-local` |
| Whisper Turbo | 3428 / 6158 / 13 | p50 11546 / p95 32450 ms (n=13) | p50 3383 / p95 5099 ms (n=14) | 4181 / 13987 | `20261005T062416Z-local` |
| Apple, legacy debug | 1069 / 1933 / 14 | p50 5964 / p95 16730 ms (n=14) | p50 173 / p95 276 ms (n=15) | not recorded / not recorded | `20261004T083627Z-apple` |
| xAI, paid legacy debug, biased references | 1088 / 2097 / 14 | p50 8329 / p95 29320 ms (n=14) | p50 194 / p95 296 ms (n=15) | not recorded / not recorded | `20261004T073341Z-xai` |

Boosting leaves provisional arrival essentially unchanged, but first committed text moves from
6742 ms to 8397 ms at the median, and the stop tail from 47 ms to 283 ms. On
`dictation-thinking-pauses`, first commitment moves from 8911 ms to 16471 ms; on
`dictation-long-continuous`, from 9911 ms to 15473 ms. These per-sample figures are derived from
`20261005T061114Z-local` and `20261005T061642Z-local`.

The following speech-to-commit gaps use the first speech evidence event to first commitment and
the last evidence event to the last commitment, with warm samples only. They are derived from
event timestamps. They are not word alignment: evidence can arrive after inference, particularly
with Whisper, and continuous speech can conceal lag for older words. Exact per-word acoustic lag
was not measured.

| Candidate | First speech to first commit ms, p50 / p95 / n | Last speech to last commit ms, p50 / p95 / n | Run |
|---|---:|---:|---|
| Unified, boosting off | 5952 / 15658 / 13 | 550 / 1258 / 13 | `20261005T061114Z-local`, derived |
| Unified, boosting on | 7688 / 15201 / 13 | 777 / 3353 / 13 | `20261005T061642Z-local`, derived |
| Whisper Turbo | 10840 / 31745 / 13 | 2030 / 2172 / 13 | `20261005T062416Z-local`, derived |

### First downloads and paired installed loading

Each fresh run moved every required installed directory aside, including shared Silero, then
downloaded the pinned files and loaded one sample. Its paired run loaded the same installed files in
a fresh process. Transcription used `dictation-short-reply`; Qwen used `cleanup-clear-correction`.
Download time is readiness start to the loading message, including transfer, file verification and
installation. First load includes runtime loading and warm-up. These phases overlap across
manifests, so they are elapsed service preparation, not summed file-transfer times. The preserved
copies remain under `~/Library/Application Support/EchoType/Evaluation-20261005-exclusive/`.

| Selection | Fresh / paired run | Payload bytes | Download ms | First load ms | Paired installed load ms | Installed / shared bench cache bytes |
|---|---|---:|---:|---:|---:|---:|
| parakeet-unified | `20261005T071509Z-local` / `20261005T071516Z-local` | 609592802 | 29295 | 20987 | 299 | 626429952 / 19521536 |
| parakeet-unified-keyterms | `20261005T071635Z-local` / `20261005T071726Z-local` | 712395257 | 27874 | 43978 | 44176 | 728633344 / 20148224 |
| whisper-turbo | `20261005T072008Z-local` / `20261005T072029Z-local` | 630541207 | 28072 | 128242 | 11076 | 662065152 / 136376320 |
| qwen3-4b-2507 | `20261005T072145Z-local` / `20261005T072155Z-local` | 2274455727 | 64326 | 2271 | 1627 | 2274467840 / 136785920 |

Payload is the pinned selected-file sum, independently verified after delivery. Installed disk
includes runtime-created files inside the model directories. The cache column is the whole shared
bench Core ML cache at that run, not a per-model charge. These are first loads after clean
transfers, with existing system caches; first load after reboot or an OS update remains unmeasured.

The Core ML artifacts already ship as `.mlmodelc`. No source `.mlmodel` compilation is required by
these loaders. Core ML generated executable cache output such as ANE `.e5` and BNNS program files
while loading
the fresh directories, recorded in each run's `evaluation-delivery.json`. Runtime compilation
or specialization therefore occurred, but its duration is not isolated from loading and warm-up.
Qwen uses MLX, so its loading phase has no Core ML compilation. Evidence is the fresh transcription
runs
`20261005T071509Z-local`, `20261005T071635Z-local`, `20261005T072008Z-local`
and Qwen `20261005T072145Z-local`.

| Run | Preparation ms | Peak / ready MiB | Load average median / max | Thermal / pressure |
|---|---:|---:|---:|---|
| `20261005T071509Z-local` | 50282 | 632 / 68 | 2.66 / 3.51 | nominal / normal |
| `20261005T071516Z-local` | 299 | 43 / 43 | 3.72 / 3.72 | nominal / normal |
| `20261005T071635Z-local` | 71852 | 605 / 52 | 3.94 / 4.41 | nominal / normal |
| `20261005T071726Z-local` | 44176 | 115 / 45 | 4.30 / 4.59 | nominal / normal |
| `20261005T072008Z-local` | 156314 | 494 / 95 | 3.45 / 4.50 | nominal / normal |
| `20261005T072029Z-local` | 11076 | 110 / 93 | 3.92 / 4.01 | nominal / normal |
| `20261005T072145Z-local` | 66597 | 4442 / 2378 | 3.72 / 3.93 | nominal / warning |
| `20261005T072155Z-local` | 1627 | 2649 / 2393 | 3.35 / 3.57 | nominal / normal |
| `20261005T072301Z-local` | 54235 | 627 / 66 | 3.71 / 4.04 | nominal / normal |

These single paired loads are observations, not a startup distribution. Boosted Unified still
took 44176 ms in its paired installed load, while Whisper fell from 128242 ms first loading to
11076 ms paired loading (`20261005T071635Z-local`, `20261005T071726Z-local`,
`20261005T072008Z-local`, `20261005T072029Z-local`). Cache creation and specialization
continued during both installed loads. Qwen's fresh peak of 4442 MiB includes delivery and
verification, compared with 2649 MiB for its paired installed process
(`20261005T072145Z-local`, `20261005T072155Z-local`). Neither figure measures only inference.

A separate real Unified download was killed after four seconds. The installed Unified directory was
absent, with 5 files and 14444100 bytes left under `Incomplete/`. The retry completed and installed
every pinned file with matching sizes and SHA-256 values (`20261005T072301Z-local`,
`evaluation-interruption.json` and `evaluation-delivery.json`). The loader entered its loading phase
only after installation; no incomplete directory was passed to the runtime. This proves recovery
from this interruption, not every possible network failure.

The earlier failed interruption remains preserved in `.build/transcription-evaluation/`; it had no
run id because readiness failed. Aidan authorized closing the GUI and MCP processes for the
replacement experiment. Read-only source inspection established that `--mcp` itself never creates
readiness or model services; the GUI can start shared-store downloads. No existing installed model,
set-aside copy or run was deleted. The installed GUI was restored.
The original MCP stdio clients require reconnection because the exposed tools cannot reattach
their transports. A standalone protocol check passed; it does not prove harness reconnection.
See the workstream 5 handoff for restoration evidence. Local read aloud is unavailable in this
slice and belongs to the next workflow; that is separate from the original MCP transport limitation.

### Offline use

Every network-denied pass completed without errors or contract violations. A curl request also
failed under the same deny-network profile. Fast runs provide quality and offline evidence,
not latency figures.

| Candidate | Online / offline WER | Online / offline formatted WER | Identical final texts | Runs |
|---|---:|---:|---:|---|
| parakeet-unified | 6.9% / 6.9% | 18.8% / 18.8% | 15/15 | `20261005T061546Z-local`, `20261005T061600Z-local`, paired derived log |
| parakeet-unified-keyterms | 6.1% / 6.1% | 16.5% / 16.5% | 15/15 | `20261005T062117Z-local`, `20261005T062139Z-local`, paired derived log |
| whisper-turbo | 2.5% / 3.6% | 12.5% / 13.1% | 12/15 | `20261005T063149Z-local`, `20261005T063537Z-local`, paired derived log |

Whisper's differing samples are `dictation-thinking-pauses`, `dictation-false-starts` and
`dictation-long-continuous`. The false-starts WER changes from 9.2% online to 18.5% offline.
Its paced and fast online outputs also differ. Queue timing and rolling-window segmentation are
plausible causes, not a demonstrated effect of network denial. No second offline pass was run to
isolate the cause. See `20261005T063149Z-local`,
`20261005T063537Z-local` and the latter's paired derived log.

### Concurrent dictation and cleanup

Unified with boosting was selected before these passes, with Qwen3-4B-Instruct-2507 cleanup.
The selection record is `.build/transcription-evaluation/preferred-candidate.json` and is copied
into the local dictation run. The later delivery runs also completed successfully.
The bench prepares both models, feeds the actual Reviser live, and scores the raw transcript;
inserted text is not scored as a cleanup reference. The final revision timer starts after the
cancelled live revision joins, so end-to-end insertion and the final deadline are separate
measurements in `20261005T064539Z-local` and `20261005T065030Z-apple`.

Unified with boosting and Qwen, `20261005T064539Z-local`:

- deadline fallbacks 0, deadline overruns 0 (`20261005T064539Z-local`).
- warm stop-to-insert p50 1240 / p95 2716 ms (n=14), transcription p50 295 / p95 341 ms (n=14), cleanup p50 938 / p95 2415 ms (n=14) (`20261005T064539Z-local`).
- warm revision p50 1161 / p95 2775 ms (n=25), cancellation latency p50 2 / p95 407 ms (n=14), revising 11.8% of the time (`20261005T064539Z-local`).
- cold stop-to-insert 2004 ms, transcription 307 ms, cleanup 1697 ms, first revision 1695 ms (`20261005T064539Z-local`).

Apple with Apple cleanup, `20261005T065030Z-apple`:

- deadline fallbacks 1, deadline overruns 0 (`20261005T065030Z-apple`).
- warm stop-to-insert p50 1929 / p95 2922 ms (n=14), transcription p50 176 / p95 280 ms (n=14), cleanup p50 1740 / p95 2642 ms (n=14) (`20261005T065030Z-apple`).
- warm revision p50 1915 / p95 3524 ms (n=38), cancellation latency p50 0 / p95 1 ms (n=13), revising 23.8% of the time (`20261005T065030Z-apple`).
- cold stop-to-insert 3361 ms, transcription 232 ms, cleanup 3128 ms, first revision 3127 ms (`20261005T065030Z-apple`).

The local concurrent final requests stayed inside the deadline: maximum final revision
2008 ms and maximum stop-to-insert 2716 ms (`20261005T064539Z-local`, derived).
This does not prove cancellation during an over-budget request. Joint preparation took
48096 ms and peak footprint was 2781 MiB, versus standalone Qwen's 4043 ms and 2591 MiB
(`20261005T064539Z-local`, `20261005T063709Z-local`). The joint readiness phases do
not isolate download-free compilation, specialization or each service's load.

The standalone release cleanup corpus has different, hand-written windows, so its revision
latency and revising share are context, not a controlled slowdown estimate. Revising is the
arithmetic mean of each counted sample's share, not a duration-weighted total. It reports warm
revision p50/p95 452/1626 ms and revising 79.9% in `20261005T063709Z-local`. The concurrent rows above
measure real recognised windows, including the delay until boosted text first commits. Footprint
covers both loaded local services but still omits Core ML cost charged outside the process.

### Signed app and remaining checks

The [workstream 4 signed-app record](implementation/transcription/04-app-provider.md#external-validation)
passed on the unchanged reviewed candidate. Aidan confirmed the installed app, model progress and
ready states, corrected-content cleanup, long dictation, quick stop, final-tail insertion,
read-aloud unavailability, offline dictation and the Whisper comparison. Switching away during
download was explicitly waived and remains untested in the signed app. The keyterms recommendation
was not a separate signed-app build in that gate.

First load after reboot or an OS update, energy and read aloud were not measured. Neither was the
voice comparison's combined memory. Developer ID notarisation of nested dependency bundles remains
untested. The corpus is one person's speech, and the same few coding terms recur across samples.

### Recommendation

Take forward `parakeet-unified-keyterms` for local live dictation, with Qwen cleanup. It trades a
later stable transcript for markedly better coding vocabulary than unboosted Unified, without
Whisper's multi-second tail. The supporting standalone runs are
`20261005T061114Z-local`, `20261005T061642Z-local` and
`20261005T062416Z-local`; concurrent behaviour is `20261005T064539Z-local`.
Aidan chose to record this recommendation and leave the spike's build selection at unboosted
Unified. Productionising belongs to a separate task. No boosted build follow-up or new signed-app
gate is authorized in this workflow; the normal provider default is unchanged.

The remaining quality gap is real. Boosted Unified has WER 6.1% and keyterms 84.2%, versus xAI's
0.4% and 100.0% on references that began as xAI drafts and therefore flatter it
(`20261005T061642Z-local`, `20261004T073341Z-xai`).
It beats Apple's corpus WER and keyterms, 10.0% and 31.6%, but commits later and has a slower
standalone tail (`20261005T061642Z-local`, `20261004T083627Z-apple`).
Whisper improves local quality to WER 2.7% and keyterms 94.7%, but its warm tail is 3383/5099 ms
and its first committed p95 is 32450 ms (`20261005T062416Z-local`). It is a useful
quality comparison, not the preferred live adapter under these settings.

Unified's remaining recognition and formatted-text gap warrants the spec's offline re-decoding
experiment, and Ultra is a justified later quality challenger. This is a proposal, not measured
proof that either helps (`20261005T061642Z-local`,
`20261005T062416Z-local`). Nemotron's sustained-cost condition is not established by these paced runs
(`20261005T061114Z-local`, `20261005T061642Z-local`): the adapters kept up,
but process footprint can understate Core ML cost and energy was not measured.
Fresh-download and real interruption recovery passed in the delivery runs above. Independent
review and focused closure passed. The evaluation is accepted with the recommendation recorded
and the current build selection unchanged.
