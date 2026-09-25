# Settings implementation plan

Status: complete; workstreams 1 and 2 and the whole-feature review accepted.

## Orchestration record

- Integration branch: `feat/settings`
- Starting commit: `086af98`
- Review command: `lead subagents`
- Specification approved at commit: `f81ca54`
- Started: `2026-09-24`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Persistent settings and the window](01-persistent-settings-and-window.md) | Approved spec | Accepted |
| 2 | [Input device, key test and system status](02-device-test-and-system-status.md) | 1 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-2 | Accepted |

## Why these boundaries

Workstream 1 makes settings real: the encoding and its round-trip test in
`EchoTypeCore`, one store writing `UserDefaults`, the Keychain write path, and the
settings window with the rows that only read and write those stores (API key, hotkey,
keyterms, language). The hotkey monitor and the dictation controller switch from the
hard-coded defaults to the store in the same pass, because an editor whose values the
app ignores is not something to ship. Deleting the placeholder keyterms belongs here
too: the editor that replaces them lands in the same commit, so nothing has to preserve
them in between. The intermediate state is shippable: every setting the window shows
works, and the window has a form that workstream 2 adds rows to.

Workstream 2 holds the rows that reach past `UserDefaults` into the machine: the input
device picker and the device selection in `AudioCapture`, the Test button that runs a
real session through the controller, the permission status rows, and launch at login.
They share one kind of acceptance, which only Aidan can give at G2, and they share the
controller and capture paths that workstream 1 does not touch beyond reading settings.
Launch at login and the permission rows are small, so they ride here rather than cost a
workstream's review overhead of their own.

Gate G1 closes workstream 1 before workstream 2 builds on it, because the two riskiest
unknowns live there: whether the Keychain item the app writes can be read back without a
prompt, and whether a settings window opens in front for an `LSUIElement` app.

## Cross-workstream contracts

Frozen once workstream 1 is accepted:

- `EchoTypeCore` owns the encoding between `Settings` and `Data`. It persists `hotkey`,
  `keyterms`, `language` and `inputDeviceID`. A stored value missing a field decodes to
  that field's default, and unreadable data decodes to all defaults, so adding a field
  later never resets the hotkey. `silenceTimeout`, `hardCap` and `finalizeTimeout` are
  not persisted: nothing edits them.
- The default keyterms list is empty. `Settings.placeholderKeyterms` no longer exists.
- The hotkey presets are Opt+D and Ctrl+Opt+D, both `Settings.Hotkey` values defined in
  `EchoTypeCore`. The stored form is still keycode plus modifiers.
- One observable settings store in `EchoTypeApp` is the only writer of `UserDefaults`.
  The controller reads the settings once at the start of each session, and the hotkey
  monitor matches against the current hotkey on every key event. Workstream 1 names the
  store and records its API in its handoff.
- `Keychain` reads, writes and clears the API key as one generic password item under the
  service `com.aidanzealley.echotype`. The item is written by the app itself, so the app
  can read it without a prompt.
- The settings window is one grouped SwiftUI `Form` in a `Settings` scene, opened from a
  Settings item in the menu. Workstream 2 adds sections and rows to it and does not
  restructure it.

Held by the specification and not open to a workstream:

- The API key lives only in the Keychain, never in `UserDefaults` or `Settings`.
- The overlay must never take focus from the target app. Nothing in this milestone
  touches the panel.
- Nothing is inserted by a timer except the ten minute hard cap, and the Test button
  never inserts.
- The bundle identifier is `com.aidanzealley.echotype`.
- `scripts/run.sh` is the only supported build and launch path.

## Ownership handoffs

| File | Owner | Notes |
|---|---|---|
| `Sources/EchoTypeCore/Settings.swift` | 1 | Frozen after acceptance |
| `Tests/EchoTypeCoreTests/` | 1 | The settings round-trip tests |
| New settings store in `Sources/EchoTypeApp/` | 1 | |
| `Sources/EchoTypeApp/Keychain.swift` | 1 | |
| `Sources/EchoTypeApp/HotkeyMonitor.swift` | 1 | Only to match the current hotkey |
| `Sources/EchoTypeApp/App.swift` | 1 | The store, the Settings scene and the menu item |
| `Sources/EchoTypeApp/Views/` settings views | 1, then 2 | New in 1. 2 adds its sections |
| `Sources/EchoTypeApp/DictationController.swift` | 1, then 2 | 1 reads settings and rewords the missing key; 2 adds the device and the Test run |
| `Sources/EchoTypeApp/AudioCapture.swift` | 2 | Device selection |
| New input device listing in `Sources/EchoTypeApp/` | 2 | |
| `docs/specs/echotype-v1.md` | 2 | Only the error list's key wording, owed by [0006](../../decisions/0006-api-key-and-error-surface.md) |
| `docs/decisions/0007-known-gaps.md` | 1, then 2 | Each removes the items it resolves and adds the gaps it hands on |

## Whole-feature acceptance

- Workstreams 1 and 2 accepted.
- Gates G1 and G2 passed, with Aidan's evidence recorded in the owning workstream
  records.
