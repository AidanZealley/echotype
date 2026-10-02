# Apple on-device provider implementation plan

Status: workstreams 1-6 and whole-feature review accepted. Eight G2 external checks remain pending.

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
| 2 | [Language picker](02-language-picker.md) | 1 | Accepted |
| 3 | [Apple transcription](03-apple-transcription.md) | 1, 2 | Accepted |
| 4 | [Apple read aloud](04-apple-read-aloud.md) | 3 | Accepted |
| 5 | [Apple cleanup](05-apple-cleanup.md) | 3 | Accepted |
| 6 | [Register Apple and verify on the Mac](06-register-apple.md) | 4, 5 | Accepted |
| Final | [Whole-feature review](final-review.md) | 1-6 | Accepted |
| External | [Remaining signed-build checks](#g2-end-checklist) | Final | Pending external checks |

Run strictly in this order, one workstream at a time.

## Why these boundaries

- **1 Provider readiness** is the only new shared contract. It lands first, with fake services, so every Apple adapter targets a settled contract and xAI is shown to be unchanged before Apple exists. It includes the amber pill and Provider tab reasons because the contract has no other consumer.
- **2 Language picker** is an independent shared settings change. It comes before the Apple adapters so their language resolution starts from the picker's fixed tags. It follows 1 because both edit `SettingsView.swift`.
- **3–5 Apple adapters** are one service each, with that service's readiness check. Each is reviewable on its own with fixture tests and opt-in live checks. None is registered, so no intermediate state shows a half-built provider. 3 goes first because it owns the shared Apple pieces: the namespace, language resolution and the change signal.
- **6 Register Apple** composes the description and readiness, adds the registry line, settles permissions, deletes the spike, writes the documentation, and records Aidan's signed-build verification. Those checks can only run once all three services are registered. Aidan moved the remaining checks after whole-feature review.

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

- Workstreams 1–6 and whole-feature review accepted. Remaining external checks do not block those acceptances.
- `swift test` and the release build pass with live checks unset.
- The extensibility report accounts for every change outside `Providers/Apple/` and `Providers.swift`.
- All G2 items pass before reporting the feature fully verified. Any final-review correction affecting a passed item adds it to the end checklist for re-checking.

## External validation gates

| Gate | Owning workstream | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1 Waiting pill look | 1 | After closure, before acceptance | Passed | Workstream 1 accepted tree | Aidan approves the waiting and error pills in both themes, or his corrections are applied |
| G2 Signed-build verification | External, after Final | After whole-feature review | Partially passed; eight checks pending | Signed WS6 candidate for reported passes; use the final reviewed candidate for remaining checks | Record all checklist items passing before claiming full external verification |

### G2 end checklist

Aidan approved moving anything unverified after whole-feature review on 2026-10-02. Items 1, 2, 10, 11 and 12 passed by his report. Items 3, 4, 5, 6, 7, 8, 9 and 13 remain pending external checks. They block full external verification, not workstream 6 acceptance or whole-feature review.

The reported passes refer to the WS6 source candidate over base `53c563bea5aab0fe43a3e0ee9f9b96d87d21b670`. Its scratch bundle was `/Users/aidanzealley/code/echotype/.build/EchoType-ws6.app`, signed with Apple Development team `LJHNNE925Q`, hardened runtime and the audio-input entitlement. Strict signature verification passed; executable SHA-256 was `a9bd2cabb5b28d58db014d95b86e5ff6be94cb78d0d2ff78becbe45bfa53e227`. A signed bundle and automated/live tests are separate evidence from Aidan's runtime checks.

After whole-feature review, use its final reviewed source candidate. Aidan runs `./scripts/run.sh` from the repository root when ready to replace his development copy. Agents do not run it. Record results here with the candidate identity and any unavailable test condition. Keep the item numbers stable. Do not remove assets or voices to manufacture a test condition without a separate decision.

1. Passed, Aidan reported 2026-10-02. With assets installed, Apple Intelligence available and Apple selected, turn networking off and verify dictation with cleanup, read aloud, MCP `speak` and Settings Test. Restore networking afterward.
2. Passed, Aidan reported 2026-10-02. Switch xAI → Apple → xAI. Each keeps its voice and speed; xAI still works as before.
3. Pending external check after whole-feature review. Turn Apple Intelligence off. Cleanup keeps its support mark and shows its reason; dictation shows the red pill and does not start. Re-enable it and check cleanup again.
4. Pending external check after whole-feature review. On a missing speech-model setup, verify the amber waiting pill blocks dictation, setup completion and failure refresh Settings, and launch with Apple selected starts setup. If no missing model is available, report that explicitly rather than removing assets to manufacture the state.
5. Pending external check after whole-feature review. After a normal restart with assets installed, first dictation is ready within five seconds.
6. Pending external check after whole-feature review. Silence before speech cancels quietly; silence after speech pauses and resumes in a real room; tap-and-stop without speech shows no error. Final R1 narrowed the finish-time rejection exception to empty committed and provisional text; this pending check covers that boundary. No previously passed G2 behavior changed.
7. Pending external check after whole-feature review. Dictate real jargon with saved keyterms and check their spellings.
8. Pending external check after whole-feature review. Pause/resume a long reading without missing audio or continuing to synthesize the rest while paused. Cancel during pending synthesis or model loading; the next operation works. Listen to a sentence longer than 250 Unicode scalars.
9. Pending external check after whole-feature review. A missing saved voice falls back without overwriting the saved choice. A voice downloaded in System Settings is picked up. Report an unavailable test condition rather than deleting voices without a separate decision.
10. Passed, Aidan reported 2026-10-02. Listen to Zoe and Jamie at 0.8x, 1x and 1.3x. Aidan accepts the existing `0.8...1.3` range as usable and sensible. His preferred speed is 1.1x; defaults remain unchanged.
11. Passed, Aidan reported 2026-10-02. Run a representative long dictation with cleanup and report text loss or cleanup failures.
12. Passed, Aidan reported 2026-10-02. Check Apple in the Provider tab, its three support marks and readiness reasons, and the waiting pill in both themes.
13. Pending external check after whole-feature review. Report first Apple dictation permission behavior on the signed app: microphone prompt if not already granted, any Speech Recognition prompt or denial, and whether transcription succeeds. Existing grants may mean no prompt appears; state that explicitly. Item 1's successful dictation does not establish first-use permission behavior.

## Escalations

None. E6-G2 was resolved by Aidan's decision to move the remaining checks after whole-feature review. Their pending status remains in the end checklist.

## Conventions learned

- Readiness adapters (3-5): `check` returns the current state without awaiting setup. Run setup in a task the adapter owns, not the caller's, because the controller cancels its in-flight `check` on every provider switch and app activation, and an installation must be able to finish after a switch.
- Readiness adapters (3-5): yield `changes` whenever setup starts, finishes or fails, including setup started by an operation's own `check`. Settings learns of operation-triggered state only through `changes`; `changes()` is called once per follow and must return a fresh stream each call, and `check` may be called concurrently.

- Apple adapters (4-5): surface a framework result stream's error the moment it throws, not at `finish()`. Workstream 3's first transcriber only observed its results task after finishing, so a mid-session failure went silent. In actor readiness checks, read cached setup state after the framework awaits, so a setup that ended meanwhile is not started again.
- Language (3-5): the picker's list is `Settings.Language.all` in `Sources/EchoTypeCore/Settings.swift`, entries `Language(name:tag:)` with bare tags, currently only `.english` (`en`). Stored settings map through `Language.matching` on load, but `Settings(language:)` built in code keeps any tag, so adapters still resolve whatever tag they receive.
- Seams (3-6): do not add injection parameters, such as a defaulted framework object, that no caller passes. Inject fixtures through a pure mapping function instead. Workstream 5's only Required finding was an unused `model:` parameter on its readiness check.
- Verification: `swift test --filter` matches suite or function names, and `Tests/EchoTypeCoreTests/SettingsTests.swift` holds free functions in no `SettingsTests` suite. Filter by test function name, or run the target, when a packet's filter names a file.

- Verification records, 6 and Final: distinguish SDK and unsigned tests from signed-app runtime evidence. Successful signing does not confirm permission prompt behavior. Keep stable G2 item numbers and update the end checklist if a correction requires repeating a passed item. Extensibility reports also account for changed workflow records as documentation outside the shared contract. A preferred speed does not change the provider's defaults.

- Transcription error policy, Final: the empty-finish exception must check both committed and provisional text. Recognized provisional words must not turn a finish-time rejection into silent success. Extend the existing mapping fixture rather than introducing framework injection.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-02 | `DictationOperation` checks readiness after the Starting pill and before capture opens, which is before the credential check rather than after it. `Reader` follows the specified order. | The key is read only after capture opens, so the specified order would open capture for a blocked dictation or change xAI startup. Not observable for any planned provider: xAI has no readiness and Apple no credential. | Workstream 1 lead | 1, 6 |
| 2026-10-02 | Gate G1 passed: the waiting pill ("Not ready", amber hourglass, reason in primary text, no glow, three-second fade) and the unchanged error pill are approved in both themes. | Aidan approved as is. Later workstreams reuse `Pill.Phase.waiting(String)` for readiness messages without restyling. | Aidan | 1, 3-6 |
| 2026-10-02 | Workstream 6 recovery initially had no specification drift. Fresh independent review and focused closure passed before G2. | Reused the completed implementation and corrected two documentation findings in one pass. Gate placement changed later by the user decision below. | Workstream 6 recovery lead | 6 |
| 2026-10-02 | G2 items 1, 2, 10, 11 and 12 passed. Retain the Apple `0.8...1.3` speed range and existing defaults; Aidan prefers 1.1x. Move unverified items 3, 4, 5, 6, 7, 8, 9 and 13 after whole-feature review, without blocking WS6 or Final acceptance. | Aidan cannot make environment changes or restart now and instructed, "Let's move anything unverified right to the end". This amends the frozen gate placement; it does not mark pending checks passed. | Aidan | 6, Final, External |
| 2026-10-02 | Final whole-feature review accepted after narrowing the empty-finish rejection exception and synchronizing the accepted speed-range comment. No new specification drift. | Independent whole-feature review, one focused correction and fresh closure passed. All packet commands passed. G2 retains five reported passes and eight pending checks; the correction concerns pending item 6 and invalidates no reported pass. | Final-review lead | Final, External |
