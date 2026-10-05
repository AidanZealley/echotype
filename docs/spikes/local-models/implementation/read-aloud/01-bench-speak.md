# Workstream 1: Bench reading and listening page

Status: implemented, awaiting review.

## Task packet

### Outcome

The bench can read the corpus's passages through any provider's `VoiceService` the way the app's
reader does, without making sound. A `speak` run records each reading's first audio, gaps,
synthesis speed, audio held while paused, cancellation latency, memory and a WAV, and checks the
`SpeechStream` contract. `report` scores `speak` runs and builds a blind listening page from
several of them, on which Aidan rates each passage and saves their ratings as JSON. Apple's voices
prove it. A local run also prepares every service named with `--candidate`, so later workstreams
can measure a combination's memory.

### Scope

- **`speak` command,** with `--provider`, `--voice <id>`, `--speed <x>`, `--fast`, `--repeat <n>`
  and sample ids, like `transcribe` and `cleanup`. It reads every `reading` sample in the
  manifest, or the ids given. The default voice is the service's first, and the default speed 1.
  An unknown voice, or a speed outside the service's range, fails before a run directory is
  created.
- **Paced player model.** Paced runs pull the stream as `Reader` and `SpeechPlayer` do (see
  `Sources/EchoTypeApp/Reader.swift` and `SpeechPlayer.swift`). The player starts on the first
  chunk, holds at most 500 ms queued and drains in real time, and the next chunk is pulled only
  when it fits. `--fast` pulls without waiting, for synthesis speed and first audio only.
- **Pause.** In paced runs, samples tagged `pause-resume` pause once, about a third of the way
  through the audio, for 5 seconds; the player stops draining and pulling. Record how much audio
  arrives without waiting in the first second after resuming, as the observable measure of audio
  generated while paused. Also record the sampler's footprint across the pause.
- **Cancellation.** Paced runs end each pass with one cancellation trial on the longest passage.
  Cancel after about 2 seconds of audio while a `next()` is pending, and record the time until it
  throws or returns.
- **Records,** per reading:
  - request time and first chunk time ("first audio");
  - gaps, meaning a queue that ran dry before the end: count and total duration;
  - total synthesis time, audio duration and real-time factor;
  - chunk count, the largest chunk and the sample rate;
  - audio after resume, cancellation latency, and the WAV in the run directory.
- **Contract check.** Record violations as other commands do: a chunk over 100 ms, a changed
  sample rate, an empty stream for non-empty text, a cancellation that does not end `next()`
  within 1 s, and an error thrown.
- **Sampler, preparation and cold split,** as for `transcribe` and `cleanup`. The run's first
  reading is the cold request.
- **Report.** Covers:
  - first audio, warm p50/p95/n, with the cold reading apart;
  - first audio for passages tagged `short` against the spec's 500 ms target, reported
    separately;
  - gaps, real-time factor, audio after resume, cancellation latency;
  - preparation, footprint, thermal state, pressure and load average.
- **Listening page.** `report --listen <run-id>...` writes a self-contained HTML page and copies
  of the WAVs into a new directory under `~/Library/Application Support/EchoTypeBench/listening/`,
  and prints its path. For each passage it:
  - shows the text and plays one reading from every run, under shuffled labels;
  - asks for a 1-5 rating per reading, a tick for each item in the passage's `checks` that it got
    right, and a free note;
  - offers a button that downloads the ratings as JSON, with the mapping from label to run and
    voice;
  - reveals the mapping only after saving.

  Plain HTML and JavaScript in one file, no dependencies.
- **Preparing named services.** A local run prepares the service it measures plus every service
  named with `--candidate`, and keeps them loaded for the run. This workstream applies it to
  `transcribe` and `cleanup`, where `--candidate` already names `transcription` and `cleanup`.
  Workstream 2 adds `voice`. `speak --provider local` cannot run until then; it fails with the
  usual "no voice" readiness message.
- Update the harness spec's bench section and the bench's usage text to describe `speak`, the
  listening page and the named-services rule as built, in a sentence or two each.
