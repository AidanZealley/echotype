# Workstream 2: Overlay panel and variants

Status: accepted.

## Task packet

### Outcome

`./scripts/run.sh --hud-demo` shows the pill cycling through every state with fake
transcripts, in a panel that never takes focus. Aidan chose the design from two or three
variants at gate G1, and only his choice remains in the code. Normal launches behave
exactly as before: no live session drives the pill yet.

### Sequence

This workstream runs the gate inside its loop, because the choice decides what the rest
of it builds:

```text
implementation pass 1: panel, pill value, demo, variants A, B and C
    -> gate G1: block; Aidan chooses (troubleshooting loop for adjustments)
    -> implementation pass 2: keep the chosen variant, apply adjustments, delete the rest
    -> independent review
    -> one remediation pass if required
    -> focused closure review
    -> accept
```

Pass 2 uses a fresh implementation agent that reads the pass 1 handoff and the G1 record.

### Scope

**The pill value.** One app-side value holding everything the pill shows: its phase
(starting, listening, paused, transcribing, or an error with its message), the settled
and provisional text, the input level (0 to 1), and when the session started. The view
renders this value and nothing else, so the demo and the live controller in workstream 3
drive it the same way. The view derives elapsed time from the start with a timeline, and
turns it amber at eight minutes.

Keep this value in `EchoTypeApp`. Map SessionMachine states onto it in workstream 3,
not here.

**The panel.** `OverlayPanel.swift`: an `NSPanel` shim hosting the SwiftUI pill, built to
the specification's Overlay section. `canBecomeKey` false, non-activating, floating,
`level` `.screenSaver`, shown with `orderFrontRegardless()`, `collectionBehavior`
including `.canJoinAllSpaces` and `.fullScreenAuxiliary`. Transparent background, no
shadow artefacts from the window itself. It shows, updates and hides the pill, fading on
hide, and reports a click on the pill to its owner. Place it at bottom centre of a
screen passed in by the caller. Choosing which screen is workstream 3's job, so the demo
passes `NSScreen.main`.

Taking focus is the failure that matters most here. If the panel ever becomes key or
main, the target field loses focus and insertion goes nowhere. Read every property and
call on the panel with that in mind.

**The demo.** `--hud-demo` on the command line shows the pill cycling through every state
on a loop, about three seconds each: starting; listening with text growing, dimmed
provisional text turning solid, and a moving level; a long transcript full of jargon that
truncates from the left; paused; elapsed past eight minutes, in amber; transcribing; an
error; and the silent fade. `scripts/run.sh` forwards its arguments to the app so
`./scripts/run.sh --hud-demo` works. The demo does not start the hotkey monitor or open
the microphone.

**The variants.** In pass 1, build two or three structurally distinct pill layouts,
labelled A, B and C. Each renders the same value and holds the same content the
specification lists: level meter, transcript, elapsed time, the hint `⌥D stop · esc
cancel`, and every phase. They differ in structure, not in colour or spacing. Starting
points, which you may replace with better ideas:

- **A, the specification literally.** One row: meter on the left, transcript in the
  middle on one or two lines, elapsed on the right. Hint line beneath in a dim weight.
- **B, text first.** A slim top strip holds the meter, a phase word and elapsed time. The
  transcript is the dominant element below it, with the hint at the foot.
- **C, the pill as the meter.** The level is expressed by the pill itself, for example
  bars along its edge or a fill that breathes with the voice. The body holds only the
  transcript; elapsed and hint are compact and muted.

The demo shows every variant through the same state cycle, stacked at bottom centre, each
labelled with its letter, so Aidan can compare them side by side.

