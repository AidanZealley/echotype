# Parakeet production readiness

The bench commands below are historical investigation recipes, recoverable at `2f231b9`.
Stream 4 recorded the remaining chosen-stack measurements, then retired that executable.
See [consolidated evidence](../decisions/0026-local-model-stack.md).

Investigated on 2026-10-09. The intended transcription choice is Unified EN 0.6B, 640 ms INT8, with the 110M CTC model for keyterm boosting. This note records remaining decisions rather than approving the model for release.

## Licence provenance

The [pinned CoreML conversion card](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml/blob/d32e972dd4315f1dc3f6be28fb2aab0ab3e80358/README.md) declares CC-BY-4.0 and identifies `nvidia/parakeet-unified-en-0.6b` as its base. The [current conversion card](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml) still declares CC-BY-4.0. The pinned repository's file listing contains no LICENSE or Notice file.

The [NVIDIA model card](https://huggingface.co/nvidia/parakeet-unified-en-0.6b) names the NVIDIA Open Model License as its governing terms. Our manifest already records that licence. Changing its label would not establish what permissions the conversion publisher has or satisfy notice requirements.

The [NVIDIA agreement](https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-open-model-license/) permits derivative models and additional derivative terms, subject to compliance with its underlying terms. The differing labels therefore do not by themselves prove the conversion is unusable. Section 3.1 requires recipients of distributed models to receive the agreement and a Notice text file containing "Licensed by NVIDIA Corporation under the NVIDIA Open Model License". Sections 2.1 and 2.3 contain continuing conditions, including the linked Trustworthy AI terms.

Before release, decide how EchoType's direct download installation supplies these terms and notices, and obtain a documented basis for the conversion's CC-BY claim. Maintainer confirmation or a reviewed assessment of the derivative licensing would address the provenance question. No maintainer has been contacted during this investigation. The app's installation lifecycle work owns notice delivery; this note does not claim that a licence string or link is sufficient.

For boosting, the [NVIDIA CTC card](https://huggingface.co/nvidia/parakeet-tdt_ctc-110m) and [conversion card](https://huggingface.co/FluidInference/parakeet-ctc-110m-coreml) both declare CC-BY-4.0. Include appropriate upstream and conversion attribution, licence reference and conversion identification in the release's model notices. Silero remains a separate MIT component.

## Installed loading

The spike records one boosted installed-process readiness time of 44,176 ms and ongoing CoreML cache creation/specialization. Unboosted Unified's paired time was 299 ms. These are single observations, not distributions. They do not identify a failing stage.

Source inspection of FluidAudio revision `0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7` found:

- Unified loads its encoder on CPU/ANE and decoder/joint on CPU. INT8 GPU execution is explicitly unsupported by the runtime.
- EchoType loads Unified, Silero and CTC sequentially, then warms them sequentially.
- CTC's direct loader uses CPU/ANE and synchronously loads its mel and encoder models. It attempts compilation only if direct loading throws.
- CTC warm-up constructs a boosting session, loads its tokenizer and runs rescoring on two seconds of silence. A tokenizer link points FluidAudio's fixed cache location at EchoType's installed directory.

Added per-phase monotonic timing logs to `ParakeetModel`, under subsystem `com.aidanzealley.echotype`, category `ParakeetModel`. Phases are `unified-load`, `vad-load`, `ctc-load`, `unified-warm`, `vad-warm` and `ctc-warm`. Each successful phase records `duration_ms`. These diagnostics do not change inference configuration or remove warm-up. A thrown phase is identified by the last completed phase and the existing readiness error.

At the source-investigation stage, no load-performance fix was justified. Changing compute units or removing warm-up could move the delay into dictation or change performance. The measurements below now separate first observed loading from subsequent launches.

## Verification after package changes

Build once after package resolution. Confirm all selected models are already installed before invoking the bench, since its readiness check still downloads missing models. Do not delete caches to simulate cold starts during ordinary verification.

In one terminal, capture phase timings:

```sh
log stream --level info --style json --predicate 'subsystem == "com.aidanzealley.echotype" AND category == "ParakeetModel"'
```

In another terminal, run at least three separate installed-model processes, serially and without other inference workloads:

```sh
.build/release/EchoTypeBench transcribe --provider local --candidate transcription=parakeet-unified-keyterms --fast dictation-keyterms-stack
```

Record each run's preparation time, phase timings, machine load and memory pressure. Compare with separate unboosted processes using `transcription=parakeet-unified`. `--repeat` repeats sessions inside one loaded process, so it cannot measure repeated model loading.

If the CTC loading or warming phase still costs tens of seconds, investigate the identified stage before changing its configuration. Any change affecting compute units must also recheck keyterm accuracy and inference latency. If subsequent installed loads are short, preserve the 44-second observation as first-use specialization evidence and measure enough launches to establish normal startup cost.

Final validation also needs paced boosted transcription with cleanup and Kokoro loaded together. The previous combined-memory result used unboosted Unified and cannot establish the recommended combination's memory requirement.

The initial source investigation performed no builds or inference. The following authorised local measurements complete the loading investigation; they do not resolve the licence decision or combined-set validation.

## Measured installed launches

Measured on 2026-10-09, macOS 27.2 build `26B5091g`, Apple Silicon, 16 GiB RAM. Source HEAD was `077a1ec3973cd9629c527e7f9c419c6e4263ee93`, with the working-tree phase instrumentation present. Dependencies include FluidAudio `0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7`, MLX Swift 0.32.3 and MLX Swift LM `5e46681b2adcef2db158e7b949aeae3896778e23`.

Before running, all 30 pinned files were verified by size and SHA-256: 13 Unified, five VAD and 12 CTC files. The CTC tokenizer link already pointed at the intended installed revision. Disk had 33 GiB free. Existing app and settings-demo processes were left running and untouched; process inspection found no concurrent inference or Swift build. The release bench build succeeded in 21.62 seconds, then six separate bench processes ran serially, alternating boosted and unboosted. Every process used the same recorded `dictation-keyterms-stack` sample with `--fast`.

All durations below are milliseconds. Preparation includes all loading and warm-up; it excludes sample inference.

| Order / variant | Preparation | Unified load | VAD load | CTC load | Unified warm | VAD warm | CTC warm |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 / boosted | 46,874 | 22,497.3 | 324.2 | 23,670.5 | 164.0 | 1.7 | 216.3 |
| 2 / unboosted | 322 | 135.9 | 28.4 | n/a | 155.8 | 0.9 | n/a |
| 3 / boosted | 797 | 137.0 | 28.0 | 254.0 | 149.0 | 0.8 | 227.7 |
| 4 / unboosted | 321 | 137.4 | 26.9 | n/a | 154.9 | 0.9 | n/a |
| 5 / boosted | 751 | 133.5 | 26.3 | 250.1 | 146.3 | 0.7 | 193.5 |
| 6 / unboosted | 292 | 135.2 | 26.8 | n/a | 128.6 | 0.7 | n/a |

Machine samples reported `warning` memory pressure and `nominal` thermal state throughout. One-minute load ranged from 11.33 to 7.31 across the run sequence, including the preceding build's activity. This is a working desktop measurement, not an isolated performance baseline. Sampled bench-process peak physical footprints were 107.2, 46.6, 59.6, 45.1, 60.2 and 45.3 MiB in run order. Those values exclude compiler/XPC processes and do not establish total system memory cost. All six processes exited successfully; each sample had zero stream-contract violations and no recorded error.

Run artifacts, each containing `run.json`, `preparation.json`, `sampler.json` and `transcribe.jsonl`:

- Boosted first launch: [20261009T125922Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125922Z-local>)
- Unboosted first comparison: [20261009T125924Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125924Z-local>)
- Boosted second launch: [20261009T125925Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125925Z-local>)
- Unboosted second comparison: [20261009T125926Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125926Z-local>)
- Boosted third launch: [20261009T125928Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125928Z-local>)
- Unboosted third comparison: [20261009T125929Z-local](</Users/aidanzealley/Library/Application Support/EchoTypeBench/runs/20261009T125929Z-local>)

The local diagnostic capture is `.build/parakeet-load-investigation/phases.jsonl`; the machine-readable combined measurements are `.build/parakeet-load-investigation/summary.json`. These are temporary local artifacts. The table above preserves the measurements if `.build` is cleaned.

## Loading conclusion

The tens-of-seconds delay did not persist across installed launches. On the first observed launch, almost all preparation time was in model loading, split between Unified and CTC. Warm-up was small. Subsequent boosted preparation was 751–797 ms, compared with 292–322 ms unboosted. CTC adds roughly 250 ms loading and 194–228 ms warming in these subsequent processes.

`ANECompilerService` was active while the first process loaded. This, the phase timings and the immediately fast subsequent processes support first-use CoreML/ANE specialization as the explanation. We did not trace CoreML's cache keys, so we cannot establish why the previous spike's second launch still specialized, which rebuild or system changes trigger it, or whether it recurs after reboot. No cache was deleted or moved; ordinary inference was allowed to create runtime caches.

No compute-unit change, warm-up removal or persistent cache workaround is warranted by these results. Keep the current implementation. Production setup must remain visibly loading until first-use preparation completes; installed files do not imply a subsecond first load.

The loading concern no longer requires a runtime fix before confirming boosted Unified as the intended transcription choice. Release approval still depends on licence provenance/notice handling and the planned combined-set, paced quality and signed-app checks. This one-sample loading investigation is not a new accuracy assessment or a cold-install test.
