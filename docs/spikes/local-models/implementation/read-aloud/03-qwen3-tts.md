# Workstream 3: Qwen3-TTS read aloud

Status: accepted.

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

- Base commit: `cdec843`
- Outcome: Local reads aloud with Qwen3-TTS-12Hz-1.7B-CustomVoice (MLX four-bit) through MLX Audio
  Swift as `qwen3-tts`, and with the 0.6B CustomVoice weights as `qwen3-tts-0.6b`, one
  implementation with two manifests. Both load only from the store. `LocalSelection.build` keeps
  `kokoro`. Every acceptance criterion is met on release builds of the final source; the cleanup
  pins moved (see below) and cleanup still passes.
- Files changed:
  - `Package.swift`, `Package.resolved`: MLX Audio Swift added (product `MLXAudioTTS`); MLX Swift and
    MLX Swift LM moved.
  - New in `Sources/EchoTypeCore/Providers/Local/`: `QwenTTSManifests.swift` (`large`, `small`),
    `QwenTTSModel.swift` (load and warm, voices, style prompt, `speak`), `QwenTTSSpeech.swift` (the
    bounded `SpeechStream` and the utterance grouping).
  - `LocalCandidates.swift`: `qwen3TTS`, `qwen3TTSSmall` from one `qwenTTS(name:manifest:styled:)`;
    `voice` is `[kokoro, qwen3TTS, qwen3TTSSmall]`. `LocalProvider.swift` unchanged.
  - `CleanupModel.swift`: three call-site changes for MLX Swift LM 3.31.4
    (`GenerateParameters(prefillStepSize:)`, non-throwing `newCache`, no `.rejectedToolCall`).
  - `Sources/EchoTypeBench/main.swift`: usage lists the two new voice candidates. `RunOptions.swift`
    unchanged (it already takes any name in `LocalCandidates.voice`). `Speak.swift` (remediation):
    the cancellation trial waits 1 s before returning (see Known limitations).
  - Tests: new `QwenTTSSpeechTests.swift` (read-ahead bound including an utterance with no audio;
    cancel ends a waiting pull and stops generation).
  - `scripts/build-app.sh` unchanged: it already copies every `*.bundle`, and MLX Audio Swift's
    library targets ship no resource bundle (only a test target has resources).
- Dependency pins and resolution:
  - `Blaizzy/mlx-audio-swift` at revision `bf14ae0c26e4e85553dd989571cae29d70fa6735` (3 Sep 2026,
    `v0.1.3` plus 20). The newest tag, `v0.1.3`, is from July. `origin/main` (`8d86630`, 30 Sep)
    has identical `Models/Qwen3TTS/` sources. Its manifest asks for `mlx-swift` from 0.30.6,
    `mlx-swift-lm` from 3.31.3, `swift-transformers` from 1.1.6 and `swift-huggingface` from 0.8.1
    (already resolved at the base commit; MLX Audio Swift uses it only in its downloader, which we
    never call).
  - Resolved now: `mlx-swift` 0.31.6 (`0bb916c6`), `mlx-swift-lm` 3.31.4 (`bd4b7434`),
    `swift-transformers` 1.3.4 unchanged, FluidAudio and WhisperKit unchanged.
  - Why the old pins could not stay: with `mlx-swift` 0.32.3 and `mlx-swift-lm` at
    `5e46681b` (3.32.3 plus nine) SwiftPM resolves, but `MLXAudioTTS` does not compile: MLX Swift LM
    3.32 made `makePromptCache` throwing and `Models/Marvis/CSMModel.swift` lines 462, 463 and 501
    call it without `try` (checked in a scratch copy, `swift build --target MLXAudioTTS`; the same
    lines are on `origin/main`). The newest earlier MLX Swift LM, 3.31.4, requires `mlx-swift`
    `.upToNextMinor(from: "0.31.4")`, so MLX Swift moves to 0.31.6. No fork or vendoring.
  - Cleanup on the moved pins: `20261005T212053Z-local` (`cleanup --provider local --fast
    cleanup-clear-correction`): exact, 0 fallbacks. `swift test` passes.
