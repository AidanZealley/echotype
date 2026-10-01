# 0010 How settings and the API key are stored

Status: accepted, 2026-09-25 (settings gate G1), updated 2026-09-30 for compatible speech-speed validation
and 2026-10-01 for the retired `cleanUp` key, the `provider` key and one Keychain item per
provider, and per-provider reading choices.
Replaces the hand-seeded key in [0006](0006-api-key-and-error-surface.md).

## Context

Before the settings milestone the defaults in `Settings()` were the settings, the key was
seeded by hand with `security`, and the keyterms were a hard-coded list. Two risks shaped
the storage: a stored value that decodes to a different hotkey after an upgrade, and a
Keychain item the app cannot read without a prompt.

## Decision

- `EchoTypeCore` owns the encoding. `Settings` is stored as JSON under the `UserDefaults`
  key `settings`, with the keys `hotkey` (`{"keyCode": UInt16, "modifiers": UInt8}`),
  `provider`, `keyterms`, `language`, `inputDeviceID` (omitted when `nil`),
  `readAloudHotkey` (shaped like `hotkey`), `reading` and
  `sendReplyRequests`. The key names and
  the modifier bit positions are the upgrade contract.
- Each field decodes on its own and falls back to its default, so a missing or unreadable
  field resets only itself and adding a field never resets the hotkey. Data that is not a
  JSON object gives all defaults.
- `reading` is a JSON object keyed by provider id, with `voice` and `speed` in each entry.
  A missing choice uses the provider's first voice and speed 1. A voice it no longer offers
  falls back to its first voice; a non-finite speed or one outside its `speedRange` falls
  back to 1. Each field and provider entry decodes independently. Reading requests and
  persistence apply the same validation, preserving valid fractional speeds. The slider
  uses the provider's range in 0.1 steps.
- When `reading` is absent, stored `voice` and `speechSpeed` migrate to the `xai` entry.
  The migration retains the previous finite 0.7 through 1.5 speed validation and fallback
  to 1. Encoding writes `reading` and stops writing `voice` and `speechSpeed`. A present
  but malformed `reading` falls back independently without re-importing legacy fields.
- `provider` is the selected provider's id ([0025](0025-provider-adapters.md)). A missing
  id, or one no registered provider has, gives the first entry of `Providers.all`, today
  `xai`.
- The retired `batchOnCommit` and `cleanUp` keys are ignored on decode and never written,
  so an old batch or cleanup preference does not govern revision, which is always on (see
  [0021](0021-revise-committed-dictation.md)).
- The menu bar's `hotkeysActive` choice is stored under its own `UserDefaults` key and
  defaults to on. Other stored settings are fields the window edits. `silenceTimeout`, `hardCap` and
  `finalizeTimeout` stay code defaults, so today's values are not frozen into every
  install.
- The keyterms list starts empty. The hard-coded placeholder list is gone: once the
  editor exists, keyterms are the user's data.
- The hotkey dropdown offers Opt+D and Ctrl+Opt+D (`Settings.Hotkey.presets`). The right
  Option double tap is deferred to [0007](0007-known-gaps.md).
  Opt+D was chosen over Option dead keys, which can leave a pending accent when the
  tap is unavailable, and Fn, whose system action fires below the event tap.
  Ctrl+Opt+D is an alternative rather than the default because Ctrl+Opt is
  VoiceOver's modifier.
- The read-aloud hotkey offers Opt+S and Ctrl+Opt+S (`Settings.Hotkey.readAloudPresets`).
- `SettingsStore` in the app is the only writer of `UserDefaults`. The hotkey monitor
  reads the current hotkey on every key event, so a change applies without a relaunch.
  The coordinator snapshots settings when reserving dictation, Test or reading.
- Each provider's API key lives only in the Keychain, as one generic password item whose
  service is the bundle identifier in `Resources/Info.plist` and whose account is the
  provider id, `xai` for xAI. The wrapper reads, saves and removes only the selected
  provider's item; reading no longer accepts an item under any other account name, and
  there is no migration for one. `Keychain.save` updates the existing item, so its access
  rule survives a changed key, and adds one when there is none. Because the app writes the
  item itself, it reads it back without a prompt. Keychain calls can block on a prompt, so
  the app makes them from detached tasks.

## Consequences

- `SettingsTests` pins a literal stored payload, including both hotkey presets, so a
  change to the key names or the modifier bits fails the suite.
- `SettingsValidationTests` exercises stored malformed/out-of-range values and public
  construction/mutation through actual JSON persistence and speech request encoding.
  Coordinator coverage preserves a previous Last Dictation across Test and checks that
  dictation/read-aloud hotkeys, Escape, Space and supplied speech cannot take over Test.
- The window reports a failed save or remove. Changing the Keychain paths means checking
  them by hand again; reading, saving and removing by account is checked on the Mac rather
  than through a protocol around the Keychain.
