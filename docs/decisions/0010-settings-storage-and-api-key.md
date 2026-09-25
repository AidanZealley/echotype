# 0010 How settings and the API key are stored

Status: accepted, 2026-09-25 (settings gate G1). Replaces the hand-seeded key in
[0006](0006-api-key-and-error-surface.md).

## Context

Before the settings milestone the defaults in `Settings()` were the settings, the key was
seeded by hand with `security`, and the keyterms were a hard-coded list. Two risks shaped
the storage: a stored value that decodes to a different hotkey after an upgrade, and a
Keychain item the app cannot read without a prompt.

## Decision

- `EchoTypeCore` owns the encoding. `Settings` is stored as JSON under the `UserDefaults`
  key `settings`, with the keys `hotkey` (`{"keyCode": UInt16, "modifiers": UInt8}`),
  `keyterms`, `language`, `inputDeviceID` (omitted when `nil`) and `batchOnCommit`. The key
  names and the modifier bit positions are the upgrade contract.
- Each field decodes on its own and falls back to its default, so a missing or unreadable
  field resets only itself and adding a field never resets the hotkey. Data that is not a
  JSON object gives all defaults.
- Only fields the window edits are persisted. `silenceTimeout`, `hardCap` and
  `finalizeTimeout` stay code defaults, so today's values are not frozen into every
  install.
- The keyterms list starts empty. The hard-coded placeholder list is gone: once the
  editor exists, keyterms are the user's data.
- The hotkey dropdown offers Opt+D and Ctrl+Opt+D (`Settings.Hotkey.presets`). The right
  Option double tap is deferred to [0007](0007-known-gaps.md).
- `SettingsStore` in the app is the only writer of `UserDefaults`. The hotkey monitor
  reads the current hotkey on every key event, so a change applies without a relaunch.
  The controller snapshots the settings once at the start of each session.
- The API key lives only in the Keychain, as one generic password item whose service
  is the bundle identifier in `Resources/Info.plist` and whose account is `xai`.
  `Keychain.save` deletes every item under that service, then adds the new one.
  Because the app writes the item itself, it reads it back
  without a prompt. Keychain calls can block on a prompt, so the window makes them from
  detached tasks.

## Consequences

- `SettingsTests` pins a literal stored payload, including both hotkey presets, so a
  change to the key names or the modifier bits fails the suite.
- Delete-then-add leaves a gap of microseconds with no key, and a failed add leaves none.
  The window reports a failed save. Changing this means checking the Keychain paths by
  hand again.
