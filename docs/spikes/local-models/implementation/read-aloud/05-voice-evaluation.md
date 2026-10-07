# Workstream 5: Voice evaluation and spike recommendation

Status: accepted. Blind listening gate passed (ET-R5-01); reviewed, remediated and closed.

## Task packet

### Outcome

`docs/spikes/local-models/results.md` has a read aloud section. It compares Kokoro (Emma and
Heart) and Qwen3-TTS (Aidan's chosen preset, plain and styled) with Apple's premium UK voice, on
first audio against the 500 ms target, gaps, paused buffering, cost and Aidan's blind ratings,
and ends with a voice recommendation. The file then closes the spike with its overall
recommendation across all three services: one fixed set, a narrower local feature, or rejection,
with a proposed production scope. Every figure cites the run it came from.

### Scope

Run everything from a release build of the bench (`swift run -c release EchoTypeBench ...`), on
the machine as it is, and record each run's load average from `report`. Use Aidan's chosen Qwen
voice from the plan's decision and drift log. The voices are:

- Apple Jamie (`com.apple.voice.premium.en-GB.Malcolm`), and Zoe if installed;
- Kokoro Emma and Heart;
- Qwen3-TTS, the chosen preset plain and styled.

1. **Paced readings,** one paced pass over all eight passages per voice. These give gaps, the
   pause and cancellation trials, the cold reading, and the WAVs for listening.
2. **First audio,** `--fast --repeat 10` over the four passages tagged `short` or `heteronym`
   (`reading-ordinary-prose`, `reading-agent-reply`, `reading-demo-pronunciation`,
   `reading-past-tense-read`) per voice. That gives about 39 warm readings for p50/p95 against the
   500 ms target, with real-time factor.
3. **0.6B follow-up.** If Qwen3-TTS 1.7B's warm first-audio p50 on the short passages exceeds
   500 ms, run steps 1 and 2 for `qwen3-tts-0.6b` with the same preset, and add it to the
   listening page. Otherwise record that the condition was not met.
4. **Speed,** per local voice candidate: `reading-ordinary-prose` with `--fast` at each end of
   the speed range, recording the duration ratio against speed 1.
5. **First download and cold start** for `kokoro` and `qwen3-tts`, as slice 2 did for
   transcription. Move each installed directory aside under the README's download rule, run one
   short passage to capture download and first load, then again in a fresh process for a load
   from installed files. Record download time and size, first-load time, whether Core ML compiled
   anything (Kokoro), the cold load, and disk used, including runtime-created files and caches.
   - Check first which EchoType processes are running and whether they could touch these files.
     If they could, escalate asking Aidan to quit EchoType for these runs; never quit or kill it
     yourself.
   - Interrupted-download recovery was proven in slice 2 and is not repeated.
6. **Offline,** a `--fast` run per local voice candidate with network access denied
   (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built release binary).
7. **Combined memory.** Two paced `speak` passes over `reading-long-selection` and
   `reading-ordinary-prose`, each with all three services prepared and loaded through
   `--candidate`:
   - the reference combination, Unified, Qwen3 and Kokoro;
   - the voice comparison combination, Unified, Qwen3 and Qwen3-TTS, the spec's expected memory
     worst case.

   Then one paced dictation pass (`transcribe --provider local --cleanup`) with the voice
   comparison combination loaded, to see whether a resident speech model slows cleanup against
   slice 2's `20261005T064539Z-local`.
8. **Blind listening gate.** Build the listening page with `report --listen` over the paced runs
   from steps 1 and 3, and open the gate below. Resume when Aidan's ratings are in.
9. **Write results.** Add a read aloud section to `results.md` in the transcription section's
   style, then the spike's conclusion. Update the file's status line. Correct `research.md` where
   a measurement contradicts it, and the spec's candidate tables if a candidate changed, as
   earlier slices did.

The read aloud section covers:

- runs and candidates: repository, revision, licence and voice terms, download and disk size,
  voices, speed range, utterance and production bounds, and dependency pins;
- Aidan's blind ratings per voice and passage, their pronunciation checks, including "read",
  "demos" and the past-tense "read", whether Kokoro's native conversion reproduces the demo
  mistakes, skipped or invented words they heard, and their comparison with xAI from their own
  experience, stated as such;
- first audio warm p50/p95/n against the 500 ms target, with the cold reading apart, and the
  measurement's limits (the plan's decision log on the modelled player);
- gaps, real-time factor, paused buffering, cancellation latency and speed control;
- the style prompt's effect on ratings and first audio;
- cost: preparation, download, first load, cold load, footprint peak and ready, pressure and
  thermal state, with the note that Core ML work can be charged to system processes;
- combined memory for both combinations, and dictation with the voice comparison combination
  loaded, against slice 2's figures;
- the signed-app check's outcome, from [04-app-read-aloud.md](04-app-read-aloud.md)'s External
  validation section;
- a voice recommendation that keeps the spec's tradeoff explicit: first audible speech decides
  performance, and a large speed advantage can outweigh pronunciation mistakes.

The spike's conclusion covers what the spec's "Expected output and cleanup" asks:

- the recommended model choices per service, or which services should stay with Apple or xAI;
- total download, disk and memory for the recommended set;
- integration changes made, and remaining blockers, such as licence conflicts, notarisation, CI,
  unmeasured first load after reboot and energy;
