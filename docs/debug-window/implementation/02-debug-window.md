# Workstream 2: Capture and show the last dictation

Status: accepted.

## Task packet

### Outcome

`./scripts/run.sh --debug` opens a live Last Dictation window. A normal launch has no
debug recording or menu item. The window shows the most recent completed dictation,
supports JSON copy, and does not steal focus from the insertion target.

### Scope

- Wire `DictationController` to create one trace only for a real dictation that reaches
  `running`. Capture committed suffixes and timestamps from `SessionMachine.snapshots`;
  include the tail committed on `transcript.done` if it occurs. Fill outcome, streamed
  and inserted text after revision. Distinguish cancelled from empty using the last
  snapshot. Publish `lastTrace` once on completion. Keep `test()` and read-aloud out.
- Render the spec's summary, marked selectable text, expandable request list and Copy
  as JSON in a new SwiftUI `DebugWindow`. Use system colors in both themes.
- Add `--debug`, the launch window scene and menu item in `EchoTypeApp`. Share the
  Settings activation steps where both menu actions need them. Keep `.regular` while
  either Settings or Debug is open; return to `.accessory` after the last window
  closes. On a completed dictation, update the window without ordering or focusing it.
- Add the development command to `README.md`; write
  `docs/decisions/0023-debug-window.md` and link it from the decisions index. 0022
  already belongs to voice replies.

### Non-goals

No trace history, pause measurement beyond time between commits, debug setting,
release UI switch, changes to paste/send behavior, or broad UI test harness.

### Initial ownership

- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/App.swift`
- `Sources/EchoTypeApp/Views/DebugWindow.swift` (new)
- `README.md`
- `docs/decisions/0023-debug-window.md` (new)
- `docs/decisions/README.md`

Consume workstream 1's accepted Core API. Do not edit its files without escalation.

### Required seams

- Use `DictationTrace` as both the rendered and JSON-encoded value. With debug off,
  avoid accumulating trace data, disable Reviser attempt capture, and keep `lastTrace` nil.
- Preserve current `DictationController` reply-request detection, send decision and
  `finish` ordering from [decision 0022](../../decisions/0022-voice-replies.md).
  The trace's `inserted` field is the text actually passed to the inserter, or empty
  when none was passed. A failed session may still insert surviving committed text.
- The Settings and Debug windows share activation behavior without making completion
  of a dictation an activation event. The `--hud-demo` path remains usable.

### Acceptance criteria

- The normal app has no debug menu item, window or recorded trace. Debug launch shows
  "No dictation yet" and its menu item reopens a closed window.
- Inserted, failed, cancelled and empty dictations replace the last trace. The Test
  button does not. Commit and request rows explain the resulting inserted text.
- Text remains selectable and wraps as one paragraph, with deletion, changed form,
  commit boundary and hover details from the spec. JSON copy contains the whole trace.
- A dictation ending while an editor has focus updates the already open window and
  inserts into the editor. Either window can close while the other keeps the Dock icon.
- README and decision record describe the delivered behavior accurately.

### Targeted verification

```sh
swift build
./scripts/run.sh --debug
```

Use `swift test` at the Mac gate and final review as the spec requires. Do not launch
the app during an active user dictation. Record build results and any checks the agent
can perform in the handoff; G1 covers the remaining interactive behavior.

## Implementation handoff

- Base commit: `d34e023`
- Outcome: Implemented. `./scripts/run.sh --debug` starts the app as a regular app with
  the Last Dictation window presented, and **Last Dictation…** below **Settings…**
  reopens it. A normal launch has no item, a suppressed window with no Window menu entry,
  and `DictationController.lastTrace` stays nil. Each dictation that reaches `running`
  replaces the trace when it ends. The window shows the summary line, the marked
  paragraph, one expandable row per request and Copy as JSON.
- Files changed: `Sources/EchoTypeApp/DictationController.swift`,
  `Sources/EchoTypeApp/App.swift`, `Sources/EchoTypeApp/Views/DebugWindow.swift` (new),
  `README.md`, `docs/decisions/0023-debug-window.md` (new), `docs/decisions/README.md`.
- Decisions:
  - The controller takes `debug:` and exposes it as `let debug`. The app derives its
    debug state from `controller?.debug`, so `--hud-demo` (no controller) ignores
    `--debug`: it records no dictation, and a window that could never fill would mislead.
  - `dictate` creates the trace only in `.started`, after `phase = .running`, and passes
    `capture: debug` to `Reviser`. `run` appends a commit for each committed-text growth
    inside the existing growth check, which still gates the reply-request commit
    unchanged. It keeps `streamed` as the last snapshot's committed text and records
    `.cancelled` from a `.cancelled` snapshot. `test()` never has a trace because
    `trace` is only set in `dictate`. With debug off, every `trace?` access
    short-circuits, so nothing accumulates.
  - `publishTrace` runs after `finish`, so the reply-request decision, send and `finish`
    ordering are untouched. It mirrors `finish`: `inserted` is the `.insert` or `.failed`
    text (`""` for `.nothing`), and an audio failure wins over the session error, as it
    does in the pill. It reads `reviser.attempts` without waiting for a cancelled call.
  - Activation: `SettingsButton` became `WindowButtons`, whose two items share
    `presentWindow`. It raises `orderedWindows.first` main-capable visible window, the
    one just opened, where the old code raised `windows.first`, which could pick the
    wrong window with two open. Both scenes' `onDisappear` call `windowClosed`, which on
    the next main-queue turn returns to `.accessory` only when no main-capable window is
    visible or minimised. The debug launch sets `.regular` in `init`, because the window opens without
    a menu click. A completed dictation only changes `lastTrace`.
  - The marked paragraph is a non-editable, selectable `NSTextView` (TextKit 1, sized
    with `sizeThatFits`) built from one attributed string. SwiftUI `Text` cannot show
    hover text for part of a paragraph. Deleted words are `systemRed` struck through,
    changed words `systemOrange` with the streamed form as a tooltip, and a
    `tertiaryLabelColor` `|` before each commit start carries the gap to the previous
    commit as a tooltip. All colours are system colours.
  - The summary's word count is the streamed word count (`marks.count`). A request row's
    word count splits the window at whitespace, since `Prose` is internal. `.nothing`
    shows as `empty`. JSON is pretty-printed with sorted keys and ISO 8601 dates.
- Verification: `swift build` passes with no warnings (after touching every app source
  to force a full recompile). `swift test` passes all 69 tests. `./scripts/build-app.sh
  debug /tmp/EchoType-ws2.app` built and signed the bundle; it was then deleted.
  `./scripts/run.sh --debug` was not run: `deploy.sh` runs `pkill -x EchoTypeApp`, which
  would stop Aidan's running development instance and the `EchoTypeApp --mcp` processes
  serving agent sessions. Launching the built bundle beside the running instance would
  put two hotkey monitors on the same keys. No interactive check was done.
  Remediation: `requestCounts` now orders counts by a private `ResultKind: String,
  CaseIterable` enum instead of placeholder `Result` values, and its raw values also
  label the rows, so the summary output is unchanged. `windowClosed` counts a minimised
  main-capable window as open. The debug `Window` scene has
  `.restorationBehavior(.disabled)`. 0023 notes that the helper replaces 0011's
  `SettingsButton`, and that a silent session ends through `cancel()` and records as
  cancelled. `swift build` passes with no warnings and `swift test` passes all 69 tests.
- Known limitations or external checks: G1 must check everything interactive,
  especially: the debug launch comes to the front as a regular app (the policy is set in
  `App.init`); `orderedWindows` raises the window just opened when the other is already
  open; closing either window keeps the Dock icon while the other is open; tooltips
  appear on changed words and commit marks; the paragraph wraps and sizes correctly at
  different widths; a dictation ending with an editor focused updates the window without
  raising it. Selecting and copying the paragraph includes the `|` marks. Hyphen
  stutters render as two words (`I` struck, `I'm`), per workstream 1.
- Specification drift: The spec asks for one SwiftUI `Text` built from
  `AttributedString` runs. That cannot show the required hover text, so the paragraph is
  an `NSTextView` from one attributed string, which keeps paragraph wrapping and
  selection. Recorded in 0023. No Core contract concerns.
- Lasting decisions from E1 (Aidan, 2026-09-29): G1 passed on this candidate, with every
  check run by Aidan. Follow-up scope decision: Last Dictation becomes a normal feature
  for everyone, with the debug gate removed from the whole window, including the
  diagnostic detail. This workstream is accepted exactly as validated, with the gate.
  A new workstream 3 removes the gate and updates the spec, 0023 and the README before
  the final review. Logged in plan.md.

## Independent review

- Reviewer: fresh general-purpose subagent, reviewing the uncommitted diff on `d34e023`.
  Checks: `swift build` (clean) and `swift test` (69 passed). Nothing interactive was
  run; `./scripts/run.sh` was deliberately not launched.
