# Workstream 3: Explicit local setup and native Settings

Status: accepted on 2026-10-10 after independent reviews, focused closures and Aidan's conditional native UI approval was fulfilled.

## Task packet

### Outcome

Users explicitly download and prepare a feature in native Settings, see truthful readiness,
and reclaim EchoType-owned files. Choosing Local and checking readiness have no setup side effects.

### Scope

Implement the complete feature lifecycle with the existing verified store: requirements,
explicit consent, progress, cancellation, retry, installed-only preparation, shared concurrent
preparation and runtime release after unused selections settle. Setup ends Ready only after
preparation. Already installed assets offer Prepare/Retry without another download. Prevent
stale cancellation completions and publication/removal races. Retain the transcription-only
fallback when cleanup is unavailable as required by the spec.

Implement the chosen native sidebar and feature/provider/app pages. Local has separate model
cards plus compact storage and Manage files sheet. Manifests drive actual requirements;
filesystem inventory drives actual usage, including partial/generated/obsolete files. Removal
confirms scope, protects active work, releases loaded references and preserves unrelated caches,
settings and credentials. Shared keys appear once, including providers absent from the mock
such as Apple, with their existing appropriate setup information.

### Required context

Specification Settings, Installation, Readiness, Removal and acceptance; ../settings-variants.md;
../parakeet.md; stream 1 asset ownership and stream 2 call-site/settings handoffs;
Sources/EchoTypeApp/Views/SettingsDemo.swift as read-only layout/state reference.

### Non-goals

Generic model repositories, background auto-updates, cache eviction policies, uninstall helpers,
Qwen speech, new testing suite, public release or copying the mock's hard-coded sizes.

### Initial ownership

ModelStore.swift, ModelDownloadSource.swift, ModelManifest.swift, LocalModel.swift and
LocalProvider.swift under Providers/Local; LocalCandidates.swift for confirmed default selection
and chosen model/manifest definitions, including cleanup; ParakeetManifests.swift when required
for the complete boosted feature set; new feature installation/storage types there;
local loaders only for ownership/unloading or preventing fallback fetches; composition files
handed over by 2; Sources/EchoTypeApp/Views/SettingsView.swift and necessary new native panes;
SettingsStore.swift for observable installation status; focused store/lifecycle/app tests.
Use SettingsDemo.swift read-only and leave its removal to 4 after user acceptance.
Retain existing experimental declarations untouched unless required for these contracts;
transfer remaining candidate pruning to 4. Do not duplicate a temporary model catalogue.

### Required seams

Reporting, installation and preparation remain distinct. Status reads never load/download.
Explicit setup prepares only requested features, including installations before provider
selection. An operation may reload installed assets after restart/unloading but never fetch.
Cancelling setup prevents late Ready publication. Removal operates only on inventoried owned
paths and cannot race with an in-flight generation. Transfer API/ownership evidence to 4.

### Acceptance criteria

All spec installation/readiness/removal behavior works through real native controls, including
relaunch recovery, checksum/space/deletion failures and meaningful recovery actions. No missing
credential/model for one feature blocks the other. Only requested models load, UI stays responsive,
and switching away releases unused runtimes after work ends. Native forms/navigation support
keyboard/accessibility and both themes; Keyterms editor boundary/focus is clear in dark mode.
No production placeholder or demo action remains in the settings pages.

### Targeted verification

```sh
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter 'ModelStoreTests|LocalModelTests'
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter EchoTypeAppTests
scripts/build-app.sh release .build/local-productionization/EchoType.app
codesign --verify --deep --strict .build/local-productionization/EchoType.app
git diff --check
```

Add focused tests with temporary stores and controlled fetch/load tasks for no-side-effect
status, cancel/publication races, retained retry, feature isolation, protected removal and
unrelated-cache preservation. Add their actual filters to recorded checks. Inspect native UI
and setup states in both themes. Real destructive checks use isolated owned test assets, never
the user's model installation. Do not force cache deletion to reproduce first-use loading.

## Implementation handoff

- Base commit: `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`
- Outcome: implementation, independent review, the single remediation pass and fresh focused closure are complete. No required finding remains. Blocked at native Settings judgment, plan escalation `S3-UI-01`; changes remain uncommitted.
- Files changed:
  - `Providers/Local/ModelStore.swift`, `ModelDownloadSource.swift`, `LocalModel.swift`,
    `LocalProvider.swift`, `LocalCandidates.swift`, new `LocalSetup.swift`, and
    `KokoroSpeech.swift`; `Providers/Provider.swift` for preparation and operation leases.
  - `ParakeetModel.swift` adds only the tokenizer-cache resolution guard after
    `linkFolder`. Its existing loading timing edits remain with their recorded owner.
  - App `App.swift`, `DictationController.swift`, `DictationOperation.swift`, `Reader.swift`,
    `SettingsStore.swift`, `Views/SettingsView.swift` and new `Views/LocalSettingsPane.swift`.
  - Core `ModelStoreTests.swift`, `LocalModelTests.swift`, `KokoroSpeechTests.swift` and
    new `LocalLifecycleTests.swift`; App `DictationOperationTests.swift` and
    `ReadingOperationTests.swift`; this packet's Implementation handoff.
- Decisions and dependency contracts:
  - `Readiness.check` reports only. Explicit `LocalSetup.install` installs the requested
    feature set and prepares it before completion. `Readiness.prepare(feature)` prepares
    installed assets only and returns an operation lease. Concurrent callers join one
    load per service. Dictation's unavailable cleanup still permits unrevised transcription.
  - Leases cover Dictation's final revision and insertion, and Reader's backend/player and
    clipboard teardown. A provider switch releases unselected feature runtimes after the
    last lease settles. If selection changes during setup, that feature releases after setup
    and its leases settle. Explicit preparation before selection retains Ready. Removal checks
    affected feature leases and preparation under the same admission lock, releases affected loaded references, and keeps the other feature.
  - `SpeechStream.waitForClose()` is additive, with a default no-op for existing adapters.
    Kokoro joins its cancelled synthesis task before Reader releases the lease. Apple's
    existing cancellation schedules its MainActor end; xAI cancels StreamingResponse.
    Neither remote/system adapter writes EchoType-owned local model files. The accepted
    Kokoro phoneme/synthesis pipeline is unchanged.
  - Download cancellation invalidates publication under the store lock and cancels the
    URLSession. Setup has its own generation, so direct cancellation also prevents a late
    load or successful completion. Verified retained files remain reusable. Cancelling setup
    does not cancel preparation owned by an active operation.
  - Files verify by size and SHA-256 before publication and runtime loading. Reporting uses
    cheap completeness checks; hashing runs off the main actor during setup/preparation.
    Same-size corruption fails before runtime entry; explicit retry retains intact files.
    Requirements distinguish installed assets from complete retained downloads.
  - The confirmed default is boosted Parakeet plus Qwen3-4B and Kokoro. No rejected
    candidate declarations were removed. Existing Kokoro no-fetch guards remain intact;
    Parakeet rejects a conflicting real tokenizer-cache folder without changing it.
  - Inventory counts actual stored/generated/partial/obsolete bytes without following
    links. Known historical model names with full revision suffixes remain recognizable
    after candidate pruning, including both retired Qwen speech sizes. Unknown files remain
    untouched. Former G2P files have separate rows without double-counting parent bytes;
    parent deletion includes descendants and removes deeper paths first. Real external
    directories and links to other stores are preserved. Enumeration/deletion errors remain
    visible and the sheet refreshes after partial failure.
  - Native sidebar pages separate feature choices from shared provider setup, including
    Apple. Local cards open item-based consent initialized to the clicked feature, offer
    installed preparation/retry, and expose scoped removal plus individual obsolete-file
    cleanup. The Keyterms editor has a system-colour boundary and accent focus outline.
- Verification:
  - Final command: `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE
    swift test --filter 'ModelStoreTests|LocalModelTests|LocalLifecycleTests|KokoroSpeechTests|EchoTypeAppTests'`.
    Passed 21 Core tests in four suites and 84 App tests in 11 suites after remediation. Final log:
    `.build/local-setup-remediation-focused.log`. The packet's Core and App filters also ran
    separately during implementation; this final combined run supersedes earlier logs.
  - Temporary-store tests cover reporting-only status, no fetch during missing/installed
    operation preparation, shared loads, cancelled publication/preparation, direct setup
    cancellation, retained-vs-installed requirements, integrity after relaunch, reuse on retry,
    feature isolation/release, deselection during a suspended setup loader with and without
    an operation lease, preselection Ready, protected removal and unrelated-cache/file preservation.
    Controlled synthesis proves close joins a backend that ignores cancellation. App tests
    keep the lease through final revision/insertion and cancelled reading cleanup.
  - `scripts/build-app.sh release .build/local-productionization/EchoType.app` and
    `codesign --verify --deep --strict .build/local-productionization/EchoType.app` pass.
    Release log: `.build/local-setup-remediation-release.log`. Candidate base is
    `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` plus this uncommitted implementation and
    preserved working-tree changes. Candidate inventory is
    `.build/local-productionization/stream3-candidate.json`.
  - `git diff --check` passes. No commits, model downloads or real cache deletions were made.
  - Native light/dark checks used signed unique-id copies,
    `.build/local-productionization/SettingsInspectionLight.app` and
    `SettingsInspectionDark.app`. Their inspection-only executable wrapper execs the copied
    production code with the existing `--hud-demo` flag and appearance arguments, which skips
    the controller, hotkeys and GUI MCP observer. The unchanged production candidate retains
    its normal entry point. Both inspection copies pass strict deep signature verification.
    Their ids are `com.aidanzealley.echotype.stream3-inspection-light` and
    `com.aidanzealley.echotype.stream3-inspection-dark`. All owned inspection processes ended.
  - CUA screenshots record both themes' Local cards, actual inventory/storage sheet, and
    Keyterms editor focus. Consent requirements and combined feature choices were inspected;
    removal confirmation named Read Aloud and 98 MB, then was cancelled. No final setup,
    removal, credential, provider-choice or Keyterms-edit action was taken. Screenshots are
    in the implementation agent's tool transcript; CUA exposes no file-export API.
    After the item-based consent correction, the refreshed copies showed Read Aloud selected
    alone on first opening in both themes, then the dark copy showed the combined requirements.
    Those final consent checks were cancelled and both copies exited.
- Limitations / external checks:
  - Native inspection exercises production Settings with the controller disabled. Actual
    hotkeys, microphone Test, GUI MCP, offline inference, combined memory and real setup
    transitions belong to the signed functional gate in stream 4. Test/backend cancellation,
    failure and removal cases use controlled fakes and isolated temporary stores. No physical
    disk-full or permission-denial experiment was performed on the user's installation.
  - Aidan must judge the signed native UI after closure. Agent checks do not grant UI acceptance.
    The retained mock, demo dispatch, README, unrelated docs/deletions and existing Parakeet
    timing changes remain with their recorded owners. Plan transitions remain lead-owned.
- Specification drift: none. No model choices, new repository picker, generic router or idle
  eviction policy were introduced.

## Independent review

