# EchoType macOS rewrite implementation plan

Status: approved; execution started. Workflow approval: Aidan approved execution of the README and plan in this conversation on 2026-09-30.

## Orchestration record

- Integration branch: `refactor/macos-lifecycle`
- Starting commit: `2e17817246749f626ce36c90823dee2b4ef0d5fb`
- Review command: `lead subagents`, inherited model and effort
- Specification approval reference: agreed scope in this conversation; committed planning base `2e17817246749f626ce36c90823dee2b4ef0d5fb`; execution approved by Aidan on 2026-09-30
- Started: `2026-09-30`

This file is the resume record. Only one lead may be active. A non-terminal row without a live lead means interrupted work; restart that row with recovery, never its successor. Execution procedure and lead prompts are in [README](README.md). Do not start while workflow approval is pending.

Workstream states: Not started, Implementation, Review, Remediation, Closure review, Accepted, Blocked. An Accepted row is durable only if HEAD's committed version of this plan also records Accepted. Otherwise resume that lead to validate the existing record and finish its pending acceptance commit. This check also applies to Final.

## Workstream order

| # | Workstream | Depends on | Status |
|---|---|---|---|
| 1 | [Establish Mac verification](01-verification.md) | Workflow approval | Accepted |
| 2 | [Own clipboard and destination](02-clipboard-destination.md) | 1 | Accepted |
| 3 | [Own dictation lifetime](03-dictation.md) | 2 | Accepted |
| 4 | [Own reading lifetime](04-reading.md) | 3 | Not started |
| 5 | [Acknowledge MCP admission](05-mcp-admission.md) | 4 | Not started |
| 6 | [Validate settings compatibly](06-settings.md) | 5 | Not started |
| Final | [Whole-feature review](final-review.md) | 1 through 6 | Not started |

## Execution pause and next action

Aidan approved reduced-core G4 acceptance on 2026-09-30 and requested a pause immediately after workstream 3 is accepted. Workstreams 1 through 3 are Accepted; workstream 4 is next and remains Not started. Do not start it in this session. After the workstream 3 lead commits and releases ownership, the orchestrator verifies HEAD records acceptance and writes a continuation prompt alongside the starter prompt. A fresh orchestrator resumes workstream 4 only when Aidan continues. No further live call, Test rerun, focus change or candidate restart is required for this acceptance.

## Why these boundaries

Verification establishes real Mac commands before changing lifecycles. Clipboard/destination is a complete usable change to the existing app and proves the target contract before dictation consumes it. Dictation integrates capture, protocol, revision and its presentation together. Reading owns request/player/replacement cleanup and its presentation. MCP then changes one public admission boundary using accepted reading semantics. Settings validation protects the persistence/request boundary independently. Final review audits assembled behavior rather than serving as a deferred UI implementation stream.

All work is sequential because clipboard, dictation, reading and MCP each change the coordinator. No model/service/test split or parallel writers in the coordinator are permitted. There is no temporary insertion implementation to throw away after dictation.

## Cross-workstream contracts

- Coordinator reserves one operation synchronously; hotkey callbacks perform no blocking work. One operation owns one result and all resource cleanup. Replacements cannot receive old callbacks.
- Clipboard destination is an opaque app-owned token. Capture it at entry to finishing; verification reports matching, changed or unavailable. Cancellation wins until the service's write-and-paste transaction begins. Revalidate before paste and Return, without activating another app.
- Clipboard exposes complete selection-copy/insertion operations and an explicit way to await pending cleanup. Insertion reports attempted paste, attempted Return, skipped Return or recovery. Cleanup belongs to the service after transaction start. Concrete Swift declarations are published in workstream 2's handoff.
- Trace separates available final text from insertion/sending attempts and recovery. Recovery UI compares words with final text, not an empty insertion field. Tests/readings do not replace Last Dictation.
- Dictation consumes one typed receive loop and one ordered sender. All send/receive failures reach its owner. Existing transcript/revision/word rules stay authoritative. Eight-second finishing includes drain and protocol sends; the final revision has its separate bounded budget.
- Reading publishes startup/playing/paused/failure state, supports cancellation-aware completion, and joins necessary clipboard cleanup on replacement. Its accepted handoff supplies the coordinator boundary used by MCP.
- MCP request/reply uses distributed notifications. One UUID request id, monotonic system-uptime expiry and intended app PID correlate the exchange. The app checks expiry on the main actor when reserving reading. Reply conveys accepted, busy or expired; the client distinguishes unavailable and unconfirmed delivery. Five seconds bounds admission wait, not playback. No automatic retry or queue.
- A replacement is admitted for immediate startup after required cleanup. Accepted does not mean playback completed. Reject dictation/Test requests through insertion cleanup; newer reading requests can supersede a pending reading.
- Settings keeps current keys/defaults and per-field fallback. Speech speed must be finite and within its supported range; invalid values fall back to the default. Do not introduce versioned migrations for unchanged storage.

These contracts freeze behavior and dependency direction. Details owned solely within one packet remain flexible. A defect affecting an accepted handoff needs an escalation naming the owning workstream and evidence, not silent downstream wrappers.