- remaining quality gaps to xAI and Apple stated plainly;
- one of the spec's outcomes, a fixed set, a narrower local feature, or rejection;
- a proposed production scope, including what to remove from the spike.

It is a proposal for Aidan; it changes no build selection.

### Blind listening gate

Open it after step 7. Write the listening page's path and these instructions into the External
validation section, add an escalation entry pointing to it, and block as the README describes.

The instructions, written for Aidan:

1. Open the listening page (path in the record) in a browser. Each passage has one reading per
   voice under shuffled labels.
2. For each passage, play every reading and rate it 1-5 for how much you would want to listen to
   it. Tick each pronunciation check it gets right, and note any skipped, repeated or invented
   words. The long passage is optional.
3. Save your ratings with the page's button. It downloads a JSON file. Say where it is.
4. After saving, the page shows which voice was which. Add any overall notes, including how each
   voice compares with xAI's from your experience.

The resuming lead copies the ratings file into the evaluation's run evidence under
`~/Library/Application Support/EchoTypeBench/listening/`, not into git.

### Non-goals

- Product code changes. A bench defect that blocks a run is fixed with the smallest change and
  recorded in the handoff; anything larger is an escalation.
- Changing `LocalSelection.build` or the default provider; recommend instead.
- Productionising, removing candidates, energy, or new paid runs.

### Initial ownership

- `docs/spikes/local-models/results.md`, `docs/spikes/local-models/research.md`, and the
  candidate tables in `docs/spikes/local-models/spec.md` if a candidate changed.
- `Sources/EchoTypeBench/`, only for a blocking defect as above.

### Required seams

- Consumes the candidates, bench and listening page as workstreams 1-4 built them. Read their
  handoffs for settings, report fields, the chosen preset and the signed-app outcome.

### Acceptance criteria

1. Every run in scope exists and is cited by id, and every new run was a release build. Every
   figure, bullet and table row in the new and changed sections names its run, including derived
   figures.
2. The read aloud section covers every bullet above, including first audio against the target,
   Aidan's ratings and pronunciation checks, combined memory and the signed-app outcome.
3. The spike's conclusion chooses one of the spec's outcomes and covers every bullet above.
4. Each recommendation follows from cited figures or Aidan's recorded judgement, and claims are
   scoped to what was measured. Comparisons with xAI's voice are labelled as Aidan's recollection.
5. Unmeasured items are named as not measured: first load after reboot, energy, device output
   latency, notarisation.
6. No recording, reference text or ratings file appears in git; documents quote at most sample
   ids and short excerpts `report` prints.

### Targeted verification

```bash
swift build -c release --product EchoTypeBench
swift run -c release EchoTypeBench report 20261005T064539Z-local
```

Run `report` on each cited run id the same way. Check that each figure in `results.md` matches
its `report` output or, for derived figures, the run's logs.

## Implementation handoff

- Base commit: `d629555`
- Outcome: every step is done. Pass 1 ran steps 1-4, 6 and 7 and built the listening page;
  pass 2 (after ET-R5-01) ran step 5 and step 9. `results.md` has the read aloud section and the
  spike's conclusion (outcome: one fixed set, boosted Unified, Qwen3-4B-2507 and Kokoro Heart,
  as an opt-in provider with xAI the default) and a new status line; `research.md` is corrected
  (status, reference combination size and memory, the read aloud table, the MLX pin note).
  `spec.md` is unchanged: no candidate changed (0.6B was not triggered).
- Run provenance: every run below is a release build at `sourceRevision` `d629555`.
  `sourceDirty` is true only because of uncommitted docs; `git diff d629555 -- . ':!docs'` is empty.
  Every command exited 0 and `report` shows 0 failed readings and 0 contract violations in each.
  The load average is from `report` (median, max). The machine was busy throughout, from Aidan's
  other work: the load median ranged from 3.3 to 31.6.
