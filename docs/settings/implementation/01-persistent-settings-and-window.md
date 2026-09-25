# Workstream 1: Persistent settings and the window

Status: accepted.

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

- Base commit: `086af98`
- Outcome: implemented, uncommitted. Criteria 1, 2 and 7 are met and tested or read.
  Criteria 3 to 6 are met by reading and wait on G1. Criterion 8 is G1 itself.
- Files changed:
  - `Sources/EchoTypeCore/Settings.swift`: `Codable` with explicit keys, `init(decoding:)`
    and `encoded()`, `Hotkey.controlOptionD` and `Hotkey.presets`, `Hashable` on `Hotkey`
    and `ModifierFlags`, `placeholderKeyterms` deleted and the keyterms default empty.
  - `Sources/EchoTypeCore/STT/STTConnection.swift`: `maximumKeyterms` made public for the
    window's count. Outside the packet's initial ownership; one word.
  - `Tests/EchoTypeCoreTests/SettingsTests.swift` (new): the four tests and no more.
  - `Tests/EchoTypeCoreTests/STTConnectionTests.swift`: dropped the stale placeholder
    comment and the now-redundant `keyterms: []`.
  - `Sources/EchoTypeApp/SettingsStore.swift` (new), `Sources/EchoTypeApp/Views/SettingsView.swift`
    (new), `Keychain.swift`, `HotkeyMonitor.swift`, `DictationController.swift`, `App.swift`.
  - `docs/decisions/0007-known-gaps.md`: round-trip item removed, double-tap and pill
    stop hint items added.
- Decisions:
  - Stored format: JSON under the `UserDefaults` key `settings`, with keys `hotkey`
    (`{"keyCode": UInt16, "modifiers": UInt8 raw value}`), `keyterms`, `language` and
    `inputDeviceID` (omitted when `nil`). Each field decodes on its own with `try?`, so a
    missing or unreadable field defaults only itself; data that is not a JSON object gives
    all defaults. The literal-payload test uses a non-default hotkey, so a hotkey that
    silently fell back to its default would fail it.
  - `HotkeyMonitor` takes the store and reads `store.settings.hotkey` on each key event.
  - The controller snapshots `store.settings` at the top of `dictate()`, before the
    microphone opens, so workstream 2 can read `inputDeviceID` from the same snapshot.
  - The API key row trims whitespace, writes only when the value differs from what the
    Keychain holds, and chains its writes so a save and a clear cannot reorder. Each write
    runs detached; the row records the value as saved only when the write succeeds, so a
    failed write is retried on the next submit or blur, and shows "Couldn't save the key"
    under the field until a write succeeds. It saves on submit, on losing focus and when
    the window closes. The initial Keychain read fills the field only if it is still
    empty.
  - `save` deletes every item under the service first and adds nothing if that delete
    fails; `errSecItemNotFound` counts as success.
  - Language and keyterms rows hold their own text and write parsed values through on each
    change. A blank language stores `Settings().language` and shows it as the placeholder.
  - Keyterm parsing and the blank-language rule live in the view, not `EchoTypeCore`: they
    are two lines each and the packet caps the tests at four.
  - The saved item uses account `xai`. Save deletes every item under the service first,
    including a hand-seeded one under another account name.
  - From G1 (Aidan, E3 and E4): the app switches to a regular app, with a Dock icon and
    Cmd+Tab entry, while the settings window is open, and back to accessory when it
    closes. `SettingsButton` in `App.swift` sets `.regular`, opens the window, then
    activates on the next main-queue turn; the `Settings` scene's `onDisappear` sets
    `.accessory`. Workstream 2 adds rows inside that scene and must keep this pair.
  - From G1: from a fullscreen app, Settings switches to the desktop and opens the window
    there; the window does not join fullscreen spaces.
  - From G1: `scripts/run.sh` stops the running instance before replacing its bundle, which
    fixed the intermittent `open` error -600.
  - `SwiftUI.Settings` and `EchoTypeCore.Settings` collide; the view qualifies the core type
    and `App.swift` does not import `EchoTypeCore`.
