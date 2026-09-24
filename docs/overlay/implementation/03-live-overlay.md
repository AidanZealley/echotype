# Workstream 3: Live overlay

Status: accepted. Gate G2 passed; observation 10 (second display) remains external validation pending.

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

- Base commit: `dbbeee9`
- Outcome: every dictation drives the chosen pill through `OverlayPanel`: starting on the
  press, listening once audio flows, live settled and provisional text, the level, elapsed
  time from the press, paused, transcribing, inline errors for three seconds, and a fade at
  the end. A click commits. Escape during starting abandons the start. The tap callback only
  updates the controller's phase and schedules tasks. The menu shows the session state only.
- Files changed:
  - `Sources/EchoTypeCore/Overlay.swift`, new: `Overlay.level(rms:)` (the meter mapping) and
    `Overlay.screenIndex(holding:among:)` (the Accessibility-to-`NSScreen` flip and the
    screen containing the window's centre).
  - `Tests/EchoTypeCoreTests/OverlayTests.swift`, new: one test for each.
  - `Sources/EchoTypeApp/DictationController.swift`: owns the `OverlayPanel` and the session's
    `Pill`; `problem` is gone; new `abandoned` phase; commit, Escape and the pill's start moved
    out of the tap callback into tasks; `clicked()`; endings go through `end(showing:)`.
  - `Sources/EchoTypeApp/AudioCapture.swift`: `level` and `onLevel`. The tap measures the
    loudest channel's RMS (`vDSP_rmsqv`) on the buffer before conversion, only while
    delivering, and posts it to the main actor with one `Task` per buffer.
  - `Sources/EchoTypeApp/OverlayPanel.swift`: `NSScreen.forFocusedWindow()`, which asks
    Accessibility for the frontmost app's focused window frame and falls back to the screen
    under the mouse, then `NSScreen.main`. The panel class itself is unchanged.
  - `Sources/EchoTypeApp/App.swift`: the idle state line is always "Ready".
  - `Sources/EchoTypeApp/Views/PillView.swift`: a G2 correction; error text truncates from
    the end.
  - `docs/decisions/0007-known-gaps.md`: removed the two items.
- Decisions:
  - Tap callback: `hotkeyPressed` and `escapePressed` only change `phase`, which is what the
    consume decision reads, and start a `Task` for everything else (`dictate()`, `commit()`,
    `session.cancel()`, the abandon fade). Keeping the phase change synchronous means a
    second key event is judged against the right phase. `HotkeyMonitor` is unchanged.
  - Commit order is unchanged: `commit()` is `audio.stop()`, and the pump drains and then
    triggers.
  - Escape during starting sets `phase = .abandoned` and fades the pill at once. `dictate()`
    checks after `audio.start()` returns and again after the Keychain read; either way it
    stops the microphone and never builds the transport. Escape while abandoned is still
    consumed; Opt+D is ignored until the abandoned start unwinds, as it is while starting. A
    start failure after Escape shows no error.
  - "Audio flowing" is the first tap buffer delivered to the main actor (`onLevel`), not the
    first 100ms chunk off the stream. The pump does not read the stream until the session is
    listening, so the first chunk is not observable without a relay; the first delivered
    buffer is the moment from which speech is kept, at most one buffer (about 85ms) before
    the first chunk. A muted mic still switches to listening, with a flat meter.
  - Pill phase: `starting` until the first buffer, whatever the snapshot says; then
    `listening` or `paused` from the snapshot; `finalizing` and `inserting` map to
    `transcribing`; `idle` and `cancelled` leave it as is because the ending decides.
  - Endings go through `end(showing:)`. A mid-session microphone failure wins over the
    session's error, as the menu did before. The error pill fades after three seconds from
    a cancellable task that the next press cancels before showing its own pill.
  - Level mapping: linear in dB from -50 dBFS (0) to -20 dBFS (1). Speech at about -30 dBFS
    reads about two thirds. Aidan may tune it at G2.
  - Every Accessibility read in the placement lookup has a 0.25s messaging timeout on its
    own element (after remediation O1), because the lookup runs on the main thread that
    also serves the tap; a hung frontmost app would otherwise stall both for six seconds a
    read.
  - Click (flagged by workstream 2): a click commits only while a session is running and is
    ignored otherwise, because a click never opens a session: clicking an error pill, or a
    pill fading after a session, never starts the microphone (see drift). The second click
    of a double click needs no filtering, since `phase` stays `.running` until insertion
    finishes and a second `audio.stop()` does nothing.
  - Error click, confirmed at G2 (E5): a click on a red error pill does nothing, and that
    is intended. Only Opt+D starts a session; a click only commits a running one. This
    follows the packet's Outcome ("Clicking it commits") and criterion 6, and is recorded
    as drift from the specification's "does the same as Opt+D".
  - Error text, corrected at G2 (E5): an error keeps its start and truncates from the end
    at two lines, because the start says what failed ("Connection failed: ...", "Microphone
    access is off. ..."). The transcript still truncates from the left. The change is
    `Transcript` in `Views/PillView.swift` only, so it needs no further hand verification.
  - Fade-then-show race (flagged by workstream 2): left as is. A show during the fade
    clears `isHiding` and the stale completion handler returns early, which is what a
    generation counter would also do. The real risk is whether the zero-length `animator()`
    group cancels the in-flight alpha fade, which a counter would not fix either. It is now
    reachable (Opt+D within 0.3s of a silent end or an error fade), so G2 should include it.
- Verification:
  - `swift build` clean, no warnings.
  - `timeout 120 swift test --disable-xctest`: 41 tests passed (39 before, plus the two
    `Overlay` tests).
  - `xcrun swift-format lint --recursive Sources Tests Package.swift`: exit 0, no output.
    `~/.local/bin/swift-format` is not installed.
  - `./scripts/run.sh` launched `EchoTypeApp`; `./scripts/run.sh --hud-demo` launched with
    the flag; `./scripts/run.sh` was run again afterwards so the normal app is left running.
    Nothing was seen or dictated.
- Known limitations or external checks (all for G2):
  - Everything in `EchoTypeApp` is compile-checked and read only: the starting-to-listening
    switch, the meter's feel at the chosen dB range, placement on a second screen, the
    click committing without taking focus, the error pill and its three seconds, and
    Escape during starting.
  - Sequences worth including: Opt+D within 0.3s of a pill fading; Escape immediately after
    Opt+D, then Opt+D again; a double click on the pill; a start with no API key seeded.
  - A window straddling two screens goes to the one holding its centre; a window whose
    centre is off every screen falls back to the mouse.
- Specification drift:
  - The specification says clicking the overlay "does the same as Opt+D". Here a click
    commits a running session and does nothing otherwise, so clicking an error pill does not
    start a new session where Opt+D would. The packet's "Clicking it commits" and criterion 6
    support this reading, and a click should never start the microphone.
  - The packet says the pill switches to listening on the first audio chunk; it switches on
    the first tap buffer, up to one buffer earlier (see Decisions).

## External validation

- Gate and placement: G2, after focused closure and before acceptance
- Status: `Passed` (attempt 1, E5), with observation 10 pending
- Candidate and instructions: the uncommitted workstream 3 state on `feat/overlay` (base
  `dbbeee9`), after remediation and closure. From the repository root run
  `./scripts/run.sh`, which rebuilds, signs as `EchoType Dev` and relaunches the app. The
  pill is variant B from G1. Work through the eleven G2 observations in
  [plan.md](plan.md), then also try these sequences, which reading could not settle:
  - Opt+D within about 0.3s of a pill fading (after Escape, or after an error's three
    seconds). The new pill must appear and stay (review O3: a later fade may be cut short).
  - Escape straight after Opt+D, then Opt+D again. Nothing is inserted, and the second
    session starts normally.
  - A double click on a listening pill. It commits once and no second session opens.
  - A click on a red error pill. It does nothing (drift: only Opt+D starts a session).
  - Watch whether the pill ever says Listening while Opt+D is ignored for a moment
    (review O2, only if the Keychain read is slow).
  - Whether the meter's range feels right: quiet should sit near empty and ordinary speech
    around two thirds. Say if it should be more or less sensitive.
  - Optional, and only if you are happy to re-add your key afterwards: with no key under
    the `com.aidanzealley.echotype` Keychain service, Opt+D shows "No xAI API key in the
    Keychain" in red. Skip this if you would rather not touch the key.
  Quit from the menu bar item. The app already running from the last `./scripts/run.sh`
  is this candidate.
- Required evidence: see G2 in [plan.md](plan.md)
- Attempts and lasting decisions:
  - Attempt 1, published 2026-09-24 as E5. The escalation is E5 rather than the packet's
    E2, because G1 already used E1 to E4. Evidence so far: `swift build` clean, 41 tests
    passed, lint clean, and `./scripts/run.sh` relaunched the app. No one has looked at
    the pill or dictated.
  - Aidan's evidence (2026-09-24): observations 1 to 9 and 11 pass. Observation 10 was
    not tested because he has only one display; it is external validation still pending,
    not a failure. Opt+D just after a fade, Escape then Opt+D, a double click and the
    meter's sensitivity all behave as expected, so the dB range stays. He made no comment
    on the glow opacity, which stays as accepted in workstream 2.
  - A click on an error pill does nothing. The lead confirmed this is intended (see the
    Error click decision and the drift log).
  - The error pill showed its message truncated to the last two lines. The lead judged a
    message that loses its start unacceptable and made the smallest correction inside the
    gate: error text now truncates from the end. It touches only `Views/PillView.swift`,
    not window behaviour, the hotkey path or the start and commit path, so per E5 no
    further hand verification was requested. `swift build` clean, 41 tests passed, lint
    clean, and `./scripts/run.sh` relaunched the corrected app.
- Resume condition: met

## Independent review

- Reviewer: fresh independent review agent, 2026-09-24, against the uncommitted diff on
  `dbbeee9`.
- Verdict: acceptable for closure and G2. No required findings. Criteria 1 to 9 are met by
  reading; 10 is G2. `swift build` clean; `timeout 120 swift test --disable-xctest` 41
  passed; `xcrun swift-format lint --recursive Sources Tests Package.swift` exit 0, no
  output.
  - Focus: nothing new can make the panel key or main. `Panel` still refuses both, the
    only ordering call is `orderFrontRegardless()`, and the click handler only calls
    `audio.stop()`.
  - Tap callback (criterion 5): `hotkeyPressed` and `escapePressed` only assign `phase` and
    create tasks. The Accessibility lookup, `audio.stop()`, `session.cancel()` and every
    panel call run in those tasks. Assigning `phase` synchronously is the right call,
    because the next key event's consume decision reads it. Commit order from 0005 is
    unchanged: `commit()` is `audio.stop()`, then the pump drains and triggers.
  - Escape during starting (criterion 4): checked for Escape before `audio.start()`
    returns, between it and the Keychain read, and after the read. Each path stops the
    microphone, never builds the transport and hides the pill once. The order of the
    `end()` task and the `dictate()` task does not matter, because `end` and `updatePill`
    both guard on `pill`.
  - Level: RMS is measured before conversion, only while delivering, and a late buffer
    after `stop()` is dropped by the `isDelivering` guard. The interleaved branch uses
    `channels[0] + channel` with `buffer.stride`, which is correct. A zero RMS maps to 0
    through `-inf`.
  - Placement: the flip `primary.height - window.midY` is correct because `NSScreen.screens[0]`
    is the menu-bar screen with origin (0, 0).
  - Tests: both `Overlay` tests exercise real decisions with no fakes. The level test pins
    the tunable dB range loosely, through the noise-versus-speech property rather than
    exact values, which is acceptable. If G2 retunes the range the test changes with it.
- Required findings: none.
- Optional observations:
  - **O1. The Accessibility timeout covers only the first of three calls.**
    `AXUIElementSetMessagingTimeout(element, 0.25)` is set on the application element
    (`OverlayPanel.swift:106`). The position and size reads go to the window element that
    `copy` returns, which as far as I know is a separate reference with the global default
    timeout of about 6 seconds. If an app answers the focused-window read and then hangs,
    the main thread blocks for up to two such timeouts. While it is blocked, the event tap
    is not serviced, so every key press on the Mac stalls. Most hung apps fail the first read
    at 0.25s, so this is unlikely. The fix is one line: set the timeout on the window
    element as well, or once on `AXUIElementCreateSystemWide()`, which applies to the whole
    process.
  - **O2. The pill can say Listening while presses and clicks are still ignored.** The
    pill switches to listening on the first tap buffer (`levelChanged`), which arrives
    right after `audio.start()` returns. The controller stays `.starting` until after the
    detached Keychain read, when `phase = .running(session)`. In that window Opt+D and
    clicks are dropped even though the pill says Listening. The Keychain read normally
    takes milliseconds, so this is invisible. It only matters if the Keychain ever blocks,
    for example on an access prompt after a signing change, and then the pill would show
    Listening with a dead Opt+D. No audio is lost, since chunks buffer in the stream.
    Worth including in G2's sequences rather than changing now.
  - **O3. A stale fade completion can cut a later fade short.** Sequence: `hide()`
    (fade 1), `show()` within 0.3s (clears `isHiding`), then `hide()` again before fade 1's
    completion runs (sets `isHiding`). Fade 1's completion then passes its guard and calls
    `orderOut` early, so the second fade ends abruptly. This is reachable now through
    Opt+D within 0.3s of a fade followed at once by Escape. The effect is only visual. It
    fits the fade race the handoff already sends to G2, and a fix belongs in the panel
    contract, which is workstream 2's.
- Questions:
  - **Q1. Should a click on an error pill start a session, as Opt+D does?** The packet's
    scope says "A click on the pill takes the same path as an Opt+D press. While starting
    it is ignored, as the press is". The specification says clicking "does the same as
    Opt+D". `clicked()` commits only while `.running` and otherwise does nothing, so
    clicking an error pill does nothing where Opt+D would start a session. The handoff
    records this as drift. One of its reasons does not hold. `phase` stays `.running`
    through finalizing and inserting, until `dictate()`'s `defer`, so the second click of a
    double click already reaches `commit()` as a no-op under either reading. Routing the
    click through the press path would only add two new cases: a click on the red error
    pill starts a session, which is arguably what the spec intends, and a click during a
    silent end's 0.3s fade starts one, which is arguably unwanted. The lead should decide
    whether to keep this reading as drift or make `clicked()` do what `hotkeyPressed()`
    does, perhaps limited to while a pill is showing. Either is small.

## Resolution

- Recovery: a fresh lead inherited this workstream after the previous lead was cut off
  between the independent review and triage. The uncommitted diff is on base `dbbeee9`,
  every change lies inside this packet's ownership (plus the new `EchoTypeCore` overlay
  file and its tests, which follow the README's rule to put testable decisions in Core),
  and `swift build`, the 41 tests and lint were rerun clean before triage.
- Finding dispositions:
  - O1, promoted to Required. The Accessibility lookup runs on the main thread that
    serves the event tap. A window element left at the default timeout of about six
    seconds can stall every key press on the Mac and get the tap disabled. The fix is one
    line: bound the window element's reads as well.
  - O2, not changed. It is only visible if the Keychain read blocks. G2 sequences
    include it.
  - O3, not changed. The fade race is in workstream 2's panel contract, and a fix there
    would be an escalation. It is visual only, so G2 observes it and the final review
    decides whether it matters.
  - Q1, the handoff's reading is kept: a click commits a running session and does nothing
    otherwise. The packet's Outcome ("Clicking it commits") and criterion 6 describe a
    commit. Clicking a red error to start a new microphone session is surprising, and a
    click during a silent fade would do the same. The reviewer is right that the
    double-click reason is wrong, because `phase` stays `.running` until insertion. The
    code comment must give the real reason. This is recorded as drift.
- Simplification/deletion pass: O1 moved `AXUIElementSetMessagingTimeout(_, 0.25)` from
  the application element in `focusedWindowFrame()` into the `copy` helper, so every
  Accessibility read in the lookup (focused window, position, size) bounds its own element
  and nothing else is added. The process-wide system-wide timeout is untouched. Q1 rewrote
  the `clicked()` doc comment to give the real reason (a click never opens a session, so
  clicking an error pill or a fading pill never starts the microphone), with no behaviour
  change, and corrected the handoff's Click decision and first drift bullet to match. The lead
  updated the handoff's timeout decision to match.
- Final verification: `swift build` clean, no warnings. `timeout 120 swift test
  --disable-xctest`: 41 tests passed. `xcrun swift-format lint --recursive Sources Tests
  Package.swift`: exit 0, no output. `./scripts/run.sh` rebuilt, re-signed and relaunched
  `EchoTypeApp`, which is running. Nothing was seen or dictated, so the bounded lookup and
  click behaviour remain G2 checks.

## Closure review

- Verdict: closed, ready for G2. Both accepted findings are fixed and the fixes introduce
  no release-blocking defect. `swift build` clean; `timeout 120 swift test
  --disable-xctest` 41 passed; `xcrun swift-format lint --recursive Sources Tests
  Package.swift` exit 0, no output.
  - O1: `copy(_:of:)` in `OverlayPanel.swift` calls `AXUIElementSetMessagingTimeout(element,
    0.25)` before its one `AXUIElementCopyAttributeValue`, and it is the only Accessibility
    read in the lookup. The focused-window read bounds the application element, and the
    position and size reads bound the window element, so a hung app costs at most three
    0.25s reads on the main thread. A failed or mistyped read returns `nil` and falls back
    to the mouse screen, as before.
  - Q1: `clicked()` still guards on `.running` and calls `commit()`, so behaviour is
    unchanged. Its doc comment now gives the real reason (a click never opens a session, so
    an error or fading pill never starts the microphone). The handoff's Click decision and
    first drift bullet say the same, and the double-click note now correctly says `phase`
    stays `.running` until insertion.
- Remaining required findings: none.

## Acceptance

- Decision: accepted by the workstream 3 lead, 2026-09-24.
- Criteria 1 to 9 are met by reading, review and closure, and confirmed by Aidan at G2.
  Criterion 10: G2 passed on Aidan's evidence, except observation 10 (second display),
  which is external validation still pending for the completion report. Criterion 7 is
  therefore checked by reading and by the `Overlay.screenIndex` test only.
- Drift: a click commits a running session and does nothing otherwise, including on an
  error pill; the pill switches to listening on the first tap buffer rather than the first
  chunk; error text truncates from the end while the transcript truncates from the left.
- Deferred for the final review: review O2 (Listening shown while a slow Keychain read
  still ignores Opt+D) and O3 (a stale fade completion can cut a later fade short, in
  workstream 2's panel). Neither was seen at G2.