- Manifests, licences, voice ids and style prompt:
  - `QwenTTSManifests.large`: `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit` at
    `f35faf19b0cc2160865af64ecf0f22f83d335135`, 7 files, 2,311,984,361 bytes. `.small`:
    `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-4bit` at
    `08c72cad5e2fd0f41730c8bd1f28149585e46361`, 7 files, 1,693,530,022 bytes. Each is `config.json`,
    `model.safetensors`, `tokenizer_config.json`, `vocab.json`, `merges.txt`,
    `speech_tokenizer/config.json` and `speech_tokenizer/model.safetensors` (the codec, identical in
    both). Revisions are each repository's current `sha`; sizes and LFS hashes match the Hub tree
    API. Left out, because `fromModelDirectory` never reads them: `generation_config.json` (its
    values are copied into `QwenTTSModel.parameters`), `model.safetensors.index.json`,
    `preprocessor_config.json`, `speech_tokenizer/configuration.json` and
    `speech_tokenizer/preprocessor_config.json`.
  - Licence Apache-2.0: both conversions' cards and the upstream `Qwen/Qwen3-TTS-12Hz-*-CustomVoice`
    cards.
  - Runtime-created: `<model dir>/tokenizer.json` (4,762,740 bytes), written by MLX Audio Swift on
    first load from `vocab.json`, `merges.txt` and `tokenizer_config.json`, then read on later loads.
    Pinned files are untouched. Installed sizes 2.2 GB (1.7B) and 1.6 GB (0.6B).
  - Hub fallback stays off: `Qwen3TTSModel.fromModelDirectory` is called with the store directory
    (never `fromPretrained`). It loads the tokenizer with `AutoTokenizer.from(modelFolder:)`, and in
    swift-transformers 1.3.4 that reads only local files (`LanguageModelConfigurationFromHub.loadConfig(modelFolder:)`
    makes no network call). It swallows a tokenizer failure, so `QwenTTSModel.load`'s warm-up
    generation throws `modelNotInitialized` instead and readiness fails. The codec loads from
    `speech_tokenizer/`. The deny-network run below confirms it.
  - Voice ids, in order (`qwen3-tts`): `ryan`, `ryan-styled`, `aiden`, `aiden-styled`, `vivian`,
    `vivian-styled`, `serena`, `serena-styled`, `uncle_fu`, `uncle_fu-styled`, `dylan`,
    `dylan-styled`, `eric`, `eric-styled`, `ono_anna`, `ono_anna-styled`, `sohee`, `sohee-styled`.
    Names are the presets as the model card names them (`Ryan`, `Uncle_Fu`, ...), styled ones
    "Ryan, styled". English-native first (Ryan, Aiden), then the card's order. `qwen3-tts-0.6b`
    offers the nine plain ids only: upstream `qwen_tts` drops the instruction for the 0.6B model
    (`if self.model.tts_model_size in "0b6": instruct = None`) and its README marks 0.6B-CustomVoice
    without instruction control, although its Hub card says otherwise. A styled id on 0.6B falls
    back to the first voice.
  - Style prompt, unchanged from the packet: "Read clearly and naturally, in a calm, warm narration
    style, at an even pace." It is valid for CustomVoice: upstream takes any natural-language
    `instruct` and wraps it as `<|im_start|>user\n…<|im_end|>\n`, as MLX Audio Swift does. MLX Audio
    Swift takes it in the `voice` string as "speaker, instruction", splitting at the first comma
    only, so the prompt's own commas survive. Styled voices pass `"<preset>, <prompt>"`.
