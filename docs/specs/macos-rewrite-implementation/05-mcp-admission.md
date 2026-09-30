# Workstream 5: Acknowledge MCP admission

Status: not started.

## Task packet

### Outcome

The real `--mcp` process reports success only after the running app admits a reading. Dictation/Test return busy; replacement reading starts after necessary cleanup; no request queues for later speech.

### Scope

Extend existing distributed notifications into correlated request/reply delivery. Keep the narrow transport implementation in `EchoTypeApp`; move/remove `SpeakNotification` from core if it becomes solely an app transport detail. Preserve the hand-written modern/legacy MCP parser and tool guidance. Core only needs delivery success or a typed/localised error, not macOS notification details.

Use a UUID request id, intended running app PID and expiry on the shared system-uptime timeline. Register reply observation before posting. Bound the client wait to five seconds and service the main run loop while receiving replies. Standard-input reads must not starve that run loop. No `NSApplication`, settings store, login claim, hotkey monitor or audio initialisation in the MCP-only process.

On the app's main actor, validate request shape/expiry/target and atomically apply the spec admission table. Busy must leave the current operation alone. Accepted reserves a reading for immediate startup or replacement and replies before playback completion. Expired requests never start reading. Reject malformed text rather than crashing; do not expand tool semantics or introduce automatic retries.

Match replies to the pending request and ignore unrelated/late replies. Observer and timeout cleanup happen once. Missing app is unavailable; missing/lost reply is unconfirmed, since admission may already have happened. Do not describe timeout as proof of rejection. A repeated notification for the same live request must not create repeated playback; keep any necessary deduplication bounded by active requests/expiry rather than persistent history.

Run G6 early enough to prove the actual two-process loop before finalising implementation. Distributed notifications can be delayed or dropped and need a running main run loop. The protocol handles uncertainty; a passing round-trip is not a delivery guarantee. See Apple's [distributed notification documentation](https://developer.apple.com/documentation/foundation/distributednotificationcenter). If this mechanism cannot meet the agreed contract, escalate evidence and alternatives rather than silently adding a daemon, TCP listener or XPC service.

### Non-goals

No app launch, automatic replay, delayed speech queue, new agent configuration changes, summarisation model, general RPC framework, signing/entitlement changes or extra executable. No dual support for obsolete fire-and-forget delivery unless a concrete required external compatibility consumer is identified and approved.

### Initial ownership

- `Sources/EchoTypeApp/MCPProcess.swift`, `main.swift`, coordinator speech admission/observer code, new app-local request/reply types.
- `Sources/EchoTypeCore/SpeakNotification.swift` removal/move, `MCPServer.swift` only for delivery/error integration preserving protocol compatibility.
- `Tests/EchoTypeCoreTests/MCPServerTests.swift`, `Tests/EchoTypeAppTests/SpeechAdmissionTests.swift`, `MCPDeliveryTests.swift`.
- `Views/SettingsView.swift`/README only if setup text or error explanations need synchronization; preserve copyable registration commands.
- Decision 0022 and index, this record, row 5/G6 and escalations.

### Required seams

Consume the accepted coordinator/reading boundary from 4. Atomically reserve on the main actor before replying. Declare accepted/busy/expired admission outcomes inside the app transport; map unavailable/unconfirmed/invalid input to MCP tool errors. Preserve stdout exclusively for JSON-RPC responses and stderr for diagnostics.

No independent transport actor may decide whether dictation is busy from a stale state copy. Multiple clients may be active, but each admission is serialized by the coordinator. Register/cancel pending reply state safely across timeout, EOF and late notification delivery.

### Acceptance criteria

- Spec case 11 and every admission-table row pass, including dictation startup/finalisation/insertion and paused/startup reading.
- MCP replies follow admission, remain bounded, and do not wait for playback. Busy does not cancel dictation or Test.
- Main-actor expiry prevents a delayed request from starting reading. Unconfirmed delivery never automatically retries.
- Modern/legacy existing exchanges retain their response semantics and guidance. `--mcp` never starts the app services.
- Signed G6 proves reply receipt while the menu-bar app is inactive, concurrent clients, restart/no-app behavior and cleanup.
- The old silent-drop/fire-and-forget path is removed. Any deduplication state is bounded and tied to request expiry.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'SpeechAdmissionTests|MCPDeliveryTests|legacyExchangeDeliversText|modernRequestDeliversText|unsupportedVersionIsRejected|failedDeliveryIsAToolError'
swift build --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-workflow.app
git diff --check
```

Create named app suites and select actual new core tests too. Use fake notification timing/admission for deterministic tests. G6 must exercise the signed executable's real `--mcp` mode in two processes; write exact candidate-specific commands into External validation once built. Successful admission may trigger paid playback, so obtain authorisation before using the live speech path. Do not treat a fake parser test as proof of distributed delivery.

## Implementation handoff

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Actual request/reply fields and process-loop arrangement: TBD
- Decisions: TBD
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

- Gate and placement: G6 during implementation before independent review; recheck final candidate after fixes
- Status: Pending
- Candidate and instructions: Record exact signed executable and two-process exchanges for accepted/busy/no-app/timeout, inactive app, expiry and both MCP modes; include authorised playback setup
- Required evidence: Actual admission acknowledgement, functioning CLI run loop, bounded timeout and no expired request admitted; malformed/unrelated replies harmless
- Attempts and lasting decisions: TBD
- Resume condition: Contract passes on signed Mac; transport failure requiring a substitute is settled by evidence-backed escalation first