## Ownership handoffs

- `Package.swift` and app-test setup: 1 establishes imports; 2 through 6 may add their tests without redesigning the package. A third production target requires demonstrated tooling need and recorded rationale.
- `DictationController.swift`, or its replacement coordinator, transfers exclusively 2 -> 3 -> 4 -> 5. Each lead records changed interfaces. `App.swift` and pill composition transfer with their feature owner. No packet starts against an unaccepted handoff.
- `Inserter.swift`/`Pasteboard.swift` and new focus/clipboard files belong to 2. Workstreams 3 and 4 consume their contract; a defect in it returns to its owner through escalation.
- Core trace and Last Dictation recovery presentation belong to 2, with dictation trace recording handed to 3.
- Workstream 2 owns the narrow session finishing-transition integration seam and its tests so destination capture does not depend on buffered snapshots. Full session/STT/revision/capture ownership transfers to 3, preserving that behavioral contract. Playback/reading belong to 4. Notification transport, `MCPProcess` and MCP tests belong to 5. Settings/storage/request validation belong to 6.
- Each lead owns its numbered record and row, its gate records and relevant decision-document updates. Final owns whole-feature corrections and final evidence.

## External validation gates

| Gate | Owner and placement | Status | Candidate | Required evidence and resume condition |
|---|---|---|---|---|
| G1 Mac/toolchain/CI | 1, after closure before acceptance | Passed | Workstream 1 on `refactor/macos-lifecycle`, base `2e17817`; local tests/build and fresh closure pass; Aidan approved Actions deferral on 2026-09-30; CI unverified; required-check configuration pending | Swift tests and release build on Mac; passing Actions run or explicit approval to defer Actions execution; record whether merge-check configuration needs Aidan |
| G2 Destination feasibility | 2, during implementation before independent review | Passed | Adapter SHA-256 `ea177e90…`; base `70bbbd5`. Native TextEdit 1.21, Electron VS Code 1.139.1 and user-approved Ghostty 1.3.1 pass three stable trials and same-window Find changes each; focus-away and unavailable checks pass | Evidence re-audited 2026-09-30. Aidan explicitly approved Ghostty and confirmed same-window Find in E2-G2-TARGET. Terminal.app remains unverified; permission/attribution limits remain recorded |
| G3 Clipboard integration | 2, after closure before acceptance | Passed | Reviewed candidate base `70bbbd5`, executable SHA-256 `4bdd633e…`; separate signed driver uses exact Clipboard/Destination source | Signed TextEdit Copy/paste/Return, seeded string/HTML restoration, acknowledged stopped Copy followed by insertion, separate-process external writer, same-window destination loss before paste and before Return, and unavailable System Settings focus pass. Driver-only timing holds/failed attempts recorded; no permissions changed. Disposable TextEdit test document remains open for user discard |
| G4 Dictation/device behavior | 3, after closure before acceptance | Passed | Base `7521be7`; original/readiness/acknowledgement/amber reviews complete. Signed amber delivery candidate `.build/EchoType-workflow.app`, SHA-256 `57acc71b…`; running readiness candidate remains uninterrupted | Aidan approved reduced-core acceptance on 2026-09-30 using signed first-four passes, Settings Test use, extensive everyday/readiness use and deterministic evidence. External-input fallback/disconnect, Bluetooth profile/conversion, alternate-theme/error/amber layout, detailed signed Test controls/retention, manual Copy text recovery, configured/insertion hints and permission-edge checks remain unverified and are deferred for this workflow |
| G5 Reading/playback | 4, after closure before acceptance | Pending | TBD | Signed selection Copy, stop/replacement/Space, pause queue bounds and dictation takeover; no stale levels or playback |
| G6 Two-process MCP | 5, during implementation before independent review, then verify final candidate | Pending | TBD | Signed real `--mcp` exchanges accepted/busy/unavailable/unconfirmed; reply receipt while app inactive, main-actor expiry, modern/legacy modes, no app launch or accidental playback after expired admission |
| G7 Whole-feature Mac | Final, after focused closure before acceptance | Pending | TBD | Complete spec Mac checklist and command arbitration; both themes/accessibility/window behavior; truthful Last Dictation and no stale paths |

Gate states are Pending, Testing, Troubleshooting or Passed, separate from workstream states. Leads record runnable instructions and results in their numbered External validation section. User-dependent gates return Blocked with a plan escalation. If CI cannot be triggered without publishing a branch, record the concrete candidate and request that action or approval to defer execution; row 1 remains Blocked until either is supplied. An approved deferral permits later local work, but the final report must identify CI as unverified. Configure required checks only with available authorisation; otherwise record the repository-setting task for Aidan, without blocking unrelated local implementation.

## Whole-feature acceptance

All rows 1 through 6 must be Accepted. Tests and the unsigned release executable must pass on Mac; final review reruns the complete deterministic suite once. Every mandatory Mac behavior gate must pass or have an explicit user-approved scope decision recorded. CI execution/configuration status remains explicit. Pending required evidence prevents a complete report. No paid live xAI test is implied by workflow approval.

## Escalations

