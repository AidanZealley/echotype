# Workstream 1: Bench reading and listening page

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Command and report fields for later workstreams: `TBD`
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
