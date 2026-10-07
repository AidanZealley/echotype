# Local read aloud (slice 3) implementation plan

Status: approved; implementation has not started.

## Orchestration record

- Integration branch: `spike/local-models`
- Starting commit: `20afdf511b42f343a206f816778884b8b05a7633`
- Review command: `lead subagents`
- Specification approved at commit: `a8cabe1` (both specs approved 2026-10-03)
- Started: `2026-10-05`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Bench reading and listening page](01-bench-speak.md) | Slice 2 | Accepted |
| 2 | [Kokoro read aloud](02-kokoro.md) | 1 | Accepted |
| 3 | [Qwen3-TTS read aloud](03-qwen3-tts.md) | 2 | Accepted |
| 4 | [Read aloud in the signed app](04-app-read-aloud.md) | 3 | Accepted |
| 5 | [Voice evaluation and spike recommendation](05-voice-evaluation.md) | 4 | Accepted |
| Final | [Whole-feature review](final-review.md) | 1-5 | Not started |

## Why these boundaries

1. **Bench reading and listening page** builds the harness's missing `speak` command and the
   blind listening page, proven against Apple's voices before any local voice depends on them,
   as the harness spec's build order asks. It is bench-only code.
2. **Kokoro** is the reference voice and the first local `VoiceService`. It adds the voice
   candidate shape to `LocalCandidates.swift`, the build's voice selection and the bench's
   `--candidate voice=`. It reuses FluidAudio, which slice 2 already pinned.
3. **Qwen3-TTS** is a different runtime (MLX Audio Swift) whose risk is dependency
   compatibility with cleanup's MLX pins, bounded streaming and speed. Its 0.6B follow-up shares
   the implementation, so both belong here.
4. **Read aloud in the signed app** proves both voices in the installed app through Aidan's check,
   where they also audition Qwen's presets. It comes before the evaluation so any fix the gate
   forces is in the measured code, and so the evaluation uses the preset they chose.
5. **Voice evaluation and spike recommendation** runs the comparison, gathers Aidan's blind
   ratings and writes the read aloud section and the spike's overall recommendation in
   `results.md`. It changes no product code.

Sequential throughout. Workstreams 2 and 3 both edit `Package.swift`, `LocalCandidates.swift`
and the bench's `RunOptions.swift`.

## Cross-workstream contracts

- **Model store.** Unchanged from slices 1 and 2. There is one store per process
  (`LocalCandidates.store`). Each manifest has the repository, full commit revision, licence and
  every file's path, size and SHA-256, with Core ML directories listed file by file. Runtime
  downloaders (FluidAudio's, MLX Audio Swift's, Hugging Face Hub fallbacks) are never used;
  runtimes load from the store's directories. A store defect is an escalation, not a fix.
- **Selection.** `LocalSelection` gains an optional `voice`. The build's selection becomes
  `parakeet-unified`, `qwen3-4b-2507` and `kokoro`, the spec's reference combination. A nil
  `voice` keeps today's unavailable read aloud. The bench's `run.json` records the selection.
- **Voice candidate names and voices.** Each candidate supplies its own `Voice` list, speed range
  and character limit to `VoiceService`.
  - `kokoro`: Kokoro-82M v1.0 through FluidAudio's Core ML pipeline, with voices Emma (`bf_emma`)
    then Heart (`af_heart`).
  - `qwen3-tts`: Qwen3-TTS-12Hz-1.7B-CustomVoice, MLX four-bit. It has one voice per preset, plus
    a styled variant of each that adds one fixed style prompt.
  - `qwen3-tts-0.6b`: the same implementation with the 0.6B CustomVoice weights. It is measured
    only if 1.7B misses the warm first-audio target.

  A voice id is stable across builds. A stored voice the build does not offer falls back to the
  service's first voice, as `Settings.readingChoice` already does.
- **Bench arguments.** `--candidate <service>=<name>` gains `voice`. A local run prepares the
  service it measures, plus every service named with `--candidate`, and keeps them loaded for the
  run. `speak --provider local` with only `--candidate voice=` therefore prepares the voice alone,
  while naming all three measures the combination's memory. `speak` takes `--voice <id>` and
  `--speed <x>`, defaulting to the service's first voice and speed 1.
