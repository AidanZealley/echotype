# Local model setup, storage and release notes

Status: implemented on the productionization branch, 2026-10-10. Packaging, feature
selection and Settings/lifecycle work are accepted. Combined installed-model evidence
is recorded in the [model decision](decisions/0026-local-model-stack.md). Final signed-app
functional validation remains a separate [workflow](productionization/implementation/README.md)
acceptance gate. Public release remains held.

## Setup and readiness

Dictation installs Parakeet Unified with keyterm boosting, Silero VAD and Qwen3 cleanup
as one set. Read Aloud installs Kokoro with Heart/Emma voices. English eSpeak data ships
with the app. The [model decision](decisions/0026-local-model-stack.md) retains pinned
inputs, measured outcomes and limitations.

Selecting Local only saves that feature's provider choice. Settings shows required models,
purpose, missing download size, available space and model source/license information.
An explicit Download and prepare action installs verified files, then prepares the feature.
Show Downloading and Preparing separately. Installed files are not yet a Ready runtime.
First preparation may take tens of seconds; retain responsive UI and Cancel/Retry actions.

Install either feature or both, even before choosing Local. Installing speech does not fetch
or prepare Dictation. Status checks, Settings visits, launch and feature hotkeys never fetch
missing models. After restart/unloading, an operation can visibly prepare installed assets;
no subsecond load guarantee is implied. Ready runtimes are reused while needed.

Cancellation retains verified files for retry but prevents late publication or Ready status.
Retry reuses verified assets. Incomplete sets never count as installed. Selecting a different
provider retains downloaded files and releases unused runtimes after active work finishes.
Missing credentials/models affect only the selected feature. Cleanup unavailable at startup
retains the existing unrevised-transcription fallback with its No cleanup hint.

## Storage and removal

The managed root is `~/Library/Application Support/EchoType/Models/`. The retired bench
used this root during the spike; final measurements used isolated owned copies. Downloads are revision-specific;
incomplete files live under
`Incomplete/`. Production inventory must include installed, partial, generated and obsolete
assets, including trial pronunciation data under `espeak-english-trial-fd28f646/`.

Local Settings has separate model cards and a compact storage summary. Manage files offers
feature-specific removal, all-local-model removal and obsolete-file cleanup. Confirm affected
features and actual estimated reclaimed space. Removal preserves provider settings, keys,
preferences and assets still needed by another feature. It cannot overlap active downloads,
preparation or operations. Stop/Cancel and a reason explain disabled actions. Deletion failures
remain visible and retryable; removed models are never silently downloaded again.

FluidAudio uses fixed cache locations for some assets. The spike creates links for the CTC
tokenizer and Kokoro resources, plus generated voice packs and Core ML specialization caches.
These are different kinds of storage. The production inventory must record actual paths and
ownership; only EchoType-owned links/generated files may be removed. Never replace or delete
another tool's real cache directory. OS-managed specialization caches may be shared or omitted
from process memory/disk estimates; do not promise to reclaim data EchoType does not own.

Before uninstalling, use Manage files to remove local assets. Dragging the app to Trash leaves
its downloaded models behind. If already uninstalled, the managed Models root can be removed
when no process uses it and no model data is wanted. The current boosted Dictation tokenizer link is
`~/Library/Application Support/FluidAudio/Models/parakeet-ctc-110m-coreml`, targeting its
revision directory in the managed root. Historical speech links may remain at
`~/.cache/fluidaudio/Models/kokoro`. Remove these only if they are symbolic links whose
resolved destination belongs to EchoType's managed root, never a real directory or a link
to another installation. Runtime-generated Emma voice data is `ANE/bf_emma.bin`; Kokoro's
internal `kokoro-82m-coreml` link points at its own model directory. Feature removal accounts
for these through managed storage and ownership inventory.
Do not instruct users to remove broad FluidAudio/Core ML caches. Full settings/key reset and
an uninstall helper are outside this pass. Bench recordings/results are separate developer data.

## Build and resource requirements

MLX Swift 0.32.3 requires Xcode's Metal Toolchain on the development/CI configuration.
The spike verified `xcodebuild -downloadComponent MetalToolchain` and signed-app shader
loading. Stage dependency resource bundles, including `mlx-swift_Cmlx.bundle`, under
`Contents/Resources` before signing. Missing resources can fail only at first inference.
The production eSpeak data build must use pinned source inputs, work without the developer's
model cache or prior tests, and require no runtime compilation/download or Homebrew install.

The [speech comparison](productionization/kokoro-espeak-comparison.md) describes the historical
cache-dependent trial. Production uses a pinned build plugin to bundle English resources and
loads only the seven-stage Core ML chain, vocabulary and retained voices. Unused FluidAudio
G2P models/lexicons are obsolete storage, not required production assets.

## Licensing and public-release checks

These consolidate existing research findings, not a new legal clearance. Resolve against
exact pinned upstream/conversion artifacts before publication. A model's metadata label alone
does not establish that all distribution obligations are met.

- Unified's conversion card declares CC-BY-4.0 while NVIDIA upstream names the NVIDIA Open
  Model License. The [Parakeet report](productionization/parakeet.md) preserves sources,
  provenance questions and notice-delivery requirements. CTC is recorded CC-BY-4.0; Silero MIT.
- Qwen cleanup and Kokoro weights/voices are recorded Apache-2.0. Preserve applicable licenses,
  notices, attribution and conversion identification with the selected assets.
- eSpeak is GPLv3. The accepted personal trial did not change the repository's overall license.
  Before distributing the combined program, settle GPL-compatible licensing, corresponding
  source/build instructions and notices. The retained findings do not support a personal-only
  usage restriction on an adopted GPL release.
- Verify signing, nested resources, Developer ID/notarization and release CI separately from
  the successful Apple Development comparison build.

Public release remains held until these obligations have evidence. This does not reopen the
accepted model choice or authorize contacting maintainers, changing licenses or publishing.
The [productionization spec](specs/local-models-productionization.md) governs implementation;
the [decision record](decisions/0026-local-model-stack.md) explains the measured tradeoffs.
