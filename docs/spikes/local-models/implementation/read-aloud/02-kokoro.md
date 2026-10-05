# Workstream 2: Kokoro read aloud

Status: not started.

## Task packet

### Outcome

The local provider reads aloud with Kokoro-82M v1.0 through FluidAudio's Core ML pipeline, using
Emma and Heart. Its pinned files come from the model store. It streams bounded, short chunks as
the reader pulls them, honours speed and cancellation, and works offline. The build's selection
names Kokoro, making Unified, Qwen3 and Kokoro the reference combination. The bench measures it
with `--candidate voice=kokoro`.

### Scope

- **Runtime.** Use FluidAudio's `KokoroAne` pipeline at the pinned revision (`0b1f462`), loaded
  from the store's directories through its `directory` or `modelStore` parameters. Move the pin
  only if Kokoro needs it, and then rerun a short transcription pass to show Unified still works.
  Never call its resource downloader.
- **Manifests.** Pin the ANE English models, vocabulary, the English G2P resources the pipeline
  needs, and the `bf_emma` and `af_heart` voice packs, with upstream licences and voice terms. Find
  the exact file list by reading the pipeline's loader, not the downloader's defaults.
  - FluidAudio converts JSON voice packs to `.bin` on first use. Pin the JSON, let it convert into
    the store's directory, and record that as a runtime-created file (see conventions learned).
  - If the G2P resources live in another repository, they get their own manifest.
  - A licence conflict between a conversion and its upstream is recorded, not a stop, as slice 2
    did.
- **Voice candidate shape** in `LocalCandidates.swift`, beside the transcription and cleanup
  shapes: the name, the manifests, the voices, the speed range, the character limit and a loader.
  `LocalSelection` gains `voice`. `LocalSelection.build` names `kokoro`. `LocalProvider` builds
  `VoiceService` and voice readiness from the selected candidate through `LocalModel`, as the
  other services do. With no voice selected it keeps today's unavailable read aloud.
- **Adapter.** A `SpeechStream` that meets the plan's speech stream contract:
  - split text into short utterances at sentence boundaries, with a bound for long sentences;
  - synthesise at most one utterance ahead of what has been pulled;
  - slice audio into chunks of at most 100 ms at Kokoro's fixed rate;
  - honour the request's speed with Kokoro's native speed control;
  - on cancel, end the pending `next()` and stop before the next synthesis step;
  - run inference off the main actor, reusing the loaded models with fresh request state.
- **Utterance bound.** Choose the first utterance's length for fast first audio without losing
  sentence context. Kokoro exposes its phonemes. Compare the phonemes the bounded utterances give
  for `reading-demo-pronunciation` and `reading-past-tense-read` with the phonemes of each whole
  passage. Choose a bound that changes neither "read" nor "demos". Record the bound, the first
  audio it gives, and whether Kokoro's phonemes already reproduce the demo mistakes ("red",
  "dee-moss"). Do not add lexicon entries or word substitutions to fix them.
- **Voices and limits.** Emma first (UK, the default), then Heart. Use Kokoro's supported speed
  range, narrowed if quality breaks down at its ends, and a character limit at least as large as
  any reading sample's. Record both.
- **Bench.** `--candidate voice=kokoro` and the usage text. `speak --provider local` prepares the
  voice alone unless other services are named, per the plan's bench arguments contract.
- Tests only where they guard a real risk, such as utterance splitting and the bound on how far
  synthesis runs ahead.

### Non-goals

- Qwen3-TTS, other Kokoro voices, a custom lexicon or pronunciation fixes.
- App or Settings changes; the app receives the voice through `Provider` as it does now.
- The evaluation's runs and results.

### Initial ownership

- `Sources/EchoTypeCore/Providers/Local/` (new Kokoro files, `LocalCandidates.swift`,
  `LocalProvider.swift`), `Package.swift` and `Package.resolved` if the pin moves.
- `Sources/EchoTypeBench/RunOptions.swift`, `main.swift` usage text, and voice-specific fixes to
  `speak` if a local voice exposes a defect in it.
- `Tests/EchoTypeCoreTests/` and `Tests/EchoTypeBenchTests/` for the focused tests above.

### Required seams

- Consumes the model store, `LocalModel` and the candidate shapes as slices 1 and 2 built them
  ([transcription/01-parakeet-unified.md](../transcription/01-parakeet-unified.md) handoff), and
  workstream 1's `speak` command.
- Produces the voice candidate shape and `LocalSelection.voice` that workstream 3 extends. Name
  the shape, the voice ids and the runtime-created files in the handoff.

### Acceptance criteria

1. `speak --provider local --candidate voice=kokoro` downloads the pinned files on first use,
   reports readiness progress, and reads all eight passages with Emma in paced mode with no
   contract violations. The pause and cancellation trials pass. Repeat with `--voice af_heart` on
   two passages.
2. A `--fast` run with network access denied passes
   (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on the built binary) after the
   files are installed.
3. The speed range's ends audibly change duration: a `--fast` run of `reading-ordinary-prose` at
   each end gives audio durations that differ in the expected direction.
4. The handoff records the manifests with licences, the runtime-created files, the utterance
   bound with its phoneme comparison, and the speed range.
5. `LocalSelection.build` is Unified, Qwen3 and Kokoro. A provider with no voice selected still
   reports read aloud unavailable.
6. If the FluidAudio pin moved, a paced `transcribe --provider local dictation-short-reply`
   passes.
7. `swift test` and `swift build -c release --product EchoTypeApp` pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench speak --provider local --candidate voice=kokoro
swift run EchoTypeBench speak --provider local --candidate voice=kokoro --voice af_heart reading-ordinary-prose reading-demo-pronunciation
```

For the speed check, run `speak ... --fast reading-ordinary-prose` once with `--speed` at each
end of the range you set. For the offline run, run
`.build/debug/EchoTypeBench speak --provider local --candidate voice=kokoro --fast` under the
`sandbox-exec` profile above. Then `report` each new run.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Manifests, licences and runtime-created files: `TBD`
- Utterance bound, phoneme comparison and speed range: `TBD`
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
