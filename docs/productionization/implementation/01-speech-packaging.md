# Workstream 1: Production speech packaging

Status: accepted on 2026-10-09 after independent review, one remediation pass and fresh closure.

## Task packet

### Outcome

The accepted Kokoro/eSpeak pipeline builds reproducibly without the developer's compiled
model cache, runtime dictionary compilation or the trial environment variable.

### Scope

Productionize pinned English data compilation and bundling. Keep phrase-aware phonemization,
serialized eSpeak state, clock correction, phoneme limits and Heart/Emma identifiers.
Eliminate unused FluidAudio English G2P initialization/assets from this speech path while
retaining required Core ML components. Verify public runtime APIs before adding an adapter;
if bypassing unused G2P requires a dependency fork, escalate rather than silently adopt one.
Record build inputs, generated resource ownership and required notices. Keep older installed
assets identifiable for the later inventory/removal work. No cache deletion for performance.
Adopt the existing MLX restoration and Qwen speech retirement as one atomic dependency group:
newer CleanupModel APIs, removal of Qwen speech files/dependency, candidate entries and their
bench adapters must compile in the accepted commit. Do not split required source changes
from dependency pins merely to defer them to pruning.

### Required context

- Specification, especially Confirmed speech pipeline
- ../kokoro-espeak-comparison.md and ../kokoro-loading.md
- Existing Kokoro loaders/frontend/manifests, Package.swift and scripts/build-app.sh

### Non-goals

New voices, Qwen TTS, compute-unit experiments, provider migration, model management UI,
public release or an overall repository licence change.

### Initial ownership

KokoroEnglishFrontend.swift, KokoroText.swift, KokoroModel.swift, KokoroSpeech.swift and
KokoroManifests.swift under Sources/EchoTypeCore/Providers/Local; their focused tests;
scripts/build-app.sh and new reproducible pronunciation build resources/scripts;
Package.swift/Package.resolved for speech packaging and existing MLX restoration/Qwen removal;
CleanupModel.swift for its existing API adaptation; existing Qwen speech deletions and dedicated
tests; LocalCandidates.swift only existing Qwen retirement; existing bench Qwen retirement edits.
Leave Whisper/Smol and other candidate pruning to 4. This packet and its plan row belong to the lead.

### Required seams

Document production speech requirements and every generated file/cache link for stream 3.
Pinned eSpeak data ships in the app, not the downloaded model store. The bench and tests
can locate the same reproducible resources. Unrelated cache directories remain untouched.

### Acceptance criteria

A clean build produces usable English data from pinned inputs without a local model-cache
path or previous test run. Signed app resources contain required data/notices. Minimal
speech assets work offline without G2P fallback downloads. Both accents, contextual the,
literal thee, clocks and bounded long input remain supported. Record first-use/cache caveats.
The accepted dependency/source group compiles without dirty files owned by a later stream.

### Targeted verification

```sh
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter 'KokoroEnglishFrontendTests|KokoroTextTests|KokoroSpeechTests'
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter 'ReviserTests|LocalModelTests'
swift build -c release --product EchoTypeBench
env -u ECHOTYPE_ESPEAK_COMPILED_DATA scripts/build-app.sh release .build/local-productionization/EchoType.app
codesign --verify --deep --strict .build/local-productionization/EchoType.app
git diff --check
```

Also exercise the signed bundle offline against an isolated copy containing only declared
speech assets, without deleting or moving the user's installation. Record actual method
and evidence. Add focused resource-location/build checks only where they protect a real risk.

## Implementation handoff

- Base commit: `077a1ec3973cd9629c527e7f9c419c6e4263ee93`
- Outcome: implementation and S1-R1 correction complete. Targeted checks pass; ready for closure review.
- Files changed: `Package.swift`, `Package.resolved`, `KokoroEnglishFrontend.swift`,
  `KokoroText.swift`, `KokoroModel.swift`, `KokoroManifests.swift`, focused frontend/text
  tests, `scripts/build-app.sh`, `Plugins/EnglishPronunciationPlugin/plugin.swift` and
  `scripts/speech-data-builder/main.swift`. Adopted the existing `CleanupModel.swift`
  API changes, Qwen speech source/test deletions, Qwen retirement in `LocalCandidates.swift`
  and the two bench adapters. `KokoroSpeech.swift` remains unchanged.