- Store and Keychain API for workstream 2:
  - `@MainActor @Observable final class SettingsStore` in
    `Sources/EchoTypeApp/SettingsStore.swift`: `init()` loads; `var settings: Settings`
    writes back on every set. Bind rows with `$store.settings.inputDeviceID` through
    `@Bindable`.
  - `enum Keychain`: `apiKey() -> String?`, `save(_ key: String) -> Bool`, `clear() ->
    Bool`. `save` and `clear` return whether the write succeeded. All block on a possible
    prompt; call them from a detached task.
  - The form is `SettingsView` in `Sources/EchoTypeApp/Views/SettingsView.swift`: a grouped
    `Form` with three `Section`s (API key; hotkey and language; keyterms). Rows are private
    structs in the same file. Add sections to that `Form`.
  - `DictationController(store:)`; the session's settings are the local `settings` in
    `dictate()`.
- Verification: `swift build` clean with no warnings; `timeout 120 swift test
  --disable-xctest` 45 tests passing, including the four in `SettingsTests`; `xcrun
  swift-format lint --recursive Sources Tests Package.swift` clean. Also checked with a
  scratch script that `didSet` fires on an `@Observable` property.
- Known limitations or external checks:
  - Unverified until G1: the window opening in front and focused, the grouped form's
    sizing (`.frame(width: 460)` with vertical `fixedSize`), the app-written item reading
    without a prompt, and `SecItemDelete` removing a hand-seeded item without a prompt.
  - A failed write reports only a Bool, not the `OSStatus`, so G1 sees that a write
    failed but not why.
  - The pill's hint still reads `⌥D stop` when the hotkey is Ctrl+Opt+D. The overlay is a
    non-goal here; recorded in 0007.
- Specification drift: none beyond the logged double-tap deferral. The error list's key
  wording in the specification is still owed by workstream 2.

## Independent review

- Reviewer: independent review agent, fresh session, against base `086af98` and the
  uncommitted diff (plan.md changes excluded).
- Verdict: acceptable after one required fix. The encoding, store, controller and monitor
  changes meet their criteria and read correctly. `swift build` is clean, `timeout 120
  swift test --disable-xctest` passes 45 tests including the four in `SettingsTests`, and
  `xcrun swift-format lint --recursive Sources Tests Package.swift` is clean.
- Checked and found sound:
  - Upgrade safety. The stored hotkey is `{"keyCode":UInt16,"modifiers":UInt8}` from
    synthesized `Codable` on `Hotkey` and the raw value of `ModifierFlags`. The
    literal-payload test pins both key names, the hotkey's shape and the modifier bits
    (`6` = control and option), so a renamed property or a reordered bit fails it. Each
    field decodes on its own through `try?`, so a bad field defaults only itself.
    Installs with nothing stored get the defaults and write nothing until the first edit.
  - Main actor. Every Keychain call in the diff runs inside `Task.detached`: the row's
    load, save and clear, and the controller's existing read. The event tap does one
    observable property read per keyDown. `UserDefaults` writes on the main actor are
    cheap. There is no Core Audio in this workstream.
  - Running dictation. `dictate()` copies `store.settings` before it does anything else
    and passes that copy to both `streamingURL` and `SessionMachine`, so edits made
    during a session do not reach it. Only the hotkey is live, as the packet asks.
  - Tests. The four tests exercise the real encoding with no fakes. The round trip
    overlaps with the literal-payload test, but the packet asks for both.
  - `STTConnection.maximumKeyterms` became public outside the packet's ownership. It is a
    one-word change and justified, since the count must not duplicate the limit.
- Required findings:
  - **R1. `Keychain.save` ignores both `OSStatus` results, and the row treats every save
    as done.** `save` calls `clear()` and then `SecItemAdd` without checking either
    result, and `APIKeyRow.save()` sets `savedKey` before the detached write runs.
    Criterion 4 ("saving recreates the item") fails silently in the one case the packet
    calls out. The hand-seeded item's account name is unknown (the old comment gave only
    `-s`), and its access list does not name the app. Scenario A: the delete of that item
    fails, for example with `errSecAuthFailed` or because the user denies the prompt. The
    add under account `xai` then succeeds, which leaves two items under the service.
    `apiKey()` has no account and uses the default match limit of one, so it may keep
    returning the old item, with its prompt and possibly the old key. Scenario B: the
    seeded item already uses account `xai` and the delete fails. The add then fails with
    `errSecDuplicateItem`. In both cases the window shows the new key for the rest of the
    session, and after a relaunch the old one comes back. G1 step 2 is built to catch
    this, but with the statuses discarded, a G1 failure would give nothing to diagnose.
    Smallest fix: do not add unless the delete returned `errSecSuccess` or
    `errSecItemNotFound`, and return success from `save` and `clear`. The row should
    then only advance `savedKey` on success, so the next submit or blur retries. Whether
    a failure also shows in the window is the lead's call.
