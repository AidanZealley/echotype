# Workstream 2: Independent feature providers

Status: accepted on 2026-10-09 after recovery, independent review and fresh focused closure.

## Task packet

### Outcome

Dictation and Read Aloud independently select providers, preserve preferences and capture
providers at admission. Microphone Test follows Dictation; MCP speech follows Read Aloud.

### Scope

Migrate the legacy single provider into each missing new field, preserving explicit new
values and independent unknown-id fallback. Write only new fields. Keep keys provider-scoped,
reading preferences per provider and existing operation admission/cancellation rules.
Replace global credential blocking with feature-specific availability and captured-provider
error wording. Update existing Settings bindings only as needed to exercise independent
choices; retain native controls for reuse in stream 3, without introducing a temporary router.

### Required context

Specification Provider selection, Credentials and Implementation boundaries; Settings.swift,
SettingsStore, controller/operations, Reader, App and provider/readiness tests; stream 1 handoff.
Read affected decisions 0010 and 0025 as historical contracts being updated by this spec.

### Non-goals

Separate cleanup selection, generic/composite providers, changing model selection, native
Settings redesign or model installation/removal. Stream 3 owns local readiness side effects.

### Initial ownership

Sources/EchoTypeCore/Settings.swift, Providers/Provider.swift and Providers/Providers.swift;
Sources/EchoTypeApp/{SettingsStore,DictationController,DictationOperation,Reader,App,NotReady,MCPProcess}.swift;
SettingsView.swift only necessary provider/preference bindings; Settings/validation tests and
EchoTypeAppTests for routing, readiness, operation snapshots and wording. Extend adjacent request
construction only when the new persisted fields require it; record exact paths in the handoff.

### Required seams

Freeze two persisted choices and their migration semantics. Both operations receive their
provider directly. Document every runtime/preparation call site for stream 3. Do not add
new automatic download triggers or preserve the old provider property solely as a facade.

### Acceptance criteria

Legacy/partial/malformed settings migrate without losing unrelated preferences. Each choice
persists independently. Mixed-provider operations, Test and MCP use the correct provider/key.
Changing settings mid-operation never redirects active work or changes its error attribution.
One blocked feature leaves the other available. Existing hotkeys/admission behavior remains.

### Targeted verification

```sh
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter EchoTypeCoreTests
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter EchoTypeAppTests
swift build -c release --product EchoTypeApp
git diff --check
```

Use meaningful fake-provider tests for migration precedence, captured settings, mixed-provider
routing and independent credential failures. No paid API calls are required for those tests.

## Implementation handoff

- Base commit: `367a7ce165d9a8ac6610462877fdd9ef583dab42`.
- Outcome: independent feature selections are implemented and recovered from the
  existing dirty stream 2 files. All listed source/test edits were explicitly adopted
  before changing them. The recovery corrected main-actor access in the new fake
  credential closures. Independent review and fresh focused closure passed with no findings. The lead accepted
  the stream after all packet checks passed.
- Files changed:
  - `Sources/EchoTypeCore/Settings.swift` and `Providers/Provider.swift`.
  - `Sources/EchoTypeApp/App.swift`, `DictationController.swift`,
    `DictationOperation.swift`, `Reader.swift` and `Views/SettingsView.swift`.
  - `Tests/EchoTypeAppTests/ReadingOperationTests.swift`,
    `SpeechAdmissionTests.swift` and new `FeatureProviderTests.swift`.
  - `Tests/EchoTypeCoreTests/SettingsTests.swift` and `SettingsValidationTests.swift`.
  - Constructor compatibility only in `Sources/EchoTypeBench/Transcribe.swift` and
    `Tests/EchoTypeCoreTests/Integration/AppleTranscriptionLiveTests.swift`.
  - This packet records the implementation. No edits to `main.swift`,
    `SettingsDemo.swift`, `ParakeetModel.swift`, unrelated docs or deletions.
- Decisions and frozen dependency contracts:
  - Persist `dictationProvider` and `readAloudProvider` as provider-id strings.
    Decode legacy `provider` only to fill an absent new field. A present malformed,
    null or unknown new field independently falls back to the registry default;
    it does not inherit the legacy value. Encoding writes only the two new choices.
    Hotkeys, keyterms, language, device, reply settings and per-provider reading
    preferences retain their existing storage and validation.
  - There is no legacy `Settings.provider` facade. Dictation and Microphone Test
    capture `Providers[settings.dictationProvider]`; selection reading and MCP
    capture `Providers[settings.readAloudProvider]`. Each operation receives its
    provider directly. Transcription and cleanup stay together. Voice/speed and
    language resolve through the captured provider when constructing requests.
  - `DictationOperation.provider` and `Reader.provider` expose their captured
    dependency for error attribution. Factory injections receive the same Settings
    snapshot and Provider as production admission. Switching settings affects the
    next operation and cannot change an active operation's service, key or wording.
  - Credentials remain keyed by provider id. `refreshCredentialStatus` reports
    `dictationHasCredential` and `readAloudHasCredential` independently and reads
    one key when both use the same provider. Missing credentials fail before
    readiness and capture. The menu identifies the blocked feature, and the icon
    remains active when the other feature has its credential.
  - Existing native Settings controls bind each feature independently. Shared
    provider controls show each provider's key once; Test is offered only for the
    Dictation provider. Removal wording names affected selected features. Stream 3
    owns the approved sidebar redesign and local lifecycle.
