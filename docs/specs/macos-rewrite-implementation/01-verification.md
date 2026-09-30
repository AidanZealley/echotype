# Workstream 1: Establish Mac verification

Status: Accepted. Implementation, independent review, one remediation pass and closure are complete. G1 passed with Aidan's explicit Actions deferral.

## Task packet

### Outcome

The unchanged app has deterministic tests that run on the local Mac and a macOS CI workflow. Later workstreams can test app-layer ownership without launching the application or touching real permissions.

### Scope and non-goals

Add GitHub Actions for pull requests and main-branch pushes: pinned installed Xcode on macOS 26, logged toolchain versions, deterministic tests with coverage and unsigned release executable build. Disable live xAI tests explicitly. Use the current runner inventory when selecting installed Xcode. Keep packaging and signing outside CI.

Fix scheduler-based synchronization in existing STT/reviser tests. A request-start acknowledgement must not masquerade as result-processing completion. Add async time limits and teardown for fake continuations. Preserve meaningful protocol fixtures and settings storage fixtures.

Establish `EchoTypeAppTests` against the executable target if SwiftPM supports it on the actual toolchain. Include meaningful tests of the macOS modifier-flags adapter, including ignored flags, without creating the hotkey monitor. Demonstrate that importing the app does not run its entry point. Change the production target structure only for a demonstrated import/build constraint, with rationale and no facade exports.

Do not fix production lifecycle defects, add end-to-end UI automation, mock every macOS API, fetch a real API key or run paid live tests.

### Initial ownership

- `Package.swift`, `.github/workflows/ci.yml` and `Tests/EchoTypeAppTests/HotkeyAdapterTests.swift`.
- Existing async test synchronization in `Tests/EchoTypeCoreTests/STTClientTests.swift`, `ReviserTests.swift`, `SessionMachineTests.swift`, `STTFixtures.swift` and `Support/`.
- README development/test instructions where actual commands change.
- This record, row 1/G1 in the plan and associated escalation entries.

### Required seams

Later packets may add suites to the app test target. Keep test dependencies minimal and avoid signed-app startup, real Keychain access, microphone access or real clipboard writes in the default suite. Record the exact working import/test layout in the handoff. Preserve the existing fake-transport and clock semantics unless a defect requires their correction.

### Acceptance criteria

- `swift test` runs all deterministic tests on the Mac with live tests disabled; no synchronization relies on a fixed number of yields or sleeps.
- The app test target protects real modifier mapping behavior and does not initialise services.
- The CI definition compiles both test targets and the release executable without a signing certificate.
- A passing real Actions run is recorded, or Aidan explicitly approves deferring CI execution. Otherwise record a concrete gate, request branch publication/run or a deferral decision, and keep row 1 Blocked. Never call an unrun workflow verified.
- The repository-setting step for required checks is recorded separately from installing the workflow. Its unavailable configuration does not force unrelated local work to stop.
- G1 has actual Mac toolchain and local results. Tests added only to assert that a deleted feature stays deleted are removed.

### Targeted verification

Run from repository root on the Mac:

```sh
xcodebuild -version
swift --version
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage
swift build -c release --product EchoTypeApp
git diff --check
```

This first baseline runs the complete suite once. Re-run affected suites after changes, using `swift test list` to confirm filters select tests. Inspect the workflow's successful Actions job when available; validate the selected Xcode path against its image. Record results rather than whole logs.

## Implementation handoff

