# Workstream 2: Capture and show the last dictation

Status: not started.

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

## External validation

- Gate and placement: G1, after focused closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`; record branch/head and run `swift test`, then
  follow every item in the [spec's Final gate](../../specs/debug-window.md#final-gate)
  on the signed development build.
- Required evidence: a concise pass/fail result for launch with and without `--debug`,
  representative dictation and request rows, editor focus and insertion, cancellation,
  JSON copy, simultaneous windows and both themes. Note who checked each item.
- Attempts and lasting decisions: `TBD`
- Resume condition: every listed item has passing evidence; if agent access is
  insufficient, block for Aidan's observation through the orchestrator.