- Production bound, utterance bound and speed choice:
  - MLX Audio Swift's `generateStream` applies no backpressure: it generates each call to the end in
    its own task into an unbounded `AsyncThrowingStream`, checking cancellation at the top of every
    codec step, and cancels that task when the stream is terminated. `QwenTTSSpeech` therefore
    starts utterance n+1 only when utterance n has finished generating and the reader has pulled its
    first chunk (or drained everything, if it had none). Production stays at most one utterance
    ahead; within an utterance, audio streams every 0.32 s of speech (four codec steps) and is
    sliced into 100 ms chunks at 24 kHz. Verified by `QwenTTSSpeechTests` and by the paced pause in
    `20261005T211446Z-local` (1.1 s of audio after resume, footprint 2479 to 2477 MiB across it).
  - Utterances join Kokoro's sentence splits up to 250 Unicode scalars. Bound comparison on
    `reading-demo-pronunciation` (198 characters, two sentences), `--fast --repeat 3`, Ryan:
    - 100 (one sentence per utterance): `20261005T201243Z-local`, made with the constant temporarily
      at 100, not the final source: cold 227 ms, warm 227 and 230 ms.
    - 250 (the passage in one utterance), final source: `20261005T202954Z-local`: cold 219 ms, warm
      222 and 324 ms.
    - Both WAVs are kept: `runs/<id>/reading-demo-pronunciation.wav` in each (the third repeat).
    - Chosen: 250. First audio does not depend on the bound, because generation streams within an
      utterance, so a longer bound only means fewer joins (Qwen generates prosody across a whole
      utterance) at the cost of at most about 15 to 18 s of audio generated ahead while paused.
  - Speed: Qwen3-TTS has no native speed control (neither upstream `generate_custom_voice` nor MLX
    Audio Swift takes one). `speedRange` is narrowed to `1...1` rather than time-stretched, because
    stretching would change the voice being judged. Settings already hides the slider for an empty
    range (`SettingsView` line 208); the bench rejects `--speed 0.5` and `--speed 2` ("outside
    Local's range 1.0...1.0", no run created). Character limit 60,000, as Kokoro.
- Decisions:
  - ET-R3-01 (Aidan, 2026-10-05): the minimal option. Qwen's cancelled generation stays
    unawaitable for the spike; the bench settles 1 s after its cancellation trial, the app has no
    such wait, and fixing it is a blocker before productionising Qwen. No fork.
  - Generation parameters are the conversions' `generation_config.json` (temperature 0.9, top-p 1,
    top-k 50, repetition penalty 1.05); `maxTokens` 4096, which MLX Audio Swift further caps at six
    codec steps per text token. Sampling is random, so each reading of a passage differs (the three
    demo repeats above are 13.8, 15.3 and 17.8 s long).
  - `language: "English"` for every reading, as the app reads English.
  - `Memory.cacheLimit` is set to 64 MiB on load, the same process-wide value cleanup sets.
  - The 1.7B and 0.6B models share the 682 MB codec file but are separate store directories; the
    store has no cross-manifest sharing and adding it is out of scope.
- Verification: passed after the ET-R3-01 remediation, on the final source (last source edit
  `QwenTTSSpeech.swift` at 20:56:51Z; the release `EchoTypeBench` was rebuilt at 21:14Z and every
  cited run below started after it, except the first download, which is kept for its download
  figures only; `sourceDirty` is true in each only because the work is uncommitted). Every command's
  exit status was checked: each exited 0, and no EchoTypeBench crash report appeared in
  `~/Library/Logs/DiagnosticReports`. Before the remediation every Qwen `speak` run exited with
  SIGSEGV (139) at process exit (Closure review); the earlier "passed" did not check exit status.
  Bench runs are release builds (`.build/release/EchoTypeBench`), per the plan's decision on latency
  figures; each is `report`ed. The machine was busy: load average median 26 to 68 across these
  runs, from other processes.
  - `swift build`; `swift test` (core 145, bench 23, app 76); `swift build -c release --product
    EchoTypeApp`; `scripts/build-app.sh release .build/qwen-tts-check/EchoType.app`, whose
    `Contents/Resources` holds `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`,
    `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle`, `swift-transformers_Hub.bundle` (every
    dependency bundle the release build produces).
  - `20261005T202552Z-local` (before the remediation, exit 139 after its run directory was
    complete): first download and paced Ryan, all 8 passages. The installed 1.7B directory was
    moved aside first (and deleted after this run verified). Preparation 74.5 s (downloading
    68.4 s, "Loading the voice model" 6.0 s). Cited for the download only; not repeated.
  - `20261005T211446Z-local`: paced Ryan, all 8 passages, exit 0. 0 violations, 0 gaps. Warm first
    audio p50 288 / p95 525 ms (short passages p50 268 / p95 284 ms), cold 236 ms; pause 1.1 s of
    audio after resume, footprint 2479 to 2477 MiB across it; cancellation trial pending, 0 ms,
    0 violations. Preparation 2.4 s (loading). Footprint peak 2953 MiB, ready 2527 MiB.
  - `20261005T211844Z-local`: paced `ryan-styled`, `reading-ordinary-prose` and
    `reading-demo-pronunciation`, exit 0, 0 violations, 0 gaps, first audio 491 and 327 ms, trial
    pending 0 ms.
  - `20261005T211803Z-local`: paced `qwen3-tts-0.6b` (Ryan), `reading-ordinary-prose` and
    `reading-agent-reply`, exit 0, 0 violations, 0 gaps, first audio 390 and 205 ms, trial pending
    0 ms. The 0.6B files were already installed (downloaded and verified by the store at
    13:42-13:46Z in the earlier, uncited runs); this run measured loading only (4.0 s).
  - `20261005T211916Z-local`: `--fast`, all 8, under `sandbox-exec -p '(version 1)(allow
    default)(deny network*)'`, exit 0: 0 violations, warm first audio p50 236 / p95 442 ms, warm
    real-time factor p50 0.54 / p95 0.57 (synthesis about 1.85 times real time).
  - `--speed 0.5` is rejected ("outside Local's range 1.0...1.0", exit 1, no run created).
  - `20261005T202954Z-local` and `20261005T201243Z-local`: the bound comparison above (`--fast`, so
    no cancellation trial; unaffected by the remediation).
  - `20261005T212053Z-local`: cleanup, exact, 0 fallbacks, exit 0.
  - Superseded, not cited: `20261005T202849Z-local`, `20261005T202920Z-local`,
    `20261005T203021Z-local`, `20261005T203204Z-local` (pre-remediation; the Qwen ones exited 139),
    the closure's `20261005T204410Z-local` and `20261005T204520Z-local`, and the interrupted
    remediation's `20261005T210046Z-local` to `20261005T210651Z-local`. Earlier runs
    `20261005T132408Z` to `20261005T134645Z` predate the final source.