- **Speech stream behaviour.** Every local `SpeechStream` meets the contract in `Provider.swift`,
  which `speak`'s contract check enforces:
  - each chunk is mono Float32 of at most 100 ms, at one sample rate per stream;
  - the first audio arrives without synthesising the whole passage;
  - production stays at most one bounded utterance ahead of what the consumer has pulled, so a
    paused reader holds little generated audio;
  - `cancel()` makes a pending `next()` throw promptly, stops generation at the next step and is
    safe to call at any time and more than once.

  Inference runs off the main actor. Loaded weights are reused across readings, with fresh
  request state.
- **Readiness.** As for the other services: `.waiting` with download progress, then "Loading the
  voice model", then `.ready`, or `.unavailable` with the store's message on failure. Setup
  starts only for a model whose state is `.missing`.

## Ownership handoffs

- `Sources/EchoTypeBench/` belongs to workstream 1, then passes to 2 and 3 for
  `--candidate voice=`, its usage text and voice-specific fixes to `speak`.
- `Package.swift`, `Package.resolved`, `Sources/EchoTypeCore/Providers/Local/LocalCandidates.swift`
  and `LocalProvider.swift` pass from workstream 2 to 3, then to 4.
- `Sources/EchoTypeApp/`, `Sources/EchoTypeCore/Settings.swift` and `scripts/build-app.sh`
  belong to workstream 4.
- `docs/spikes/local-models/results.md` is extended by workstream 5 only. Workstream 5 also
  corrects `research.md`, and the spec's candidate tables if a candidate changes.

## Whole-feature acceptance

- Workstreams 1-5 and the final whole-feature review accepted, with both gates passed or waived
  item by item.
- `swift test` and `swift build -c release --product EchoTypeApp` pass, and both comparison app
  bundles pass `codesign --verify --deep --strict`.
- Pending outside this workflow, recorded in the completion report:
  - CI runs only when the branch is pushed. MLX Audio Swift changes its build time.
  - First model load after a reboot or OS update (an evicted Core ML cache) is not measured.
  - Energy (`powermetrics` needs root) is not measured.
  - Nested dependency bundles keep SwiftPM's ad hoc signatures, and Developer ID notarisation
    of them is untested (carried from slice 1).
  - Boosted Unified's 44 s installed load (`20261005T071726Z-local`) is unexplained; it is
    productionising work, not this slice's.
  - Workstream 4's stop-then-quit check of the Qwen comparison app (ET-R3-01's teardown crash)
    was not observed: Aidan was still using `.build/voice-check/EchoType.app` at acceptance. Once
    they have quit it, check `~/Library/Logs/DiagnosticReports` for an `EchoTypeApp` crash, then
    delete `.build/voice-check/`. Never quit it for them.
  - Productionising, including removing losing candidates and the comparison selection
    machinery, is separate work the spike's recommendation scopes.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| Signed-app check and Qwen preset audition | Workstream 4 | After closure, before acceptance | Passed with waiver (item 11's early ending) | `cf2f094` + R1 diff `1a0f90f6…1d84` | Every checklist item has Aidan's pass or waiver, and they have named the Qwen preset and style verdict |
| Blind listening | Workstream 5 | After the paced runs, before results | Passed (ET-R5-01; step 5 run, not waived) | Listening page `listening/20261007T105149Z` | Aidan's saved ratings file and notes on every passage they rated |

## Escalations

None open.

## Conventions learned

Carried from slices 1 and 2:

- `Readiness.check` calls `ModelStore.start` only when the state is `.missing`. `start` restarts a
  failed model and every state change yields on `changes()`, so starting a failed one would loop
  while offline. A failed model stays failed until relaunch. Hold one shared store per process.
- Derive paired figures (cold versus warm, counted versus excluded) from one filtered list in one
  pure function, not from two differently filtered reads.
- A runtime that hard-codes a cache path is reached by a symlink to the store's verified
  directory. Write it only when missing or stale, tolerate a concurrent writer and never write
  over a real folder. Never rewrite another tool's folder on every load.
- Runtime downloader switches may leave Hugging Face Hub fallback enabled. Load pinned local
  tokenizers and resources explicitly and propagate local errors, so failed preparation cannot
  fetch outside the store.
- A runtime that writes derived files into a model directory on first use, such as a converted
  voice pack, leaves the pinned files verified. Record what it writes and include it in disk
  figures.
- Cite the runs made on the final source: a run whose `run.json` says `sourceDirty` before a
  later edit is not evidence for the finished code; rerun it.
