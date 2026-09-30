# EchoType macOS rewrite implementation plan

Status: draft; implementation has not started. Workflow approval: pending.

## Orchestration record

- Integration branch: `TBD`, proposed `refactor/macos-lifecycle`
- Starting commit: `TBD`
- Review command: `lead subagents`, inherited model and effort
- Specification approval reference: agreed scope in this conversation; record the committed planning base at execution
- Started: `TBD`

This file is the resume record. Only one lead may be active. A non-terminal row without a live lead means interrupted work; restart that row with recovery, never its successor. Execution procedure and lead prompts are in [README](README.md). Do not start while workflow approval is pending.

Workstream states: Not started, Implementation, Review, Remediation, Closure review, Accepted, Blocked. An Accepted row is durable only if HEAD's committed version of this plan also records Accepted. Otherwise resume that lead to validate the existing record and finish its pending acceptance commit. This check also applies to Final.

## Workstream order

| # | Workstream | Depends on | Status |
|---|---|---|---|
| 1 | [Establish Mac verification](01-verification.md) | Workflow approval | Not started |
| 2 | [Own clipboard and destination](02-clipboard-destination.md) | 1 | Not started |
| 3 | [Own dictation lifetime](03-dictation.md) | 2 | Not started |
| 4 | [Own reading lifetime](04-reading.md) | 3 | Not started |
| 5 | [Acknowledge MCP admission](05-mcp-admission.md) | 4 | Not started |
| 6 | [Validate settings compatibly](06-settings.md) | 5 | Not started |
| Final | [Whole-feature review](final-review.md) | 1 through 6 | Not started |

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
| G1 Mac/toolchain/CI | 1, after closure before acceptance | Pending | TBD | Swift tests and release build on Mac; passing Actions run or explicit approval to defer Actions execution; record whether merge-check configuration needs Aidan |
| G2 Destination feasibility | 2, during implementation before independent review | Pending | TBD | Repeated stable editing-target identity plus changed-field detection in native, terminal and Electron editors; conservative recovery for unsupported targets; failure changing supported scope requires Aidan's decision |
| G3 Clipboard integration | 2, after closure before acceptance | Pending | TBD | Signed paste/copy/restoration, recovery and Return suppression; external clipboard writes and reading Copy cleanup checked |
| G4 Dictation/device behavior | 3, after closure before acceptance | Pending | TBD | Signed hotkeys/cancellation/last-word behavior and mic release; chosen input, disconnect and Bluetooth checks as available; network live test only with explicit authority |
| G5 Reading/playback | 4, after closure before acceptance | Pending | TBD | Signed selection Copy, stop/replacement/Space, pause queue bounds and dictation takeover; no stale levels or playback |
| G6 Two-process MCP | 5, during implementation before independent review, then verify final candidate | Pending | TBD | Signed real `--mcp` exchanges accepted/busy/unavailable/unconfirmed; reply receipt while app inactive, main-actor expiry, modern/legacy modes, no app launch or accidental playback after expired admission |
| G7 Whole-feature Mac | Final, after focused closure before acceptance | Pending | TBD | Complete spec Mac checklist and command arbitration; both themes/accessibility/window behavior; truthful Last Dictation and no stale paths |

Gate states are Pending, Testing, Troubleshooting or Passed, separate from workstream states. Leads record runnable instructions and results in their numbered External validation section. User-dependent gates return Blocked with a plan escalation. If CI cannot be triggered without publishing a branch, record the concrete candidate and request that action or approval to defer execution; row 1 remains Blocked until either is supplied. An approved deferral permits later local work, but the final report must identify CI as unverified. Configure required checks only with available authorisation; otherwise record the repository-setting task for Aidan, without blocking unrelated local implementation.

## Whole-feature acceptance

All rows 1 through 6 must be Accepted. Tests and the unsigned release executable must pass on Mac; final review reruns the complete deterministic suite once. Every mandatory Mac behavior gate must pass or have an explicit user-approved scope decision recorded. CI execution/configuration status remains explicit. Pending required evidence prevents a complete report. No paid live xAI test is implied by workflow approval.

## Escalations

None. Leads add entries with id, owning row, decision needed, options, recommendation, evidence, what it unblocks and User's answer. The orchestrator reads only the named entry and records that answer. The resuming lead writes its lasting decision into the handoff/log before removing the entry.

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
