# Workstream 4: Speaking in the app

Status: not started.

## Task packet

### Outcome

The running app reads text handed to it through a distributed notification, with the same
pill, voice, speed, pause and stop behaviour as a reading of a selection.

### Scope

Follow the specification's Behaviour (Speaking) and the App section for `DictationController`
and `Reader`.

- `EchoTypeCore` gets the notification's name and its `text` user-info key, in one small place
  that the app and workstream 5's process share.
- `Reader` takes its text source: the selection, as now, or given text. Given text skips the
  selection copy and the wait for the paste restore.
- `DictationController.speak(_ text: String)` follows `readAloudPressed`'s phase rules with the
  text given: it starts a reading from idle, replaces a reading in progress, and does nothing
  in every other phase, so the agent never talks over the user.
- The app observes the notification and calls `speak`.

### Non-goals

- The `--mcp` process, stdin, posting the notification, README setup (workstream 5).
- Any length limit beyond the existing `Speech.capped`.
- Authentication of the notification (the specification says it has none).

### Initial ownership

- `Sources/EchoTypeApp/DictationController.swift` (after workstream 3's changes)
- `Sources/EchoTypeApp/Reader.swift`
- `Sources/EchoTypeApp/App.swift` only for wiring the observer, if the controller cannot own it
- A new small file in `Sources/EchoTypeCore` for the notification name

### Required seams

Provides the notification name and `text` key. Workstream 5 posts it. Workstream 3's sending
code stays as it is.

### Acceptance criteria

- A reading started by `speak` uses the `Reading` pill, the configured voice and speed,
  `Speech.capped`, Space to pause, Escape or the read-aloud hotkey to stop, and the dictation
  hotkey to stop it and start dictating.
- `speak` during a running reading replaces it. `speak` while a dictation or test is starting
  or running is dropped.
- Reading a selection behaves exactly as before.
- `swift build` and `swift test` pass.

### Targeted verification

```sh
swift build
swift test
```

No live check here. Gate B in workstream 5 covers speaking end to end.

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