- Optional observations:
  - **O1. The API key row's initial load can overwrite typed text.** `.task` assigns
    `key` and `savedKey` whenever the detached read returns. While the prompt for a
    hand-seeded item is up, or on a slow read, anything the user has already typed or
    pasted is replaced, and `savedKey` then matches, so nothing is saved. A guard that
    skips the assignment if `key` is no longer empty is enough. The risk is low, because
    a Keychain prompt is modal in practice.
  - **O2. Changing the hotkey during a session.** The monitor switches at once, as the
    packet asks. But the pill's hint still reads `⌥D stop` (a limitation already noted
    in the handoff), so following the hint after a switch to Ctrl+Opt+D types `∂` into
    the target app instead of committing. This only happens if the user changes the
    hotkey mid-dictation. No change is needed here; it belongs with the pill hint gap.
  - **O3. The comment on `DictationController.store`** says it is "read once at the
    start of each session". The same store is also read live by the monitor, which the
    controller hands it to. Put the once-per-session comment on the `let settings =
    store.settings` line in `dictate()`, where it is true.
- Questions:
  - **Q1. A bad language tag is worded as a key problem.** Language is now free text
    with no validation, which the non-goals allow. If `api.x.ai` answers an unknown tag
    with 400, `describe` shows "xAI rejected the
    API key" (it maps `.badRequest` to that wording, per 0006). The user would then look
    in the wrong place. Should the lead accept this for now, record it in 0007, or leave
    it to workstream 2's Test button and key wording? The 400 for a bad tag has not been
    observed. It is an inference, not a measured response.
  - **Q2. The order of activation and opening the window.** `SettingsButton` calls
    `NSApplication.shared.activate()` before `openSettings()`. On macOS 14 and later,
    `activate()` is cooperative, and activation completes asynchronously. The pattern
    that tends to work for `LSUIElement` menu bar apps is to open the window and then
    activate, or to activate again once the window exists. This cannot be settled by
    reading. G1 step 1 settles it, and if it fails there, swapping the two calls is the
    first thing to try.

## Resolution

- Finding dispositions (lead):
  - R1 accepted and fixed in the one remediation pass. `save` and `clear` return
    whether the write worked, `save` does not add after a failed delete, the row advances
    `savedKey` only on success so the next submit or blur retries, and a failed write
    shows "Couldn't save the key" under the field. The OSStatus is not surfaced; G1 step
    2 is the check.
  - O1 promoted and fixed: the first Keychain read only fills an empty field. One line.
  - O2 not changed here. The overlay is out of scope; the stale ⌥D stop hint is now a
    0007 item, which covers the mid-session switch too.
  - O3 promoted and fixed, since comments must match the code.
  - Q1 accepted as is. A 400 for a bad language tag is unobserved, validating the tag is
    a non-goal, and workstream 2's Test button surfaces the outcome.
  - Q2 kept as implemented (activate, then open). It cannot be settled by reading; G1
    step 1 settles it, and swapping the calls is the first troubleshooting step.
  - Outside ownership: `STTConnection.maximumKeyterms` made public, one word, so the
    window's count does not duplicate the endpoint limit. Accepted.
- Simplification/deletion pass: `save` and `clear` return a `Bool` rather than a thrown
  error, since the row only needs success or failure. The row's write chain became one
  main-actor task that awaits the previous write and a detached Keychain call, then
  updates `savedKey` and the failure flag; no new types, wrappers or files. The misplaced
  controller comment moved to the snapshot line in `dictate()`. Nothing else to delete.
- Final verification: `swift build` clean with no warnings; `timeout 120 swift test
  --disable-xctest` 45 tests passing; `xcrun swift-format lint --recursive Sources Tests
  Package.swift` clean. The window, the failure message and the Keychain statuses are
  unverified until G1.