- Exact runtime/readiness/preparation seams for stream 3:
  - `DictationController.start`, lines 130–136, observes both selections and checks
    credentials only. The old launch `readiness.check` call is removed. Selecting
    providers has no new installation or preparation trigger in the controller.
  - `DictationController.makeOperation`, lines 288–310, captures Dictation/Test
    settings/provider. `DictationOperation.startAndTranscribe`, lines 176–197,
    checks its captured credential, calls `checkReadiness`, opens capture, then
    calls `startTranscriber`. `checkReadiness`, lines 202–211, calls the captured
    provider's `readiness.check`, requires transcription Ready and disables
    cleanup if it was not Ready. `startTranscriber`, lines 215–228, calls
    `provider.transcription.start` with the captured request. Cleanup runtime use
    occurs in `DictationOperation.revise`, line 362 onward, through its captured
    Reviser, created at lines 193–195. Preserve the No cleanup policy.
  - `DictationController.startReading`, lines 214–248, captures Read Aloud settings
    and provider once. `readAloudPressed` and `speak`, lines 187–211, share this
    admission path. MCP's stdio `MCPProcess.deliver` sends to the GUI; the GUI
    observer in `DictationController.start`, lines 116–128, admits through `speak`.
    `Reader.read`, lines 94–130, checks the captured credential, calls
    `provider.readiness.check` at line 110, requires voice Ready and calls
    `provider.voice.speak` at lines 113–114 before pulling chunks.
  - `SettingsView.ReadAloudTab`, lines 226–229, follows the Read Aloud provider's
    readiness. `ProviderTab`, lines 315–317, follows the Dictation provider's
    readiness. `Followed`, lines 235–244, captures provider/language/voice.
    `Readiness.follow`, lines 721–736, checks once and again on `changes`, ignoring
    answers after cancellation. Its current comment still describes legacy setup
    side effects; update it with the stream 3 reporting-only contract.
  - Current local implementation still has legacy side effects. In
    `Providers/Local/LocalProvider.swift`, lines 46–54, one readiness check calls
    transcription, voice and cleanup `LocalModel.check`. In `LocalModel.swift`,
    lines 43–65, `check` starts missing downloads via `ModelStore.start`, then
    `startLoading` at lines 93–116 loads all installed manifests in an owned Task.
    These calls must become reporting-only, with explicit per-feature installation
    and preparation elsewhere. Runtime service closures in `LocalProvider.swift`,
    lines 28–44, only consume each LocalModel's loaded value. Stream 2 deliberately
    does not claim that Local selection, Settings or operations are download-free
    until stream 3 replaces this legacy lifecycle.
  - The stream 1 speech packaging contract remains intact: prepare Kokoro through
    its guarded verified installation and bundled pronunciation data; do not use
    FluidAudio manager.initialize or reintroduce G2P assets/runtime compilation.
- Verification:
  - Recovery Core run initially failed while compiling the newly added App test
    fixture's main-actor `keys` access. Both fixture closures now use
    `MainActor.run`. The following commands were rerun against the corrected tree.
  - `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test
    --filter EchoTypeCoreTests`: passed, 153 tests in 22 suites. Opt-in live/model
    checks stayed skipped. Log: `.build/feature-providers-recovery-core.log`.
  - Same environment and `swift test --filter EchoTypeAppTests`: passed,
    82 tests in 11 suites. Log: `.build/feature-providers-recovery-app.log`.
    New fakes cover both mixed-provider directions, successful service requests
    and provider keys, preserved settings, captured failure wording, Test,
    selection reading, MCP admission and independently blocked credentials.
  - `swift build -c release --product EchoTypeApp`: passed in 106.02 seconds.
    Log: `.build/feature-providers-recovery-release-app.log`. The pronunciation
    compiler emitted its previously documented missing `en_dict` diagnostic
    during generation; the resource build and app link completed successfully.
  - `git diff --check`: passed. Log:
    `.build/feature-providers-recovery-diff-check.log`. All builds/tests ran
    sequentially, with no inference or edits to the user's model store.