- Reviewer and configuration: independent review subagent, inherited model and effort,
  Codex harness. Reviewed base and HEAD
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` plus the complete owned uncommitted
  source/test changes and new files in the Implementation handoff. Applied the
  code-review skill, its coding practices and unslop. Read the specification, packet,
  Settings study, Parakeet evidence, accepted stream 1/2 contracts and plan conventions.
  The Parakeet tokenizer guard is included; unrelated timing instrumentation, demo
  dispatch/source, README and documentation deletions remain with their recorded owners.
- Verdict: changes required. Two correctness findings block stream 3 closure. Aidan's
  native Settings gate remains pending independently of these findings.
- Required findings:
  - S3-R1. Release a feature switched away during setup after setup settles.
    `Sources/EchoTypeCore/Providers/Local/LocalSetup.swift`, lines 98–105, 158 and 197.
    Start explicit setup while the feature selects Local, switch that feature to another
    provider while its loader is suspended, then let setup finish. `select` calls
    `releaseUnused`, which preserves the feature because it remains in `setup`. The
    setup defer only clears `setup` and its generation. No later release runs, so the
    loaded runtime stays in memory until another selection update or operation occurs.
    This violates the required release after unused selections settle. Track a selection
    transition away during setup and release that feature once setup and its leases end.
    Preserve the separately required case where explicit setup before selecting Local
    completes Ready. An unconditional release of every unselected setup would break it.
    Add a controlled suspended-loader check for the selection-away trigger and retain the
    existing preselection setup check.
  - S3-R2. Give shared provider controls the selected provider's view identity.
    `Sources/EchoTypeApp/Views/SettingsView.swift`, line 54 and lines 429–437.
    Apple and xAI use the same default detail branch and the same `ProviderControls`
    position. Navigating from Apple to xAI changes its input without replacing its
    SwiftUI identity. Apple's one-shot task has already set `loaded = true` without
    reading a key, so xAI inherits that state and its task does not reload the saved xAI
    key. Settings shows the empty Save form instead of the existing key's Replace and
    Remove controls. The old provider loop explicitly supplied provider identity; the
    redesign removed it. Add `.id(provider.id)` at this call site, or an equivalent
    complete reset and provider-keyed task. Verify Apple to xAI navigation with a saved
    key through a controlled fixture, preserving the real user's Keychain.
- Optional observations:
  - S3-O1. Historical files have no feature association in scoped removal.
    `Sources/EchoTypeCore/Providers/Local/LocalSetup.swift`, lines 109–118 and 182–183;
    `Sources/EchoTypeApp/Views/LocalSettingsPane.swift`, lines 163–168.
    Inventory recognizes old pinned revisions and `espeak-english-trial-fd28f646`, but
    feature attribution uses only current manifest directory names. Consequently Remove
    Read Aloud/Dictation models omits their historical revisions, and speech's generated
    trial directory gets the generic obsolete-only confirmation. Individual selection
    and Remove all still allow removal, so this does not block acceptance. Consider
    retaining historical feature ownership alongside the existing historical names so
    convenience actions include the complete owned feature set and name its purpose.
    Keep current-runtime active-work protection distinct from historical attribution.
- Questions: none.
- Contract checks:
  - Local status reads report without fetch or load. Explicit installation verifies
    retained/installed files, prepares only requested features and invalidates cancelled
    publication. Operations prepare installed files only and concurrent callers join
    one service loader. Cleanup failure retains unrevised transcription.
  - Operations hold leases through final dictation revision/insertion and reading
    backend/player/clipboard teardown. Kokoro close joins synthesis. Removal shares the
    lifecycle admission lock with preparation, checks download tasks under the store
    lock, drops affected loaded references and preserves the other feature.
  - Filesystem inventory counts retained, generated and recognizable obsolete payloads
    without following links. Unknown files, external real directories and links outside
    the owned store are excluded from removal. Parent/obsolete-frontend rows avoid double
    counting, and the UI refreshes after partial deletion failure.
  - Native sidebar pages separate feature assignment, provider setup and app concerns.
    Model manifests drive consent requirements; feature availability and Keyterms focus
    use real controls. Public preparation/lease/close additions preserve adapter defaults,
    captured operation providers, stored feature selections and retained voice ids.
- Verification performed by reviewer:
  - Inspected every owned source/test diff and new file, surrounding adapter/composition
    code, accepted dependency handoffs and the Settings reference. Ran `git diff --check`,
    which passed. Findings above follow directly from the relevant state transitions;
    no new inference or live-store experiment was needed.
  - Reused `.build/local-setup-final-focused.log`, confirming 20 Core tests in four suites
    and 84 App tests in 11 suites passed. All six changed/new test files predate that log.
    The supplied release log records a successful app build. Every source hash in
    `.build/local-productionization/stream3-candidate.json` matches the current tree,
    and its executable SHA-256 matches the production candidate. Independently ran
    `codesign --verify --deep --strict` on that candidate, which passed.
- Acceptance limits: light/dark native inspection evidence is supplied from the
  implementation transcript and uses controller-disabled inspection copies. It does
  not establish actual signed production hotkey, Test, MCP, offline inference or
  combined-memory behavior. Those checks remain stream 4's functional gate. Aidan's
  native UI judgment remains pending. No builds, downloads, Keychain writes or changes
  to the user's model installation were performed during review.

## Resolution

- S3-R1 corrected in `LocalSetup.swift`. Selection records features actually switched away
  from Local while their setup is active. Setup clears its admission state, then releases only
  those unused features and signals readiness. An active operation keeps the runtime until
  its lease ends. Reselecting Local clears the deferred release. Explicit setup before provider
  selection still retains Ready; an unconditional release at setup completion would break it.
- `LocalLifecycleTests.selectionDuringSetup` suspends the loader and checks deselection
  both without an operation and with an operation already using the shared load. Setup
  completion releases the unused runtime, preserves installed files and reports Waiting.
  The active lease delays release until it ends. The existing `featureIsolation` test retains
  the explicit preselection Ready check and installed-only reload check.
- S3-R2 corrected at the shared `ProviderControls` call site in `SettingsView.swift` with
  `.id(provider.id)`. Each provider gets fresh credential view state and a fresh loading task.
  No credential implementation or storage changes were needed.
- Saved-key verification used temporary `.build/local-productionization/credential-fixture-source`
  and signed `CredentialInspectionLight.app` / `CredentialInspectionDark.app`. All production
  Sources matched except the copied `Keychain.swift`, which returns a synthetic xAI fixture
  and denies every write without calling system Keychain APIs. The original provider-controls
  source and `.id` correction were unchanged. Native Apple-to-xAI navigation in both themes
  showed the masked saved key and Replace/Remove, and a repeated dark round trip returned
  the same controls. Show key, Replace, Remove and Save were never clicked. No real credential
  metadata, secrets, settings or provider selections were read or changed for this check.
  `.build/local-productionization/stream3-credential-fixture.json` records source and executable
  identity separately from the production candidate. Screenshot evidence is in the CUA transcript.
  Both fixture inspection processes exited. This verifies view identity with controlled saved-key
  input; real Keychain permissions and writes remain outside this remediation check.
- Simplification/deletion pass: kept the fixes to deferred feature release and one keyed view.
  No production credential fixture, demo route or test dependency was added. S3-O1 remains
  optional and outside this pass. `SpeechStream.waitForClose` and the accepted synthesis
  pipeline remain unchanged, as do the unrelated dirty paths and Parakeet timing edits.
- Focused verification: the packet's combined Core/App command passed 21 Core tests in four
  suites and 84 App tests in 11 suites. Log `.build/local-setup-remediation-focused.log`.
- Final artifact verification: `scripts/build-app.sh release
  .build/local-productionization/EchoType.app` passed, log `.build/local-setup-remediation-release.log`.
  The production candidate and all four inspection copies passed `codesign --verify --deep --strict`.
  `stream3-candidate.json` matches the current production source hashes and executable hash;
  the executable is newer than every recorded source. Production-only light/dark copies were
  refreshed from that candidate and re-signed, including their changed executable identity.
  Read-only native checks showed the Apple credentialless page and Local Installed cards plus
  9.48 GB storage in both themes, with screenshots in the CUA transcript. No preparation,
  download, deletion, provider selection or credential action ran. All owned inspection processes
  exited. `git diff --check` passed. Closure review and Aidan's UI acceptance remain pending.

## Closure review

- Reviewer and configuration: fresh independent closure subagent, inherited model and
  effort, Codex harness. Reviewed HEAD and base
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` plus the current owned implementation.
  Applied code-review, its coding practices and unslop. Read the packet, specification,
  Settings study, Parakeet evidence, accepted stream 1/2 handoffs and plan conventions.
  This closure checks the two accepted corrections and their consequences within the
  original scope. S3-O1 remains optional and outside remediation.
- Verdict: pass for focused closure on 2026-10-09. S3-R1 and S3-R2 are closed.
  Neither correction introduces a new blocking defect in the reviewed scope.
- Remaining required findings: none. New optional observations and questions: none.
- Dispositions verified:
  - S3-R1. `LocalLifecycle.select` records only features selected away during active
    setup. Setup's defer clears its admission state and releases those features under
    the lifecycle lock when unselected and without operation leases. A retained lease
    delays release until teardown ends; selecting Local again clears the pending
    release. The existing cancellation/generation checks and removal admission remain
    intact. Release drops loaded references and signals observers, so installed files
    remain installed while readiness returns Waiting rather than stale Ready.
    `selectionDuringSetup` exercises the suspended-loader transition with and without
    a lease. `featureIsolation` still checks explicit preselection setup ends Ready and
    that installed-only reloading fetches no additional files.
  - S3-R2. `.id(provider.id)` gives `ProviderControls` separate SwiftUI state and task
    identity for Apple and xAI. Navigation resets saved-key, loading and editing state;
    the existing task reads the selected provider's key and rejects cancelled results.
    No production credential-storage behavior changed.
- Verification performed by closure reviewer:
  - Inspected the corrected lifecycle, regression scenarios, readiness/release
    implementation, selection binding, operation lease teardown, Settings call site
    and credential task. Ran `git diff --check`, which passed.
  - All 94 source/package hashes in `stream3-candidate.json` match the current tree.
    The production executable matches SHA-256
    `f076a3517b8dff6c5abc7c0bc65b6d025a1408941e251148a49b5c5dbcf8a5b3`.
    Strict deep signature verification passed on the production candidate.
  - Compared the saved-key fixture's complete Sources with production. Only copied
    `Keychain.swift` differs; its recorded hash matches, its read returns a synthetic
    xAI key, and save/remove return false without system Keychain calls. The provider
    controls and identity correction match production. Both credential inspection
    runtime executable hashes match `stream3-credential-fixture.json`, and both bundles
    pass strict deep signature verification.
- Supplied verification reviewed and reused:
  - `.build/local-setup-remediation-focused.log` records 21 Core tests in four suites
    and 84 App tests in 11 suites passing, including deferred release and preselection
    Ready. All six scoped test files and both corrected production files predate the
    successful log. `.build/local-setup-remediation-release.log` records the successful
    release app build. No builds or inference were repeated for closure.
  - The resolution and fixture inventory record native Apple-to-xAI saved-key navigation
    with Replace/Remove controls in both themes and a repeated dark round trip. These
    are supplied UI observations from the implementation transcript, not a new closure
    inspection. The fixture is separate from the production candidate and its source
    comparison supports the claimed credential isolation.
- Acceptance boundary: Aidan's native Settings judgment remains pending and is required
  before stream 3 acceptance. Actual signed production-app hotkeys, Test, MCP, offline
  inference, setup/removal transitions and combined-memory evidence remain stream 4's
  functional gate. Controller-disabled inspection and controlled tests do not satisfy
  those gates. No downloads, model-store operations, real settings or Keychain writes,
  commits or source changes were made during closure. Only this review section changed.

## External validation