- Base commit: `2e17817246749f626ce36c90823dee2b4ef0d5fb`, branch `refactor/macos-lifecycle`. This is the first packet, so there are no dependency handoffs.
- Outcome: Added the macOS CI definition and an executable-target test suite. Reviser and STT ordering tests now wait for observable progress instead of scheduler guesses. Production source files remain unchanged.
- Files changed: `Package.swift`, `.github/workflows/ci.yml`, `README.md`, `Tests/EchoTypeAppTests/HotkeyAdapterTests.swift`, core `STTClientTests.swift`, `ReviserTests.swift`, `STTFixtures.swift`, `SessionMachineTests.swift`, `Support/ScriptedTransport.swift`, `Support/SnapshotLog.swift`, and this handoff. The lead owns the separate plan changes.
- Decisions and app-test layout:
  - `EchoTypeAppTests` depends directly on `EchoTypeApp`; tests use `@testable import EchoTypeApp` and import `EchoTypeCore` for its settings value. SwiftPM supports this layout on the actual toolchain. Its debug build description passes `-entry-point-function-name EchoTypeApp_main`, so the test executable can link the app without executing `main.swift`. Both adapter tests passed, including `NSApp == nil`. They construct no monitor or app services. No production target split or facade was needed.
  - STT test-only actor methods use `Task.immediate`, available in Swift 6.2, to enqueue work on the client's actor before returning its task. The test releases the blocked first send only after this acknowledgement. The transport still records completed frame order.
  - Reviser tests await accepted updates, the next queued request, or `finish`. A next request proves the preceding rejected reply has been processed; a request-start signal alone proves no such thing. Rejected final attempts are checked after `finish`; failed-attempt recording is checked in the final-fallback test.
  - STT and reviser suites have one-minute limits. Stream-based gates replace suspended fake checked continuations and respond to cancellation. Teardown closes the gates and transport; session tests cancel their running tasks and close transport. The remaining scripted-transport and snapshot waiters release on cancellation. Existing clock, protocol fixture and settings-storage fixture behavior stays intact.
  - R1 remediation makes reviser fake closure permanent by checking the input stream's yield result before creating a response stream. `close` synchronously finishes that input stream, so every later request throws `CancellationError`; its existing cancellation task releases the current response. The stream already holds the closed state, so no extra flag or synchronization helper was needed.
  - The simplification pass removed the request-start waiter and yield loops, the fake sixty-second sleep, redundant release state and a duplicate final-request closure. No generic test framework or production seam was added.
  - CI selects `/Applications/Xcode_26.6.app/Contents/Developer` on `macos-26`. The [official macOS 26 arm64 inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), checked 2026-09-30, lists Xcode 26.6, build 17F113, at that path in image `20260907.0351.1`. The job logs versions, clears both live-test environment variables, runs coverage tests and builds the unsigned release executable. Packaging and signing remain separate.
