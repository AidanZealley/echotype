# Local models spike results

Status: cleanup section only (slice 1, workstream 4). Transcription and read aloud are not run yet.

Every figure is from `swift run EchoTypeBench report <run id>` and was rechecked against its
output. Figures marked "derived" come from the run's `cleanup.jsonl` rather than `report`.
Runs are under `~/Library/Application Support/EchoTypeBench/runs/`, from source revision
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
(`ModelStoreTests`), not by killing a live download.

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
runs (first, cold request excluded) is 452 ms for qwen3 and 464 ms for smollm3, so cold is about 19% and 5% slower (`…110130Z-local`,
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

Across all cited qwen3 runs the highest peak is 2649 MiB (about 2.6 GiB, `…111803Z-local`, offline
`--fast`), with 2638 MiB in `…105222Z-local` (`--fast`); smollm3's highest is 2171 MiB
(`…105256Z-local`). The cold-start runs peak at 2571 MiB and 2169 MiB, ready 2381 and 1829 MiB, with pressure normal
(`…111652Z-local`, `…111730Z-local`). Memory pressure `warning` also appeared in `…105222Z-local`
(qwen3 `--fast`) but in no other run, on a busy 16 GiB machine; I cannot attribute it to the
model alone. Apple's and xAI's footprints describe the bench only, not Apple's out-of-process
model. The planning estimate of 3 to 4 GB for qwen3 in `research.md` is high against the 2649 MiB
peak (`…111803Z-local`) for this window size; the buffer cache limit was 64 MiB. Concurrent memory with transcription and
read aloud is the later slices' question.

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
long sample; `…110130Z-local`, `…121048Z-xai`), one command-following failure that falls back safely, and a local cost of about 2.6 GiB
of memory and a 3 s load that xAI does not have. smollm3-3b is rejected: 60 validation rejections, 15
wrong-deleted words and the most missed edits, for 0.5 GiB less memory (`…110916Z-local`).

Both candidates under-edit false starts and the abandoned "the build"; that is a prompt and model
limit under the spec's rule of sending Reviser's prompt unchanged, and it is the same limit xAI (paid) shows.
It is not a reason to reject Qwen but means "cleanup" here is conservative tidying, not full
disfluency removal.

Conditions before treating this as a product direction: repeat on a quiet machine with a release
build; measure cleanup running alongside local transcription (the spec's concurrent check); grow the
corpus beyond 11 inputs with real dictation.

**Follow-ups, proposed and not built:**

- **Draft-model speculation: not triggered by anything measured.** The spec's condition is that warm
  latency misses the budget. It never did alone: longest stop-to-insert 2.23 s, longest final request
  1.85 s against a 3 s budget (`…110130Z-local`). The concurrent run with local transcription is still to
  decide.
- **Constrained decoding: not worth it for qwen3.** The spec's condition is that validation rejections
  prove common, and I read it that way. qwen3 had 0 rejections in 255 non-cancelled requests
  (`…110130Z-local`). smollm3 had 60 of 255 non-cancelled requests (30 of 165 final requests, on 2 of 11
  samples; `…110916Z-local`) and is rejected anyway. It would not touch qwen3's actual gap,
  under-editing, since a subsequence grammar permits keeping every word. One thing could change the
  verdict: qwen3's 15 length-cap failures on `command-not-followed` (15 of 165 final requests) are a
  different check (the output cap), safe fallbacks on one sample, and constrained decoding would arguably
  prevent them. They do not meet the spec's condition, and cost a 945 ms median stop-to-insert on that
  sample.
