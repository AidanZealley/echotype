# Workstream 5: Voice evaluation and spike recommendation

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Runs, with what each is for: `TBD`
- Voice recommendation and why: `TBD`
- Spike outcome: `TBD`
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

## External validation

- Gate and placement: blind listening, after the paced runs and before results.
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: Aidan's saved ratings file, with notes, for every passage they rated.
- Attempts and lasting decisions: `TBD`
- Resume condition: the ratings file is saved and copied into the evaluation's evidence.
