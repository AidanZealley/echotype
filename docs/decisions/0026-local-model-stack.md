# 0026 A fixed local model stack with explicit setup

Status: accepted, 2026-10-09. Updated 2026-10-12 for installed loading and setup.
Public release remains held for licensing, provenance and Developer ID/notarization.

## Context and decision

Local models give EchoType offline dictation, cleanup and speech without an API key.
Ship one predefined supported set rather than model pickers or experimental candidates.
xAI remains the default provider. Users independently choose Dictation and Read Aloud
providers; Dictation keeps transcription and cleanup together.

| Purpose | Chosen model / runtime | Reason |
| --- | --- | --- |
| Transcription | Parakeet Unified EN 0.6B, 640 ms INT8, plus Silero VAD and CTC keyterm boosting; FluidAudio | Streaming fit, useful coding vocabulary, faster finalization than Whisper |
| Cleanup | Qwen3-4B-Instruct-2507, four-bit; MLX Swift LM | Conservative editing with fewer harmful deletions than tested alternatives |
| Read Aloud | Kokoro-82M v1.0 Core ML, eSpeak NG English frontend; Heart and Emma | Accepted voice quality, repeatability and substantially lower resource cost than Qwen TTS |

## Runtime and installation policy

Selecting Local loads its installed models at launch and when the selection changes.
It never downloads missing models. Local status checks only report readiness.
Dictation waits for transcription and starts cleanup loading in the background.
If cleanup is not ready when dictation starts, that dictation skips it and shows
"No cleanup". Escape or stop ends a slow preparation wait immediately. The shared
load can continue for the next operation.

Keep selected models resident. Only critical memory pressure releases the cleanup
model, and only when no dictation holds it. Warning pressure is normal with all
models loaded on the measured 16 GB M1 Pro. The next dictation starts cleanup
loading in the background again. Switching away releases unused runtimes after
active leases and setup finish, while retaining installed files.

A failed load is remembered until setup retries it from Settings. Loads check
manifest file sizes rather than hashing every model. Installation verifies size
and SHA-256. A corrupt installed set is deleted and downloaded again. Verified
files from an interrupted download remain available for retry.

Settings installs one feature at a time in request order. A queued feature shows
"Waiting for Dictation setup" or "Waiting for Read Aloud setup". Cancel removes a
waiting feature or stops the running install and load. Setup loads all of a
feature's services before completing. A feature installed while not selected is
released after setup. Installation does not select it.

Keyterm boosting applies only when the user has saved keyterms. No built-in
"EchoType" keyterm is added. The reply trigger accepts "echo type". CTC still loads
and warms with Parakeet so every dictation uses the same prepared model set.
Boosting improves vocabulary but costs finalization time and can cause false
substitutions, as the measurements below show.

[0025](0025-provider-adapters.md) owns the provider setup contract.
[0015](0015-settings-window-layout.md) owns Settings navigation.
[Local storage notes](../local-models.md) own file ownership and removal.

## Pinned inputs

These are the measured production choices. Manifests and Package.resolved own exact file
checksums and transitive dependencies; this table is an evidence/recovery reference.

| Input | Revision |
| --- | --- |
| FluidInference/parakeet-unified-en-0.6b-coreml | d32e972dd4315f1dc3f6be28fb2aab0ab3e80358 |
| FluidInference/parakeet-ctc-110m-coreml | accdafd8cf8a2ff1cabe3c11e54416b405d409aa |
| FluidInference/silero-vad-coreml | b419383c55c110e2c9271fa6ee0ea83d03c70d96 |
| mlx-community/Qwen3-4B-Instruct-2507-4bit | 50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b |
| FluidInference/kokoro-82m-coreml | 006395f65025af251858b1ab0a7178a6a1e73f9f |
| FluidAudio | 0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7 |
| MLX Swift / MLX Swift LM / swift-transformers | 0.32.3 / 5e46681b2adcef2db158e7b949aeae3896778e23 / 1.3.4 |
| eSpeak NG Swift package | fd28f6460cc4cdf631528c8e2f7bd825747aac5c |