- Known limitations:
  - Eric and Dylan read English in a Chinese dialect mode: MLX Audio Swift applies a preset's
    `spk_is_dialect` language override whatever the requested language, while upstream applies it
    only for Chinese or auto. Not fixable without forking; Aidan hears it in workstream 4.
  - Blocker to fix before productionising Qwen (ET-R3-01): a cancelled reading's generation cannot
    be awaited. MLX Audio Swift runs it in its own unstructured task, cancelled at the next codec
    step, with no handle to await. Until it settles it can overlap the next reading on the shared
    model (resetting its codec decoder's streaming state, two MLX evaluations at once), and it
    crashes MLX's static teardown with SIGSEGV if the process exits meanwhile. Closure saw the
    crash on every Qwen `speak` run. Aidan chose the minimal mitigation for the spike: `speak`
    waits 1 s after each cancellation trial (its only cancel of a running generation), so the next
    pass and the exit start after it has settled. That is a heuristic, not a fix; the app has no
    such wait and may still crash on stop-then-read or on quit shortly after stopping a reading.
    The exact fix needs a fork that exposes generation in the caller's task, or non-streaming
    generation that ties first audio to utterance length. Workstream 4's signed-app check
    exercises stop-then-read and stop-then-quit (plan, conventions learned).
  - MLX Audio Swift prints to stdout on every load and utterance (`[Qwen3TTS] CustomVoice: speaker
    ...`); harmless, but noisy in the bench and the app's stdout.
  - Footprint is large: ready about 2.3 GB (0.6B) to 2.5 to 3.6 GB (1.7B) with only the voice
    loaded; the combination's worst case is for workstream 5.
  - Synthesis is about 1.85 times real time on this M1 Pro under load, so headroom is thin; a busier
    machine could produce gaps in long passages. None were seen.
  - Paced runs' "synthesis" and real-time factor (0.03 to 0.13) are far below the `--fast` figures
    (0.53 to 0.56), because a paced reader pulls at playback pace; use `--fast` runs for throughput.
- Specification drift:
  - The packet named the existing pins as the ones to resolve against; they moved (MLX Swift 0.32.3
    to 0.31.6, MLX Swift LM `5e46681b` to 3.31.4), as the packet allows, for the compile failure
    above. The research's verified-against-Swift-6.4 revision for cleanup is no longer the one used.
  - `qwen3-tts-0.6b` offers no styled voices, since upstream ignores instructions on 0.6B.

## Independent review

- Reviewer: fresh independent review agent (Claude Code), against base `cdec843` and the
  uncommitted diff including the four untracked Qwen files. `docs/specs/app-testing.md` and
  `docs/specs/local-models-productionization.md` are the user's and were not reviewed.
- Verdict: accept. No Required findings; every acceptance criterion is met.
- Checks run by the reviewer:
  - `swift build` passed; `swift test` passed (core 145 including `QwenTTSSpeechTests`, bench 23,
    app 76); `swift build -c release --product EchoTypeApp` passed;
    `scripts/build-app.sh release .build/qwen-tts-check/EchoType.app` passed, and
    `Contents/Resources` holds `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`,
    `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle` and `swift-transformers_Hub.bundle`,
    the same four bundles as `.build/release/*.bundle`. MLX Audio Swift's only `resources:` entry is
    its test target's.
  - `report` on every cited run: the figures in the handoff match. Each run's `run.json` arguments
    match its description and each started after the last source edit (`QwenTTSModel.swift`,
    20:20:51Z); the release `EchoTypeBench` binary was built at 20:24Z, after it.
  - New `20261005T203820Z-local`: `--fast`, `aiden-styled`, `reading-past-tense-read`, under the
    `(deny network*)` `sandbox-exec` profile: loads from the store and reads, 276 ms first audio,
    0 violations.
  - `speak ... --speed 0.5` is rejected ("outside Local's range 1.0...1.0").
  - Both store directories exist with every manifest file at its pinned size (the store verified
    their SHA-256 on download), plus the runtime-written `tokenizer.json`.
- Acceptance criteria:
  1. Met. `20261005T202552Z-local`: downloaded (68.4 s), "Loading the voice model", ready; all 8
     passages paced with `ryan`, 0 violations, 0 gaps; pause 1.2 s of audio after resume; the
     cancellation trial was pending and ended in 0 ms. `20261005T202849Z-local`: `ryan-styled`, two
     passages, 0 violations.
  2. Met. `20261005T202920Z-local`: `qwen3-tts-0.6b`, two passages paced, 0 violations.
  3. Met. `20261005T203021Z-local` (all 8, `--fast`), confirmed independently by
     `20261005T203820Z-local` above. Source check agrees: `fromModelDirectory` is given the store
     directory, `AutoTokenizer.from(modelFolder:)` in swift-transformers 1.3.4 reads only local
     files (its fallback tokenizer config is bundled), and a tokenizer failure surfaces as
     `modelNotInitialized` from the warm-up.
  4. Met. `20261005T203204Z-local` exact, 0 fallbacks; MLX Swift 0.31.6 and MLX Swift LM 3.31.4
     recorded. The three `CleanupModel.swift` changes are API renames with the same meaning.
  5. Met by narrowing to `1...1`, with the reason recorded. Settings hides the slider for a
     zero-width range (`SettingsView.swift` line 208) and `Settings.readingChoice` resets a stored
     speed outside it to 1.
  6. Met, with one inaccuracy (Optional 1).
  7. Met, as above.
- Boundaries and ownership: changes stay inside the packet's ownership. `LocalProvider.swift`,
  `RunOptions.swift` and `build-app.sh` are untouched; `CleanupModel.swift` changes only for the
  dependency move; `LocalSelection.build` keeps `kokoro`. Reusing `KokoroSpeech.utterances` as the
  sentence splitter is reasonable reuse, not a cross-candidate coupling worth a new type.
- Correctness, lifecycle and cancellation (`QwenTTSSpeech`): the producer waits under the same lock
  the reader updates, so no wake-up is lost; `reached` includes `ending`, so cancel always releases a
  waiting producer; cancelling the production task terminates MLX Audio Swift's
  `AsyncThrowingStream`, whose `onTermination` cancels its generation task, which checks
  cancellation every codec step. Repeated `cancel()` is idempotent; a cancelled or failed stream
  throws on every later pull; an utterance with no audio does not stall production (tested).
  The production task retains the stream until it ends, but `Reader.run` always cancels its stream,
  so no reading leaks. Production is eager (the first utterance starts in `init`), unlike Kokoro's
  first-pull start; that is within the one-utterance bound and helps first audio. The read-ahead
  while paused is the rest of the current utterance plus the next one, the same semantics as
  Kokoro's accepted bound. Inference runs off the main actor (`produce` and MLX Audio Swift's
  generation task are nonisolated; the package sets no default isolation).
