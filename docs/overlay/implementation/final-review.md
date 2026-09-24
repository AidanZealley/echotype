# Overlay whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved specification's Overlay section. Read the accepted handoffs, then review the
combined diff and surrounding code independently.

Audit:

- Completeness against the specification's Overlay section and the plan's whole-feature
  acceptance.
- The seams: snapshots from `SessionMachine`, the pill value, `OverlayPanel`, and the
  level from `AudioCapture`. Look for state held twice, for example a phase the
  controller tracks that a snapshot already carries.
- Lifecycle: the pill, the microphone and the socket each end on every path (insert,
  nothing, failure, Escape during starting and during a session, the silence close, the
  hard cap).
- Focus: nothing anywhere can make the panel key or main.
- The event tap callback does no work beyond deciding whether to consume.
- Dependency direction: `EchoTypeCore` has no UI, no global state and no I/O.
- Leftovers from the variants: labels, switches, dead layouts or demo-only branches in
  live code.
- Tests: meaningful, not coupled to implementation details, no fakes of AppKit.
- Documentation: 0007 matches what is still open, and comments match the code.

Verification: `swift build`, `timeout 120 swift test --disable-xctest`, and
`swift-format lint --recursive Sources Tests Package.swift`.

## Initial whole-feature review

- Reviewer: Whole-feature reviewer (fresh subagent)
- Branch, base, and reviewed head: `feat/overlay`, base `d0139bc`, head `549c4db`
- Verification run:
  - `swift build`: clean. A fresh build into a separate scratch path also finished with no
    warnings.
  - `timeout 120 swift test --disable-xctest`: 41 tests passed.
  - `~/.local/bin/swift-format` does not exist on this Mac (see O4), so lint ran as
    `xcrun swift-format lint --recursive Sources Tests Package.swift`: exit 0, no output.
- Acceptance-criteria audit:
  - Specification Overlay section: met, with the approved departures in the drift log (the
    variant B layout and glow, and the click only committing). Everything else is there:
    the non-activating `NSPanel` with the specified properties, bottom centre of the focused
    window's screen, the bar meter driven by RMS, settled text solid and provisional text
    dimmed, left truncation at two lines, elapsed time counting up and turning amber at
    8:00, the hint line, the starting, listening, paused, transcribing and red error states,
    and the silent fade. Paused dims the meter and the timer and leaves the transcript at
    full contrast (`Views/PillView.swift:75`, `:147`).
  - Seams: `SessionMachine` publishes deduplicated `Snapshot`s and owns the only assembler
    (`SessionMachine.swift:151`, `:389-395`). `STTClient` keeps only the protocol. The pill
    renders one `Pill` value, and the demo and the controller both drive it through
    `OverlayPanel.show(_:on:)`. The controller keeps `state` (the menu's copy of the
    snapshot state), `phase` (the start and consume decision, which no snapshot carries) and
    `pill` (display phase, text and level). None of these holds another's state, except
    `AudioCapture.level` (O1).
  - Lifecycle, traced on every path in `DictationController.swift`:
    - Insert, nothing and failure: `run` always calls `audio.stop()` (`:165`),
      `SessionMachine.conclude` always closes the transport (`SessionMachine.swift:350`),
      and `finish` always calls `end(showing:)` (`:203`).
    - Escape during starting: `:74-77` fades the pill. `dictate` then checks `isAbandoned`
      after the microphone opens and again after the Keychain read (`:116-120`), stops the
      microphone and never builds a transport. Nothing can suspend between the second
      check and `phase = .running` (`:120-130`), so no socket can open after an Escape.
    - Escape in a session: `session.cancel()` (`:81`) closes the socket, and the ending
      then follows the "nothing" path above.
    - Silence close and hard cap: both end inside the machine
      (`SessionMachine.swift:300-311`), so the snapshot stream finishes and the same `run`
      and `finish` path releases the microphone and ends the pill.
    - Missing key and microphone failure: `:121-124` and `:115-116`.
    - After the pill ends, `updatePill` guards on `pill` (`:227`), so a late level or
      snapshot cannot show it again. Before each new press `errorFade` is cancelled
      (`:211`).
  - Focus: `Panel` is private to `OverlayPanel`, returns false from `canBecomeKey` and
    `canBecomeMain`, uses `[.borderless, .nonactivatingPanel]` from init, and is only ever
    ordered in with `orderFrontRegardless()` (`OverlayPanel.swift:20-26`, `:51`, `:74-75`).
    `sendEvent` takes `leftMouseDown` before anything in SwiftUI can handle it (`:78-84`).
    I found nothing that calls `makeKey`, `makeMain`, `activate` or `makeKeyAndOrderFront`.
  - Event tap: `hotkeyPressed` and `escapePressed` (`DictationController.swift:56-84`) only
    assign `phase` and create tasks. `audio.stop()` is out of the callback, and
    `HotkeyMonitor` is unchanged. The placement lookup's Accessibility reads run in the
    `dictate` task, not in the callback, and each read has a 0.25s timeout.
  - Dependency direction: `EchoTypeCore/Overlay.swift` is pure arithmetic on
    `CGRect`/`Float`. It adds no UI, no global state and no I/O.
  - Variant leftovers: none. There are no labels, `edge` parameters, `PillA`/`PillB`/`PillC`,
    `Accent` or glow forms. `PillDemo` is the specification's `--hud-demo` and drives the
    real panel.
  - Tests: the new snapshot, assembler and `Overlay` tests assert observable behaviour
    against recorded frame shapes, an injected clock and plain geometry. They add no fakes
    of AppKit or AVFoundation. `SnapshotLog` is test plumbing over the real stream, and the
    `ScriptedTransport` it relies on existed before this milestone.
  - Scope: no settings window, hotkey dropdown, device picker, keyterms editor, launch at
    login or `install.sh` in the diff.
  - Documentation: 0007 dropped the three items the milestone resolved, which is correct.
    Code comments match the code, except the small ones below.
