# Local model provider research

Status: initial findings, 2026-10-03. No models downloaded or benchmarked locally.

## Purpose

Find a predefined set of local models for EchoType's transcription, cleanup and read
aloud services. Download weights on first use rather than including them in the app.
Aim for a useful improvement over the Apple provider, with xAI as the quality reference.
Neither improvement nor parity has been established by this research.

Three research agents investigated one service each. The assessment below combines
their primary-source research with inspection of EchoType's provider contracts,
session, reviser, reader and bundle build script. The next experiment is described in
[the draft spec](spec.md).

## Evidence and hardware baseline

The development Mac reports an Apple M1 Pro and 16 GiB of unified memory, running
macOS 27.2 with Xcode 27.0 and Swift 6.4. EchoType targets macOS 26, so Apple baselines
measured here reflect macOS 27's services. Published M2, M4 and M5 measurements are
useful context, not predictions for this Mac.

Checks run on this Mac on 2026-10-03 are marked as verified. They used FluidAudio at
`0b1f462`, MLX Swift 0.32.3 and MLX Swift LM at `5e46681`.

Download figures are approximate decimal MB/GB from Hugging Face file metadata.
They select one runtime configuration where possible, excluding duplicate formats,
alternative precisions and unused voices. They are not peak RAM measurements.
Cleanup RAM figures are planning estimates for short-context inference. Core ML
preparation caches and temporary downloads require additional disk space.

Quality judgments are hypotheses for the spike. General instruction-following scores,
clean audiobook recognition and speech intelligibility tests do not measure faithful
cleanup, technical dictation or preferred voice sound. No direct evaluation establishes
that these exact native configurations outperform macOS 26's Apple services or xAI.

## Initial recommendation

| Service | First candidate | Comparison | Reason |
| --- | --- | --- | --- |
| Transcription | Parakeet Unified EN 0.6B, 640 ms INT8 | Whisper large-v3-turbo, compressed Core ML | A model trained for streaming, compared with a different recognition family. |
| Cleanup | Qwen3-4B-Instruct-2507, MLX four-bit | SmolLM3-3B, MLX four-bit with thinking disabled | Explicitly nonthinking instruction model, compared with a smaller alternative. |
| Read aloud | Kokoro-82M v1.0, Core ML | Qwen3-TTS-12Hz-1.7B-CustomVoice, MLX four-bit | Small fixed-voice synthesis, compared with the voice preferred in demo auditions. |

The read-aloud comparison was originally Pocket TTS. Demo auditions recorded in
[the spec](spec.md) replaced it with Qwen3-TTS; Pocket remains a research alternative.

The reference combination (Unified, Qwen3-2507, Kokoro) needs roughly 3 GB of model
downloads, subject to the final Kokoro and keyterm asset manifests. Its combined RAM use
is unknown. FluidAudio could supply both of its audio services and MLX Swift LM its
cleanup, keeping its inference dependencies to two. The comparison builds add WhisperKit
and MLX Audio Swift, so the spike as a whole uses four runtimes. The voice comparison
build adds about 2.3 GB of Qwen3-TTS weights and is the likely memory worst case.

## Transcription candidates

EchoType accepts 16 kHz mono Int16 PCM and distinguishes committed, utterance and
provisional text. Committed text can only grow. Accuracy is useful only if the adapter
can decide when words are settled without delaying the transcript excessively.

