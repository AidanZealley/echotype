# Workstream 02: Scrollable pill

Workflow status: draft. Workstream status: not started.

## Task packet

### Outcome

The pill previews the full revised transcript, grows to eight wrapped lines, then scrolls
within its glass outline while the status row and shortcut hint stay fixed.

### Scope

- First, build two or three structurally distinct A/B/C layout variants in `--hud-demo`
  using the real `PillView` tokens and primitives. Each shows eight-line overflow, fixed rows,
  soft top and bottom scroll edges, and text arriving while scrolled up. Present them to Aidan
  and stop for his choice. Keep production behavior unchanged during this candidate stage.
- After the choice, implement only the selected variant and remove unused prototypes. Keep
  the panel anchored to the bottom of the visible screen as it grows.
- Follow the bottom by default, preserve position after the user scrolls up, and follow again
  only when they return to the bottom. Reset on a new session. Include revisions that alter
  text before the viewport in the position check.
- Make trackpad, wheel, and scrollbar scrolling safe during dictation. If click-to-stop
  conflicts, remove it and its dead callback/comments rather than build hit-testing machinery.
  Keep the hotkey, Escape, and read-aloud controls working.
- Use the native soft scroll edge effect above and below the transcript under the fixed rows.
  Keep the existing pill glass as the main surface.

### Non-goals

Revision algorithm, HTTP parameters, settings, transcript storage, and a new glass material
system. Do not add a general scrolling component for other screens.

### Initial ownership

`Sources/EchoTypeApp/Views/PillView.swift`, `Sources/EchoTypeApp/Views/PillDemo.swift`, and
`Sources/EchoTypeApp/OverlayPanel.swift`. `Sources/EchoTypeApp/DictationController.swift`
transfers from stream 01 only if click-to-stop is removed. Update matching comments in files
you own and record superseded portions of `docs/decisions/0008-pill-design.md` and
`docs/decisions/0009-overlay-behaviour.md`. No other source files without a documented
compile or integration need.

### Required seams

- Consume the stream 01 `Pill` value without duplicating transcript or revision state.
- Preserve the current nonactivating panel and target-field focus. Scrolling and layout
  changes must not make it key or main.
- Error and read-aloud pills remain legible and do not inherit dictation scroll position.

### Acceptance criteria

- Aidan chooses a variant before production layout work begins; unchosen prototypes are removed.
- The transcript grows to eight wrapped lines, then scrolls without enlarging the panel.
  Status and hint remain visible. The panel's lower edge stays anchored.
- New words follow at the bottom; scrolling up keeps the reading position through additions
  and revisions; returning to the bottom resumes following. A new session starts at bottom.
- The native soft edge treatment is visible at overflow on both edges without obscuring text.
  Aidan verifies it in the actual Mac pill in light and dark mode after closure.
- Scrolling never stops dictation. Read-aloud and error states remain usable. The app builds.

### Targeted verification

Run `swift build` and `./scripts/run.sh --hud-demo` on the Mac for variants and selected layout.
Check a small visible screen, both themes, wheel/trackpad and any scrollbar, scroll-up while new
text arrives, revision before the viewport, a new session, and continued focus in the target
app. The user visual check is an external gate after closure. Leave `swift test` to the final
gate.

## External validation

- Gate and placement: Variant choice before implementation; visual approval after closure,
  before acceptance.
- Status: `Pending` for both gates.
- Candidate and instructions: Record demo launch command, variant labels or selected layout,
  and how to reach overflow in `--hud-demo` on the Mac.
- Required evidence: Aidan's chosen variant; later Aidan's approval of top and bottom soft
  edges in light and dark mode, or a concrete correction.
- Attempts and lasting decisions: `TBD`
- Resume condition: The orchestrator records Aidan's answer in the matching plan escalation
  and starts a fresh lead. That lead audits the uncommitted candidate before continuing.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

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