- Decisions and dependency contracts:
  - A SwiftPM build plugin compiles English pronunciation data with the pinned
    `espeak-ng-spm` library and source data at
    `fd28f6460cc4cdf631528c8e2f7bd825747aac5c`. Ordinary app, bench and test builds need
    this build step, so a build tool avoids a separate developer preparation command.
    No dependency fork or runtime compiler is needed.
  - The public `KokoroAneModelStore` loads the chain and retained voice packs. Injecting
    it into `KokoroAneManager` and calling `synthesizeFromPhonemesDetailed` bypasses
    `initialize` and its unused English G2P preparation. The manifest contains only
    the seven-stage chain, vocabulary, Heart pack and Emma JSON. Loading rejects
    missing manifest files before FluidAudio can enter its download fallback.
    After S1-R1, it also requires the nested repository path to resolve to that
    same guarded installation before voice conversion or backend entry. A real
    conflicting directory is retained and preparation fails with a conflict error.
  - SwiftPM owns generated `EnglishPronunciation.bundle` under
    `.build/plugins/outputs/<package>/EchoTypeCore/destination/EnglishPronunciationPlugin/`.
    The runtime reads it through `Bundle.module`, with no model-cache lookup or copies.
    It contains `espeak-ng-data/{en_dict,phondata,phonindex,phontab,intonations}`,
    `espeak-ng-data/lang/gmw/{en,en-US}`, `COPYING.txt` and `SOURCE.txt`.
    `build-app.sh` stages the containing `EchoType_EchoTypeCore.bundle` before signing
    and checks the compiled tables/notices. It excludes a stale `espeak-ng_data.bundle`
    left by incremental builds. The trial environment variable has no role.
  - Stream 3 inventory must retain the old
    `Models/espeak-english-trial-fd28f646/{espeak-ng-data,ready}` as obsolete owned data.
    Former G2P files remain identifiable inside the pinned Kokoro directory:
    `G2PEncoder.mlmodelc`, `G2PDecoder.mlmodelc`, `g2p_vocab.json` and
    `us_lexicon_cache.json`. The old link is
    `~/.cache/fluidaudio/Models/kokoro` pointing at that model directory.
    Remove only an EchoType-owned link, never a real external directory.
  - Runtime-generated model files remain `ANE/bf_emma.bin` and the internal
    `kokoro-82m-coreml` link pointing at its own installed directory. Core ML may
    create device specialization caches; this work does not delete or manage them.
  - The GPL text ships both inside pronunciation resources and in app
    `Contents/Resources/Licenses/eSpeak-NG.txt`. Public release still requires the
    combined-program licensing/source obligations recorded in the specification.
