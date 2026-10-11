# Revisit Qwen3-TTS voice consistency

Status: deferred research, updated 2026-10-11. This is a record of decisions and a proposed
investigation, not an approved implementation spec. Productionization completed local
implementation and review; this investigation remains outside that completed scope.

## Decision and desired outcome

EchoType's chosen production speech pipeline is eSpeak NG with Kokoro v1.0 Core ML.
Aidan accepted its audio on 9 October 2026. The productionization pass removed the
experimental Qwen3-TTS adapter. Qwen3-TTS remains a separate future experiment.
Qwen3-4B-Instruct-2507 for dictation cleanup is a different model and remains in scope.

Aidan liked Qwen's realistic sound, especially Ryan, but found its delivery inconsistent
between readings and even between lines within one reading. The problem includes tone,
emotion, pace and unexpected expressive behaviour, not just speaker identity. A realistic
voice with a stable identity can still fail this requirement through varying delivery.

The desired future feature has two parts:

- A small set of dependable, neutral voices with consistent identity and delivery.
- An optional open description for playful or unusual voices, including agent speech.

The open description should not be required to make ordinary reading sound consistent.
No final voice descriptions, UI, reference recordings or model variants have been chosen.

## What the spike actually tested

The measured candidate was
`mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit` at
`f35faf19b0cc2160865af64ecf0f22f83d335135`. It downloaded 2,311,984,361 bytes in
seven pinned files. The spike recorded Apache-2.0 from conversion and upstream cards.
Recheck the terms and provenance of any new conversion or reference audio when restarting.

The adapter offered these presets: Ryan, Aiden, Vivian, Serena, Uncle_Fu, Dylan, Eric,
Ono_Anna and Sohee. Aidan chose Ryan for the recorded comparison. The 1.7B adapter also
offered each preset with this fixed instruction:

> Read clearly and naturally, in a calm, warm narration style, at an even pace.

Aidan heard no useful difference between styled and plain Ryan in the signed-app audition.
The subsequent measured comparison used plain Ryan. This does not establish that every
instruction is ineffective. No prompt search or controlled consistency experiment was done.

Generation used temperature 0.9, top-p 1, top-k 50, repetition penalty 1.05 and a requested
maximum of 4096 tokens. The talker and code predictor used the conversion's generation
configuration. No fixed seed or lower-temperature comparison was measured.

Whole sentences were grouped into utterances up to 250 Unicode scalars. Each utterance
started a separate generation, with fresh generation state over shared weights. Audio
streamed every four codec steps, about 0.32 seconds. Only one utterance was produced ahead
of what the reader pulled. Splitting may contribute to audible delivery changes between
utterances, but that cause was not isolated experimentally.

The 0.6B CustomVoice variant was provisioned as a candidate but not run in the final
evaluation because the latency condition for testing it was not met. It had no styled
voices because the upstream path ignored its instructions. Base, VoiceDesign, cloning
and fine-tuning were not implemented or evaluated by EchoType.

## Results worth retaining

These are historical results on the M1 Pro under variable load, not guarantees for a
future runtime. See the [consolidated model evidence](../decisions/0026-local-model-stack.md) for methodology
and comparison limits. Full sample counts and raw measurement tables remain in the
archived results at commit `2f231b9`.

| Observation | Recorded result |
| --- | --- |
| Warm short-passage first audio | Ryan p50 241 ms, p95 489 ms |
| Generation throughput | About 1.8 times real time |
| Voice-only memory | About 2.5 GiB ready; about 2.9 GiB peak in paced/repeat runs |
| Combined dictation and speech models | 5,201 MiB peak, 4,775 MiB ready; critical memory pressure |
| Installed model load in a fresh process | 1.4 seconds in the recorded installed-load run |
| Pronunciation | Every tested heteronym was correct in the Ryan listening run |
| Listening | Highly realistic, but unpredictable tone, laughs and sighs; consistency was unacceptable |
| Native playback-speed support | Only 1× offered; no measured time-stretching alternative |

The combined memory run used unboosted Unified transcription and Qwen cleanup. It does
not establish the cost of the recommended boosted dictation set. One blind listening
reading per voice and passage cannot characterise the full distribution of Qwen output.

Useful archived runs, under `~/Library/Application Support/EchoTypeBench/runs/`:

- `20261007T100825Z-local`: Ryan's eight-passage paced listening run.
- `20261007T101342Z-local`: repeated warm first-audio measurements.
- `20261007T104124Z-local`: offline Ryan readings.
- `20261007T104448Z-local`: combined-model memory measurement.
- `20261007T114144Z-local` and `20261007T114153Z-local`: fresh and installed loading.

The blind listening page and ratings were under
`~/Library/Application Support/EchoTypeBench/listening/20261007T105149Z/`, outside git.
Do not cite the interrupted partial run `20261006T141807Z-local` as completed evidence.
If local artifacts are gone, this document, the decision record and archived results
still retain the conclusions. The future investigation does not require keeping the old bench alive.

## Runtime blockers at the tested revision

