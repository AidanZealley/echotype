# Workstream 3: Make Last Dictation a normal feature

Status: accepted.

## Task packet

### Outcome

Last Dictation is a normal feature of the main app. Every launch through
`./scripts/run.sh` or the installed app records the last dictation and shows
**Last Dictation…** below **Settings…**. The window shows everything workstream 2
delivered, including revision attempts, raw replies, timings and marks. `--debug` no
longer exists, and nothing else about normal dictation, read-aloud, reply requests or
Settings changes.

### Source of truth

- Aidan's decision of 2026-09-29, the last row of the decision and drift log in
  [plan.md](plan.md). It overrides the spec where they conflict.
- [The debug window spec](../../specs/debug-window.md), apart from its debug gate.
- [Decision 0023](../../decisions/0023-debug-window.md), and
  [0022](../../decisions/0022-voice-replies.md) for reply-request behavior.
- The accepted handoffs in [01-trace-core.md](01-trace-core.md) and
  [02-debug-window.md](02-debug-window.md), and the code they committed.

### Scope

- **Reviser.** Remove the `capture` parameter and record `attempts` for every
  `Reviser`. Update its comments so they no longer tie attempts to a debug trace.
- **Controller.** Remove `debug` from `DictationController`'s initialiser and
  properties. Create the trace for every dictation that reaches `running`, pass no
  capture flag and always publish `lastTrace`. Rewrite the type and property comments
  that mention debug mode.
- **App.** Stop reading `--debug`. Remove the launch-time `.regular` activation policy
  and the `debug` property. Show **Last Dictation…** whenever a controller exists, so
  `--hud-demo`, which records nothing, still has no item. Suppress the window at launch
  instead of presenting it; it opens only from the menu item. Keep
  `.restorationBehavior(.disabled)` and `.commandsRemoved()`, rewriting their comments
  for the ungated window.
- **Naming.** Rename `DebugWindow` to `LastDictationWindow`, its file to
  `Views/LastDictationWindow.swift`, and its window id to `last-dictation`. Remove
  "debug" wording from code comments, including `DictationTrace`'s type comment. Leave
  `scripts/build-app.sh` and `scripts/deploy.sh` alone: their `debug` is the Swift
  build configuration.
- **Docs.** Remove the `--debug` line from the README's development commands. If the
  README describes features, mention Last Dictation there in one line. Update the spec
  so it describes the ungated feature: behavior, the App implementation notes, tests
  that mention debug capture, and the Final gate. Rewrite 0023 as the record of the
  shipped feature, with its title changed in both the record and the decisions index.
  Keep the paths `docs/specs/debug-window.md` and
  `docs/decisions/0023-debug-window.md`: this workflow, the accepted packets and the
  index link to them. Record the change of decision in 0023 itself. Don't add a new
  decision record.

### Non-goals

No trace history, persistence, setting to turn recording off, new diagnostic content,
layout changes, or changes to dictation, read-aloud, reply requests, paste/send or
Settings. No compatibility alias for `--debug`, `DebugWindow`, the old window id or the
`capture` parameter. Do not edit accepted packets 01 and 02, or the plan's workstream
table and drift log.

### Initial ownership

Workstreams 1 and 2 are accepted, so this workstream owns their files for this change:

- `Sources/EchoTypeCore/Reviser.swift`
- `Sources/EchoTypeCore/DictationTrace.swift` (comments only)
- `Tests/EchoTypeCoreTests/ReviserTests.swift` (drop `capture: true` only)
- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/App.swift`
- `Sources/EchoTypeApp/Views/DebugWindow.swift`, renamed to
  `Sources/EchoTypeApp/Views/LastDictationWindow.swift`
- `README.md`
- `docs/specs/debug-window.md`
- `docs/decisions/0023-debug-window.md`
- `docs/decisions/README.md`
- This packet, and plan.md rows and sections the README assigns to a lead.

Any other file needs an escalation.

### Required seams

- Keep the `DictationTrace` contract and `marks` unchanged. Workstream 1's Core tests
  must keep passing without edits, apart from dropping `capture: true`.
- Preserve `DictationController`'s reply-request detection, send decision and `finish`
  ordering from 0022. `publishTrace` still runs after `finish`, and `test()` and
  read-aloud still create no trace.
- Keep the trace in memory only. It is not written to disk, logged or sent anywhere.
- Keep the shared `presentWindow` and `windowClosed` activation behavior from 0011 and
  0023. The only path that makes the app regular is opening a window from the menu.

### Acceptance criteria

- A normal launch starts as an accessory app with no window open. The menu shows
  **Last Dictation…** below **Settings…**, and it opens a window reading "No dictation
  yet" until the first dictation ends.
- Every dictation that reaches `running` replaces the trace, with commits, revision
  attempts, raw replies, timings and marks, as workstream 2's window showed with
  `--debug`. The Test button and read-aloud do not.
- `--hud-demo` shows no **Last Dictation…** item.
- `--debug`, the `debug` property, the `capture` parameter and `DebugWindow` are gone,
  with no aliases. A search of `Sources`, `Tests`, `README.md`, the spec and 0023
  finds no debug-mode wording for this feature.
- The spec, 0023, its index entry and the README describe the delivered behavior.

### Targeted verification

```sh
swift test
./scripts/build-app.sh debug /tmp/EchoType-ws3.app   # then delete the bundle
rg -n -i -- '--debug|debug window|debug mode|DebugWindow|capture' Sources Tests README.md docs/specs/debug-window.md docs/decisions/0023-debug-window.md
```

Explain each remaining `rg` hit, or remove it. `./scripts/run.sh` runs `pkill -x
EchoTypeApp`, which stops Aidan's running instance and the `--mcp` processes serving
agent sessions. Launch it only for G2, and never during an active dictation.

## Implementation handoff

- Base commit: `d8d334d`
- Outcome: Implemented. Every app launch with a controller records each dictation that
  reaches `running` and shows **Last Dictation…** below **Settings…**. The window is
  suppressed at launch and opens only from the menu, so the app starts as an accessory
  app. `--hud-demo` has no controller and no item. `--debug`, the controller's `debug`
  property, `Reviser`'s `capture` parameter and `DebugWindow` are gone, with no aliases.
- Files changed: `Sources/EchoTypeCore/Reviser.swift`,
  `Sources/EchoTypeCore/DictationTrace.swift` (type comment),
  `Tests/EchoTypeCoreTests/ReviserTests.swift` (dropped `capture: true`),
  `Sources/EchoTypeApp/DictationController.swift`, `Sources/EchoTypeApp/App.swift`,
  `Sources/EchoTypeApp/Views/DebugWindow.swift` renamed with `git mv` to
  `Sources/EchoTypeApp/Views/LastDictationWindow.swift`, `README.md`,
  `docs/specs/debug-window.md`, `docs/decisions/0023-debug-window.md`,
  `docs/decisions/README.md`.
- Decisions:
  - `Reviser` drops the `capture` flag and the optional start time. It always takes
    `Date()` and `ContinuousClock.now` before each request and appends an attempt after
    it. The judging and result mapping are unchanged.
  - `DictationController.init(store:)` loses `debug`. `dictate` sets `trace`
    unconditionally in `.started`, after `phase = .running`, so `test()` and read-aloud
    still create none. `publishTrace` still runs after `finish`. The reply-request
    detection and send decision are untouched.
  - `App` no longer reads `--debug` or sets `.regular` at launch. `WindowButtons` takes
    `hasLastDictation: controller != nil` in place of `debug`, and the app's `debug`
    computed property is removed. The scene uses `.defaultLaunchBehavior(.suppressed)`
    and keeps `.restorationBehavior(.disabled)` and `.commandsRemoved()` with rewritten
    comments. `presentWindow` and `windowClosed` are unchanged.
  - The window id is `last-dictation`.
  - README: removed the `--debug` command and added one Features bullet for Last
    Dictation.
  - Spec: retitled "Last Dictation window" (path kept), status notes the same-day
    revision and that it is implemented. Behaviour, Reviser, controller, window and
    `EchoTypeApp` notes, Docs, Decision record, the `Reviser.attempts` test and the Final
    gate now describe the ungated feature. It also states the trace stays in memory.
    Since the window bullet was being rewritten for the rename, it now describes the
    delivered `NSTextView` paragraph rather than the original SwiftUI `Text`, pointing to
    0023. The Core `marks` boundary-flag wording from workstream 1's drift is left as it
    was, since that section is outside this packet's listed spec changes.
  - 0023: retitled "A Last Dictation window shows the last dictation's trace" in the
    record and the index. The first decision bullet now says every launch records, the
    menu item is the only way in, and the trace stays in memory. The activation bullet
    says the app always starts as an accessory app. A "Change of decision" section
    records the original `--debug` gate and Aidan's 2026-09-29 decision to remove it. A
    new consequence notes that every dictation now keeps its revision windows and replies
    in memory until the next one replaces them.
- Verification: `swift test` passes all 69 tests. `swift build` after touching every app
  source and `Reviser.swift` finishes with no warnings. `./scripts/build-app.sh debug
  /tmp/EchoType-ws3.app` built and signed the bundle, which was then deleted.
  `./scripts/run.sh` was not run (it stops Aidan's running instance; G2 covers the
  launch). The `rg` command's remaining hits:
  - `docs/decisions/0023-debug-window.md` "Change of decision": the one historical
    mention of `--debug`, which the packet asks 0023 to record.
  - `Tests/EchoTypeCoreTests/ReviserTests.swift:128`, the test title "Captured attempts
    record ...". It means recorded attempts, not the removed flag. Ownership allowed
    only dropping `capture: true`, so the title stays.
  - Every other hit is audio capture (`AudioCapture`, `AVCapture*`, `CaptureError`,
    "capture layer", "capture tap", "ends capture") or a C closure that "cannot capture"
    in `HotkeyMonitor.swift`. None relates to this feature.
- Known limitations or external checks: G2 must confirm on the Mac that a plain
  `./scripts/run.sh` launch starts as an accessory app with no window, **Last
  Dictation…** sits below **Settings…**, the empty window reads "No dictation yet", and a
  cleanup-on dictation fills it with marks and request rows. No interactive check was
  done here.
- Specification drift: none beyond the approved 2026-09-29 decision. The spec's window
  bullet now matches workstream 2's recorded `NSTextView` drift.

## Independent review

- Reviewer: fresh reviewer subagent, against `git diff -M HEAD` on `debug-window` at
  `d8d334d`.
- Verdict: Accept. No required findings. The diff meets every acceptance criterion
  that can be checked without the Mac. G2 still has to confirm launch state and the
  menu interactively. Checks run: `swift test` (69 tests pass), `swift build` (no
  warnings), and `./scripts/build-app.sh debug /tmp/EchoType-review.app`, which built
  and signed the bundle. The bundle was then deleted. The packet's `rg` and a
  repo-wide `rg -- '--debug|DebugWindow'` find only historical mentions: 0023:49,
  which the packet asks for, and the workflow docs under `docs/debug-window/`, which
  are out of scope. The rest are audio-capture hits.
  - Reviser: `capture` and its stored property are gone. `attempts` is always appended
    after `judge` (`Reviser.swift:71-86`), and the judging and result switch are
    unchanged. The only test edit is removing `capture: true`
    (`ReviserTests.swift:131-134`).
  - Controller: `init(store:)` has no `debug` (`DictationController.swift:87`). The
    trace is created unconditionally, right after `phase = .running`, in `.started`
    (`:255-256`), so `test()` and read-aloud still create none. The reply-request
    arguments and `publishTrace` after `finish` are untouched (`:260-297`), and
    `lastTrace` is only kept in memory.
  - App: it no longer reads `--debug` or calls `.regular` at launch (`App.swift:14-19`).
    The menu item uses `hasLastDictation: controller != nil` (`:46`, `:108-119`), so
    `--hud-demo` shows none. The scene is `.suppressed`, with restoration disabled and
    commands removed (`:60-72`). `presentWindow` and `windowClosed` are unchanged
    (`:127-153`). The window id is `last-dictation` (`LastDictationWindow.swift:9`), and
    the rename was staged with `git mv`. No alias remains.
  - Docs: the README drops the `--debug` command and gains one Features bullet
    (`README.md:30-31`). The spec's Behaviour, App notes, Docs, Decision record, Tests
    and Final gate describe the ungated feature. 0023 and its index entry are retitled,
    and 0023 records the change of decision (`0023-debug-window.md:47-52`).
- Required findings: none.
- Optional observations:
  - O1. `docs/specs/debug-window.md:186` was not rewrapped after "with debug capture
    enabled" was deleted. It is now a 134-character line, while the rest of the file
    wraps near 90.
  - O2. The test title `"Captured attempts record ..."` (`ReviserTests.swift:128`) is
    the only code hit left for the removed `capture` wording. It still reads correctly,
    and the packet limits that file to dropping `capture: true`, so leaving it is
    defensible. If a later owner touches the file, "Attempts record ..." would remove
    the last echo of the flag.
- Questions: none.

## Resolution

- Finding dispositions: no Required findings, so no remediation pass. O1 accepted: the
  lead rewrapped the `Reviser.attempts` test bullet in `docs/specs/debug-window.md`
  (whitespace only). O2 rejected: the packet limits `ReviserTests.swift` to dropping
  `capture: true`, and the title still reads correctly as "recorded attempts".
- Simplification/deletion pass: the diff only deletes the gate, its flag, property,
  parameter and launch-time policy change, and renames the window. No new state,
  wrappers or aliases were added.
- Final verification: the recovering lead audited the interrupted diff (base `d8d334d`,
  every file within ownership), reran `swift test` (69 pass) and the packet's `rg`; the
  reviewer additionally ran `swift build` and `./scripts/build-app.sh debug`.

## Closure review

- Verdict: Accept. Fresh closure reviewer, against `git diff -M HEAD` on
  `debug-window` at `d8d334d`. The O1 fix is in place: `git diff HEAD --
  docs/specs/debug-window.md` shows the `Reviser.attempts` bullet under "## Tests"
  rewrapped with its wording unchanged, and no line in the spec now exceeds 95
  characters. The O2 rejection is consistent with the packet's ownership limit on
  `ReviserTests.swift`. The resolution touched only that spec bullet, so the reviewed
  code diff is unchanged. `swift test` passes all 69 tests on the cumulative diff.
  `./scripts/run.sh` was not run; G2 still owns the interactive launch checks.
- Remaining required findings: none.

## External validation

- Gate and placement: G2, after focused closure and before acceptance. It follows the
  README's External Mac validation rules for G1.
- Status: `Passed` 2026-09-29.
- Candidate: branch `debug-window` at `d8d334d` plus workstream 3's uncommitted diff
  (closure accepted), built with a plain `./scripts/run.sh`. On resuming, the lead
  confirmed it is the candidate closure accepted: HEAD is still `d8d334d`, the changed
  file set is unchanged, no source file changed after the closure-reviewed O1 spec
  rewrap, and `swift test` passes 69 tests.
- Instructions: Record branch/head, run `swift test`, then launch
  the signed development build with `./scripts/run.sh`, without `--debug`. Check that
  the app starts with no window and **Last Dictation…** sits below **Settings…**. Open
  it and check it says "No dictation yet". Dictate a sentence with cleanup on and check
  the window updates with marks and at least one request row that expands to its
  window and reply.
- Required evidence: a pass/fail result for launch state, menu item, empty window and
  one recorded dictation. Note who checked each item.
- Attempts and lasting decisions: the agent did not launch the candidate, because
  `./scripts/run.sh` stops Aidan's running instance and its `--mcp` processes, and the
  checks need desktop and microphone access. It blocked through plan escalation E2.
  Aidan chose to run all four checks himself (option (a)), as for G1. One attempt, no
  corrections.
- Evidence (all checked by Aidan on the Mac, 2026-09-29):
  - Launch state: Passed. No window opened and no Dock icon.
  - Menu item: Passed. **Last Dictation…** sits directly below **Settings…**.
  - Empty window: Passed. It opened and read "No dictation yet".
  - One recorded dictation: Passed. His screenshot shows the window after a 49s,
    73-word, 4-commit dictation with commit marks, struck and changed words, five
    request rows (3 accepted, 1 unchanged, 1 cancelled) and Copy as JSON.

### G2 re-check: layout correction (2026-09-29)

- Status: `Passed` 2026-09-29, Aidan's visual re-check through plan escalation E3.
- Defects Aidan found on the accepted build (`45c7c05`), with screenshots:
  1. The marked paragraph sometimes shifted up and drew over the summary line. It
     happened once on its own; resizing the window forced it, with the paragraph
     jumping and sometimes settling over the summary.
  2. Expanded request rows centred short Window and Reply blocks, such as "Can you
     hear me?", instead of aligning them to the leading edge.
- Cause 1: `MarkedText.sizeThatFits` set the displayed text container's size at each
  width SwiftUI probed (a harness logged 560, 0, infinity and nil before it settled).
  `NSTextView` defaults to `isVerticallyResizable = true`, so after each probe the view
  resized its own frame, and in the unflipped host its origin, to that width's height,
  fighting the frame SwiftUI assigned. The final position depended on call order.
- Cause 2: `DisclosureGroup` content centres a view narrower than the row, so only
  short content appeared centred.
- Fix, in `Views/LastDictationWindow.swift` only: the text view no longer resizes
  itself; its container follows the frame through the default `widthTracksTextView`;
  `sizeThatFits` measures the same attributed string in a separate TextKit 1 stack, so
  measuring never touches the displayed view, and returns the natural one-line size for
  a nil or infinite width. The disclosure content gets
  `.frame(maxWidth: .infinity, alignment: .leading)`. No behavior, contract or
  ownership change, so the implementation/review loop was not reopened.
- Checks: `swift test` passes 69 tests; `./scripts/build-app.sh debug` to a temporary
  path builds and signs (Aidan's running app untouched). Throwaway AppKit harnesses,
  since deleted: the implementer logged the old code's self-resizing and confirmed that
  after the fix only SwiftUI changes the frame and, at 12 widths, the frame height equals
  the rendered height and the paragraph stays below the summary; the disclosure content
  moved from centred (x 345.75) to leading (x 20). The reviewer independently confirmed
  the container tracks the frame and the measured height matches the displayed height
  across widening and narrowing.
- Review: one fresh review of the diff found no Required defects. Accepted Optional:
  name `widthTracksTextView` in the comment and shorten it (done by the lead). Declined
  Optional: caching the measurement, unneeded for one paragraph. Question carried to
  Aidan's check: whether the last line is ever clipped by a pixel after resizing.
- Candidate: branch `debug-window` at `45c7c05` plus the uncommitted change to
  `Views/LastDictationWindow.swift`, built with a plain `./scripts/run.sh`.
- Evidence (Aidan, 2026-09-29, on the candidate above):
  - Resize with a long dictation shown, repeatedly narrow and wide: Passed. The marked
    paragraph never overlapped the summary line and its last line was never clipped,
    which also answers the review's clipping Question.
  - Expand every request row: Passed. Window and Reply align to the leading edge in
    every expanded row.
- No drift: the correction restores the approved layout.