- Gate / placement: Aidan judges native Settings after closure and before acceptance.
- Status: Awaiting explicit acceptance, blocked through plan escalation `S3-UI-01`.
- Candidate: signed `.build/local-productionization/EchoType.app`, base revision
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` plus reviewed uncommitted implementation
  and preserved trial sources. Executable SHA-256
  `c30a9cfdeb9b9e5f3cd5a408b63e2e51c8f857a3039b9dfe8e48b606308efe68`.
  `stream3-candidate.json` and `stream3-feedback-verification.json` record the final
  94-source inventory, signatures, test/log identity and equivalent signed inspection copies.
- Instructions: inspect the direct native Settings copy's permanent sidebar, consistent
  grouped feature/provider/app pages, page-button consent, readable source/licence links,
  Manage files and Keyterms boundary/focus in both themes. Do not perform real setup or
  confirm removal for layout judgment. Safe launch/reopen commands are in S3-UI-01.
- Required evidence: candidate provenance, agent UI checks and explicit Aidan acceptance
  or concrete feedback. Previous UI feedback is implemented, independently reviewed
  and closed; Continue did not supply acceptance.
- Agent evidence: both themes passed native direct Settings launch, grouped pages,
  licences/storage and Keyterms focus, with normal Command-W closure and reopening.
  No real setup or removal ran. Store-only review fixes have fresh controlled tests,
  release packaging and artifact verification; layout code is unchanged from inspection.
  Final corrected Light inspection is intentionally open for Aidan, PID 18183, native
  `EchoType Settings` window. Its ownership is transferred to Aidan, so later agents
  must preserve it. See Final inspection launch below for exact process provenance.
- Resume condition: explicit UI acceptance. Further meaningful corrections require
  focused review under the lead guide. No stream 3 commit is made before this gate passes.
- Design drift: back/forward history and a scroll-revealed page title were omitted.
  These were requested only where supported simply; native grouped forms and the
  permanent sidebar avoid custom navigation/toolbar effects. Record the omission for
  Aidan's UI judgment. Stream 4 functional and public-release gates remain unchanged.

## 2026-10-10 feedback correction handoff

- Base and recovery: HEAD remains `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`.
  The reviewed uncommitted stream 3 implementation was adopted. Earlier packet review records
  remain unchanged. App inspection startup was recovered from the interrupted edit. Its
  conditional `SceneBuilder` failed compilation, so scenes now use native launch behavior
  and menu-bar insertion rather than conditional scene construction.
- Scope: corrected `App.swift`, `SettingsStore.swift`, `Views/SettingsView.swift`,
  `Views/LocalSettingsPane.swift`, `LocalSetup.swift`, `ModelStore.swift`,
  `LocalLifecycleTests.swift`, `ModelStoreTests.swift` and new App
  `LocalInstallationTests.swift`. The lead also approved the small `LocalModel.swift`
  synchronous preparation-admission seam needed to close its cancellation race.
  README, main dispatch, SettingsDemo, Parakeet timing, earlier lifecycle integration,
  consolidated notes and spike deletions were preserved. All work remains uncommitted.
- UI and explicit consent: inspected all three supplied Raycast images. The established
  sidebar uses a native permanent `HSplitView` and sidebar List, removing the collapse toggle
  and split-navigation opening transition. Every page uses a grouped native Form with system
  body controls and a compact page title. Dictation and Read Aloud use matching provider and
  feature sections; vocabulary retains its editor boundary and focus outline. Permissions
  use labelled rows and System Settings actions. About contains installed version, update
  instructions, releases, source and issue links. No search was added. Scrolling title effects
  and navigation history were omitted to keep this Settings shell simple.
- Each Local card and selected Local feature page shows manifest names, purposes, sizes,
  installed/retained status, missing download total, available disk space, temporary storage,
  offline behavior and source/licence links before its action. Download directly installs and
  prepares that feature; installed models offer Prepare / Retry. The duplicate consent sheet
  was removed. Sources and licences remain readable bottom text and links, including access
  to bundled eSpeak notices. This does not claim public-release legal compliance. The recorded
  Parakeet provenance and combined-program GPL/source release hold remains unchanged.
- Concurrency contracts: LocalInstallation owns separate task/generation/message state per
  feature and does not disable the other feature's action. LocalLifecycle admits disjoint
  feature setups and their store tasks under its existing lock. A cancelled feature loses
  its generation; manifests still owned by another valid setup keep downloading. When both
  owners cancel, cancelled generations do not retain the asset. ModelStore still owns one
  task per manifest, now including installed checksum verification and corrupt-install
  recovery, so overlapping callers cannot move the same damaged directory independently.
  Synchronous LocalModel preparation admission occurs under the lifecycle lock, preventing
  cancellation from admitting a later loader. Existing installed-only operation preparation,
  leases, deferred release and removal admission remain intact.
- Focused verification: `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE
  swift test --filter 'ModelStoreTests|LocalModelTests|LocalLifecycleTests|KokoroSpeechTests|EchoTypeAppTests'`
  passed 24 Core tests in four suites and 85 App tests in twelve suites. Final log is
  `.build/local-feedback-focused.log`. Controlled tests cover overlapping shared assets with
  Dictation cancellation and retained Read Aloud completion, independent Read Aloud completion
  during a suspended Dictation download, shared corrupt-install recovery with intact reuse,
  and independent App page task/cancellation state. Existing controlled preparation,
  cancellation/publication, lease/removal and external-cache preservation checks also pass.
  One release command was briefly queued behind SwiftPM's build lock before the final test
  rerun ended; that waiting command was stopped. Compilations did not run concurrently and
  release packaging was restarted after the successful test process exited.

- Recovered release and artifact verification, 2026-10-10. Reused the successful
  `.build/local-feedback-release.log`, which records a 108.33-second release build and
  app signing after the final focused run. The signed production candidate is
  `.build/local-productionization/EchoType.app`, executable SHA-256
  `43e406db6ed829e8c936eb2b59adc81ec754cef0af9d44b52c6d7464ab1bdb49`.
  All 94 hashes in `stream3-candidate.json` match the current source/package tree,
  and its executable timestamp follows the latest recorded source. `git diff --check`
  passes. No build or inference was repeated during recovery.
- The refreshed inspection copies launch the production Settings directly through its
  native inspection Window. Their unique bundle ids plus signed Info.plist inspection
  boolean disable the controller, hotkeys, microphone and GUI MCP observer; their Light
  or Dark inspection theme is separate from the user's appearance preference. There is
  no executable wrapper or HUD argument. Strict deep signature verification passes on
  production and both copies. The light executable SHA-256 is
  `5a399d971a67d015fe375ebaf2df29030d30d12bfe1017e46ce62942b6ac516d`;
  dark is `95cd1d7e34b4678693a70293ef3b2874e8f8fa2c40b9a8f7822446e5aef2fcc9`.
  Recovery copied each executable to owned `.build` scratch files and removed only
  those scratch signatures. All three resulting code hashes match
  `aab843ffcba0e82cc36925a1d11468a06a86f10a2c22a26f2387e6db330b490e`.
  All resource file hashes match production. Full provenance and log hashes are in
  `.build/local-productionization/stream3-feedback-verification.json`; scratch code
  comparisons are under `feedback-inspection-provenance` beside it.
- Native inspection recovery adopted the already running dark copy's exact PID 11119,
  started at 07:45:24 Europe/London. Dark screenshots and accessibility observations
  checked Dictation, Read Aloud, xAI, Apple, Local, General, Keyterms, Agents and About.
  Feature pages use matching grouped native rows. Apple and General show readable
  permission status/actions. Keyterms has a visible unfocused boundary and accent focus
  outline. Local shows installed Dictation, missing Read Aloud, manifest requirements,
  separate enabled Prepare / Retry and Download actions, actual 2.99 GB storage and
  readable bottom source/licence links. Manage files opened and closed with its actual
  five-row inventory; no removal action was invoked. xAI's credential read remained
  pending during its layout check, so this recovery does not claim a saved-key check.
  Supplied light checks from the preceding implementation transcript cover the same
  pages, editor, notices, storage and normal close/reopen behavior.
- Cmd-W closed the dark Settings window normally. Selecting the exact bundle through
  CUA `getApp` reopened Settings directly, with no HUD pill or menu-bar dependency.
  CUA screenshots remain in the tool transcript; there is no supported file-export API.
  Recovery then verified PID 11119 still had the exact inspection executable command
  and terminated only that PID. User `/Applications/EchoType.app --mcp` processes 6205
  and 90751 were preserved. The previously reported absent PID 76788 was not recovered,
  and this recovery makes no claim about why it exited.
- No real download, preparation, deletion, provider choice, settings edit, permission
  grant or Keychain write was performed. This is native layout and signed-copy
  provenance evidence, not stream 4 functional validation or Aidan's UI acceptance.
  The independent review has since requested bounded lifecycle/store corrections.
  These candidate hashes describe the checked pre-correction build and must be refreshed
  after those corrections. UI acceptance and the public-release hold remain pending.


## 2026-10-10 feedback independent review

- Reviewer: fresh independent review subagent, inherited model and effort, Codex harness.
  Base and HEAD are `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`.
  Reviewed the complete current owned changes in App.swift, SettingsStore.swift,
  SettingsView.swift, LocalSettingsPane.swift, LocalSetup.swift, LocalModel.swift,
  ModelStore.swift and their focused tests, including untracked files. Earlier lifecycle
  integration, provider contracts and candidate changes were read-only context.
  Applied the supplied code-review and unslop skills and coding practices. Read this
  packet, the productionization specification, Settings study, Parakeet evidence,
  accepted stream 1/2 handoffs and plan conventions.
- Required S3-FR1: retain intact files when recovering an incomplete installed set.
  `ModelStore.swift:107-128` enters recovery only when `stateOnDisk` reports that every
  expected file has its expected size. If one installed file is truncated or missing,
  recovery skips that directory. Download reads only `Incomplete`, fetches the intact
  files again, then deletes the old installation during publication. This violates
  the specification's requirement that retry reuse verified files and fetch only missing
  or invalid files. It also overstates missing download bytes and can require another
  full model allocation. Recover extant installed files regardless of whole-set
  completeness, verify them, and reuse the intact files. The current tests cover
  same-size checksum corruption, which passes this size gate, rather than this case.
- Required S3-FR2: admit a fresh shared-asset generation after a cancelled writer drains.
  `ModelStore.swift:75` returns any registered task, including the cancelled task kept
  registered at lines 146-150. `LocalSetup.swift:214-226` admits disjoint feature setup.
  Cancel Dictation while its shared-manifest fetch is suspended with no other owner,
  then start Read Aloud before that writer finishes. Read Aloud joins the cancelled task
  and fails with `CancellationError`, despite its independent valid setup request.
  The specification requires safe reuse of overlapping assets and independent feature
  cancellation. Drain the cancelled writer before starting or joining a fresh generation
  for the new owner, preserving the single-writer rule. The current overlap test admits
  Read Aloud before cancellation and does not cover this ordering. Today's chosen
  production stacks are disjoint, but the explicit shared-assets contract still applies.
- Optional: none. Question: none. The lead accepted both Required findings and assigned
  one bounded correction pass followed by fresh focused closure.
- No additional blocking finding in the native Settings corrections or synchronous
  preparation admission. Source inspection supports the direct declarative inspection
  Window, production launch suppression, consistent grouped forms, page-button consent,
  independent feature actions and readable source/licence links. Aidan's native UI
  acceptance remains pending; this review does not replace it.
- Verification: reused `.build/local-feedback-focused.log`, with 24 Core tests in four
  suites and 85 App tests in twelve suites, and the successful release build recorded
  in `.build/local-feedback-release.log`. Independently matched all 94 source hashes
  in `stream3-candidate.json` and ran `git diff --check`, which passed. Signature and
  native UI results are supplied by the artifact-verification handoff above. The two
  findings follow concrete code paths; no new executable reproduction was run.
- Limitations and safety: no rebuild, inference, download, settings or Keychain mutation,
  user-process action or source edit. This section is the only review edit. The supplied
  candidate and test results describe the pre-correction tree and must be refreshed
  after remediation. Public-release obligations remain unchanged.

## 2026-10-10 feedback resolution

- Resolved accepted S3-FR1 and S3-FR2 in one bounded correction pass. Base and HEAD
  remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on
  `feat/local-models-productionization`. Changes remain uncommitted; fresh focused
  closure and Aidan's native Settings judgment remain pending.
- Changed `ModelStore.swift`, `ModelStoreTests.swift` and `LocalLifecycleTests.swift`.
  No `LocalSetup.swift` seam or app/layout change was needed. Preserved adopted
  stream 3 work, unrelated trials, model choices and frozen provider contracts.
- S3-FR1: recovery now considers any extant installed directory, including a set
  with missing or truncated files. It moves known files into retained storage and
  verifies each before reuse, fetching only missing or invalid files. An existing
  verified retained copy wins over an invalid installed copy. Cheap requirement
  reporting counts intact-sized files in either location without treating the
  incomplete set as installed. Controlled two-file cases remove or truncate one
  installed file after relaunch, verify the repaired set and assert that the other
  file was fetched only once, during the original installation.
- S3-FR2: a new valid owner joins an active task or registers a fresh generation
  behind a cancelled task. That replacement waits for the old writer to drain
  before recovery or fetching. Task identity protects registered-task cleanup;
  generation checks reject the old writer's progress and publication. Cancelling
  the waiting replacement prevents its recovery, fetch and preparation. The task
  remains registered during the drain, so removal stays blocked. This keeps the
  existing feature-specific lifecycle cancellation policy and one writer per model.
- The new shared-asset regression suspends the sole Dictation fetch with a checked
  continuation that ignores cancellation, cancels Dictation, then admits Read Aloud
  before draining that writer. It proves removal protection, at most one shared
  writer, no cancelled Dictation loading, a fresh Read Aloud fetch and successful
  preparation. Its second case cancels both features before drain and verifies no
  replacement fetch, shared-model publication or late Ready result.
- Verification: the sequential combined command
  `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test --filter 'ModelStoreTests|LocalModelTests|LocalLifecycleTests|KokoroSpeechTests|EchoTypeAppTests'`
  passed 26 Core tests in four suites and 85 App tests in twelve suites. Final log
  `.build/local-feedback-focused.log` supersedes the pre-correction result. The
  first run exposed a test-fixture inventory race with the independently publishing
  speech directory; the removal assertion now uses its known temporary retained
  path, and the fresh combined run passes.
- `scripts/build-app.sh release .build/local-productionization/EchoType.app` passed;
  log `.build/local-feedback-release.log`. Strict deep signature verification passed
  on the production candidate and refreshed Light/Dark inspection copies.
  `git diff --check` passed. The candidate inventory refresh covers all 94 source
  hashes and current mtimes; verification records the changed test hashes and log
  hashes in `.build/local-productionization/stream3-feedback-verification.json`.
- Refreshed direct native Settings copies retain their signed unique ids and inspection
  Info.plist flags, with no wrapper or HUD arguments. Production executable SHA-256
  is `c30a9cfdeb9b9e5f3cd5a408b63e2e51c8f857a3039b9dfe8e48b606308efe68`;
  Light is `2760e5bb907965ad600cfb6cfe0f122ca08ce339ea517e5893c53a1a322d9116`;
  Dark is `0a6e15d0b813e187c45cc0a9e12d635982e8c05e68056f5995133a4666fdcde7`.
  Removing signatures only from owned scratch executable copies gives the same
  code hash for all three,
  `6728ad259882500ab5b98a1c3e7de6f7ff53e5f1deabdd0021f2f3f9113d70be`.
  All resource file hashes match production. Scratch comparisons remain under
  `.build/local-productionization/feedback-inspection-provenance`.
- The refreshed copies were prepared but not launched. Previous native light/dark
  layout evidence remains applicable because only store and test sources changed;
  its provenance is retained separately from these new artifact hashes. This does
  not establish Aidan's UI acceptance or stream 4 functional validation.
- No live model download, preparation, removal, Keychain/settings write or user-process
  action was performed. Tests used controlled sources and temporary stores. No
  specification drift or new generic machinery was introduced. Public-release
  obligations remain unchanged.

## 2026-10-10 feedback closure review

- Reviewer: fresh independent closure subagent, inherited model and effort, Codex
  harness. Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`.
  Applied code-review, coding practices and unslop. Read the packet, specification,
  required context, accepted stream 1/2 contracts and plan conventions. Reviewed
  the accepted S3-FR1/S3-FR2 corrections and their consequences in the current
  uncommitted implementation. This is focused closure, not another full review.