- Runs, with what each is for and their key figures:
  - Step 1, paced, all 8 passages (gaps, pause, cancellation, cold reading and listening WAVs):
    | Run | Voice | Warm first audio p50 / p95 (n=7) | Cold | Gaps | Pause, audio after resume (footprint) | Cancellation | Peak / ready MiB | Pressure / thermal | Load |
    |---|---|---|---|---|---|---|---|---|---|
    | `20261006T140826Z-apple` | Jamie (`com.apple.voice.premium.en-GB.Malcolm`) | 353 / 386 ms | 911 ms | 0 | 1.1 s (13 to 13) | not pending (Apple drains whole) | 20 / 8 | warning / nominal | 4.55, 5.70 |
    | `20261006T141044Z-apple` | Zoe (`com.apple.voice.premium.en-US.Zoe`, installed) | 749 / 764 ms | 1462 ms | 0 | 1.1 s (12 to 12) | not pending | 20 / 8 | warning / nominal | 3.83, 5.21 |
    | `20261006T141305Z-local` | Kokoro Emma (`bf_emma`) | 279 / 616 ms | 345 ms | 0 | 1.1 s (469 to 469) | pending after 10.9 s, 0 ms | 683 / 421 | warning / nominal | 4.10, 4.57 |
    | `20261006T141539Z-local` | Kokoro Heart (`af_heart`) | 270 / 651 ms | 366 ms | 0 | 1.3 s (409 to 417) | pending after 11.0 s, 0 ms | 641 / 418 | warning / nominal | 3.28, 4.52 |
    | `20261007T100825Z-local` | Qwen3-TTS Ryan (`ryan`) | 292 / 482 ms | 236 ms | 0 | 1.2 s (2475 to 2385) | pending after 2.9 s, 0 ms | 2944 / 2550 | critical / nominal | 6.15, 7.70 |

    Preparation (loading): Kokoro 11.3 s and 11.2 s; later Kokoro loads are 2.4 to 2.6 s, except
    `20261007T101244Z-local` 12.6 s, `20261007T101858Z-local` 11.6 s and `20261007T104112Z-local`
    11.8 s (see step 5 for the likely cause). Qwen 2.5 s, Apple 0.2 to 0.3 s. Kokoro's
    `reading-numbers-abbreviations` is the passage over 500 ms (616 and 651 ms).
    `20261006T141807Z-local` is an interrupted, partial Qwen run: never cite it.
  - Step 2, `--fast --repeat 10` over the four short or heteronym passages (n=39 warm each):
    | Run | Voice | Warm p50 / p95 | Short-tagged warm p50 / p95 (n=19) | Cold | Warm RTF p50 / p95 | Peak / ready MiB | Load |
    |---|---|---|---|---|---|---|---|
    | `20261007T101127Z-apple` | Jamie | 340 / 368 ms | 340 / 375 ms | 957 ms | 0.05 / 0.09 | 14 / 8 | 6.30, 6.55 |
    | `20261007T101151Z-apple` | Zoe | 759 / 1021 ms | 779 / 1004 ms | 1399 ms | 0.11 / 0.22 | 16 / 8 | 20.08, 31.39 |
    | `20261007T101244Z-local` | Emma | 281 / 429 ms | 236 / 501 ms | 284 ms | 0.06 / 0.10 | 654 / 427 | 31.31, 32.65 |
    | `20261007T101313Z-local` | Heart | 252 / 352 ms | 206 / 267 ms | 313 ms | 0.06 / 0.07 | 637 / 425 | 22.48, 26.26 |
    | `20261007T101342Z-local` | Ryan | 244 / 489 ms | 241 / 489 ms | 328 ms | 0.55 / 0.61 | 2949 / 2379 | 13.64, 43.04 |

    "Short-tagged" is `report`'s line over `reading-ordinary-prose` and `reading-agent-reply`.
    Pressure worst warning except Zoe and Emma (normal); thermal nominal throughout. Use these
    `--fast` runs, not paced ones, for real-time factor (paced readers pull at playback pace).
  - Step 3: condition not met. Qwen3-TTS 1.7B's warm first audio p50 is 241 ms on the short
    passages and 244 ms over all four (`20261007T101342Z-local`), under 500 ms, so
    `qwen3-tts-0.6b` was not run.
  - Step 4, Kokoro Emma, `reading-ordinary-prose --fast`: speed 1 `20261007T101904Z-local` 9.75 s;
    speed 0.5 `20261007T101858Z-local` 19.43 s (ratio 1.99); speed 2 `20261007T101901Z-local`
    5.23 s (ratio 0.54). Ratios derived from `speak.jsonl` `audioSeconds`. Qwen has no speed range
    (`1...1`, plan's decision log), so it has no speed runs. Load 6.4 to 6.6.
  - Step 5, first download and cold start, `--fast --voice <first> reading-ordinary-prose`, run
    2026-10-07 11:39-11:42Z by `logs/ws5/step5/step5.sh` (under
    `~/Library/Application Support/EchoTypeBench/`; its `step5.log` has each command, exit status
    and run id, plus per-run cache and model-directory listings). Precondition rechecked right
    before: the only EchoType process was `/Applications/EchoType.app/... --mcp` (pid 36802); the
    script aborted on any other `EchoTypeApp`. The installed directory (and, for Kokoro, the
    `~/.cache/fluidaudio/Models/kokoro` link) was moved to
    `~/Library/Application Support/EchoType/Evaluation-20261007-readaloud/`, then removed once the
    fresh directory matched it by SHA-256 file for file (Qwen's runtime `tokenizer.json` differs in
    bytes only: same size, `json.load` equal, different key order). Every command exited 0.
    | Run | What | Preparation | Peak / ready MiB | Load |
    |---|---|---|---|---|
    | `20261007T114030Z-local` | Kokoro fresh | 51.4 s: downloading 40.2 s, loading 11.2 s | 479 / 419 | 4.32, 4.73 |
    | `20261007T114034Z-local` | Kokoro installed | loading 2.5 s | 466 / 437 | 4.13, 4.32 |
    | `20261007T114144Z-local` | Qwen fresh | 69.7 s: downloading 66.4 s, loading 3.3 s | 3178 / 2555 | 6.09, 6.85 |
    | `20261007T114153Z-local` | Qwen installed | loading 1.4 s | 2937 / 2593 | 6.08, 6.18 |

    Disk (`du -sk`): Kokoro 99,584 KiB, Qwen 2,264,860 KiB. Runtime-created: Kokoro `ANE/bf_emma.bin`
    and both links; Qwen `tokenizer.json`. Core ML: `~/Library/Caches/EchoTypeBench` went from
    41 files / 84,352 bytes to 107 files / 242,306,419 bytes during Kokoro's fresh load (`.e5`
    and BNNS programs under `com.apple.e5rt.e5bundlecache`), unchanged by the installed load, and
    back to 46 files / 84,672 bytes during the Qwen fresh run. The cause of that emptying is not
    established (free disk was about 11 GiB before a 2.3 GB download); it is the likely reason
    for Kokoro's recurring 11 to 13 s loads, stated in results as consistent with, not proven.
    Pressure normal, thermal nominal in all four.
  - Step 6, offline, `--fast` all 8 under `sandbox-exec -p '(version 1)(allow default)(deny
    network*)' .build/release/EchoTypeBench`, both exit 0:
    - `20261007T104112Z-local` Kokoro Emma: warm p50 257 / p95 598 ms, cold 390 ms, warm RTF p50
      0.06, peak 819 / ready 436 MiB, load 10.24, 11.29.
    - `20261007T104124Z-local` Qwen Ryan: warm p50 282 / p95 458 ms, cold 249 ms, warm RTF p50
      0.56 / p95 0.59, peak 2951 / ready 2637 MiB, load 12.89, 16.94.
    - Evidence: `~/Library/Application Support/EchoTypeBench/logs/ws5/runs.log` (each exact
      command, its start, exit status and run directory) and `step6-*.out`. Immediately before,
      `sandbox-exec` with the same profile made `curl https://huggingface.co` fail with "Could not
      resolve host" (exit 6) while plain `curl` returned 200.
    - `20261007T101908Z-local` and `20261007T101920Z-local` (earlier `--fast` runs) have no proof
      of the sandbox and are superseded: do not cite them as offline evidence.
  - Step 7, combined memory, paced over `reading-long-selection` and `reading-ordinary-prose`,
    every service loaded through `--candidate` (`transcription=parakeet-unified`,
    `cleanup=qwen3-4b-2507`):
    - Reference combination, `voice=kokoro` Emma, `20261007T104327Z-local`: footprint peak
      3062 / ready 2806 MiB, pressure warning, thermal nominal, load 11.64, 26.34. First audio cold
      447 ms, warm 285 ms; 0 gaps; pause 1.1 s after resume; trial pending, 0 ms. Preparation
      29.7 s.
    - Voice comparison combination, `voice=qwen3-tts` Ryan, `20261007T104448Z-local`: peak 5201 /
      ready 4775 MiB, pressure critical, thermal nominal, load 31.59, 35.96. First audio cold
      246 ms, warm 280 ms; 0 gaps; pause 1.1 s after resume; trial pending, 0 ms. Preparation
      4.6 s.
    - Dictation with the voice comparison combination loaded (`transcribe --provider local
      --cleanup`, `voice=qwen3-tts` too), `20261007T104647Z-local`, against `20261005T064539Z-local`:
      | Figure | `20261007T104647Z-local` | `20261005T064539Z-local` |
      |---|---|---|
      | Warm stop-to-insert p50 / p95 (n=14) | 1357 / 2260 ms | 1240 / 2716 ms |
      | Cleanup p50 / p95 (n=14) | 1306 / 2209 ms | 938 / 2415 ms |
      | Transcription p50 / p95 | 48 / 58 ms | 295 / 341 ms |
      | Cold stop-to-insert (cleanup) | 1828 ms (1782) | 2004 ms (1697) |
      | Warm revision p50 / p95 | 1564 / 2513 ms (n=35) | 1161 / 2775 ms (n=25) |
      | Cancellation latency p50 / p95 | 230 / 1045 ms (n=13) | 2 / 407 ms (n=14) |
      | Deadline fallbacks / overruns | 0 / 0 | 0 / 0 |
      | WER / formatted / keyterms | 6.9% / 18.8% / 57.9% | 6.1% / 16.5% / 84.2% |
      | Footprint peak / ready | 4977 / 4685 MiB | 2781 / 2478 MiB |
      | Pressure / thermal | warning / nominal | warning / nominal |
      | Load median, max | 8.69, 24.87 | 4.66, 6.88 |

      Not like for like on transcription: the packet's combination is `parakeet-unified`, while
      `20261005T064539Z-local` used `parakeet-unified-keyterms` (boosting on), which explains the
      WER, keyterm and transcription-time differences (6.9% / 18.8% match slice 2's unboosted
      Unified). Cleanup is the same model in both; its p50 is 368 ms slower and p95 206 ms faster,
      on a busier machine (load median 8.69 against 4.66), so this run alone cannot attribute the
      difference to the resident voice model.
