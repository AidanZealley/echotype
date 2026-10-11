# Workstream 4: Prune experiments and validate the chosen stack

Status: accepted on 2026-10-11. Pruning, combined validation, deterministic checks, signed packaging, technical review and fresh functional evidence closure pass. Actual physical Local Dictation capture and user shortcut commit produced observed app insertion and idle settlement. Mixed-provider, offline speech, preparation, cancellation and removal evidence is retained below. Public-release obligations remain a separate hold. No further paid request, merge or publication is authorized.

## Task packet

### Outcome

Only the chosen local models remain in active implementation. The app passes final
verification after the bench is retired, with recorded combined-model evidence and
accurate documentation.

### Scope

Verify the accepted MLX restoration and Qwen speech removal handoff; adopt Parakeet diagnostics.
Remove Whisper/WhisperKit, SmolLM3, alternate candidate plumbing, obsolete flags and dedicated
obsolete tests. Keep the stable local provider and selected manifests, using the smallest direct
composition. Work in this order:

1. Make only the bench changes needed to run remaining installed-model validation against
   the chosen stack and final lifecycle. No ongoing bench compatibility or new features.
2. Record measurements, configurations, run ids and limitations in the consolidated evidence
   and this handoff. Include restored cleanup, boosted Dictation and combined speech residency.
3. Remove Sources/EchoTypeBench, Tests/EchoTypeBenchTests, their Package targets and commands,
   bench-only corpus/report/listening tooling and unused helpers/resources. Inspect consumers
   before removing Corpus/manifest.json or test support. Preserve helpers/fixtures that core/app
   tests actually use; move only useful bench-only fixtures into remaining test resources.
4. Rerun deterministic tests and build/sign/validate the app on the post-removal revision.
   Earlier bench measurements remain evidence; they do not replace these final checks.

EchoTypeTestSupport currently has live-test consumers in AppleTranscriptionLiveTests.swift
and LiveProtocolTests.swift. Preserve their required WAV/resampling support; remove only
parts with no remaining consumer. Do not delete user recordings, listening files, saved
results or installed models under Application Support. The old bench is recoverable at
`2f231b9`; no compatibility wrapper or replacement testing suite is needed in this pass.

After the UI gate passes, remove SettingsDemo.swift and its main.swift dispatch/marker handling.
The previous demo artifacts and historical git revision remain available; do not delete user
model files or the consolidated decision evidence. Completed spike workflow documents
have already been removed; their full git archive stays at `2f231b9`.
Inspect the net diff for duplicated state/facades,
unused resources and comparison-only build options. Update README, uninstall paths, decisions
0010/0025 and productionization notes. Keep Qwen follow-up and testing follow-up intact.

Run the restored cleanup configuration and boosted transcription with cleanup and Kokoro
resident. Verify the app separately from bench measurements. Record loading, memory pressure,
quality limitations and cancellation. Do not assert total memory from bench-only process footprint.
Document model notices/provenance and public-release obligations without silently changing the
repository licence or claiming legal uncertainties are solved by a manifest label.

### Required context

Specification acceptance and deletion pass; ../dependencies.md, ../parakeet.md,
../kokoro-espeak-comparison.md, ../kokoro-loading.md; accepted 1–3 handoffs;
[model decision evidence](../../decisions/0026-local-model-stack.md) for measured revisions;
[setup/storage/release notes](../../local-models.md); testing and Qwen follow-up specs.

### Non-goals

Automation suite, new model comparisons, paid model quality studies,
public publication, broad unrelated refactors or deleting consolidated evidence.

### Initial ownership

LocalCandidates.swift as handed over by 3 for remaining experimental pruning;
CleanupModel.swift, ParakeetModel.swift and obsolete local runtime/
manifest files; Package.swift/Package.resolved; Sources/EchoTypeBench, Tests/EchoTypeBenchTests,
Corpus and Sources/EchoTypeTestSupport after consumer inventory; core/app test resources
only for retaining consumed fixtures/helpers; bench references in scripts/CI/docs; SettingsDemo.swift removal and main.swift dispatch cleanup;
README, affected decisions and productionization/spec documentation. Necessary integration
fixes stay within accepted contracts; otherwise escalate to the earlier owner.

### Required seams

Pre-retirement bench checks use installed chosen assets without bypassing app consent.
No final check depends on the removed bench target. Shared test support remains test-only.
UI requirements and runtime selection share production manifests, not experimental registries.
Final review receives retirement inventory, resource/ownership inventory and signed-app evidence.

### Acceptance criteria

No rejected runtime/candidate/dependency, settings demo or bench target remains in the
merged codebase. Selected pins/voices remain valid. Recorded bench evidence predates retirement;
full deterministic tests, release build and signed-app checks pass after retirement. Signed app supports mixed providers, offline installed Local, visible preparation, active
switches, cancellation/retry and removal without silent reinstallation. Combined chosen set has
recorded paced quality and memory evidence. README explains install, switch and uninstall cleanup.
Public-release holds remain clearly identified if unresolved; they do not become claimed acceptance.
The production tree contains consolidated evidence, not completed spike task/review records,
and all documentation references resolve. Recheck the net merge diff for regenerated spike docs.

### Targeted verification

Before bench retirement, build it and record the required model measurements:

```sh
swift build -c release --product EchoTypeBench
.build/release/EchoTypeBench corpus status
.build/release/EchoTypeBench transcribe --provider local --cleanup dictation-keyterms-stack
.build/release/EchoTypeBench cleanup --provider local --fast
.build/release/EchoTypeBench speak --provider local --voice af_heart --fast reading-ordinary-prose
```

Confirm installed assets and corpus recordings before inference. If absent, record the need
and use explicit Settings setup or escalate; do not let a smoke command silently fetch models.
Run serially. Record combined-model residency explicitly; standalone commands alone do not
prove combined memory. Retain durable summaries/configuration/run ids before removing tooling.

After retirement, run final checks against the app and surviving tests:

```sh
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-productionization/EchoType.app
codesign --verify --deep --strict .build/local-productionization/EchoType.app
git diff --check
```

Inspect the package, source/tests, scripts and CI for active bench references. Update docs
so historical evidence is clearly archived, not instructions for a removed executable.
Validate the post-removal signed app offline and through real hotkeys/MCP; retain evidence
of per-feature failures and captured-provider switching. External xAI calls need the user's
configured access; fake routing tests cover the reverse combination when no paid access is
authorized, but unavailable required real-app evidence must remain explicit.

## Implementation handoff

- Base commit: `868f5ea3e839f3510afa68a9aef3eb7966f100b5`, branch
  `feat/local-models-productionization`. Changes remain uncommitted. Accepted streams 1–3,
  the frozen native toolbar/pages and the confirmed models/pins remain unchanged in behavior.
- Outcome: required installed-model measurements and additional combined paced quality,
  memory, pause and cancellation measurements completed before retirement. Fixed production
  composition now replaces the experiment registry. Bench, Corpus, dedicated bench tests,
  Whisper/WhisperKit, SmolLM3 and the Settings demo are removed. Final deterministic tests,
  release build, packaging/signing and strict signature validation pass. Actual isolated
  signed-app functional validation is in progress under the lead; acceptance is not claimed.
- Files changed:
  - `Package.swift` / `Package.resolved`; removed Argmax/WhisperKit and its otherwise unused
    argument-parser dependency, retaining all selected runtime pins.
  - Replaced `Sources/EchoTypeCore/Providers/Local/LocalCandidates.swift` with
    `LocalModels.swift`. Updated `LocalProvider.swift`, `LocalSetup.swift`, `LocalModel.swift`,
    `CleanupModel.swift`, `ParakeetModel.swift`, `KokoroModel.swift`, `ModelStore.swift` and
    the stale resource comment in `KokoroEnglishFrontend.swift`.
  - Deleted all six `Whisper*.swift` runtime/manifest/helper files and both dedicated Whisper
    core test files. Removed candidate-only tests from `LocalModelTests.swift`; retained
    manifest pin/checksum and download/readiness coverage. `LocalLifecycleTests.swift` only
    changes its loaded-runtime typealias references, preserving every fake lifecycle test.
  - Removed `Sources/EchoTypeBench/`, `Tests/EchoTypeBenchTests/`, `Corpus/manifest.json`
    and untracked `Sources/EchoTypeApp/Views/SettingsDemo.swift`; restored `main.swift` to
    ordinary app/MCP dispatch. Updated only comments in the two surviving test-support files
    and `scripts/build-app.sh`.
  - Narrow approved isolation support in `Sources/EchoTypeApp/Keychain.swift`,
    `MCPProcess.swift`, `HotkeyMonitor.swift`, `SettingsStore.swift` and guarded launch
    presentation in `App.swift`, with
    `Tests/EchoTypeAppTests/IsolatedValidationTests.swift`.
  - README; decisions 0010/0025/0026; `docs/local-models.md`; productionization
    Parakeet/Kokoro loading notes, Settings study, workflow README and this packet;
    `docs/specs/local-models-productionization.md`. Adopted the 29 authorized historical
    spike-document deletions without regenerating their contents.
- Decisions and dependency contracts:
  - One `Provider.local` directly composes the pinned boosted Parakeet/Qwen/Kokoro set.
    `LocalModels` owns the manifests/shared store, not a candidate registry or model router.
    Loader typealiases belong to their concrete runtimes. Removed the empty/SmolLM template
    configuration from cleanup; Qwen's unchanged template uses an empty additional context.
    Existing readiness/install/removal/preparation/lease behavior remains intact, including
    cleanup-unavailable fallback and release only after operations/setup settle.
  - Adopted existing Parakeet phase timings while preserving stream 3's tokenizer-link
    conflict guard. Historical installed-model names remain in ModelStore ownership inventory
    so obsolete user files remain discoverable/removable; they are not active runtimes.
  - Bench preparation briefly acquired production feature leases and retained them through
    operation teardown. Cleanup measurements include transcription because production
    Dictation prepares that feature as a set. Final speech explicitly joined waitForClose
    before releasing its runtime lease. None of this temporary bench adaptation remains.
  - Signed validation metadata plus dedicated
    `com.aidanzealley.echotype.stream4-validation-` bundle ids activate a separate Keychain
    service and suppress only the AX trust prompt, using one Bundle predicate. All six
    identity/flag combinations are tested without touching any real credential. Normal
    launches retain the production Keychain service and prompting; missing event-tap access
    remains a real failure. MCP targets its signed bundle id, with the original production
    fallback for an unbundled process. No general testing commands were added.
  - The initial accessory launch could not be reached through CUA. The lead approved guarded
    presentation of the existing native Settings scene with its real controller. Only signed
    validation identity changes launch presentation. The frozen pages, toolbar and normal
    launch behavior are unchanged.
  - A Foundation probe confirmed that CFPreferences did not read the seeded redirected-home
    plist. The first MCP response was fallback xAI admission failure, not offline Local speech.
    The lead approved a validation-only atomic plist backend for all settings and hotkeysActive.
    It requires the same signed identity guard and an explicit CFFIXED_USER_HOME equal to
    FileManager's redirected home, different from the real passwd home, including symlink
    resolution. It fails closed before any defaults access if those checks fail. Ordinary
    launches retain the original UserDefaults path. Focused tests cover owned seed/read/write
    and three invalid-home cases.
