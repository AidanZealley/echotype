# Workstream 4: Speaking in the app

Status: accepted.

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

- Base commit: `7cb0e7c` (working tree, uncommitted)
- Outcome: the app observes the `speak` distributed notification and reads its text with the Reading pill, configured voice and speed, `Speech.capped` and the existing pause and stop keys. Replaces a reading in progress and is dropped in every other non-idle phase.
- Files changed: `Sources/EchoTypeCore/SpeakNotification.swift` (new), `Sources/EchoTypeApp/Reader.swift` (also rewrapped long lines), `Sources/EchoTypeApp/DictationController.swift`
- Decisions: `SpeakNotification.name` is `com.aidanzealley.echotype.speak` and `textKey` is `text`. `Reader.init` takes `Reader.Source` (`.selection` or `.text(String)`); `.text` skips the copy and `waitForRestore`. The idle branch of `readAloudPressed` moved into a private `startReading(_:)` shared with `speak(_:)`, so both build the pill and reader identically. Replacing calls `reader.stop()` then starts the new reader; the old `read(_:)` task returns early because `isReading` is false. The controller owns the observer (queue `.main`), so `App.swift` is untouched. `speak(_:)` is private, reached only through the observer. Remediation: a distributed center holds notifications while the receiving app is inactive, so the controller sets `suspended = false` on it and `SpeakNotification` documents that the poster (workstream 5) must post with `deliverImmediately`. `Phase.reading` and the pill comment now cover given text as well as a selection.
- Verification: `swift build` and `swift test` pass (66 tests), re-run after the remediation pass.
- Known limitations or external checks: no unit tests and no live check, as the packet says; Gate B in workstream 5 covers it.
- Specification drift: none.

## Independent review

- Reviewer: `claude -p` on claude-opus-5-5, medium effort, read-only
- Verdict: Changes required
- Required findings: (1) A distributed notification can be held back while the receiving app is inactive, and EchoType is normally inactive, so `speak` could go unheard until the app is activated.
- Optional observations: `speak("")` sends empty text to xAI and could show a misleading error; stale `Phase.reading` and `startReading` comments; two lines over 100 columns in `Reader.swift`; `speakObserver` is only written; the old pill shows briefly when a reading is replaced.
- Questions: none

## Resolution

- Finding dispositions: Required 1 accepted. `SpeakNotification` now says the poster must use `deliverImmediately` (workstream 5 carries this), and the requirement is recorded in the plan's cross-workstream contracts. A receiver-side `suspended = false` was tried and removed: the app resets it on every activation change, so it does not hold. Optional: stale comments and long lines promoted and fixed. Empty text rejected as out of scope (the MCP tool and Gate B cover it, and `Speech.capped` is the only limit the packet allows). `speakObserver` kept as the conventional token. Old pill on replace rejected as cosmetic and identical to selection readings.
- Simplification/deletion pass: the idle branch of `readAloudPressed` became one `startReading` shared with `speak`; no wrappers or flags added; `App.swift` untouched.
- Final verification: `swift build` and `swift test` pass (66 tests).

## Closure review

- Verdict: Changes required, on one point of Required 1: the receiver-side `suspended = false` did not hold, and the `deliverImmediately` obligation was not in workstream 5's packet.
- Remaining required findings: none after the lead's fix. The lead removed `suspended = false` and its comment and recorded the poster's `deliverImmediately` obligation in the plan's cross-workstream contracts and drift log, since packet 5 is frozen. The selector-based receiver was rejected as heavier (an `NSObject` target) for a requirement the poster meets in one option. Gate B verifies delivery while the app is inactive. No third review loop, per the README.
