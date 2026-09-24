# Overlay implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `TBD`
- Starting commit: `TBD`
- Review command: `lead subagents`
- Specification approved at commit: `bc0fea8`
- Started: `TBD`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Live session seam](01-live-session-seam.md) | Approved spec | Not started |
| 2 | [Overlay panel and variants](02-overlay-panel-and-variants.md) | 1 | Not started |
| 3 | [Live overlay](03-live-overlay.md) | 1, 2 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-3 | Not started |

## Why these boundaries

Workstream 1 is the only part of this milestone with fast automated tests. It changes the
`SessionMachine` seam that every later workstream reads. Transcript text crossing that
seam, settled text told apart from provisional text, and pause cycles accumulating
correctly are all defects that are invisible on screen until someone dictates, and cheap
to pin with recorded frames and an injected clock. Settling the seam first means the
overlay is built against the real shape, not a guess.

Workstream 2 builds the overlay as a thing you can look at without dictating: the
non-activating panel, the SwiftUI pill, the `--hud-demo` launch, and the variants Aidan
chooses between at gate G1. It does not touch the controller. Everything the pill can
show is reachable from the demo, so the design choice and the panel's window behaviour
can be judged before any live data flows. The intermediate state is shippable: dictation
works as before, and the demo is a permanent part of the specification.

Workstream 3 feeds the chosen pill from a real session: the starting state, the level
meter, live text, elapsed time, inline errors, the click, and placement on the focused
window's screen. These change together in `DictationController` and `AudioCapture`, and
their acceptance is one observable fact at gate G2: the pill tracks a real dictation and
never takes focus. Splitting them would leave the controller half-wired between commits.

## Cross-workstream contracts

Frozen once workstream 1 is accepted:

- `SessionMachine` publishes one stream of snapshots in place of `states`. A snapshot
  holds the session state, the settled transcript text (rendered solid) and the
  provisional tail (rendered dimmed). A new snapshot is published on every state
  transition and every change to either text, and the stream finishes when the session
  does. Workstream 1 chooses the names and records them in its handoff; later workstreams
  read that handoff rather than assuming a shape.
- `run()`, `send(audio:)`, `trigger()`, `cancel()` and `Outcome` keep their current
  meaning. A defect in them found later is an escalation, not a rewrite.
- There is one transcript assembler per session, and the inserted text and the displayed
  settled text come from it.

Frozen once workstream 2 is accepted:

- The pill renders one app-side value describing everything it shows: its phase
  (starting, listening, paused, transcribing, or an error with its message), the settled
  and provisional text, the input level, and when the session started. It renders
  nothing else. `--hud-demo` and the live controller drive the same value. Workstream 2
  chooses the names and records them in its handoff.
- `OverlayPanel` shows, updates and hides the pill and reports a click on it. It never
  becomes key or main.
- Only the variant Aidan chose at G1 exists in the code.

Held by the specification and not open to a workstream:

- The overlay must never take focus from the target app.
- Nothing is inserted by a timer except the ten minute hard cap.
- The bundle identifier is `com.aidanzealley.echotype`.
- `scripts/run.sh` is the only supported build and launch path.

## Ownership handoffs

| File | Owner | Notes |
|---|---|---|
| `Sources/EchoTypeCore/SessionMachine.swift` | 1 | Frozen after acceptance |
| `Sources/EchoTypeCore/STT/TranscriptAssembler.swift` | 1 | |
| `Sources/EchoTypeCore/STT/STTClient.swift` | 1 | Only to leave one assembler per session |
| `Tests/EchoTypeCoreTests/` | 1 | |
| `Sources/EchoTypeApp/DictationController.swift` | 1, then 3 | 1 only adapts it to the new stream |
| `Sources/EchoTypeApp/OverlayPanel.swift` | 2, then 3 | New in 2. 3 changes it only to wire placement and the click |
| `Sources/EchoTypeApp/Views/` | 2, then 3 | New in 2. 3 changes it only for defects G2 finds |
| `Sources/EchoTypeApp/App.swift` | 2, then 3 | 2 adds the demo launch; 3 removes the menu's problem line |
| `scripts/run.sh` | 2 | Forwards launch arguments to the app |
| `Sources/EchoTypeApp/AudioCapture.swift` | 3 | The input level |
| `Sources/EchoTypeApp/HotkeyMonitor.swift` | 3 | Only if moving work out of the tap callback needs it |
| `docs/decisions/0007-known-gaps.md` | 1, then 3 | Each removes the items it resolves |

