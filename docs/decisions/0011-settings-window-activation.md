# 0011 The settings window makes EchoType a regular app while it is open

Status: accepted, 2026-09-25 (settings gates G1 and G2). Departs from the
specification's `LSUIElement` behaviour.

## Context

EchoType is an `LSUIElement` app, so the specification keeps it out of the Dock and
Cmd+Tab. At G1 the settings window opened intermittently behind the frontmost app, or
without keyboard focus. macOS treats activation as a request it can decline, and it
declines an accessory app's request often enough to notice. Two workarounds, activating
after the menu closed and raising the window directly, were not enough on their own.
Tailscale's settings window shows a Dock icon while it is open, and the author chose to match
it.

## Decision

- The settings window is one grouped SwiftUI `Form` in a `Settings` scene, opened from a
  Settings item in the menu bar menu.
- `SettingsButton` in `App.swift` sets the activation policy to `.regular`, opens the
  window, activates on the next main-queue turn and raises the window with
  `orderFrontRegardless()`. The scene's `onDisappear` sets `.accessory` again. While the
  window is open, EchoType has a Dock icon and a Cmd+Tab entry.
- From a fullscreen app, Settings switches to the desktop and opens the window there. The
  window does not join fullscreen spaces.

## Consequences

- While the window is open, the menu bar menu does not open from a fullscreen app. This
  is a macOS limitation for status items of regular apps. Showing the Dock icon only
  while EchoType is frontmost would fix it, but drop the window's Cmd+Tab entry, so it is
  kept as a gap in [0007](0007-known-gaps.md).
- The window occasionally opened behind until `orderFrontRegardless()` was added, and
  that could not be reproduced on demand. If it comes back, start here.
- `scripts/run.sh` stops the running instance before replacing its bundle. Replacing it
  underneath the running app made `open` fail with error -600.