- Verdict: Accept.
- Required findings: none. Checked and found correct:
  - Capture: the trace is created only in `.started`, after `phase = .running`
    (`DictationController.swift:259-260`). `test()` never creates one, because `trace` is
    only set in `dictate` and `phase` rules out overlap. The commit loop's suffix
    (`:426-434`) sees the `transcript.done` tail, because `observe` publishes before
    `conclude` (`SessionMachine.swift:197-199`). Cancelled comes from the `.cancelled`
    snapshot, and `.nothing` otherwise keeps the default. `inserted` matches what
    `finish` passes: `.insert` text always, `.failed` text (empty means no call). An
    audio failure wins over the session outcome, as in the pill. With debug off, every
    `trace?` is nil, `capture: false` is passed and `lastTrace` is never set.
  - 0022 ordering: the reply-request `commit()` has the same growth and match guard as
    before. `sends` and `finish` are unchanged, and `publishTrace` runs after `finish`.
  - Activation: one shared `presentWindow`, `windowClosed` checks for a visible
    main-capable window on the next turn, and completion only assigns `lastTrace`.
    `--hud-demo` has no controller, so `debug` is false and the scene is suppressed and
    empty.
  - Rendering: the summary format, strikethrough and colours, amber changed word with the
    streamed form as tooltip, `|` mark with the commit gap as tooltip, rows in start order
    with `rejected at "word"`, and JSON of the whole `DictationTrace` all match the spec.
    `commits[commit - 1]` cannot go out of range, because `marks` never assigns commit 0.
    The `NSTextView` deviation is justified, since SwiftUI has no per-run hover. The
    TextKit 1 `sizeThatFits` measures at the proposed width. `widthTracksTextView` keeps
    the container at the placed width. Dynamic `NSColor`s re-resolve when the theme
    changes.
  - README and 0023 describe the delivered behaviour accurately, including the hyphen
    and copied-mark consequences.
- Optional observations:
  - O1. Request rows count window words with a whitespace split (`DebugWindow.swift:63`),
    but the summary uses `Prose` (`marks.count`). `well-known` counts as 1 in a row and
    2 in the summary. It rarely matters. Matching would need `Prose` to be public, which
    is a frozen Core change, so leave it.
  - O2. Request row labels (`DebugWindow.swift:64-68`) are not selectable. The summary,
    window and reply are. The spec says "Keep the text selectable". Adding
    `.textSelection(.enabled)` may fight the disclosure toggle, so check at G1 before
    changing it.
  - O3. `requestCounts` builds placeholder values `.rejected(word: "")` and `.failed("")`
    only to get ordered kind strings (`DebugWindow.swift:180-185`). An ordered string
    array with the same `kind` names would say the same with one concept fewer.
  - O4. `windowClosed` counts a minimised window as not visible. If one window is
    minimised and the other is closed, the app goes back to accessory, and the minimised
    window loses its Dock tile until reopened from the menu. This is an edge case that
    0011 already had with Settings alone.
  - O5. `endedAt` is set after `finish`, so a sent dictation's duration includes the
    200 ms Return delay. That's negligible for diagnosis.
  - O6. Lead records: plan.md's drift log has no entry for the `NSTextView`-for-`Text`
    drift, which is recorded only in 0023 and this handoff. 0011 still names
    `SettingsButton` and a single `onDisappear`. Records are historical, so this needs a
    pointer to 0023 at most.
