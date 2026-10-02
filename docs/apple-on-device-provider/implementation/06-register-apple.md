# Workstream 6: Register Apple and verify it on the Mac

Status: accepted. G2 partially passed; remaining external checks follow whole-feature review.

## Task packet

### Outcome

Apple appears in the Provider tab after xAI and supplies all three services. Required permissions are in place, the spike code is gone, the documentation describes the new provider and readiness, and signed-build evidence is recorded. Aidan moved the remaining external checks after whole-feature review.

Specification: [Apple provider](../../specs/apple-on-device-provider.md#apple-provider), [Spike code](../../specs/apple-on-device-provider.md#spike-code), [Verification](../../specs/apple-on-device-provider.md#verification) and [Extensibility report](../../specs/apple-on-device-provider.md#extensibility-report).

### Scope

- Add `Provider.apple`: id `apple`, name `Apple`, summary "Free. Runs on this Mac.", `Credential.none`, and the three services. Compose `Readiness` from the per-service checks and the change signal.
- Register it in `Providers.all` after xAI, so xAI stays the default.
- Settle permissions. Record the SDK and runtime evidence for whether `SpeechTranscriber` needs Speech authorisation or a usage description. If it does, follow the microphone pattern:
  - add the usage text and any entitlement,
  - request at operation start,
  - word the denial in `DictationController.describe`,
  - show it in the Settings system rows.
  
  Record the evidence either way. First-use signed-app permission behavior remains an end check.
- Delete `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/` after confirming the production adapters and tests cover what is useful. Update the research document's Experiment code and Reproduction sections to say the experiments were removed and live in git history.
- Documentation:
  - add the extensibility report to `docs/decisions/0025-provider-adapters.md`, listing every change outside `Providers/Apple/` and `Providers.swift` with its reason and whether it belongs in the shared contract,
  - update its "Adding a provider" steps for readiness and language resolution,
  - update `README.md` where it says xAI is the only provider.
- Prepare G2 and record Aidan's results, including the speed range. Remaining checks follow whole-feature review by his 2026-10-02 decision.

### Non-goals

- Cleanup quality tuning, additional languages, and changes to the readiness contract.
- Launching or replacing Aidan's running EchoType. `scripts/run.sh` and `scripts/install.sh` stop running copies, so only Aidan runs them.

### Initial ownership

- New description file in `Sources/EchoTypeCore/Providers/Apple/`, and the Apple files only for composition fixes
- `Sources/EchoTypeCore/Providers/Providers.swift`
- `Resources/Info.plist`, `Resources/EchoType.entitlements`, plus `AudioCapture.swift`, `DictationController.swift` and `SettingsView.swift` only if a permission is required
- `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/` (deletion), `docs/research/apple-on-device-provider.md`, `docs/decisions/0025-provider-adapters.md`, `README.md`
- Apple voice and transcription files for speed-range and troubleshooting corrections during G2

### Required seams

- Consumes every earlier handoff.
- The extensibility report is the final account of shared changes for the whole-feature review.

### Acceptance criteria

- `Providers.all` is `[.xAI, .apple]`, and `Provider.xAI` is unchanged.
- The Provider tab lists Apple with three feature marks and readiness reasons, with no settings or UI change beyond workstreams 1 and 2 and any required permission row.
- The permission decision is recorded with evidence.
- The spike folder is deleted, and no link to it remains outside git history.
- The extensibility report accounts for every shared change in the branch.
- Record G2 passes and the chosen speed range. Keep the unverified items in the plan's end checklist after whole-feature review; they do not block this acceptance.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift build -c release --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-ws6.app
git diff --check
```

`build-app.sh` signs a bundle at a scratch path without stopping the running app.

## External validation

- Gate and placement: G2 signed-build verification. Aidan moved all remaining checks after whole-feature review on 2026-10-02, amending the original pre-acceptance placement.
- Status: partially passed. Items 1, 2, 10, 11 and 12 passed by Aidan's report; items 3, 4, 5, 6, 7, 8, 9 and 13 are pending external checks.
- Candidate, instructions and evidence: [G2 end checklist](plan.md#g2-end-checklist) is the canonical numbered record. The reported passes concern the WS6 candidate over `53c563bea5aab0fe43a3e0ee9f9b96d87d21b670`. Remaining checks use the final reviewed candidate.
- Lasting decisions: retain the existing Apple `0.8...1.3` range, including 1x. Aidan prefers 1.1x and accepts the range as usable and sensible. Defaults remain unchanged. He cannot change the environment or restart now and instructed, "Let's move anything unverified right to the end".
- Required evidence: remaining item results, any unavailable test conditions and first-use permission prompt behavior. Automated and unsigned live evidence does not replace this signed-app evidence. Item 1 passed, but item 13's first-use permission behavior remains unverified.
- Acceptance: independent review and focused closure passed after R1 and R2 were fixed. Aidan's explicit relocation resolves E6-G2 and permits WS6 acceptance and whole-feature review. Full external verification still requires the remaining checklist items.

## Implementation handoff

This records the original implementation and remediation evidence before Aidan's G2 report. Current external validation status is above.

- Base commit: `53c563bea5aab0fe43a3e0ee9f9b96d87d21b670`
- Outcome: `Provider.apple` is registered after xAI and composes the three services and their readiness checks. No permission change was needed. The spike folder is deleted, and the README, the research document and the provider adapters decision (with the extensibility report) describe Apple and readiness. Gate G2 is not run; it is the lead's.
- Files changed:
  - `Sources/EchoTypeCore/Providers/Apple/Apple.swift`: `public static let apple` in `extension Provider` (id `apple`, name `Apple`, summary "Free. Runs on this Mac.", `.none`, the three services). `readiness.check` returns `ServiceReadiness(transcription: await Apple.speechAssets.check(language:), voice: Apple.Speech.check(language:voice:), cleanup: Apple.Intelligence.check(language:))`; `changes` is `{ Apple.changes.stream() }`. The `Apple` doc comment names `Provider.apple`.
  - `Sources/EchoTypeCore/Providers/Providers.swift`: `all = [.xAI, .apple]`.
  - `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/`: deleted (six files).
  - `Tests/EchoTypeCoreTests/SettingsTests.swift`: `registeredProviders`, which checks registry order (xAI default) and that a stored `"apple"` selection loads as Apple.
  - `Tests/EchoTypeCoreTests/Integration/AppleTranscriptionLiveTests.swift`: `providerIsReady`, a live check that `Provider.apple.readiness` answers all `.ready` for English and the default voice.
  - `README.md`: tagline, Keyterms limit (99 saved terms, matching the Keyterms tab's `keytermLimit - 1`), Provider bullet, Install requirements and step 5, the `ECHOTYPE_APPLE_LIVE` gate, and readiness in the add-a-provider paragraph.
  - `docs/decisions/0025-provider-adapters.md`: the registry lists xAI then Apple; the `Apple` namespace sits beside `XAI`; "Adding a provider" gains language resolution and readiness steps; the closing paragraph names the readiness reasons and pills; a new "Extensibility report" section tabulates every change outside `Providers/Apple/` and `Providers.swift` across the branch, with reason and contract status, and records the permission decision.
  - `docs/research/apple-on-device-provider.md`: "Experiment code" says the experiments were removed and gives a `git log --diff-filter=D` command, with the links removed. "Reproduction" says its spike commands are historical and need the experiments restored, and points at the production live checks. Two "retained" phrasings now say the code is in git history.
- Decisions:
  - Composition lives in `Apple.swift`, matching `Provider.xAI` in `XAI.swift`, rather than in a new description file. The packet allowed a new file; one more file holding 13 lines added nothing.
  - Registering Apple initialises no framework at load. `Provider.apple` touches only the lazy `static let` service values; `Apple.changes` and `Apple.speechAssets` are reached only inside the readiness closures, which the controller calls only when Apple is selected.
  - Permissions: no Speech authorisation, usage description or entitlement added, so `AudioCapture.swift`, `DictationController.swift`, `SettingsView.swift`, `Info.plist` and the entitlements are unchanged. Evidence:
    - SDK (`MacOSX27.0.sdk`): the Speech framework's authorisation API and the `NSSpeechRecognitionUsageDescription` requirement are documented only on `SFSpeechRecognizer` (`SFSpeechRecognizer.h`: `requestAuthorization`, `authorizationStatus`, and "If this key is not present, your app will crash when you call this method"). The Swift interface declaring `SpeechAnalyzer`, `SpeechTranscriber` and `AssetInventory` (`Speech.swiftmodule/arm64e-apple-macos.swiftinterface`) has no authorisation or usage symbol. No other Apple documentation is available locally.
    - Runtime: on 2026-10-02, before deletion, the spike's transcription suite ran (`ECHOTYPE_APPLE_SPIKE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-synthetic/recording.wav swift test --disable-xctest --filter AppleTranscriptionSpike`, 6 tests passed on macOS 27.2 26B5091g). `SFSpeechRecognizer.authorizationStatus()` printed `0` (`notDetermined`) before any request and after every lifecycle case, and the recording case transcribed the full synthetic sentence. The research recorded the same in S1. The production live suite also transcribes with no authorisation request.
    - Bundle: the built `.build/EchoType-ws6.app` has `NSMicrophoneUsageDescription` only, the hardened runtime flag and the `com.apple.security.device.audio-input` entitlement, with no sandbox. `codesign --verify --strict` passes.
    - Confirmed: `SpeechTranscriber` transcribes without Speech authorisation in an unsigned, unsandboxed `swift test` process. Not confirmed, and left for G2: on the signed hardened-runtime bundle, the first Apple dictation shows only the microphone prompt, no Speech Recognition prompt, and transcribes. If G2 shows a Speech prompt or a denial, follow the packet's microphone pattern then.
  - Spike coverage before deletion: production fixture tests and `ECHOTYPE_APPLE_LIVE` checks cover readiness/installation, finish before ready, silence, the synthetic recording through `SessionMachine`, both voices' PCM, paused-read bounds, pull cancellation, cleanup readiness, revision and overflow. Not carried over, and kept only in git history and the research: inventory printing, keyterm read-back, explicit French installation, the rate-grid calibration, listening-sample export, language fallback with real voices, cancellation of a human recording, and the cleanup quality comparison. All were measurements whose results the research records.
  - The extensibility report says every shared change belongs in the shared contract, and none names Apple. The one behaviour change xAI also sees is listed: a reader's raw `.failed` description is no longer flashed before the worded failure (workstream 1).
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest`: 126 core tests in 14 suites (138 before, minus 14 spike tests, plus the two new ones; live suites skip), 71 app tests in 10 suites.
  - `swift build -c release --product EchoTypeApp`
  - `./scripts/build-app.sh debug .build/EchoType-ws6.app`: signed with team `LJHNNE925Q`, hardened runtime; nothing was launched or stopped.
  - `git diff --check`
  - Live: `ECHOTYPE_APPLE_LIVE=1 ECHOTYPE_FIXTURE_WAV=/tmp/echotype-s1-synthetic/recording.wav swift test --disable-xctest --filter Apple`: 31 tests in 6 suites, including `providerIsReady`.
- Known limitations or external checks:
  - G2 has not run: every Verification item, the speed range (still the provisional `0.8...1.3` in `AppleVoice.swift`, anchors cover `0.7...1.5`) and the Speech prompt behaviour on the signed build.
  - The Provider tab with Apple selected, its three marks and its reasons were not seen; the tab's code is unchanged since workstreams 1 and 2.
  - The spec, the implementation README and plan still mention the spike path in prose (not links). They are outside this packet's ownership and describe the plan.
  - The extensibility report's last paragraph states the permission decision as the signed build will confirm it; the lead should amend it if G2 disagrees.
- Specification drift: none.

- Remediation for accepted R1 and R2:
  - `docs/decisions/0025-provider-adapters.md` retains the SDK and `swift test` permission evidence and now states that signed-build dictation and permission prompt behaviour await G2. This supersedes the original handoff's description of the report's permission conclusion; no signed runtime confirmation has occurred.
  - The extensibility report groups the six implementation packets and `plan.md` in one workflow documentation row, marked outside the shared contract.
  - Verification passed: `git diff --check`; a focused documentation check compared the branch's changed workflow files against the grouped row, confirmed all seven records are covered once, and checked the permission wording against G2's pending status in this packet and `plan.md`.
  - Simplification pass kept both corrections in the existing report. No production code, tests, permissions or frozen task packet changed.

## Independent review

This review preceded Aidan's G2 report and gate-relocation decision.

- Reviewer: fresh independent review agent, Codex.
- Verdict: Changes required in documentation. The registration and composition meet the code criteria, with no implementation defect found. G2 remains Aidan's pending gate and is not a code finding.
- Required findings:
  - R1: Correct the permission evidence in `docs/decisions/0025-provider-adapters.md:132-135`. It says the signed build's verification confirms no Speech authorisation is needed. That has not happened: External validation above is pending, and the handoff expressly limits the runtime evidence to `swift test`. Keep the SDK and test evidence, and state that signed dictation and prompt behaviour await G2. A successfully signed bundle establishes packaging, not runtime permission behaviour.
  - R2: Complete the extensibility report's account of changes outside the provider folder and registry. `docs/decisions/0025-provider-adapters.md:115-130` promises every branch change but omits `docs/apple-on-device-provider/implementation/01-provider-readiness.md` through `06-register-apple.md` and `plan.md`. These appear in `git diff e943484911c71384bf2d75fb4f7f13e68ff6f823 --name-only`. One grouped row can explain the workflow records and mark them outside the shared contract. All shared production files are already accounted for.
- Optional observations:
  - O1: `Tests/EchoTypeCoreTests/Integration/AppleTranscriptionLiveTests.swift:33-37` asserts all-ready after one check. Run in isolation on a Mac missing English speech assets, it can legitimately receive waiting while installation starts. The separate `englishBecomesReady` test at `:19-30` does not run when filtering just `providerIsReady`. Consider making this check wait for transcription setup itself, or documenting that this particular check needs installed assets and available Apple Intelligence. No live failure was reproduced, and assets were not removed.
- Questions: none.
- Review evidence:
  - `Sources/EchoTypeCore/Providers/Apple/Apple.swift:6-18` composes the description, all three services, per-service readiness and fresh change streams without another abstraction. `Sources/EchoTypeCore/Providers/Providers.swift:3` keeps xAI first. The diff leaves `Providers/XAI/`, bundle permissions and Settings UI untouched.
  - Composition consumes the dependency handoffs directly. The existing speech-assets actor owns setup across caller cancellation; the composition adds no task lifetime or cancellation wrapper. `DictationController.swift:167-190` subscribes before checking and rejects cancelled answers; `SettingsView.swift:240-242` uses the three generic service marks and reasons.
  - The six spike files are deleted, and the research's former file links are removed. Remaining spike paths are historical prose or frozen instructions, not broken links. The registry test protects both default order and loading a saved Apple selection.
  - All packet checks passed independently: `swift build`; `swift test --disable-xctest`, 126 core tests in 14 suites and 71 app tests in 10 suites, with live checks skipped; `swift build -c release --product EchoTypeApp`; `./scripts/build-app.sh debug .build/EchoType-ws6.app`; `git diff --check`. Full test log: `/tmp/echotype-ws6-independent-tests.log`.
  - Additional checks passed: `codesign --verify --strict .build/EchoType-ws6.app`; entitlement inspection shows only `com.apple.security.device.audio-input`. The local SDK's `SFSpeechRecognizer.h:105-115` documents the Speech usage key and authorisation API, consistent with the handoff's distinction between that API and `SpeechTranscriber`. No live framework check, app launch, process stop or installation command was run.

## Resolution

- Acceptance: Accepted. The user-authorized gate relocation is the only new specification drift; [the plan](plan.md#decision-and-drift-log) records it. No required code finding remains.
- Documentation amendment: this packet, the plan, implementation README, final-review packet and specification now agree on the remaining G2 checks following whole-feature review. The provider adapters report includes these workflow records and separates the passed dictation check from pending first-use permission evidence.
- Finding dispositions: R1 and R2 accepted and corrected in the single remediation pass. R1 now limits permission evidence to the SDK and unsigned tests, with signed-app confirmation pending G2. R2 groups the changed implementation packets and plan as workflow documentation. O1 deferred: the live all-ready composition check assumes installed English speech assets and available Apple Intelligence. It remains opt-in; no failing live run was reproduced. G2 separately checks missing-asset setup.
- Simplification/deletion pass: recovered implementation already deletes the six spike files and keeps composition in the existing Apple namespace. Review and remediation added no production abstractions, state, wrappers or tests. No further deletion was needed.
- Final verification: independent reviewer reran all five packet checks successfully, including 126 core and 71 app tests with live checks skipped, release build and scratch signed app. Strict signature verification passed. After documentation-only remediation, focused documentation checks and `git diff --check` passed. Closure accepted the existing build/test evidence. G2 later passed five items by Aidan's report. The remaining items follow whole-feature review by his explicit decision, so WS6 is accepted with this commit. Focused documentation consistency, local links and `git diff --check` passed for the gate relocation; no passed code checks were repeated.

## Closure review

This review preceded Aidan's decision to move the remaining G2 checks after whole-feature review. Its findings and verification evidence remain valid.

- Verdict: Passed focused closure. R1 and R2 are resolved, and their documentation fixes introduce no release-blocking defect. G2 remains Aidan's pending external gate before acceptance.
- Remaining required findings: none.
- Evidence:
  - R1: `docs/decisions/0025-provider-adapters.md:133-136` keeps the SDK and `swift test` evidence and explicitly leaves signed-build dictation and permission prompt behaviour for G2. This agrees with the pending gate in this packet and `plan.md`, and with the handoff's limit on runtime evidence.
  - R2: `docs/decisions/0025-provider-adapters.md:131` groups implementation packets 01 through 06 and `plan.md`, explains their role and marks them outside the shared contract. Comparing `git diff e943484911c71384bf2d75fb4f7f13e68ff6f823 --name-only` with that row confirms all seven changed workflow records are covered once.
- Checks: focused documentation assertions and `git diff --check` passed. The independent review records all five packet commands passing before these documentation fixes; `/tmp/echotype-ws6-independent-tests.log` confirms 126 core tests and 71 app tests passed. That evidence is sufficient for these fixes, so builds and tests were not repeated. No live service check, app launch, process stop or installation command ran. O1 remains deferred.