- Verdict: pass. S3-FR1 and S3-FR2 are closed. Remaining required findings: none.
  New blocking defects, optional observations and questions: none.
- S3-FR1: `recoverInstalled` considers any extant installation, so missing or
  truncated siblings no longer discard intact files. Recovery preserves a verified
  retained copy when both locations contain a file; the download loop verifies
  recovered files before reuse and fetches only missing or invalid files. Reporting
  includes complete-sized installed siblings without marking the whole set installed.
  The missing/truncated regression verifies the repaired set and exact per-file
  fetch counts. Existing same-size corruption and shared recovery checks also pass.
- S3-FR2: `start` joins a valid writer or registers a replacement that awaits its
  cancelled predecessor before touching files. Further replacements drain that
  chain. Task-generation identity prevents an old completion from removing the new
  registration; generation checks prevent stale progress or publication. Cancelling
  a queued replacement stops it before recovery or fetching. Removal stays protected
  while the registered task drains, and the unchanged lifecycle rejects cancelled
  feature completion while allowing the new owner to prepare successfully.
  The controlled regression covers both successful new ownership and cancellation
  of both owners, with at most one shared writer and no cancelled late Ready result.
- Supplied verification reused: `.build/local-feedback-focused.log` records 26 Core
  tests in four suites and 85 App tests in twelve suites passing, including both new
  regressions. `.build/local-feedback-release.log` records the successful 109.18-second
  release build and signing. The corrected production file and both regression files
  predate the successful focused log. No tests, builds or inference were repeated.
- Independently verified all 94 source/package hashes in `stream3-candidate.json`,
  both remediation test hashes and both log hashes in `stream3-feedback-verification.json`.
  Production executable SHA-256 is
  `c30a9cfdeb9b9e5f3cd5a408b63e2e51c8f857a3039b9dfe8e48b606308efe68`.
  Production and both inspection executables match their recorded hashes and are
  newer than all inventoried sources. Inspection Info.plist identities/flags match;
  all 22 resource file hashes match production. Existing unsigned-code scratch files
  share hash `6728ad259882500ab5b98a1c3e7de6f7ff53e5f1deabdd0021f2f3f9113d70be`.
  Strict deep signature checks passed on all three bundles. `git diff --check` passed.
- Acceptance boundary: refreshed inspection copies were not launched during closure.
  Earlier native layout observations are supplied evidence; Aidan's UI acceptance
  and stream 4 signed-app functional validation remain pending. Public-release
  obligations remain unchanged. No source, plan, settings, Keychain, model-store or
  user-process action was taken. Only this assigned review section was written.

## Final inspection launch

- On 2026-10-10 after focused closure passed FR1 and FR2, the refreshed production
  candidate executable SHA-256 is
  `c30a9cfdeb9b9e5f3cd5a408b63e2e51c8f857a3039b9dfe8e48b606308efe68`.
  Before launch, process inspection found no running Settings inspection copy.
  User `/Applications/EchoType.app --mcp` processes 6205 and 90751 were preserved.
- Opened only `.build/local-productionization/SettingsInspectionLight.app` through
  CUA's exact-path `getApp`. Its strict deep signature passed, its inspection boolean
  is true, and its unique bundle id is
  `com.aidanzealley.echotype.stream3-inspection-light`. The actual process is PID 18183,
  started at 07:58:49 Europe/London, running its exact `Contents/MacOS/EchoTypeApp`
  executable without HUD arguments. Accessibility and screenshot inspection show the
  native window titled `EchoType Settings`, id `settings-inspection`, on Dictation.
  There is no HUD demo or menu-bar dependency.
- PID 18183 and this window are intentionally left open for Aidan. Inspection ownership
  transfers to Aidan at this handoff; do not include it in automated cleanup. A safe reopening command is
  `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/SettingsInspectionLight.app`.
  Aidan can close the window with Cmd-W. No model, settings, provider, permission or
  Keychain action was taken. Native UI acceptance remains pending.

## 2026-10-10 native window correction handoff