- Qwen readings that end at the codec-step cap (ET-R4-02):
  - Method: MLX Audio Swift caps each utterance at `max(75, 6 × text tokens)` codec steps, each
    1920 samples (80 ms) at 24 kHz. Utterances and token counts came from a scratch test (deleted)
    calling `QwenTTSSpeech.utterances(in:limit: 250)` and `AutoTokenizer.from(modelFolder:)` on the
    installed 1.7B store directory, the tokenizer and call MLX Audio Swift uses. Caps: demo 222
    (37 tokens), past-tense 84 (14), technical 264 (44), numbers 342 (57), punctuation 192 (32),
    ordinary prose 204 (34), agent reply 222 (37); long selection is five utterances, caps 252,
    246, 246, 240, 138 (sum 1122). Every reading's `audioSeconds / 0.08` is a whole step count;
    a single-utterance reading with steps equal to its cap ended at the cap.
  - Listening run `20261007T100825Z-local`: `reading-demo-pronunciation` (222), `reading-technical-terms`
    (264) and `reading-numbers-abbreviations` (342) end at the cap. The other four
    single-utterance readings ended before it.
  - `20261007T101342Z-local`: 6 of 40 at the cap: `reading-demo-pronunciation` repeats 3, 5, 7
    and `reading-agent-reply` repeats 4, 5, 9 (indexes from 0). First audio is unaffected, since
    the cap ends a reading, not its start.
  - `20261007T104124Z-local`: `reading-technical-terms` (264). `20261007T104448Z-local`: none of
    its single-utterance readings.
  - `reading-long-selection` (813 of 1122 steps in `20261007T100825Z-local`, 880 in
    `20261007T104124Z-local`, 863 in `20261007T104448Z-local`): undetermined. The bench records
    only whole-reading audio, so whether one of its five utterances hit its own cap cannot be
    told from the runs. A tail-energy check on the WAVs did not separate capped from uncapped
    readings, so it is not evidence.
  - The listening page keeps the capped readings unmarked, since marking them would reveal the
    Qwen voice. The lead decides whether the gate instructions mention it; results must mark them.