- Verification:
  - Local Mac reports macOS 27.2, build `26B5091g`; `xcodebuild -version` reports Xcode 27.0, build `27A266a`; `swift --version` reports Apple Swift 6.4 targeting `arm64-apple-macosx27.2.0`.
  - The complete initial baseline, `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage`, exited 0 and reported 69 tests. Both live integration tests were explicitly skipped.
  - `swift test list` confirmed the four affected suite filters select 35 tests. The affected-suite coverage run exited 0 with 33 core tests and two app tests passing. After removing redundant fake release state, the seven STT tests passed again.
  - Coverage files exist at `.build/out/Products/Debug/codecov/EchoType.json` and `default.profdata`. `swift build -c release --product EchoTypeApp` exited 0. Workflow YAML parsed with Ruby's YAML library, and `git diff --check` passed.
  - After R1 remediation, `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list | rg ReviserTests` confirmed the ten retained reviser tests. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage --filter ReviserTests` exited 0 with all ten passing. A temporary teardown probe also passed: close released the blocked current request, two subsequent requests threw `CancellationError`, and the input stream ended. The probe was removed after checking this test-only failure path.
- Known limitations or external checks: No Actions job has run. Aidan approved deferring Actions on 2026-09-30 through E1-CI, allowing local acceptance and dependent work to continue. CI remains unverified; this answer does not authorise publication or a PR. Making `macOS tests and release build` a required check is a separate repository-setting task and has not been done. Local verification used Swift 6.4 on macOS 27.2; the selected CI Xcode and macOS 26 remain unverified until Actions runs. No signed app was launched, permissions changed, installed app touched, real API key read or billed request made.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent lead subagent, 2026-09-30. Applied the `unslop` skill to this record.
- Reviewed base: `2e17817246749f626ce36c90823dee2b4ef0d5fb`. Inspected the complete owned diff, including untracked CI and app tests, and surrounding STT, session, reviser, adapter and entry-point code. No dependency handoffs precede this packet.
- Verdict: Required finding R1 blocks code acceptance. The CI execution gate remains pending separately.
- Required findings:
  - R1: Reviser fake teardown can start another blocked request after closing. `RevisionGate.close` finishes the input stream and schedules cancellation of only the current response, but `request` never checks a closed state. In `revisionSingleFlight` and `revisionFallback`, a timeout while the first response is blocked can run the deferred close with a newer committed window already pending. The unstructured Reviser drain receives `CancellationError`, processes it as a failed reply and starts that next window. It creates a fresh response stream after close, with nobody left to answer or finish it. Evidence is `Tests/EchoTypeCoreTests/ReviserTests.swift:181-187` and `:201-208`, plus `Reviser.drain` and `Reviser.revise`. A temporary standalone probe used the actual production Reviser and the copied gate with an observation stream added. It submitted `One.`, observed its blocked request, submitted `One. Two.`, called `close`, and observed `Request started after teardown: One. Two.`. This violates the packet's teardown requirement. Make fake closure persistent so current and later requests terminate, or otherwise guarantee the reviser is stopped during every exit. Keep the change in test code.
- Optional observations: none.
- Questions: none.
- Positive evidence and checks:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage --filter 'STTClientTests|ReviserTests|SessionMachineTests|HotkeyAdapterTests'` exited 0. All 33 selected core tests and both app tests passed. `git diff --check` passed. Local versions independently confirmed Xcode 27.0, build `27A266a`, and Apple Swift 6.4 on arm64 macOS 27.2. Only that Xcode is installed, so I did not claim a local build with the CI toolchain.
  - The [current official macOS 26 arm64 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), read 2026-09-30, lists image `20260907.0351.1` and Xcode 26.6 at `/Applications/Xcode_26.6.app`, build `17F113`. The explicit CI selection matches it. PR and main pushes, logged versions, empty live-test variables, coverage and unsigned executable build match the packet. Packaging and signing remain outside CI. Required-check configuration is documented separately.
  - [SE-0472](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md) records `Task.immediate` as implemented in Swift 6.2. It runs on the inherited actor until an actual suspension. Both test helpers execute on the STTClient actor and set `lastSend` before waiting for its task, so returning the helper's task proves queue registration before releasing the blocked send. This is a real acknowledgement, without yield counts or sleeps.
  - Reviser rejected-window checks wait for the next request, which requires the preceding reply to pass through `revise`. Accepted-result checks wait for updates; final-attempt checks await `finish`. Request start is used only to coordinate a deliberately blocked request. Scripted frame acknowledgement follows the session's return to the next receive, and its checked waiters now release on cancellation and close.
  - App tests exercise every chord modifier and ignored flags through the actual adapter. The successful `NSApp == nil` assertion and unchanged production targets demonstrate import without app entry-point execution or service construction. No production sources, protocol fixtures or settings-storage fixtures changed. The diff removes obsolete waiters and scheduler guesses without a facade or generic test framework.
- Limits: No Actions run, publication, app launch, permission interaction, real-key access or billed request was performed. G1 remains for the lead after closure.

## Resolution

- Finding dispositions: Required R1 accepted. `RevisionGate.close()` only releases the current response; its asynchronous teardown allows a queued Reviser window to create another suspended request. Keep closure permanent in the fake and reject post-close requests. This meets the packet teardown criterion without changing production behavior. One remediation pass authorised.
- Simplification/deletion pass: Used the input stream's existing permanent termination state instead of adding a closed flag, lock, wrapper or production seam. Moved input publication ahead of response-stream creation so post-close requests allocate no waiting response. Removed the temporary fake-only probe after validation; retained meaningful product tests unchanged.
- Final verification: Remediation's ten ReviserTests passed with coverage and live-test variables empty. The filter was confirmed with `swift test list`. The temporary teardown probe passed before removal, and `git diff --check` passed. Fresh closure passed with no remaining required findings. The lead independently reconfirmed Xcode 27.0, Swift 6.4 and macOS 27.2, reran the unsigned release build successfully after closure, audited file ownership against the recorded base and passed `git diff --check`. Aidan approved deferring Actions on 2026-09-30, satisfying G1 while CI remains unverified.