- Questions:
  - Q1. A session with no speech is ended by `deadlineReached` calling `cancel()`
    (`SessionMachine.swift:251-258`), so under the spec's rule it is recorded as
    `cancelled`, the same as Escape. `empty` appears only for a triggered session with no
    text. This follows the spec literally. Is that the intended reading, or should
    silence show as `empty`? Changing it would need a signal from Core.
  - Q2. The debug launch sets `.regular` in `App.init` but never activates or raises the
    window, as `presentWindow` does. That relies on LaunchServices activating the app
    that `open` launches. G1 should confirm the window comes to the front at launch.
  - Q3. A normal launch now declares a `Window` scene. G1 should confirm it stays hidden
    in two cases. First, after quitting a `--debug` launch with the window open (state
    restoration versus `.suppressed`). Second, when clicking the Dock icon while Settings
    is minimised (SwiftUI's reopen). If either shows the window, add
    `.restorationBehavior(.disabled)` or check `debug` in the content.

## Resolution

- Finding dispositions (no Required findings; one remediation pass for cheap items that
  protect acceptance criteria):
  - O3 accepted: the summary's count order comes from a private `ResultKind` enum rather
    than placeholder `Result` values. The output did not change.
  - O4 accepted: `windowClosed` counts a minimised main-capable window as open, so the
    Dock icon stays while either window is still open.
  - Q3 accepted in part: `.restorationBehavior(.disabled)` on the debug scene, so a
    normal launch cannot restore a window left open by a debug launch. Reopening from
    the Dock while Settings is minimised is left to G1.
  - Q1 answered: a silence-timeout session records as `cancelled`. This follows the spec's
    last-snapshot rule and is now noted in 0023. No Core change.
  - O6: 0023 now says the helper replaces 0011's `SettingsButton`. 0011 is a historical
    record and stays unedited. The lead logged the `NSTextView` drift in plan.md's
    drift log after closure, which closes closure's record gap.
  - Rejected: O1, because matching `Prose` word counts would change the frozen Core. O2,
    because making the disclosure label selectable may break the toggle; the window and
    reply text are selectable. O5, because 200 ms is negligible for diagnosis.
  - Q2 was left to G1.
- Simplification/deletion pass: `SettingsButton` became one `WindowButtons` view with a
  shared `presentWindow` helper. Remediation removed the placeholder-value ordering. No
  wrappers or flags were added beyond `debug` and the trace.
- Final verification: after remediation, `swift build` is clean and `swift test` passes
  69 tests (implementation agent).

## Closure review

- Reviewer: fresh session, checking the Resolution's fixes on the uncommitted diff over
  `d34e023`. After touching every app source, `swift build` is clean with no warnings,
  and `swift test` passes 69 tests. No Core or test files changed. Nothing interactive
  was run.
- Verdict: Accept.
- Remaining required findings: none. Fixes verified:
  - O3: `requestCounts` (`DebugWindow.swift:178-185`) orders counts by
    `ResultKind.allCases` (`:189-193`), and each `Result` maps to its kind through an
    exhaustive switch (`:196-207`). The raw values keep the old labels, including
    `reply request removed`, and `label` (`:210-216`) uses them for the rows, so the
    summary and row text are unchanged.
  - O4: `windowClosed` (`App.swift`) treats a main-capable window as open when it is
    `isVisible || isMiniaturized`. A closed window is neither, so the app still returns
    to accessory after the last window closes.
  - Q3: the debug `Window` scene has `.restorationBehavior(.disabled)` next to
    `.defaultLaunchBehavior(debug ? .presented : .suppressed)`. The target is macOS 26,
    so the API is available.
  - 0023 says a silence timeout records as cancelled, which matches
    `SessionMachine.deadlineReached` calling `cancel()` when nothing was heard. It also
    says the shared helper replaces 0011's `SettingsButton`.
- Non-blocking record gap: the Resolution says the `NSTextView` drift "is logged in
  plan.md", but plan.md's drift log has only workstream 1's `Mark.commit` entry. The
  drift is recorded in 0023 and in this packet's handoff. The lead should add the log
  row or correct the Resolution before acceptance.

## External validation

- Gate and placement: G1, after focused closure and before acceptance.
- Status: Passed (Aidan, 2026-09-29, plan E1).
- Candidate and instructions: branch `debug-window`, head `d34e023` plus this
  workstream's uncommitted diff. `swift test` passes (69 tests) on the candidate. Build
  and launch it with `./scripts/run.sh --debug`, then `./scripts/run.sh`, and follow
  every item in the [spec's Final gate](../../specs/debug-window.md#final-gate).
  Also check the review's G1 items. At a debug launch, the window comes to the front.
  When the other window is already open, the one just opened is raised. Tooltips show
  on changed words and commit marks. The paragraph wraps and resizes. On a normal
  launch, clicking the Dock icon while Settings is minimised does not open Last
  Dictation. A Last Dictation window left open when quitting a `--debug` launch does
  not reappear on a normal launch.
- Required evidence: a concise pass/fail result for launch with and without `--debug`,
  representative dictation and request rows, editor focus and insertion, cancellation,
  JSON copy, simultaneous windows and both themes. Note who checked each item.
- Attempts and lasting decisions:
  - Attempt 1 (agent): `swift build` and `swift test` (69 tests) pass. No interactive
    item was checked, so the row blocked for Aidan's observation (plan E1).
  - Attempt 2 (Aidan, 2026-09-29): he ran every G1 check on this candidate himself and
    reported that all of them passed. This covers the spec's Final gate: launch with
    and without `--debug`, representative dictation and request rows, editor focus and
    insertion, cancellation, JSON copy, simultaneous windows and both themes. It also
    covers the review's extra items: the window comes to the front at a debug launch,
    the window just opened is raised, tooltips, wrapping and resizing, the Dock reopen
    with Settings minimised, and no restored window on a normal launch. The evidence is
    Aidan's report as relayed in E1. No per-item notes were supplied.
  - Before commit the resuming lead confirmed the candidate had not changed since
    closure. Every app source and 0023 was last modified before the closure section was
    written, Core and tests are unchanged from `d34e023`, and `swift build` is clean.
- Result: every listed item has passing evidence. G1 passed.