- Verification:
  - `KokoroEnglishFrontendTests|KokoroTextTests|KokoroSpeechTests`: 10 active tests
    passed after S1-R1, with the opt-in model test skipped. The new regression
    checks the exact conflict error, preserved real directory and contents, and
    rejection before generated voice data or backend entry.
    Final log: `.build/speech-remediation-focused.log`.
  - `ReviserTests|LocalModelTests`: 15 tests passed. Log:
    `.build/speech-dependency-tests.log`.
  - Release `EchoTypeBench` and release app builds passed. Original logs:
    `.build/speech-release-bench.log`, `.build/speech-release-app.log`.
    The changed loader's refreshed release app also passed:
    `.build/speech-remediation-release-app.log`.
  - `.build/local-productionization/EchoType.app` passed strict deep signature
    verification. Final app size was 72,048 KiB allocated, including 928 KiB of compiled
    pronunciation resources. No eSpeak source bundle is staged.
  - A separate signed validation host at
    `.build/local-productionization/SpeechValidation.app` used the exact release
    app resources and an isolated copy of 37 manifest files, 85,473,788 bytes.
    Each copied file matched the manifest size and SHA-256. Inventory:
    `.build/local-productionization/speech-assets-inventory.json`.
    The sandbox denied networking, read/write access to the user's real model
    store and FluidAudio cache, and reads of build product/plugin resources.
    Profile: `.build/local-productionization/speech-offline.sb`.
    Both voices synthesized clocks, numbers, punctuation and a long reading at
    speed 1.2. Emma produced 1,171,800 samples; Heart produced 1,099,200 samples.
    All samples were finite at 24 kHz. The seven stages loaded in 10.89 seconds;
    the test finished in 17.874 seconds. First-run log:
    `.build/speech-offline-signed-first.log`. After the final missing-file guard,
    app rebuild and validation-host refresh, the same test passed with identical
    sample counts. Stages loaded in 1.44 seconds and the test took 8.474 seconds.
    Original final log: `.build/speech-offline-signed.log`. After S1-R1 and another
    successful host refresh, the same signed sandbox passed both minimal offline
    synthesis and the conflicting-directory regression. Both voices retained
    the same sample counts. Stages loaded in 1.44 seconds and the two tests took
    8.322 seconds. Final log: `.build/speech-remediation-offline-signed.log`.
    Strict deep signature verification passed for the refreshed app and host.
    This is packaging evidence from a signed validation host, not a production
    GUI/MCP run. The test uses `ECHOTYPE_KOKORO_OFFLINE_ROOT` only when explicitly
    enabled, plays no audio and is skipped in ordinary test runs.
  - Release `EchoTypeBench` and `EchoTypeApp` also built from an isolated archive of
    the base commit overlaid only with this stream's owned sources/dependencies.
    Later dirty sources, including Parakeet timing edits, app demo dispatch and
    `SettingsDemo.swift`, were excluded. Tree:
    `.build/local-productionization/atomic-source`; overlay inventory:
    `.build/local-productionization/atomic-source-overlay.json`; logs:
    `.build/speech-atomic-build.log`, `.build/speech-atomic-app-build.log`.
    The fresh package identity regenerated its pronunciation bundle during that
    build, without a prior test or model-cache dependency. After S1-R1, both
    release products passed again with the updated loader/test overlay. Logs:
    `.build/speech-remediation-atomic-bench.log`,
    `.build/speech-remediation-atomic-app.log`.
  - Two compiler runs into empty owned output directories produced byte-identical
    results for all nine shipped files. The final app's staged pronunciation
    files match those hashes. Evidence:
    `.build/local-productionization/speech-resource-sha256.json` and
    `.build/local-productionization/repro-{one,two}/EnglishPronunciation.bundle`.
    The compiler emits an expected missing `en_dict` diagnostic while selecting
    its initial voice before compiling that dictionary; compilation succeeds.
  - Validation host reconstruction is recorded in
    `.build/local-productionization/refresh-validation-host.py`. It copies only
    the owned app artifact, replaces its executable with the Xcode SwiftPM
    testing helper, copies the core test bundle, adds the Xcode test-library
    search paths to that bundle and signs both. Reconstruction fails on any
    subprocess error and checks the copied helper bytes before signing.
    Execute the helper with `--test-bundle-path` first, pointing at
    `SpeechValidation.app/Contents/PlugIns/EchoTypeCoreTests.xctest/Contents/MacOS/EchoTypeCoreTests`,
    then `--testing-library swift-testing --filter
    KokoroEnglishFrontendTests/offlinePackagedSynthesis`, under the recorded
    sandbox and `ECHOTYPE_KOKORO_OFFLINE_ROOT` pointing at the isolated speech copy.
  - During the final host refresh, copying over a read-only GPL notice failed.
    The shell then continued and briefly launched the copied app executable in
    the validation bundle under the same offline/model-store-denial sandbox.
    Only that owned process was stopped. Reconstruction now recreates the owned
    validation copy and invocation follows successful checks in a separate
    command. The intended signed test subsequently passed. No files in the
    user's model store or installed app were changed; this incident provides
    no production-app functional evidence.
  - `git diff --check`: passed.
