# Workstream 3: Qwen3-TTS read aloud

Status: not started.

## Task packet

### Outcome

The local provider can read aloud with Qwen3-TTS-12Hz-1.7B-CustomVoice (MLX four-bit) through MLX
Audio Swift. It offers each preset plain and with one fixed style prompt. Its first audio arrives
without synthesising the whole passage, production stays bounded while the reader is paused, and
speed and cancellation behave. Cleanup still passes on the shared MLX runtime. The same
implementation also loads the 0.6B CustomVoice weights as `qwen3-tts-0.6b`. The bench measures
both with `--candidate voice=`.

### Scope

- **Dependency.** Add MLX Audio Swift (`Blaizzy/mlx-audio-swift`), pinned to a tag or commit that
  builds with Swift 6.4 and macOS 26 and resolves against the existing `mlx-swift` 0.32.3,
  `mlx-swift-lm` and `swift-transformers` pins. Its manifest asks for `mlx-swift` from 0.30.6 and
  `mlx-swift-lm` from 3.31.3, and the repository pins `mlx-swift-lm` by revision (3.32.3 plus
  nine commits). Check that SwiftPM accepts that before anything else.
  - If resolving needs a cleanup pin to move, move it. Then show cleanup still passes with a
    `cleanup --provider local --fast` run and `swift test`.
  - If no compatible combination exists without forking or vendoring, escalate with the options
    rather than fork.
  - Check that `build-app.sh` stages any new resource bundle.
- **Manifests.** Pin `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit` and
  `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-4bit` by full revision. Include every weight,
  codec, tokenizer and configuration file each needs, with licences. Load the tokenizer and codec
  from the store; Hub fallback must stay off (see conventions learned).
- **Voices.** One voice per preset the model offers, named as the model names it, plus a styled
  variant of each that adds one fixed style prompt. Use this prompt unless the model's
  documentation shows it is malformed: "Read clearly and naturally, in a calm, warm narration
  style, at an even pace." Order the voices with the English-native presets first, plain before
  styled. Record the voice ids. Aidan auditions them in workstream 4 and may change the prompt
  there.
- **Adapter.** A `SpeechStream` that meets the plan's speech stream contract. Inspect MLX Audio
  Swift's streaming producer rather than assuming its stream applies backpressure.
  - If the producer does not apply backpressure, bound it in the adapter: synthesise at most one
    bounded utterance ahead of what has been pulled, or suspend generation between steps while
    nothing is pulled.
  - Resample or slice to chunks of at most 100 ms at one fixed rate.
  - Cancel between generation steps.
  - Run inference off the main actor, with fresh request state over the loaded weights.
  - Set MLX's buffer cache limit so cached buffers do not inflate the footprint, as cleanup does.
- **Utterance bound.** If the adapter splits text, compare first audio for two bounds on
  `reading-demo-pronunciation`. Keep both WAVs for workstream 4's lead to put in front of Aidan.
  Record the bound chosen and why.
- **Speed.** Use native speed control if the model has one. Otherwise time-stretch in the adapter
  or narrow `speedRange`; record the choice. Shared playback does not change.
- **Candidates.** `qwen3-tts` and `qwen3-tts-0.6b` share one implementation and differ only in
  their manifest. `LocalSelection.build` keeps `kokoro`.
- Tests only where they guard a real risk, such as the production bound while not pulled.

### Non-goals

- Choosing the preset or prompt; Aidan does that in workstream 4.
- Kokoro changes, app or Settings changes, other Qwen3-TTS variants (VoiceDesign, Base, cloning)
  and a style prompt editor.
- The evaluation's runs and results.

### Initial ownership

- `Package.swift`, `Package.resolved`.
- `Sources/EchoTypeCore/Providers/Local/` (new Qwen3-TTS files, `LocalCandidates.swift`,
  `LocalProvider.swift` if the voice shape needs a small change), and `CleanupModel.swift` only if
  a dependency move requires it.
- `Sources/EchoTypeBench/RunOptions.swift` and `main.swift` usage text.
- `scripts/build-app.sh`, only if MLX Audio Swift ships a resource the current staging misses.
- Focused tests under `Tests/`.

### Required seams

- Consumes workstream 2's voice candidate shape, `LocalSelection.voice` and the bench's
  `--candidate voice=` (handoff in [02-kokoro.md](02-kokoro.md)), and workstream 1's `speak`.
- Produces the voice ids, style prompt and utterance-bound samples that workstream 4's gate puts
  in front of Aidan. Name them in the handoff.

### Acceptance criteria

1. `speak --provider local --candidate voice=qwen3-tts` downloads the pinned files, reports
   readiness, and reads all eight passages with the first plain voice in paced mode with no
   contract violations. The pause trial shows bounded audio after resume, and the cancellation
   trial passes. A styled voice reads two passages.
2. `qwen3-tts-0.6b` reads two passages in paced mode with no contract violations.
3. A `--fast` run of `qwen3-tts` with network access denied passes after installation.
4. Cleanup still passes: `cleanup --provider local --fast cleanup-clear-correction` completes,
   with the resolved MLX versions recorded in the handoff.
5. The speed range's ends change duration in the expected direction, or the narrowed range is
   recorded with its reason.
6. The handoff records dependency pins, manifests and licences, voice ids, the style prompt, the
   production bound and how it was verified, and the speed choice.
7. `swift test`, `swift build -c release --product EchoTypeApp` and
   `scripts/build-app.sh release .build/qwen-tts-check/EchoType.app` pass, and the bundle's
   resources include every dependency bundle.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/qwen-tts-check/EchoType.app
ls .build/qwen-tts-check/EchoType.app/Contents/Resources
swift run EchoTypeBench speak --provider local --candidate voice=qwen3-tts
swift run EchoTypeBench speak --provider local --candidate voice=qwen3-tts-0.6b reading-ordinary-prose reading-agent-reply
swift run EchoTypeBench cleanup --provider local --fast cleanup-clear-correction
```

Also run a styled voice with `--voice` on two passages, the speed check at each end of the range,
and the offline run under the `sandbox-exec` profile, as workstream 2 did. Then `report` each new
run.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Dependency pins and resolution: `TBD`
- Manifests, licences, voice ids and style prompt: `TBD`
- Production bound, utterance bound and speed choice: `TBD`
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
