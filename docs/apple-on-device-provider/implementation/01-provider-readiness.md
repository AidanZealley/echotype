# Workstream 1: Gate operations on provider readiness

Status: accepted.

## Task packet

### Outcome

A provider can declare readiness. Dictation, Test, reading and MCP speech start only when the services they use are ready. Otherwise they show the provider's reason: in a new amber or neutral pill when waiting, or in the existing red error pill when unavailable. The Provider tab shows the reason beside a supported service that is not ready, and Settings refreshes when the provider reports a change. xAI declares no readiness and behaves exactly as before.

Specification: [Readiness](../../specs/apple-on-device-provider.md#readiness) and [Goal and scope](../../specs/apple-on-device-provider.md#goal-and-scope).

### Scope

- Add the readiness types to `Provider.swift` as the plan's cross-workstream contract describes. `Provider.init` gains `readiness` defaulting to nil.
- `DictationOperation` checks readiness after the credential check and before opening capture: transcription and cleanup for dictation, transcription for Test. A blocked operation opens no capture and no transcriber.
- `Reader` checks voice readiness before requesting speech. MCP speech reaches the same `Reader`, so it inherits the check.
- `DictationController` holds the selected provider's latest `ServiceReadiness` for Settings. It re-checks when:
  - the provider, language or the selected provider's voice changes,
  - the app launches,
  - the app becomes active,
  - the provider's `changes` stream yields.
  
  It follows the selected provider's stream and drops the previous one on a switch.
- Word readiness failures with the provider's reason string. `.waiting` ends the pill in a new `Pill.Phase.waiting(String)`, styled amber or neutral with theme-aware colours, which fades like `.error`. `.unavailable` uses `.error`.
- Add the waiting and error pills to `PillDemo` so `--hud-demo` shows them.
- In the Provider tab, show the reason beside a supported feature whose service is not ready. Missing cleanup keeps its grey mark.
- Add an amber or neutral menu-bar or status treatment only if the existing `lastError` path needs it for consistency. Suggestion, not required.

### Non-goals

- Apple code, the language picker and any change to `Providers/XAI/`.
- Numeric progress, a shared download manager, retry machinery, or dictating without cleanup when cleanup is not ready.
- Changes to `SessionMachine` or `Reviser`.

### Initial ownership

- `Sources/EchoTypeCore/Providers/Provider.swift`
- `Sources/EchoTypeApp/DictationOperation.swift`, `Reader.swift`, `DictationController.swift`, `App.swift`
- `Sources/EchoTypeApp/Views/Pill.swift`, `PillView.swift`, `PillDemo.swift`, and the Provider tab in `SettingsView.swift`
- Tests under `Tests/EchoTypeAppTests/` and `Tests/EchoTypeCoreTests/`, new or existing
- `docs/decisions/0025-provider-adapters.md`, only to describe the readiness contract in its Decision and Service responsibilities sections. Workstream 6 writes the extensibility report.

### Required seams

- Produces the readiness contract for workstreams 3–6. Record its final Swift shape in the handoff Decisions field.
- Produces `Pill.Phase.waiting(String)` and its styling for later readiness messages.

### Acceptance criteria

- With a fake provider whose transcription or cleanup is `.waiting`, dictation does not start capture or a transcriber and ends with the waiting pill showing the reason. With `.unavailable`, it ends with the red pill.
- Test blocks on transcription readiness only. Reading blocks on voice readiness only.
- A provider with nil readiness starts exactly as before; existing xAI and operation tests pass unchanged.
- The controller's readiness refreshes after the fake provider's `changes` yields. A focused test covers this where it is testable without AppKit.
- The Provider tab shows the reason beside a not-ready supported feature.
- Gate G1 passes.

### Targeted verification

```bash
swift build
swift test --disable-xctest --filter 'DictationOperationTests|ReadingOperationTests|ProviderWordingTests|MCPDeliveryTests|SpeechAdmissionTests'
swift test --disable-xctest
git diff --check
```

Add the suites you create to the filtered run. The full `swift test --disable-xctest` run is required here because this changes the shared contract.

## External validation

- Gate and placement: G1 waiting pill look, after closure and before acceptance.
- Status: `Passed`
- Candidate and instructions: Aidan runs `./scripts/run.sh --hud-demo` from the repository root, then views the waiting and error pills in dark and light appearance. This relaunches the development bundle. Candidate: the uncommitted workstream 1 tree on `feature/apple-on-device-provider` at base `e943484`. The demo now shows, after the existing dictation steps: a dictation waiting pill ("Not ready", amber hourglass, reason "Downloading speech model" in primary text), a dictation error pill ("Cleanup is not supported on this Mac" in red), then after the reading steps a reading waiting pill ("Downloading voice") before the existing "Nothing selected" error. Each holds three seconds.
- Required evidence: Aidan's approval, or corrections to apply.
- Attempts and lasting decisions: one candidate. Aidan approved the waiting and error pills as is in dark and light appearance (2026-10-02). No corrections.
- Resume condition: met.

## Implementation handoff

- Base commit: `e943484911c71384bf2d75fb4f7f13e68ff6f823`
- Outcome: Readiness is part of the provider contract. Dictation and Test check it before opening capture, reading before requesting speech; a blocked operation ends in the new amber waiting pill (`.waiting`) or the red error pill (`.unavailable`) with the provider's reason. The controller follows the selected provider's readiness for the Provider tab, which shows a not-ready service's reason beside its mark. xAI declares none and is unchanged.
- Files changed:
  - `Sources/EchoTypeCore/Providers/Provider.swift`: `Provider.readiness`, `Readiness`, `ReadinessRequest`, `ServiceReadiness`, `ServiceState`.
  - `Sources/EchoTypeApp/DictationOperation.swift`: `Dependencies.readiness`, `checkReadiness()`, and the app-internal `NotReady` error with `ServiceState.reason` and `requireReady()`.
  - `Sources/EchoTypeApp/Reader.swift`: `Dependencies.readiness`, checked after the credential and before `speak`.
  - `Sources/EchoTypeApp/DictationController.swift`: `readiness` property, `followReadiness(of:)`, refresh triggers, operation wiring, waiting pill ending, `NotReady` wording.
  - `Sources/EchoTypeApp/Views/Pill.swift`, `PillView.swift`, `PillDemo.swift`: `Pill.Phase.waiting(String)`, its styling and demo steps.
  - `Sources/EchoTypeApp/Views/SettingsView.swift`: Provider tab reasons.
  - `docs/decisions/0025-provider-adapters.md`: readiness in Decision and Service responsibilities.
  - Tests: `DictationOperationTests.swift`, `ReadingOperationTests.swift`, `ProviderWordingTests.swift`, new `Tests/EchoTypeAppTests/ProviderReadinessTests.swift`.
- Decisions:
  - Final contract shape, in `Provider.swift` (all public, with public memberwise-style inits):
    ```swift
    public struct Provider { …; public var readiness: Readiness? }
    // init(id:name:summary:credential:transcription:voice:cleanup:readiness: Readiness? = nil)
    public struct Readiness: Sendable {
      public var check: @Sendable (ReadinessRequest) async -> ServiceReadiness
      public var changes: @Sendable () -> AsyncStream<Void>
      public init(check:changes:)
    }
    public struct ReadinessRequest: Equatable, Sendable {
      public var language: String   // Settings.language, unresolved
      public var voice: String      // settings.readingChoice(for: provider.voice).voice
      public init(language:voice:)
      public init(settings: Settings, voice: VoiceService)
    }
    public struct ServiceReadiness: Equatable, Sendable {
      public var transcription: ServiceState
      public var voice: ServiceState
      public var cleanup: ServiceState?   // nil when the provider has no cleanup
      public init(transcription:voice:cleanup:)
    }
    public enum ServiceState: Equatable, Sendable { case ready, waiting(String), unavailable(String) }
    ```
  - The app calls `changes()` once per follow, before the first `check`, and iterates it until the selection changes or the app becomes active; cancelling the follower ends iteration, so the stream's `onTermination` fires. Adapters should create a fresh stream per call.
  - When `check` runs: on every operation start (dictation, Test, reading, MCP speech), and from the controller at launch, on a change of provider, language or the selected provider's voice, on app activation, and on each `changes` yield. Calls may overlap (an operation check during a follower check), so adapters must tolerate concurrent `check` calls.
  - Operations receive readiness as an optional closure (`Dependencies.readiness`, default nil), built by `DictationController.readinessCheck(_:_:)` from the settings snapshot. Nil readiness adds no await, so xAI startup is exactly as before.
  - Blocked operations fail with app-internal `NotReady(state:)`; `DictationController.describe` returns the provider's reason unchanged. `end(showing:waiting:)` picks `.waiting` for `NotReady(.waiting)`, `.error` otherwise. `lastError` (menu bar status line) carries the reason for both; no separate amber menu-bar treatment.
  - The waiting pill: title "Not ready", amber `hourglass` (`Color.orange`, theme-aware) in place of the level meter, reason in `.primary`, no glow, fades after three seconds like `.error`. Red error styling is unchanged.
  - G1 (escalation E1): Aidan approved this waiting pill and the unchanged error pill as is in both themes (2026-10-02). Later readiness messages reuse `Pill.Phase.waiting(String)` without restyling.
  - `showReading` no longer shows a reader's raw `.failed` description; the worded failure from `end(showing:waiting:)` replaces it a moment later anyway, and leaving it would flash red before an amber waiting pill.
  - Provider tab: reason as a caption beside the mark, secondary for waiting and red for unavailable, matching the Permissions row. The mark itself is unchanged; unsupported cleanup has nil state and so no reason.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'DictationOperationTests|ReadingOperationTests|ProviderWordingTests|MCPDeliveryTests|SpeechAdmissionTests|ProviderReadinessTests'`: 53 tests in 6 suites.
  - `swift test --disable-xctest`: 107 core tests and 71 app tests.
  - `git diff --check`
  - Existing operation, reading and xAI test assertions are unchanged; the dictation and reading fixtures gained only a `readiness` field.
- Known limitations or external checks:
  - Gate G1 passed (see External validation). `./scripts/run.sh --hud-demo` cycles dictation waiting ("Downloading speech model"), dictation error ("Cleanup is not supported on this Mac") and reading waiting ("Downloading voice") pills before the existing reading error.
  - The controller's Observations and app-activation triggers use the static registry and AppKit, so they are not unit-tested; `followReadiness(of:)` (check, re-check on `changes`, drop on switch) is.
  - The Test button stays enabled when transcription is not ready; Test then reports the reason in red under the button, as other Test failures do.
- Specification drift: in `DictationOperation`, readiness is checked after the "Starting" pill appears and before capture opens, which is before the credential check, because the credential is read after capture opens and moving it would change xAI startup. Not observable for any planned provider (xAI has no readiness; Apple has no credential). `Reader` checks after the credential as specified.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5.5), against base `e943484` plus the uncommitted diff.
- Verdict: **Pass, no Required findings.** Every code acceptance criterion is met; G1 remains Aidan's. Verification rerun by the reviewer, all passing: `swift build`; the filtered run with `ProviderReadinessTests` added (53 tests in 6 suites); `swift test --disable-xctest` (107 core, 71 app); `git diff --check`. Existing operation, reading and xAI assertions are unchanged; the only edited existing lines are the fixtures' new `readiness:` argument (`DictationOperationTests.swift:236`, `ReadingOperationTests.swift:77`). Containment holds: no change to `Providers/XAI/`, `SessionMachine` or `Reviser`, and no provider-specific branch or wording in shared code. Reason strings in `PillDemo.swift:58-77` are demo data only.
- Drift assessment (readiness before the credential in `DictationOperation`): **accept.** The spec's order (credential, then readiness, then capture) cannot hold on the base code, where the key is read only after capture opens (`DictationOperation.swift:181-185`). Satisfying it literally would mean opening capture before readiness, which breaks the acceptance criterion that a blocked dictation opens nothing, or moving the key read ahead of capture, which changes xAI startup. Checking at `DictationOperation.swift:180`, after `.starting` is published and before `startCapture`, keeps "opens nothing" and leaves xAI unchanged. The only observable difference, a not-ready reason taking precedence over the missing-key message, needs a provider with both a credential and readiness, and no planned provider has both. Escape during the check is still handled: `cancel()` publishes `.cancelled` at once and `checkStartup()` after the await (`DictationOperation.swift:200-203`) stops startup without reporting a failure. ADR 0025 already gives the implemented order ("before opening capture"). The lead should record this in the plan's decision and drift log.
- Required findings: none.
- Optional observations:
  - **O1. State in the contract that setup must outlive the caller's task.** `followReadiness(of:)` cancels the follower on every switch and activation (`DictationController.swift:166-174`), so cancellation propagates into an in-flight `check`. The spec says one installation "may complete after switching providers", and both the doc comment at `Provider.swift:87-88` and the handoff's Decisions say only "calling again is cheap". Add one line, in the doc comment or the handoff's contract notes for workstreams 3-5: `check` returns the current state without awaiting setup, and setup runs in a task the adapter owns rather than the caller's.
  - **O2. Provider tab clears its reasons on every app activation.** `followReadiness` sets `readiness = nil` (`DictationController.swift:168`) even when it re-follows the same provider from the `didBecomeActive` observer (`:153-158`). Opening Settings therefore briefly removes any shown reason until the new check answers. Separately, on a provider switch the nil assignment arrives one `Observations` turn after the selection changes, so a single render can show the old provider's reasons beside the new provider's marks. A smaller version: keep the previous answer when the provider id is unchanged, and clear it only on a switch. This is cosmetic, but G1 or Aidan may notice it.
  - **O3. The dictation pill ending is untested at controller level.** `blockedDictation` (`DictationOperationTests.swift:422`) asserts `NotReady` and that nothing opened, but the "ends with the waiting pill" criterion for dictation relies on the one-line call site at `DictationController.swift:408`. Only the reading path is asserted at controller level (`ReadingOperationTests.swift:355`). The shared `end(showing:waiting:)` and `isWaiting` are covered, so the risk is low. Add a test only if a controller dictation fixture is cheap (`SpeechAdmissionTests` has one).
  - **O4. Small consistency nits.** `Reader.Dependencies.readiness` is not `@Sendable` while `DictationOperation`'s is (`Reader.swift:21` vs `DictationOperation.swift:73`). `state == .unavailable(reason)` in `SettingsView.swift:264` reads more directly as `if case .unavailable = state`. `ServiceState.reason` and `requireReady()` live in `DictationOperation.swift` but are used by `Reader`, the controller and Settings. Fine to leave.
- Questions:
  - **Q1. Should an operation's readiness answer refresh the Settings copy?** The spec's Refresh list includes "operation start" (`docs/specs/apple-on-device-provider.md:73-78`). Operations do call `check` and so start setup, but their answer never reaches `controller.readiness` (`DictationController.swift:185-191`). Settings then depends on the adapter yielding `changes` whenever an operation's check changes its state, for example retrying a failed setup and moving from `unavailable` to `waiting`. Recommendation: keep the code as is, and add to the contract notes for workstreams 3-5 that adapters yield `changes` whenever a check starts, finishes or fails setup. Feeding operation answers into the controller would couple operations to Settings state for little gain.

## Resolution

- Finding dispositions:
  - No Required findings, so no remediation pass.
  - Drift (readiness before the credential in `DictationOperation`): accepted and logged in the plan. The key is read after capture opens, so the specified order would either open capture for a blocked dictation or change xAI startup. No planned provider has both a credential and readiness.
  - O1 (setup must outlive the caller's cancelled `check`) and Q1 (operation answers do not reach Settings): accepted as adapter obligations for workstreams 3-5, recorded in the plan's conventions learned. No code change, because the packet's controller triggers omit operation start, and an operation's `check` already starts setup.
  - O2 (Provider tab clears reasons on app activation, one stale render on a switch): deferred. Cosmetic, and a fix belongs with the first real readiness provider if Aidan notices it.
  - O3 (no controller-level test for the dictation waiting pill): deferred. The shared ending path is covered through reading.
  - O4 (nits): deferred.
- Simplification/deletion pass: done by the implementation agent; no further deletions found in review or closure.
- External validation: G1 passed; Aidan approved both pills as is in both themes, so there were no corrections to review.
- Final verification at acceptance, rerun by the resuming lead on the approved tree, all passing: `swift build`; the filtered run with `ProviderReadinessTests` added (53 tests); `swift test --disable-xctest` (107 core, 71 app); `git diff --check`.
- Closure verification: closure reran every targeted command on the current tree, all passing: `swift build`; the filtered run with `ProviderReadinessTests` added (53 tests); `swift test --disable-xctest` (107 core, 71 app); `git diff --check`.

## Closure review

- Reviewer: fresh closure agent (Claude Opus 5.5), focused closure against base `e943484` plus the current uncommitted tree.
- Verdict: **Pass.** The independent review raised no Required findings and the lead accepted none, so there were no fixes to verify. Targeted verification rerun on the current tree, all passing: `swift build`; the filtered run with `ProviderReadinessTests` added (53 tests in 6 suites); `swift test --disable-xctest` (107 core tests in 11 suites, 71 app tests in 10 suites); `git diff --check`.
- Drift (readiness before the credential in `DictationOperation`): no release-blocking defect. `checkReadiness()` runs after `.starting` is published and before `startCapture` (`DictationOperation.swift:180`). It re-checks cancellation after the await, so Escape during the check ends as cancelled, not as a failure. A not-ready result throws before capture or a transcriber opens. `run()` handles it like any other early startup failure: the shared release path runs, and `end(showing:waiting:)` shows the reason. xAI has nil readiness, so its startup is unchanged (no extra await) and its credential check still runs after capture opens, as before. The only observable change, a not-ready reason taking precedence over the missing-key message, needs a provider with both a credential and readiness. No planned provider has both.
- Remaining required findings: none. Optional observations O1–O4 and question Q1 stay as the independent review recorded them. G1 is still pending Aidan.