- Pre-retirement measurements / durable evidence:
  - All chosen installed files matched size/SHA-256. Kokoro was absent from the real managed
    root but its accepted 37-file, 85,473,788-byte owned stream 1 copy remained available and
    verified. Parakeet/CTC/Silero/Qwen were copied from their verified managed installations.
    All fifteen recordings and reviewed references existed. No downloads or paid calls ran.
  - Required packet runs `20261010T121805Z-local`, `121826`, `121854`; complete combined
    paced runs `121907`, `122021`, `122339`, all on 2026-10-10. Decision 0026 retains exact
    configuration, quality, timing/memory/load/pressure figures and limitations. Raw runs,
    JSON, reports/audio and logs remain under owned `.build/local-productionization/`.
    `122141` speech is marked provisional/superseded because it predated the teardown join.
  - Bench release builds passed in 23.23 s and 21.70 s. Corpus status reported
    15 Dictation/12 Cleanup/8 Reading samples, no missing recordings or reviewed references.
    Packet commands ran serially under `CFFIXED_USER_HOME` and the offline denial sandbox.
    Final source/package hash inventories are `stream4-bench-source-sha256.json` and
    `stream4-bench-final-source-sha256.json` beside the logs. No inference/build overlap ran.
- Shared support/fixture consumer inventory:
  - `AppleTranscriptionLiveTests.swift` and `LiveProtocolTests.swift` import
    EchoTypeTestSupport and use WAVRecording/resampling. Preserved both support files and
    their test-only Package target. No app/core source or surviving test consumes Corpus's
    manifest or bench reports/listening helpers. No bench fixture needed moving. The
    pronunciation build plugin and its resources remain required by production/core tests.
  - Package/source/tests/scripts/CI searches find no active bench, Whisper, candidate-picker
    or SettingsDemo reference. Historical evidence recipes are labelled archived. Existing
    `docs/specs/test-harness.md` text is preserved as requested, along with app-testing and
    Qwen follow-up. User model payloads, corpus recordings, listening and saved results remain.
- Post-retirement verification and signed candidate revision:
  - Final packet environment `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV
    -u ECHOTYPE_APPLE_LIVE swift test` passed 164 Core tests in 21 suites and 87 App
    tests in 13 suites. The two focused isolation tests cover six flag/identity combinations,
    owned preferences and invalid-home guards. Logs `stream4-final-tests.log` and
    `stream4-preferences-isolation-tests.log` remain under `.build/local-productionization/`.
  - Final `scripts/build-app.sh release .build/local-productionization/EchoType.app` passed
    with a 117.87 s release build. Both production and final owned copies pass
    `codesign --verify --deep --strict`; `git diff --check` passes.
    Log `stream4-final-packaging.log`. Earlier builds and candidate copies remain retained.
  - Production executable SHA-256
    `777aaa307b3e925997f02e2ccc0b9a22e5392f5ad7f6842c09fb0d650ed60d96`.
    The production executable/resources were copied to `Stream4ValidationIsolated.app`,
    assigned dedicated signed validation metadata/id, then re-signed. Validation SHA-256
    `5a96cefd670c24dd061a24a904e7c69455c52f8f1312391da3df70c45b33e79f`.
    `stream4-candidate.json` records every source/package hash, both paths/hashes, signed
    id, initial settings/defaults path, home and sandbox. This is the production GUI/controller.
    Initial and intermediate candidate provenance remains in `stream4-initial-candidate.json`
    and `stream4-presentation-candidate.json`; those superseded copies are not final evidence.
- Limitations / external checks:
  - Final owned GUI PID 95594 was launched with CFFIXED_USER_HOME rooted at
    `.build/local-productionization/validation-home` under `stream4-offline.sb`; log
    `stream4-actual-app-final.log`, exec session 77351. Bundle id is
    `com.aidanzealley.echotype.stream4-validation-offline`. Initial settings use xAI Dictation,
    Local Heart Read Aloud at speed 1.2, Ctrl+Opt+D/S, and hotkeysActive true. Its dedicated
    plist is under owned `Library/Preferences`. MCP uses the same bundle invocation with
    `--mcp`. Lead owns serial CUA/MCP/hotkey/setup/removal validation; implementation app,
    inference and source activity is paused. No permission grant/TCC mutation is authorized.
    Missing access/hardware or required real-app evidence remains a blocking gate.
  - No paid xAI access is authorized; reverse mixed-provider routing retains accepted fake
    coverage. Real credential namespaces and `/Applications/EchoType.app` were untouched.
    Existing user inspection PIDs 75712/75743 and live MCP PIDs 71261/87145 remain preserved.
  - Bench process footprint is not total combined/system memory. The first isolated Dictation
    preparation observed critical system pressure; later combined runs ranged warning/normal.
    Technical-word errors, boosting ordinary-word substitutions, cleanup under-editing,
    small corpus/repeat distributions and first-specialization limits remain explicit in 0026.
  - Parakeet provenance/notices, eSpeak combined-program licensing/source obligations and
    future Developer ID/notarization remain public-release holds. No licence change or
    publication is authorized; manifest labels do not resolve these obligations.
- Specification drift: none. Lead-approved narrow isolation and direct-composition ownership
  transfers are necessary for the packet's isolated actual-app checks, preserving ordinary
  behavior and accepted lifecycle/UI contracts.

## Independent review

- Reviewer and configuration: independent review subagent, inherited model and effort,
  Codex harness. Reviewed base/HEAD `868f5ea3e839f3510afa68a9aef3eb7966f100b5` on
  `feat/local-models-productionization` plus the complete owned dirty/untracked change,
  including recovered trial edits, retirement and signed-validation isolation. Applied
  the code-review skill, its coding practices and unslop. Read the specification,
  required context, plan contracts/conventions and accepted streams 1–3 handoffs.
- Verdict: one Required finding remains, S4-R1. Candidate/dependency pruning,
  retained selected loaders, retirement and consolidated evidence otherwise meet
  this packet's implementation requirements. Stream acceptance also remains blocked
  by the separate actual signed-app functional gate; passing tests or bench/host
  evidence cannot replace missing real hotkey, microphone and xAI completion evidence.
- Required finding S4-R1: invalidate stale setup success when readiness changes.
  `Sources/EchoTypeApp/SettingsStore.swift:115` stores "Ready. Models are prepared."
  in `LocalInstallation.messages[feature]`. Neither `follow` at line 97 nor `remove`
  at line 153 invalidates that message after readiness changes.
  `Sources/EchoTypeApp/Views/LocalSettingsPane.swift:84` displays it unconditionally
  beside current readiness. The lead's actual signed-app check prepared Dictation,
  removed its disposable installed copies and observed Needs download, a 2.99 GB
  Download action and this combined accessibility text: "Download models in Settings
  > Local. Cleanup: Download models in Settings > Local. Ready. Models are prepared."
  The retained removal artifact, `.build/local-productionization/stream4-after-dictation-removal.json`,
  records only Kokoro remaining in owned installed storage and a 639 MB app footprint.
  Source inspection independently confirms the stale-message cause. Provider-driven
  unloading has the same cause: current readiness updates but the old success message
  survives. This contradicts the required distinction between Installed, Ready and
  missing models, confusing whether setup is necessary. It is an accepted stream 3
  integration seam exposed by this packet's required actual-app validation, rather
  than a new pruning regression. Avoid retaining readiness success as duplicate
  status, or invalidate affected success messages whenever readiness ceases to be
  Ready, including removal and unloading. Keep failure/cancellation feedback and
  unaffected feature state. Add one focused behavior check; no page, provider or
  lease redesign is needed. The root has authorized this narrow earlier-owner correction.
- Optional observations: none.
- Questions: none.
- Verification performed by reviewer:
  - Inspected fixed `LocalModels` composition against the removed registry. Selected
    transcription/cleanup/speech manifests, Qwen revision/checksums/empty template
    context, keyterm limit, voices, speed and maximum text length are preserved.
    Loader typealiases moved to concrete runtimes; accepted lifecycle behavior,
    tokenizer/cache-conflict guards, native toolbar and production pages are unchanged.
    Parakeet diagnostics retain monotonic phase timing without altering inference.
  - Inspected package removal and retirement consumers. No active bench target,
    Whisper runtime/dependency, candidate registry, Settings demo, MLX Audio/Qwen
    speech code or comparison-only speech build option remains in package/source/
    tests/scripts/CI. Historical model names remain solely for owned-file inventory.
    Both shared audio helpers retain live-test consumers; no surviving consumer
    needs the removed corpus manifest or dedicated bench helpers/tests.
  - Inspected isolation guards, preferences read/write, Keychain service, launch
    presentation and MCP bundle targeting. Ordinary settings/credentials/prompting
    retain their existing path. Validation preferences require explicit redirected
    home checks before defaults access. Focused tests cover identity/flag combinations,
    owned preference persistence and invalid-home rejection. No general automation
    commands or test-only local inference path were added.
  - Independently verified all 74 source/package hashes in `stream4-candidate.json`
    and both executable hashes. Production and isolated signed bundles both pass
    `codesign --verify --deep --strict`; `git diff --check` passes.
  - Checked local Markdown links in 22 scoped documentation/context files; all
    resolve. Completed spike documents remain absent, and archived research/results
    exist at `2f231b9`. Setup/uninstall ownership and public-release holds remain
    explicit. Unrelated test-harness, app-testing and Qwen follow-up work was preserved.
- Supplied verification reviewed and reused:
  - `stream4-final-tests.log` records 164 Core tests in 21 suites and 87 App tests
    in 13 suites passing. `stream4-preferences-isolation-tests.log` records both
    focused isolation tests passing. `stream4-final-packaging.log` records the
    successful post-retirement release build in 117.87 seconds and packaging.
  - Read each of the six required/final combined run configurations, preparation
    records and reports, plus corpus status. These support the recorded chosen
    residency, paced quality, cancellation, timings and footprint figures. The
    superseded speech run remains identified; process footprint is explicitly
    distinguished from total system memory. Measurements predate retirement.
  - Lead-supplied actual GUI/controller observations and retained MCP/removal/memory
    artifacts support offline Local speech, setup cancellation/retry, combined
    preparation and captured-provider lease/removal protection. I did not operate
    the app or repeat builds/inference while lead validation was running. No user
    credentials, preferences, model/cache files or processes were touched.
- Acceptance boundary: S4-R1 needs the authorized correction and focused closure.
  The lead owns the external section and remaining real-app evidence. Missing
  microphone permission/access, successful real hotkey operations and required xAI
  completion remain a hard functional gate. Public-release licence/provenance and
  signing/notarization holds remain separately recorded; this review waives neither.

## Resolution