- Base remains `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on
  `feat/local-models-productionization`. This correction changes only the root composition
  in `App.swift` and `Views/SettingsView.swift`, plus the new 35-line
  `Views/SettingsSplitView.swift`. Approved page Forms, controls, typography and text,
  lifecycle/store corrections and unrelated dirty trial files are preserved. Changes remain
  uncommitted. Plan ownership stays with the lead. Independent review and Aidan's full-window
  judgment remain pending; consistent pages did not establish acceptance of the whole window.
- Diagnosis came from the supplied latest screenshot and the original running Light copy,
  PID 18183. Its 900-point window hosted a root fixed to 790 points, centering it with a
  55-point leading gutter. The opposite gutter merged visually into the white detail.
  The original AX tree identified the purple titlebar control as system `Window sharing`,
  not an application sidebar toggle. The correction preserves that macOS recording/sharing
  indicator. Source-level claims about native controls alone missed the fixed-root/window
  mismatch and the surrounding opaque Form background.
- Native integration choice: a small `NSViewControllerRepresentable` hosts the existing
  SwiftUI sidebar and detail in an `NSSplitViewController`. The sidebar item uses
  `NSSplitViewItem(sidebarWithViewController:)` with `canCollapse = false`. AppKit supplies
  sidebar material and safe-area handling; no navigation toggle, private toolbar-item lookup,
  toolbar removal, custom titlebar drawing or compensating gutter padding is involved.
  The split fills its resizable scene. Minimum content dimensions replace the fixed frame,
  and both production Settings and inspection scenes declare their initial size separately.
  Sidebar thickness retains the established 170-point starting width, with native sizing
  limits; detail has its own minimum thickness. System `regularMaterial` backs the detail,
  and the root hides only the outer scroll backgrounds so approved grouped rows remain.
  Native materials respond to system appearance/accessibility settings without hand-picked
  light/dark colours or a second sidebar effect layer.
- Primary API context: target is macOS 26; inspection ran on macOS 27.2, `26B5091g`.
  Apple's [NSSplitViewItem documentation](https://developer.apple.com/documentation/appkit/nssplitviewitem)
  documents sidebar items and collapse policy. Apple's
  [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310/)
  describes automatic sidebar materials from NSSplitViewController, native safe-area handling
  and avoiding a legacy visual-effect layer over the sidebar. The native content controllers
  retain safe-area layout while the SwiftUI scene lets the split occupy the whole root.
- Fresh affected verification: `scripts/build-app.sh release
  .build/local-productionization/EchoType.app` passed in 21.91 seconds and signed successfully.
  Log `.build/native-settings-release.log`. Strict deep signature verification passed for
  the candidate and both new inspection copies. All 95 recorded source/package hashes match
  the current tree, including the new helper; the executable postdates all recorded sources.
  After removing signatures from temporary executable copies, all three code hashes match;
  their resource inventories match byte for byte. `git diff --check` passed.
  Previous 26 Core and 85 App results from `.build/local-feedback-focused.log` are reused
  because this correction changes no store, lifecycle, provider or operation behavior.
  No model inference or competing Swift build ran.
- Refreshed artifacts: `.build/local-productionization/stream3-candidate.json` describes
  the current production candidate, executable SHA-256
  `da8c78d971733c2996a1475f3baa54dbc36d982e1124f462c96e1b9f6e51b528`.
  `.build/local-productionization/stream3-native-window-verification.json` records strict
  signatures, source/log identity, normalized executable hashes and resource equality.
  The previous feedback verification file is historical evidence, not this candidate's
  artifact inventory. New safe copies use the exact production code/resources and existing
  controller-disabled inspection entry point, with distinct ids and theme metadata only:
  `NativeSettingsInspectionLight.app`, id
  `com.aidanzealley.echotype.stream3-inspection-native-light`, executable SHA-256
  `8dcc2ba99674c674b41fce05335364e8fdc8324d3e47a8f909abc2096c9d579c`;
  `NativeSettingsInspectionDark.app`, id
  `com.aidanzealley.echotype.stream3-inspection-native-dark`, executable SHA-256
  `73706f42a17feaec3945a062a7b833828eacf570aefe1e70609ac50de7266631`.
  Their paths are alongside the candidate. No original running copy was overwritten.
- Rendered CUA verification: both new 790-point windows place the sidebar at x=0,
  eliminating the white leading strip, and show native traffic lights above it before
  capture replaces them with the system sharing indicator. The titlebar remains native;
  page titles sit below it without the previous misplaced gutter. Light detail is a system
  material rather than solid white; dark uses the corresponding native dark treatment.
  Native Zoom expanded each window to 1512-point width without moving or collapsing the
  sidebar, then restored its original size. Command-W and reopening the same app path
  retained the native split in both themes. Dark was also quit and freshly relaunched.
  Read Aloud navigation, Local cards and dark Keyterms boundary/focus survived the new
  hosting hierarchy. The Local page still scrolls normally. Screenshots and AX observations
  are in this implementation agent's CUA transcript; no image-export API is available.
- Process ownership: original user-owned Light PID 18183 and `/Applications/EchoType.app`
  MCP PIDs 6205, 21165 and 90751 were preserved. New Light PID 23302 remains open.
  The first owned Dark process quit normally; its PID was not sampled. A fresh Dark
  relaunch is PID 24222. CUA reported that the user changed that app during the attempted
  final quit, so further actions stopped and this process was preserved. Both new inspection
  processes and their windows are handed to the lead/user for review. No blanket termination
  occurred. Reopen a new copy with its exact app path using normal app launch.
- Limits: no setup, prepare, download, deletion, Keychain edit, provider choice, text edit
  or live settings write was performed. Local's existing long model name can meet its
  installed-size text at the established narrow width; this correction preserves the
  approved page content as requested. OS Reduce Transparency/Increase Contrast were not
  toggled; system material behavior is retained but not separately tested. Controller-disabled
  inspection does not establish signed production hotkeys, microphone, MCP, inference or
  setup/removal behavior. Those remain stream 4 checks. Aidan's explicit UI acceptance
  remains required. No implementation remediation pass was needed before this handoff.
- Safe review launch command for this correction:
  `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/NativeSettingsInspectionLight.app`.
  The dark equivalent is
  `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/NativeSettingsInspectionDark.app`.
  These exact copies are currently open as PIDs 23302 and 24222. The production candidate
  remains `.build/local-productionization/EchoType.app`; use the isolated copies for layout
  review so the user's live controller/MCP app remains untouched.


## 2026-10-10 native window independent review

- Reviewer: independent review subagent, inherited model and effort, Codex harness.
  Applied the code-review skill, coding practices and unslop. Read the specification,
  packet and latest native correction handoff, Settings layout study, Parakeet context,
  accepted stream 1/2 handoffs and plan conventions and feedback. Base and HEAD remain
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`.
- Scope: the complete owned native correction, including adopted root-container work:
  both Settings scene default sizes in `App.swift`, `SettingsView.swift` root split,
  background, sizing and safe-area composition, and all of `SettingsSplitView.swift`.
  Previously reviewed page, store, lifecycle, inspection startup and unrelated trial
  changes were read as context rather than reopened as this correction's scope.
- Verdict: no blocking findings. Required findings: none. Optional findings: none.
  Questions: none. The bridge is a proportionate use of native AppKit for a permanent
  sidebar and native material/safe-area ownership. It introduces no custom navigation,
  toolbar lookup, titlebar drawing or compensating gutter padding. `canCollapse = false`
  makes the sidebar permanent. The minimum root frame fills a larger window, and matching
  initial scene sizes replace the old fixed-root/window mismatch. Updating both hosting
  roots keeps the existing destination binding, provider identity and page composition.
  No setup, credential, store or operation contract changes appear in this correction.
- Independent rendered inspection: used read-only CUA on exact
  `NativeSettingsInspectionLight.app` and `NativeSettingsInspectionDark.app` paths.
  Inspected actual screenshots and accessibility trees in both themes. Light was on
  Read Aloud and Dark on the user's already scrolled Local page. Both screenshots show
  the sidebar at the left edge with no leading white strip, native window titlebar and
  system sharing indicator, and appearance-appropriate detail material. Light grouped
  controls remain readable; Dark Local retains its grouped rows and native scrolling.
  No navigation, resize, close, focus, text, settings or model action was performed.
  The handoff's resize/restore, close/reopen, fresh launch and Keyterms-focus results
  are supplied implementation evidence, not interactions repeated by this reviewer.
- Independent artifact checks: all 95 source/package hashes in `stream3-candidate.json`
  match the current tree. Executable hashes for the production candidate and both exact
  new inspection copies match `stream3-native-window-verification.json`. Independently
  ran strict deep signature verification for all three bundles; all passed.
  `.build/native-settings-release.log` records successful release packaging and its hash
  matches the verification record. The reused focused-results log hash also matches.
  `git diff --check` passed before this appended review. Normalized code/resource equality
  is supplied verification evidence. No build, tests, inference, cache or Keychain action
  ran during review; source changes are confined to this appended section.
- Acceptance limits: current rendered screenshots independently establish the correction's
  Light/Dark layout, not every page or system accessibility preference. The preserved
  approved pages and earlier focused 26 Core / 85 App results remain supporting evidence.
  Controller-disabled copies do not establish production hotkeys, microphone, MCP,
  offline inference or actual setup/removal behavior; those remain stream 4's gate.
  PIDs 18183, 23302 and 24222 and user app processes were preserved. Aidan's explicit
  full-window UI judgment remains pending; this review does not grant UI acceptance.

## 2026-10-10 native window focused closure