- Listening page: `~/Library/Application Support/EchoTypeBench/listening/20261007T105149Z/index.html`,
  from `report --listen 20261006T140826Z-apple 20261006T141044Z-apple 20261006T141305Z-local
  20261006T141539Z-local 20261007T100825Z-local` (exit 0). 8 passages, 5 readings each (40 WAVs).
  Aidan's ratings are `ratings.json` beside it (saved 2026-10-07T11:30Z; 37 of 40 readings rated,
  checks recorded on every passage that has them). It never enters git; results quote only
  scores, checks and short excerpts.
- Ratings, derived from that file (mean, n rated; checks right of 21): Heart 3.71 (7), 10;
  Ryan 2.88 (8), 11; Emma 2.71 (7), 8; Zoe 1.50 (8), 17; Jamie 1.43 (7), 15. Heart's and Zoe's
  5173 ticks contradict their notes ("five thousand four hundred and seventy three"); results
  count the ticks and state the contradiction under the checks table (by the notes: Heart 9/21,
  Zoe 16/21).
- Voice recommendation and why: Kokoro Heart (`af_heart`), Emma second. Both local voices meet the
  500 ms target, so first audio does not decide; Aidan rated Heart highest and called Ryan
  "unhinged" at times; Kokoro costs 97 MB and about 0.4 GiB against 2.3 GB and 2.5 GiB; Qwen has
  the fork blockers (ET-R3-01, ET-R4-02). Qwen kept as a later controllability experiment.
- Spike outcome: one fixed set (`parakeet-unified-keyterms`, `qwen3-4b-2507`, Kokoro Heart),
  opt-in, xAI the default; production scope removes Whisper, SmolLM3, Qwen3-TTS, MLX Audio Swift
  and the selection machinery, and fixes Kokoro's "the" and number normalisation. The build
  selection is unchanged (Emma is still Kokoro's first voice).
- Decisions:
  - Step 7's dictation pass uses the packet's combination (`parakeet-unified`), not the boosted
    variant of the slice 2 baseline; see the table's note.
  - Runs were made with the built `.build/release/EchoTypeBench` (rebuilt and up to date at
    `swift build -c release`), which is what `swift run -c release` runs; `run.json` records
    `release`.
  - Step 5 used `--fast` on one short passage, so the fresh and installed runs record preparation,
    cold first audio and footprint without the cancellation trial.
  - The style prompt has no new measurement: Aidan's workstream 4 verdict (no different) stands,
    and results cite workstream 3's `20261005T211844Z-local` for its only first-audio figures.
  - Recommending Heart over the built default Emma, and the outcome, are proposals; no code changed.
  - ET-R5-01 (Aidan, 2026-10-07), lasting: the blind listening gate passed and step 5 ran with
    EchoType's app windows quit. Aidan preferred Kokoro Heart and Qwen3-TTS Ryan; Heart
    mispronounces some things, Ryan is the most realistic but unpredictable, and Qwen needs more
    control (consistent, neutral tone) before it is worth productionising; custom Qwen voices are
    an idea for later. No xAI voice-quality comparison; start time "very comparable with XAI" is
    their recollection. Their notes are recorded verbatim in External validation; the ratings file
    stays at `listening/20261007T105149Z/ratings.json`, outside git.
  - Lead triage: the review's five Optional observations (O1 to O5) were promoted to Required as
    accuracy and scoping fixes under acceptance criterion 4; Q1's quote was kept and re-cited to
    External validation, since the plan's escalation entry is removed at acceptance. R1 (stale gate
    status) was fixed by the lead.