## Whole-feature acceptance

- Workstreams 1 to 3 accepted.
- Gates G1 and G2 passed, with Aidan's evidence recorded in the owning workstream records.
- `swift build` clean, `timeout 120 swift test --disable-xctest` green, and
  `swift-format lint --recursive Sources Tests Package.swift` clean.
- No settings window, hotkey dropdown, device picker, keyterms editor, launch at login or
  `install.sh` in the diff. Those belong to the settings milestone and their appearance
  here is scope creep to reject.

## External validation gates

### G1 Pill variant choice

- Owning workstream: 2
- Placement: after the first implementation pass, before the independent review
- Status: `Pending`
- Candidate: the uncommitted workstream 2 state, launched with
  `./scripts/run.sh --hud-demo`
- Resume condition: Aidan names one variant, optionally with adjustments. If he asks for
  adjustments or rejects every variant, the lead iterates candidates inside the gate.

Required evidence, in Aidan's words:

1. Which variant he chooses: A, B or C.
2. Any adjustments he wants to the chosen variant before it is finished.
3. That he looked at it in both dark and light appearance.

### G2 Real dictation with the overlay

- Owning workstream: 3
- Placement: after focused closure, before acceptance
- Status: `Pending`
- Candidate: the uncommitted workstream 3 state, launched with `./scripts/run.sh`
- Resume condition: Aidan reports every observation below, or a failure the lead can
  correct and republish

Required evidence, in Aidan's words:

1. Dictating into TextEdit, a terminal and one Electron app (for example VS Code or
   Slack), the transcript lands at the caret each time. The overlay never took focus.
2. The pill appears at once in its starting state and switches to listening when audio
   flows. Whether the first word was clipped.
3. The level meter moves with his voice and sits still when he is quiet.
4. Live text appears while he speaks, provisional text dimmed and settled text solid.
   Long text truncates from the left.
5. After ten seconds of quiet the pill shows paused; speaking again resumes it.
6. Clicking the pill commits exactly as Opt+D does.
7. Escape during the starting state and during listening each close the pill and insert
   nothing.
8. Opening a session and saying nothing: the pill fades away silently after about ten
   seconds.
9. A failure shows inline in red, for example with networking turned off: the pill
   shows an error and any settled text is still inserted.
10. With a second display, the pill appears on the screen holding the focused window.
    Skip if there is only one display.
11. The last word of a dictation is not dropped.

## Escalations

None open.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-24 | The pill is chosen from two or three structurally distinct variants at gate G1, then the others are deleted | Aidan asked to choose the design from variants | Aidan, before the workflow | 2 |
| 2026-09-24 | Failures and a missing API key show inline in the overlay. The menu bar's state line goes back to showing only the session state | The overlay is the error surface the specification describes. The menu carried failures only while nothing else could ([0006](../../decisions/0006-api-key-and-error-surface.md)) | Pending approval of this workflow | 3 |
| 2026-09-24 | Escape during the starting state is consumed and abandons the start: the microphone is released and no socket opens | The pill is visible from the first press, so Escape has an obvious target. Resolves the open item in [0007](../../decisions/0007-known-gaps.md) | Pending approval of this workflow | 3 |
| 2026-09-24 | `SessionMachine` owns the session's one transcript assembler. `STTClient` keeps the socket protocol (holding audio until `transcript.created`, send ordering, the closing messages) and stops assembling | The machine already decodes every frame to drive pausing. Mirroring the client's assembler would hold the same transcript twice | Pending approval of this workflow | 1 |
