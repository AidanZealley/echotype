# Workstream 2: Input device, key test and system status

Status: not started.

## Task packet

### Outcome

The settings window also picks the input device, tests the whole dictation path with one
click, shows whether each permission is granted with a button to fix it, and turns
launch at login on and off. Dictation uses the chosen device when it is connected and
the system default otherwise.

### Scope

**Listing inputs.** List the connected input devices through Core Audio, each with its
UID and name. The UID is what `Settings.inputDeviceID` stores; `nil` means follow the
system default. Refresh the list when the window appears. Nothing here runs in the event
tap's path.

**Using the chosen device.** `AudioCapture.start` takes the device UID for the session.
It opens that device when it is connected and the system default otherwise. The reopen
after a configuration change resolves the UID again. Setting the device on the input
node's audio unit before the engine starts (`auAudioUnit.setDeviceID`) is a suggestion.
Update `AudioCapture`'s comments, which say it follows the default by never choosing a
device. The controller passes the UID from the settings it read at the session's start.

**The picker.** An input row with System default followed by each connected input. A
stored device that is not connected stays selected and shows as not connected, so
unplugging it never silently resets the choice.

**The Test button.** Beside the API key. It saves the key in the field first, so it
tests the key the user sees. Then it runs a real streaming session through
`DictationController`, with the settings and the device a dictation would use, for five
seconds, then commits it the way Opt+D does. The outcome shows inline under the button:

- the transcript, for `insert`
- that nothing was heard, for `nothing`
- the error, worded by the controller's existing `describe(_:)`, for `failed` and for a
  start failure

A test never inserts and never shows the pill. The button shows that a test is running
and is disabled while one runs or while a dictation runs. Opt+D does nothing while a test
runs. The test and a dictation share one start sequence (microphone, key, socket) in the
controller rather than two copies of it.

**Permission rows.** One row each for Microphone and for Device Control and Data Access,
showing granted or not. Read the first with `AVCaptureDevice.authorizationStatus(for:)`
and the second with `AXIsProcessTrusted()`, which is still the check on macOS 27.2 (see
[0001](../../decisions/0001-build-and-sign-on-the-mac.md)). Refresh when the window
appears and when the app becomes active, so returning from System Settings updates them.
Each row's button opens its pane:
`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone` and
`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. Whether
the second lands on the Device Control and Data Access pane is checked at G2.

**Launch at login.** A toggle over `SMAppService.mainApp`. It reads the service's status
when the window appears rather than storing anything. Turning it on registers, and
turning it off unregisters. A failure shows inline. When the status is
`requiresApproval`, say so and offer `SMAppService.openSystemSettingsLoginItems()`.

**The specification's error list.** In `docs/specs/echotype-v1.md`, change the errors
line's "401 bad key" to say that a wrong key is a 400 and a 401 means no credentials were
sent, as recorded in [0006](../../decisions/0006-api-key-and-error-surface.md). Change
nothing else in the specification.

**The gap list.** In `docs/decisions/0007-known-gaps.md`, rewrite the Bluetooth item to
say the input picker now lets the user choose another microphone, and that there is no
warning. Add an item for `install.sh` (build-order step 6): a login item registered from
`.build/EchoType.app` points at that path, so the installed app has to be registered
again from `/Applications`.

**Gate G2.** After focused closure, the lead fills in this record's External validation
section with the candidate and the exact steps from G2 in `plan.md`, adds escalation
entry E2 to `plan.md`, sets the row to `Blocked` and G2 to `Testing`, and returns.
Failures Aidan reports go through the troubleshooting loop in the README.

### Non-goals

- A warning about Bluetooth input.
- A level meter or live transcript in the settings window.
- The batch endpoint.
- Watching for devices connecting while the window is open, beyond refreshing when it
  appears.
- Requesting permissions from the rows. The first dictation or test raises the
  Microphone prompt, and launch raises the other.
- Changes to the overlay, `SessionMachine`, the settings encoding or the store's shape.
  A defect in a frozen contract is an escalation.
- `install.sh`.

### Initial ownership

- `Sources/EchoTypeApp/AudioCapture.swift`
- A new input device listing file in `Sources/EchoTypeApp/`
- `Sources/EchoTypeApp/DictationController.swift`, for the device and the Test run
- The settings views in `Sources/EchoTypeApp/Views/`, adding sections and rows only
- `docs/specs/echotype-v1.md`, the errors line only
- `docs/decisions/0007-known-gaps.md`
- Workstream 1's files, only for defects G2 finds, as the README allows

### Required seams

- Workstream 1's handoff: the settings store and its API, the `Keychain` API, and where
  the form's sections live.
- `AudioCapture.start()` and `stop()`, and the commit order in
  [0005](../../decisions/0005-microphone-per-session.md): stop capture first so the pump
  drains the tail before `trigger()`.
- `SessionMachine.Outcome` and the controller's `describe(_:)`.

### Acceptance criteria

1. Sessions and tests open the chosen input when it is connected and the system default
   otherwise, including after a device change mid-session.
2. The picker lists System default and the connected inputs, and keeps a disconnected
   choice visible as not connected.
3. Test saves the key, runs one five second streaming session and shows its outcome
   inline. It never inserts or shows the pill, and it cannot overlap a dictation in
   either direction.
4. The start sequence exists once in the controller.
5. Both permission rows show current status, refresh on return to the app, and open
   their panes.
6. The launch at login toggle reflects and changes `SMAppService.mainApp`, and shows
   failures and the approval state.
7. The specification's error line and the 0007 items are updated as above.
8. Gate G2 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
timeout 120 swift test --disable-xctest
xcrun swift-format lint --recursive Sources Tests Package.swift
```

This workstream adds no `EchoTypeCore` logic, so it adds no tests. It is verified by
reading and at G2.

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

- Gate and placement: G2, after focused closure, before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: the G2 list in [plan.md](plan.md)
- Attempts and lasting decisions: `TBD`
- Resume condition: every G2 observation reported as passing
