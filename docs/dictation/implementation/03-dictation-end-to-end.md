# Workstream 3: Dictation end to end

Status: not started.

## Task packet

### Outcome

Opt+D starts a session, speech streams to xAI, Opt+D again inserts the transcript at the
caret in whatever app has focus, and Escape discards it. The menu bar icon says whether a
session is running. Aidan can dictate a prompt into a coding agent with it.

### Scope

**The hotkey, rewritten.** `HotkeyMonitor.swift` is spike code: a file-scope mutable tap,
a hardcoded keycode, and a call to `insert` with a literal string. Replace it with a type
that takes the configured `Settings.Hotkey` and reports presses to its caller. Keep the
`tapDisabledByTimeout` and `tapDisabledByUserInput` re-enabling exactly as it is; that
part is right, and the specification names a tap that silently stops as the most likely
mystery failure in the project.

Escape is consumed only while a session is open, so it behaves normally the rest of the
time.

Put the matching rule in `EchoTypeCore`, on `Settings.Hotkey`: given a keycode and a set
of modifiers, does this chord match, with the configured modifiers held and no others.
That predicate is the only part of the tap that can be tested, and the settings milestone
will add presets that lean on it. Keep it to that; if it grows into a general event model
it has gone wrong. The `CGEventFlags` to `ModifierFlags` mapping stays in the app.

**The Keychain, read only.** `Keychain.swift` reads a `kSecClassGenericPassword` item for
service `com.aidanzealley.echotype` and returns the xAI key, or nothing. No write path
and no UI: the settings milestone owns those. Aidan seeds the item by hand once, and you
publish the exact `security add-generic-password` command with the G1 candidate.

A missing key is a normal state, not a crash. The user sees it as the menu's state line.

**The controller.** One type owning the session lifecycle: on a hotkey press with no
session, read the key, open a `URLSessionWebSocketTransport` against
`STTConnection.streamingURL(settings:)`, start a `SessionMachine`, start audio delivery,
and pump chunks into `send(audio:)`. On a press with a session running, `trigger()`. On
Escape, `cancel()`. When `run()` returns, act on the outcome:

- `insert(text)`: insert it.
- `nothing`: do nothing.
- `failed(text, error)`: insert the text if there is any, and show the error in the menu.

Recall that the socket opens on trigger, not at launch, because an idle open socket bills
streaming time. The audio device is the opposite: it stays warm, which is workstream 2's
concern.

**The menu bar.** `MenuBarExtra`'s icon reflects state, driven by `SessionMachine.states`.
The menu holds the current state, and Quit. No manual trigger item: clicking it leaves
focus wherever it was, so it cannot do the real job. The icon is `waveform` for now.

The menu's state line is also where a failure is reported, and where "no API key" is
reported. This is the only place the user can see anything in this milestone, which is
why it carries more than the specification's overlay-era description implies. Record that
as drift.

**The insertion fix.** `Inserter.insert` schedules its pasteboard restore with a bare
`asyncAfter` 800ms out. Two dictations inside that window race: the second snapshots the
first one's transcript as the contents to restore. Give the pending restore an identity so
a new insertion supersedes it. Also skip the restore write when there was nothing on the
pasteboard to begin with, rather than clearing it and writing an empty array.

Do not change the `changeCount` rule itself. Step 4 of the specification's insertion
sequence is settled and the spike confirmed it by hand.

### Non-goals

- The overlay, in any form, including a borderless window "just to see the transcript".
- Live transcript text, interim text or elapsed time crossing the `SessionMachine` seam.
- The level meter.
- The settings window, the hotkey preset dropdown, the device picker, the keyterms
  editor, launch at login and the Test button.
- `install.sh` and `--hud-demo`.
- Writing to the Keychain.
- Reconnecting or retrying a failed session.
- Changing `SessionMachine`, the transport or `Package.swift`. A defect there is an
  escalation.

### Initial ownership

- `Sources/EchoTypeApp/HotkeyMonitor.swift`
- `Sources/EchoTypeApp/Keychain.swift`
- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/Inserter.swift`
- `Sources/EchoTypeApp/App.swift`
- `Sources/EchoTypeCore/Settings.swift`, for the hotkey matching predicate only
- `Tests/EchoTypeCoreTests/`, for that predicate's tests

`Sources/EchoTypeApp/AudioCapture.swift` belongs to workstream 2. Change it only while
troubleshooting gate G1, and record each change in the handoff as a correction to
workstream 2's work.

### Required seams

- `SessionMachine` as workstream 1 left it. Consume it; do not extend it.
- The capture API recorded in workstream 2's Implementation handoff.
- `STTConnection.streamingURL(settings:)` and `STTConnection.headers(apiKey:)`.
- `Settings` as it stands, including its placeholder keyterms. There is no persistence in
  this milestone: construct the default `Settings` and use it.

### Acceptance criteria

1. Opt+D opens a session; Opt+D again inserts the transcript at the caret. Proven by gate
   G1, not by a test.
2. Escape while a session is open cancels it and inserts nothing. Escape with no session
   passes through to the focused app untouched.
3. The chord is read from `Settings.Hotkey`, not hardcoded, and matching requires the
   configured modifiers and no others, so Cmd+Opt+D and Ctrl+Opt+D pass through. Tests
   cover the predicate.
4. The tap re-enables itself on `tapDisabledByTimeout`.
5. A missing Keychain item leaves the app running and says so in the menu.
6. `Outcome.failed` inserts the accumulated text and shows the error in the menu.
   `Outcome.nothing` inserts nothing.
7. Two dictations inside the 800ms restore window do not corrupt each other's pasteboard
   restore.
8. The menu bar icon differs between idle and a running session.
9. No overlay, settings window or level meter appears in the diff.
10. Gate G1 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
swift test
./scripts/run.sh
```

Add the hotkey predicate's tests to `Tests/EchoTypeCoreTests/`.

```bash
swift-format lint --recursive Sources Tests Package.swift
```

Skip the lint if swift-format is not installed and say so in the handoff.

Everything else is gate G1. Do not manufacture a test for the tap, the pasteboard or the
Keychain by wrapping them in a protocol and faking them.

## External validation

- Gate and placement: G1, after focused closure and before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: `TBD`
- Attempts and lasting decisions: `TBD`
- Resume condition: `TBD`

The candidate is the uncommitted branch state. The instructions Aidan receives must
include the exact `security add-generic-password` command to seed the API key, the
`./scripts/run.sh` invocation, and the seven observations listed under G1 in
[plan.md](plan.md). If a grant misbehaves, `tccutil reset All com.aidanzealley.echotype`
is the verified escape hatch.

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