## Evaluation limits

The evaluation ran on an M1 Pro with 16 GiB memory, macOS 27.2, Xcode 27.0 and Swift 6.4,
under variable desktop load. Cleanup's initial comparisons were debug builds; later
cleanup, local transcription and speech measurements were release builds. Apple/xAI
transcription comparisons used earlier debug runs. System memory pressure is not solely
attributable to a model, and process footprint can omit Core ML compiler/XPC costs.

Transcription used one person's recordings. References began as xAI drafts corrected by
Aidan, which favors xAI. About thirteen warm first-text observations per local pass make
p95 close to the slowest observation, not a dependable tail estimate. Cleanup had twelve
hand-written cases, eleven counted, repeated fifteen times. Repeats are not independent
inputs; scoring counted words, not punctuation or casing. Voice ratings were one listener
and one reading per passage/voice. No measured xAI voice-quality comparison was made.

## Transcription evidence and tradeoffs

| Candidate | WER | Formatted WER | Keyterm accuracy | Evidence run |
| --- | ---: | ---: | ---: | --- |
| Unified without boosting | 6.9% | 18.8% | 57.9% | 20261005T061114Z-local |
| Unified with boosting | 6.1% | 16.5% | 84.2% | 20261005T061642Z-local |
| Whisper Turbo | 2.7% | 12.5% | 94.7% | 20261005T062416Z-local |
| Apple, earlier debug | 10.0% | 19.0% | 31.6% | 20261004T083627Z-apple |
| xAI, earlier paid debug, biased references | 0.4% | 12.9% | 100.0% | 20261004T073341Z-xai |

Boosting improves vocabulary but can replace correct ordinary words. It delays stable
commitment until a roughly fifteen-second segment is rescored, including the final tail.
First committed text p50 was 8.397 seconds boosted versus 6.742 unboosted; stop-to-final
p50 was 283 ms versus 47 ms. Whisper was more accurate but slower to settle: first commit
p50 11.546 seconds and stop-to-final p50 3.383 seconds. These figures include utterance
structure and are not per-word acoustic latency. All cited local passes had zero changed
committed prefixes, stream-contract violations and recorded errors.

A process-kill download recovery installed and verified Unified in run
20261005T072301Z-local. Offline transcription completed; Whisper's fast offline and online
outputs differed on three samples. These findings do not prove universal determinism.

The original boosted installed-load concern was 44.176 seconds in
20261005T071726Z-local. On 9 October, six alternating fresh-process checks found first
boosted preparation 46.874 seconds, then 797 and 751 ms; unboosted took 322, 321 and 292 ms.
The slow run split almost evenly between Unified and CTC loading, with little warm-up.
Compiler activity supports specialization, without proving cache causality. Keep the current
runtime. These are preparation timings, not hotkey timings. In the first run,
Unified loading took 22.497 seconds and CTC loading 23.671 seconds. Subsequent
CTC loading took 250 to 254 ms and warming 194 to 228 ms. `ANECompilerService` was
active during the slow run. No cache was deleted or moved. These observations do
not prove which rebuild, system change or cache eviction causes specialization.

## Cleanup evidence and tradeoffs

Qwen and xAI produced the same final words on all eleven counted cases: 120/165 exact,
zero wrong-deleted words and 150 missed-edit words in paced runs 20261004T110130Z-local
and 20261004T121048Z-xai. Apple had 75/165 exact and 300 wrong-deleted words; SmolLM3 had
105/165 exact, fifteen wrong-deleted words and sixty validation rejections. The small corpus
cannot establish Qwen/xAI parity in general dictation.