- Complexity: proportionate. One implementation, two manifests from one helper, one bounded stream
  with a two-continuation handshake that the absent backpressure requires, two tests that guard the
  real risks (the read-ahead bound and cancel ending a waiting pull).
- Required findings: none.
- Optional observations:
  1. The handoff calls `swift-huggingface` a new transitive dependency. It is already in
     `Package.resolved` at `cdec843`; the pin diff adds only `mlx-audio-swift` and moves
     `mlx-swift` and `mlx-swift-lm`. Correct the sentence.
  2. Cleanup's latency figures in `results.md` were measured on MLX Swift 0.32.3 and MLX Swift LM
     `5e46681b`. Only one exactness sample has run on the moved pins. Workstream 5's combination
     runs will remeasure cleanup on 0.31.6 / 3.31.4; the lead may want the pin move in the plan's
     drift log (the handoff already records it as drift) so workstream 5 scopes the old figures.
  3. On `qwen3-tts-0.6b` a stored styled id falls back to `ryan`, not to the same preset plain. If
     Aidan picks, say, `aiden-styled` in workstream 4 and 0.6B is later measured, it reads as Ryan.
     Mapping `<preset>-styled` to `<preset>` in `prompt(for:)` when styled voices are not offered
     is a one-line fix; alternatively workstream 5 passes `--voice` explicitly.
  4. MLX Audio Swift's stdout prints are harmless: the `--mcp` process relays speech to the main
     app (`MCPProcess.deliver`) and never loads a voice, so they cannot corrupt the MCP channel.