- Reviewer: fresh focused closure subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet and
  required context, accepted stream 1/2 handoffs, plan conventions and latest window
  feedback. Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`.
- Scope: both Settings scene default sizes in `App.swift`, the Settings root split,
  sizing, material and safe-area composition in `SettingsView.swift`, and all of
  `SettingsSplitView.swift`. This closes the native correction and accepted review
  disposition without reopening the earlier page or lifecycle reviews.
- Verdict: pass. The independent review recorded no Required, Optional or Question
  findings, and the lead accepted that disposition without remediation. No outstanding
  required finding or new blocking defect remains in this correction. Optional
  observations and questions: none.
- The fixed 790-point root has become a minimum-size root, with matching 790 by 590
  initial scene sizes. The native split can fill a larger window without centering
  a fixed-width child. `NSSplitViewItem(sidebarWithViewController:)` owns the sidebar
  treatment and `canCollapse = false` keeps it visible. The detail uses system
  `regularMaterial` and hides outer scroll backgrounds while retaining the approved
  grouped pages. Updating both hosting roots preserves destination binding and
  provider-specific identity. This small bridge adds no custom chrome or toolbar
  removal and changes no setup, credential, provider, store or operation contract.
- Independently checked all 95 current source/package hashes against
  `.build/local-productionization/stream3-candidate.json`; all match. Production
  executable SHA-256 is
  `da8c78d971733c2996a1475f3baa54dbc36d982e1124f462c96e1b9f6e51b528`.
  Production and both exact `NativeSettingsInspectionLight.app` and
  `NativeSettingsInspectionDark.app` executables match the current native verification
  record and postdate all inventoried sources. Bundle identities and inspection/theme
  flags match; strict deep signature verification passed on all three bundles.
  All 22 resource files match production. The existing unsigned-code scratch files
  match the recorded common hash
  `3775e8f21322db3e5d9552f0576909df5b1e8a8951bc277bb8b4cfeb2e084569`.
- Reused the affected successful build in `.build/native-settings-release.log`, which
  records completion in 21.91 seconds and signing. Its hash matches
  `stream3-native-window-verification.json`. The reused `.build/local-feedback-focused.log`
  hash also matches and records 26 Core tests in four suites and 85 App tests in
  twelve suites passing. The correction changes only native container composition,
  so these unchanged behavior checks remain applicable. `git diff --check` passed.
  No build, tests or inference were repeated.
- Rendered evidence remains correctly attributed. The independent review inspected
  actual Light/Dark screenshots and accessibility trees read-only, establishing
  leading x=0, native titlebar and appearance-appropriate material. Resize/restore,
  close/reopen, fresh launch and Keyterms focus are supplied implementation evidence.
  Closure did not repeat UI interactions. User/lead-owned PIDs 18183, 23302 and 24222
  and user app processes were preserved.
- Acceptance boundary: Aidan's explicit full-window judgment remains pending, and
  stream 3 remains Blocked on `S3-UI-01`. Controller-disabled inspection does not
  establish production hotkeys, microphone, MCP, inference or actual setup/removal;
  stream 4 retains that functional gate. No source, plan, settings, Keychain, cache,
  model-store or user-process action was taken. Only this closure section was appended.

## 2026-10-10 header correction handoff

- Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on
  `feat/local-models-productionization`. Only `Views/SettingsView.swift` and
  `Views/SettingsSplitView.swift` changed in this correction. `App.swift`, approved
  grouped page contents, the permanent native sidebar, detail material, store and
  lifecycle fixes remain intact. Changes are uncommitted; plan ownership stays with the lead.
- The three latest header attachments show a top-only padded page title stacked
  beneath the visible app title. The old VStack also stops Form scrolling directly
  at the title's lower edge. The title now occupies a top `safeAreaInset`, with
  symmetric 16-point vertical spacing and standard SwiftUI `regularMaterial`.
  The Form owns the scrolling region beneath that inset. This avoids scroll-offset
  tracking, extra history state, a hand-drawn separator or custom blur machinery.
- A private subclass of the existing native split controller applies
  `window.titleVisibility = .hidden` and `titlebarAppearsTransparent = true` in
  `viewDidAppear`. The window retains its `EchoType Settings` title string and AX
  identity. Ordinary native traffic lights, resize behavior and split/sidebar
  configuration remain. No toolbar lookup, replacement chrome or window enumeration
  is needed; the controller configures its own attached window, including reopening.
- Primary API support: Apple's [SwiftUI materials documentation](https://developer.apple.com/documentation/swiftui/material)
  describes in-app background blur, platform-specific blending and appearance-sensitive
  material thickness. Apple's [WWDC21 safe-area/material demonstration](https://developer.apple.com/videos/play/wwdc2021/10021/)
  explains using `safeAreaInset` to let a scrolling region extend beneath material
  while reserving unobscured space for content. Apple's
  [hidden title visibility documentation](https://developer.apple.com/documentation/appkit/nswindow/titlevisibility-swift.enum/hidden)
  documents hiding the title without removing native window controls. Apple's
  [Reduce Transparency documentation](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)
  says backgrounds should become opaque for that preference. This correction leaves
  standard material rendering to SwiftUI. Reduce Transparency and Increase Contrast
  were not toggled, so their appearance is not verified here.
- Verification: sequential release packaging passed in 23.80 seconds, log
  `.build/header-settings-release.log`. Strict deep signatures pass for production
  and both fresh inspection copies. All 95 source/package hashes match
  `stream3-candidate.json`, with the executable newer than every inventoried source.
  Normalized executable code matches after signature removal; all 22 resources match
  byte for byte. `stream3-header-verification.json` contains hashes and provenance.
  Reused unchanged 26 Core and 85 App results from `.build/local-feedback-focused.log`.
  `git diff --check` passed. No inference or competing Swift build ran.
- Fresh candidate executable SHA-256:
  `f66bbce542535bbff668071d0417cb64277ce3691ca90de8099e60d309457450`.
  Fresh safe copies are `HeaderSettingsInspectionLight.app` and
  `HeaderSettingsInspectionDark.app`, beside the production candidate. Their unique
  ids end `stream3-inspection-header-light` and `stream3-inspection-header-dark`,
  with existing inspection boolean and theme metadata. Their executable hashes are
  `453211a009343a842d1969b11ca73ee5ee8e0ae6b67207fb4fcfde883bd942ad` and
  `3a3bdb35b9a29d513d90a8080665359fadad8daf2b60eb50e908c063d055d59c`.
  Previous native verification and bundles remain historical and were not overwritten.
- Actual CUA screenshots and AX observations cover scrolled Local in both themes,
  Light Dictation and both short General pages. Local's scrollbars reached
  `0.2321342925659473`; rows move beneath the inset header while its title stays
  readable with bottom space. The standard material visibly separates header and
  content. This is rendered layout evidence and API-supported blur, not a measured
  pixel-level blur test. Screenshots are in this agent's CUA transcript; the available
  screenshot API has no filesystem export. Both native Zoom commands expanded from
  790 to 1512 points and restored the original size, with sidebar leading x=0.
  Command-W followed by exact-path reopening retained the correction in both themes.
  AX still reports `EchoType Settings`, id `settings-inspection`, while screenshots
  omit the visible app title. Fresh screenshots show native traffic lights; macOS
  recording later substitutes its system sharing indicator during capture.
- Final safe Light is open on scrolled Local, PID 30630, launched at 08:26:22
  Europe/London from the exact new Light bundle executable. Fresh Dark PID 30748,
  launched at 08:26:42, remains open on General. User-owned inspection PIDs 18183,
  23302 and 24222 and all `/Applications/EchoType.app --mcp` processes, observed as
  6205, 21165 and 90751, were preserved. No CUA user-activity notice occurred in the
  fresh copies. No setup, prepare, download, removal, provider choice, credential,
  settings edit or permission action ran. New copies transfer to lead/user ownership.
- Focused before/after context is saved in `.build/header-settings-evidence/` as
  `SettingsView.before.swift`, `SettingsSplitView.before.swift` and corresponding
  `.diff` files, with hashes in the header verification record. These isolate this
  correction from adopted stream 3 dirty work. No remediation pass was needed.
  Independent review and explicit Aidan UI acceptance remain pending. Controller-disabled
  inspection does not establish stream 4 production hotkey, microphone, MCP, inference
  or setup/removal behavior.
- Safe review launch:
  `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/HeaderSettingsInspectionLight.app`.
  Dark uses the exact neighbouring `HeaderSettingsInspectionDark.app` path.


## 2026-10-10 header independent review

- Reviewer: fresh independent review subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet and
  required Settings/Parakeet context, accepted stream 1/2 handoffs, plan conventions and
  latest header feedback. Base and HEAD remain
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on `feat/local-models-productionization`.
- Scope: the entire isolated correction in `SettingsView.swift` and
  `SettingsSplitView.swift`, compared with the saved before-files and complete focused
  diffs in `.build/header-settings-evidence/`. Both diffs exactly reproduce the current
  source changes, and all four evidence hashes match `stream3-header-verification.json`.
  Earlier adopted native-container, grouped-page, inspection-startup and lifecycle/store
  work remains context, with its completed review and closure retained.
- Verdict: no blocking findings. Required findings: none. Optional findings: none.
  Questions: none. The page title now has symmetric 16-point vertical padding in a
  top safe-area inset. Public SwiftUI `regularMaterial` supplies its in-app material;
  the Form remains the scrolling content beneath the inset. The small private subclass
  configures its attached native window in `viewDidAppear`, hiding visible title text
  without clearing the window title or replacing native controls. No custom blur,
  scroll-offset state, toolbar lookup, replacement chrome, gutter or sidebar toggle
  appears. Existing native sidebar sizing/collapse policy, destination binding,
  provider identity, grouped pages and store/operation contracts are unchanged.
- Independent rendered inspection: used read-only CUA on the exact fresh
  `HeaderSettingsInspectionLight.app` and `HeaderSettingsInspectionDark.app` paths.
  Light remains on Local at scroll value `0.2321342925659473`; Dark remains on General.
  Actual screenshots show balanced spacing around each page title, no visible app
  title, sidebar leading x=0, readable grouped content and theme-appropriate header
  material. Light rows reach the lower edge of the inset while its title stays clear.
  Both AX trees retain `EchoType Settings`, id `settings-inspection`. Light's initial
  AX tree includes native close, full-screen/zoom and minimize controls; capture shows
  the macOS Window sharing indicator. No app toggle or replacement chrome is present.
  No navigation, scroll, resize, close, focus, settings or model action was performed.
- Independently checked all 95 source/package hashes against `stream3-candidate.json`;
  all match. The production executable hash is
  `f66bbce542535bbff668071d0417cb64277ce3691ca90de8099e60d309457450`.
  Production and both exact inspection executable hashes match the header verification
  record and postdate every inventoried source. Unique bundle identities,
  inspection booleans and Light/Dark theme metadata match their intended launches.
  Strict deep signature verification passed on all three bundles. All 22 resource
  files match production byte for byte. The supplied unsigned-code scratch hashes
  match the recorded common hash
  `1a81bf80a891556fa8fc73205ca292f5a710cc4804c97d589d0bce4cdcd1f15e`;
  signature-removal provenance remains supplied implementation evidence.
- Reused `.build/header-settings-release.log`, which records successful release
  packaging in 23.80 seconds and signing, after independently matching its hash.
  Reused `.build/local-feedback-focused.log`, independently matching its hash and
  confirming 26 Core tests in four suites and 85 App tests in twelve suites passed.
  These unchanged behavior checks remain applicable to this container-only correction.
  `git diff --check` passed. No new build, tests or inference ran during review.
- Limits: the rendered checks establish the current Light scrolled Local and Dark
  General header layouts. The material's blur follows the public API contract; no
  pixel-level blur measurement or Reduce Transparency/Increase Contrast toggle was
  performed. Zoom/restore, close/reopen, other pages and both themes' scrolled Local
  checks are supplied implementation evidence, not interactions repeated here.
  Controller-disabled copies do not establish production hotkeys, microphone, MCP,
  offline inference or actual setup/removal behavior; stream 4 retains that gate.
  Aidan's full-window UI acceptance remains pending on `S3-UI-01`.
- Preserved PIDs 18183, 23302, 24222, 30630 and 30748 and all observed
  `/Applications/EchoType.app --mcp` processes. No CUA user-activity notice occurred.
  No source, plan, settings, Keychain, cache, model-store or process action was taken.
  Only this review section was appended.


## 2026-10-10 header focused closure

- Reviewer: fresh focused closure subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet,
  required Settings/Parakeet context, accepted stream 1/2 contracts and handoffs,
  plan conventions and latest header feedback. Base and HEAD remain
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on `feat/local-models-productionization`.
- Scope: only the isolated header correction in `SettingsView.swift` and
  `SettingsSplitView.swift`. The independent review recorded no Required, Optional
  or Question findings; the lead accepted that disposition without remediation.
  Earlier native-container, grouped-page and lifecycle/store closures remain intact.
- Verdict: pass. No outstanding required finding or new blocking defect remains.
  Required findings: none. Optional findings: none. Questions: none. The top
  safe-area inset gives the page title symmetric 16-point vertical spacing and
  standard `regularMaterial`, with the existing Form as the scrolling content.
  The private native split-controller subclass configures its own attached window
  in `viewDidAppear`, hiding visible title text while preserving the title string,
  native controls and reopening lifecycle. The correction adds no scroll-offset
  state, custom blur, toolbar lookup, replacement chrome or gutter. Sidebar policy,
  destination binding, provider identity, approved pages and operation/store contracts
  are unchanged.
- Independently reproduced both complete focused diffs from the saved before-files
  and current sources. All four before/diff hashes match
  `.build/local-productionization/stream3-header-verification.json`. All 95 current
  source/package hashes match `stream3-candidate.json`. Production executable SHA-256
  is `f66bbce542535bbff668071d0417cb64277ce3691ca90de8099e60d309457450`.
  Production and both exact `HeaderSettingsInspectionLight.app` and
  `HeaderSettingsInspectionDark.app` executable hashes match the verification record
  and postdate every inventoried source. Bundle ids and inspection/theme metadata
  match; strict deep signature verification independently passed on all three.
  All 22 resource files match production byte for byte. The existing unsigned-code
  scratch files match the recorded common hash
  `1a81bf80a891556fa8fc73205ca292f5a710cc4804c97d589d0bce4cdcd1f15e`.
  Signature-removal provenance remains supplied implementation evidence.
- Reused the successful release packaging in `.build/header-settings-release.log`,
  which records 23.80 seconds and signing, after independently matching its hash.
  Independently matched `.build/local-feedback-focused.log` and confirmed its
  26 Core tests in four suites and 85 App tests in twelve suites passed. These
  unchanged behavior results remain applicable to this header-only correction.
  `git diff --check` passed. No redundant build, tests or inference ran.
- Rendered evidence stays attributed to its source. The independent review inspected
  actual Light scrolled Local and Dark General screenshots and AX trees read-only,
  establishing balanced title spacing, no visible app title, sidebar leading x=0,
  readable content and theme-appropriate material. AX retained `EchoType Settings`
  and native window controls. Both-theme Local, other short pages, native Zoom/restore
  and close/reopen are supplied implementation evidence. Closure repeated no UI
  interactions. Standard material supplies blur by its API contract; no pixel-level
  blur measurement or Reduce Transparency/Increase Contrast check was performed.
- Acceptance boundary: Aidan's explicit full-window UI acceptance remains pending
  on `S3-UI-01`; this technical closure does not grant it. Controller-disabled copies
  do not establish production hotkeys, microphone, MCP, offline inference or actual
  setup/removal behavior, which remain stream 4's gate. No source, plan, settings,
  Keychain, cache, model-store or process action was taken. Existing inspection PIDs
  18183, 23302, 24222, 30630 and 30748 and all user app processes were left untouched.
  Only this closure section was appended.

## 2026-10-10 native toolbar implementation handoff

- Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. Only
  `Views/SettingsView.swift` and `Views/SettingsSplitView.swift` changed for this correction.
  App.swift, approved forms, lifecycle and unrelated dirty work remain preserved. No commit,
  merge, publication or live setup/settings/cache/Keychain action occurred. Source is frozen
  for independent review; explicit UI acceptance remains pending.
- Removed the padded SwiftUI `safeAreaInset` title. The existing native split controller now
  installs an actual `NSToolbar` with `.unifiedCompact` window style and system titlebar treatment.
  `NSTrackingSeparatorToolbarItem` follows the permanent sidebar divider. A standard AppKit
  `NSTextField` with semibold system font supplies the page title inside an `NSToolbarItem`.
  The container, sizing and material are native toolbar behavior; the title label is custom
  toolbar-item content. It is not a special built-in page-title item. The window title stays
  `EchoType Settings` for accessibility and menus, with visible title text hidden. No duplicate
  app-title row, negative padding, custom blur or private titlebar lookup is used.
- Public Apple references used are [compact unified toolbar style](https://developer.apple.com/documentation/appkit/nswindow/toolbarstyle-swift.enum/unifiedcompact),
  [tracking separator](https://developer.apple.com/documentation/appkit/nstrackingseparatortoolbaritem),
  [toolbar item view](https://developer.apple.com/documentation/appkit/nstoolbaritem/view) and
  [view safe area](https://developer.apple.com/documentation/appkit/nsview/safeareainsets).
  Read the latest supplied screenshot and both header/window Raycast references.
- Measured geometry uses temporary inspection-only logging of public window/hosting-view
  frames and safe areas. The logger was removed before the final clean release. Before evidence
  restores the prior composed header and transparent titlebar configuration in an isolated
  diagnostic source variant. Its 790×622-point window has a 790×590 content layout, detail top
  safe area 32 and sidebar top safe area 42. Its screenshot places the composed header bottom
  about 84.5 points below the window top. The recorded before `titleWindowRect` belongs to an
  unused label and must not be treated as the visible SwiftUI title's bounds.
- After diagnostic geometry is a 790×630-point window with 790×590 content layout, 40-point
  content and both hosting-view top safe areas. Sidebar begins at x=0 and remains 170 points
  wide; detail begins at x=170 and is 620 points wide. Actual title label rect is
  `{{172.5,602},{61.5,16}}` in window coordinates. The system bar is 40 points tall, with
  12 points above and below the 16-point label view. Final release screenshots independently
  show the same 80-pixel bar at 2× scale, replacing the prior roughly 169-pixel combined header.
  Glyph ink bounds and blur strength were not measured. The unchanged grouped forms consume
  their hosting view's native safe area rather than a second custom top inset.
- Fresh final release log is `.build/toolbar-settings-release.log`. Candidate provenance is
  `.build/local-productionization/stream3-candidate.json`; verification is
  `.build/local-productionization/stream3-toolbar-verification.json`. All 95 source hashes
  match and the binary is newer than its sources. Production plus both fresh inspection copies
  pass deep strict signing; normalized executable code and resources match after signatures
  are removed from comparison copies. Existing unchanged 26 Core/85 App tests remain applicable.
  `git diff --check` passes. No fresh lifecycle tests were warranted for this container change.
- Light and Dark final copies were inspected on scrolled Local and short General. Native Zoom
  and restore passed in both themes, with sidebar x=0 and the page title retained. Both windows
  closed with Cmd-W and reopened normally with native traffic lights and accessible identity.
  Screenshots and accessibility states are in the CUA transcript, which has no documented file
  export API. Material separation was visually inspected in both themes; accessibility
  contrast/transparency settings were not toggled. Actual production inference remains stream 4.
- First release and subsequent diagnostic build commands briefly overlapped by mistake.
  SwiftPM explicitly serialized them on its shared lock. Both completed before the subsequent
  before-diagnostic and final clean builds, which ran sequentially. This command overlap is
  recorded in verification rather than presented as compliant scheduling.
- Final safe Light PID `40641` is open on scrolled Local; Dark PID `40642` is open on General.
  Both started 2026-10-10 08:48:15 Europe/London. Exact commands are the corresponding
  `.build/local-productionization/ToolbarSettingsInspectionLight.app/Contents/MacOS/EchoTypeApp`
  and `ToolbarSettingsInspectionDark.app/Contents/MacOS/EchoTypeApp` under this repository.
  Unique ids end in `stream3-inspection-toolbar-light` and `stream3-inspection-toolbar-dark`.
  Launch evidence is `.build/local-productionization/stream3-toolbar-inspection-launch.json`.
  Ownership transfers to the lead and Aidan. Preserve these processes and bundles.
- Diagnostic PID `39620` received user activity and is preserved as user-owned. Its bundle is
  `ToolbarGeometry.app`, id `com.aidanzealley.echotype.stream3-inspection-toolbar-geometry`.
  The separate before diagnostic PID `40217` is also preserved, `ToolbarBeforeGeometry.app`.
  Geometry artifacts are `toolbar-before-geometry.json` and `toolbar-after-geometry.json` in
  `.build/local-productionization`. Neither diagnostic executable is the final candidate.
  Existing HeaderSettingsInspection PIDs `30630`/`30748`, all earlier user processes and
  every live `/Applications` MCP process remain untouched. No specification drift.

## 2026-10-10 native toolbar independent review

- Reviewer: fresh independent review subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet,
  required Settings/Parakeet context, accepted stream 1/2 handoffs, plan conventions
  and latest native toolbar authorization. Base and HEAD remain
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on `feat/local-models-productionization`.
- Scope: the complete isolated correction in `SettingsView.swift` and
  `SettingsSplitView.swift`, including recovered trial edits. Reproduced the exact
  correction diff from both saved before-files. Earlier page, container and
  lifecycle work is accepted context; this review does not reopen it.
- Verdict: pass for source behavior. Required findings: none. Questions: none.
  The controller installs an actual `NSToolbar` on its attached window in
  `viewDidAppear`, uses unifiedCompact system treatment and a tracking separator,
  and hides visible window title text while retaining the window title string.
  The title is a standard `NSTextField` used as custom toolbar-item content, not a
  special built-in page-title item. Representable updates refresh its value and
  size for each destination. Removing the SwiftUI padded safe-area inset leaves
  AppKit owning the toolbar and hosting-view safe area. The permanent sidebar,
  approved forms, provider identity and lifecycle/store contracts are unchanged.
- Optional finding S3-TO1: refresh the candidate's nested verification pointers.
  `.build/local-productionization/stream3-candidate.json`, lines 222-228, still
  names `.build/header-settings-release.log` and
  `stream3-header-verification.json`. Those are historical header evidence, while
  the same file's executable hash and correction describe the new toolbar build.
  A reader following only those pointers receives evidence for the prior source.
  Update them to `.build/toolbar-settings-release.log` and
  `stream3-toolbar-verification.json`. This is provenance bookkeeping, not a source
  defect or code remediation requirement. Current toolbar evidence independently
  verifies the candidate, so the stale nested pointers do not block this review.
- Independently verified all 95 current source/package hashes against the candidate
  inventory, exact before-file/diff and geometry-artifact hashes against toolbar
  verification, and production executable SHA-256
  `837378c7ca439cf93b0f3e8b6f4adab2d2c52935755c48009dcdc5b755071bfd`.
  Production and both exact ToolbarSettingsInspection Light/Dark bundle ids and
  executable hashes match; all three binaries postdate inventoried sources and
  independently pass deep strict signature verification. All 22 resource files in
  each inspection copy match production. Existing unsigned-code comparison files
  match the common recorded hash
  `4d86377a49c11ad7f92a7256fc91ae5d0e39ae5f5f6ce9f1d30ad48392473afa`.
  Signature-removal provenance remains supplied implementation evidence.
- Independently matched the fresh toolbar release log hash and confirmed successful
  24.58-second release packaging/signing. Matched the focused log hash and confirmed
  26 Core tests in four suites and 85 App tests in twelve suites passed. Reused those
  unchanged lifecycle/page behavior results. `git diff --check` passed. No new
  build, inference or redundant lifecycle test run was needed for this correction.
- Read-only CUA inspection used the exact final
  `.build/local-productionization/ToolbarSettingsInspectionLight.app` and
  `ToolbarSettingsInspectionDark.app` paths. Actual screenshots and AX trees show
  Light scrolled Local and Dark short General, one page title in an 80-pixel bar
  at 2x scale, sidebar at leading x=0 and no visible duplicated app-title header.
  AX retains `EchoType Settings` and a toolbar title matching the selected page.
  Native control availability varies with current activation/window-sharing state;
  this review did not change focus. Both-theme navigation, native Zoom/restore,
  Cmd-W/reopen and traffic-light checks are supplied implementation evidence.
- Geometry remains diagnostic evidence, separate from the final signed executable.
  The checked after record gives 40-point content and hosting-view top safe areas,
  sidebar x=0, detail x=170 and a 16-point label with 12 points above and below.
  The before composed header's approximately 84.5-point total comes from supplied
  screenshot measurement; its unused `titleWindowRect` is not a visible-title bound.
  The final screenshots corroborate bar height and placement, without an injected
  logger. System toolbar material follows the selected public API and both themes
  were visually inspected. Blur strength, glyph ink bounds and accessibility
  contrast/transparency preferences were not measured or altered.
- Acceptance boundary: explicit Aidan UI acceptance remains pending on `S3-UI-01`.
  Controller-disabled copies do not establish actual production hotkeys, microphone,
  MCP, offline inference or setup/removal behavior; those remain stream 4's gate.
  No source, plan, settings, Keychain, cache, model-store or process action occurred.
  Confirmed PIDs 40641/40642, 30630/30748 and diagnostic 39620/40217 remain running;
  all user processes and live `/Applications` MCP processes were left untouched.
  Only this review section was appended.

### S3-TO1 resolution, 2026-10-10

- Corrected only `stream3-candidate.json`'s nested verification metadata. `release_log` now
  points to `.build/toolbar-settings-release.log`; `provenance` now points to
  `.build/local-productionization/stream3-toolbar-verification.json`. Added their current
  SHA-256 values, toolbar verification timestamp, 95-source count and the existing accurate
  binary/source modification times with `binary_newer_than_sources: true`.
- Existing 26 Core/85 App test references and passed strict-signature record remain valid.
  No source, executable, inspection bundle, verification artifact or process changed. No
  rebuild occurred. The source behavior review passed with no Required findings or Questions;
  the lead promoted optional S3-TO1 for this one bounded bookkeeping remediation. Fresh
  focused closure remains pending, independently of Aidan's UI acceptance.

## 2026-10-10 default toolbar spacer implementation handoff

- Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on
  `feat/local-models-productionization`. The only source change from the reviewed toolbar
  candidate is `SettingsSplitView.swift`'s default item array, now
  `[Self.separatorID, .space, Self.titleID, .flexibleSpace]`. Exact before-file comparison and
  all 95 source hashes establish that the other 94 inventoried files are unchanged.
  No custom padding, title redesign or other source edit was made. Changes remain uncommitted;
  plan/status changes and final acceptance belong to the lead.
- AppKit supplies its standard `NSToolbarItem.Identifier.space` between the tracking separator
  and existing title item. The container and material remain native toolbar behavior. The title
  remains an `NSTextField` used as custom toolbar-item content, rather than a built-in page-title
  item. Approved pages, native sidebar/window configuration and lifecycle contracts are preserved.
- Sequential release packaging passed in 22.98 seconds, recorded in
  `.build/spacer-settings-release.log`. The expected pronunciation-builder initial missing
  dictionary diagnostic preceded successful completion, as in accepted packaging evidence.
  Candidate executable SHA-256 is
  `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`.
  Fresh production and `SpacerSettingsInspectionLight.app` / `SpacerSettingsInspectionDark.app`
  copies all pass deep strict signature verification. Normalized executable code matches after
  removing signatures from comparison copies, and all resources match production.
  All 95 source hashes match; the release binary postdates the inventoried sources.
  Existing unchanged 26 Core / 85 App results in `.build/local-feedback-focused.log` are reused.
  `git diff --check` passes. No inference or redundant lifecycle tests ran.
- Actual fresh Light and Dark native windows were inspected with CUA. Dictation was rendered in
  both themes, then Light Local and Dark General. Their toolbar titles update with navigation
  and have a visible standard gap from the sidebar divider. In the 1580-pixel screenshots at
  2x scale, the divider is near x=340 and title starts near x=365. This is an approximate visual
  observation, not instrumented geometry. Native theme treatment and accessible window identity
  remain present. No screenshot export API is documented; screenshots and AX states remain in
  the CUA transcript. No blur-strength measurement, accessibility preference toggle, resize or
  close/reopen check was repeated for this one-line spacer change.
- Current candidate metadata is `.build/local-productionization/stream3-candidate.json`.
  Its nested verification pointers and hashes now consistently reference
  `.build/spacer-settings-release.log` and
  `.build/local-productionization/stream3-spacer-verification.json`. Exact correction evidence
  is `.build/local-productionization/default-toolbar-spacer.diff`; before-source inventory is
  `spacer-before-source-sha256.json`. Reconstruction uses `refresh-spacer-artifacts.py` and
  signing/code/resource comparison is recorded in `spacer-provenance-refresh.log`, all under
  `.build/local-productionization`. Previous toolbar provenance remains historical and untouched.
- Fresh safe Light PID `75712` remains open on Local; Dark PID `75743` remains on General.
  Exact executable paths are under this repository's
  `.build/local-productionization/SpacerSettingsInspectionLight.app/Contents/MacOS/EchoTypeApp`
  and `SpacerSettingsInspectionDark.app/Contents/MacOS/EchoTypeApp`. Their unique bundle ids are
  `com.aidanzealley.echotype.stream3-inspection-spacer-light` and
  `com.aidanzealley.echotype.stream3-inspection-spacer-dark`. Launch evidence is
  `.build/local-productionization/stream3-spacer-inspection-launch.json`. Ownership transfers
  to the lead and Aidan; preserve these processes and bundles.
- The previously recorded toolbar PIDs `40641`/`40642`, diagnostic PIDs `39620`/`40217` and prior
  inspection processes were absent at the initial inventory. None were relaunched or touched.
  Their existing bundles and all old handed-off bundles remain untouched. The live
  `/Applications/EchoType.app` MCP process and installed bundle are preserved. No downloads,
  setup, removal, provider/settings edit, Keychain or model-store change occurred.
- Aidan's instruction to fix this one header issue and mark Settings approved supplies
  conditional UI authorization once the exact spacer is verified. Implementation has verified
  it; the lead records acceptance after the pending fresh focused closure. No further UI
  question is needed. Actual production operations and offline inference remain stream 4's gate.
  No specification drift.


## 2026-10-10 default toolbar spacer independent review

- Reviewer: fresh independent review subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet,
  Settings/Parakeet context, stream 1/2 handoffs and plan conventions. Base and HEAD remain
  `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on `feat/local-models-productionization`.