No open escalations. E3-G4-DEVICE is resolved into packet 3 and the decision log.

E2-G2-TARGET is resolved into packet 2 and the decision log.

## Completion summary

The final lead fills these fields before its acceptance commit so the orchestrator can report completion from this plan alone.

- Delivered outcomes: TBD
- Verification, including local Mac and actual CI results: TBD
- Approved pending checks and practical limitations: TBD
- Specification drift: TBD
- Deferred optional observations: TBD

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-29 | Clipboard before dictation; UI with feature owners | Prove editing-target identity before consumers and avoid deferred recovery/cancellation UI | Proposed in draft workflow | 2 through 5 |
| 2026-09-29 | Correlated distributed-notification request/reply with five-second admission wait | Extend existing delivery narrowly; signed two-process gate verifies feasibility | Proposed in draft workflow | 5 |
| 2026-09-30 | Workstream 1 drift: none. Direct executable-target app tests work without a production split | Local SwiftPM import and adapter tests pass without app startup; recovery confirms reviewed code and local checks | Within approved packet scope | 1 |
| 2026-09-30 | Workstream 2 Accepted. Approved validation drift: Ghostty replaces Terminal.app for G2; Terminal.app remains unverified. No architecture drift | E2-G2-TARGET answered "Yes, accept Ghostty; Find opened in the same window." G2 evidence audited; complete clipboard/recovery integration passed independent review, one R1 remediation and fresh closure. G3 signed service trials passed after closure. Final targeted run passed 31 tests. Narrow Pill ownership extension hides cancellation during insertion; temporary probes removed, logs preserved | Aidan, E2-G2-TARGET, 2026-09-30; remaining implementation within approved specification | 2 through 4 and final reporting |
| 2026-09-30 | Defer the first Actions execution. CI remains unverified; required-check configuration remains an administrator follow-up | E1-CI resolved. Continue local work after G1; no publication or PR authorised | Aidan, explicit answer recorded in E1-CI on 2026-09-30 | 1 and final reporting |
| 2026-09-30 | G4 bounded live authority, temporary input/appearance changes and device reconnects approved | Initial shared limit was twelve 20-second dictations and one 5-second Test. Test is consumed and must not be rerun. Aidan later authorised six additional 20-second dictations, existing-key STT/cleanup only, and an idle-time candidate restart. Native restart established workflow GUI PID 83457 while preserving eight MCP processes; AX binding timed out. Temporary input/theme changes and reconnects require restoration. No TTS, key display/export, new grants or production install. Acceptance recovery used zero additional calls and did not reset allowances; reduced-core approval removes the need to reconstruct historical use or gather further live evidence | Aidan, successive E3-G4-DEVICE answers preserved in packet 3 | 3 and final reporting |
| 2026-09-30 | Approved workstream 3 scope addition: advisory destination readiness and dictation-error line height 1.5 | Aidan requested early "Select an input" feedback and automatic readiness after focusing a text field. Capture and transcription continue under the existing lifetime. The advisory check discards its destination token; only finishing captures the insertion destination. Conservative app/window/target identity, final Clipboard validation and accepted workstream 2 APIs remain unchanged. Frozen Task packet stays unchanged; this new request does not reset or consume another remediation pass | Aidan, latest E3-G4-DEVICE answer; lead interpretation independently assessed | 3, 4 and final reporting |
| 2026-09-30 | Workstream 3 narrow test acknowledgement correction verified; no implementation drift | Parent authorised the existing fake-clock race correction. One shared capture-drain acknowledgement replaces presentation-based timing in stalled send/drain tests. Implementer passed 48 declarations and 20 repetitions; different focused verifier passed four declarations/six cases with no findings. No production machinery or new remediation pass. Sole R1 remediation remains used; signed G4 disposition is recorded in the acceptance decision below | Parent triage within approved verification scope | 3, 4 and final reporting |
| 2026-09-30 | Workstream 3 Accepted. Approved scope additions: advisory destination readiness, error spacing and amber label. Approved validation drift: reduced-core G4 with named manual deferrals. No architecture drift | E3-G4-DEVICE answered "Approve but pause once workstream 3 is accepted, write a continuation prompt alongside the starter prompt and then I'll continue on a fresh agent." Existing signed first-four speech, TextEdit insertion, five-second Test use and extensive successful readiness use support core; retained 80-declaration final, 45-declaration closure and corrected 48-declaration logs pass. Original/R1, readiness, acknowledgement and amber reviews remain complete, with only one remediation used. Strict signing and amber delivery hash reverified. External-input fallback, external microphone disconnect/reopen, Bluetooth headset profile/format conversion, alternate-theme and changed error/amber layout, detailed signed Test hotkey/Escape isolation/no overlay/no insertion/Last Dictation retention, manual Last Dictation Copy text recovery, fine-grained configured/insertion hints and permission-edge checks are deferred for this workflow and remain unverified in final reporting. Earlier T3 intermittency remains unattributed. Pause after this commit; 4 is next, no further execution until Aidan continues | Aidan, explicit E3-G4-DEVICE answer on 2026-09-30 | 3, 4 and final reporting |
