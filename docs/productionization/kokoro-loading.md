# Kokoro loading investigation

The bench commands below are historical investigation recipes, recoverable at `2f231b9`.
Stream 4 recorded the remaining chosen-stack measurements, then retired that executable.
See [consolidated evidence](../decisions/0026-local-model-stack.md).

Date: 2026-10-09

## Conclusion

There is no established EchoType loading defect to fix yet. The spike demonstrated
both a roughly 11-second uncached preparation and a 2.5-second installed preparation
in consecutive processes. Its later cache disappearance is consistent with Core ML
specialization-cache eviction. Disk pressure is a plausible cause, not a proven one.

Keep the current loading implementation pending non-destructive measurements. Do
not delete caches, force recompilation, change compute-unit placement or add a
custom cache manager to address an unproven cause.

## Existing evidence

The [consolidated decision evidence](../decisions/0026-local-model-stack.md#speech-evidence-and-frontend-choice)
and archived spike results at `2f231b9` record:

- `20261007T114030Z-local`: download 40,220 ms, subsequent loading 11,159 ms.
- `20261007T114034Z-local`: installed loading 2,474 ms in a new process.
- The first load added 242,222,067 bytes in 66 files to the bench's Core ML cache.
  The immediately following installed run left that inventory unchanged.
- During the next Qwen speech download, the cache returned to roughly its previous
  small size. That run did not use Core ML. Around 11 GiB was free before a 2.3 GB
  download, which temporarily needed space alongside the set-aside installation.
- Other installed runs took 11 to 13 seconds, while several took 2.4 to 2.6 seconds.
  Those runs do not contain stage-level timing or a definitive eviction cause.

The archived inventories and scripts are under
`~/Library/Application Support/EchoTypeBench/logs/ws5/step5/`. The paired runs'
`preparation.json` files confirm the timings above. The existing script moved model
directories aside to measure downloads. Do not rerun it for this investigation.

The current Data volume reported 13 GiB available and 97% capacity on 2026-10-09.
Fresh measurements on this machine can establish current behaviour, but cannot
guarantee cache retention under less constrained storage conditions.

Apple describes specialization as work performed when loading a compiled model
for a device and configuration. Subsequent loads reuse that cache. The OS can
remove it after an OS update, low free disk space or deletion/modification of the
compiled model. See [Improve Core ML integration with async prediction](https://developer.apple.com/videos/play/wwdc2023/10049/)
and [Analyzing a Core ML model's performance in Xcode](https://developer.apple.com/documentation/coreml/analyzing-a-core-ml-model-s-performance-in-xcode).
The observed disk pressure and disappearance fit that behaviour. They do not
identify which condition caused this particular eviction.

## Code inspection

EchoType's `KokoroModel.load` creates missing/stale links, converts missing voice
packs, initializes one `KokoroAneManager` and synthesizes `Ready.` to warm it. The
manager remains shared across readings through the loaded local model. Neither
that path nor the bench intentionally removes Core ML execution caches.

The inspected FluidAudio revision is
`0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7`, pinned in `Package.swift`.

- `KokoroAneModelStore.loadIfNeeded` opens the seven installed `.mlmodelc` bundles
  with `MLModel(contentsOf:configuration:)`, using fixed stage compute units. It
  logs timing for each stage and retains successfully loaded models.
- Manager initialization also prepares the English G2P frontend and voice packs.
  EchoType's preparation timing includes these steps and its warmup synthesis.
  It is not exclusively the seven-stage model load.
- FluidAudio has a compatibility migration for bundles missing flexible-shape
  metadata. That can replace old model bundles and therefore invalidate caches.
  All seven currently installed pinned bundles contain the required metadata,
  so the inspected installation does not require that migration.
- Converted `.bin` voice packs are created only when absent. That conversion does
  not rewrite the Core ML model bundles.

Avoid conflating downloaded model files, FluidAudio cache links and Core ML's
device-specific execution caches. An installed model can still need specialization.

## Follow-up measurement

Run after dependency resolution and other model work finish, with no concurrent
model benchmark. Use one release binary for both runs. Confirm the installed
Kokoro payload is present, use network denial to prevent unexpected downloads,
and leave all existing model and cache files in place.

For each run, execute this same command in a new process:

```sh
sandbox-exec -p '(version 1)(allow default)(deny network*)' \
  .build/release/EchoTypeBench speak --provider local \
  --candidate voice=kokoro --voice af_heart --fast reading-ordinary-prose
```

Capture the following before, between and after the two runs:

- Available disk space and current model-inference processes.
- File paths, sizes and modification times under `~/Library/Caches/EchoTypeBench`.
- Model bundle paths and modification times, including the resolved cache links.
- Each run directory and its `preparation.json`, speech measurements and exit status.
- FluidAudio's stage-load and G2P logs, if available through unified logging.

If the first run adds specialization artifacts and the second reuses them with a
shorter preparation, that supports normal cache reuse. It does not reproduce the
earlier eviction. If both stay slow while the cache and bundles remain unchanged,
use the Core ML Instruments template to distinguish cached loading, specialization
and warmup prediction before proposing a source change. If cache files disappear
between runs, investigate OS storage reclamation and process logs first.

The signed app has its own execution context and cache. A bench result does not
establish signed-app relaunch performance. Measure that separately during release
validation, without installing or stopping a running app as part of this research.

## Production implications

Keep loading progress visible, allow an installed model to need first-use
preparation, and reuse its loaded manager across readings. Those behaviours are
already supported by the spike. The production lifecycle work should preserve them.

No runtime fork or loading-code change is justified by the current evidence.
Cache deletion is neither a fix nor a useful prerequisite for the paired check.