- Limitations / external checks: actual signed production-app functional evidence
  remains the stream 4 gate. Core ML first-use specialization and later cache eviction
  can still add preparation time. The user's installation, existing trial data,
  external cache directories and unrelated dirty work remain intact.
- Specification drift: no model or pipeline changes. The lead accepted the separate
  signed validation host as this stream's packaging check, with actual app evidence
  explicitly outstanding for stream 4.

## Independent review

- Reviewer and configuration: independent review subagent, inherited model and effort,
  Codex harness. Reviewed HEAD `077a1ec3973cd9629c527e7f9c419c6e4263ee93`
  plus the complete current owned diff and new files, including adopted MLX/Qwen edits.
  Applied the code-review skill, its coding practices and unslop.
- Verdict: one Required finding remains. The pinned build plugin, bundled frontend,
  public FluidAudio API use and atomic dependency retirement otherwise meet this
  stream's requirements.
- Required finding S1-R1: reject a repository path that bypasses the checked installation.
  `Sources/EchoTypeCore/Providers/Local/KokoroModel.swift:21` checks manifest files
  under `directory/ANE`, then passes `directory` to FluidAudio. FluidAudio reads
  `directory/kokoro-82m-coreml/ANE`. The existing `linkFolder` helper at
  `LocalModel.swift:124` preserves a real folder at that repository path and returns
  successfully, so these can be different directories. I reproduced this with a
  hard-linked copy of the owned minimal speech assets and an empty real
  `kokoro-82m-coreml` directory. Under the recorded sandbox, the signed validation
  host attempted a HuggingFace download and failed on network denial after 0.163
  seconds. Evidence: `.build/speech-review-nested-directory.log`; isolated fixture:
  `.build/local-productionization/review-nested-directory`. No user stores or live
  app were touched. This violates the installed-files-only/no fallback download
  contract and can fetch an unpinned runtime copy despite the manifest guard.
  After creating or reusing the internal link, require its resolved location to
  equal the guarded installation before calling FluidAudio. Preserve a conflicting
  real directory and fail with a useful error. Add one focused check for this case.
- Optional observations: none.
- Questions: none.
- Verification performed by reviewer:
  - Inspected all scoped source changes and deletions, plugin/builder and app staging,
    plus the pinned FluidAudio model store, manager, downloader and migration path.
    No retired Qwen speech symbols or MLX Audio imports remain in Sources/Tests.
  - Confirmed all nine generated-resource hashes match both independent compiler
    outputs, the signed release app and the signed validation host.
  - Confirmed all 16 atomic-overlay files match the current owned sources and all
    four owned Qwen deletions are present in that archive. The supplied release
    bench/app build logs establish compilation without later-stream dirty sources.
  - Re-ran strict deep signature verification for the app and validation host.
    Both passed. `git diff --check` passed.
  - Read the supplied focused/dependency test logs and final offline synthesis log.
    They cover both accents, contextual articles, literal thee, clock preparation,
    bounded phonemes, stream cancellation and minimal offline synthesis. I did not
    repeat costly builds or successful model inference. The isolated failing case
    above stopped before model loading.
- Signed-host decision and limits: the separate signed host is a proportionate
  packaging check because it uses the exact app resources, synthesizes with only
  declared assets and cannot access build resources, the user model store, the
  FluidAudio cache or the network. It does not satisfy the specification's actual
  signed production-app functional criterion. Deferring that criterion to the
  explicit stream 4 gate is acceptable for this stream, provided that gate remains
  blocking for overall acceptance. Cancellation through the production app,
  operation wiring and release-context loading still need that evidence.

## Resolution

- Finding dispositions: S1-R1 accepted and implemented. A real nested repository
  directory could redirect FluidAudio away from verified files and trigger its
  downloader. The loader now requires the internal path to resolve to the guarded
  installation and preserves a conflicting real directory. The correction stays
  within KokoroModel and its focused tests.
