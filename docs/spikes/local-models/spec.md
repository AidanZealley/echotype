# Local model provider spike

Status: draft, 2026-10-03. This document proposes future spike work. The initial
authorised scope is the spike branch and these documents.

## Goal

Determine whether a predefined local model set can give EchoType better dictation,
cleanup and read aloud than its Apple provider at acceptable cost on an M1 Pro with
16 GiB memory. Use xAI as the quality reference. Measure the gap rather than promising
parity with cloud models.

Weights should download on first use and remain usable offline. Users should not
need Hugging Face credentials, Python, Ollama or a separate model server.

See [research findings](research.md) for candidates, evidence, sources and limitations.

## Initial candidates and comparisons

| Service | First candidate | Required comparison | Reason |
| --- | --- | --- | --- |
| Transcription | Parakeet Unified EN 0.6B, 640 ms INT8 Core ML | Whisper large-v3-turbo, Argmax compressed 626 MB Core ML | Streaming-trained model versus a different recognition family. |
| Cleanup | Qwen3-4B-Instruct-2507, MLX four-bit | SmolLM3-3B, MLX four-bit, thinking disabled | Conservative editing candidate versus lower memory cost. |
| Read aloud | Kokoro-82M v1.0, Core ML ANE pipeline | Qwen3-TTS-12Hz-1.7B-CustomVoice, MLX four-bit | Smaller fixed-voice synthesis versus the preferred demo's pronunciation and style control. |

Compare each service with EchoType's existing Apple and xAI adapters using the same
inputs. Apple's read-aloud baseline should include an installed premium UK voice,
not just the default voice. Record the exact voices and model versions used.

Conditional follow-ups are Nemotron Streaming if Unified's sustained cost is too
high, Ultra if recognition quality disappoints, and Qwen3-TTS 0.6B CustomVoice if 1.7B
misses the first-audible-speech target. The 0.6B model uses the same implementation
with different weights, so it is the cheapest follow-up. Its MLX four-bit conversion
exists, at about 1.69 GB against 2.31 GB, so expect a latency rather than download saving. Larger cleanup models stay outside
the first comparison. Pocket and Supertonic remain research alternatives rather than
planned comparison builds. Revisit only when a measured problem justifies extra work.

## Voice audition findings and priorities

Aidan preferred Qwen3-TTS in the hosted demos. Kokoro's Heart and Emma voices sounded
good, but it pronounced "commonly read" with past-tense "red" instead of present-tense
"reed", and "demos" as "dee-moss" rather than "deh-mohs". Qwen avoided those mistakes,
and its voice-style prompting was appealing. Supertonic sounded robotic; Pocket had
noticeable audio artefacts and similar pronunciation mistakes to Kokoro.

These are subjective demo observations, not native-runtime benchmark results. They
replace Pocket with Qwen in the initial shortlist from the research document. Use
Heart and Emma for Kokoro, and audition Qwen presets before fixing its comparison
voice. Record the selected voice and any style prompt. Compare a plain Qwen preset
first, then test a fixed style prompt separately to understand its quality and latency
cost. No user-facing style editor is required for the spike.

Time to first audible speech is the deciding performance measure. A substantial speed
advantage could make Kokoro preferable despite pronunciation mistakes. Better speech
does not compensate for several seconds of startup delay during normal warm use.
Keep this tradeoff in the final recommendation rather than ranking models by sound
quality or total synthesis throughput alone.

## Scope

Build the smallest disposable experiment that can run the six candidates, record
paired results and compare them inside signed EchoType builds. Add one experimental
local provider with two candidates per service. Each build selects one candidate for
each service through a single spike-only configuration file. Keep the normal provider
default unchanged during the spike.

The spike covers English dictation and curated English reading voices, with UK speech
and coding vocabulary in the evaluation. It covers native inference, selected-file
downloads, model preparation, warm reuse and teardown.

BYOM, arbitrary repositories, model selection settings, voice cloning, training,
multiple hardware tiers, automatic model updates and a general model-management
framework are outside scope. Candidate selection is an internal build choice, with
no runtime model picker or new settings.

## Provider and candidate selection

Create the experimental provider and its candidate implementations under
`Sources/EchoTypeCore/Providers/Local/`. One file, `LocalCandidates.swift`, selects
the transcription, cleanup and voice candidates and assembles the local provider.
Keep the provider's stable id and its normal Settings entry the same across builds.
Change this file and rebuild to test a different combination.

Candidates implement the existing service contracts directly:

| Service | Candidate implementation boundary |
| --- | --- |
| Transcription | TranscriptionService starts a LiveTranscriber. Unified and Whisper need separate implementations for their runtimes and live transcript handling. |
| Cleanup | CleanupService returns revised text. Qwen and SmolLM can share one MLX implementation with different model assets and chat-template options. |
| Read aloud | VoiceService creates a SpeechStream. Kokoro and Qwen3-TTS need separate implementations for their runtimes, generation, buffering and speed behaviour. |

Keep each candidate's pinned weights, required resources and runtime options together.
Changing a weights path is sufficient only when the runtime and generation flow are
compatible. The selection file should choose existing implementations and their
configuration, without another adapter protocol or general factory framework.

Assemble voices, speed limits, keyterm limits and readiness from the selected
implementations. Prepare only the selected models and do not instantiate or warm
unused candidates. The rest of EchoType continues to receive a Provider and does not
inspect candidate names or handle model-specific behaviour.

Use the same candidate implementations for repeatable corpus comparisons and app
trials. The [test harness](../../specs/test-harness.md) bench runs any `Provider`
through the existing contracts, so Apple, xAI and the local candidates run through
identical code, and can select a local candidate with a bench-only argument. Avoid
separate inference implementations for benchmarking.

## Comparison builds

Start with Unified, Qwen3-2507 and Kokoro as the reference local combination. Make
three comparison builds, each changing one service while keeping the other two fixed.

| Build | Transcription | Cleanup | Read aloud |
| --- | --- | --- | --- |
| Reference | Unified | Qwen3-2507 | Kokoro |
| Transcription comparison | Whisper Turbo | Qwen3-2507 | Kokoro |
| Cleanup comparison | Unified | SmolLM3 | Kokoro |
| Voice comparison | Unified | Qwen3-2507 | Qwen3-TTS |

Qwen3-2507 in this table is the text cleanup model. Qwen3-TTS is the separate speech
model, with its own weights, tokenizer/codec resources and loaded-model state.

Record the source revision and complete candidate selection for every build and test
result. Verify the selected combination in the signed app before collecting results.
Reuse verified downloads between builds while keeping different candidate artifacts
separate. Hold inputs and runtime options fixed except for changes a candidate needs.

Compare each service against Apple and xAI as described above. Test service quality
and standalone cost first, then its behaviour in the app. After choosing a preferred
candidate for each service, build that combination and measure concurrent latency,
memory, lifecycle behaviour and overall usability. Do not test every possible model
combination. Add a third candidate only when the initial pair exposes a measured gap.

## Native integration

Try FluidAudio for Unified and Kokoro, MLX Swift LM for cleanup, WhisperKit for Whisper,
and MLX Audio Swift for Qwen3-TTS. Check that the two MLX packages resolve compatible
versions of the shared runtime. Pin dependencies to versions compatible with the
actual Swift toolchain and macOS 26 target. If MLX packaging is the main obstacle,
assess llama.cpp before adding a second cleanup runtime.

Keep model loading and inference in provider-owned code. Preserve the boundaries in
[decision 0025](../../decisions/0025-provider-adapters.md). The experimental local provider
supplies all three services with no credential. Shared app code continues to use
Provider, LiveTranscriber, SpeechStream and CleanupService.

Separate loaded-model lifetime from operation lifetime. Prepare and warm models
before marking a service ready. Reuse loaded weights with fresh request state; do
not carry cleanup conversation history between windows. Avoid UI-executor inference.
Measure idle residency before choosing when to unload unused models.

For transcription, convert the existing 16 kHz mono Int16 PCM to runtime input.
Keep revisable results provisional until an utterance is settled. Vocabulary rescoring
must not rewrite committed text. Supply genuine speech evidence, drain buffered audio
on finish, resolve the tail before the finished event and join teardown after close.
Unified's streaming manager has no end-of-utterance signal, so derive utterance
boundaries from FluidAudio's `VadManager` or word timings, and use the VAD for speech
evidence. Keyterm boosting needs a CTC spotting model in the manifest and rescores in
segments of about 15 seconds, so measure commit lag with boosting on and off before
choosing when to commit. Set `keytermLimit` from what boosting supports. Re-decoding
settled utterances with Unified's offline path is a follow-up experiment rather than
a default: it needs a second encoder of about 596 MB. Try it only if streaming
punctuation or accuracy disappoints, and compare accuracy, punctuation, commit
latency and memory with and without it.

For cleanup, send Reviser's existing prompt and window unchanged for the initial
comparison. Return plain revised text. Retain validation and original-text fallback.
Use greedy sampling and cap output tokens near the window's token count. Prefill the
fixed prompt's KV cache once per loaded model and copy it into each fresh request;
MLX Swift LM supports both. Its speculative decoding needs a draft model, and it has
no prompt-lookup decoding. Try draft-model speculation only if warm latency misses the
budget, and record its memory cost. Check cancellation between
generation steps, including during prompt prefill, and establish whether the existing
three-second final deadline is enforceable by the chosen runtime. Constrained decoding
to a subsequence of the input words is a production option if validation rejections
prove common; `MLXGuidedGeneration` supplies EBNF-constrained decoding, so it needs a
per-request grammar rather than a custom sampler. Do not build it for the spike unless
rejections are common.

