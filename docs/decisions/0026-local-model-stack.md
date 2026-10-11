# 0026 A fixed local model stack with explicit setup

Status: accepted choices, 2026-10-09. Production implementation is pending the
[workflow](../productionization/implementation/README.md). This record consolidates
useful spike findings; it does not claim the production acceptance checks have passed.

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

Setup explicitly downloads, verifies and prepares requested features before showing Ready.
Aidan accepts a long initial preparation in that flow. Status checks never initiate setup.
The selected runtime is reused; after restart or unloading, visible preparation may recur.
The [productionization spec](../specs/local-models-productionization.md) owns exact product
behavior. It supersedes 0025's single-provider selection rule for this planned implementation;
0025's adapter/service boundaries remain relevant.

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

The spike ran on an M1 Pro with 16 GiB memory, macOS 27.2, Xcode 27.0 and Swift 6.4,
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
runtime. The [loading report](../productionization/parakeet.md) retains phase timings,
verification, run ids, license provenance and limits. These are preparation, not hotkey, timings.

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
prove cancellation during an over-budget prefill. The moved older MLX pins and Qwen TTS
residency confounded later measurements; revalidate the restored chosen pins.

## Speech evidence and frontend choice

Aidan preferred Kokoro Heart over the tested Apple premium voices and found Qwen Ryan
highly realistic but inconsistent. Historical Heart short-passage first audio p50/p95 was
206/267 ms in 20261007T101313Z-local; Ryan 241/489 ms in 20261007T101342Z-local. The old
Kokoro frontend had article, number, technical-term and context-free heteronym problems.
Those ratings and timings describe the old frontend, not a quality score for the new one.

The always-weak article correction was rejected before vowels. Aidan accepted the
phrase-aware eSpeak comparison on 9 October. It retains written-form normalization,
explicit a.m./p.m. preparation, serialized accent switching and bounded phoneme chunks.
The [comparison record](../productionization/kokoro-espeak-comparison.md) retains the
accepted audition, smoke measurements and remaining reproducible-packaging work.
The [loading report](../productionization/kokoro-loading.md) retains Kokoro's observed
11–13 second versus 2.4–2.6 second loads; cache eviction is plausible, not proven.

Historical Kokoro synthesis was about sixteen times real time versus Qwen's 1.8. The
reference set with unboosted Unified, cleanup and Kokoro peaked at 3062 MiB, ready 2806 MiB,
in 20261007T104327Z-local; Qwen speech raised the combination to 5201 MiB and critical
pressure in 20261007T104448Z-local. Neither measured the complete chosen boosted set.
The benchmark's audio-ready-after-pause number did not measure total buffered production;
boundedness relies on stream design/tests, with footprint only supporting evidence.

Signed-app checks covered Kokoro playback, speed, pause/resume, stop, MCP speech and offline
reading. Earlier Dictation checks waived switching away during download; the boosted model
was not the auditioned default. Qwen's incomplete reading was also waived for the spike,
not accepted for production. Those waivers do not carry into production acceptance.

## Alternatives and remaining checks

Remove Whisper/WhisperKit, SmolLM3, Qwen TTS/MLX Audio Swift and candidate selection machinery.
Preserve the [Qwen voice follow-up](../specs/qwen-tts-follow-up.md) instead of dormant code.
Pocket was replaced by Qwen in auditions. Pocket, Supertonic, Kitten, other Parakeet variants,
Qwen3.5, Gemma and Llama were research options, not evaluated production candidates.
Their old estimates and source survey remain available in the archive if needed.

Historical chosen manifests totaled 3,084,340,346 download bytes and about 3.11 GB allocated
installed data. Those totals included old Kokoro frontend assets and exclude external
specialization caches; production UI must calculate actual revised manifest requirements.
Kokoro's first load generated about 242 MB of bench cache. Setup/storage requirements and
release obligations are consolidated in [local models](../local-models.md).

Still validate the full boosted/cleanup/speech set, signed-app loading and offline isolation,
provider switches, cancellation and owned removal. First load after reboot/OS update, energy,
output-device latency and Developer ID notarization remain unmeasured. Resolve the recorded
Parakeet provenance and eSpeak public-release obligations before publication.