- Bench fixes, if any: none.
- Verification: `swift build -c release --product EchoTypeBench` passes; `swift run -c release
  EchoTypeBench report 20261005T064539Z-local` exits 0. `report` exits 0 for every run id cited in
  the new and changed sections (outputs under `logs/ws5/reports/`), including the earlier-slice
  runs the conclusion cites. Figures were checked against those outputs; derived figures (speed
  ratios, rating means, check counts, cap marks, byte totals) against `speak.jsonl`, the ratings
  file and the step 5 listings. `git diff --check` passes. No ratings file, recording or reference
  text is in the worktree. No `EchoTypeApp` or `EchoTypeBench` crash report in
  `~/Library/Logs/DiagnosticReports` (checked 2026-10-07 after the comparison app was quit and
  again after step 5).
- Known limitations or external checks:
  - The machine was busy for most runs (load medians up to 31.6), and figures vary with it; Zoe's
    and Emma's step 2 runs ran at load medians of 20 and 31.
  - Memory pressure reached critical with Qwen loaded (`20261007T100825Z-local`,
    `20261007T104448Z-local`).
  - For the final review: the comparison app `.build/voice-check/EchoType.app` is quit and left no
    crash report, but whether Aidan stopped a Qwen reading just before quitting is unknown, so
    ET-R3-01's stop-then-quit stays unobserved. `.build/voice-check/` is not deleted (final
    review's pending item).
  - Kokoro's Core ML cache was emptied by the time this pass ended, so the next Kokoro load on
    this Mac will likely take about 11 s.
- Specification drift: none beyond the plan's log (no xAI read aloud baseline; Qwen plain Ryan
  only, styled not re-measured; cap readings marked per ET-R4-02).

## Independent review

- Reviewer: fresh independent review agent (Claude Code), 2026-10-07.
- Verdict: changes required, one small record fix (R1, lead-owned). The results, research and
  figures are sound: every acceptance criterion is met on the evidence checked.
- Checks run: `swift build -c release --product EchoTypeBench` passes; `report` exits 0 for all 36
  run ids under `logs/ws5/reports/` (including `20261005T064539Z-local`), and each fresh output is
  identical to the saved one. Every run id cited in the new `results.md` and `research.md` text is
  in that set and exists under `runs/`; all 22 slice 3 runs have `buildConfiguration` `release`,
  `sourceRevision` `d629555` (committed 13:58Z on 10-06, before the first run).
  `git diff d629555 -- . ':!docs'` is empty and `git diff --check` passes. No ratings file,
  recording or reference text is in the worktree (`docs/spikes/local-models/ratings.json` is
  gone; `git status --ignored` shows nothing new).
- Acceptance criteria:
  1. Met. Spot-checked against `report`: every row of the runs, first audio, gaps/RTF/pause/
     cancellation, offline, combined memory, dictation and cost tables; Kokoro's 11 to 13 s and
     2.4 to 2.6 s load lists; Qwen's 2.5 to 4.6 s; load range 3.28 to 31.59; footprint ranges
     637-683 and 2944-2949. Derived figures rechecked: speed ratios from `speak.jsonl`
     (9.75/19.425/5.225 s, 1.99 and 0.54); Qwen caps (`audioSeconds / 0.08` = 222, 264, 342 in
     `20261007T100825Z-local`, 264 in `20261007T104124Z-local`); step 5 disk (99,584 and
     2,264,860 KiB), files (50 = 49 + `bf_emma.bin`; 8 = 7 + `tokenizer.json`), SHA diff
     (Kokoro empty; Qwen only `tokenizer.json`); download sum 3,084,340,346 and unboosted 2.98 GB;
     disk sum 728,633,344 + 2,274,467,840 + 101,974,016 = 3,105,075,200; 2139 MiB = 2.1 GiB.
  2. Met. Every read aloud bullet is covered; ratings table cells, means, n and check counts all
     match `ratings.json` (37 of 40 rated); the pronunciation table and the per-voice quotes
     ("thee", "jee-bee", "ahm", "hash", "pen-pom", "gy-bytes", "tice", "veet madda beet",
     "lock-al-host", "good fallback potentially", sigh, laughs) are faithful to the notes, and the
     overall-notes excerpts match plan.md's ET-R5-01 answer.
  3. Met. Outcome is one fixed set; model choices, download/disk/memory, integration changes,
     blockers, quality gaps and production scope (including the spec's removal of
     `LocalCandidates.swift` machinery) are all present.
  4. Met, subject to Q1. xAI comparisons are labelled as Aidan's recollection.
  5. Met. Reboot first load, energy, device output latency and notarisation are named as not
     measured, in both the section and the conclusion.
  6. Met.