- Scope: the complete recovered native toolbar correction in `SettingsView.swift` and
  `SettingsSplitView.swift`, including adopted trial edits and the final default spacer.
  Earlier page/lifecycle review and closure are accepted context, not restarted here.
  Reproduced the complete native toolbar diff from the two saved before-files and verified
  their hashes and the historical diff hash. Reproduced the final exact one-line insertion
  from `spacer-before-SettingsSplitView.swift`. Comparing all 95 prior/current source hashes
  establishes that only that file changed after the previous toolbar review.
- Verdict: pass. Required findings: none. Optional findings: none. Questions: none.
  The native controller installs unifiedCompact NSToolbar treatment when attached to its
  window, uses a tracking separator for divider zero and preserves the accessible window
  title while hiding visible window-title text. Representable updates refresh the title
  label and its size. Removing the padded SwiftUI inset leaves native toolbar/safe-area
  ownership intact. The default items now place AppKit's `.space` exactly between the
  separator and title, followed by `.flexibleSpace`. The NSTextField is ordinary custom
  toolbar-item content, not a special built-in page-title item. Approved pages, provider
  identity, permanent sidebar and lifecycle/store contracts are unchanged.
- Independently verified all 95 current source/package hashes against `stream3-candidate.json`,
  the exact spacer diff hash against `stream3-spacer-verification.json` and candidate
  executable SHA-256 `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`.
  Production and both exact SpacerSettingsInspection Light/Dark executable hashes and
  bundle ids match the verification record; all three binaries postdate every inventoried
  source and independently pass deep strict signature verification. Inspection metadata
  enables controller-disabled Settings. All 22 resource files in each copy match production.
  Existing unsigned-code comparison files match the common recorded hash
  `416ae1068e492e5edef427c4a5206589ace241d726da914e0268d2e7aac51715`.
  Signature-removal provenance remains supplied implementation evidence.