All variants are roughly 420pt wide, use Liquid Glass (`glassEffect`), and work in both
dark and light appearance through system materials and semantic colours. The
specification's constraints hold for every variant: paused dims the meter and the
elapsed timer but not the text, errors show inline in red, the meter is small vertical
bars driven by RMS (or C's equivalent) and not decorative waveform art. Keep product copy
minimal and use no em dashes in it.

**Gate G1.** After pass 1, the lead fills in this record's External validation section
with the candidate and the exact command, adds escalation entry E1 to `plan.md`, sets the
row to `Blocked` and G1 to `Testing`, and returns. When Aidan asks for adjustments or a
blend of variants, the lead iterates candidates inside the gate. When he names a final
choice, G1 is `Passed`.

**Pass 2.** Keep the chosen variant, apply the agreed adjustments, and delete the other
variants, the variant labels and any machinery for switching between them. The demo then
shows the one pill. The code should read as if there had only ever been one design.

### Non-goals

- Driving the pill from a real session, the level from the microphone, or the click to a
  commit. That is workstream 3.
- Choosing the screen from the focused window. That is workstream 3.
- Following the caret.
- A settings pane, a variant setting, or any way to switch designs at runtime after G1.
- Custom menu bar icon assets.
- Snapshot tests or any test of the view. The demo and G1 are its verification.

### Initial ownership

- `Sources/EchoTypeApp/OverlayPanel.swift`, new
- `Sources/EchoTypeApp/Views/`, new
- `Sources/EchoTypeApp/App.swift`, for the demo launch only
- `scripts/run.sh`, to forward arguments

### Required seams

- Consumed: nothing from workstream 1 beyond knowing its handoff's snapshot shape, so the
  pill value's text fields match what a snapshot carries.
- Produced: the pill value and `OverlayPanel` described in the plan's cross-workstream
  contracts. Record their names and API in the handoff.

### Acceptance criteria

1. Gate G1 passed, with Aidan's choice and adjustments recorded below.
2. Only the chosen variant exists in the code. No variant labels, switches or dead
   layouts remain.
3. `./scripts/run.sh --hud-demo` cycles the pill through every phase listed above,
   including left truncation of a long transcript and amber elapsed time.
4. The panel's configuration matches the specification's Overlay section, and nothing
   in it can make the panel key or main.
5. The pill renders one value; the demo drives it through the same API the controller
   will use.
6. A launch without `--hud-demo` behaves as before: no pill, and dictation works.
7. The pill uses Liquid Glass and semantic colours and reads correctly in both
   appearances.

### Targeted verification

```bash
swift build
swift-format lint --recursive Sources Tests Package.swift
./scripts/run.sh --hud-demo
```

`EchoTypeCore` is untouched, so the test suite does not need to run. Launching the demo
proves only that it starts; how it looks is gate G1.

## Implementation handoff

- Base commit: `0c25e2f`
- Outcome: pass 2 done. `./scripts/run.sh --hud-demo` shows the one pill at bottom centre,
  driven by one `Pill` value through one `OverlayPanel`, cycling through every state. The
  pill is the design chosen at G1 (see External validation). A launch without the flag
  creates the controller exactly as before and never builds a panel.
- Files changed:
  - `Sources/EchoTypeApp/Views/Pill.swift`, new: the pill value.
  - `Sources/EchoTypeApp/Views/PillView.swift`, new: `PillView` and its private pieces,
    `LevelMeter`, `Transcript` (with `TailLayout` for left truncation), `Elapsed`,
    `LevelGlow` and `Pill.Phase.name`.
  - `Sources/EchoTypeApp/Views/PillDemo.swift`, new: the `--hud-demo` loop.
  - `Sources/EchoTypeApp/OverlayPanel.swift`, new: the panel.
  - `Sources/EchoTypeApp/App.swift`: `controller` is optional. `--hud-demo` leaves it nil,
    so no hotkey monitor or microphone, and starts `PillDemo.run()`. The menu reads
    "Overlay demo" in that case.
  - `scripts/run.sh`: `open "$app" --args "$@"`, plus a header line saying so.
- Decisions:
  - `OverlayPanel` is a plain class that owns a private `NSPanel` subclass rather than being
    one, so no owner can call `makeKey`, `makeMain` or `makeKeyAndOrderFront` on it. The
    subclass returns false from `canBecomeKey` and `canBecomeMain`. Style mask
    `[.borderless, .nonactivatingPanel]` is set at init (changing it later is unreliable),
    `isFloatingPanel`, `level = .screenSaver`, shown only with `orderFrontRegardless()`.
  - `hidesOnDeactivate = false`. `NSPanel` defaults it to true, and this app is never
    active, so the panel would otherwise never appear.
  - `collectionBehavior` adds `.ignoresCycle` to the specification's `.canJoinAllSpaces` and
    `.fullScreenAuxiliary`, which keeps the panel out of window cycling.
  - Clicks: the panel's `sendEvent` turns `leftMouseDown` into `onClick` and does not
    forward it, so nothing in the SwiftUI tree handles the click and there is no reliance on
    `acceptsFirstMouse`. A non-activating panel receives the event without activating the
    app.
  - Transparent window (`isOpaque = false`, clear background, `hasShadow = false`). The glass
    draws the shape and its own shadow, and `PillView` pads 16pt so that shadow is not
    clipped. The panel sizes to `hosting.fittingSize` on every `show`, so the pill can grow
    from one line to two, and sits 12pt above the bottom of `screen.visibleFrame`, so it
    clears the Dock.
  - `show` both shows and updates. Hiding fades alpha over 0.3s, then `orderOut`. A `show`
    during the fade cancels it (`isHiding`).
  - Layout: 420pt wide, `glassEffect` in a 22pt rounded rectangle. A slim 11pt strip holds
    the meter, the phase word and elapsed time; the 16pt transcript is below; the hint
    `⌥D stop · esc cancel` is right-aligned at the foot. The transcript shows no phase
    placeholder, since the strip names the phase; with no text it keeps one blank line.
    Errors replace the transcript with the message in red.
  - Left truncation uses a small `Layout` rather than `truncationMode(.head)`. `.head` is
    not reliable on multiline text. The layout measures the text at full height, caps it at
    the height of a hidden two-line text in the same font, and anchors it to the bottom, so
    the pill shows one line, or the last two lines of anything longer, with no line-height
    arithmetic.
  - The level meter is five capsules scaled by fixed weights of the one level, so it moves
    with the voice and draws nothing that is not driven by RMS. It is flat and faint while
    starting, dimmed while paused, replaced by a spinner while transcribing and a red
    triangle on error.
  - `LevelGlow` is a blurred (12pt) blue wave drawn behind the content and on the glass,
    clipped to the pill's shape, hanging from the top edge from about 8% of the pill's
    height at silence to about 70% at full level, fading lighter downward. It averages the
    last 4 levels in `@State` so it swells rather than jitters, and its
    `TimelineView(.animation)` runs only while listening. Opacity 0.4 listening, 0.25 and
    grey starting, 0.15 and still paused, 0 once transcribing or failed. It still renders
    only the `Pill` it is given; the value's API is unchanged.
  - Elapsed is a `TimelineView` ticking each second from `startedAt`, `m:ss`, orange from
    8:00, dimmed while paused.
  - The demo calls `OverlayPanel.show(_:on:)` with `NSScreen.main` and `hide()`, the same
    calls the controller will make, and passes a click handler that does nothing.
  - G1's lasting decision (Aidan, E1 to E4, final at E4): text-first layout B with its
    bar meter, plus the blue wave glow hanging from the top edge inside the pill, at a
    lower opacity than any candidate showed (the lead chose 0.4, 0.25, 0.15). Aidan may
    tune the opacity at G2.
- Pill value and `OverlayPanel` API:
  - `struct Pill: Equatable { var phase: Phase; var settled = ""; var provisional = "";
    var level = 0.0; var startedAt: Date }`.
  - `enum Pill.Phase: Equatable { case starting, listening, paused, transcribing,
    error(String) }`.
  - `settled` and `provisional` take `SessionMachine.Snapshot.settled` and `.provisional`
    as they are. `level` is 0 to 1 and already scaled for display: mapping RMS onto it is
    workstream 3's.
  - `@MainActor final class OverlayPanel { init(onClick: @escaping @MainActor () -> Void);
    func show(_ pill: Pill, on screen: NSScreen); func hide() }`. `show` also updates;
    `hide` fades.
- Pass 2 changes after G1:
  - The chosen pill became `PillView.body`; the candidate stack, its labels, the
    `edge: VerticalEdge` parameter and the `scaleEffect(y: -1)` bottom placement are gone.
  - Glow opacity lowered to 0.4 listening, 0.25 starting, 0.15 paused (E4).
  - `PillParts.swift` existed to share pieces between layouts. It is merged into
    `PillView.swift` and every piece is now private; the one-line `Hint` view is inlined.
  - The meter was drawn at A's size and scaled by 0.8 in the strip. Its sizes are now the
    ones it is shown at (18 by 14pt, 2pt bars), without `scaleEffect`, and the spinner is
    `.mini`. The triangle now takes the strip's 11pt font rather than a scaled default.
- Verification:
  - `swift build` clean, no warnings.
  - `xcrun swift-format lint --recursive Sources Tests Package.swift` exit 0, no output
    (`~/.local/bin/swift-format` is not installed on this machine; `xcrun` is the same
    tool).
  - `./scripts/run.sh --hud-demo` launches `EchoTypeApp --hud-demo`.
    `CGWindowListCopyWindowInfo` showed one on-screen window from the app, 452 by 138pt,
    horizontally centred near the bottom, and `lsappinfo front` still reported T3 Code in
    front. The process was then killed with `pkill -x EchoTypeApp`.
  - An empty argument list is forwarded as nothing under `set -u` in the system bash 3.2.
  - The test suite was not run: `EchoTypeCore` is untouched.
- Known limitations or external checks:
  - Nobody has looked at the pass 2 pill. The opacity change, and the meter now drawn at
    its own size rather than scaled, are for G2.
  - Never taking focus is established by reading and by the front app not changing on
    launch. Clicking the pill while typing in another app is for G2.
  - The fade-then-show race (a `show` inside the 0.3s fade) is correct by reading only; the
    demo leaves at least 1.5s between a hide and the next show. It relies on the
    zero-duration `animator()` group cancelling the fade. Workstream 3 makes it reachable
    (Opt+D just after an error fades), so its G2 run should include that sequence; if the
    pill stays invisible, replace `isHiding` with a generation counter.
  - `onClick` fires on every `leftMouseDown`, so a double click reports two. Workstream 3
    decides whether that needs filtering when a click means trigger.
- Specification drift: the pill's arrangement and its level glow depart from the Overlay
  section's single left-to-right row and its "not decorative waveform art". Aidan chose
  both at G1; recorded in the plan's decision and drift log. `.ignoresCycle` and
  `hidesOnDeactivate = false` only add to the section's panel properties.
- Remediation: for O1, `LevelGlow` takes its identity from `pill.startedAt`, so its
  smoothing history resets with each session; the pause drop is unchanged. For Q1, a
  comment in `OverlayPanel.show` explains that the zero-length `animator()` alpha
  animation is what cancels an in-flight fade-out. `swift build` is clean and
  `xcrun swift-format lint --recursive Sources Tests Package.swift` exits 0 with no output.

## External validation

- Gate and placement: G1, after pass 1 and before the independent review
- Status: `Passed` (attempt 4, E4)
- Candidate and instructions: see attempt 4 below. Attempt 1 was the uncommitted pass 1 state on `feat/overlay` (base
  `0c25e2f`). From the repository root run `./scripts/run.sh --hud-demo`. Variants A, B and
  C appear stacked at bottom centre, each labelled with its letter, cycling together
  through starting, listening with growing text, a long jargon transcript truncating from
  the left, paused, elapsed past eight minutes in amber, transcribing, an error and the
  silent fade. Switch System Settings > Appearance between Dark and Light while it runs.
  Quit from the menu bar item ("Overlay demo" > Quit EchoType). Clicks on the stacked
  panel are counted as pill clicks but do nothing in the demo. A normal
  `./scripts/run.sh` afterwards restores the usual app.
  - A, the specification literally: meter, transcript (up to two lines) and elapsed in one
    row, hint centred beneath.
  - B, text first: a slim strip with meter, phase word and elapsed; a larger transcript
    below; hint at the foot.
  - C, the pill as the meter: a line along the bottom edge spreads from the centre with the
    level; the body holds only the transcript, with a small muted row for hint, status
    icon and elapsed.
- Required evidence: see G1 in [plan.md](plan.md)
- Attempts and lasting decisions:
  - Attempt 1 (pass 1 candidate above): published 2026-09-24. Aidan's answer (E1,
    2026-09-24): B is the favourite, but C's level feedback was more explicit. Keep B's
    small bar meter and add a blue level bar like C's. Build three variants of B with that
    bar: B1 with the bar on the pill's top edge, inset from both ends; B2 with a subtle
    blurred glow behind the pill along its top edge; B3 a different idea of the lead's
    choosing. Delete A and C. Dark and light appearance both work.
  - Attempt 2, published 2026-09-24. Correction: `PillView.swift` now holds only `PillB`
    with an `Accent` for the bar's placement and a shared `LevelBar`; `PillA`, `PillC` and
    the transcript's phase placeholder are gone. The bar is system blue, its length follows
    the level, it is grey and short while starting, dimmed while paused and gone once
    transcribing or failed. From the repository root run `./scripts/run.sh --hud-demo`.
    B1, B2 and B3 appear stacked and labelled at bottom centre, cycling together through
    every state as before. Quit from the menu bar item. A normal `./scripts/run.sh`
    afterwards restores the usual app.
    - B1, edge: a 3pt bar centred on the pill's top edge line, inset 48pt from each end,
      spreading from its centre with the level.
    - B2, glow: an 8pt bar blurred by 8pt behind the glass along the top edge, spreading
      from its centre, so the pill's top lights up softly from behind.
    - B3, track (lead's choice): the bar moves inside B's strip, a faint track between the
      phase word and elapsed time that fills blue from the left with the level, so the
      strip reads as meter, state, level and time in one line and the pill's outline stays
      clean.
    - Evidence: `swift build` clean with no warnings, `xcrun swift-format lint` clean, and
      `--hud-demo` launched one window at layer 1000, alpha 1, 494 by 341pt at bottom
      centre, with QuickTime Player still the front app. No one has looked at it.
  - Aidan's answer (E2, 2026-09-24): none of B1, B2 or B3 yet. He expected the level
    feedback inside the pill, not on or outside its edge. Refine only the glow direction
    (B2) into three new variants: the glow sits inside the pill, is taller, is clipped by the
    pill's outer edge, and looks less uniform and more organic, a flowing blurred glow whose
    shape follows the waveform rather than a bar spreading evenly. Delete B1 and B3. Dark
    and light unchanged.
  - Attempt 3, published 2026-09-24. Correction: `PillB` draws a `LevelGlow` behind its
    content and in front of the glass, clipped to the pill's rounded rectangle, replacing
    `Accent` and `LevelBar`. Every form hangs from the top edge, reaches from about 8% of
    the pill's height at silence to about 70% at full level, is blurred by 12pt and fades
    from system blue to lighter blue downward. It is faint grey while starting, dimmed and
    still while paused, gone once transcribing or failed. The pill has only the current
    level, so the glow keeps the last 32 levels to give it a shape. From the repository
    root run `./scripts/run.sh --hud-demo`. Glows 1, 2 and 3 appear stacked and labelled at
    bottom centre, cycling together through every state as before. Quit from the menu bar
    item. A normal `./scripts/run.sh` afterwards restores the usual app.
    - 1, envelope: the glow's lower outline is the level over the last few seconds, newest
      at the centre and flowing outward to both ends, so a spoken phrase ripples out from
      the middle and settles.
    - 2, blobs: five soft blobs along the top, each swelling with the level a moment after
      the one nearer the centre and drifting slowly sideways while someone speaks, like a
      lava lamp driven by the voice.
    - 3, wave: a rolling wave across the top whose depth is the recent level. Its ripples
      move on their own while listening, but the wave flattens to a faint line when he is
      quiet, so it only moves in proportion to the voice.
    - Evidence: `swift build` clean with no warnings, `xcrun swift-format lint` clean, and
      `--hud-demo` launched one window at layer 1000, alpha 1, 494 by 398pt at bottom
      centre, with T3 Code still the front app. No one has looked at it.
  - Aidan's answer (E3, 2026-09-24): glow 3, the wave. He likes how it animates smoothly
    between states, and its size and position are right. Delete glows 1 and 2. Before
    choosing finally, compare two adjustments of it: lower opacity along the top, and the
    same lower-opacity wave inverted along the bottom edge. Size, position and state
    animation otherwise unchanged. Dark and light both work.
  - Attempt 4, published 2026-09-24. Correction: `GlowForm`, the envelope and the blobs are
    gone; `LevelGlow` draws only the wave, keeping the 4 levels the wave averaged. Its
    opacity drops by a third in every phase: 0.6 listening (was 0.9), 0.35 starting (was
    0.5), 0.2 paused (was 0.3), still gone once transcribing or failed. `PillB` takes an
    `edge`, and the bottom placement is the top one flipped vertically, so its shape,
    depth, blur, gradient and animation are identical, rising from the bottom edge with the
    bluest part at the edge. From the repository root run `./scripts/run.sh --hud-demo`.
    Two pills appear stacked and labelled at bottom centre, cycling together through every
    state as before. Quit from the menu bar item. A normal `./scripts/run.sh` afterwards
    restores the usual app.
    - T, top: the wave hangs from the pill's top edge, behind the strip and the transcript.
    - B, bottom: the wave rises from the pill's bottom edge, behind the hint and the
      transcript.
    - Evidence: `swift build` clean with no warnings, `xcrun swift-format lint` clean, and
      `--hud-demo` launched one window at layer 1000, alpha 1, 494 by 270pt at bottom
      centre, with T3 Code still the front app. No one has looked at it.
  - Aidan's answer (E4, 2026-09-24), final: T, the wave hanging from the top edge. G1
    passes with it. One adjustment: the glow's opacity lower still than 0.6 while listening,
    with no number given, so the lead picked 0.4 listening, 0.25 starting and 0.15 paused
    (about two thirds of attempt 4 again), still gone once transcribing or failed. No further
    G1 round; he sees it at G2 and can adjust it there. Dark and light both work (E1).
- Final choice for pass 2: B, text first, with its small bar meter, plus the blue wave
  `LevelGlow` hanging from the top edge inside the pill, clipped by its shape, at the
  attempt 3 size, depth, blur and state animation and the opacities above. Everything else
  from the G1 candidates is deleted.

## Independent review

- Reviewer: fresh independent review agent, 2026-09-24, against the uncommitted pass 2
  state on `feat/overlay` (base `0c25e2f`).
- Verdict: accept once R1 is done. The code meets acceptance criteria 2 to 7 by reading,
  and nothing in the panel can make it key or main. R1 covers the records only.
- Checks run: `swift build` clean. `timeout 120 swift test --disable-xctest` gives 39
  tests passing (`EchoTypeCore` is untouched). `xcrun swift-format lint --recursive
  Sources Tests Package.swift` exits 0. `/bin/bash` 3.2 with `set -u` forwards an empty
  `"$@"` as nothing and keeps `"a b"` as one argument, so the `run.sh` change is sound. A
  grep for `variant`, `PillB`, `Accent`, `edge`, `scaleEffect` and `PillParts` finds no
  leftover variant machinery. The demo was not launched, and nothing was looked at.
- Focus and event tap, by reading:
  - The panel is a private `NSPanel` subclass behind a plain class, so no caller can
    reach `makeKey*`. `canBecomeKey` and `canBecomeMain` are both false. The style mask
    `[.borderless, .nonactivatingPanel]` is set at init. `isFloatingPanel` is set before
    `level = .screenSaver`, so the level is not overwritten. The only ordering call is
    `orderFrontRegardless()`. There is no `NSApp.activate`. `hidesOnDeactivate = false` is
    correct and necessary for an `LSUIElement` app.
  - `sendEvent` consumes `leftMouseDown` before `super`, so AppKit's usual click-to-key
    path never runs for it. A later `leftMouseUp` reaches a hosting view that saw no down,
    which does no harm.
  - This diff does not touch `HotkeyMonitor` or the event tap callback.
  - A normal launch builds `DictationController()` exactly as before and never builds an
    `OverlayPanel`. `--hud-demo` leaves the controller nil, so `monitor.start()` and the
    microphone never run.
- Tests: none added. That is correct: the packet rules out view tests, and no fake panel,
  window server or tap was built.
- Required findings:
  - R1 (records, owned by the lead, not an implementation defect). The plan is the
    resume source, and workstream 3 reads it. It is stale:
    - The drift log row for the pill still says the wave sits "at the top or bottom edge
      as G1 is still choosing" and cites only E1 to E3. It should record the final
      choice: top edge, opacities 0.4, 0.25 and 0.15, per E4.
    - Escalation E4 is still in `plan.md`. The README says to copy its lasting decision
      and then remove the entry before accepting.
    - The handoff's "Specification drift: none" contradicts that drift row. The Overlay
      section gives the contents "left to right" and calls for "not decorative waveform
      art". The chosen strip-over-transcript layout and the self-rippling wave glow both
      depart from it. Aidan approved both at G1, so this is drift to record, not a defect.
      The handoff should say so, as the plan does.
- Optional observations:
  - O1. `LevelGlow.history` is `@State` in the one long-lived `NSHostingView`. It
    survives `hide()` and carries into the next session: `starting` draws a grey wave at
    the last session's average level rather than the faint 8% line. It also changes only
    in `onChange(of: pill.level)`, so a single drop to 0 on pause leaves the static paused
    wave at three quarters of the previous depth. The demo shows this, because pause sets
    the level once. In the silent-fade case, the hidden panel also keeps a `listening`
    pill, whose `TimelineView(.animation)` may keep scheduling frames while ordered out.
    One fix covers the first and third: `.id(pill.startedAt)` on `LevelGlow`, or letting
    workstream 3 show a non-listening pill before `hide()`. Cosmetic, and G2 would catch
    it.
  - O2. `show` runs `fittingSize` and `setFrame(_:display: true)` on every call.
    Workstream 3 will call it at the audio level's update rate. That is cheap enough, but
    calling `setFrame` only when the size changes costs one comparison.
  - O3. `Pill`'s own `Equatable` conformance is unused (only `Phase ==` is used). Remove
    it unless workstream 3 needs it to deduplicate updates.
  - O4. `onClick` fires on every `leftMouseDown`, so a double click reports two clicks.
    In workstream 3 a click means trigger, so a double click could commit and then act on
    the next state. Workstream 3 should decide whether to filter on `event.clickCount ==
    1` or rely on `SessionMachine` ignoring a trigger while finalizing.
- Questions:
  - Q1. The fade race is sound only if AppKit behaves as assumed.
    - How it works: `show` during a fade calls `panel.animator().alphaValue = 1` in a
      zero-duration group. This relies on that group cancelling the in-flight 0.3s alpha
      animation on an `NSWindow`.
    - If it does not cancel: the fade finishes at alpha 0 while the panel stays ordered
      in, and `isHiding` is already false. Every later `show` then returns early
      (visible, not hiding), so the pill stays invisible for the whole session. The
      README's worst failure, blind dictation, would return.
    - A second, milder case: hide, then show, then hide inside 0.3s. If the first
      group's completion fires at its original end, it sees `isHiding == true` and orders
      the panel out early.
    - Workstream 3 makes this reachable: an error shows, it fades, and Aidan presses Opt+D
      within 0.3s.
    - Suggestion: add a line to G2's evidence ("press Opt+D immediately after an error
      fades"). If the lead wants it right by construction instead, replace the `isHiding`
      flag with a generation counter checked in the completion handler, and set
      `panel.alphaValue = 1` directly as well as through the animator. In either case,
      add a comment on why the zero-duration animator group is there.

## Resolution

- Finding dispositions:
  - R1 accepted and done by the lead: the plan's drift row records the final G1 choice,
    E4's decision is in the handoff's Decisions and the entry is removed, and the
    handoff's drift line now names the drift.
  - O1 promoted and fixed in the remediation pass: `LevelGlow` takes identity from
    `pill.startedAt`, so its history resets per session and a hidden listening glow is
    discarded with the session. The pause drop to three quarters depth is left as is:
    paused is dimmed and still, and Aidan approved the state animation.
  - O2 declined: one `fittingSize` per level update is cheap, and workstream 3 owns the
    live call rate.
  - O3 declined: the derived `Equatable` costs nothing and workstream 3 may deduplicate
    updates with it.
  - O4 deferred to workstream 3, recorded under Known limitations.
  - Q1 answered: the zero-duration animator group is AppKit's usual way to interrupt an
    animator animation, so the design stays; a comment now explains it. The early
    `orderOut` in hide, show, hide within 0.3s only cuts a fade short. The reachable
    sequence is handed to workstream 3's G2 run under Known limitations.
- Simplification/deletion pass: pass 2 removed the candidate stack, labels, `edge`
  parameter and flipped placement, merged `PillParts.swift` into `PillView.swift` and
  dropped the meter's `scaleEffect`. Nothing added by remediation beyond one modifier and
  one comment.
- Final verification: `swift build` clean, `xcrun swift-format lint --recursive Sources
  Tests Package.swift` exit 0, `./scripts/run.sh --hud-demo` launched one window at bottom
  centre without changing the front app (pass 2). `timeout 120 swift test
  --disable-xctest` 39 passing (review).

## Closure review

- Verdict: `Accept`. Fresh closure session, 2026-09-24, against the uncommitted state on
  `feat/overlay`. Every accepted finding is fixed, and no fix introduces a release-blocking
  defect.
  - R1: the plan's drift row now records the final G1 choice (top edge, opacity 0.4, 0.25
    and 0.15, citing E1 to E4). Escalations reads "None open", and E4's lasting decision
    is in the handoff's Decisions. The handoff's drift line names both departures from
    the Overlay section. G1 is `Passed` in the plan.
  - O1 (promoted): `LevelGlow(pill:).id(pill.startedAt)` in `PillView.swift` resets the
    glow's `@State` history with each session. The panel and its focus properties are
    unchanged.
  - Q1: the comment in `OverlayPanel.show` explains why the zero-length `animator()` group
    is there. The reachable sequence is handed to workstream 3's G2 under Known
    limitations.
  - Checks: `swift build` clean. `xcrun swift-format lint --recursive Sources Tests
    Package.swift` exits 0 with no output.
- Remaining required findings: none.