## Productionization measurements, 2026-10-10

Before retiring the bench, serial release runs revalidated the restored pins and production
feature preparation/leases at `868f5ea3e839f3510afa68a9aef3eb7966f100b5` plus stream 4
uncommitted changes. No model choice changed. All declared installed files matched manifest
sizes and SHA-256, including the 37-file Kokoro copy retained by stream 1. All fifteen
recordings and reviewed references were present. No download or paid provider request ran.

Validation copied models/recordings into
`.build/local-productionization/validation-home/Library/Application Support/`.
`CFFIXED_USER_HOME` redirected Foundation home, Application Support and Caches there.
`sandbox-exec` denied networking and access to the user's real model, FluidAudio, bench,
cache/preferences directories and `/Applications/EchoType.app`. Real user models,
recordings, results, preferences, credentials and inspection processes were preserved.

| Run | Configuration and result |
| --- | --- |
| `20261010T121805Z-local` | Required paced boosted Dictation + cleanup, keyterms-stack. Preparation 57.704 s; stop-to-final 309 ms; no errors/violations. Peak bench footprint 4103 MiB; system pressure critical during this first isolated preparation. |
| `20261010T121826Z-local` | Required fast cleanup, all twelve cases with production Dictation resident. 8/11 counted exact, no wrong deletions, 13 missed edits, one safe fallback, no deadline failures. Preparation 5.492 s. |
| `20261010T121854Z-local` | Required fast Heart ordinary prose. Preparation 11.562 s; first audio 310 ms; 9.3 s audio; RTF 0.07; no violations. |
| `20261010T121907Z-local` | Combined boosted Parakeet, Qwen cleanup and Kokoro resident; four recordings twice, paced Dictation. Preparation 7.436 s; warm stop-to-insert p50/p95 1114/1447 ms, transcription 278/297 ms, cleanup 818/1150 ms. Peak/ready bench footprint 4482/2747 MiB; system pressure warning; zero deadline failures/errors/violations. |
| `20261010T122021Z-local` | Same combined residency; all twelve cleanup cases twice, paced. 16/22 counted exact, zero wrong deletions, 20 missed edits, two safe output-cap fallbacks, no validation rejections/deadline failures. Warm stop-to-insert p50/p95 658/1844 ms; cancellation 155/177 ms. Preparation 7.945 s; peak/ready footprint 4486/2745 MiB; system pressure warning. |
| `20261010T122339Z-local` | Same combined residency; Heart long reading, speed 1, pause/resume and cancellation, with explicit speech teardown join before lease release. Preparation 7.372 s; first audio 260 ms; 58.0 s audio, 583 chunks, maximum 100 ms, zero gaps/errors/violations. Pending-pull cancellation 0.055 ms, then joined teardown. Peak/ready footprint 4490/2746 MiB; system pressure normal. |

`20261010T122141Z-local` is provisional and superseded by the last speech run because
its legacy bench caller had not yet joined speech teardown. Raw artifacts remain for audit.
Bench builds passed in 23.23 s and 21.70 s after the teardown correction. Source/package
hash inventories, logs, sandbox and raw runs remain under `.build/local-productionization/`.
Run directories retain configuration, preparation, trace, machine samples, reports and audio.
These measurements precede retirement and do not verify the final signed production app.

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

## Evidence recovery

Full research, results and completed workflow records are preserved in spike commit
`2f231b9` on `spike/local-models`; they are intentionally absent from the production tree.
Read them without restoring them:

```sh
git show 2f231b9:docs/spikes/local-models/results.md
git show 2f231b9:docs/spikes/local-models/research.md
git ls-tree -r --name-only 2f231b9 docs/spikes/local-models
```

Historical raw runs are under `~/Library/Application Support/EchoTypeBench/runs/`; listening
ratings/audio under `~/Library/Application Support/EchoTypeBench/listening/`. These are local
artifacts, not checked-in fixtures. Losing those files does not erase the archived conclusions.
The productionization cleanup records remaining measurements, then retires the model bench
before merging. The [testing follow-up](../specs/app-testing.md) starts independently.