## Closure review

- Reviewer: fresh closure subagent, 2026-09-30. Applied the `unslop` skill. Read the workflow, approved specification, packet, accepted R1 and resolution; reviewed only the fix and its affected cleanup path.
- Verdict: R1 resolved. Code closure passes; G1 remains pending separately.
- Remaining required findings: none. No release-blocking defect introduced by the fix was found.
- Evidence: `inputPublisher.finish()` permanently terminates request publication. A later `yield` returns `.terminated`, so `request` throws before allocating a response stream. For a request accepted just before close, the actor creates and stores its response without suspending between publication and registration. The cleanup task must enter the same actor, so it cannot miss that response. A queued production drain request is rejected after the first response is released.
- Checks: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list | rg ReviserTests` confirmed the ten retained tests. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage --filter ReviserTests` exited 0 with all ten passing. An independent temporary standalone probe compiled the actual production Reviser and an unchanged copy of the gate. It verified requests after an initial close throw `CancellationError`, close releases an active blocked response, and the queued `One. Two.` production request also throws after teardown. The input stream ended and `finish` returned the available text. The probe used observable stream events, no sleeps or yield counts, and was removed. `git diff --check` passed.
- Limits: No broader review, implementation change, Actions run, publication, app launch, permission interaction, real-key access or billed request. G1 remains the lead's external gate before acceptance.

## External validation

- Gate and placement: G1, after closure before acceptance.
- Status: Passed. Local evidence passes. Aidan explicitly approved deferring Actions execution on 2026-09-30 in E1-CI; CI remains unverified.
- Candidate: Uncommitted workstream 1 on `refactor/macos-lifecycle`, base `2e17817246749f626ce36c90823dee2b4ef0d5fb`. Includes deterministic STT/reviser/session teardown changes, executable-target adapter tests, README commands and `.github/workflows/ci.yml`. No production sources changed. The acceptance commit includes the authorised initial orchestration fields and lasting CI deferral decision in `plan.md`.
- Local evidence: macOS 27.2, build `26B5091g`; Xcode 27.0, build `27A266a`; Apple Swift 6.4. Complete baseline passed with live variables empty, 69 tests reported and both live tests skipped. All 35 affected tests passed in independent review; ten reviser tests passed after remediation and again in fresh closure. Lead's post-closure unsigned release executable build exited 0, as did `git diff --check`. Existing coverage artifacts are recorded in the handoff.
- CI evidence: Workflow defines PR and main-push checks with the inventoried Xcode 26.6 path on macOS 26. No Actions run exists for this uncommitted candidate; YAML inspection and local success do not verify the selected hosted toolchain.
- CI follow-up: When branch publication is separately authorised, trigger `CI / macOS tests and release build`. Record the successful run URL, logged Xcode 26.6/Swift version, both deterministic targets passing with live tests disabled and successful release build. The approved deferral does not authorise publication or a PR.
- Required-check configuration: Not configured by this workstream. Separately, Aidan or an authorised repository administrator should require `macOS tests and release build` in the main-branch rules after it has run. This settings step does not block later local implementation after an explicit Actions deferral.
- Attempts and lasting decisions: No live key access, billed requests, signed-app launch, permission changes, installed-app writes or branch publication. One remediation pass used for Required R1; fresh closure passed. No specification drift. Recovery audited the complete owned diff and confirmed the recorded base, implementation, independent review, single remediation pass and fresh closure. Those phases were preserved without another remediation pass. The frozen Task packet is unchanged. E1-CI is resolved into this handoff and the plan decision log.
- Recovery verification: Reconfirmed macOS 27.2, Xcode 27.0 and Swift 6.4. `swift test list` confirmed the affected filters; the recovery coverage run passed all 33 core tests and two app-adapter tests with both live variables empty. The unsigned release build and `git diff --check` passed. No implementation changes were needed.
- Acceptance: Local results and recorded closure remain valid. Aidan's explicit Actions deferral satisfies the remaining G1 condition. Required-check configuration remains a separate administrator follow-up; CI must be reported as unverified until a real run passes.
