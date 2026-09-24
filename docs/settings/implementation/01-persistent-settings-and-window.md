# Workstream 1: Persistent settings and the window

Status: not started.

## Task packet

### Outcome

A Settings item in the menu bar opens a settings window holding the API key, the hotkey,
the keyterms and the language. Every value survives a relaunch. The key is written to
the Keychain by the app, so it is read back without a prompt. A hotkey change takes
effect at once, and the other settings take effect from the next session. The encoding
has round-trip tests that would catch a stored hotkey decoding differently after an
upgrade.

### Scope

**The encoding, in `EchoTypeCore`.** Encode and decode `Settings` to and from `Data`
under the rules in the plan's cross-workstream contracts: persist `hotkey`, `keyterms`,
`language` and `inputDeviceID`; a missing field decodes to its default; unreadable data
decodes to all defaults. `inputDeviceID` has no editor until workstream 2, but it belongs
to the same stored value, so its encoding lands here. Pick explicit, stable key names;
they are the upgrade contract. `Codable` with a hand-written `init(from:)` using
`decodeIfPresent` per field is a suggestion, not a requirement.

**Presets.** Add Ctrl+Opt+D beside `Hotkey.optionD`, and one list of the presets the
dropdown offers, in `EchoTypeCore`. The menu labels for them are UI copy and belong in
the view.

**Keyterms default.** Delete `Settings.placeholderKeyterms` and its comment. The
default keyterms list is empty.

**Tests.** Add `Tests/EchoTypeCoreTests/SettingsTests.swift` covering, and no more than:

- A round trip of non-default settings, including a non-default hotkey and a device ID.
- Decoding a literal payload, written as the stored bytes this version produces, gives
  the expected settings. This is the test that fails if a key name or the hotkey's shape
  changes under an existing install.
- A payload missing some fields keeps the fields it has and defaults the rest.
- Unreadable data decodes to the defaults.

**The store.** One `@MainActor @Observable` settings store in `EchoTypeApp`. It loads
from `UserDefaults.standard` under one key at launch and writes back on every change. It
is the only code that touches `UserDefaults`. `App.swift` creates it and hands it to the
controller and the settings view.

**The Keychain write path.** `Keychain` gains save and clear beside `apiKey()`. Save
deletes any existing item under the service and adds a new one, so the item is always
created by the app. An item seeded by hand with `security` carries an access list that
makes the app prompt on every read, and updating it in place would keep that list.
Keychain calls can block on a prompt, so call them off the main actor, where the event
tap runs. Update the type's comment, which still says there is no write path.

**The controller and the monitor.** `DictationController` reads the store's settings
once at the start of each session, in place of its `Settings()` constant. The monitor
matches against the store's current hotkey on each key event, so a change applies
without a relaunch or reinstalling the tap. The missing key error in the pill becomes
"Add your xAI API key in EchoType Settings".

**The window.** A `Settings` scene holding one grouped SwiftUI `Form`, with these rows:

- API key: a secure field showing the stored key, masked. The key is saved when the
  user submits the field or leaves it. An emptied field clears the item.
- Hotkey: a picker over the presets, labelled with their key symbols (⌥D, ⌃⌥D).
- Keyterms: a text editor with one term per line. Blank lines and surrounding whitespace
  are dropped. Show the count against the endpoint's limit of 100. The editor holds its
  own text while the user types; writing the parsed list back into it on every keystroke
  would eat the newline being typed.
- Language: a text field holding the language tag. A blank field stores the default.

Keep product copy minimal and without em dashes.

**The menu.** Add a Settings item above Quit that opens the window and brings it to the
front. The app is `LSUIElement`, so opening the scene alone leaves the window behind the
frontmost app; activate the app when opening it.

**The gap list.** In `docs/decisions/0007-known-gaps.md`, remove the settings round-trip
item. Add an item recording that the right Option double-tap hotkey from the
specification is deferred, and why: it is not a keycode-plus-modifiers chord, so it needs
`flagsChanged` events in the tap, a timing window and a second stored shape.

**Gate G1.** After focused closure, the lead fills in this record's External validation
section with the candidate and the exact steps from G1 in `plan.md`, adds escalation
entry E1 to `plan.md`, sets the row to `Blocked` and G1 to `Testing`, and returns.
Failures Aidan reports go through the troubleshooting loop in the README.

### Non-goals

- The input device picker, the Test button, the permission rows and launch at login.
  They are workstream 2's.
- The right Option double-tap hotkey, and a hotkey recorder.
- Validating the key when it is saved. The Test button in workstream 2 does that.
- Persisting the timeouts, or any setting the window does not edit.
- A list of supported languages.
- Migrating the hand-seeded item. Saving from the window replaces it; until then
  `apiKey()` keeps reading it.
- Changes to the overlay, the session machine or the transcript assembler.

### Initial ownership

- `Sources/EchoTypeCore/Settings.swift`
- `Tests/EchoTypeCoreTests/SettingsTests.swift` (new), and existing tests only where the
  keyterms default change breaks them or leaves a comment stale, such as the one in
  `STTConnectionTests.swift` that names the placeholder list
- A new settings store file in `Sources/EchoTypeApp/`
- New settings views in `Sources/EchoTypeApp/Views/`
- `Sources/EchoTypeApp/Keychain.swift`
- `Sources/EchoTypeApp/HotkeyMonitor.swift`, only to match the current hotkey
- `Sources/EchoTypeApp/DictationController.swift`, for reading settings and the missing
  key wording
- `Sources/EchoTypeApp/App.swift`
- `docs/decisions/0007-known-gaps.md`

### Required seams

- `Settings` as it stands, and `STTConnection.streamingURL(settings:)`, which already
  applies the keyterm caps.
- `DictationController`'s session start, which today builds the URL and `SessionMachine`
  from its `settings` constant.
- `HotkeyMonitor`'s initialiser, which today takes a fixed hotkey.
- Outputs for workstream 2, recorded in the handoff: the store's name and API, the
  `Keychain` API, and where the form's sections live.

### Acceptance criteria

1. `Settings` encodes and decodes under the contract's rules, and the four tests above
   pass.
2. `placeholderKeyterms` is gone and the default keyterms list is empty.
3. One store is the only code touching `UserDefaults`, and every row writes through it.
4. The key is saved, read and cleared through `Keychain`, never on the main actor, and
   saving recreates the item.
5. A hotkey change applies without a relaunch. Other settings apply from the next
   session and never to one already running.
6. The menu's Settings item opens the window in front.
7. The 0007 items are updated as above.
8. Gate G1 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
timeout 120 swift test --disable-xctest
xcrun swift-format lint --recursive Sources Tests Package.swift
```

Everything outside `EchoTypeCore` is verified by reading and at G1.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Store and Keychain API for workstream 2: `TBD`
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

- Gate and placement: G1, after focused closure, before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: the G1 list in [plan.md](plan.md)
- Attempts and lasting decisions: `TBD`
- Resume condition: every G1 observation reported as passing