- Review of the G1 troubleshooting corrections (fresh reviewer, after G1 passed): the
  activation policy switch in `App.swift` and the reordered stop in `scripts/run.sh`. No
  required findings. `swift build` clean, 45 tests passing, swift-format lint clean,
  `bash -n scripts/run.sh` clean. The reviewer checked by reading that the policy returns
  to accessory on every close path, that Cmd+, only exists while the window is open, that
  the overlay panel and event tap do not depend on the policy, and that a failed
  `swift build` exits before `run.sh` stops the running app. Dispositions (lead):
  - Optional: `run.sh` now stops the app before `codesign`, so a failed signing leaves no
    app running. Accepted as is; a failed signing has to be fixed before anything runs.
  - Question: after the window closes, the accessory app may stay active with no window,
    so focus might not return to the previous app until a click. Unverified, not a
    regression and not seen at G1. Deferred; `NSApp.hide(nil)` after the switch is the
    fix if Aidan notices it.
  - Question: Cmd+H with the window open might fire `onDisappear` and drop the Dock icon.
    Worst case the menu bar Settings item unhides it. No change.

## Closure review

- Verdict: Accepted
- Remaining required findings: none
- Verified:
  - R1 fixed. `save` returns early on a failed `clear()`, so it never adds beside or
    after an item it could not delete. `clear` counts `errSecItemNotFound` as success.
    `save` returns whether `SecItemAdd` succeeded.
  - R1 row. `APIKeyRow.save()` advances `savedKey` only when the write succeeds and shows
    "Couldn't save the key" otherwise. Each write waits for the previous task, so writes
    stay in order, and the Keychain call runs in `Task.detached`.
  - O1 fixed. The initial read returns without assigning if `key` is no longer empty.
  - O3 fixed. The once-per-session comment is on `let settings = store.settings` in
    `dictate()`, and the property comment describes both readers.
  - O2, Q1 and Q2 were dispositioned without code changes, as recorded in Resolution.
  - `swift build` clean; `timeout 120 swift test --disable-xctest` 45 passing; `xcrun
    swift-format lint --recursive Sources Tests Package.swift` clean.

## External validation

- Gate and placement: G1, after focused closure, before acceptance
- Status: `Passed`
- Candidate and instructions: the uncommitted workstream 1 state on `feat/settings`
  (base `086af98`), after closure. Launch it with `./scripts/run.sh` only. Then:
  1. Choose Settings… from the menu bar. The window should open in front of other apps
     with keyboard focus in it. Check it in dark and light appearance.
  2. Paste the xAI API key into the key field and press Return or click elsewhere. No
     "Couldn't save the key" line should appear. Relaunch with `./scripts/run.sh`. The
     field should still show a masked key, and an Opt+D dictation should work with no
     Keychain prompt.
  3. Empty the key field and click elsewhere. Opt+D should show "Add your xAI API key in
     EchoType Settings" in the pill. Paste the key back afterwards.
  4. Add a keyterm (one per line) and change the language, relaunch, and check both are
     still there. Dictate the keyterm and check its spelling.
  5. Switch the hotkey to ⌃⌥D. Without relaunching, Opt+D should type a character into
     the focused app and Ctrl+Opt+D should dictate. Relaunch and check ⌃⌥D is still
     chosen. Switch back to ⌥D and check Opt+D dictates again.
- Troubleshooting notes: if step 1 leaves the window behind, the first correction is to
  open the window before activating the app (review Q2). If step 2 shows "Couldn't save
  the key" or a prompt on read, the likely cause is the hand-seeded item; report whether
  macOS showed a prompt when saving.