- Finding dispositions: S4-R1 implemented on 2026-10-10 against unchanged HEAD/base
  `868f5ea3e839f3510afa68a9aef3eb7966f100b5`. Removed the redundant setup-success
  assignment from `LocalInstallation.start` in `Sources/EchoTypeApp/SettingsStore.swift`.
  Current readiness remains the source of Ready status, so removal and provider-driven
  unloading cannot leave a saved "Ready. Models are prepared." message beside Installed
  or Needs download. Failure/cancellation messages, per-feature generations/tasks and the
  existing validation-preferences edits are preserved. No provider, lease or UI contract changed.
- Simplification/deletion pass: deleted the three-line success assignment without adding
  another status cache or invalidation path. Updated the existing independent-task test to
  expect no retained success message. Added one focused App behavior test proving successful
  Dictation setup retains no success message, fake-file removal refreshes inventory, and an
  unrelated Read Aloud failure survives both. Existing cancellation coverage still passes.
  Only SettingsStore.swift, LocalInstallationTests.swift and this Resolution section changed
  during remediation. Changes remain uncommitted.
- Final verification: serial `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV
  -u ECHOTYPE_APPLE_LIVE swift test --filter LocalInstallationTests` passed both tests.
  The first attempt used an incorrect literal assertion for ProviderError.localizedDescription;
  the corrected test compares the existing error's actual localizedDescription. The final log
  is `.build/local-productionization/stream4-r1-local-installation-tests.log`.
  The full requested environment-filtered `swift test` passed 164 Core tests in 21 suites
  and 88 App tests in 13 suites. Log `.build/local-productionization/stream4-r1-full-tests.log`.
  `git diff --check` passed. No app launch, model inference, user-file change or process
  termination ran. Release packaging, independent closure and the signed-app functional
  gate remain lead-owned; these test results do not claim functional-gate acceptance.

## Closure review

- Reviewer: fresh focused closure subagent, inherited model and effort, Codex harness.
  Reviewed S4-R1 and its correction on `feat/local-models-productionization`, unchanged
  HEAD/base `868f5ea3e839f3510afa68a9aef3eb7966f100b5` plus the owned dirty change.
  Applied the code-review skill, its coding practices and unslop. Read the packet,
  specification, required context, accepted stream 1–3 contracts/handoffs and plan
  conventions. The durable Independent review remains the full pruning/isolation audit.
- Verdict: S4-R1 is resolved. No new blocking defect arose from its correction.
  Remaining required code findings: none. Optional observations and questions: none.
  This closes the authorized correction, not stream 4's signed-app functional gate.
- Disposition verified: `LocalInstallation.start` now clears the requested feature's
  old feedback and retains only failures. It no longer saves successful readiness as
  another status. `follow` and the unchanged Local card continue to use current
  readiness, so removal or provider-driven unloading cannot leave the removed success
  message beside Installed or Needs download. Per-feature task/generation protection,
  cancellation feedback, unrelated feature messages, providers, leases and native UI
  contracts are unchanged. This is the three-line deletion requested by S4-R1, with
  no additional cache or invalidation mechanism.
- Test correction verified: the existing independent-task test still checks cancellation
  isolation and now expects no retained success message. The added behavior test checks
  successful Dictation setup, refreshed fake-file inventory after removal and preservation
  of an unrelated Read Aloud failure. The fake test does not claim actual UI or runtime
  unloading evidence; removing the sole success assignment removes that stale-state cause.
- Independent checks: all 74 source/package hashes and both remediation test hashes in
  `stream4-candidate.json` match current files. Its source inventory includes every
  surviving Swift source; comparison with `stream4-pre-r1-candidate.json` identifies only
  SettingsStore.swift as a changed source. Both recorded executable hashes match, both
  production EchoType.app and Stream4ValidationR1.app pass deep strict signature checks,
  and their signed identifiers/validation metadata are correct. The copied executables
  match byte-for-byte before their signatures after normalizing signature offsets/sizes
  and signing-dependent `__LINKEDIT` sizes. All 22 resource files match. `git diff --check`
  passes. No bundle or executable was modified for these read-only comparisons.
- Supplied results inspected and reused: `stream4-r1-local-installation-tests.log` records
  both focused tests passing; `stream4-r1-full-tests.log` records 164 Core tests in 21 suites
  and 88 App tests in 13 suites passing, including both LocalInstallation tests.
  `stream4-r1-packaging.log` records successful fresh release packaging in 101.72 seconds.
  These results cover the current inventoried correction. No further build, test run,
  model inference or app operation was needed for this bounded closure.
- Acceptance boundary: microphone access, successful real hotkeys, required xAI completion,
  settled long playback or explicit cancellation, and final signed-candidate functional
  checks remain lead-owned and blocking. Earlier app evidence predates this correction;
  admission and process absence do not establish playback completion. Public-release
  provenance/licensing and signing/notarization holds remain separate. No gate is waived,
  and no acceptance commit, merge or publication is authorized by this closure. Only this
  section was changed; user files, models, credentials, preferences and processes were untouched.

## External validation

- Gate / placement: signed-app functional evidence before acceptance; stream 4 lead owns it.
- Status: blocked on explicit microphone/access and paid-provider authorization, recorded
  as S4-FUNCTIONAL-01 in plan.md. No functional requirement is waived.
- Recovery on 2026-10-10: the durable Independent review is complete. Its only Required
  finding S4-R1 received the authorized narrow earlier-owner correction. Prior owned
  PID 95594 is absent at recovery, so no process was terminated. The prior 5,100-character
  reading was still active at the last observation. Its MCP response establishes admission,
  not playback completion. No completion or cancellation is inferred from process absence.
- Proven actual signed-app evidence before S4-R1: offline Kokoro setup visibly loaded;
  cancelling preserved Installed without Ready, and retry reached Ready. Local speech worked
  while xAI Dictation lacked a key. Explicit Dictation preparation while Kokoro was Ready
  yielded about 2,741 MB direct process footprint under normal pressure. This excludes
  Core ML/XPC and is not total memory. During the long captured Local reading, Manage files
  blocked speech/all removal and allowed Dictation removal. Selecting xAI for the next
  reading left the active Local lease protected. Removing only disposable Dictation copies
  reclaimed the confirmed 2.99 GB, left only the 86 MB Kokoro installation and reduced
  process footprint to about 639 MB. Original installed models and user app were untouched.
- Durable artifacts under `.build/local-productionization/`: `stream4-mcp-local-reading.json`,
  `stream4-mcp-captured-switch.json`, `stream4-actual-combined-memory-samples.json` and
  `stream4-after-dictation-removal.json`. The MCP result is explicitly admission evidence.
  The packet's earlier independent review verifies the pre-remediation signed candidate.
- Remaining required evidence: real hotkey Dictation with microphone access; successful
  xAI Dictation with Local Read Aloud and Local Dictation with xAI Read Aloud through real
  hotkeys/MCP; settled long playback or explicit cancellation; final signed candidate
  functional checks. Fake routing tests and pre-retirement bench runs cannot replace these.
- No paid call, microphone permission grant, TCC database change or production credential
  access is authorized. The dedicated validation Keychain service has no configured key.
  Device Control/Data Access permission does not establish microphone permission.
- Public-release hold: Parakeet provenance/notices, eSpeak combined-program licence/source
  obligations and future Developer ID/notarization remain pending. Local implementation
  acceptance would not authorize publication, merging or a repository licence change.

- Post-remediation signed candidate: packaging completed in 101.72 seconds in
  `stream4-r1-packaging.log`. Production executable SHA-256 is
  `9f7b3e252eb37777892a59a4e3ec6196e05067dc036b650cfbab91fffabbd6ca`.
  Fresh `Stream4ValidationR1.app` retains the isolated bundle identity and executable
  SHA-256 `a5e98f2f68df68fa9585e1068d28a4d88e52719665be4fc2cd0c4a4384c0721b`.
  Both bundles pass deep strict signature checks; source/package and focused test hashes
  are refreshed in `stream4-candidate.json`. Earlier candidate metadata is preserved as
  `stream4-pre-r1-candidate.json`. Earlier actual-app observations predate this correction.

- Final R1 actual-app recovery evidence on 2026-10-10: owned PID 95327 runs the exact
  `Stream4ValidationR1.app` under the offline sandbox and redirected owned home. Only Kokoro
  is installed, about 86 MB; Dictation remains Needs download, 2.99 GB. Explicit speech
  Prepare visibly showed Setting up and Loading the voice model, then Ready without stored
  success feedback. MCP admitted a controlled reading. Manage files blocked speech/all
  removal and named Stop Read Aloud before removing its files. Escape did not establish
  cancellation; no real hotkey success is claimed. A second short MCP request replaced that
  reading. Afterward speech/all removal became enabled, establishing operation and lease
  settlement. This supports replacement teardown rather than audible completion or quality.
  Switching the next Read Aloud provider to xAI then changed the Local card from Ready to
  Installed with Prepare/Retry and no stale Ready text, confirming S4-R1 through the real app.
  General explicitly shows Microphone Not granted and Device Control and Data Access Granted.
  Evidence is `stream4-r1-mcp-reading.json`, `stream4-r1-mcp-replacement.json` and
  `stream4-r1-actual-observations.json`. The earlier interrupted 5,100-character reading remains
  unproven. No paid call, permission change or user-root access ran. The owned app is idle on
  Local; both next providers are xAI, and its isolated key is missing. Its PID/path transfer
  to the lead/orchestrator for inspection, never use a global app kill.
- Final stream disposition: Blocked on S4-FUNCTIONAL-01. Independent review and fresh focused
  closure have no remaining technical Required findings. S4-R1 is resolved. Required signed
  mixed-provider/microphone/hotkey evidence is not waived by deterministic tests, bench runs,
  permissions labels, MCP admission or replacement settlement. No scoped acceptance commit,
  whole-feature review, merge or publication occurred. Unrelated dirty work remains preserved.

- Bounded functional resume on 2026-10-10: retained Aidan's authorization for exactly
  one 5–10-second xAI Dictation with its normal cleanup and one single-sentence xAI
  Read Aloud. No long reading, repeat paid trial or voice-quality comparison is authorized.
  Read-only recovery identified the user-relaunched validation PID 2033. Its Apple page
  explicitly reports Microphone Granted and Device Control and Data Access Granted.
  An isolated-service metadata query with ReturnData false and authentication UI disabled
  found an xAI item, status 0. No secret was retrieved or printed and no production
  credential namespace was queried. These checks establish current setup observations,
  not successful operation admission, output insertion or playback.
- Network-enabled resume artifacts are ready under `.build/local-productionization/`.
  `launch-stream4-r1-network.sh` launches the same signed candidate with the same owned
  redirected home and guarded credential/settings identity. `stream4-network.sb` differs
  from the offline profile only by removing the network denial. All user-root and live
  app denial rules remain byte-for-byte unchanged; the profile parses successfully.
  Current 74 source/package hashes match the candidate. Evidence is
  `stream4-functional-resume-preflight.json`. No paid operation or model inference ran.