Qwen retained three under-edited inputs. On the command-following case its reply hit the
output cap, and EchoType safely kept the original words. Subsequence validation cannot
prevent every harmful deletion; output caps, cancellation and conservative fallbacks remain
important. Speculative decoding and constrained decoding were researched but not justified
by the measured deadline or rejection rates.

Release cleanup run 20261005T063709Z-local retained 120/165 exact with zero deadline
fallbacks/overruns. Warm stop-to-insert p50/p95 was 561/1699 ms; cancellation 143/213 ms.
Preparation was 4.043 seconds, peak footprint 2591 MiB and ready 2397 MiB. Concurrent
boosted Dictation plus cleanup in 20261005T064539Z-local had warm stop-to-insert
1240/2716 ms, zero deadline fallbacks/overruns and peak footprint 2781 MiB. This does not
prove cancellation during an over-budget prefill. Older MLX pins and Qwen TTS
residency confounded intervening measurements. The combined runs below revalidated
the restored chosen pins.

## Speech evidence and frontend choice

Aidan preferred Kokoro Heart over the tested Apple premium voices and found Qwen Ryan
highly realistic but inconsistent. Historical Heart short-passage first audio p50/p95 was
206/267 ms in 20261007T101313Z-local; Ryan 241/489 ms in 20261007T101342Z-local. The old
Kokoro frontend had article, number, technical-term and context-free heteronym problems.
Those ratings and timings describe the old frontend, not a quality score for the new one.

The always-weak article correction was rejected before vowels. Aidan accepted the
phrase-aware eSpeak comparison on 9 October. It retains written-form normalization,
explicit a.m./p.m. preparation. A dotted meridiem after a valid 12-hour clock is
prepared as letter names before sentence splitting. Ambiguous prose is left alone.
The phrase-aware frontend adapts eSpeak phonemes to Kokoro's Misaki alphabet.
One actor serializes process-global accent selection and conversion. Phonemes split
at word or punctuation boundaries to stay within 510 Unicode scalars. The earlier
word-by-word frontend could not distinguish "the" from "thee" or use following
sound context. No maintained FluidAudio fork was needed.

The accepted comparison smoke run `20261009T111948Z-local` synthesized pronunciation
and number passages twice through Heart. Real-time factor was 0.06 and first audio
331 to 730 ms after readiness, with no recorded violations. It was not a controlled
speed comparison. Production-resource checks later loaded the seven stages in
10.89 seconds, then 1.44 seconds in subsequent processes. An isolated signed host
produced finite 24 kHz audio with networking denied. These checks do not establish
full-app launch latency.

Earlier Kokoro installed loads took 11 to 13 seconds or 2.4 to 2.6 seconds. Paired runs
`20261007T114030Z-local` and `20261007T114034Z-local` took 11.159 and 2.474 seconds.
The first added 242,222,067 bytes of Core ML cache in 66 files. Cache disappearance
during a later unrelated download supports possible eviction under disk pressure,
without proving its cause. Keep the loader and warm-up. No custom cache manager or
compute-unit change is justified by this evidence.

Historical Kokoro synthesis was about sixteen times real time versus Qwen's 1.8. The
reference set with unboosted Unified, cleanup and Kokoro peaked at 3062 MiB, ready 2806 MiB,
in 20261007T104327Z-local. This did not measure the complete chosen boosted set.
The benchmark's audio-ready-after-pause number did not measure total buffered production;
boundedness relies on stream design/tests, with footprint only supporting evidence.

## Alternatives and remaining checks

Whisper, SmolLM3 and Qwen TTS were removed with their candidate-selection machinery.
Qwen Ryan sounded realistic but its tone, laughs and sighs were inconsistent.
A fixed calm narration instruction made no useful difference in Aidan's audition.
The tested `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-4bit` revision was
`f35faf19b0cc2160865af64ecf0f22f83d335135`, with MLX Audio Swift
`bf14ae0c26e4e85553dd989571cae29d70fa6735`. It downloaded 2,311,984,361 bytes.
Installed loading took 1.4 seconds in one run. Voice-only memory was about 2.5 GiB
ready and 2.9 GiB peak. The combined unboosted set reached 4,775 MiB ready and
5,201 MiB peak with critical pressure in `20261007T104448Z-local`.