- Required findings:
  - R1 (record accuracy, lead-owned). This packet's External validation still says `Status:
    Pending`, "No review has run yet" and asks the resuming lead to run step 5, and plan.md's gate
    row says `Open (ET-R5-01)`, while the handoff, results and plan's ET-R5-01 answer show the
    ratings are in (`ratings.json` saved 11:30Z) and step 5 ran (11:39-11:42Z). Record attempt 1's
    outcome (ratings file location, step 5 run with EchoType quit) and set both statuses to passed
    before acceptance. Evidence: this file's External validation section; plan.md gate table.
- Optional observations:
  - O1. Two ticks contradict their notes, not one: Heart's and Zoe's `5173` on
    `reading-technical-terms` are ticked right while both notes say "five thousand four hundred and
    seventy three" (the same sentence as Emma's, likely pasted). The handoff mentions only Heart and
    results say nothing. One clause under the checks table ("two ticks conflict with their notes;
    counts follow the ticks") would keep Heart's 10/21 and Zoe's 17/21 honest.
  - O2. Recommendation's first bullet says Heart and Ryan "both beat Apple's Jamie, 340 / 375 ms";
    Ryan's short p95 is 489 ms, behind Jamie's 375 (`20261007T101342Z-local`,
    `20261007T101127Z-apple`). Scope it to p50.
  - O3. "Core ML cache written by the first load, bytes 242,306,419 in 66 files" (Cost table and
    conclusion's Disk bullet) is the cache total after the load; the growth is 242,222,067 bytes
    (before 41 files / 84,352 bytes, after 107 / 242,306,419, `logs/ws5/step5/kokoro-fresh.*.cache.txt`).
    Either say "cache size after" or use the delta. Immaterial to any conclusion.
  - O4. The conclusion lists Kokoro's 11 to 13 s reloads as a blocker but not boosted Unified's
    44,176 ms paired installed load (`20261005T071726Z-local`, results' transcription section),
    which is the slowest installed load in the recommended set. Worth one line under blockers or
    the recommended set's costs, since the set chooses the boosted variant.
  - O5. "Aidan noted ... no skipped or repeated words in any reading" reads as a positive statement
    by Aidan; the ratings file is simply silent on it, and three Ryan readings ended at the cap.
    "did not note any skipped or repeated words" is more exact.
- Questions:
  - Q1. The quote that local start time is "very comparable with XAI" is cited to plan.md's
    ET-R5-01 answer, which attributes it to "the workstream 4 gate note", but no committed or
    uncommitted document contains it (`git log --all -S "very comparable"` finds nothing;
    `04-app-read-aloud.md`'s gate record has "well within my tolerance" only). Can the lead confirm
    Aidan said it? If it cannot be traced, drop it from results' xAI paragraph and the
    conclusion's model table, leaving "no comparison with xAI given".

## Resolution

- Finding dispositions (all in `results.md`; R1 is lead-owned and untouched):
  - O1 fixed: a note under the ratings table says Heart's and Zoe's `5173` ticks contradict their
    notes, that the table and counts follow the ticks, and what the notes would give (Heart 3/8,
    9/21; Zoe 5/8, 16/21). The handoff's ratings bullet now names both.
  - O2 fixed: the recommendation's first-audio bullet says both start sooner than Jamie at p50
    (340 ms), and at p95 Heart does (267 ms) and Ryan does not (489 against 375 ms).
  - O3 fixed: the cost table and the conclusion's disk bullet use the growth, 242,222,067 bytes in
    66 files (107 / 242,306,419 after minus 41 / 84,352 before, `logs/ws5/step5/kokoro-fresh.*.cache.txt`).
    The cost prose ("gained 242 MB") and `research.md`'s "about 242 MB" already match.
  - O4 fixed: a blocker bullet in the conclusion gives boosted Unified's 44,176 ms paired installed
    load (`20261005T071726Z-local`) against its 43,978 ms first load (`20261005T071635Z-local`) and
    the unboosted 299 ms (`20261005T071516Z-local`), as one observation with the cause not isolated.
  - O5 fixed: the ratings file has no statement about skipped or repeated words, so results now say
    Aidan "did not note any skipped or repeated words".
  - Q1 fixed: the quote is kept and attributed as Aidan's recollection, relayed from the
    workstream 4 gate. All five `(plan, ET-R5-01 answer)` citations in `results.md` now cite
    `05-voice-evaluation.md`, External validation; none remain in `results.md`, `research.md` or
    `spec.md`.
- Simplification/deletion pass: no new concepts were added; O1 and O4 are one note and one bullet.
  The new citation reuses the bare-filename style `results.md` already uses for
  `04-app-read-aloud.md`. Nothing else in the owned files became obsolete.
- Final verification: `swift build -c release --product EchoTypeBench` passes. `report` exits 0 for
  `20261005T064539Z-local` and for every run the changed text cites (`20261005T071516Z-local`,
  `20261005T071635Z-local`, `20261005T071726Z-local`, `20261007T101127Z-apple`,
  `20261007T101313Z-local`, `20261007T101342Z-local`); its preparation (299, 43,978, 44,176 ms)
  and short-passage first audio (340 / 375, 206 / 267, 241 / 489 ms) match the text. The cache
  delta and the ratings-file facts were rechecked against `kokoro-fresh.*.cache.txt` and
  `ratings.json`. `git diff --check` passes.

## Closure review

- Reviewer: fresh closure review agent (Claude Code), 2026-10-07.
- Verdict: closed, no release-blocking defect.
- Remaining required findings: none.
- Accepted findings checked:
  - R1 fixed. External validation reads `Status: Passed` and records attempt 1's outcome (ratings
    file location, overall notes, xAI remark, app windows quit for step 5, `--mcp` left running);
    plan.md's Blind listening gate row reads `Passed (ET-R5-01; step 5 run, not waived)`.
  - O1 fixed. The note under the ratings table names both `5173` ticks; recomputed from
    `ratings.json`: Heart 10/21 by ticks (4/8 technical), Zoe 17/21 (6/8), so 3/8, 9/21 and 5/8,
    16/21 by the notes, as stated.
  - O2 fixed. The first-audio bullet scopes the Jamie comparison to p50 and states Ryan's p95 is
    behind; `report` gives 340 / 375, 206 / 267 and 241 / 489 ms for the short passages
    (`20261007T101127Z-apple`, `20261007T101313Z-local`, `20261007T101342Z-local`).
  - O3 fixed. The cost table and the conclusion's disk bullet give 242,222,067 bytes in 66 files;
    the step 5 listings sum to 41 / 84,352 before and 107 / 242,306,419 after.
  - O4 fixed. The blocker bullet's 44,176, 43,978 and 299 ms match `report` for
    `20261005T071726Z-local`, `20261005T071635Z-local` and `20261005T071516Z-local`.
  - O5 fixed. Results say Aidan "did not note any skipped or repeated words".
  - Q1 fixed. The quote is labelled Aidan's recollection, relayed from the workstream 4 gate, and
    cites this file's External validation, which now contains it. No `ET-R5-01` citation remains
    in `results.md`, `research.md` or `spec.md`.
- Verification: `swift build -c release --product EchoTypeBench` passes. `swift run -c release
  EchoTypeBench report` exits 0 for `20261005T064539Z-local` and for each run the fixes cite
  (above, plus `20261007T114030Z-local`, `20261006T141539Z-local`, `20261006T141044Z-apple`).
  `git diff --check` passes; no ratings file or recording is tracked or untracked in the worktree.
  No bench run was made and no EchoType process was touched.
- Note for the lead, not a finding: this file's top status line still says "not yet reviewed";
  update it at acceptance.

## External validation

- Gate and placement: blind listening, after the paced runs and before results.
- Status: `Passed` (ET-R5-01, opened and answered 2026-10-07; step 5 run, not waived)
- Candidate: listening page
  `~/Library/Application Support/EchoTypeBench/listening/20261007T105149Z/index.html`, built by
  `report --listen` over the paced runs `20261006T140826Z-apple` (Jamie), `20261006T141044Z-apple`
  (Zoe), `20261006T141305Z-local` (Kokoro Emma), `20261006T141539Z-local` (Kokoro Heart) and
  `20261007T100825Z-local` (Qwen3-TTS Ryan, plain). 8 passages, 5 readings each. Qwen 0.6B is
  not included: its condition was not met (handoff, step 3).
- Instructions for Aidan:
  1. Open the listening page (path above) in a browser. Each passage has one reading per voice
     under shuffled labels.
  2. For each passage, play every reading and rate it 1-5 for how much you would want to listen
     to it. Tick each pronunciation check it gets right, and note any skipped, repeated or
     invented words. The long passage is optional.
  3. Save your ratings with the page's button. It downloads a JSON file. Say where it is.
  4. After saving, the page shows which voice was which. Add any overall notes, including how
     each voice compares with xAI's from your experience.

  Addition from the lead: a few readings stop before the end of the passage. That is a known
  runtime cap (ET-R4-02), not a page fault. Rate the voice on what it read and note the reading
  as cut off.
- Second request in the same entry, step 5 (first download and cold start): the voice comparison
  app `.build/voice-check/EchoType.app` was running against the shared model store, so the
  packet requires Aidan to quit EchoType for these runs. When convenient, quit every EchoType app
  window (the comparison app and `/Applications/EchoType.app`), leave the `--mcp` processes alone,
  and keep EchoType closed until the resuming lead reports step 5 done (about 15 to 30 minutes,
  mostly the Qwen download). Quitting the comparison app also lets the final review check
  ET-R3-01's teardown crash report and remove `.build/voice-check/`.
- Required evidence: Aidan's saved ratings file, with notes, for every passage they rated; and
  confirmation that EchoType is quit, or a waiver of step 5.
- Outcome (Aidan's answer, 2026-10-07, attempt 1):
  - Ratings saved and moved out of the repository to
    `~/Library/Application Support/EchoTypeBench/listening/20261007T105149Z/ratings.json`; never in
    git.
  - Overall notes, verbatim: "Kokoro Heart and Qwen3 Ryan were the ones that I quite liked and
    found most realistic. Heart doesn't quite pronounce things quite right, but Ryan was like
    totally unpredictable and at times unhinged. The potential is massive there though, because it
    was so realistic. But we need to control the model more. Get it to produce more consistent,
    neutral sounding tones. There may be research we can do on how best to use Qwen 3 TTS. That
    will give us that level of control. I can see it being really fun to generate custom voices
    with, like if the settings had an option when using Qwen to create a custom voice, that could
    just be hilarious."
  - xAI: no comparison of voice quality. Aidan's only remark, relayed with this answer from the
    workstream 4 gate, is that local start time is "very comparable with XAI"; it is their
    recollection, not a measurement.
  - EchoType's app windows were quit for step 5; the `--mcp` processes were left running and do
    not touch the model store (`MCPProcess.swift` builds no store or services).
- Resume condition: met. Step 5 ran (handoff) and results were written after the ratings.