- Independently matched the fresh release log hash and confirmed successful 22.98-second
  release packaging/signing. The initial missing pronunciation dictionary diagnostic is
  followed by successful build completion. Matched the focused log hash and confirmed
  26 Core tests in four suites and 85 App tests in twelve suites passed. Reused those
  unchanged page/lifecycle results. `git diff --check` passed. No build, inference or
  redundant lifecycle test ran. Candidate nested release/provenance paths and hashes now
  consistently identify the spacer evidence, resolving prior optional S3-TO1.
- Read-only CUA inspection used the exact final Light/Dark app paths. Actual screenshots
  show Light Local and Dark General, one readable toolbar title with the standard gap
  after the sidebar divider, sidebar at leading x=0 and theme-appropriate native treatment.
  The title starts near x=365 with divider near x=340 in 1580-pixel captures at 2x scale,
  an approximate visual observation rather than instrumented geometry. AX retains
  `EchoType Settings` and matching Local/General toolbar title values. Window-sharing
  chrome is visible; native control availability follows activation/sharing state.
  This review changed no focus, selection, scroll, settings or window state.
- Limits and acceptance: implementation's both-theme Dictation/navigation checks and earlier
  toolbar Zoom/restore/close/reopen checks remain supplied evidence. They were not repeated
  for the one-line spacer. No blur-strength, glyph-bound or accessibility preference
  measurement was made. Controller-disabled copies do not establish production hotkeys,
  microphone, MCP, offline inference or actual setup/removal, which remain stream 4's gate.
  Aidan's conditional Settings approval applies once this exact correction and focused
  closure pass; the lead records that acceptance without another UI question. Confirmed
  PIDs 75712/75743 remain running at their exact handed-off paths. No source, plan, Keychain,
  model-store, cache or process action occurred. All user processes are preserved. Only
  this review section was appended.

## 2026-10-10 default toolbar spacer focused closure

- Reviewer: fresh focused closure subagent, inherited model and effort, Codex harness.
  Applied code-review, coding practices and unslop. Read the specification, packet,
  required Settings/Parakeet context, accepted stream 1/2 handoffs and plan conventions.
  Base and HEAD remain `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` on
  `feat/local-models-productionization`. Earlier lifecycle/page closures remain accepted.
- Verdict: pass. Required findings: none. Optional findings: none. Questions: none.
  Verified the complete recovered native toolbar correction in `SettingsView.swift` and
  `SettingsSplitView.swift`, the lead's accepted review dispositions and promoted S3-TO1
  bookkeeping correction. Reproduced the historical complete toolbar diff from both
  saved before-files, then verified the exact final one-line spacer insertion. Of all
  95 prior/current source entries, only `SettingsSplitView.swift` changed after the
  toolbar review. No new blocking defect was found in this scope.
- Default items are exactly `[Self.separatorID, .space, Self.titleID, .flexibleSpace]`.
  AppKit supplies the fixed space between the split tracking separator and title item.
  No custom spacing was added. The unifiedCompact toolbar owns native header treatment;
  its ordinary `NSTextField` title updates and sizes with navigation. The removed padded
  SwiftUI inset stays removed. Accessible window identity, permanent sidebar, approved
  controls, provider identity and lifecycle contracts remain intact.
- Independently matched all 95 current source/package hashes, current production SHA-256
  `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`, both exact
  SpacerSettingsInspection executable hashes and bundle ids, and binary freshness against
  every inventoried source. All three bundles independently pass deep strict signature
  verification. Each inspection copy's 22 resources match production. Existing normalized
  executable comparison files match the common recorded SHA-256
  `416ae1068e492e5edef427c4a5206589ace241d726da914e0268d2e7aac51715`.
  Signature-removal provenance remains supplied implementation evidence; no copies were
  modified or signatures removed during this closure.
- Independently matched the spacer and historical toolbar diff/artifact hashes, release
  log hash and reused focused log hash. Release packaging completed in 22.98 seconds,
  after the previously documented initial missing pronunciation-dictionary diagnostic.
  The focused log confirms 26 Core tests in four suites and 85 App tests in twelve suites
  passed. Candidate nested release/provenance paths and hashes consistently identify
  `.build/spacer-settings-release.log` and `stream3-spacer-verification.json`, closing
  S3-TO1. `git diff --check` passed. No builds, inference or redundant tests ran.
- Reused the just-completed independent read-only Light Local/Dark General rendered
  inspection. It records one readable page title, the standard gap after the divider,
  leading sidebar and native treatment in both themes, with matching accessible titles.
  This closure made no UI interaction. Both-theme navigation and earlier native
  Zoom/restore/close/reopen checks remain supplied evidence. Blur strength, glyph bounds
  and accessibility preferences were not measured or changed.
- Confirmed PIDs `75712` and `75743` remain running at their exact handed-off
  SpacerSettingsInspection Light/Dark executable paths. All user processes and bundles
  are preserved. No source, plan, settings, Keychain, cache, model-store or process action
  occurred; only this closure section was appended. Aidan's recorded instruction,
  `Fix that one header thing and let's just mark this settings UI as approved`, authorizes
  the lead to record UI acceptance now that this exact fix and focused closure pass.
  Plan/status changes and any scoped commit remain lead-owned. Actual production hotkeys,
  microphone, MCP, offline inference and setup/removal remain stream 4's functional gate.
  No specification drift.


## Final acceptance and dependency handoff, 2026-10-10

- Lead accepts stream 3. Required implementation, lifecycle/page reviews, bounded corrections and fresh native toolbar/default-spacer closure are complete. No required finding remains. Final independent review and focused closure both report no Required, Optional or Question findings.
- Aidan said `Fix that one header thing and let's just mark this settings UI as approved`. The only final source correction inserted standard `.space` between the native split tracking separator and title item. It passed actual Light/Dark inspection and independent verification. This fulfills conditional UI approval; native Settings judgment is Accepted and plan S3-UI-01 is resolved.
- The final header is a native AppKit unified compact toolbar with a tracking separator and default spacing. A standard NSTextField supplies custom content for the title item; it is not a special built-in page-title control. AppKit owns the toolbar's height, material and spacing. Approved forms, permanent sidebar, setup/lifecycle and ownership behavior remain unchanged.
- Current production candidate SHA-256 is `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`. Current provenance is `.build/local-productionization/stream3-spacer-verification.json`. Release packaging passed in 22.98 seconds, 95 source identities and three strict signatures pass, normalized code/resources match. The unchanged 26 Core/85 App test results remain applicable. Earlier candidate/blocked statements above are historical.
- Scoped acceptance includes only this stream's source/tests and packet/plan records. Parakeet's tokenizer-cache guard is staged separately from stream 4 timing instrumentation. Unrelated dirty trial files remain preserved. Updated specification stays with stream 4 documentation ownership.
- Safe signed Light PID 75712 and Dark PID 75743 are left open and transferred to Aidan. All prior observed user processes/bundles remain untouched. Stream 4 retains actual signed production-app functional evidence, combined-memory checks, demo/bench retirement and public-release hold. No merge or publication is authorized. No drift.