The adapter used MLX Audio Swift `bf14ae0c26e4e85553dd989571cae29d70fa6735`.
These findings apply to that revision. Check whether upstream has fixed them before
deciding that a dependency fork is necessary.

1. **Incomplete readings, ET-R4-02.** The runtime capped each utterance at
   `max(75, 6 × text tokens)` codec steps of 80 ms, despite the larger requested limit.
   Three of eight Ryan listening passages ended at that cap. Completion cannot be
   inferred from a clean stream ending or a plausible-sounding WAV.
2. **Unawaitable cancellation, ET-R3-01.** Generation ran in an unstructured task without
   an awaitable completion handle. Cancellation could overlap the next reading's use
   of shared codec state, and process teardown during remaining generation crashed MLX
   in CLI checks. The bench's one-second wait was a spike heuristic, not a fix. The
   signed app did not reproduce that crash in its audition, which does not clear it.
3. **Preset language overrides.** Eric and Dylan forced a Chinese dialect during English
   reading because the runtime applied their dialect override regardless of requested
   language. Upstream's reference implementation applied it only for Chinese or auto.
4. **Dependency constraints.** MLX Audio Swift forced older MLX pins across the app.
   Removing Qwen speech restored MLX Swift 0.32.3 and the evaluated MLX Swift LM revision
   `5e46681b2adcef2db158e7b949aeae3896778e23`. A future speech integration must account
   for its effect on cleanup rather than silently changing that runtime.

Completion, cancellation and resource cost remain adoption criteria even if voice
consistency improves. A new runtime must demonstrate them rather than inherit a waiver.

## Proposed consistency experiments

The [official Qwen3-TTS documentation](https://github.com/QwenLM/Qwen3-TTS) distinguishes
CustomVoice preset speakers with instructions, VoiceDesign from descriptions, and Base
voice cloning from reference audio. It also demonstrates designing a voice and then
reusing that generated reference through Base cloning. These are upstream capabilities;
support in a chosen native/MLX runtime still needs verification.

Two paths are worth comparing, not assuming equivalent:

- Tune a CustomVoice preset's delivery with instructions and sampling controls.
- Design or select a reference voice once, save its audio and transcript, then reuse
  that reference for subsequent Base-model readings instead of redesigning it each time.

The second path may better anchor identity, but a reference alone does not prove stable
emotion or prosody. Repeatedly submitting the same voice description is also not evidence
of a stable voice. Lower temperature or a fixed seed may reduce variation, but neither
has been demonstrated as the solution for EchoType; they may reduce quality instead.

## How to restart without reviving the spike

1. Read this record and the archived blocker reports. Pin the models, runtime and
   generation configuration for the new experiment. Verify supported model variants
   and whether the old cancellation, cap and language bugs still exist.
2. Establish a small isolated reference experiment before adding a new app integration.
   A supported upstream runtime can help separate model capability from Swift adapter
   behaviour. Record the hardware and runtime; do not compare their timings as equivalent.
3. Repeat the same short and long passages, then vary the text. Keep raw audio, settings,
   reference audio/transcript where used, and completion/timing data. Compare consistency
   between runs, between utterances, and across different texts. Change one variable at a
   time: prompt, sampling, seed, reference or segmentation.
4. Compare promising output with the accepted Kokoro/eSpeak pipeline. Include routine
   prose, agent replies, questions, numbers, heteronyms, expressive punctuation and long
   readings. Separate unwanted expression and identity drift from pronunciation errors.
5. Only after a useful voice-control result, implement a bounded native adapter and
   check complete playback, pause/resume, stop, rapid stop/start, quit after cancellation,
   offline use, model removal and coexistence with dictation. Request a focused listening
   decision on a finished candidate before making it a production choice.

Use the follow-up [app testing spec](app-testing.md)'s scripted real-model tests when
available. Retain structured results and recordings for both Aidan and agents. Do not
reintroduce a general model bench or ship unused providers to preserve the experiment.

## Where the implementation and evidence remain

The completed spike is preserved at commit `2f231b9` on `spike/local-models`. Read the
archived implementation without restoring it into production:

```sh
git show 2f231b9:Sources/EchoTypeCore/Providers/Local/QwenTTSModel.swift
git show 2f231b9:Sources/EchoTypeCore/Providers/Local/QwenTTSSpeech.swift
git show 2f231b9:Sources/EchoTypeCore/Providers/Local/QwenTTSManifests.swift
git show 2f231b9:Tests/EchoTypeCoreTests/QwenTTSSpeechTests.swift
git show 2f231b9:Package.swift
```

The completed workflow records are archived, not required production files. Read details
without restoring those documents:

```sh
git show 2f231b9:docs/spikes/local-models/implementation/read-aloud/03-qwen3-tts.md
git show 2f231b9:docs/spikes/local-models/implementation/read-aloud/04-app-read-aloud.md
git show 2f231b9:docs/spikes/local-models/implementation/read-aloud/05-voice-evaluation.md
```

The [dependency cleanup notes](../productionization/dependencies.md) record the subsequent
restoration of cleanup's runtime.
The historical findings remain evidence; their temporary mitigations and old dependency
pins are not requirements for the new investigation.
