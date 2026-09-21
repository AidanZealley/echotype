# Workstream 2: Hotkey tap and paste

Status: not started.

## Task packet

### Outcome

With the app running and permissions granted, pressing Opt+D while TextEdit has focus
inserts the literal string `hello from echotype` at the caret. No `d` character
appears. The behaviour survives a rebuild through `./scripts/run.sh` without any new
permission prompt.

### Scope

- A `CGEventTap` installed at `cghidEventTap` as an active tap, not listen-only, so it
  can consume events. It watches `keyDown` and matches keycode 2 (`d`) with
  `.maskAlternate` set, returning `nil` for that event so the character never reaches
  the focused app.
- Handling for `tapDisabledByTimeout` and `tapDisabledByUserInput`, re-enabling the tap
  with `CGEvent.tapEnable`. The specification names this as the most likely cause of a
  silent failure, so it is in scope now rather than later.
- A permissions check on launch using `AXIsProcessTrustedWithOptions` with the prompt
  option, so a missing grant surfaces rather than failing quietly.
- Insertion following the specification's sequence: record
  `NSPasteboard.general.changeCount`, write the string, post Cmd+V via `CGEventPost`
  to `cghidEventTap`, then after roughly 800ms restore the previous contents only if
  `changeCount` advanced by exactly one.

### Non-goals

- Audio capture, the xAI socket, and anything transcription-related.
- The overlay panel, the settings window and the Keychain.
- Making the hotkey configurable. Opt+D is hardcoded for the spike.
- Escape to cancel, the paused state, and the session timeouts. There is no session.
- Handling secure input mode. The specification records it as a known risk, and the
  spike does not need to solve it.

### Initial ownership

Inherits and owns `Sources/EchoTypeApp/`. May add files there.

May change `Resources/Info.plist` only if a TCC requirement demands it, and must
record that as specification drift.

Must not change the bundle identifier, the signing identity or `scripts/run.sh`'s
contract. Those are frozen by workstream 1. A defect in one of them is an escalation,
not a silent rewrite.

### Required seams

Consumes workstream 1's bundle identifier, signing identity and `scripts/run.sh`.

### Acceptance criteria

1. Opt+D with TextEdit focused inserts `hello from echotype` at the caret.
2. No `d` character appears alongside it.
3. After `./scripts/run.sh` rebuilds and relaunches, Opt+D still works and macOS
   issues no new Accessibility or Input Monitoring prompt.
4. Quitting and relaunching the app preserves the behaviour.
5. Pasteboard contents present before the insertion are restored afterwards, and are
   left alone if something else wrote to the pasteboard in the meantime.
6. The tap recovers from being disabled. Demonstrate this by calling
   `CGEvent.tapEnable(tap:enable:false)` from a debug path, or by documenting why a
   live demonstration was not practical and showing the handler code instead.

### Targeted verification

```bash
swift build
./scripts/run.sh
codesign -dv --verbose=4 .build/EchoType.app
```

Criteria 1 to 5 are observed by Aidan through gate G3. Criterion 6 is verified by the
implementation agent where possible and reviewed as code where not.

No unit tests. Every behaviour here is a system integration that cannot be exercised
without a signed bundle and a TCC grant.

## External validation

- Gate and placement: G3, after closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md).
- Required evidence: pass or fail for each of the four spike criteria, and for
  criterion 3 specifically whether any permission prompt reappeared.
- Attempts and lasting decisions: `TBD`
- Resume condition: all four criteria pass.

If criterion 3 fails, do not redesign the signing approach. That result contradicts
the specification's development workflow and belongs to the user. Record the evidence,
write an escalation and block.

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