- Focused tests for new pure logic only, such as the player model's gap and queue accounting and
  the listening page's shuffling and mapping.

### Non-goals

- Any local voice, provider, `Reader` or app code. Making sound.
- Round-trip transcription of readings (see the plan's decision log), the app driver,
  `bench session`, energy, and the harness's draft results document.
- Changing how existing `transcribe`, `cleanup` or dictation figures are computed.
- xAI runs. `speak` works with any provider, but do not call xAI.

### Initial ownership

- `Sources/EchoTypeBench/` (all files) and `Tests/EchoTypeBenchTests/`.
- `docs/specs/test-harness.md`, bench section only.

### Required seams

- Consumes `VoiceService`, `SpeechStream` and `SpeechRequest` from `Provider.swift` unchanged, and
  slice 1's sampler and measurement functions
  ([cleanup/03-bench-measurement.md](../cleanup/03-bench-measurement.md)).
- Produces the `speak` command, its report fields and the listening page that workstreams 2-5
  use. Name each report field in the handoff.

### Acceptance criteria

1. `speak --provider apple` in paced mode reads all eight reading samples with Jamie
   (`com.apple.voice.premium.en-GB.Malcolm`) with no contract violations. Its report shows every
   field above, including the pause on `reading-long-selection` and one cancellation trial.
2. `--fast --repeat 3` on two short passages reports warm first audio p50/p95/n with the cold
   reading apart.
3. `report --listen` over two Apple runs (Jamie and the system voice, or Zoe if installed) writes
   a page that plays both voices per passage under shuffled labels and downloads ratings JSON
   with the label mapping. The implementation agent checks it in a browser or by inspecting the
   generated file, and says which.
4. An unknown voice, an out-of-range speed and `--candidate voice=...` each fail before a run
   directory is created, the last naming the services `--candidate` accepts.
5. `transcribe --provider local --cleanup` is unchanged. A `cleanup --provider local` run with
   `--candidate transcription=parakeet-unified` prepares both models, as `preparation.json` and
   the footprint show.
6. `report` on existing `transcribe`, `cleanup` and dictation runs still works with the same
   figures.
7. `swift test` passes.

### Targeted verification

```bash
swift build
swift test --filter EchoTypeBenchTests
swift run EchoTypeBench speak --provider apple --voice com.apple.voice.premium.en-GB.Malcolm
swift run EchoTypeBench speak --provider apple --fast --repeat 3 reading-ordinary-prose reading-agent-reply
swift run EchoTypeBench cleanup --provider local --candidate transcription=parakeet-unified --fast cleanup-clear-correction
swift run EchoTypeBench report 20261005T064539Z-local 20261005T063709Z-local
```

Then `report` each new run, and `report --listen` the two Apple runs. Adjust the syntax to what
you built and record the commands you ran.

## Implementation handoff

- Base commit: `20afdf511b42f343a206f816778884b8b05a7633`
- Outcome: `speak`, its report and `report --listen` are built and proven against Apple. A local run
  now prepares the measured service plus every `--candidate` service. All acceptance criteria are
  met; Apple's cancellation trial is never pending (see limitations).
- Files changed:
  - New `Speak.swift` (command, `PlayerModel`, records), `Listening.swift` (page and its pure
    shuffling), `Tests/EchoTypeBenchTests/SpeakTests.swift` (4 tests).
  - Edited `RunOptions.swift` (`--voice`, `--speed`, `LocalService.voice`, named-services rule,
    `requireReady` takes the services to wait for), `ContractCheck.swift` (`SpeechContractCheck`),
    `Report.swift` (`ScoredSpeakRun`), `Measurements.swift` (`ResultLog`, replacing three copies of
    the JSONL setup in `transcribe`, `cleanup` and `speak`), `RunInfo.swift` (`speech`, `utcStamp`),
    `Record.swift` (`writeWAV` takes a sample rate), `Transcribe.swift`, `Cleanup.swift`, `main.swift`.
  - `docs/specs/test-harness.md`: bench section.
- Command and report fields for later workstreams:
  - `speak --provider apple|local [--voice <id>] [--speed <x>] [--candidate <service>=<name>] [--fast]
    [--repeat <n>] [<id>...]`. Writes `speak.jsonl` (per reading: `firstAudioMs`, `gapCount`, `gapMs`,
    `synthesisSeconds`, `audioSeconds`, `realTimeFactor`, `chunks`, `largestChunkMs`, `sampleRate`,
    `pause` {`pausedAt`, `resumedAt`, `audioAfterResumeSeconds`}, `violations`, `error`,
    `repeatIndex`), `cancellation.jsonl` (per paced pass: `pending`, `latencyMs`, `audioSeconds`,
    `violations`), `<id>.wav` (first pass only), plus `preparation.json`, `sampler.json`; `run.json`
    gains `speech` {`voice`, `speed`}.
  - `report` prints per reading: first audio, gaps, synthesis, audio, real-time, chunks, largest,
    rate, after resume, violations. Totals lines: `warm first audio` and `cold first audio`; `short
    passages, warm first audio ... (target 500 ms)`; `warm real-time factor`; `gaps N totalling M ms`;
    `pause in <id>: audio after resume, footprint A to B MiB across the pause`; `cancellation latency`
    with `next() already ended in k of n trials`; then the usual preparation and machine lines.
  - `report --listen <run>...` (two or more) prints the path of `listening/<stamp>/index.html`.
  - `LocalService` now has `voice`, but `LocalService.candidates` (what `--candidate` accepts) is
    `[.transcription, .cleanup]`. Workstream 2 adds `.voice` there, adds `voice` to
    `LocalSelection`, and extends `localSelection(measuring:)` in `RunOptions.swift`. `speak` already
    measures `.voice`, so `speak --provider local` fails with "Local voice is not ready: Local read
    aloud is not available yet." until then.
- Decisions:
  - Audio after resume counts chunks that the paced loop pulled within 1 s of resuming and that
    `next()` returned in under 10 ms. The player's 500 ms queue still limits pulling, so it tops out
    near 1.5 s; more than zero means the stream generated ahead while paused.
  - The pause point is a third of the estimated audio (text length at 15 characters per second), since
    the length is unknown while streaming.
  - Synthesis time is time spent inside `next()`. Only `--fast` runs measure synthesis speed; in paced
    runs a stream that works ahead looks faster.
  - A cancellation trial where `next()` had already ended before `cancel()` is recorded as not
    pending, with no latency and no violation. Cancel waits 50 ms after starting `next()`.
  - The trial is its own file, not part of `speak.jsonl`, so reading rows stay one per reading.
  - Listening labels are shuffled per passage; the page needs at least two runs. The mapping is in the
    page's script, hidden until Save; ratings JSON holds `passage`, `label`, `run`, `provider`,
    `voice`, `rating`, `checks` and `note` for each reading.
  - Preparation now records `services` for every run, and cleanup's `requireReady` message names them.
- Verification: all passed.
  - `swift build`, `swift test` (76 tests; 23 in the bench).
  - `speak --provider apple --voice com.apple.voice.premium.en-GB.Malcolm` (`20261005T084814Z-apple`):
    8 readings, 0 violations, pause on `reading-long-selection` (1.1 s after resume), one trial.
  - `speak --provider apple --fast --repeat 3 reading-ordinary-prose reading-agent-reply`
    (`20261005T085040Z-apple`, system voice): warm first audio p50 311 / p95 321 ms (n=5), cold 854 ms.
  - `speak --provider apple --voice system` (`20261005T085044Z-apple`), then
    `report --listen 20261005T084814Z-apple 20261005T085044Z-apple`: wrote
    `listening/20261005T085321Z/index.html` with 16 WAVs. Checked by inspecting the generated file and
    `node --check` on its script; not opened in a browser.
  - Unknown voice, speed 9 and `--candidate voice=kokoro` each failed with no new run directory; the
    last names `transcription=<name> or cleanup=<name>`.
  - `cleanup --provider local --candidate transcription=parakeet-unified --fast cleanup-clear-correction`
    (`20261005T085354Z-local`): `preparation.json` lists both services, footprint peak 2637 MiB.
  - `report` on that run, `20261005T064539Z-local` and `20261005T063709Z-local` (dictation and cleanup)
    prints the same figures as before.
  - Not rerun: `transcribe --provider local --cleanup`; its service selection is unchanged by
    inspection (`services(measuring: .transcription)` adds cleanup).
- Known limitations:
  - Apple produces the whole stream ahead, so its cancellation trial is never pending and its pause
    figure does not show generation while paused (footprint 12 to 12 MiB). Apple's runs were debug builds.
  - A stuck `next()` in an ordinary read has no watchdog, unlike `transcribe`.
  - The listening page keeps ratings only in memory until Save.
- Specification drift: none.

## Independent review

- Reviewer: independent review agent (Sonnet 5.5), against the uncommitted diff on base `20afdf5`.
- Verdict: Accept. No Required findings.
- Checks run:
  - `swift build`; `swift test` (76 tests pass; 23 in `EchoTypeBenchTests`).
  - `speak --provider apple --speed 9` and `--voice nope` each fail with a clear message and
    `--candidate voice=kokoro` fails naming `transcription=<name> or cleanup=<name>`, with no new
    run directory (criterion 4). `speak --provider local` fails with "Local voice is not ready:
    Local read aloud is not available yet." and no run directory.
  - `report 20261005T084814Z-apple 20261005T064539Z-local` prints the speak fields and the
    unchanged dictation figures (criteria 1 and 6). It printed first audio, short-passage target,
    real-time factor, gaps, the pause on `reading-long-selection` and the cancellation line.
  - Read the generated listening page's source and its directory (two WAVs per passage, neutral
    names `<passage>-A.wav`). I did not open it in a browser, as the handoff says.
  - Not rerun: the long Apple `speak` runs, the `--fast --repeat 3` run, the local `cleanup`
    preparation run and `transcribe --provider local --cleanup`. I relied on the handoff's run ids
    for those and checked the code paths by reading.
