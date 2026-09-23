# Dictation implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `TBD`
- Starting commit: `TBD`
- Review command: `lead subagents`
- Specification approved at commit: `47e3fa1`
- Started: `TBD`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Core seams](01-core-seams.md) | Approved spec | Not started |
| 2 | [Audio capture](02-audio-capture.md) | 1 | Not started |
| 3 | [Dictation end to end](03-dictation-end-to-end.md) | 1, 2 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-3 | Not started |

## Why these boundaries

Workstream 1 is the only work in this milestone with fast automated tests, and it is
small on purpose. A hang in `finalizing` and a mis-mapped 401 are both defects you
cannot see from the app, and both are cheap to pin with an injected clock and one live
call. Doing them first also means the app target picks up its `EchoTypeCore` dependency
before anything needs it, so no later workstream edits `Package.swift`.

Workstream 2 is split from 3 because audio capture is a different subsystem with
different failure modes: sample rate conversion, device acquisition latency and buffer
cadence have nothing to do with event taps or the pasteboard. It is the largest single
piece of unfamiliar API surface in the milestone and deserves its own review.

Workstream 3 is deliberately one unit rather than three. A hotkey monitor with nothing to
trigger, a Keychain reader with nothing to authenticate, and a controller with no hotkey
are each unshippable alone, and splitting them would mean the earlier half building stubs
for the later half to delete. Their acceptance is a single observable fact: pressing
Opt+D twice puts what you said at the caret.

Gate G1 sits at the end of workstream 3 rather than being spread across 2 and 3, because
one hand-run session is the only evidence that exists for both the audio path and the
insertion path, and asking Aidan to sit down twice for the same sentence buys nothing.

## Cross-workstream contracts

Frozen once workstream 1 is accepted:

- `EchoTypeApp` depends on the `EchoTypeCore` target. No workstream after 1 edits
  `Package.swift`.
- `SessionMachine`'s public surface is `run()`, `send(audio:)`, `trigger()`, `cancel()`,
  `states` and `Outcome`. Workstream 3 consumes it as it is. A defect in it is an
  escalation, not a rewrite.
- `SessionMachine` gains a bounded wait in `finalizing`. Its expiry produces
  `Outcome.failed(text:error:)`, not a hang and not a silent success.

Frozen once workstream 2 is accepted:

- Audio reaches the session as `Data` holding 16 kHz mono little-endian Int16, in chunks
  of roughly 100ms, in capture order. Workstream 2 chooses the exact API and records it
  in its handoff; workstream 3 reads that handoff rather than assuming a shape.
- Acquiring and releasing the input device is separate from starting and stopping
  delivery, because the first costs 100 to 300ms and would clip the first word.

Held by the specification and not open to a workstream:

- The bundle identifier is `com.aidanzealley.echotype`. TCC grants, the Keychain item and
  `UserDefaults` all key off it.
- `scripts/run.sh` is the only supported build and launch path.
- Nothing is inserted by a timer except the ten minute hard cap.

## Ownership handoffs

| File | Owner | Notes |
|---|---|---|
| `Package.swift` | 1 | Frozen after acceptance |
| `Sources/EchoTypeCore/SessionMachine.swift` | 1 | |
| `Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift` | 1 | |
| `Sources/EchoTypeCore/Settings.swift` | 3 | The hotkey matching predicate |
| `Sources/EchoTypeApp/AudioCapture.swift` | 2 | 3 may correct it during G1 troubleshooting |
| `Resources/Info.plist` | 2 | |
| `Sources/EchoTypeApp/HotkeyMonitor.swift` | 3 | Rewritten, not extended |
| `Sources/EchoTypeApp/Keychain.swift` | 3 | New |
| `Sources/EchoTypeApp/DictationController.swift` | 3 | New |
| `Sources/EchoTypeApp/Inserter.swift` | 3 | |
| `Sources/EchoTypeApp/App.swift` | 3 | |

Workstream 3 may change `AudioCapture.swift` only while troubleshooting gate G1, and
records each such change in its handoff as a correction to workstream 2's work.

## Whole-feature acceptance

- Workstreams 1 to 3 accepted.
- Gate G1 passed, with Aidan's evidence recorded in
  [03-dictation-end-to-end.md](03-dictation-end-to-end.md).
- `swift build` clean and `swift test` green.
- No overlay, settings window, level meter, launch-at-login or `install.sh` in the diff.
  Those are later milestones and their appearance here is scope creep to reject.

## External validation gates

### G1 Real dictation on Aidan's Mac

- Owning workstream: 3
- Placement: after focused closure, before acceptance
- Status: `Pending`
- Candidate: the uncommitted workstream 3 branch state, launched with `./scripts/run.sh`
- Resume condition: Aidan reports every required observation below, or reports a failure
  the lead can correct and republish

Required evidence, in Aidan's words:

1. The app launches, prompts for Microphone and for Device Control and Data Access, and
   both grants stick across a subsequent `./scripts/run.sh`.
2. Opt+D in TextEdit, one spoken sentence, Opt+D again, and that sentence appears at the
   caret.
3. Whether the first word was clipped.
4. Escape mid-session discards and inserts nothing.
5. The clipboard contents from before the dictation come back afterwards.
6. Two dictations back to back both land, the second within a second or two of the
   first.
7. The menu bar icon changes while a session is running.

Before the gate, Aidan must seed the Keychain item once. The lead publishes the exact
command with its candidate.

## Escalations

None yet.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-23 | Errors surface in the menu bar menu, not an overlay | The overlay is a later milestone, and `Outcome.failed` still has to go somewhere the user can see | Aidan, before the workflow | 3 |
| 2026-09-23 | The API key is read from the Keychain with no UI to write it | Storage is the real one from the start, so the settings milestone adds only the editor; an `LSUIElement` app launched by `open` inherits no shell environment, so an environment variable was never an option | Aidan, before the workflow | 3 |