- Remaining coordination: preserve PID 2033 and its current Settings while Aidan finishes
  configuration. After he confirms readiness, restore only verified disposable Dictation
  assets, explicitly Prepare, and restart only the owned validation app through the network
  script. Focus a disposable input target before Ctrl+Opt+D. Aidan supplies one 5–10-second
  phrase for the paid Dictation check and a separate short phrase for Local Dictation.
  Verify inserted output, one-sentence xAI reading, Local hotkey/MCP speech, captured-provider
  behavior and settled playback/cancellation with lease release. Do not infer microphone
  input from a permission label or use silent capture as successful Dictation evidence.
  S4-FUNCTIONAL-01 remains Blocked pending readiness and these actual-app checks.


- Bounded session after Aidan confirmed readiness, 2026-10-10: exact owned PID 2033
  was restarted through the prepared network script as PID 9478. The signed candidate,
  guarded owned home, credential service and all original user-root denials are retained.
  All 74 source/package hashes still match. No production app, user model/cache root,
  normal Keychain service or TCC setting was changed.
- A new disposable TextEdit document was blank and focused. The orchestrator coordinated
  the short phrase before capture. CUA sent Ctrl+Opt+D, waited eight seconds and sent the
  same stop chord. TextEdit received two U+0004 control characters. No recording pill,
  transcript or output insertion established capture or paid Dictation admission. These
  characters were cleared. This attempt is unproven and cannot count as a successful
  Dictation or an authorized repeat paid trial.
- Read-only General inspection after restart reports Microphone Not granted, while Device
  Control and Data Access remain Granted. The user-launched PID 2033 previously reported
  Microphone Granted. macOS launch/responsible-process attribution may explain that
  difference, but it has not been established. The configured hotkey remains Ctrl+Opt+D
  and owned hotkeysActive is true. No permission workaround or UI/source change ran.
- Restored only the 36 verified pinned Dictation files to disposable owned storage, reading
  originals without modification and checking every original and copy checksum. Evidence
  is `stream4-functional-restored-assets.json`. No setup, download or inference followed
  while physical input coordination was pending.
- The single authorized xAI Read Aloud used exactly `This is a short speech check.` through
  the isolated MCP, with Local Dictation and xAI Read Aloud selected. The MCP admitted it.
  Dictation's Test microphone button became enabled again; source disables that control
  while the controller is not idle, establishing operation settlement. Audible success
  remains pending Aidan's outcome. Admission and idle state do not establish audio quality
  or distinguish a completed reading from failure. No second paid speech request ran.
  Evidence is `stream4-functional-xai-reading.json` and
  `stream4-functional-bounded-attempt.json`. The paid Dictation remains unused because
  capture/admission was not established. The one-sentence reading allowance is consumed
  as an attempt and must not be repeated without a new user decision.
- Current safe handoff: owned network PID 9478 is idle, the disposable TextEdit target is
  blank, and selected providers are Local Dictation/xAI Read Aloud. The orchestrator has
  pending physical-hotkey and audibility questions. Do not switch providers or initiate
  capture/speech until their outcomes arrive. Physical input and microphone attribution
  need resolution before another capture. Remaining Local checks must use the offline
  launch and no paid requests. Stream 4 stays Blocked on S4-FUNCTIONAL-01; fresh functional
  acceptance review and a scoped commit have not occurred. The earlier technical closure
  remains valid. No merge, publication or whole-feature review started.