- Simplification/deletion pass: reviewed the complete owned diff. The runtime
  compiler, trial packaging override, unused G2P payloads/cache link and retired
  Qwen speech implementation are already removed. The correction adds one
  canonical-path guard with Foundation URL APIs and one focused regression.
  No new helper or dependency is needed; `LocalModel.swift` remains unchanged.
- Final verification:
  - S1-R1 implemented. After creating or reusing the internal link, the loader
    rejects a resolved repository location different from the guarded installation.
    A conflicting real folder is preserved and fails before voice conversion or
    FluidAudio, with an error naming the conflicting folder.
  - Focused speech checks pass, 10 active tests and one opt-in skip. Signed
    sandbox validation passes both the regression and both-voice minimal offline
    synthesis. Refreshed app/host strict deep signatures pass. Evidence is recorded
    in the updated Implementation handoff.
  - Updated isolated base-source release bench and app builds passed, excluding
    later-stream dirty sources. Logs: `.build/speech-remediation-atomic-bench.log`
    and `.build/speech-remediation-atomic-app.log`. Their loader and focused-test
    overlay files match the final owned source files.
  - `git diff --check` passed. No unrelated source or shared helper was changed.

## Closure review

- Reviewer and configuration: fresh independent closure subagent, inherited model
  and effort, Codex harness. Reviewed HEAD
  `077a1ec3973cd9629c527e7f9c419c6e4263ee93` plus the current owned implementation.
  Applied the code-review skill, its coding practices and unslop. This review
  checks the original finding's correction and its effects within stream 1.
- Verdict: pass for this stream. S1-R1 is closed. The correction introduces no
  new blocking defect in the reviewed scope.
- Remaining required findings: none. Optional observations and questions: none.
- Disposition verified: `KokoroModel.load` now compares the resolved, standardized
  nested repository path with the guarded installation after `linkFolder` returns.
  A preserved real directory resolves elsewhere and receives the named conflict
  error before voice conversion, model-store construction or FluidAudio loading.
  The regression supplies all outer manifest paths, checks that exact error,
  preserves the real directory and its sentinel contents, and confirms that no
  Emma binary was generated. It therefore exercises the bypass from S1-R1 rather
  than failing at the earlier missing-file guard.
- Verification performed by closure reviewer:
  - Read the original review, resolution, updated handoff, specification,
    comparison/loading context and plan contracts. Inspected the corrected loader,
    regression, unchanged link helper and pinned FluidAudio repository/downloader
    path to confirm the guard covers the path FluidAudio actually reads.
  - Confirmed all 16 isolated-source overlay files match the current owned files
    and all four Qwen source/test deletions remain absent in that tree.
  - Compared the refreshed signed app and validation-host resource trees. All
    22 resource files match by SHA-256. Strict deep signature verification passed
    for both bundles. `git diff --check` passed.
- Supplied verification reviewed and reused:
  - `.build/speech-remediation-focused.log` records 10 passing active tests and
    one opt-in skip, including the conflict regression. The current loader and
    test source precede the compiled test binary and these refreshed logs.
  - `.build/speech-remediation-offline-signed.log` records the conflict regression
    and minimal offline synthesis passing under the recorded sandbox. Emma and
    Heart retained 1,171,800 and 1,099,200 samples respectively, with the tests
    completing in 8.322 seconds. The sandbox denies network access, the user's
    model store and FluidAudio cache, and build/plugin resource reads.
  - `.build/speech-remediation-atomic-bench.log` and
    `.build/speech-remediation-atomic-app.log` record successful release builds
    from the base-source tree containing only this stream's overlay. Earlier
    dependency and resource-reproducibility evidence remains applicable.
  - No builds or model inference were repeated during closure. No user model/cache
    files, installed app or unrelated dirty paths were touched.
- Acceptance boundary: the signed host verifies this stream's packaging with the
  exact app resources. Actual signed production-app functional evidence remains
  pending at stream 4 and blocks overall acceptance until supplied. This closure
  does not satisfy that gate or the public-release licensing obligations.