- Required findings by owner: none.
- Optional observations:
  - O1, simplification. `AudioCapture` stores `level` (`AudioCapture.swift:27-29`), resets
    it in two places (`:58`, `:108`) and fires an argument-less `onLevel` (`:32`, `:95`).
    Its only reader is `DictationController.levelChanged`, which copies it straight into
    `Pill.level` (`DictationController.swift:218-222`). The level is therefore held twice.
    If `onLevel` passed the level as an argument (`@MainActor (Double) -> Void`), the stored
    property and both resets could go.
  - O2, documentation. The second-display placement (G2 observation 10) is now verified
    only by reading and by `screenHoldingWindow`. The plan records it as pending external
    validation, but 0007's "Verified only by reading" item (`0007-known-gaps.md:8-9`) does
    not list it, and 0007 is the record that survives retirement. Adding it there, or making
    sure the retirement step carries it over, would keep 0007 matching what is still open.
  - O3, documentation at retirement. 0006's state-line bullet (`0006:17-18`) now describes
    superseded behaviour: the menu shows only the session state, and failures show in the
    pill. The drift log already records the change, and 0006's title anticipates it. When
    the workflow retires, 0006 needs a status or consequences update alongside the 0003
    update the plan already calls for.
  - O4, workflow documentation. `README.md:32` says `swift-format` is at
    `~/.local/bin/swift-format`, but it is not installed there. Every agent in this
    milestone, including this review, used `xcrun swift-format`. Correct the path in the
    README or the workflow template when the workflow retires.
  - O5, comment. `Overlay.level`'s doc says ordinary speech "lands around the middle"
    (`Overlay.swift:10-11`). The mapping puts -30 dBFS at 0.67, and the workstream 3
    handoff and the test comment describe that as about two thirds. The doc could say
    "about two thirds".
- Questions: none.
- Verdict: accept. No Required findings. The lifecycle, focus, tap and seam paths read as
  correct on every ending I traced. O1 is the one simplification worth doing now if the lead
  wants it. O2 to O5 are documentation.

## Lead triage

- Accepted findings and owners: promoted and sent to one fresh implementation agent
  owning the files below.
  - O1, owner `AudioCapture.swift` and `DictationController.swift`. The level was held
    twice, which the packet asks the review to find. `onLevel` now passes the level and
    the stored property and its resets are gone. Behaviour is unchanged: the first call
    after `start()` still flips a starting pill to listening, and the `isDelivering` guard
    stays. It changes a callback's signature, not the panel, the hotkey path or the start
    and commit sequence, so it does not call for another hand verification.
  - O2, owner `docs/decisions/0007-known-gaps.md`. 0007 survives retirement, so the
    unverified second-display placement belongs there now.
  - O4, owner `README.md`. The lint command every agent is told to run did not exist.
  - O5, owner `Sources/EchoTypeCore/Overlay.swift`. The comment disagreed with the maths.
- Rejected findings and reasons: none.
- Deferred optional observations: O3. Decision records are rewritten when the workflow
  retires, as the plan already arranges for 0003. The 0006 update is added to the drift
  log next to it so retirement picks it up.
- Drift requiring user decision: none.

## Focused closure

- Reviewed head: `549c4db` with uncommitted corrections
- Finding outcomes:
  - O1: fixed. `onLevel` is `@MainActor (Double) -> Void`, and the stored `level` and
    both resets are gone, with no remaining reader. `levelArrived` still returns early
    unless `chunker.isDelivering`, so a buffer measured before `stop()` is still dropped.
    `levelChanged(_:)` still sets `pill.level` and flips `.starting` to `.listening` on the
    first call, through `updatePill`, which still guards on `pill`. Dropping the zero reset
    changes nothing visible, because each press builds a fresh `Pill` with level 0
    (`DictationController.swift:213`).
  - O2: fixed. 0007's "Verified only by reading" item now lists the pill on the second
    display.
  - O4: fixed. The README's tooling note and its reviewer prompt template both use
    `xcrun swift-format`. The remaining `~/.local/bin` mentions are in historical
    handoffs and this record.
  - O5: fixed. The doc now says -30 dBFS lands at about two thirds, which matches
    `(-30 + 50) / 30 = 0.67`.
  - O3: deferred by the lead to retirement, as triaged. Not reopened.
- Final simplification assessment: the corrections remove state and add none. Nothing
  further to simplify.
- Remaining blockers: none. `swift build` is clean, `timeout 120 swift test
  --disable-xctest` passed 41 tests, and `xcrun swift-format lint --recursive Sources
  Tests Package.swift` exited 0 with no output.
- Verdict: accept.

## Completion record

- Final verification: on `549c4db` with the corrections, `swift build` clean,
  `timeout 120 swift test --disable-xctest` 41 tests passed, and
  `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.
- External validation pending: G2 observation 10, the pill on the focused window's screen
  with a second display. Recorded in 0007.
- Specification drift: none beyond the plan's log. The corrections change no behaviour.
  0006's menu state-line bullet is stale and is added to the log for retirement, beside
  0003's.