Three of eight Ryan listening passages ended at the runtime's codec-step cap.
Generation cancellation had no awaitable completion handle, so teardown could
race shared codec state. Its dependency forced older MLX pins across cleanup.
These are reasons to reject that revision even if future voice consistency improves.
No lower-temperature, fixed-seed, cloning or VoiceDesign comparison was measured.

Pocket was replaced by Qwen in auditions. Supertonic, Kitten, other Parakeet variants,
Qwen3.5, Gemma and Llama were research options, not evaluated candidates.

Historical chosen manifests totaled 3,084,340,346 download bytes and about 3.11 GB allocated
installed data. Those totals included old Kokoro frontend assets and exclude external
specialization caches; production UI must calculate actual revised manifest requirements.
The current UI calculates requirements from the supported manifests.

First load after reboot or OS update, energy and output-device latency remain
unmeasured. Licensing and release checks below remain open.

## Accepted signed-app evidence, 2026-10-11

Physical Local capture followed by the next Dictation shortcut inserted a paragraph
into a previously blank TextEdit target and settled idle. Paragraph fidelity was
not measured. Silence only showed Paused; it did not commit text. Other checks
covered physical xAI Dictation with Local Read Aloud selected, audible xAI MCP
speech with Local Dictation selected, offline audible Local MCP completion,
captured-provider lease protection, physical Escape and settled controls.
Successful Local selection-reading hotkey playback is not claimed. These checks
precede the current loading and Settings changes.

## Combined-model measurements, 2026-10-10

Serial release runs revalidated the restored pins and feature preparation with
installed models in a separate home. All declared files matched manifest sizes and
SHA-256. All fifteen recordings and reviewed references were present. Networking
and access to the user's real models, caches and preferences were denied. No
download or paid request ran. These measurements precede retirement of the bench
and do not verify the final signed app.

| Run | Configuration and result |
| --- | --- |
| `20261010T121805Z-local` | Paced boosted Dictation + cleanup, keyterms-stack. Preparation 57.704 s; stop-to-final 309 ms; no errors/violations. Peak bench footprint 4103 MiB; system pressure critical during this first isolated preparation. |
| `20261010T121826Z-local` | Fast cleanup, all twelve cases with production Dictation resident. 8/11 counted exact, no wrong deletions, 13 missed edits, one safe fallback, no deadline failures. Preparation 5.492 s. |
| `20261010T121854Z-local` | Fast Heart ordinary prose. Preparation 11.562 s; first audio 310 ms; 9.3 s audio; RTF 0.07; no violations. |
| `20261010T121907Z-local` | Combined boosted Parakeet, Qwen cleanup and Kokoro resident; four recordings twice, paced Dictation. Preparation 7.436 s; warm stop-to-insert p50/p95 1114/1447 ms, transcription 278/297 ms, cleanup 818/1150 ms. Peak/ready bench footprint 4482/2747 MiB; system pressure warning; zero deadline failures/errors/violations. |
| `20261010T122021Z-local` | Same combined residency; all twelve cleanup cases twice, paced. 16/22 counted exact, zero wrong deletions, 20 missed edits, two safe output-cap fallbacks, no validation rejections/deadline failures. Warm stop-to-insert p50/p95 658/1844 ms; cancellation 155/177 ms. Preparation 7.945 s; peak/ready footprint 4486/2745 MiB; system pressure warning. |
| `20261010T122339Z-local` | Same combined residency; Heart long reading, speed 1, pause/resume and cancellation, with explicit speech teardown join before lease release. Preparation 7.372 s; first audio 260 ms; 58.0 s audio, 583 chunks, maximum 100 ms, zero gaps/errors/violations. Pending-pull cancellation 0.055 ms, then joined teardown. Peak/ready footprint 4490/2746 MiB; system pressure normal. |

