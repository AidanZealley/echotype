# Workstream 1: Establish Mac verification

Status: not started.

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

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Decisions and app-test layout: TBD
- Verification: TBD
- Known limitations or external checks: TBD
- Specification drift: TBD

## Independent review

- Reviewer: TBD, lead subagent
- Verdict: TBD
- Required findings: TBD
- Optional observations: TBD
- Questions: TBD

## Resolution

- Finding dispositions: TBD
- Simplification/deletion pass: TBD
- Final verification: TBD

## Closure review

- Verdict: TBD
- Remaining required findings: TBD

## External validation

- Gate and placement: G1, after closure before acceptance
- Status: Pending
- Candidate and instructions: Record actual Mac toolchain, local results, CI candidate and any user action needed to trigger Actions
- Required evidence: Passing deterministic suite and release build on Mac; accurate Actions and required-check configuration status
- Attempts and lasting decisions: TBD
- Resume condition: Mac tests/build pass and Actions passes or Aidan explicitly approves deferring CI execution; configuration follow-up recorded explicitly