- Required evidence: the G1 list in [plan.md](plan.md)
- Attempts and lasting decisions:
  - Attempt 1, published 2026-09-24 (answered in E1). Steps 2 to 5 passed in Aidan's
    words: the key persists between runs, a missing key shows the error, keyterms work
    and hotkey switching works. Step 1 passed on appearance in dark and light. Failure:
    sometimes clicking Settings does not open the window and a second click is needed.
    Keyboard focus was not reported.
  - Diagnosis: `SettingsButton` activated the app, then opened the window, while the menu
    was still closing. Activation on macOS 14 and later is cooperative, so a request made
    then can be lost, and the window opens behind the frontmost app, which reads as not
    opening. The second click works because the first one's activation has landed by then.
    Not reproducible here; agents cannot open the window.
  - Correction for attempt 2 (`App.swift`, `SettingsButton` only): open the window, then
    on the next main-queue turn, after the menu has closed, activate and call
    `makeKeyAndOrderFront` on the `Settings` scene's window, found by SwiftUI's
    identifier `com_apple_SwiftUI_Settings_window` (present in this macOS's SwiftUI; a
    miss only skips the raise). Troubleshooting correction, not yet reviewed; it gets one
    review after the gate passes. `swift build` clean, swift-format lint clean.
  - Lasting decision: from a fullscreen app, Settings switches to the desktop and opens
    the window there. Aidan finds this acceptable and Tailscale also switches, so the
    window stays a standard window and is not made to join fullscreen spaces.
  - Attempt 2, published 2026-09-24. Rerun step 1 only, since nothing else changed:
    launch with `./scripts/run.sh`, then choose Settings… from the menu bar at least ten
    times, closing the window between tries and with another app frontmost each time.
    Also try once with the window already open behind another app. Each click should open
    or raise the window in front on the first try, and typing straight away should go
    into the window without clicking it first.
  - Attempt 2 answer (E2): the window that seemed not to open had opened behind the
    active app's window. Aidan did not say whether that still happens on attempt 2, and
    did not report keyboard focus. Separately, `./scripts/run.sh` sometimes failed with
    `_LSOpenURLsWithCompletionHandler() failed with error -600.` after re-signing.
  - Diagnosis: the ordering failure is the one attempt 2 targets, but attempt 2 still
    relies on macOS granting the activation, which is cooperative and can be declined.
    Error -600 is `procNotFound`: `run.sh` deleted and rebuilt the bundle while the old
    instance was still running from it, then killed that instance, so Launch Services could
    still hold a record of it when `open` ran.
  - Correction for attempt 3. `App.swift`, `SettingsButton`: after activating, also call
    `orderFrontRegardless()` on the window, which puts it above other apps' windows even
    when activation is declined. `scripts/run.sh`: stop the old instance before replacing
    its bundle rather than after. Troubleshooting corrections, not yet reviewed; they get
    one review after the gate passes. `swift build` clean, 45 tests passing, swift-format
    lint clean, `bash -n scripts/run.sh` clean.
  - Attempt 3, published 2026-09-24. Rerun step 1 only, as described for attempt 2:
    launch with `./scripts/run.sh`, choose Settings… at least ten times with another app
    frontmost and the window closed between tries, and once with the window already open
    behind another app. Report, for each: whether the window came up in front on the
    first click, and whether typing straight away went into the window without clicking
    it first. Also report whether `./scripts/run.sh` printed error -600 on any launch.
  - Attempt 3 answer (E3): Aidan did not report attempt 3's observations. He chose the
    stronger activation instead: show the Dock icon while the settings window is open, as
    Tailscale does, if it is not too complex.
  - Lasting decision (Aidan, 2026-09-25): EchoType becomes a regular app, with a Dock icon
    and Cmd+Tab entry, while the settings window is open, and returns to accessory when it
    closes. Logged as drift from the specification's `LSUIElement` behaviour in
    [plan.md](plan.md).
  - Correction for attempt 4 (`App.swift` only). `SettingsButton` switches the activation
    policy to regular, opens the window, then activates on the next main-queue turn. The
    `Settings` scene's content switches the policy back to accessory in `onDisappear`, the
    same close signal the API key row already saves on. A regular app's activation is
    reliable and raises its windows, so attempt 2 and 3's workarounds are removed: the
    lookup of the window by SwiftUI's undocumented identifier, `makeKeyAndOrderFront` and
    `orderFrontRegardless`. The deferred activation stays, because the menu is still closing
    when the button fires. The `run.sh` change from attempt 3 stays. Troubleshooting
    correction, not yet reviewed; it gets one review after the gate passes. `swift build`
    clean, 45 tests passing, swift-format lint clean.
  - Attempt 4, published 2026-09-25. Rerun step 1 only: launch with `./scripts/run.sh`,
    choose Settings… at least ten times with another app frontmost and the window closed
    between tries, and once with the window already open behind another app. Report
    whether the window came up in front on every first click; whether typing straight away
    went into the window without clicking it first; whether the Dock icon appeared while
    the window was open and disappeared when it closed; and whether `./scripts/run.sh`
    printed error -600 on any launch.
  - Attempt 4 answer (E4, Aidan, 2026-09-25): all four pass. The window opens in front on
    every first click, keyboard focus lands in it, the Dock icon appears while it is open
    and disappears on close, and `./scripts/run.sh` did not print error -600.
- Evidence, in Aidan's words where given:
  1. Step 1 passed on attempt 4: the window opens in front on every first click with
     keyboard focus in it, and looks right in dark and light (attempt 1).
  2. The key persists between runs, with no Keychain prompt reported (attempt 1).
  3. A missing key shows the error (attempt 1).
  4. Keyterms work (attempt 1).
  5. Hotkey switching works (attempt 1).