For read aloud, let SpeechStream.next control bounded production. Generate at most
one bounded short utterance ahead for batch models, then return mono Float32 chunks
of at most 100 ms at one fixed sample rate. A paused consumer must not allow an entire
document to be generated. Qwen's streaming implementation must return initial audio
without waiting for the whole passage and keep production bounded when playback
pauses. Inspect its producer rather than assuming a streaming API supplies backpressure.
Verify speed control and cancellation explicitly. If Qwen3-TTS has no native speed
control, time-stretch in its adapter or narrow its `speedRange`; record the choice
rather than changing shared playback. Compare bounded utterance lengths
to ensure faster first audio does not sacrifice contextual pronunciation or intonation.

Do not add a new shared abstraction merely to wrap each runtime. Make a contract
change only when an observed incompatibility cannot be handled in the provider.

## Model delivery experiment

Create an explicit file list for each tested runtime configuration. Record repository,
full commit revision, required tokenizer/configuration/voice resources, file sizes and
integrity metadata. Download only those files. Resolve upstream licence and voice
terms before choosing an automatic-download artifact.

Keep downloaded files outside the app bundle in EchoType's Application Support
directory. Pin model versions independently from installed app updates. A download
must not count as installed until all required files are verified. Keep incomplete
files separate and demonstrate recovery after interruption without loading partial
weights. Record transient disk usage and compiled Core ML caches.

Selecting the local provider is the opt-in. The app checks readiness only for the
selected provider, at launch and on a change of provider, and `Readiness.check` starts
setup by contract. xAI remains the default, so no other install starts a download.
Report download and loading progress in the `.waiting` message, such as "Downloading
models, 1.2 of 3 GB", and failures as `.unavailable`. A production setup UI can follow
once the model set and measured requirements are known.

Demonstrate inference with network access disabled after preparation. Ship runtime
code and required small resources in the app; do not package weights in the build.

## Evaluation

Run the evaluation with the [test harness](../../specs/test-harness.md): its corpus,
bench, scoring and report, and its app driver and guided sessions for signed-app
checks. The spike is the harness's first consumer and builds its first two steps.
Calling xAI sends samples or text to xAI and uses paid credentials; mark that
comparison explicitly. Record which samples, if any, were excluded and why.

Start with about 15 dictation clips, 12 cleanup samples and 8 reading passages, with
10-20 warm repeats for each latency figure.

| Service | Sample coverage | Measurements |
| --- | --- | --- |
| Transcription | UK accent, coding/product names, punctuation, pauses, corrections, background noise and silence. Include short recordings and a longer continuous dictation. | Word error rate against a manual transcript, keyterm accuracy, hallucinations, first provisional text, first committed text, stop-to-final latency and any changed/lost committed words. |
| Cleanup | Clear corrections, ambiguous corrections, deliberate repetition, false starts, fragments, dictated commands/questions and long unpunctuated input. | Wrong deletions, additions/reorderings, missed edits, validation rejections, deadline fallbacks, warm latency distribution, stop-to-insert latency and the share of dictation time spent revising. |
| Read aloud | Kokoro Heart and Emma, selected Qwen presets, ordinary prose, technical terms, numbers, abbreviations, punctuation and a long selection. Include contextual pronunciation and a fixed Qwen style-prompt trial. | Intelligibility, preferred voice/prosody, pronunciation errors, first audible speech, playback gaps, synthesis throughput, utterance joins, style effects, speed control and buffering while paused. |

Include the exact pronunciation passage from the demo audition:

> Try the same paragraph in each, including a few technical terms you commonly read.
> These demos help judge voice quality; their response times won't represent
> performance inside EchoType on your Mac.

Check "read" and "demos" in that passage, plus a past-tense reading of "Yesterday I
read the report". Preserve enough sentence context for the intended pronunciation.
Record whether the native conversion reproduces the demo mistakes; do not assume it
will. Avoid word-specific substitutions merely to make these examples pass.

Measure user-request-to-first-audible-speech separately from request-to-first-generated
audio and total synthesis time. Include scheduling and playback buffering in the
audible result. For an already prepared model, report both cold first reading after
app launch, including model loading, and warm subsequent readings. Record any loading
wait before a retry so readiness cannot hide user-visible startup cost.