| Candidate | Potential quality | Computational cost | Integration cost |
| --- | --- | --- | --- |
| [Parakeet Unified EN 0.6B, 640 ms INT8](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml) | Best first live-English trial. Joint offline/streaming training, punctuation and capitalisation. Accent and coding vocabulary need local evaluation. | About 609 MB selected files. ANE/CPU inference. Recomputes overlapping left context, increasing sustained work. | Medium. Swift streaming manager exists. Add speech evidence, utterance boundaries, final flushing and safe commitment. Vocabulary rescoring can revise earlier provisional text. |
| [Nemotron Speech Streaming EN 0.6B, 560 ms INT8](https://huggingface.co/FluidInference/nemotron-speech-streaming-en-0.6b-coreml) | Promising cache-aware alternative. Conversion authors report 2.12% word error rate on 100 LibriSpeech clean files. This is narrow preliminary evidence. | About 600 MB per selected variant. Reuses encoder state. Authors report 8.5 times realtime on M2. | Medium. Native Swift streaming and flush APIs exist. Still needs commitment and lifecycle handling. Documentation and licence inconsistencies need reconciliation. |
| [Parakeet Ultra 0.6B](https://huggingface.co/FluidInference/parakeet-ultra-coreml) | Quality-oriented batch option. Published paired Core ML results improve on Parakeet v3; upstream evaluations include difficult English recordings. | About 632 MB. INT8 encoder with Core ML support. Published server throughput is not a Mac estimate. | Higher for live use. Needs segmentation, rolling windows, overlap deduplication and stability handling. |
| [Whisper large-v3-turbo, 626 MB Core ML variant](https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/openai_whisper-large-v3-v20240930_626MB) | Established independent comparison with broad training. Silence hallucination, repetition and uneven accent performance remain risks. | About 627 MB plus tokenizer resources. Live use repeatedly decodes audio windows. No verified M1 Pro measurement found. | Medium to high. WhisperKit handles native inference. Window merging, speech detection, settled text and the final tail remain adapter responsibilities. |
| [Parakeet Realtime EOU 120M, 320 ms](https://huggingface.co/FluidInference/parakeet-realtime-eou-120m-coreml) | Simpler live option with a likely accuracy compromise. Conversion evaluation reports 4.87% word error rate on the full LibriSpeech test-clean set. | About 449 MB selected files. Smaller cache-aware model. Reported 12.48 times realtime on M2. | Lowest relative cost. Explicit end-of-utterance events fit provisional and committed text naturally. Still verify flushing and cancellation. |

The 640 ms Unified configuration is an initial accuracy/latency compromise, not a
measured end-to-end response time. NVIDIA supports multiple chunk/context choices;
the Swift conversion supplies selected variants. Avoid comparing word error rates
across different evaluation subsets as if they were a paired test.

Unified's [Swift manager](https://github.com/FluidInference/FluidAudio/blob/main/Sources/FluidAudio/ASR/Parakeet/Unified/StreamingUnifiedAsrManager.swift)
supports audio appends, processing, final flushing and partial callbacks. Its vocabulary
rescoring can change earlier partial text, so token arrival alone is not permission
to insert words. Inspect the [benchmark notes](https://github.com/FluidInference/FluidAudio/blob/main/Sources/FluidAudio/ASR/Parakeet/Unified/benchmark.md)
before reusing its quality or throughput figures.

Verified in FluidAudio's source:

- **Keyterms need a second model.** Unified's vocabulary boosting takes pre-loaded CTC
  models for keyword spotting, such as `parakeet-ctc-110m-coreml` (about 106 MB for the
  whole repository). Their weights belong in the asset manifest and memory figures.
- **Boosting rescores in segments of about 15 seconds.** Text becomes immutable once its
  segment is rescored, and `finish()` rescores the tail. Committing text before its
  segment is rescored forfeits boosting for it; waiting delays commitment, and therefore
  live cleanup, by up to about 15 seconds. This trade-off needs measuring.
- **No end-of-utterance signal.** The streaming manager exposes audio appends,
  processing, partial transcripts, token and word timings, finish and reset. Utterance
  boundaries must come from timings or FluidAudio's `VadManager`, which is also a
  candidate for speech evidence.
- **Offline re-decoding needs another encoder.** The offline batch path
  (`UnifiedAsrManager`) shares the decoder and joint but uses its own encoder, about
  596 MB in INT8, and a fixed 15-second window. Re-decoding settled utterances
  offline is possible, at the cost of that extra download and memory.
- **Streaming configurations are separate encoders.** The repository has one encoder per
  chunk configuration, named by left, chunk and right context in 80 ms frames. The
  640 ms configuration is `70_7_1`: 560 ms chunks with 80 ms of look-ahead.

WhisperKit is a product in [Argmax's Swift runtime](https://github.com/argmaxinc/argmax-oss-swift).
The [original Turbo card](https://huggingface.co/openai/whisper-large-v3-turbo) explains
the smaller decoder and known limitations. [Ultra's upstream card](https://huggingface.co/moondream/parakeet-ultra)
and [Core ML evaluation](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/ParakeetUltra.md)
support keeping Ultra as a later quality challenger. Distil-Whisper would not remove
Whisper's live-window integration work.

## Cleanup candidates

EchoType removes clear corrections, false starts and accidental repetitions while
preserving other words and their order. Reviser owns the prompt and validation.
Validation catches additions and reorderings but can accept incorrect deletions.
Task-specific editing accuracy therefore matters more than general reasoning scores.

| Candidate | Potential quality | Download and estimated runtime memory | Integration cost |
| --- | --- | --- | --- |
| [Qwen3-4B-Instruct-2507, four-bit](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit) | Best starting balance. Explicitly nonthinking, with strong vendor-reported instruction following. Faithful cleanup is untested. | 2.28 GB download; estimate 3-4 GB RAM for short contexts. | Low to medium. Supported architecture, native system prompt and no reasoning-mode parser. Apache 2.0. |
| [SmolLM3-3B, four-bit](https://huggingface.co/mlx-community/SmolLM3-3B-4bit) | Smaller comparison. Worth checking whether reduced capability affects conservative editing. | 1.75 GB download; estimate 2.5-3.5 GB RAM. | Low to medium. Native support exists. Disable thinking through the actual chat-template flag. Apache 2.0. |
| [Qwen3.5-4B, four-bit](https://huggingface.co/mlx-community/Qwen3.5-4B-4bit) | Newer challenger. Broad improvements do not establish better nonthinking cleanup. | 3.06 GB including multimodal weights; estimate 4-5 GB RAM pending text-only loading checks. | Medium. Hybrid architecture, text-only loading and thinking configuration need verification. Apache 2.0. |
| [Gemma4-E2B-it](https://huggingface.co/google/gemma-4-E2B-it) | Interesting on-device challenger without directly comparable editing evidence. | Four-bit artifact about 3.58 GB; estimate 4.5-6 GB RAM. E2B means effective compute, with 5.1B total parameters including embeddings. | Medium to high. New architecture and multimodal loading increase version sensitivity. Apache 2.0. |
| [Llama-3.2-3B-Instruct, four-bit](https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit) | Mature nonthinking baseline. Less compelling evidence for choosing it over Qwen or SmolLM. | 1.82 GB download; estimate 2.5-3.5 GB RAM. | Lower technical cost, additional distribution considerations. Meta's upstream repository is gated and uses custom terms. |

The [Qwen model card](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507) and
[SmolLM card](https://huggingface.co/HuggingFaceTB/SmolLM3-3B) provide instruction-following
evidence, not transcript-editing results. [MLX's published benchmark](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/BENCHMARKS.md)
reports Qwen3-2507 four-bit at 3.35 GB memory and 134.5 generated tokens per second on
an M4 Max with 64 GB. Those measurements do not establish M1 Pro performance.

The three-second final revision budget is the main computational uncertainty.
A 70-100-token output requires roughly 23-33 output tokens per second before prompt
processing and scheduling. The rolling window is not capped at 50 words, so long
unpunctuated passages can require much more output. Warm inference must be measured
while transcription runs. Cold loading belongs in readiness preparation.

The budget does not bound the whole stop-to-insert wait. `Reviser.finish` cancels the
in-flight live revision and awaits it before starting the three-second timer. A cloud
request cancels at once; local generation stops only between steps, and a long prompt
prefill may not be interruptible. `Reviser` also starts a new live revision whenever
committed text grows, so a local model may run almost continuously during dictation.

Local inference allows optimisations a hosted API does not. Verified in MLX Swift LM's
source:

- **Prompt caching is supported.** `Reviser.prompt` is fixed. `KVCache` supports
  copying, and `ChatSession` can save and restore prompt cache snapshots, so the prompt
  can be prefilled once and copied into each fresh request.
- **Speculative decoding needs a draft model.** It supports draft-model speculation and
  multi-token prediction for Qwen3.5, but not prompt-lookup (n-gram) decoding. Output
  that mostly copies its input suits prompt lookup, which would need a custom token
  iterator. A small same-tokenizer draft, such as Qwen3-0.6B for Qwen3-4B, is the
  supported alternative at the cost of extra memory.
- **Constrained decoding has infrastructure.** `MLXGuidedGeneration` masks logits with
  XGrammar against an EBNF grammar. Faithful output is a subsequence of the input words,
  so a per-request grammar could make unfaithful replies impossible without writing a
  custom sampler.

Output can be capped near the input's token count, with greedy sampling for repeatable
results.

As an Apple baseline, a short Foundation Models revision took 2.9-3.0 seconds in two
command-line runs on this Mac, close to the final budget. These are single observations,
not a distribution.

Use ordinary [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) APIs for the
macOS 26 target. Its newer Foundation Models bridge requires a newer SDK. Pin a
compatible release, model architecture implementation, tokenizer and downloader.
[llama.cpp's XCFramework](https://github.com/ggml-org/llama.cpp/blob/master/docs/xcframework.md)
with GGUF weights is a fallback if MLX build requirements prove more costly than a
small Swift-to-C generation adapter. Do not integrate both for the first experiment.

## Read-aloud candidates

EchoType pulls mono Float32 audio in chunks of at most 100 ms. Pausing playback must
bound generation and buffering. A streaming API with an unbounded producer does not
meet that requirement merely because the consumer stops requesting frames.

| Candidate | Potential quality | Computational cost | Integration cost |
| --- | --- | --- | --- |
| [Kokoro-82M v1.0, Core ML ANE pipeline](https://huggingface.co/FluidInference/kokoro-82m-coreml) | Best first audition for fixed-voice narration. Explicit UK voices. British voices need their own audition. | Plan 100-200 MB including pronunciation and selected voice assets; complete manifest needs verification. | Low to medium. Swift/Core ML, native speed control and 24 kHz Float32. Generate bounded utterances lazily and slice audio for playback. |
| [Pocket TTS English, Core ML v2.1 INT8](https://huggingface.co/FluidInference/pocket-tts-coreml) | Strong naturalness and quick-first-audio comparison. Use curated fixed voice states. | Roughly 300-320 MB with one voice and required resources. Genuine 80 ms audio frames. | Medium. Swift implementation exists, but its unbounded stream needs bounded production. Speed control needs additional implementation. |
| [Supertonic-3, Core ML INT4](https://huggingface.co/FluidInference/supertonic-3-coreml) | Efficient challenger with fixed voices and speed control. No verified UK-specific voice. | About 104 MB for a selected short-utterance configuration. Longer utterances may need extra estimator variants. | Low to medium technically. Swift/Core ML, no external phonemizer, batch synthesis. Weight licensing adds work. |
| [Qwen3-TTS-12Hz-1.7B-CustomVoice, four-bit](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit) | Larger expressive-voice comparison. A suitable British preset is not established. | About 2.31 GB including speech codec and tokenizer weights. Additional GPU memory and generation state. | Medium to high. Native MLX implementation exists. Requires bounded streaming, small audio slices, speed handling and heavier model lifecycle management. A [0.6B CustomVoice four-bit conversion](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-4bit) exists (verified, about 1.69 GB in total, so the speech codec and tokenizer dominate the saving) and would use the same implementation. |
| [Kitten TTS mini 0.8](https://huggingface.co/KittenML/kitten-tts-mini-0.8) | Small fixed-English-voice option. Limited evidence of improvement over Apple premium voices. | About 82 MB; CPU inference. No trustworthy M1 Pro measurement found. | Medium to high despite small weights. Native ONNX embedding and frontend work; reference implementation uses eSpeak NG. |

Kokoro's [voice catalogue and author grades](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)
include UK voices, but do not imply equal quality across accents. Its
[native pipeline](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/KokoroAne.md)
uses Core ML pronunciation resources, avoiding a requirement to bundle eSpeak.
Verify UK pronunciation in the selected pipeline.

Pocket's [native documentation](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/PocketTTS.md)
describes mixed GPU, CPU and ANE execution. Do not assume the whole pipeline runs on
ANE. Its [session implementation](https://github.com/FluidInference/FluidAudio/blob/main/Sources/FluidAudio/TTS/PocketTTS/Pipeline/PocketTtsSession.swift)
uses an unbounded AsyncThrowingStream. Bound work to short utterances or provide an
awaited producer/consumer boundary; dropping frames is not acceptable.

[FluidAudio's TTS benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/Benchmarks.md)
are mostly on M5 Pro with 24 GB. Kyutai's familiar 200 ms first-audio and six-times-realtime
figures describe its Python implementation on M4 MacBook Air. Neither predicts this
Mac's native performance. See also the [Supertonic pipeline](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/Supertonic3.md)
and [Qwen Swift implementation](https://github.com/Blaizzy/mlx-audio-swift/blob/main/Sources/MLXAudioTTS/Models/Qwen3TTS/README.md).

Piper is not a first choice. Its [maintained implementation](https://github.com/OHF-Voice/piper1-gpl)
is GPL-3.0 and commonly uses eSpeak. Archived MIT code does not remove phonemizer or
voice-resource obligations. Kitten mini has similar frontend concerns; its small
download does not make it the simplest integration.

## Downloads, licensing and packaging

Predefined files can be downloaded at a pinned repository commit and used offline.
[Hugging Face's download documentation](https://huggingface.co/docs/huggingface_hub/en/guides/download)
describes revisions and file filtering. The app can use native HTTP or a native
runtime downloader; users do not need the Python SDK or CLI.

Resolve the following against exact pinned artifacts before treating them as
distribution-ready. A conversion's metadata does not replace upstream terms.

| Model or resource | Finding |
| --- | --- |
| Unified, Nemotron and EOU | NVIDIA upstream model terms apply. Some conversion cards conflict with their upstream licence. [Unified upstream](https://huggingface.co/nvidia/parakeet-unified-en-0.6b), [Nemotron upstream](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b). |
| Ultra | Upstream and conversion identify CC-BY-4.0. Preserve attribution. |
| Whisper | MIT weights and native Argmax runtime. |
| Qwen3-2507, SmolLM3, Qwen3.5, Gemma4 | Apache 2.0 model families. Verify notices in the selected conversion. |
| Llama 3.2 | Custom Meta terms and gated original repository. Public conversions do not remove obligations. [Upstream card](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct). |
| Kokoro | Apache 2.0 weights. Check selected voice assets and attribution. |
| Pocket | CC-BY-4.0 weights; voice licences vary. The [original repository](https://huggingface.co/kyutai/pocket-tts) is gated with terms/contact sharing. The public conversion's distribution obligations need confirmation. |
| Supertonic-3 | [Upstream weight licence](https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE) is Open RAIL-M. Conversion metadata and runtime documentation conflict. |
| Kitten mini | Apache model/project and MIT ONNX Runtime, but GPL eSpeak NG in the reference frontend. |

EchoType currently builds with SwiftPM and manually assembles its signed app. The
bundle script copies the executable, plist and icon only. Inference dependencies can
add resource bundles, native libraries and Metal shaders that must be built, staged
and signed correctly. MLX's [installation guidance](https://github.com/ml-explore/mlx-swift)
calls out Metal shader handling for command-line builds. Check the exact pinned
release and toolchain rather than assuming current main is a drop-in dependency.

Verified on this Mac with MLX Swift 0.32.3:

- **`swift build` compiles MLX's shaders, given the Metal Toolchain.** Xcode 27 ships
  without it; `xcodebuild -downloadComponent MetalToolchain` installs it. Without it the
  build fails at the first `.metal` file. CI needs the same step.
- **The shaders arrive as a resource bundle.** The build produces
  `mlx-swift_Cmlx.bundle` containing `default.metallib` beside the executable in
  `swift build --show-bin-path`.
- **A signed app loads it from `Contents/Resources`.** A hardened-runtime bundle signed
  with Apple Development, with the bundle copied into `Contents/Resources` and `.build`
  moved away, ran a GPU computation. Without the bundle, MLX failed at its first GPU
  operation with "Failed to load the default metallib". A missing bundle fails loudly.
- **The default build system has no hidden fallback.** Swift 6.4's default build
  system generates a `Bundle.module` accessor that searches only the app's resources,
  the containing framework and the executable's directory. Only the deprecated native
  build system adds an absolute `.build` path fallback that could hide a missing
  bundle on the building Mac. `build-app.sh` should copy every `*.bundle` from the bin
  path into `Contents/Resources` before signing.

## Unanswered questions

- Which candidates improve real dictation and reading compared with Apple and xAI?
- Can warm cleanup finish within three seconds while recognition runs on the M1 Pro?
- What are combined peak memory, sustained compute, battery and thermal costs, including
  near-continuous live revision?
- How long does stopping dictation take end to end, including cancelling an in-flight
  live revision?
- How well do transcription keyterms work, rather than merely being accepted?
- Can every adapter stop, pause and finish within EchoType's current contracts?
- Are the selected conversions, voices and dependency versions suitable for automatic
  downloads without an account or separate setup?

The spike should answer these with a small paired evaluation and a signed-app check,
then recommend one fixed model set or reject the approach with recorded evidence.
