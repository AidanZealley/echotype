# Workstream 2: Local cleanup candidates

Status: accepted.

## Task packet

### Outcome

`swift run EchoTypeBench cleanup --provider local --candidate cleanup=<name>` downloads the
candidate's pinned weights on first use, loads and warms the model, and runs every cleanup sample
through the real `Reviser` with on-device MLX inference, for both `qwen3-4b-2507` and
`smollm3-3b`. A signed debug app bundle builds with MLX's resources staged.

### Scope

- **Dependencies.** Add MLX Swift LM (and through it MLX Swift) to `EchoTypeCore`, pinned to
  revisions that build with Swift 6.4 and the macOS 26 target. Research verified MLX Swift
  0.32.3 with MLX Swift LM at `5e46681`; start there. Record the pins and why in the handoff.
- **Packaging.** `scripts/build-app.sh` copies every `*.bundle` from the build's bin path into
  `Contents/Resources` before signing. CI downloads the Metal toolchain
  (`xcodebuild -downloadComponent MetalToolchain`) before building. See the spec's "Build
  verification".
- **Provider.** Under `Sources/EchoTypeCore/Providers/Local/`: the provider description, and
  `LocalCandidates.swift`, which holds both cleanup candidates' configuration and the build's
  selection and assembles the provider. Follow the plan's local provider contract, the spec's
  "Provider and candidate selection" and decision 0025's "Adding a provider". No new adapter
  protocol or factory framework.
- **Manifests.** One pinned manifest per candidate for the store from workstream 1. Resolve the
  full commit revision of `mlx-community/Qwen3-4B-Instruct-2507-4bit` and
  `mlx-community/SmolLM3-3B-4bit`, list only the files MLX Swift LM needs to load each, and
  record every file's size and SHA-256. Confirm and record each conversion's licence notice.
- **Readiness.** Cleanup is `.waiting` with download or loading progress in the message, such
  as "Downloading models, 1.2 of 3 GB" or "Loading the cleanup model", `.ready` only once the
  model is loaded and warmed, and `.unavailable` with the store's message on failure. A check
  starts setup by contract. Only the selected candidate is prepared.
- **Cleanup implementation,** shared by both candidates, following the spec's "Native
  integration" cleanup paragraph:
  - send `Reviser`'s prompt and window unchanged and return plain text;
  - greedy sampling, output capped near the window's token count;
  - SmolLM3's thinking disabled through its chat template's real flag;
  - the fixed prompt's KV cache prefilled once per loaded model and copied into each fresh
    request, with no history carried between requests;
  - cancellation checked between generation steps and during prompt prefill;
  - loaded weights reused across requests, inference kept off the main actor, and MLX's buffer
    cache limit set so cached buffers do not inflate the process footprint.
- **Bench.** `--provider local` and `--candidate cleanup=<name>` per the plan's bench arguments
  contract, with `run.json` recording the provider and candidate selection.
- Fixture tests only where logic is testable without a model, such as the output cap.

### Non-goals

- Registering the provider in `Providers.all`, Settings or any app UI.
- Local transcription or read aloud.
- Draft-model speculation, constrained decoding, or any cleanup prompt change.
- Measurement features (repeats, memory sampling, timing breakdowns); workstream 3 owns them.
- Changing the model store's behaviour; escalate a defect in it.

### Initial ownership

- `Package.swift` and `Package.resolved`.
- `Sources/EchoTypeCore/Providers/Local/`, except the workstream 1 store files.
- `scripts/build-app.sh` and `.github/workflows/ci.yml`.
- `Sources/EchoTypeBench/RunOptions.swift`, `RunInfo.swift` and `main.swift` (usage text).
- New focused tests under `Tests/EchoTypeCoreTests/`.

### Required seams

- Consumes workstream 1's store unchanged.
- Produces the plan's local provider, candidate names and bench arguments contracts, which
  workstreams 3 and 4 rely on.

### Acceptance criteria

1. The bench command in the outcome completes all 12 cleanup samples for each candidate with
   `--fast`, after downloading and verifying the weights on the first run.
2. A second run starts from the installed files without downloading.
3. Cleanup readiness reports download and loading progress, and reaches `.ready` only after the
   model is warmed.
4. Every manifest names a full commit revision, licence and per-file size and SHA-256, and lists
   only required files.
5. `run.json` for a local run records the provider and the cleanup candidate.
6. `Provider.local` is not in `Providers.all`; its transcription and voice report
   `.unavailable`.
7. Code outside `Providers/Local/` and the bench names no local candidate or model.
8. `scripts/build-app.sh debug` produces a bundle whose `Contents/Resources` holds MLX's resource
   bundle, and `codesign --verify` accepts it.