- Limitations / external checks: automated tests use fake services and no paid API
  calls. Actual signed production-app hotkey, microphone Test and MCP validation
  remains stream 4 work. Local explicit installation, per-feature preparation,
  unloading and storage management remain stream 3 work. The release build uses
  the shared dirty tree, preserving trial demo and timing edits; it is compilation
  evidence only and does not establish an isolated stream 2 app artifact.
- Specification drift: none. Historical decisions 0010 and 0025 describe the old
  single selection and readiness setup behavior; their final documentation update
  remains part of the later productionization consolidation.

## Independent review

- Reviewer and configuration: independent review subagent, inherited model and effort,
  Codex harness. Reviewed base and HEAD
  `367a7ce165d9a8ac6610462877fdd9ef583dab42` plus the complete current owned dirty
  diff and new `FeatureProviderTests.swift`, including the recovered trial edits.
  Applied the code-review skill, its coding practices and unslop. Read the packet,
  specification, decisions 0010/0025, stream 1 handoff and plan contracts.
- Verdict: pass for stream 2. No blocking finding remains in the reviewed scope.
- Required findings: none.
- Optional observations: none.
- Questions: none.
- Contract checks:
  - Each absent feature choice inherits legacy selection. A present malformed,
    null or unknown choice independently uses the registry default. Encoding
    writes only the new fields and retains unrelated settings and reading entries.
    No legacy Settings provider facade remains.
  - Dictation/Test and selection/MCP reading resolve their own provider at
    admission. Production factories pass that provider and the same Settings
    snapshot into the operation. Service requests, credential accounts and error
    attribution use the captured dependency throughout active work.
  - Credential status is separate for each feature, with one lookup when both
    select the same provider. Missing credentials fail before readiness or audio
    capture. Admission, interruption and cancellation paths retain their existing
    ownership rules. Cleanup remains part of Dictation with its No cleanup policy.
  - Native bindings use Dictation for language/keyterm limits and Test, and Read
    Aloud for voice/speed. Provider controls expose credentials once per provider
    and removal wording names the affected selected features.
- Verification performed by reviewer:
  - Inspected all 14 owned source/test paths, surrounding composition and request
    construction, SettingsStore, provider registry and key save/remove paths.
    Searched Sources/Tests for obsolete Settings provider references.
  - Ran `git diff --check`, which passed.
  - Read the supplied recovery Core/App/release logs and confirmed every owned
    source/test file predates each successful log. Core reports 153 tests in
    22 suites; App reports 82 tests in 11 suites, including both mixed-provider
    directions, captured settings/errors, Test, selection reading and independent
    credential failures. Release EchoTypeApp compiled successfully. These are
    supplied checks, reused without repeating builds or inference.
- Acceptance limits: the shared dirty release build establishes compilation,
  not an isolated stream 2 artifact or signed production-app behavior. Actual
  hotkey, microphone Test and MCP evidence remains the stream 4 gate. The exact
  legacy Local readiness/download/loading side effects listed in the handoff
  remain stream 3 work. This review does not claim reporting-only readiness or
  download-free Local selection/operations before that lifecycle replacement.

## Resolution

- Finding dispositions: independent review passed with no findings. No remediation was needed.
- Simplification/deletion pass: the lead inspected the owned diff. The legacy provider
  property and launch readiness trigger are removed. Two stored choices resolve directly
  to captured providers; no router, composite provider or temporary facade was added.
  Existing service contracts and native controls remain reusable by stream 3.
- Final verification: supplied fresh Core, App and release checks passed against the
  recovered implementation. The reviewer and lead independently ran `git diff --check`,
  which passed. No source changes were made after those checks. Fresh focused closure passed with no remaining required findings.

## Closure review

- Verdict: pass for stream 2 on 2026-10-09. The lead accepted the independent
  review's empty Required, Optional and Question categories. No remediation or
  source changes followed, so there are no fixes requiring another defect review.
- Remaining required findings: none.
- Verification: confirmed HEAD remains
  `367a7ce165d9a8ac6610462877fdd9ef583dab42`. All 14 owned source/test paths
  predate each supplied successful recovery log and the independent review record;
  no source drift is evident. Rechecked migration/encoding, admission factories,
  captured credentials/requests/error attribution and their focused tests against
  the handoff. Persistence and captured-provider contracts remain consistent.
- Reused the supplied Core result of 153 tests in 22 suites, App result of 82 tests
  in 11 suites and successful release EchoTypeApp build. Ran `git diff --check`,
  which passed. No builds, inference or model-store operations were repeated.
- Scope limits remain unchanged. Legacy Local readiness/download/loading side
  effects belong to stream 3. Signed production-app hotkey, microphone Test and
  MCP evidence belongs to stream 4. The shared dirty release build establishes
  compilation only. These outstanding gates do not block stream 2 closure.
