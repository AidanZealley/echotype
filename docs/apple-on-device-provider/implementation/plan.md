# Apple on-device provider implementation plan

Status: in progress; workstream 1 accepted.

## Orchestration record

- Integration branch: `feature/apple-on-device-provider`
- Starting commit: `e943484911c71384bf2d75fb4f7f13e68ff6f823`
- Review command: `lead subagents`
- Specification approved at commit: `e943484911c71384bf2d75fb4f7f13e68ff6f823`
- Started: `2026-10-02`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Provider readiness](01-provider-readiness.md) | Approved spec | Accepted |
| 2 | [Language picker](02-language-picker.md) | 1 | Not started |
| 3 | [Apple transcription](03-apple-transcription.md) | 1, 2 | Not started |
| 4 | [Apple read aloud](04-apple-read-aloud.md) | 3 | Not started |
| 5 | [Apple cleanup](05-apple-cleanup.md) | 3 | Not started |
| 6 | [Register Apple and verify on the Mac](06-register-apple.md) | 4, 5 | Not started |
| Final | [Whole-feature review](final-review.md) | 1-6 | Not started |

Run strictly in this order, one workstream at a time.

## Why these boundaries

- **1 Provider readiness** is the only new shared contract. It lands first, with fake services, so every Apple adapter targets a settled contract and xAI is shown to be unchanged before Apple exists. It includes the amber pill and Provider tab reasons because the contract has no other consumer.
- **2 Language picker** is an independent shared settings change. It comes before the Apple adapters so their language resolution starts from the picker's fixed tags. It follows 1 because both edit `SettingsView.swift`.
- **3–5 Apple adapters** are one service each, with that service's readiness check. Each is reviewable on its own with fixture tests and opt-in live checks. None is registered, so no intermediate state shows a half-built provider. 3 goes first because it owns the shared Apple pieces: the namespace, language resolution and the change signal.
- **6 Register Apple** composes the description and readiness, adds the registry line, settles permissions, deletes the spike, writes the documentation, and holds Aidan's signed-build verification. Those checks can only run once all three services are registered.

## Cross-workstream contracts

- **Readiness contract.** Workstream 1 implements the specification's [readiness](../../specs/apple-on-device-provider.md#readiness) shape in `Provider.swift`: `Provider.readiness: Readiness?`, `Readiness.check` and `Readiness.changes`, `ReadinessRequest(language:voice:)`, `ServiceReadiness` and `ServiceState` (`ready`, `waiting(String)`, `unavailable(String)`). `Provider.init` takes `readiness` with a default of nil, so `Provider.xAI` is unchanged. Workstream 1 may adjust signature details but must record the final form in its handoff. Later workstreams consume what it recorded.
- **Operation semantics.** An operation starts only when every service it uses is `.ready`: dictation uses transcription and cleanup, Test uses transcription, and reading and MCP speech use voice. `.waiting` blocks with the amber pill and `.unavailable` with the red pill. Provider adapters write every reason string.
- **Language.** `Settings.language` holds a tag from the picker's fixed list, currently only `en`. Each adapter resolves that tag to its own form. Apple maps bare `en` to `en-GB` for transcription and cleanup, and voice fallback chooses an installed voice for the language.
- **Apple namespace.** Apple code lives in `Sources/EchoTypeCore/Providers/Apple/`, internal to `EchoTypeCore` like `XAI`. Only `Provider.apple` is public, added in workstream 6. Workstream 3 creates the namespace, language resolution and the internal change signal that 4 and 5 reuse. Workstreams 3–5 each expose their service value plus an internal per-service readiness check. Workstream 6 composes these into `Provider.apple.readiness`.
- **Live checks.** Apple tests that touch real frameworks run only when `ECHOTYPE_APPLE_LIVE=1`. They skip before any service initialisation or asset request otherwise. Fixture tests run unconditionally.

## Ownership handoffs

- `SettingsView.swift`: 1 (Provider tab readiness reasons) → 2 (language row) → 6 (any permission row).
- `Provider.swift`: owned by 1. Later workstreams change it only through an escalation.
- `Providers/Apple/`: created by 3, extended by 4 and 5, composed by 6.
- `Providers.swift`, `Resources/Info.plist`, `Resources/EchoType.entitlements`, `README.md`, `docs/decisions/0025-provider-adapters.md`, `docs/research/apple-on-device-provider.md` and the spike folder: 6 only.
- `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/`: read-only reference for 3–5. Deleted by 6.

## Whole-feature acceptance

- Workstreams 1–6 accepted, including workstream 6's signed-build gate.
- `swift test` and the release build pass with live checks unset.
- The extensibility report accounts for every change outside `Providers/Apple/` and `Providers.swift`.
- Anything the final review corrects after Aidan's gate is listed for him to re-check in the completion report.

## External validation gates

| Gate | Owning workstream | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1 Waiting pill look | 1 | After closure, before acceptance | Passed | Workstream 1 accepted tree | Aidan approves the waiting and error pills in both themes, or his corrections are applied |
| G2 Signed-build verification | 6 | After closure, before acceptance | Pending | `TBD` | Aidan reports every verification item passing, with the speed range tuned |

## Escalations

None open.

## Conventions learned

- Readiness adapters (3-5): `check` returns the current state without awaiting setup. Run setup in a task the adapter owns, not the caller's, because the controller cancels its in-flight `check` on every provider switch and app activation, and an installation must be able to finish after a switch.
- Readiness adapters (3-5): yield `changes` whenever setup starts, finishes or fails, including setup started by an operation's own `check`. Settings learns of operation-triggered state only through `changes`; `changes()` is called once per follow and must return a fresh stream each call, and `check` may be called concurrently.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-02 | `DictationOperation` checks readiness after the Starting pill and before capture opens, which is before the credential check rather than after it. `Reader` follows the specified order. | The key is read only after capture opens, so the specified order would open capture for a blocked dictation or change xAI startup. Not observable for any planned provider: xAI has no readiness and Apple no credential. | Workstream 1 lead | 1, 6 |
| 2026-10-02 | Gate G1 passed: the waiting pill ("Not ready", amber hourglass, reason in primary text, no glow, three-second fade) and the unchanged error pill are approved in both themes. | Aidan approved as is. Later workstreams reuse `Pill.Phase.waiting(String)` for readiness messages without restyling. | Aidan | 1, 3-6 |