- Acceptance criteria: 1 met by the recorded run and the report; 2 met by the recorded run
  (p50/p95/n and cold reported apart); 3 met by inspection; 4 met (rerun); 5 met by code
  reading and the recorded run (`services(measuring:)` plus `requireReady` over all named
  services, `preparation.services` recorded); 6 met (rerun); 7 met (rerun).
- Required findings: none.
- Optional observations:
  1. `--voice` and `--speed` are accepted by `transcribe` and `cleanup` and ignored. Evidence:
     `transcribe --provider apple --voice x` ran and created a run directory (I deleted that
     stray run, `20261005T085610Z-apple`). `RunOptions` documents them as speak-only and
     already rejects `--cleanup` and `--synthetic` in `speak`, so the same one-line `guard`
     in `transcribe` and `cleanup` would match.
  2. The pause point is estimated at 15 characters per second (`Speak.swift`,
     `Speech.charactersPerSecond`). A voice that reads a passage in less audio than that
     estimates never pauses, and the run records `pause: nil` with no warning, so the report
     simply omits the pause line. For workstream 5, treat a missing pause line on
     `reading-long-selection` as a failed measurement rather than "nothing generated".
  3. Apple's cancellation trial is never pending and its pause shows 1.1 s after resume with a
     flat footprint, so Apple gives no evidence for either measure. The handoff says so. The
     first real evidence is workstream 2's. Worth stating in `results.md` when it uses these
     fields.
  4. An ordinary read has no watchdog on `next()`. A hung local stream stalls the run until
     killed, though earlier lines are already in `speak.jsonl`. Acceptable for a spike; add one
     only if workstream 2 or 3 hits a hang.
  5. `speak` crashes on `readings.max { ... }!` if the manifest has no reading samples. The
     committed manifest has eight, so it cannot happen today.
  6. Audio-after-resume uses a 10 ms "already ready" threshold. It is a heuristic, not a
     direct measure of generation while paused. The handoff documents it; the footprint across
     the pause is the second signal.
  7. The `ResultLog` extraction replaces three copies of the JSONL setup and is a justified
     deletion. `SpeechContractCheck`, `PlayerModel` and `ListeningPassage` are small and pure,
     and the four new tests cover real logic (queue and gap accounting, pause, contract,
     shuffle mapping). No unjustified machinery found.