`20261010T122141Z-local` was superseded by the last speech run because its caller
had not joined speech teardown.

The combined Dictation pass had 6.1% WER, 9.8% formatted WER and 18/22 keyterms across
four distinct recordings repeated twice. Its technical-word errors include Vite/shadcn;
boosting also changed "tests are failing" to "tests are Tailwind". Cleanup preserves such
recognition errors rather than inventing replacement words. Three cleanup inputs remain
under-edited, matching the historical limitation. The corpus and repeats remain too small
for reliable tail estimates or general quality claims. Paced speech's measured pull time
is not total synthesis time or a read-ahead bound; the stream contract tests establish
bounded chunks and teardown, while pause memory is only supporting evidence.

These runs used MacBookPro18,3, macOS 27.2, with variable desktop load. System thermal
state stayed nominal. Load median/max was 12.04/13.90 for combined Dictation,
8.61/10.59 for combined cleanup and 6.01/6.44 for final speech. Process footprint omits
compiler/XPC costs and is not the combined set's total system memory. Initial specialization,
background pressure and cache reuse confound preparation comparisons. No first-load after
reboot, energy, output-device latency or broad speech-quality study was performed.

## Build and release checks

MLX Swift 0.32.3 needs Xcode's Metal Toolchain. Dependency bundles, including
`mlx-swift_Cmlx.bundle`, must be staged under `Contents/Resources` before signing.
Missing shader resources can fail at first inference.

A SwiftPM plugin compiles English pronunciation resources from the pinned eSpeak
source and library. The runtime reads `EnglishPronunciation.bundle` through
`Bundle.module`. It needs no runtime compiler, Homebrew installation or developer
model cache. Kokoro loads only its seven-stage Core ML chain, vocabulary and Heart
and Emma voices. It bypasses FluidAudio's unused G2P initialization. The signed
release packaging check on 10 October measured 72,048 KiB allocated for the app,
including 928 KiB of compiled pronunciation resources. No eSpeak source bundle
was staged.

The pinned [Unified conversion card](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml/blob/d32e972dd4315f1dc3f6be28fb2aab0ab3e80358/README.md)
declares CC-BY-4.0 and identifies NVIDIA's model as its base, but its repository
contains no license or Notice file. The [NVIDIA model card](https://huggingface.co/nvidia/parakeet-unified-en-0.6b)
names the NVIDIA Open Model License. Different labels do not establish the
conversion's provenance. Before release, document a basis for the conversion's
license claim and how direct-download installation delivers required terms and
notices. The [NVIDIA agreement](https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-open-model-license/)
requires agreement and Notice delivery under section 3.1 and has continuing
conditions under sections 2.1 and 2.3. No maintainer confirmation was obtained.

CTC is recorded CC-BY-4.0 and Silero MIT. Qwen cleanup and Kokoro weights and voices
are recorded Apache-2.0. Preserve licenses, notices, attribution and conversion
identification for exact pinned assets. Metadata labels alone do not settle
release obligations.

eSpeak is GPLv3. Its license ships in the pronunciation resources and app notices.
The repository's license has not changed. Public distribution still needs a
GPL-compatible combined-program license, corresponding source, build instructions
and notices. Audio acceptance did not settle these obligations.

Verify nested resources, Developer ID signing, notarization and release CI before
publication. Apple Development builds and isolated signed-host checks do not
establish public-release readiness.

## Evidence recovery

Full evaluation research and results remain in commit `2f231b9`. Historical raw
runs are under `~/Library/Application Support/EchoTypeBench/runs/`, with listening
ratings and audio under `~/Library/Application Support/EchoTypeBench/listening/`.
They are local artifacts, not checked-in fixtures. This record retains the
conclusions if those files are lost.