9. `swift test` and the release build of `EchoTypeApp` still pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast
swift run EchoTypeBench cleanup --provider local --candidate cleanup=smollm3-3b --fast
scripts/build-app.sh debug .build/local-cleanup/EchoType.app
codesign --verify --deep --strict .build/local-cleanup/EchoType.app
ls .build/local-cleanup/EchoType.app/Contents/Resources
```

The first two bench runs download about 2.3 GB and 1.8 GB. Do not launch the built app.

## Implementation handoff

- Base commit: `660d37033ecbb4ad64eebd7aba4ef8b3b169fe88`
- Outcome: `swift run EchoTypeBench cleanup --provider local --candidate cleanup=<name> --fast`
  completed all 12 cleanup samples for both candidates on the M1 Pro (Xcode 27.0, Swift 6.4,
  macOS 27.2). The first run of each downloaded and verified its weights (about 1 minute each);
  later runs showed no download lines. `run.json` records `"candidates": {"cleanup": "<name>"}`.
  All acceptance criteria are met. Observed on this run, not a measurement: stop-to-insert was
  0.3 to 2.0 s per sample (qwen3 up to 1973 ms on the long unpunctuated sample, smollm3 up to
  1613 ms), with 1 fallback for qwen3 and 2 for smollm3 (see limitations).
- Files changed:
  - New, `Sources/EchoTypeCore/Providers/Local/`:
    - `LocalCandidates.swift`: public `LocalSelection` (the build's selection, `cleanup` only for
      now), `CleanupCandidate`, both candidates with their manifests and template context, the one
      shared `ModelStore`, `Provider.local` and `Provider.local(_ selection:) throws`.
    - `LocalProvider.swift`: the provider description. Transcription and voice are
      `.unavailable` and throw `ProviderError.unavailable`.
    - `LocalCleanup.swift`: one candidate's download, load and readiness, and the
      `CleanupService`.
    - `CleanupModel.swift`: the MLX implementation, plus a 25-line bridge from swift-transformers'
      tokenizer to MLX Swift LM's contract (the `MLXHuggingFace` macros would pull in a macro
      build for the same code).
  - New, `Tests/EchoTypeCoreTests/LocalCleanupTests.swift` (4 tests, no model, no network).
  - Edited: `Package.swift`, new `Package.resolved` (commit it), `scripts/build-app.sh`,
    `.github/workflows/ci.yml`, `Sources/EchoTypeBench/{RunOptions,RunInfo,main}.swift`, and one
    line each in `Cleanup.swift` and `Transcribe.swift`, which are outside the listed ownership
    but call `RunInfo.begin`, whose signature gained `candidates:`.
- Interface for workstreams 3 and 4:
  - `--provider local` and `--candidate cleanup=<name>`. An unknown name fails with
    `Unknown cleanup candidate x. Known: qwen3-4b-2507, smollm3-3b.`. `RunOptions.localSelection`
    starts as `LocalSelection.build` and `RunOptions.recordedSelection` is nil for other
    providers. To add `--candidate transcription=` or `voice=`, add a field to `LocalSelection`
    (it is `Codable`, and `run.json` encodes it as `candidates`).
  - `LocalCleanup.check()` and `changes()` back `Readiness`. Messages: `Downloading models, 1.2 of
    2.3 GB`, `Loading the cleanup model`, `.ready` after load and warm-up, or the store's message
    as `.unavailable`. `changes()` merges the store's stream with the load finishing.
  - `Provider.local` is not in `Providers.all`. `Provider.local.id` is `local`.
- Decisions:
  - **Tokenizer.** MLX Swift LM at this revision has no tokenizer or downloader. It takes a
    `TokenizerLoader`, so `swift-transformers` (`Tokenizers`, which brings swift-jinja for the
    chat template) is a direct dependency and `CleanupModel.swift` bridges it. No downloader is
    used: weights come from `ModelStore` and load from its directory with
    `LLMModelFactory.shared.loadContainer(from:using:)`.
  - **Loading and the store.** `check()` starts a download only when the state is `.missing`, so a
    failed download stays `.unavailable` until relaunch (plan convention). The load runs in an
    unstructured `Task` the object owns; there is no cancel. One `ModelStore` per process lives
    in `LocalCandidates.store`.
  - **Prompt cache.** At load, the system-prompt tokens are the common prefix of the chat
    template applied to two probe windows, run through the model once. Each request copies that
    cache (`KVCache.copy()`), prefills only the rest and generates with `TokenIterator`
    and `generateTask`. A request whose tokens do not start with the prefix (SmolLM3's template
    prints today's date, so this can happen after midnight in a long-lived process) prefills
    everything instead; nothing is rebuilt. Observed reuse: prefix 162 tokens of 173 to 181.
  - **Cancellation.** Prefill steps are 128 tokens so MLX's chunked prefill checks cancellation
    between forwards, and the token loop stops on task cancellation. Measured by the cancelled
    live revisions in the bench: 0.00 to 0.15 s. The one uncancellable unit is a forward of up to
    128 tokens.
  - **Output cap.** `windowTokens + windowTokens / 4 + 16` generated tokens. A reply that hits the
    cap throws `ProviderError.failed`, because `Reviser` accepts any in-order subset of the
    window and would otherwise insert text that silently lost its end. This is what rejected
    the "write a poem" command sample (it counts as a fallback, which is correct).
  - **Thinking.** SmolLM3's template flag is `enable_thinking`, passed as chat template context
    (`false`). Qwen3-4B-Instruct-2507's template has no flag.
  - **Serial access.** `ModelContainer.perform` runs one request at a time, and the prefix cache
    is touched only inside it.
  - **Buffer cache.** `MLX.Memory.cacheLimit` is set to 64 MiB when a model loads. It is process
    wide, not per model.
  - **Bundles.** `build-app.sh` copies every `*.bundle` beside the executable. The debug bundle
    holds `mlx-swift_Cmlx.bundle` (MLX's Metal library) and also `swift-crypto_Crypto.bundle` and
    `swift-transformers_Hub.bundle`, which arrive through the new dependencies.
- Dependency pins and model revisions:
  - `mlx-swift` exactly 0.32.3 (`19601207e9a0de51e03ee6ec0c3c5f3784275075`).
  - `mlx-swift-lm` revision `5e46681b2adcef2db158e7b949aeae3896778e23`, six commits after its
    tag 3.32.3 (`3b339ad`), so it is pinned by commit. It needs mlx-swift `~> 0.32.3`.
  - `swift-transformers` exactly 1.3.4 (`c21fdcde390313a6d98d8e33a346f2c3486c3ab0`), which
    resolved swift-jinja 2.5.1, swift-huggingface 0.12.0, swift-crypto 4.5.2, swift-syntax
    603.0.2 and others; `Package.resolved` records all. swift-syntax is resolved (mlx-swift-lm
    declares it for macros) but not built, because no macro product is used.
  - Qwen3: `mlx-community/Qwen3-4B-Instruct-2507-4bit` at
    `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b`, Apache-2.0. The conversion's README front matter
    says `license: apache-2.0` and links the upstream LICENSE; upstream `Qwen/Qwen3-4B-Instruct-2507`
    ships a LICENSE file. Files: `config.json`, `generation_config.json`, `tokenizer_config.json`,
    `chat_template.jinja`, `tokenizer.json`, `model.safetensors`: 2,274,455,727 bytes in total.
  - SmolLM3: `mlx-community/SmolLM3-3B-4bit` at `d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce`,
    Apache-2.0. The conversion's README says `license: apache-2.0`; upstream
    `HuggingFaceTB/SmolLM3-3B` declares apache-2.0 in its card metadata and has no LICENSE file.
    The same six files: 1,747,319,274 bytes in total.
  - Sizes and SHA-256 come from the Hugging Face API for the LFS files and from downloading the
    rest at the pinned revision. The store verified every file on both real downloads. Left out
    as unneeded: `model.safetensors.index.json` (the loader falls back to `model*.safetensors`),
    `special_tokens_map.json`, `added_tokens.json`, `vocab.json`, `merges.txt`, `README.md`.
    Both models loaded and ran without them.
- Verification: all passed.
  - `swift build`, `swift test` (core 134 tests, bench 12, app 76), and
    `swift build -c release --product EchoTypeApp`.
  - Both bench commands, 12 of 12 samples each. The first run of each downloaded (qwen3 about 2.3
    GB, smollm3 about 1.7 GB, about a minute each or less on this connection); reruns did not download.
  - `scripts/build-app.sh debug .build/local-cleanup/EchoType.app` succeeded;
    `codesign --verify --deep --strict` exited 0; `Contents/Resources` holds `AppIcon.icns`,
    `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle` and `swift-transformers_Hub.bundle`.
    The app was not launched.
  - `--candidate cleanup=bogus` fails with the known names. After the final simplification both
    benches and the packaging were run again.
- Known limitations or external checks:
  - Loading MLX inside the signed, installed app is unverified (the plan's pending item); this
    workstream only checks that the bundle is staged and signed.
  - CI's new Metal toolchain step runs only once the branch is pushed. The toolchain is already
    installed on this Mac.
  - Fallbacks seen: both candidates hit the length cap on the "write a poem" sample (the model
    tries to follow it); smollm3 also fell back on `cleanup-question-not-answered`. Quality is
    workstream 4's to judge.
  - The bench prints one `Waiting: Downloading models...` line per 1% of progress (existing
    `requireReady` behaviour; about 100 lines per download).
  - The models occupy 3.8 GB under `~/Library/Application Support/EchoType/Models/` on this Mac.
  - A download interrupted mid-file restarts that file (store behaviour).
- Specification drift: the spec names MLX Swift LM (and through it MLX Swift) as the dependency,
  but tokenizing and the chat template need `swift-transformers`, a third direct dependency,
  because the library no longer bundles a tokenizer. The research-verified commit `5e46681` has
  no tag, hence the revision pin.

## Independent review

- Reviewer: independent review agent (Sonnet 5.5), read-only apart from this section.
- Verdict: Accept. No Required findings; every acceptance criterion is met on the evidence below.
- Checks run (uncommitted tree on base `660d370`):
  - `swift build`, `swift test` (core 134, bench 12, app 76, all passed) and
    `swift build -c release --product EchoTypeApp` all succeed.
  - `swift run EchoTypeBench cleanup --provider local --candidate cleanup=qwen3-4b-2507 --fast` and
    `...=smollm3-3b --fast`: 12 of 12 samples each, no download lines (weights were installed), so
    the "second run starts from installed files" half of criteria 1 and 2 is observed. Fallbacks
    were 1 (qwen3: poem command) and 2 (smollm3: poem command, question) as the handoff says.
    `run.json` holds `"provider": "local"` and `"candidates": {"cleanup": "smollm3-3b"}`.
  - `--candidate cleanup=bogus` prints `Unknown cleanup candidate bogus. Known: qwen3-4b-2507,
    smollm3-3b.`; `--provider apple` still runs and `run.json` carries no candidates for it.
  - `scripts/build-app.sh debug .build/local-cleanup/EchoType.app`: `codesign --verify --deep
    --strict` exits 0; `Contents/Resources` holds `AppIcon.icns`, `mlx-swift_Cmlx.bundle` (with
    `default.metallib`), `swift-crypto_Crypto.bundle` and `swift-transformers_Hub.bundle`. The
    release bin path holds the same three bundles, so `package-release.sh` and `deploy.sh`, which
    go through `build-app.sh`, are covered. The app was not launched.
  - Installed files under `~/Library/Application Support/EchoType/Models/` hash and size to the
    manifest values for both candidates. The sandbox had no network, so the Hugging Face
    revisions and licence cards were not re-fetched.
- Acceptance criteria:
  1. Met (both candidates, 12 of 12, `--fast`). The first-download half was not repeated; it rests
     on the handoff and workstream 1's verified store.
  2. Met (no download lines on rerun).
  3. Met by reading: `LocalCleanup.check()` returns `.waiting("Downloading models, x of y GB")`,
     then `.waiting("Loading the cleanup model")`, and `.ready` only after `CleanupModel.load`
     returns, which includes a warm-up `revise`. The unit test covers progress and the failed
     state.
  4. Met. Both revisions are 40-character commits, licence `Apache-2.0`, six files each with size
     and SHA-256. `generation_config.json` is needed (`LLMModelFactory` reads it for EOS ids) and
     the omitted files are not read by this loader. `LocalCleanupTests.manifestsArePinned` guards
     the shape.
  5. Met (`run.json` above).
  6. Met. `Providers.all` is untouched; `Provider.local` reports transcription and voice
     `.unavailable` and both services throw `ProviderError.unavailable`.
  7. Met. A grep for `qwen3`, `smollm`, `MLX` and `Provider.local` outside `Providers/Local/`
     finds only the bench (`RunOptions.swift`, `main.swift`) and the new test.
  8. Met (above).
  9. Met (above).
- Boundaries and ownership: the workstream 1 store files are unmodified. `Cleanup.swift` and
  `Transcribe.swift` changed by one line each, outside the listed ownership, but the packet
  forces it by adding `candidates:` to `RunInfo.begin`; accepted. No new adapter protocol or
  factory; `LocalCandidates.swift` holds configuration and the one public constructor.
- Correctness, lifecycle and cancellation (read against the pinned MLX Swift LM source):
  - Greedy sampling (`temperature == 0` selects `ArgMaxSampler`), `enable_thinking: false` is a
    real flag in SmolLM3's template and Qwen3's has none, and the prompt is passed unchanged.
  - The prefix cache is safe by construction. It is copied per request and used only when the
    request's tokens start with the cached tokens, otherwise everything is prefilled, so a
    tokenisation or date difference costs time, never correctness.
  - Prefill cancellation holds: `PrefillParameters.forEachChunk` throws `CancellationError`
    between chunks, the token loop checks `Task.isCancelled` before each step, and `generate`
    checks before starting and after the stream ends. A request queued behind another in
    `ModelContainer.perform`'s async mutex is checked once it acquires it. The 0.00 to 0.15 s
    cancellation figure was not re-measured.
  - A reply that stops on `.length` throws rather than returning a truncated reply. This is the
    right call given `Reviser` accepts any in-order subset.
  - Loading runs in an owned `Task`, off the main actor, and survives a provider switch. A
    failed load stays failed for the process, consistent with the plan's convention.
- Required findings: none.
- Optional observations:
  1. `README.md` (line 89) lists Xcode 27 and a signing certificate as build requirements. The
     Metal Toolchain component is now needed for any `swift build`, `swift test` or release
     build, not only CI, so a contributor without it will hit a build failure. A one-line
     mention there would keep the docs in step with the change. Not blocking for the spike.
  2. `LocalCleanup.check()` always starts the cleanup setup, so `transcribe --provider local`
     would begin a cleanup download before reporting transcription `.unavailable`. This follows
     the contract ("a check starts setup") and is harmless while only the bench uses it, but it
     is worth remembering when slice 2 adds the other services.
  3. `--candidate cleanup=x` is silently ignored with `--provider apple|xai` (not recorded, not
     rejected). Rejecting it would be a few lines; leaving it is fine for a bench argument.
  4. `UnknownCandidate` carries a `service` field that has one caller. It anticipates
     transcription and voice candidates, which the packet does not need yet. Inline "cleanup"
     if you want the smallest diff.
  5. `outputLimit` in `LocalCleanupTests` asserts only `limit > tokens`, which says little. The
     packet permits a test of the cap, so keep it or tighten it to the actual formula; it is not
     worth more than that. The cap-hit-throws behaviour needs a model and is rightly untested.
  6. `LocalCleanup` follower bookkeeping (a UUID-keyed continuation map plus a forwarding task
     per `changes()` call) is the one non-obvious piece of machinery. It is needed to merge the
     store's stream with load completion, and the test exercises it, so I would keep it.
- Questions:
  1. Q: Should the CI Metal toolchain step be confirmed on a pushed branch before merge? It cannot
     run locally, and the handoff and plan already record it as pending. No action from this
     workstream.
  2. Q: The licence and revision facts (Apache-2.0 for both conversions, no LICENSE file in
     upstream SmolLM3) are taken from the handoff, because the sandbox was offline. Does the
     orchestrator want a second look from a networked check before the results record cites
     them? The installed hashes do match the manifests.

## Resolution

- Finding dispositions: No Required findings, so no remediation pass.
  - Optional 1 (README lacks the Metal Toolchain requirement): accepted; one sentence added to
    the Development section of `README.md`.
  - Optional 2 (a local readiness check always starts cleanup setup): skipped. It follows the
    contract; slice 2 should revisit it when the other services exist.
  - Optional 3 (`--candidate` ignored for apple and xai): skipped. A bench argument; not recorded
    in `run.json` for those providers, so nothing misleading is written.
  - Optional 4 (`UnknownCandidate.service`): skipped. One field, one caller, no machinery.
  - Optional 5 (`outputLimit` test is weak): skipped. It is the one model-free test of the cap.
  - Optional 6: kept, as the reviewer advised.
  - Questions 1 and 2: both are already recorded as pending outside this workflow (CI toolchain
    step runs on push; licence facts come from the handoff and the installed hashes match the
    manifests). No action.
  - Out-of-ownership one-line edits in `Cleanup.swift` and `Transcribe.swift`: accepted, forced by
    the `RunInfo.begin` signature the packet requires.
- Simplification/deletion pass: Implementation agent's pass stands. The lead found nothing
  further to remove.
- Final verification: lead reran `swift build`, `swift test` (all suites passed) and
  `swift build -c release --product EchoTypeApp`. The bench runs, packaging and codesign check
  were run by both the implementation agent and the reviewer and are recorded above.

## Closure review

- Verdict: Not run. There were no accepted findings or fixes to verify; the lead reran the
  build, test and release build itself.
- Remaining required findings: none.