- Questions:
  1. `plan.md` is outside this packet's ownership, but the diff edits it (starting commit,
     start date and the status of row 1). The edits are bookkeeping that the orchestrator
     normally owns. Confirm that is intended rather than the implementer's.
  2. `--candidate` now prepares an unmeasured service for `cleanup` and `transcribe`, where it
     used to be an error ("does not apply to this command"). That matches the packet's scope.
     Confirm the older error is intentionally gone for runs such as
     `transcribe --candidate cleanup=x` without `--cleanup`, which now loads cleanup but never
     uses it other than to measure its memory.

## Resolution

- Finding dispositions: no Required findings, so no remediation pass. Optional 1 (speak-only flags
  ignored by `transcribe` and `cleanup`), 5 (empty manifest crash) and 4 (no watchdog): declined,
  no product risk in a spike bench. Optional 2 and 3: carried to workstreams 2 and 5 as conventions
  (a missing pause line is a failed measurement; Apple gives no evidence for cancellation or
  paused generation). Optional 6: documented heuristic, kept. Question 1: the `plan.md` edits are
  the orchestrator's, not the implementer's. Question 2: the old "does not apply" error is
  intentionally replaced by preparing named services, per the packet.
- Simplification/deletion pass: the implementer's `ResultLog` extraction already replaced three
  copies of the JSONL setup; the reviewer found no unjustified machinery.
