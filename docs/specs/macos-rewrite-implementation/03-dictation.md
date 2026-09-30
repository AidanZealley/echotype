# Workstream 3: Own dictation lifetime

Status: not started.

## Task packet

### Outcome

One dictation owner manages startup through insertion and teardown. Escape prevents insertion until the clipboard transaction starts; send errors and stalled finalisation cannot become silent success or a hung operation.

### Scope

Replace the current session/client/relay coordination with one typed receive loop and an explicitly ordered sender. Reuse transcript assembly and revision validation. Remove obsolete relay/tasks/state in the same slice, without deleting genuine persistence or MCP compatibility boundaries.

Give a dictation operation one result and ownership of capture, readiness, sends/receives, live/final revision and cleanup. The coordinator owns admission and its top-level task. Test uses the same capture/transcription lifetime but no insertion, overlay or trace. Preserve its five-second timer and ignore its hotkey/Escape controls.

Propagate live and buffered send errors, malformed frames, server errors and abnormal closure. Keep committed words on failure and apply the accepted clipboard destination rule. No automatic Return on capture/transcription failure. Successful finalisation requires protocol completion.

Cancellation is effective through startup, drain, finalisation and final revision. A callback arriving after cancellation cannot start a socket or affect a replacement. Recheck cancellation at the clipboard boundary; the service owns restoration afterwards. Join child work through teardown, closing resources to release suspended work.

Use the existing monotonic timing seam. Retain silence/hard-cap defaults. Arm the eight-second finishing budget before draining/sending. Bound readiness after transport opening without timing out system prompts. Keep a separate bounded final revision and reuse its network session. Put finite audio backlog limits in named constants and fail visibly on overflow. Preserve device fallback/reopen and conversion behavior.

Derive dictation menu/pill state from the operation, preserving microphone readiness. Fix configured hints and stop advertising Escape during insertion. Capture destination at entry to finishing as established by 2. Record trace result from the insertion result, not just the transcript outcome. Preserve reading behavior while handing its lifecycle refactor to 4.

### Non-goals

Do not change wording/word matching, providers, models, visual design, clipboard contracts or MCP transport. Do not add a universal reducer, generic task manager or speculative reconnect/retry framework.

### Initial ownership

- `Sources/EchoTypeCore/SessionMachine.swift`, `SessionClock.swift`, `STT/`, `RelayTransport.swift`, `Reviser.swift`, `RevisionRequest.swift`, and focused new operation/protocol types.
- `Sources/EchoTypeApp/DictationController.swift` or replacement coordinator, `AudioCapture.swift`, `AudioChunker.swift`, `App.swift`, `Views/Pill.swift`, `PillView.swift`, `PillDemo.swift`, `HotkeyMonitor.swift` for operation integration.
- Focused core session/STT/reviser tests and `Tests/EchoTypeAppTests/DictationOperationTests.swift`, `CoordinatorTests.swift`, synthetic capture tests where valuable.
- Decision records 0004/0005/0009/0012/0021 and index as affected, this record, row 3/G4 and escalations.
- Consume the accepted clipboard/trace APIs from 2. Changes to those contracts require escalation to their owner rather than silent redesign.

### Required seams

Coordinator command admission stays synchronous and nonblocking. Operation settings are snapshots. Expose typed presentation and one completion outcome; concrete declarations belong in the handoff. Preserve reading command arbitration while replacing dictation state. A stopped operation owns only its own resources.

The clipboard service remains responsible for final insertion cancellation/destination validation and completion of restoration. Network errors remain distinguishable from revision fallback. Final text, attempted insertion/sending and recovery flow into the trace contract from 2.

### Acceptance criteria

- Spec cases 1 through 7 pass, along with destination integration and Test retention rules.
- Closing frames never overtake final audio; timeouts include stalled sends/drain and free dependent tasks.
- Escape during finalisation/revision wins over queued success and never pastes or sends before the boundary.
- Device startup/reopen races cannot affect another operation; mic capture stops promptly and backlogs stay bounded.
- Reply detection, faithfulness, cleanup fallback, transcript fixtures and failure-text recovery preserve meaning.
- Only one owner publishes each fact; obsolete relay, duplicate decode paths and unowned lifecycle tasks are gone.
- G4 passes for the signed candidate, with paid live verification only when explicitly authorised.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'DictationOperationTests|CoordinatorTests|SessionMachineTests'
swift build --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-workflow.app
git diff --check
```

Add affected existing STT/reviser/transcript tests using actual identifiers from `swift test list`; many are top-level functions rather than file-named suites. Record the exact selected test command and count. Create suspension/failure gates with deterministic acknowledgements; do not depend on real sockets or wall-clock sleeps.

## Implementation handoff

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Coordinator/operation/presentation declarations used by reading: TBD
- Timing/backlog constants and rationale: TBD
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

- Gate and placement: G4, after closure before acceptance
- Status: Pending
- Candidate and instructions: Record signed startup/stop/cancel/final-word/mic-release checks, chosen input fallback, disconnect and Bluetooth steps; identify any required user grants or paid live call before running it
- Required evidence: Signed behavior, no stale operation callbacks, capture release and unchanged device behavior; exact limits and unavailable hardware recorded
- Attempts and lasting decisions: TBD
- Resume condition: Required evidence supplied; any unavailable hardware scope decision explicitly recorded by Aidan