- In `results.md`, put a run id on every figure, bullet and table row, including derived ones,
  and scope runtime claims to what was measured. Derive "warm" figures with the cold request
  excluded, as `report` does.
- Apple's `speak` run proves the harness, not cancellation or paused generation: it produces the
  whole stream ahead, so its cancellation trial is never pending. Treat a missing pause line on
  `reading-long-selection` (pause estimated at 15 characters per second) as a failed measurement.
- Model preparation can take minutes before readiness. Do not call a Loading state a hang without
  runtime evidence. Use `/usr/bin/log` on this Mac to avoid zsh's `log` builtin.
- Bench measurement code records a stream's thrown error with the contract check; never swallow it with `try?`, or a failure reads as a clean end.
- A runtime whose cancelled generation cannot be awaited (MLX Audio Swift's Qwen3-TTS) keeps running MLX work after `cancel()`: it can overlap the next reading on the shared model, and crashes MLX's teardown if the process exits meanwhile (ET-R3-01). The bench only waits 1 s after its cancellation trial, a heuristic; the app has no such wait. The signed-app check must stop a Qwen reading and immediately start another, several times, then stop one and quit at once, checking the app log for MLX errors and `~/Library/Logs/DiagnosticReports` for a crash. Check every bench command's exit status, not only its run directory.
- A runtime that ends generation silently at an internal length cap (MLX Audio Swift's Qwen3-TTS: `max(75, 6 × text tokens)` codec steps per utterance) truncates speech without an error. When judging or measuring such a voice, compare each utterance's step count with the cap and mark readings that end at it (ET-R4-02).
- Before removing an answered escalation entry, mark the gate's record and the plan's gate row with the outcome, copy the user's answer into the record, and re-cite anything that cites the entry to the record, so no citation dangles.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-05 | No xAI read-aloud baseline. Aidan judges the local voices against their own experience of xAI's voice; the results say so beside every comparison with xAI. Drift from the spec's completion criterion that voice preference is judged against actual xAI samples. | Aidan uses xAI's voice daily and knows how it reads; a paid run adds nothing to their judgement. | Aidan | 5 |
| 2026-10-05 | Apple's baseline is its premium UK voice, Jamie (`com.apple.voice.premium.en-GB.Malcolm`), installed on this Mac, plus Zoe if installed. | The spec asks for an installed premium UK voice. | Planning agent | 1, 5 |
| 2026-10-05 | Latency figures come from release builds, on the machine as it is, with load average recorded. | Carried from slice 2. | Aidan | 5 |
| 2026-10-05 | `speak` models a real-time player instead of playing sound. It starts on the first chunk, queues at most 500 ms as `SpeechPlayer` does and drains in real time. First audible speech is the first chunk's arrival under that player. Device output latency and the app's selection capture and readiness check are the same for every provider and are not measured. | The bench must not make sound on Aidan's machine, and the app driver does not exist. The provider-dependent part of first audible speech is what distinguishes the candidates. | Planning agent | 1, 5 |
| 2026-10-05 | Qwen's presets are auditioned in the signed voice comparison app, during workstream 4's gate, rather than in a separate gate. The candidate offers every preset plain and styled; Aidan picks the preset the evaluation uses. | One stop for Aidan instead of two, and the app is where they would choose a voice. | Planning agent | 3, 4, 5 |
| 2026-10-05 | The spec's fixed style-prompt trial is a styled variant of each Qwen voice, not a separate candidate or build. | It shares the model and runtime; a voice id is enough to compare plain and styled. | Planning agent | 3, 5 |
| 2026-10-05 | `qwen3-tts-0.6b` is built with 1.7B but measured only if 1.7B misses the warm first-audio target, per the spec's conditional follow-up. | It is a manifest on the same implementation. Building it in workstream 3 keeps workstream 5 free of product code. | Planning agent | 3, 5 |
| 2026-10-05 | Read-aloud round-trip transcription scoring is not built. Skipped, repeated or invented words are caught by Aidan's listening and noted in their ratings. | Eight passages are few enough to hear in full; the round trip cannot hear pronunciation, which decides the comparison. | Planning agent | 1, 5 |
| 2026-10-05 | The app never reads and dictates at once: starting dictation stops a reading. "Read aloud alongside dictation" is all three models loaded and used in turn, measured by the bench with every service prepared and checked in the signed app. | That is the concurrency the app permits. | Planning agent | 1, 4, 5 |
| 2026-10-05 | `speak`'s cancellation trial plays about 2 s of audio paced, then pulls unpaced until a `next()` waits, and cancels there. Drift from the harness spec and `01-bench-speak.md`, which say it cancels after about 2 s of audio. A stream that has everything ready first (Apple, short passages) ends and is recorded as not pending. | A stream that stays one utterance ahead never has a `next()` pending at 2 s of paced audio, so the old trial could not measure local cancellation. | Workstream 2 lead | 3, 5 |
| 2026-10-05 | Kokoro's Emma voice pack is converted from the pinned JSON by our loader with FluidAudio's converter, not by FluidAudio itself. Drift from the packet's "let it convert". | FluidAudio's `ensureVoicePack` fetches the JSON over the network and never reads a local one. | Workstream 2 lead | 3 |
| 2026-10-05 | MLX Swift moved from 0.32.3 to 0.31.6 and MLX Swift LM from `5e46681b` (3.32.3 plus nine) to 3.31.4. Drift from the packet's "resolve against the existing pins" and from the revision research verified for cleanup. Cleanup's figures in `results.md` were measured on the old pins; only single exactness samples (`20261005T203204Z-local`, `20261005T212053Z-local`) have run on the new ones. Workstream 5 remeasures cleanup in its combination runs and scopes the old figures. | MLX Audio Swift calls `makePromptCache` without `try`, which MLX Swift LM 3.32 made throwing, so it does not compile on the old pins; 3.31.4 needs MLX Swift 0.31. No fork. | Workstream 3 lead | 5 |
| 2026-10-05 | Qwen3-TTS reads at speed 1 only (`speedRange` `1...1`), and `qwen3-tts-0.6b` offers plain presets only. | The model has no native speed control and time-stretching would change the voice being judged; upstream ignores instructions on 0.6B. | Workstream 3 lead | 4, 5 |
| 2026-10-05 | ET-R3-01: Qwen3-TTS's cancelled generation stays unawaitable for the spike. The bench's `speak` waits 1 s after its cancellation trial so the next reading and process exit start after it settles; the app has no such wait. No fork of MLX Audio Swift. Fixing it (a fork exposing awaitable streaming, or another runtime) is a blocker before productionising Qwen. Drift from the plan's speech stream contract, whose `cancel()` stops generation but cannot be awaited here. | MLX Audio Swift runs each generation in an unstructured task it cancels but never exposes; Aidan wants the minimal option that lets Qwen be evaluated, and will decide on a proper fix only if Qwen is worth productionising. | Aidan | 4, 5 |
| 2026-10-06 | ET-R4-02: no patch to MLX Audio Swift. Qwen3-TTS readings may end early, because the runtime silently caps each utterance at `max(75, 6 × text tokens)` codec steps (0.48 s of speech per token), worst with slow presets. Item 11's early ending is waived for the spike. The cap and ET-R3-01's unawaitable cancellation are together fork work that blocks productionising Qwen. Workstream 5 flags readings that end at the cap and marks or excludes them in the listening and results. Drift from the spec's complete-reading expectation and the gate's item 11. | The fix needs a fork; Aidan wants both fork fixes deferred until Qwen is worth productionising. Evidence: run `20261006T132708Z-local`. | Aidan | 5, Final |
| 2026-10-06 | The evaluation's Qwen voice is plain Ryan (`ryan`). The styled variant sounded no different, so the style prompt is not evaluated further. Every preset was "super impressive" but very non-deterministic between readings (Uncle Fu's accent changed), while Kokoro is the same every time: a finding for workstream 5, not a defect. A voice prompt field and "a couple of predictable voices plus an open prompt" are productionising scope for the spike's recommendation, not built here. | Aidan's gate answers (ET-R4-01, ET-R4-02). | Aidan | 5 |
| 2026-10-07 | ET-R5-01: blind listening passed. Aidan preferred Kokoro Heart and Qwen3-TTS Ryan; Ryan is the most realistic but unpredictable and needs more control before productionising. `results.md` recommends Kokoro Heart over the build's default Emma and one fixed set, opt-in, with xAI the default, as a proposal; the build selection is unchanged. Their notes are in `05-voice-evaluation.md`, External validation. | Aidan's ratings and notes; figures in `results.md`. | Aidan (ratings), workstream 5 lead (recommendation) | Final |