The initial warm target is roughly 500 ms to first audible speech on ordinary short
passages. Report p50/p95 and sample count against that target. This is a proposed
product target, not an established model capability. Multi-second warm starts fail
the intended reading experience. Assess cold-start delay separately and verify that
generation stays ahead of playback without gaps on longer passages.

Measure stop-to-insert end to end. `Reviser.finish` awaits the cancelled live revision
before its three-second timer starts, so an uninterruptible prefill extends the wait
beyond the budget. `Reviser` starts a live revision whenever committed text grows, so
record how much of each dictation the cleanup model spends generating.

Separate cold download/preparation/load/first-inference time from warm operation time.
Distinguish first load after download, which may include Core ML compilation, from
first load after reboot or an OS update, which may find the compiled cache evicted.
Record exact Mac, OS, toolchain, dependency revisions, model artifacts, precision,
streaming configuration and voice. Measure standalone services first, then transcription
and cleanup together. Exercise read aloud alongside any dictation concurrency the
app permits. Record peak process memory and observed system memory pressure. Use
`phys_footprint` rather than resident size, and set MLX's buffer cache limit so cached
buffers do not inflate it. ANE work may be attributed to system processes, so process
memory alone can understate Core ML cost. Expect the voice comparison build, with
Qwen3-4B, Qwen3-TTS and Unified loaded together, to be the memory worst case.

Use enough repeated warm trials to report useful distributions, including p50/p95 and
sample count. Keep the original measurements rather than reporting only averages.
Note whether cleanup completed inside three seconds and how often the user saw
unrevised fallback text. Do not extend the deadline to make a candidate look successful.

Run focused lifecycle checks for rapid stop, stop during inference, pause/resume,
provider switching and final-tail flushing. Record cancellation latency. Core ML calls
may not be interruptible midway; the adapter still needs bounded work and safe teardown.

## Build verification

MLX packaging was checked on 2026-10-03 (see [research](research.md#downloads-licensing-and-packaging)).
`swift build` compiles MLX's shaders once Xcode's Metal Toolchain component is
installed, and a signed hardened bundle loads them from `mlx-swift_Cmlx.bundle` in
`Contents/Resources`. Add the toolchain download to CI and make `build-app.sh` copy
every `*.bundle` from the bin path into `Contents/Resources` before signing. A missing
bundle fails loudly under the default build system, so no hidden-fallback check is
needed. Recheck when FluidAudio, WhisperKit or MLX Audio Swift add their own bundles.

Update bundle staging only as needed for pinned inference dependencies. Preserve
signing and the existing microphone entitlement. Validate the installed signed app,
not only swift test or an executable running beside its build resources.

Verify dependency packaging for each comparison build, since selected runtimes can
differ. Demonstrate model preparation and the selected service in each build, then
dictation, cleanup, read aloud, pause/resume, cancellation and offline relaunch with
the preferred combination. No broad app refactor is part of the spike.

## Completion criteria

- A paired results record identifies tested candidates, inputs, configurations,
  build revisions and measurements. It covers the reference and three single-service
  comparison builds. Untested candidates remain labelled as research hypotheses.
- The recommended set has a reproducible pinned asset manifest, documented terms and
  successful offline inference after opt-in setup.
- The provisional provider meets the existing transcript, audio and operation-lifetime
  contracts in a signed build, or records the specific incompatibility that blocks it.
- Cleanup deadline behaviour and concurrent memory cost are measured on the M1 Pro.
- Voice preference and dictation improvement are judged against actual Apple and xAI
  samples, with remaining quality gaps described plainly.
- The voice decision compares Kokoro and Qwen3-TTS on contextual pronunciation and
  first audible speech. It records Heart/Emma trials, Qwen's fixed style-prompt trial,
  cold/warm latency and playback gaps, and explains any quality-for-speed tradeoff.
- The decision recommends one fixed set, a narrower local feature, or rejection. Poor
  results are a valid spike outcome; no production provider is required to declare the
  investigation complete.

The initial performance targets are recognition that keeps up with live speech,
warm first audible speech around 500 ms with synthesis that keeps up with playback,
and final cleanup within the current three-second budget on ordinary samples. Report
failures and their frequency. Product acceptance thresholds for quality, memory, cold
startup and battery cost remain open until the measurements exist.

## Expected output and cleanup

Add a results document here when experiments run. Include the winning model choices,
download and runtime costs, integration changes, remaining blockers and a proposed
production scope. Keep research and this draft in sync when a candidate changes.

Before proposing production work, remove superseded experiments, unused dependencies
and losing candidate implementations. Remove LocalCandidates.swift's comparison
selection machinery and keep a direct composition of the chosen services if the
provider proceeds. Retain only evidence or code that supports the chosen direction.
Avoid turning comparison machinery into permanent product settings.
