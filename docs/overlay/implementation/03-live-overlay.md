# Workstream 3: Live overlay

Status: not started.

## Task packet

### Outcome

Every dictation shows the pill Aidan chose. It appears the moment Opt+D is pressed, says
when to start speaking, shows the input level, live text and elapsed time, dims when
paused, shows failures inline, and fades when the session ends. Clicking it commits. It
never takes focus. The menu bar goes back to showing only the session state.

### Scope

**Phases, from the controller.** `DictationController` drives the pill value from
workstream 2 through `OverlayPanel`, reading workstream 1's snapshots. Map the phases
like this:

| Pill phase | When |
|---|---|
| starting | From the press until the first audio chunk arrives from the microphone. This covers the device open, the Keychain read and the socket opening. |
| listening, paused | The snapshot's state, once audio is flowing |
| transcribing | `finalizing` and `inserting` |
| error | The session produced `failed`, or the start failed (microphone denied, no input device, no API key) |

The pill shows at once on the press, before `audio.start()` is awaited, so the user sees
it while the device opens. Take the settled and provisional text from each snapshot. The
session's start time is the press.

**Endings.** When the session ends:

- `insert`: insert, then fade the pill.
- `nothing` (Escape, or the silence close with nothing heard): fade the pill silently.
- `failed`: insert any text as now, and show the error inline in red for about three
  seconds before fading.

A start failure shows its error the same way. A new Opt+D press while an error is showing
starts a new session and replaces it. Reuse the existing `describe(_:)` wording for
errors.

**Escape during starting.** Consume Escape while the controller is starting, and abandon
the start: release the microphone once `audio.start()` returns, open no socket, and fade
the pill. Escape still passes through when no session is starting or running.

**Nothing slow in the tap callback.** `hotkeyPressed()` currently calls `audio.stop()`
inside the event tap callback. Move that work, and anything else this workstream adds to
the press and Escape paths, out of the callback so the tap only decides whether to consume
the event. Keep the commit order from [0005](../../decisions/0005-microphone-per-session.md):
stopping capture first so the pump drains the tail before `trigger()`.

**The click.** A click on the pill takes the same path as an Opt+D press. While starting
it is ignored, as the press is.

**The level meter.** `AudioCapture` publishes an input level from 0 to 1, derived from the
RMS of each tap buffer and mapped so ordinary speech moves the meter visibly and room
noise barely does. Compute it on the buffer the tap already receives, before conversion.
Deliver it to the main actor at about the tap's buffer rate; do not add a timer. The
level is zero whenever capture is stopped.

**Placement.** At the press, choose the screen holding the focused window: ask
Accessibility for the frontmost application's focused window frame and pick the
`NSScreen` containing its centre. Remember that Accessibility coordinates have their
origin at the top left of the primary screen. Fall back to the screen under the mouse
when there is no focused window. The pill stays on that screen for the session.

**The menu.** Remove the controller's `problem` and the menu's failure line. The state
line shows the session state only. The icon behaviour is unchanged.

**The gap list.** Remove the "Escape during the starting state" and "`audio.stop()` runs
inside the event tap callback" items from `docs/decisions/0007-known-gaps.md`.

**Gate G2.** After focused closure, the lead fills in this record's External validation
section with the candidate and the exact commands, adds escalation entry E2 to
`plan.md`, sets the row to `Blocked` and G2 to `Testing`, and returns. Failures Aidan
reports go through the troubleshooting loop in the README.

### Non-goals

- Settings of any kind, including a device picker or a warning about Bluetooth input.
- Following the caret, or moving the pill between screens mid-session.
- Changing `SessionMachine`, the transcript assembler or the pill's design. A defect in
  the seam or the panel's contract is an escalation. A visual defect G2 finds may be
  fixed in `Views/` as a troubleshooting correction.
- Reconnecting or retrying a failed session.
- A history of errors, or errors outside the pill.

### Initial ownership

- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/AudioCapture.swift`, for the level
- `Sources/EchoTypeApp/App.swift`, for the menu line and composition
- `Sources/EchoTypeApp/OverlayPanel.swift`, for placement and the click only
- `Sources/EchoTypeApp/HotkeyMonitor.swift`, only if moving work out of the callback
  needs it
- `Sources/EchoTypeApp/Views/`, only for defects G2 finds
- `docs/decisions/0007-known-gaps.md`, for the two items above

### Required seams

- The snapshot stream recorded in workstream 1's handoff.
- The pill value and `OverlayPanel` API recorded in workstream 2's handoff.
- The capture API as it stands in `AudioCapture.swift`, plus the level this workstream
  adds.

### Acceptance criteria

1. The pill appears on the press in its starting state and switches to listening on the
   first audio chunk.
2. Live settled and provisional text, the level, elapsed time and the paused state all
   reach the pill.
3. Each ending behaves as listed above, and a failure's settled text is still inserted.
4. Escape during starting abandons the start, releases the microphone and opens no
   socket. Escape passes through when nothing is starting or running.
5. The tap callback does no work beyond deciding whether to consume the event.
6. A click on the pill commits exactly as Opt+D does.
7. The pill appears on the screen holding the focused window.
8. The menu shows only the session state.
9. The two 0007 items are removed.
10. Gate G2 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
timeout 120 swift test --disable-xctest
swift-format lint --recursive Sources Tests Package.swift
./scripts/run.sh
./scripts/run.sh --hud-demo
```

The test suite guards workstream 1's seam against accidental change. Everything this
workstream adds is verified at gate G2.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## External validation

- Gate and placement: G2, after focused closure and before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: see G2 in [plan.md](plan.md)
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan reports every G2 observation, or a failure the lead can correct
  and republish

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
