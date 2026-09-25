# 0006 API key in the Keychain, errors in the menu bar until the overlay exists

Status: accepted, 2026-09-23 (dictation). The error surface is superseded by
[0009](0009-overlay-behaviour.md): failures now show in the overlay. The hand-seeded key
is superseded by [0010](0010-settings-storage-and-api-key.md), where the settings window
writes it. Reading the key from the Keychain stands.

## Context

The dictation milestone shipped without the overlay or the settings window, but
failures still had to be visible and the key had to come from somewhere. An
`LSUIElement` app launched by `open` inherits no shell environment, so an environment
variable was never an option.

## Decision

- The API key is read from the Keychain item keyed to the bundle identifier. There is
  no UI to write it yet, so it is seeded once by hand. The settings milestone adds only
  the editor. (Superseded: the app writes the item itself, see 0010.)
- The menu bar menu's state line shows the running state, every session failure and a
  missing key. The overlay and settings milestones take this over. (Superseded: the
  state line now shows only the session state.)
- `api.x.ai` answers a wrong key with 400 (`"Incorrect API key provided"`) and sends
  401 only when no credentials are presented. `STTError(httpStatus:)` stays faithful
  to HTTP, and the app words both `.badRequest` and `.unauthorized` as a key problem.

## Consequences

The specification's error list was corrected in the settings milestone. Every 400 is
still worded as a key problem, including one caused by something else in the request
(see [0007](0007-known-gaps.md)).