- Questions:
  1. Overlap after cancel-then-read. MLX Audio Swift's generation task resets the shared codec
     decoder's streaming state on entry and in a `defer` on exit (`Qwen3TTS.swift` around lines
     400-407), and nothing can await a cancelled task. A reading started within one codec step of
     cancelling another can have its decoder state reset mid-stream by the old task's `defer`, and
     runs two MLX evaluations concurrently on one model. The handoff names this; the bench never
     exercises it (each run's cancellation trial comes last). The adapter cannot close it without
     forking or switching to non-streaming per-utterance `generate`, which would tie first audio to
     utterance length. Recommendation: accept as a known limitation and make "stop a Qwen reading
     and immediately start another, several times" an explicit item in workstream 4's signed-app
     checklist, with the app log checked for MLX errors.

## Resolution

Lead triage. Recovery: the row was in Implementing when the previous lead and its implementation
agent were stopped by a usage limit. The uncommitted work sat on base `cdec843`, stayed inside the
packet's ownership and built, so a fresh implementation agent reused and finished it and reran
every cited bench run on the final source. No remediation pass was needed.

- Finding dispositions:
  - Required: none.
  - Optional 1 (`swift-huggingface` called new): accepted; the lead corrected the handoff sentence.
  - Optional 2 (cleanup figures predate the pin move): accepted as drift; the plan's decision and
    drift log records the move so workstream 5 scopes the old cleanup figures and remeasures.
  - Optional 3 (styled id on 0.6B falls back to Ryan): not taken. It matches the plan's contract
    (a voice the build does not offer falls back to the first voice), and workstream 5 passes
    `--voice` explicitly if it measures 0.6B.
  - Optional 4: no action.
  - Question 1 (cancel-then-read overlap on the shared model): accepted as a known limitation, not
    Required. Closing it needs a fork of MLX Audio Swift or non-streaming generation, which would
    tie first audio to utterance length and break the packet's first-audio outcome. The window is
    one codec step. The plan's conventions learned now tells workstream 4 to make "stop a Qwen
    reading and immediately start another, several times, with the app log checked for MLX errors"
    an explicit item of its signed-app check.
- Simplification/deletion pass: done by the implementation agent; the reviewer found the design
  proportionate. Nothing further removed.
- Final verification: the implementation agent's and the reviewer's runs on the final source, as
  recorded above; no source changed after review.
- After closure: closure showed Question 1 is a real release-blocking defect, not a tolerable
  limitation. Every Qwen `speak` run exits with SIGSEGV when `main` returns while the cancelled
  generation still runs MLX work, so the packet's `speak` verification fails; the lead confirmed it
  from the crash reports. Every exact fix needs a fork or gives up streaming first audio, so the
  lead blocked with escalation `ET-R3-01` in `plan.md` instead of a remediation pass. The resuming
  lead runs the single remediation pass on Aidan's answer, then a fresh closure. The plan's
  conventions-learned line on cancel-then-read stays as written and should be revised to match the
  chosen option.

Remediation pass (ET-R3-01, Aidan's answer: option 3, no fork, streaming generation kept).

- Finding: every Qwen `speak` run exits with SIGSEGV (139) because MLX Audio Swift's cancelled
  generation task, which nothing can await, still runs MLX work at process exit. Fixed for the
  bench, as Aidan chose:
  - `Speak.swift`: `cancellationTrial` waits 1 s after cancelling, before it returns. The trial is
    `speak`'s only cancel of a running generation (a reading pulled to its end has finished
    generating), so the next pass's first reading and the process exit both start after the
    cancelled generation has settled. A codec step takes tens of milliseconds, so 1 s is many
    steps; it is a heuristic, not a fix. The interrupted pass had already written it; it was kept
    as sound and minimal. It applies to every provider and costs 1 s per paced pass.
  - Considered and rejected: the closure's suggestion to keep consuming MLX Audio Swift's stream
    after cancel. Its `onTermination` cancels the task and finishes the stream at once, so the
    stream's end says nothing about the task's; only a fork could expose that.
  - `QwenTTSSpeech`'s doc comment states the overlap and points to the handoff's blocker. No
    product code changed.
  - Recorded: the handoff's Known limitations entry now names the unawaitable cancellation as a
    blocker to fix before productionising Qwen, including the app's quit and stop-then-read risks.
    The plan's conventions-learned line was revised: it no longer says the overlap is one step, and
    workstream 4's signed-app check now also stops a reading and quits at once, checking for crash
    reports, as well as stop-then-read.
  - Handoff corrections: "Verification: passed" now rests on checked exit statuses; cited runs are
    the new ones (`20261005T211446Z-local`, `20261005T211844Z-local`, `20261005T211803Z-local`,
    `20261005T211916Z-local`, `20261005T212053Z-local`), with the first download
    (`20261005T202552Z-local`) kept for its download figures only. Files changed lists `Speak.swift`.
- Simplification/deletion pass: nothing to remove. The mitigation is one wait in the bench; no
  machinery was added to `QwenTTSSpeech`.
- Verification on the final source: every packet command plus the styled, offline and speed
  checks, release bench builds, each exit status checked (all 0; `--speed 0.5` rejected with 1 as
  intended), and no new EchoTypeBench crash report. Details in the handoff's Verification.

## Closure review

- Reviewer: fresh closure agent (Claude Code), base `cdec843`, same uncommitted tree (no source
  changed since review; last source edit `QwenTTSModel.swift` 20:20:51Z).
- Verdict: block. The accepted dispositions are in place, but a packet verification command
  fails: `speak` with a Qwen voice exits with SIGSEGV (139) after finishing its run.
- Accepted dispositions:
  - Optional 1: fixed. The handoff says `swift-huggingface` was already resolved at the base
    commit; `git show cdec843:Package.resolved` confirms it (0.12.0), and the pin diff adds only
    `mlx-audio-swift` and moves `mlx-swift` and `mlx-swift-lm`.
  - Optional 2: fixed. The plan's decision and drift log has the pin-move entry (affects 5),
    naming `20261005T203204Z-local` as the only cleanup sample on the new pins and telling
    workstream 5 to remeasure.
  - Question 1: fixed as dispositioned. Conventions learned has the cancel-then-read line for
    workstream 4's signed-app check. The plan also records speed `1...1` and 0.6B plain-only.
- Targeted verification, rerun:
  - `swift build`, `swift test`, `swift build -c release --product EchoTypeApp`,
    `scripts/build-app.sh release .build/qwen-tts-check/EchoType.app`: all exit 0. `Contents/Resources`
    holds `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`,
    `swift-crypto_Crypto.bundle`, `swift-transformers_Hub.bundle`.
  - `cleanup --provider local --fast cleanup-clear-correction`: `20261005T204446Z-local`, exact,
    stop-to-insert 338 ms, 0 fallbacks, exit 0.
  - `swift run -c release EchoTypeBench speak --provider local --candidate voice=qwen3-tts-0.6b
    reading-ordinary-prose reading-agent-reply`: `20261005T204410Z-local`, exit 139. Rerun
    directly from `.build/release/EchoTypeBench` as `20261005T204520Z-local`: exit 139 again.
    Both run directories are complete and `report` reads the first cleanly (0 violations, 0 gaps,
    first audio 174 and 216 ms, cancellation trial pending, 0 ms). Because the process dies,
    buffered stdout is lost when piped: neither invocation printed its summary or run path.
- Remaining required finding (new, release-blocking for this packet):
  - Qwen `speak` crashes at process exit. Crash reports
    `~/Library/Logs/DiagnosticReports/EchoTypeBench-2026-10-05-214512.ips` (this closure's first
    run) and `EchoTypeBench-2026-10-05-212921.ips` (launched 20:24:36Z, crashed 20:28:47Z, which is
    the cited first-download run `20261005T202552Z-local`) both show the main thread in `exit` →
    `__cxa_finalize_ranges` → MLX static destructors (`Scheduler::~Scheduler` →
    `metal::Device::end_encoding`, or `ThreadPool::~ThreadPool`), while in the first report a
    cooperative thread is still inside `Qwen3TTSModel.generateStream` (MLX `compile` cache). The
    cancellation trial cancels the last reading, and MLX Audio Swift's generation task, which
    nothing awaits, is still running MLX work when `main` returns. This is the Question 1 overlap
    observed for real: cancelled generation outlives `cancel()` long enough to collide with
    teardown. It does not reproduce on the base commit (Kokoro uses no MLX). The handoff's
    "Verification: passed" and the cited runs did not notice the exit status.
  - Consequences: the packet's `speak` verification commands do not pass; any bench script or
    workstream 5 pass that checks exit status or reads stdout fails; and the app can crash on quit
    shortly after stopping a Qwen reading, the same unawaited task.
  - Direction for the lead (not prescriptive): make cancelled Qwen production observable, for
    example have `QwenTTSSpeech` keep consuming the MLX Audio Swift stream after cancel until it
    ends and expose that end, so the bench (and the model's next reading) can wait for it.
- Remaining required findings: 1 (Qwen `speak` exits with SIGSEGV after cancellation).

### Closure review after remediation (ET-R3-01)

- Reviewer: fresh closure agent (Claude Code), base `cdec843`, same uncommitted tree. Last source
  edits `Speak.swift` 20:56:40Z and `QwenTTSSpeech.swift` 20:56:51Z (doc comment only); every run
  below started after them.
- Verdict: accept. The remediation matches Aidan's option 3 and every targeted verification
  command now exits 0.
- Against the chosen option:
  - Bench mitigation: `Speak.swift`'s `cancellationTrial` sleeps 1 s after cancelling, before
    returning. It is `speak`'s only cancel of a running generation (readings otherwise end by being
    pulled to their end; `defer { stream.cancel() }` then cancels nothing in flight), so the next
    pass and process exit follow the wait. Minimal, commented as a heuristic, no product code
    changed. Costs 1 s per paced pass for every provider; not release-blocking.
  - Blocker recorded: the handoff's Known limitations names the unawaitable cancellation as a
    blocker before productionising Qwen, including the app's stop-then-read and quit risks;
    `QwenTTSSpeech`'s doc comment points to it.
  - Workstream 4: the plan's conventions learned now requires the signed-app check to stop a Qwen
    reading and start another several times, then stop one and quit at once, checking the app log
    and `~/Library/Logs/DiagnosticReports`, and to check every bench command's exit status.
  - No fork: `Package.swift` still pins upstream `Blaizzy/mlx-audio-swift` at `bf14ae0c`.
  - The earlier closure's accepted dispositions (Optional 1, Optional 2, Question 1) remain in place.
- Targeted verification, rerun with each exit status checked:
  - `swift build` 0; `swift test` 0 (core 145, bench 23, app 76); `swift build -c release
    --product EchoTypeApp` 0; `scripts/build-app.sh release .build/qwen-tts-check/EchoType.app` 0,
    and `Contents/Resources` holds `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`,
    `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle`, `swift-transformers_Hub.bundle`.
  - `swift build -c release --product EchoTypeBench` 0, then from `.build/release/EchoTypeBench`:
    - `speak --provider local --candidate voice=qwen3-tts`: `20261005T212611Z-local`, exit 0,
      summary and run path printed. 8 readings, 0 failed, 0 violations, 0 gaps; warm first audio
      p50 310 / p95 427 ms, cold 231 ms; pause 1.2 s of audio after resume, footprint 2622 to
      2479 MiB; cancellation trial pending, 0 ms, 0 violations.
    - `speak --provider local --candidate voice=qwen3-tts-0.6b reading-ordinary-prose
      reading-agent-reply`: `20261005T212916Z-local`, exit 0. 0 violations, 0 gaps, first audio 404
      and 206 ms; cancellation trial pending, 0 ms.
    - `cleanup --provider local --fast cleanup-clear-correction`: `20261005T212954Z-local`, exit 0,
      exact, stop-to-insert 351 ms, 0 fallbacks.
  - Crash reports: no EchoTypeBench report in `~/Library/Logs/DiagnosticReports` after the runs
    started (21:22Z). The earlier closure's `.ips` files are no longer in that directory; the system
    has rotated them.
- Remaining required findings: 0. The unawaitable cancellation stays an open product blocker for
  Qwen, recorded as Aidan chose, not a defect of this packet.
