# Workstream 2: Overlay panel and variants

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Pill value and `OverlayPanel` API: `TBD`
- Variants built in pass 1: `TBD`
- Pass 2 changes after G1: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## External validation

- Gate and placement: G1, after pass 1 and before the independent review
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: see G1 in [plan.md](plan.md)
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan names one variant, optionally with adjustments

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
