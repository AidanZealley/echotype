# 0016 Install to /Applications and claim the login item there

Status: accepted, 2026-09-25 (install gate G1).

## Context

`scripts/install.sh` puts a signed release bundle at `/Applications/EchoType.app`. The
development and installed bundles share one bundle identifier, so they share one
`SMAppService.mainApp` login item. Before this work the item pointed at
`.build/EchoType.app`, and the installed app's toggle showed it as on anyway, because
`status` answers by bundle identifier. An installed app whose login item still launches
the development bundle is not installed.

## Decision

- `install.sh` and `run.sh` both call `scripts/deploy.sh` with a configuration and a
  target path. It builds, stages and signs the bundle in `.build` before it stops any
  running copy, then replaces the target and opens it. A failed build or signature leaves
  the existing bundle and running app alone.
- `deploy.sh` stops every running EchoType, development or installed, so only one copy
  holds the hotkey. `run.sh` therefore quits the installed app and does not relaunch it.
- The installed app claims the login item itself. At launch, only when its bundle path is
  `/Applications/EchoType.app` and the item is `.enabled`, it calls
  `SMAppService.mainApp.register()` off the main actor. A disabled item is never
  re-enabled. The script can't do this, because only the app can act as `mainApp`.
- It calls the documented `register()` rather than relying on reading `status`. Reading
  it also moves the item, but that is undocumented.

## Evidence

Observed on macOS 27.2 with `sfltool dumpbtm` (entry `2.com.aidanzealley.echotype`):

- Launching another copy does not move the item. Reading `status` from a copy moves it to
  that copy and keeps its enabled or disabled state.
- `register()` from the installed copy while the item is enabled leaves it enabled at
  `/Applications/EchoType.app`. An enabled `.build` item moved to `/Applications` after
  install, and a disabled one stayed disabled.
- G1: with Launch at login on, the next real login started `/Applications/EchoType.app`.
  With it off, nothing started. Calling `register()` at every launch did not show a
  "Login item added" notification or ask for approval.

## Consequences

- Opening Settings in a `run.sh` build moves the item to `.build/EchoType.app` until the
  installed app next launches. See [0013](0013-test-button-and-system-rows.md).
- `/Applications/EchoType.app` is written in both `App.swift` and `install.sh`. Sharing it
  across Swift and shell would need machinery for a value that does not change.
- If deleting the old bundle fails partway, for example on a root-owned bundle from an
  earlier `sudo` install, the script exits with the app stopped and a partial bundle in
  place. Rerunning after fixing ownership recovers it.
- The wait for the old app to quit has no timeout, so a hung EchoType stalls the script.