- Access diagnosis on 2026-10-10 uses non-capturing, targeted TCC evidence. User-launched
  PID 2033's microphone preflight at 18:24:54 names responsible Ghostty and returns
  authValue 2. Assistant-launched PID 9478 names responsible T3 Code Nightly,
  `com.t3tools.t3code`, and TCC explicitly rejects its missing hardened-runtime
  `com.apple.security.device.audio-input` entitlement. Policy rejection repeats at
  18:29:23, 18:29:28 and 18:29:51. The retained actual request at 18:29:51 returns
  authValue 0, authReason 5.
  The isolated validation app has audio-input entitlement. This establishes the launch
  attribution cause rather than an inferred permission toggle. The profiles differ only
  by removal of network denial; the executable and redirected owned home are unchanged.
  Apple documents the [audio-input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input)
  and [authorization-status API](https://developer.apple.com/documentation/avfoundation/avcapturedevice/authorizationstatus(for:)).
  Retained nonsecret evidence and exact targeted query are in
  `.build/local-productionization/stream4-access-diagnosis.json`.
- Starting and Escape have narrower evidence than successful capture. Source publishes
  Starting before credential lookup, installed-model preparation and permission request.
  Restored Dictation files had not received explicit preparation, so loading may account
  for some delay; its duration/stage was not recorded. Escape publishes cancellation and
  stops capture immediately, while controller ownership waits for suspended startup and
  cleanup. Startup checks prevent later capture/session/insertion after cancellation.
  Later denied requests are independently proved by TCC logs. No correctness defect has
  been established, so no source, UI or broad permission-support machinery changed.
- Aidan confirms physical Ctrl+Option+D reached Starting and no Dictation was inserted.
  He heard nothing from the one paid xAI sentence while earbuds were connected to two
  devices. That audio outcome is unverified; it does not establish provider failure.
  `stream4-functional-network.log` is empty, so it supplies no playback failure/completion
  evidence. No repeat paid speech, capture, prompt, TCC mutation or device change ran.
- Current user gate remains S4-FUNCTIONAL-01. Aidan quits only the isolated app, current
  PID 9478, and runs the existing network script from his prior working Ghostty terminal.
  Inspect General without capture and retain the new PID for responsible-attribution
  verification. If microphone remains Not granted, stop. Explicitly Prepare Local
  Dictation to Ready before coordinated physical input. The script/key/model identities
  are preserved; the remaining paid allowance is one 5–10-second Dictation with normal
  cleanup. The consumed paid reading cannot be retried without a new user decision.
  Exact steps are in plan.md. No app takeover or relaunch was performed during diagnosis.
- Fresh independent diagnosis review reran the targeted TCC query, checked both signed
  entitlement listings and the profile difference, and confirmed the empty network log.
  It independently inspected startup/cancellation ownership and accepted the no-fix
  disposition with no Required findings. This review establishes diagnosis, not successful
  capture, playback or functional acceptance. The prior technical closure remains valid.
- Fresh focused diagnosis closure corrected one evidence wording issue, distinguishing
  repeated policy rejection at all three times from retained authValue/authReason values
  at 18:29:51. The reviewer verified the correction, non-capturing launch gate and paid
  limits, with no remaining Required findings. No source correction or rebuild was needed.
  This closes the diagnosis record only. Stream 4 remains Blocked on S4-FUNCTIONAL-01.


## Ghostty launch functional recovery, 2026-10-10

- Aidan relaunched the unchanged network candidate from his own Ghostty terminal.
  Exact validation PID 19185, parent zsh PID 19159, started at 18:38:25. The lead
  preserved that process. General shows Microphone Granted and Device Control and
  Data Access Granted. This resolves the prior assistant-launch permission attribution
  gate; real capture and insertion are still unproven.
- All 74 recorded source/package hashes match. The owned isolated xAI Keychain item
  is present by attributes-only query, with return-data disabled. No credential was read
  into an artifact. Restored disposable Dictation files remain installed. The lead
  explicitly clicked Dictation Prepare with Zero KB download shown, observed loading
  and then Ready. The native shortcut is Ctrl+Option+D.
- CUA reported user activity during the attempted xAI provider selection. UI actions
  stopped immediately. Read-only owned preferences still show Local Dictation and xAI
  Read Aloud. No microphone test, capture or paid request ran in this recovery.
- Evidence is `.build/local-productionization/stream4-ghostty-resume.json` and the
  preparation sample alongside it. Resume only after orchestrator coordination. Finish
  independent xAI Dictation/Local Read Aloud selection and disposable target setup,
  then coordinate physical shortcuts. The single paid reading remains consumed,
  unheard and unverified. No repeat is authorized; acceptance remains blocked.


## Physical Dictation setup resume, 2026-10-10

- Aidan answered `Yes, finish setup now`. The lead retained Ghostty-launched PID 19185,
  parent zsh PID 19159, start 18:38:25. No restart or permission change occurred.
- Owned Settings now select xAI Dictation and Local Read Aloud. Explicit speech Prepare
  showed Zero KB download, Loading the voice model, then Ready. Dictation shows xAI
  Ready. Enabled Test microphone proves controller idle through its existing `!isIdle`
  disabling rule; the test was not invoked. Owned plist confirms `xai` and `local`.
- The blank disposable TextEdit `Untitled` window has `First Text View` focused. The
  coordinated phrase is `EchoType turns this short sentence into text. I am testing
  the microphone once.` The orchestrator asks Aidan for physical Ctrl+Option+D,
  5–10 seconds of speech, then physical Ctrl+Option+D to stop. No synthetic shortcut,
  capture or paid request was initiated by the lead.
- Setup evidence is `.build/local-productionization/stream4-ghostty-resume.json`.
  Actual insertion and settled operation remain pending user input. The earlier paid
  reading remains consumed, unheard and unverified. No repeat is authorized.

- Terminal handoff: no physical attempt outcome has arrived. Read-only observations
  still show empty TextEdit and idle controller. Do not infer an attempt or paid
  Dictation consumption from no response. Preserve the ready target and PID 19185.
  Stream 4 stays Blocked on S4-FUNCTIONAL-01 pending actual functional evidence.


## Physical Dictation outcome recovery, 2026-10-10

- Aidan reports `Ok I manually did a ctrl+opt+D dictation into an active text edit
  and it worked`. This supersedes the earlier empty-target report and establishes
  user-observed physical shortcut, capture/transcription and insertion success.
- Read-only inspection preserves Ghostty-launched PID 19185, parent zsh 19159,
  start 18:38:25. Current owned preferences remain xAI Dictation/Local Read Aloud
  with hotkeysActive true. Dictation Settings shows xAI Ready, Ctrl+Option+D and
  enabled Test microphone. The existing disabling rule at SettingsView.swift:278
  establishes controller idle settlement. No microphone test was clicked.
- Attribute the successful check to the unchanged xAI Dictation setup, with the
  limitation that no per-operation provider/request trace or transcript was retrieved.
  The existing network log remains empty. The user report supplies insertion evidence;
  idle UI alone does not prove insertion, cleanup quality or playback. Evidence is
  `.build/local-productionization/stream4-physical-dictation-result.json`.
- The one paid Dictation allowance is consumed by this successful reported check.
  Do not repeat it. The prior paid reading allowance remains consumed, unheard and
  unverified. No new paid request, capture, inference, settings/source change, focus
  action or restart ran during this recovery. User apps and current target are preserved.
- S4-FUNCTIONAL-01 remains Blocked. Required remaining evidence includes successful
  Local Read Aloud through hotkey/MCP, reverse Local Dictation/xAI Read Aloud with
  audible completion, installed offline operation, captured-provider switching and
  settled playback/cancellation with lease release. Earlier setup/removal and technical
  evidence remains valid. The unreadable paid audio outcome needs a user decision
  before any repeated paid reading; this recovery supplies no further spending consent.
  No functional acceptance, scoped commit, whole-feature review, merge or publication
  occurred.


## Authorized speech repeat recovery, 2026-10-10

- Aidan authorized exactly one additional xAI reading with `Ok repeat`. The
  orchestrator delivered a listen-now notice and gave the lead go-ahead. The
  retained Ghostty PID 19185 admitted exactly `This is a short speech check.`
  through its isolated MCP with Local Dictation/xAI Read Aloud selected.
- All 74 source/package hashes and the recorded signed executable hash match
  the reviewed R1 candidate. No rebuild, source, credential, TCC or device change ran.
- Enabled Test microphone after admission establishes controller idle settlement.
  Aidan then confirms `Yes, heard the full sentence`. Together these establish
  successful audible xAI reading and settlement for the reverse provider selection.
  Evidence is `.build/local-productionization/stream4-xai-repeat-result.json`.
- This repeat allowance is consumed. No further paid Dictation or Read Aloud is
  authorized. Earlier unheard attempts remain historical evidence.
- Installed Local Dictation was explicitly prepared with Zero KB download, showing
  Loading the cleanup model, then Ready/Ready. Real Local microphone capture and
  insertion remain unproven. Current PID 19185 retains its network sandbox and
  Local Dictation/xAI Read Aloud; it cannot establish denied-network operation.
- The orchestrator is coordinating an offline relaunch from the same Ghostty
  terminal. Preserve the current process until that user action. Never relaunch
  through T3 Code, change TCC or synthesize Ctrl+Option+D. Remaining Local audio,
  physical hotkey/capture, offline and lifecycle checks stay open. Stream 4 remains
  Blocked on S4-FUNCTIONAL-01; no acceptance commit or whole-feature review ran.

## Speech repeat evidence review

- Reviewer: independent focused evidence-review subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Reviewed only the
  completed Authorized speech repeat recovery against this packet, the specification,
  plan and accepted streams 1–3 contracts. Earlier source reviews remain accepted.
- Verdict: the recovery record is supported. Required findings: none. Optional findings:
  none. Questions: none. No evidence inconsistency was found in this scoped recovery.
  Historical unheard-reading and no-repeat statements describe the earlier authorization;
  the plan's later `Ok repeat` and full-sentence confirmation supersede that audio outcome.
- Spending is bounded to one additional reading of `This is a short speech check.`
  The retained JSON records one tool call and the orchestrator's listen-now go-ahead.
  Aidan's `Ok repeat` authorizes that sentence, not another Dictation, longer text or
  automatic retry. This allowance is consumed; the recovery grants no further spending.
- Independently verified HEAD/base `868f5ea3e839f3510afa68a9aef3eb7966f100b5`, all
  74 source/package hashes and the validation executable SHA-256
  `a5e98f2f68df68fa9585e1068d28a4d88e52719665be4fc2cd0c4a4384c0721b`.
  The isolated bundle metadata, guarded preferences/Keychain identity and network launch
  script agree with the reviewed candidate. The network profile differs from the offline
  profile only by removing network denial; every user-root denial remains unchanged.
  PID 19185 and its selected providers are supplied recovery observations, not a fresh
  process or UI inspection by this reviewer.
- `MCPProcess` and `SpeechDelivery` acknowledge admission, not playback. The retained
  `Speaking.` response therefore proves acceptance of the sentence. SettingsView's
  enabled Test microphone requires `controller.isIdle`; the controller returns to idle
  after Reader finishes backend/player/clipboard teardown. Idle alone also follows failure
  and does not prove audible success. Aidan's separate `Yes, heard the full sentence`
  supplies audible completion evidence for xAI Read Aloud with Local Dictation selected.
  It does not establish Local Dictation capture, simultaneous operation or voice quality.
- S4-FUNCTIONAL-01 remains Blocked. Real Local microphone capture/insertion, Local speech
  through hotkey/MCP, installed operation with network denied, captured-provider switching
  and the remaining playback/cancellation and local lease-release checks still need
  actual-app evidence. Prepared Local files and a network-enabled process cannot replace
  those checks. No functional acceptance, scoped commit or whole-feature review is claimed.
- Verification was limited to file reads and hashing. No GUI control, build, test,
  inference, credential query, microphone access, settings change or process action ran.
  All apps/processes were preserved. Only this review section was added.

## Offline resume preflight, 2026-10-10

- Offline resume verification after Aidan answered `Yes, I think` found the original
  network PID 19185 still running, with parent 19159 and unchanged start time
  18:38:25. No new R1 process was found. Evidence is
  `.build/local-productionization/stream4-offline-resume-preflight.json`. The lead
  did not infer an offline relaunch or invoke dependent controls/capture. The
  orchestrator clarified the exact owned-PID stop and Ghostty offline-launch steps.
  A new offline PID and Granted state must be verified before capture.

- A second check after Aidan reported `Yes, it reopened` again found PID 19185,
  parent 19159 and unchanged start time 18:38:25, with no new R1 PID. The lead
  reported that conflict to the orchestrator and preserved the process. User
  confirmation alone does not establish network denial. No dependent controls,
  capture, inference or paid call ran. Actual offline relaunch evidence remains
  the concrete S4-FUNCTIONAL-01 blocker.

- Fresh direct shell evidence at 18:05:16 UTC rules out a cached CUA process
  report. PID 19185 owns foreground process group 19185 on Ghostty `ttys004`;
  zsh PID 19159 has terminal foreground process group 19185 and is waiting.
  Commands typed into that occupied terminal would reach app stdin rather than
  execute in zsh. This is the likely cause, not observed command-history evidence.
  App source has no SIGTERM handler or singleton reactivation path; the launcher
  directly execs sandbox-exec rather than `open`. The lead recommended a new
  Ghostty tab with a visible shell prompt, TERM only PID 19185, verify absence,
  then run the existing offline script. No process or source mutation ran.

## Native Ghostty recovery blocker, 2026-10-10

- Aidan's `Ok let's continue` authorizes computer use to finish the isolated offline
  launch and setup. Fresh shell inspection at 19:32:45 BST still finds exact network
  PID 19185, parent 19159, start 18:38:25, foreground process group 19185 on `ttys004`.
  No offline relaunch is established.
- CUA inventory lists running Ghostty. Selecting its exact bundle identifier with
  `cua.getApp('com.mitchellh.ghostty')` fails with `Computer Use is not allowed to use
  the app 'com.mitchellh.ghostty' for safety reasons.` This is a tool-access rejection
  before any terminal interaction. No alternate identifier, keyboard routing through
  another app or assistant-shell launch was used to bypass it.
- Preserved the current validation app, production app, all user windows/processes,
  isolated preferences/key/models and existing reviewed dirty work. No termination,
  launch, capture, inference, paid request, TCC or audio-device change ran. No build or
  test reran because source is unchanged. The rejected tool call is not offline or
  functional evidence.
- Evidence is `.build/local-productionization/stream4-native-ghostty-blocker.json`.
  S4-FUNCTIONAL-01 remains Blocked pending a working authorized launch route retaining
  Ghostty attribution. No functional acceptance, commit or Final review occurred.

## Offline interrupted recovery, 2026-10-11

- Fresh process and CUA inventory found yesterday's offline PID 59620 absent. Its
  retained Oct10 evidence proves denied networking and Ghostty microphone access
  for that process, with Dictation preparation started. It does not prove Ready
  or successful input/output. The production MCP process was preserved.
- All 74 source/package hashes and the signed R1 executable still match. No
  unchanged build/test was repeated. Evidence is
  `.build/local-productionization/stream4-offline-recovery-oct11.json`.
- After the orchestrator supplied one offline launch instruction, Aidan answered
  `done`. Fresh inspection finds PID 62901, parent Ghostty zsh 25015, started
  08:46:42 BST. `sandbox_check` denies network outbound, inbound and bind without
  issuing network requests. General shows Microphone Granted and Device Control
  and Data Access Granted. Targeted preflight `62901.7` names responsible Ghostty
  and returns authValue 2, authReason 2. No TCC/device change occurred.
- Both Local cards showed Installed and Zero KB. Explicit Dictation Prepare
  loaded transcription, then reached Ready with cleanup ready. Serial Read Aloud
  Prepare loaded the voice model, then reached Ready. Dictation and Read Aloud
  both select Local. Dictation's enabled Test microphone establishes idle through
  the existing disabling rule; the button was not invoked.
- Created a new blank disposable TextEdit `Untitled 2` and focused First Text
  View, preserving the older populated document. The orchestrator coordinates
  physical Ctrl+Option+D, Recording, about five seconds of the supplied phrase,
  then physical Ctrl+Option+D to stop. No synthetic shortcut, microphone capture
  or speech request ran during setup. Actual Local insertion, playback and
  lifecycle outcomes remain pending. Paid authorization is exhausted.

## Offline recovery evidence review, 2026-10-11

- Reviewer: independent focused evidence-review subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Scope is the complete
  Oct11 Offline interrupted recovery section and its retained JSON, against the plan,
  specification, accepted streams 1–3 contracts and relevant existing source semantics.
  Base and HEAD are `868f5ea3e839f3510afa68a9aef3eb7966f100b5`; previously reviewed
  uncommitted stream 4 implementation remains outside this focused review.
- Verdict: the record supports recovery and explicit setup only. Required findings:
  none. Optional findings: none. Questions: none. Functional acceptance remains blocked.
- Independently verified all 74 candidate source/package hashes and R1 executable
  SHA-256 `a5e98f2f68df68fa9585e1068d28a4d88e52719665be4fc2cd0c4a4384c0721b`.
  The offline launcher uses the retained network-denial profile and owned validation
  home; the profile preserves the user-root denials. No unchanged build/test was needed.
- The JSON's initial timestamp, process/UI inventory and read-only action describe the
  prelaunch check. Its updated timestamp, new PID and setup fields describe subsequent
  recovery. The packet distinguishes absent Oct10 PID 59620 from Oct11 PID 62901 and
  does not carry yesterday's incomplete preparation forward as Ready.
- Installed and Zero KB report asset availability, not prepared runtimes. The recorded
  explicit serial preparation and separate transcription, cleanup and voice Ready states
  agree with the accepted setup contract and Local card implementation. SettingsView's
  enabled Test microphone requires `controller.isIdle`; that controller property excludes
  dictation, testing and reading. This supports idle state only, not successful capture,
  insertion or audible playback.
- PID, network-denial checks, targeted TCC attribution and UI states are supplied lead
  observations, not fresh process/UI observations by this reviewer. The recorded pending
  physical input and Local playback/lifecycle outcomes remain unproven. No paid repeat
  authorization or workaround for the Ghostty tool-access refusal is inferred.
- Verification used file reads and hashing only. No GUI control, process launch or
  termination, microphone/audio use, inference, build/test, settings change or credential
  inspection ran. Only this assigned review section was added; earlier records and the
  plan remain unchanged.

## Offline ready terminal handoff, 2026-10-11

- No physical-input outcome arrived before the orchestrator ended its turn awaiting
  Aidan's response. Two bounded read-only target checks remained blank and focused.
  Absence of a response does not establish an attempt, failure or success. Final
  read-only process check preserves PID 62901 and its original start/parent.
- Resume from the pending physical Local Dictation result with the prepared offline
  process and disposable `Untitled 2` target. Do not restart, send synthetic shortcuts
  or initiate capture without coordination. Free Local reading and captured-provider
  switching/cancellation/lease outcomes remain required after insertion. Paid scope
  is exhausted. Stream 4 remains Blocked on S4-FUNCTIONAL-01; no functional acceptance,
  scoped commit or whole-feature review occurred.

## Empty Local target diagnosis, 2026-10-11

- Aidan reports missing the pill and no text in `Untitled 2`. Fresh read-only inspection
  preserves offline PID 62901, parent 25015 and start 08:46:42. Dictation is Local
  Ready/Ready with Test microphone enabled. The target is empty and First Text View
  was focused. Owned preferences retain hotkeysActive true and Ctrl+Option+D.
- These observations prove current idle state and no insertion in that target. They
  do not establish whether the shortcut admitted an operation. The bounded recent
  PID log query returned no EchoType, TCC or coreaudio subsystem entries. Camera
  enumeration and CenterStage errors at 19:48:44 do not identify a Dictation failure.
- The orchestrator authorized narrow diagnostic navigation after idle was established.
  Standard app and Window menus contain no Last Dictation entry. CUA's current
  window AX/screenshot omits the MenuBarExtra that owns Last Dictation and the
  controller's retained lastError. Ctrl+F8 exposed no such menu. Inspected menus
  were cancelled. No trace or retained error has been observed.
- Preserve the process. The next step is to expose the isolated waveform menu and
  Last Dictation through a supported UI route or user action, then read existing
  trace/status before another recording. Startup failure can leave no trace, so
  `No dictation yet` alone would still need the retained menu status.
- Evidence is `.build/local-productionization/stream4-local-empty-diagnosis-oct11.json`.
  No capture, Dictation shortcut, speech, paid request, settings/source change,
  restart, TCC/device change, production action or rebuild ran. Stream 4 remains
  Blocked on S4-FUNCTIONAL-01. This diagnosis record is not functional acceptance.

- A bounded supported-API check found no macOS desktop/menu-bar/system-UI capture
  in CUA documentation or inventory. Existing MCPServer declares only `speak` and
  protocol discovery/ping, with no status, trace or resources diagnostic. No MCP
  speech or new process ran. Minimal user navigation is to open the EchoType
  waveform menu, report its first status line exactly, choose Last Dictation,
  and leave that window open. Do not assume the retained status is Ready from
  Settings readiness. This allows a trace/error read before a recording retry.

## Last Dictation read and physical retry, 2026-10-11

- Aidan exposed the existing Last Dictation window. Read-only inspection of the exact R1
  app shows `No dictation yet`, with no trace, timestamp, provider or outcome.
  `DictationOperation` creates a trace only after capture/transcriber startup, so this
  does not distinguish an unadmitted shortcut from a startup failure. Retained waveform
  status remains unobserved. No prior failure or success is inferred.
- The orchestrator authorized one coordinated physical Local retry. Preflight preserves
  PID 62901, parent 25015 and start 08:46:42. Dictation is Local Ready/Ready, Test
  microphone enabled and Ctrl+Option+D. General shows Microphone Granted and Device
  Control and Data Access Granted. Closed the diagnostic, restored Dictation and
  focused the existing blank disposable `Untitled 2` First Text View.
- After explicit physical NOW instructions, Aidan reports `Recording started, I spoke
  and stopped it`. A bounded actual-PID CoreAudio query independently shows input start
  at 19:56:56.502 BST and stop at 19:57:08.095, with one-channel 16 kHz input.
  This supports capture start/stop, not speech amplitude or transcription success.
- Settled AX and screenshots still show blank `Untitled 2`. Local Ready/Ready and
  enabled Test microphone support idle settlement. Input now shows `MacBook Pro
  Microphone`, whereas preflight showed `System default`; the agent made no such
  change. User attribution remains pending. No insertion acceptance is claimed.
- Evidence is `.build/local-productionization/stream4-local-last-dictation-oct11.json`
  and `stream4-local-physical-retry-oct11.log`. The orchestrator requested existing
  postattempt Last Dictation and retained menu status. Read these before another
  recording or speech operation clears retained errors. No source/settings mutation,
  synthetic hotkey, agent capture, paid call, restart, TCC/device action or rebuild ran.
  Stream 4 remains Blocked on S4-FUNCTIONAL-01.

- Aidan reopened Last Dictation after the actual retry. It now reports
  `9s · 9 words · 1 commits · 2 requests: 1 unchanged, 1 cancelled · paste attempted`.
  Final text is `Hello, Tailwind to my computer again, isn't this fun?`. The expanded
  final revision shows that same window and reply, with unchanged result in 0.5 s.
  This establishes nonempty transcription and cleanup for a new retained operation.
  The displayed sentence differs from the supplied phrase; user attribution of the
  actual phrase and foreground target at stop is pending. The UI has no absolute
  timestamp, provider or destination, so none was extracted or assumed.
- A fresh independent read-only source diagnosis found no established stream 4 paste
  regression. `Clipboard.insert` reports attempted after posting Command+V and a
  bounded 400 ms wait, whether confirmation succeeds or times out. Destination is
  captured at finishing, so a different field focused at stop can legitimately be
  captured. The stream 4 diff leaves Clipboard, Destination, DictationOperation and
  LastDictationWindow unchanged. Completed transcription and attempted paste do not
  establish insertion into the intended TextEdit window. No implementation fix is
  justified before attribution. No clipboard export, new capture or speech ran.


## Paste diagnosis and free Local speech continuation, 2026-10-11

- Aidan confirms the retained sentence roughly matches what he spoke and that TextEdit
  was active after clicking Untitled 2 before starting. This resolves the phrase and
  starting-target uncertainty. The finishing destination remains absent from the trace.
- Read-only clipboard equality against the known final sentence initially returned false.
  No unknown clipboard content was exported or pasted. A bounded capture/finish TCC and
  sandbox query showed Ghostty microphone authorization with authValue 2 and no matching
  AX, event or sandbox denial. That absence does not establish event delivery.
- Fresh independent bounded diagnosis found no Required source defect in the owned stream
  4 change. The unchanged paste adapter reports attempted after a matching destination,
  clipboard write and Command+V path, whether confirmation succeeds or falls back after
  400 ms. Target timing, synthetic event delivery, pasteboard publication or another writer,
  and delayed paste after restoration remain possible and unproven. No transport correction
  or unchanged build is justified by this evidence.
- With orchestrator authorization, Last Dictation Copy text produced the exact known
  transcript by private equality check. Deliberately focusing the same disposable Untitled 2
  and CUA Command+V inserted that exact sentence, verified by AX. Command+Z removed only
  this test insertion and restored the blank field. Clipboard/TextEdit recovery passes;
  EchoType automatic insertion remains unproven. Evidence is
  `stream4-local-paste-diagnosis-oct11.json` under `.build/local-productionization/`.
- After a listen-now notice, one free Local sentence was admitted at 20:10:57 BST. The
  lead then sent Escape while trying to dismiss Last Dictation. It did not dismiss the
  window, and natural completion cannot be inferred from that attempt. Aidan was changing
  audio devices and requested a repeat. His device choice was preserved.
- The exact authorized repeat, `This is a short offline speech check.`, was admitted once
  at 20:11:51 BST with networking denied. No keys or UI/device changes ran during it.
  Aidan confirms the full sentence was heard. Manage files subsequently shows Dictation,
  Read Aloud and all-model removal enabled, establishing operation and lease settlement.
  Actual offline Local speech audible completion passes. Evidence is
  `stream4-local-short-speech-repeat-oct11.json`; the first attempt remains separately limited.
- A longer free Local reading was admitted at 20:13:04 BST after a new listening notice.
  Speech/all removal became disabled while Dictation removal stayed enabled. Selecting
  xAI for the next Read Aloud operation retained Local Ready and protected speech/all files.
  No paid operation was admitted. CUA Escape from focused disposable TextEdit did not
  release the protected lease. Physical cancellation or natural settlement is pending.
  Evidence is `stream4-local-captured-switch-cancel-oct11.json`. No files were removed.

- Fresh focused evidence closure passes with no Required finding or blocking misclaim.
  It verified the diagnosis dispositions and new retained JSON records without source,
  UI, capture or inference actions. Manual recovery is correctly limited, the full audible
  repeated offline sentence and enabled removal controls support completion and settlement,
  and protected files across the next-provider switch support retention of the captured
  Local lease. Cancellation remains unproven. No source correction or repeated build ran.


## Read Aloud provider restoration, 2026-10-11

- Aidan missed the physical Escape prompt, selected text and invoked Read Aloud himself.
  His screenshot shows `Error reading` and a POSIX Code 1 URLSession failure. Read-only
  inspection confirms the next Read Aloud provider was still xAI from the captured-provider
  test. The retained offline profile denies networking. Same-PID logs show failed socket
  connects with `Operation not permitted` and URLSession Code 1 completions between
  20:15:29 and 20:16:31 BST. This supports blocked network access, rather than a new Local
  synthesis failure. The screenshot task identifier `2DCB2F62-22E1-43ED-B262-98BC7B589B96`
  matches the Code 1 completion at 20:15:35.517 BST. Private host fields and multiple
  task identifiers do not establish the exact operation count.
- The word `Dictation` in that reading error comes from the controller's default error
  wording, also used for an unrecognized Reader error. No source edit is authorized by
  this user question and none ran. The read hotkey stops an active Reader, and only
  admits a selection from idle. A preemption or replacement sequence is not inferred.
- Restored only the isolated candidate's Read Aloud provider to Local using its native
  picker. Its retained Local voice is Heart and speed is 1.2. Dictation remains Local
  Ready/Ready with Test microphone enabled and the user's current input device preserved.
  PID 62901, parent 25015 and original 08:46:42 start are unchanged.
- Read Aloud now reports Installed, consistent with release of an unused prepared runtime
  after its selected provider changed to xAI and the Local operation settled. Freshly
  reopening Manage files shows Dictation, Read Aloud and all-model removal enabled,
  supporting current operation and lease settlement. The already-open sheet initially
  retained disabled speech/all controls, so that old rendering is not current lease
  evidence. No files were selected for removal or removed.
- Evidence is `stream4-local-read-reset-oct11.json` and its bounded actual-PID network log
  under `.build/local-productionization/`. No new capture, speech or paid request, restart,
  source change, TCC/device change, production action or build ran. No paid spend is
  claimed from denied networking. Actual physical Escape cancellation and automatic Local
  insertion remain unproven. Stream 4 remains Blocked on S4-FUNCTIONAL-01.


## Physical Local reading cancellation, 2026-10-11

- After restoration, the orchestrator authorized explicit installed-only Read Aloud
  preparation. The native Prepare action showed Zero KB download and reached Ready.
  Dictation stayed Ready. Aidan then answered READY before the starting notice.
- One free Local reading was admitted at 20:20:42 BST, with both feature providers Local.
  The request repeated a cancellation instruction seven times, long enough for an
  immediate physical Escape while playing. MCP replied `Speaking.`. No synthetic key ran.
- Aidan confirms he heard the voice and it stopped when he pressed physical Escape.
  Freshly opened Manage files showed Dictation, Read Aloud and all removal enabled.
  Subsequent Local settings retained Ready transcription and voice. This supports actual
  audible physical cancellation, operation settlement and lease release. No files were
  removed, paid request made or device changed.
- Evidence is `stream4-local-physical-cancel-oct11.json`. This retry resolves physical
  Escape cancellation; the earlier synthetic Escape attempt remains unproven. Automatic
  Local insertion is still outstanding. PID 62901 and Local/Local selections are preserved.


## Restoration and physical cancellation evidence closure, 2026-10-11

- Reviewer: independent focused evidence-review subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Scope is the Read
  Aloud provider restoration and Physical Local reading cancellation sections, their
  retained JSON records and bounded network log, against the plan, specification and
  existing Reader, DictationController, LocalSetup and native storage semantics. Base
  and HEAD are `868f5ea3e839f3510afa68a9aef3eb7966f100b5`. Previously reviewed
  uncommitted stream 4 implementation and later Dictation evidence are outside scope.
- Verdict: Required findings none. Optional findings none. Questions none. No new
  blocking misclaim remains within this evidence closure. Stream 4 functional acceptance
  remains blocked; these records do not establish automatic Local insertion.
- Retained PID 62901 network records show connectx EPERM and URLSession POSIX Code 1
  failures during the recorded offline xAI selection. The screenshot task identifier
  supplied by the lead, `2DCB2F62-22E1-43ED-B262-98BC7B589B96`, matches the retained
  completion at 20:15:35.517 BST. This supports the offline network-denial diagnosis for
  the shown error. It establishes neither the exact operation count nor a Local synthesis
  failure. No private host or credential content is reproduced.
- The controller's default error wording explains `Dictation` in an otherwise reading
  error. Its read hotkey stops an active Reader and admits selection only from idle.
  No replacement sequence is inferred. Restoring only the next Read Aloud selection to
  Local, preserving Dictation and its input device, agrees with independent feature
  choices. Installed after switching away is consistent with releasing an unused voice
  runtime; it does not mean Ready. Freshly reopened storage controls, rather than the
  already-open sheet's old rendering, support the restoration settlement claim.
- The subsequent explicit Zero KB preparation reached Ready before the single free
  Local cancellation retry. MCP `Speaking.` proves admission only. Aidan's separate
  confirmation that he heard the voice stop when he pressed physical Escape supplies
  the audible cancellation evidence. Reader.stop cancels the stream and stops playback;
  Reader.run joins stream closure and cleanup before releasing its lease. Freshly opened
  storage controls permit all removal only after applicable operation/preparation guards
  clear. Together, the user report and supplied fresh control observations support
  physical cancellation, operation settlement and lease release. Ready after cancellation
  is consistent with retaining prepared runtimes while Local remains selected.
- The earlier synthetic Escape attempt remains unproven. No files were removed and no
  paid request or successful denied-network xAI operation is inferred. PID/UI states,
  screenshot attribution and audibility are supplied lead/user evidence, not fresh live
  observations by this reviewer.
- Verification used scoped file reads only. No GUI control, process inspection or launch,
  capture, speech, inference, credential inspection, preference mutation, build or test
  ran. Only this closure section was added. No optional suggestion was promoted and no
  implementation correction is required by the assigned evidence.


## Controlled Local insertion retry, 2026-10-11

- The first coordinated retry after physical cancellation had no confirmed user outcome.
  Aidan then explicitly asked to try again and stay in TextEdit. Preflight checked idle
  Local Dictation Ready/Ready and enabled Test microphone, preserved his current device,
  verified the existing blank Untitled 2 and refocused its First Text View. Both feature
  providers remain Local. No capture shortcut was sent by the agent.
- The orchestrator gave physical Ctrl+Option+D, wait for Recording, speak `This is a
  local dictation test.`, stop and remain in TextEdit until insertion or 30 seconds
  before returning to T3. Read-only AX observations during the interval showed the
  blank target and its focused text field. Aidan reports the field remained blank
  after recording and staying there for 30 seconds. The final AX and screenshot
  independently confirm the blank target. No text was erased or manually inserted.
- A bounded actual-PID 62901 audio query, including info/debug, contains prior speech
  output but no new input/start/stop events for this retry. This absence does not prove
  a shortcut was missed or capture failed, and current trace/error attribution remains
  necessary. Settings is idle Local Ready/Ready. Native Window menu lists only Settings;
  Last Dictation is closed and no supported diagnostic API exposes its retained state.
  The orchestrator asked Aidan to open it once and retain the waveform menu status.
- Fresh General settings shows Microphone and Device Control and Data Access Granted.
  The permission row reads actual AVCaptureDevice authorization and AXIsProcessTrusted,
  with no validation override. Validation suppresses the prompt only. These readings
  establish current API grant status, not successful candidate CGEventPost delivery.
- Evidence is `stream4-local-controlled-insertion-oct11.json` and its bounded audio log.
  No new capture, speech, paid call, restart, TCC/device change, source edit or build ran
  during this diagnosis. There is no further blind retry. Required automatic insertion
  remains blocked pending retained operation/error attribution and supported diagnosis.


## Controlled Local insertion diagnostic review, 2026-10-11

- Reviewer: independent read-only diagnostic subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Base and HEAD are
  `868f5ea3e839f3510afa68a9aef3eb7966f100b5`, with the previously reviewed stream 4
  diff. Read the packet, plan, specification, retained controlled-attempt JSON and
  relevant insertion, operation, controller, hotkey, validation and permission sources.
- Verdict: Required source findings none. Optional findings none. One evidence question
  remains: was the latest controlled attempt admitted, and did startup fail before
  creating a trace? Stream 4 remains blocked on
  actual automatic Local insertion. This review does not establish a transport defect.
- Aidan reports the target stayed blank after 30 seconds. The lead's retained AX and
  screenshot observations show the blank disposable Untitled 2 field focused after the
  outcome, and Local Ready/Ready with idle controls. These are supplied observations,
  not fresh live observations by this reviewer. The bounded actual-PID input query did
  not independently establish new capture for this retry. The lead subsequently obtained
  the retained trace through authorized Copy as JSON, gated against the exact known
  transcript before export. Read-only inspection of
  `stream4-retained-dictation-trace-oct11.json` verifies `startedAt` 19:00:32 UTC,
  `endedAt` 19:00:40 UTC, completed outcome and attempted insertion. These timestamps
  precede the latest controlled instructions around 19:26 UTC. The old Hello, Tailwind
  transcript therefore establishes no new completed operation for this retry. Its
  timestamps also do not match the separately recorded 19:56 BST capture interval;
  this review does not assign those two records to the same operation.
- `Views/SettingsView.swift:819-821` reads actual microphone authorization and
  `AXIsProcessTrusted()`. There is no validation override reporting a fabricated grant.
  The validation guard in `HotkeyMonitor.swift:46` only disables prompting; the real
  active event tap is still installed. The retained offline sandbox allows default
  operations while denying networking and specified real-user file roots. It does not
  explicitly deny synthetic event posting or pasteboard access. This source evidence
  does not prove runtime delivery of an event posted by PID 62901.
- `Clipboard.swift:32-37` constructs key-down/up CGEvents and posts them at the HID
  tap. Creation is optional and posting returns no delivery result through this adapter.
  There is no separate event-post authorization check or delivery record. Explicit
  Last Dictation Copy followed by CUA Command+V establishes that known transcript
  publication and this TextEdit field can work. CUA posts from a different sender, so
  that success does not establish the validation process's synthetic event delivery.
- `Clipboard.swift:104-130` returns paste attempted only after its destination check
  matches, it writes the transcript and runs the Command+V path. Its confirmation can
  succeed early or end unconfirmed after 400 ms. Restoration then occurs only if the
  saved clipboard was nonempty, its snapshot stayed valid and the app still owns the
  write count. A delayed consumer could miss the transcript after restoration, but
  neither consumer timing nor restoration is observed here. Waiting in TextEdit for
  30 seconds does not extend that 400 ms ownership window. A restoration race remains
  unproven, and increasing the delay is not an evidence-backed correction.
- `DictationOperation.finish` captures the destination at finishing, before capture
  stop and final transcription/revision. `DestinationFocus.capture/verify` compares
  two bounded focus samples and retained application, window and field identities.
  Matching proves the captured field is still current at the write boundary; the trace
  does not record which field that was. The hotkey consumes key-down and repeat events.
  The paste explicitly sets Command flags, but there is no wait for physical modifier
  release or release-state record. Neither a changed finishing destination nor held
  modifiers is demonstrated by the current observations.
- Last Dictation has now been reopened, and the retained JSON resolves its attribution
  as an older operation. Its prior absence from the native Window menu was expected
  because `App.swift:95` removes that scene's commands. The next evidence is retained
  waveform-menu error/status and the actual admission/startup state, before a new
  operation clears them. Do not repeat the recording to obtain that evidence.
- `DictationOperation.startAndTranscribe` creates its trace only after readiness,
  capture and transcriber startup succeed. `run` catches earlier startup failure and
  returns a nil trace; `DictationController.startDictation` replaces `lastTrace` only
  when the result contains one, then retains a startup error and returns to idle.
  Thus an older trace plus current idle controls is consistent with an unadmitted
  hotkey, failed startup or cancellation before trace creation. It does not establish
  which happened. `HotkeyMonitor.handle` dispatches only matched chords while hotkeys
  are active and only initial key-down events; `hotkeyPressed` starts from idle,
  ignores Test and requests commit for an existing Dictation. Commit while still
  starting is ignored by `canCommit`. Current readiness or grant rows cannot prove
  that an earlier key event crossed those admission boundaries. No such cause is
  demonstrated. Inspect the retained menu error first; a displayed startup error can
  narrow this branch without new capture or source instrumentation.
- If a new attempted trace is established, runtime event-post permission/delivery,
  clipboard ownership during the 400 ms window and actual finishing destination are
  the missing evidence. Existing UI and trace do not expose those values. Do not infer
  their answers from CUA paste, the General grant row, absent denial logs or later
  target focus. No source correction, rebuild or additional recording is justified
  solely by the evidence reviewed here.
- Verification used scoped file reads and diff inspection only. No GUI action, process
  inspection or launch, TCC action, capture, speech, inference, credential inspection,
  preference/source mutation, build or test ran. Only this diagnostic section was added.


## Controlled retry retained trace attribution, 2026-10-11

- Aidan reopened Last Dictation once. It still shows the earlier `Hello, Tailwind to
  my computer again, isn't this fun?` sentence, 9 seconds, 9 words and paste attempted.
  The authorized Copy as JSON export was read only after matching that known final
  sentence. Retained JSON reports start `2026-10-11T19:00:32Z`, end `19:00:40Z`,
  completed and insertion attempted. This operation predates the controlled retries
  by more than 20 minutes; it is not their new paste result.
- This unchanged retained trace and absent new input log mean latest Dictation admission
  or capture is still unproven, despite the reported recording and blank target. A
  startup failure can precede trace creation, which occurs after capture and transcriber
  startup. Owned preferences show hotkeysActive true. No transport fix follows from
  this evidence. Retained waveform status/error is requested once to distinguish
  startup failure from an unadmitted shortcut. No further physical retry was requested.
- Evidence is `stream4-retained-dictation-trace-oct11.json`, referenced from the controlled
  insertion JSON. The known trace Copy changed only the disposable validation clipboard.
  No unknown clipboard export, inference, paid call, source edit, build or restart ran.


## Live Local admission and insertion, 2026-10-11

- Aidan reports the retained waveform menu was Ready with no error. The lead then
  verified the same offline R1 PID 62901, parent 25015, original 08:46:42 BST start,
  Local Dictation Ready/Ready, enabled Test microphone, Ctrl+Option+D and the user's
  MacBook Pro Microphone. Existing Untitled 2 was blank and focused. No agent capture
  shortcut was sent. The orchestrator coordinated physical start separately from commit.
- Aidan reported Recording. Read-only Settings showed Test microphone disabled. Actual
  PID logs establish input capture starting at 20:36:21.754 BST and stopping at
  20:39:53.637 BST. They also include an earlier 20:35:51–20:36:01 input interval;
  exact operation count and that shorter interval's attribution are not inferred.
- After the Recording report, the lead restored the blank First Text View with one
  click and promptly relayed STOP READY. No synthetic stop, paste, clipboard write or
  target text edit ran. Aidan subsequently reported seeing text in the Dictation overlay
  and using the shortcut to commit it himself. Fresh AX then showed a substantial
  dictated paragraph in the formerly blank Untitled 2, still focused, and enabled
  Test microphone in Local Ready/Ready Settings. Actual insertion and idle settlement pass.
- Physical commit is the existing workflow. DictationController starts from idle and
  commits an existing Dictation on the next matched hotkey. DictationOperation captures
  the destination when finishing, stops capture and inserts after finalization.
  SessionMachine silence only renders Paused while audio continues; it does not commit
  except at the hard cap. There is no separate review or third-press requirement.
  The requirement is app insertion after user commit, not insertion merely after silence.
- The paragraph differs from the prompted short sentence. Its audio source and exact
  transcription fidelity were not established, so this run proves actual capture and
  transport rather than sentence accuracy. The existing paced bench quality limits remain.
  The user text was preserved. No new trace was exported; the stale 19:00 trace remains
  historical and is not used to attribute this result. Direct target delivery supplies
  stronger insertion evidence than a trace's paste-attempted marker.
- Evidence is `stream4-live-admission-oct11.json` and its bounded actual-PID audio log
  under `.build/local-productionization/`. No new speech or paid call, restart, TCC/device
  mutation, source correction, rebuild or test ran. The offline candidate is preserved.

## Final stream 4 acceptance audit

- The final live result supplies the outstanding actual Local microphone/hotkey and
  app insertion evidence. Prior independently reviewed evidence supplies successful xAI
  Dictation with Local Read Aloud selected, audible xAI Read Aloud with Local Dictation
  selected, offline Local audible completion, explicit installed-only preparation,
  setup cancellation/retry, captured Local lease protection across next-provider switching,
  physical Escape cancellation, settled removal controls and disposable Dictation removal
  without silent reinstallation. Local speech is proven through MCP; the packet's
  hotkeys/MCP wording does not require a duplicate successful physical Read Aloud run.
- Combined chosen-set paced quality and measured process footprint, bench retirement,
  deterministic checks, signed production/R1 packaging, S4-R1 correction and independent
  closure were already complete. The final unchanged candidate retains 164 Core and
  88 App passing tests and signed-build verification. No repeated unchanged build or
  model run is needed to interpret the latest evidence.
- Earlier blocked/remaining statements below their historical dates describe those
  stages only. S4-FUNCTIONAL-01 can be resolved after fresh evidence review and closure.
  Public-release licence/provenance obligations remain a separate release hold. No merge,
  publication, production action or further paid request is authorized.


## Live admission and insertion independent review

- Reviewer: independent focused evidence-review subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Reviewed the new
  live admission JSON/audio log, Live Local admission and insertion and Final stream 4
  acceptance audit sections, retained recovery/speech/cancellation records, packet,
  plan and specification, and DictationController, DictationOperation, SessionMachine,
  PillView and Clipboard semantics. Base and HEAD are
  `868f5ea3e839f3510afa68a9aef3eb7966f100b5`; the previously reviewed implementation
  remains unchanged.
- Verdict: Required findings none. Optional findings none. Questions none. The supplied
  fresh target observation and user commit report close the outstanding Local capture
  and insertion evidence gate. No new source correction is justified. S4-FUNCTIONAL-01
  can be resolved after lead closure; this review does not perform acceptance or the
  separate whole-feature review.
- The retained actual-PID log independently contains input start at 20:36:21.754 BST
  and stop at 20:39:53.637 BST for PID 62901. The earlier 20:35:51–20:36:01 interval
  stays separate. The user reported Recording and later a physical shortcut commit.
  Supplied AX observations show active controls disabled, then a substantial paragraph
  in the formerly blank focused Untitled 2 and idle controls enabled. No agent paste
  or synthetic capture/commit key was used. Together these support actual capture,
  app insertion and settlement. AX and physical user actions are supplied lead/user
  evidence, not fresh UI observations by this reviewer.
- DictationController.swift:208–215 starts from idle and commits an existing Dictation.
  DictationOperation.swift:131–135 admits commit only while capturing, and its finishing
  routine captures the destination before stopping input and finalizing. SessionMachine
  silence changes the displayed state to Paused while audio continues; PillView shows
  the same stop shortcut while paused. App insertion follows user commit. No separate
  review phase or third shortcut is required, so the user's need to commit is expected.
- Clipboard's attempted result remains weaker than confirmed destination delivery.
  Its matching destination check, Command+V path and bounded confirmation do not make
  an attempted trace proof of paste. The fresh formerly blank target now supplies that
  missing delivery evidence. The stale 19:00 trace and prior manual Copy/paste recovery
  are not used to attribute this result. No clipboard-delay or event-delivery fix follows.
- The observed paragraph differs from the prompted sentence. No audio reference or new
  trace establishes exact words, cleanup accuracy or content origin. This limitation
  does not negate the observed capture/insertion result, and the audit correctly keeps
  prior paced quality limitations. No transcription-quality claim is added.
- Retained independent closures support xAI physical Dictation with Local Read Aloud
  selected, audible xAI MCP reading with Local Dictation selected, offline Local MCP
  speech completion, installed-only preparation, setup cancellation/retry, protected
  captured Local speech leases across a next-provider change, physical Escape stop and
  settlement, and disposable removal without reinstallation. The packet's hotkeys/MCP
  requirement is satisfied through physical Dictation and MCP speech across the recorded
  provider arrangements. It does not require repeating every provider/entry combination.
  Successful Local selection-reading hotkey playback is not claimed. Prior denied-network
  xAI reading remains a failure observation, not successful Local speech.
- Previously reviewed deterministic tests, signing, pruning and combined measurements
  remain applicable to the unchanged candidate. Public-release provenance/licensing
  obligations remain a separate hold. The scoped evidence contains no blocking acceptance
  misclaim. No repeated build or inference is needed for this review.
- Verification used scoped file reads only. No UI operation, process control or inspection,
  test, build, capture, speech, inference, credential access or source mutation ran.
  Only this independent review section was appended.

## Live admission and insertion focused closure

- Reviewer: independent focused closure subagent, inherited model and effort, Codex
  harness. Applied code-review, coding practices and unslop. Scope is the accepted live
  admission/insertion review, the corrected JSON limits, retained audio log and relevant
  prior speech/cancellation evidence against packet 04, plan and specification. Base and
  HEAD are `868f5ea3e839f3510afa68a9aef3eb7966f100b5`. The previously reviewed
  uncommitted stream 4 implementation remains unchanged and was not reviewed again.
- Verdict: Required findings none. Optional findings none. Questions none. The accepted
  dispositions and evidence correction leave no blocking misclaim. S4-FUNCTIONAL-01 can
  resolve under the packet/specification evidence requirements. This closure does not
  perform stream acceptance or the separate whole-feature review.
- The JSON now permits the recorded target-focus click before STOP READY and states
  that no focus-changing action followed until insertion and idle were observed. This
  matches the packet's explicit focus restoration after Recording. The earlier wording
  denying all focus actions after READY no longer contradicts that action. The click
  establishes the finishing target; it supplies neither capture nor inserted text.
- PID 62901's retained input log independently records start at 20:36:21.754 BST and
  stop at 20:39:53.637 BST. The earlier shorter interval remains unattributed. Supplied
  user Recording and physical commit reports, active-to-idle Settings observations,
  and the substantial paragraph in the formerly blank focused target support actual
  capture, app delivery and settlement together. No agent paste, clipboard write, target
  edit or capture/commit shortcut is attributed to this run. AX states and physical
  actions are supplied lead/user evidence, not fresh observations by this reviewer.
- App insertion follows physical commit in the accepted workflow. The user's report
  that he used the shortcut to commit introduces no extra review phase or unmet silence
  requirement. The stale trace and earlier deliberate Copy/paste recovery remain
  historical evidence. Neither is used to establish this delivery. The unknown audio
  reference and paragraph's difference from the prompted sentence limit fidelity and
  content-origin claims; they do not negate the observed insertion. Existing quality
  limits remain and no transcription-accuracy claim is added.
- Prior retained Local MCP speech evidence includes Aidan's confirmation of full audible
  completion and subsequent settled controls. The separate physical Escape retry includes
  his audible stop confirmation and settled removal controls. Together with the reviewed
  mixed-provider and lifecycle evidence, these satisfy the packet's hotkeys/MCP requirement.
  No successful Local selection-reading hotkey playback is claimed or required as a
  duplicate entry-path trial. MCP admission alone and the denied-network xAI reading
  remain insufficient playback evidence.
- Previously reviewed pruning, deterministic checks, signing and combined measurements
  remain applicable to the unchanged implementation. Public-release provenance/licensing
  obligations remain a separate hold. Historical blocked entries in the packet and plan
  describe earlier evidence stages; the lead can now update the functional disposition.
  No optional suggestion was promoted and no source correction is required.
- Verification used scoped file reads only. No GUI/process action, capture, speech,
  inference, preference or credential access, test or build ran. Only this closure section
  was appended; the plan and all earlier review sections remain unchanged.


## Acceptance handoff

- Accepted after the Live admission and insertion independent review and fresh focused
  closure, both with no Required finding. The acceptance audit above is complete;
  historical blocked statements describe earlier phases and are superseded here.
- Final read-only provenance matched all 74 source/package hashes, both remediation
  test hashes and production/R1 executable hashes. No source behavior changed after
  the passing 164 Core/88 App tests, release packaging and strict signing checks.
- Scoped implementation and this packet/plan are committed together. Unrelated
  app-testing and Qwen follow-up specs, Final's packet and unassigned workflow scaffold
  files remain outside the stream 4 commit. Final owns the whole-feature review.
- Drift is limited to the independently reviewed validation identity/home isolation
  needed for real signed-app evidence. Native UI, accepted provider contracts and model
  pins are unchanged. Public-release licence/provenance obligations remain a hold.