- Final verification: build, bench tests and the targeted `speak`, `cleanup` and `report` runs passed in closure (see Closure review).

## Closure review

- Verdict: Accept.
- Remaining required findings: none.
- Accepted findings: none were accepted as Required and no remediation was made, so there were no
  fixes to verify. The declined dispositions hide no release-blocking defect:
  - Optional 1 (`--voice` and `--speed` ignored by `transcribe` and `cleanup`) only affects a stray
    invocation and changes no figure.
  - Optional 4 and 5 (no watchdog, empty-manifest crash) cannot occur with the committed manifest and
    risk only a stalled spike run whose earlier lines are already written.
  - Optional 2, 3 and 6 are carried to workstreams 2 and 5 as conventions, and are documented.
- Targeted verification rerun on the uncommitted diff (base `20afdf5`), all passed:
  - `swift build` completed; `swift test --filter EchoTypeBenchTests` passed (23 tests).
  - `speak --provider apple --voice com.apple.voice.premium.en-GB.Malcolm` wrote
    `20261005T090214Z-apple`: 8 readings, 0 violations, 0 gaps, pause on `reading-long-selection`
    recorded (1.3 s after resume, footprint 19 to 19 MiB), one cancellation trial (not pending, as
    the handoff states for Apple).
  - `speak --provider apple --fast --repeat 3 reading-ordinary-prose reading-agent-reply` wrote
    `20261005T090435Z-apple`: warm first audio p50 318 / p95 322 ms (n=5), cold 631 ms reported
    apart, 0 violations.
  - `cleanup --provider local --candidate transcription=parakeet-unified --fast
    cleanup-clear-correction` wrote `20261005T090507Z-local`; `preparation.json` lists `services`
    `transcription` and `cleanup` and both models loaded.
  - `report 20261005T064539Z-local 20261005T063709Z-local` prints the same dictation and cleanup
    figures as before, and `report` on the two new Apple runs prints the speak fields.
  - Not rerun: `report --listen` (page checked by the implementer and the independent reviewer
    by inspection, not in a browser) and `transcribe --provider local --cleanup`.
- Diff soundness: the uncommitted changes sit within the packet's ownership, apart from the
  orchestrator's `plan.md` bookkeeping. I found no release-blocking defect.
- New run directories from this review, kept: `20261005T090214Z-apple`, `20261005T090435Z-apple`,
  `20261005T090507Z-local`.
