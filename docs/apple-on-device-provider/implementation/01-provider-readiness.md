# Workstream 1: Gate operations on provider readiness

Status: not started.

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
- Status: `Pending`
- Candidate and instructions: Aidan runs `./scripts/run.sh --hud-demo` from the repository root, then views the waiting and error pills in dark and light appearance. This relaunches the development bundle.
- Required evidence: Aidan's approval, or corrections to apply.
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan approves both pills in both themes.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`