- `swift build` clean, `timeout 120 swift test --disable-xctest` green, and
  `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.
- The settings round-trip item is gone from
  [0007](../../decisions/0007-known-gaps.md), and the deferred double-tap hotkey is
  recorded there.
- No double-tap hotkey, hotkey recorder, `install.sh`, transcript history, Bluetooth
  warning or overlay change in the diff. Those are out of this milestone and their
  appearance here is scope creep to reject.

## External validation gates

### G1 Settings and the key persist

- Owning workstream: 1
- Placement: after focused closure, before acceptance
- Status: `Passed`
- Candidate: the uncommitted workstream 1 state, launched with `./scripts/run.sh`
- Resume condition: Aidan reports every observation below, or a failure the lead can
  correct and republish

Required evidence, in Aidan's words:

1. Choosing Settings from the menu bar opens the window in front of other apps, with
   keyboard focus in it. It looks right in dark and light appearance.
2. Pasting the API key and relaunching with `./scripts/run.sh`: the window still shows a
   key, and a dictation works with no Keychain prompt.
3. With the key cleared, Opt+D shows the missing key error in the pill.
4. Keyterms and language entered in the window survive a relaunch. A dictation of a
   keyterm he added comes out spelled right.
5. Switching the hotkey to Ctrl+Opt+D: Opt+D now types a character into the focused app
   and Ctrl+Opt+D dictates, without a relaunch. The choice survives a relaunch.
   Switching back restores Opt+D.

### G2 Device, Test, permissions and login

- Owning workstream: 2
- Placement: after focused closure, before acceptance
- Status: `Passed`
- Candidate: the uncommitted workstream 2 state, launched with `./scripts/run.sh`
- Resume condition: Aidan reports every observation below, or a failure the lead can
  correct and republish

Required evidence, in Aidan's words:

1. The input picker lists System default and each connected input. With another input
   connected (for example AirPods), choosing the built-in microphone makes dictation and
   Test use the built-in microphone. The choice survives a relaunch.
2. With the chosen device disconnected, the picker still shows it as not connected, and
   dictation uses the system default input.
3. Test with a good key shows what he said, inline in the window. Nothing is pasted and
   no pill appears.
4. Test with a wrong key shows a key error inline. Test with the microphone speaking
   nothing shows that nothing was heard.
5. Opt+D does nothing while a test is running, and Test is disabled while a dictation
   is running.
6. The permission rows show Microphone and Device Control and Data Access as granted.
   Each button opens the matching pane of System Settings. Whether the Device Control
   and Data Access button lands on the right pane on macOS 27.2.
7. Turning on launch at login lists EchoType under System Settings > General > Login
   Items, and turning it off removes it. The toggle reflects a change made in System
   Settings once the window is reopened. Optionally, EchoType starts after logging out
   and back in.

## Escalations

None open.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-24 | The hotkey dropdown offers Opt+D and Ctrl+Opt+D only. Right Option double-tapped is deferred and recorded in 0007. The specification lists it as a third preset | A double tap is not a keycode-plus-modifiers chord: it needs `flagsChanged` in the tap, a timing window and a second stored shape. Nothing claims Opt+D yet | Aidan, before the workflow | 1 |
| 2026-09-24 | The keyterms list starts empty. The hard-coded placeholder list is deleted, not kept as a default | The keyterms are the user's data once the editor exists | Aidan, before the workflow | 1 |
| 2026-09-24 | The settings window is one grouped `Form` in the standard macOS pattern, with no layout variants | An established pattern, judged at G1 | Aidan, before the workflow | 1, 2 |
| 2026-09-24 | Only fields the window edits are persisted: hotkey, keyterms, language, input device. The timeouts stay code defaults | Persisting values nothing edits would freeze today's defaults into every install | Pending approval of this workflow | 1 |
| 2026-09-24 | Launch at login state is read from `SMAppService`, not stored | The system is the source of truth and can be changed in System Settings | Pending approval of this workflow | 2 |
| 2026-09-25 | EchoType shows a Dock icon and a Cmd+Tab entry while the settings window is open, switching to a regular app and back to accessory when the window closes. The specification says `LSUIElement` keeps it out of the Dock and Cmd+Tab | macOS does not reliably activate an accessory app, so the window opened behind the frontmost app or without focus at G1. Tailscale does the same | Aidan, at G1 (E3) | 1, 2 |
| 2026-09-24 | The Test button runs a real streaming session through the controller for five seconds and shows the outcome inline. It never inserts and shows no pill. It does not use the batch endpoint | The specification says one click validates the microphone, the device, the key and the socket, and only the streaming path covers the socket | Pending approval of this workflow | 2 |
| 2026-09-25 | Microphone capture uses an input-only `AVCaptureSession`, not `AVAudioEngine` as the specification's Architecture and Audio sections say. The input picker lists `AVCaptureDevice`s rather than Core Audio devices as the workstream 2 packet says; `Settings.inputDeviceID` stores their unique ID | `AVAudioEngine` stopped itself on every open of Bluetooth earbuds (the profile switch changes the device format) and its restarts looped, and a stale format in one restart crashed the app at G2 | Aidan, at G2 (E6) | 2 |
| 2026-09-25 | A session keeps the input it opened when the system default changes mid-session, and reopens at most once if that input goes away | Following a new default mid-session would switch a Bluetooth headset's profile mid-dictation. One reopen bounds any loop | Aidan, at G2 (E6) | 2 |
| 2026-09-25 | The overlay meter measures the audio sent, after the mix to 16 kHz mono, not the loudest channel before conversion as 0009 says | The capture format may not be float, and the sent audio reads the same for every device | Aidan, at G2 (E6) | 2 |
| 2026-09-25 | While the settings window is open, the menu bar menu does not open from a fullscreen app. Kept as a known gap in 0007 rather than showing the Dock icon only while EchoType is frontmost | A macOS limitation for status items of regular apps, following from the E3 Dock icon decision. The alternative drops the window's Cmd+Tab entry and reopens activation code. Do not reopen the window behaviour unless it becomes a problem | Aidan, at G2 (E7) | 2, Final |
