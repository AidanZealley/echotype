# 0019 Build a native macOS app with a small testable core

Status: accepted, 2026-09-26. Records the platform and package choices from the
original v1 design. Signing and deployment are covered by [0014](0014-sign-with-apple-development.md)
and [0016](0016-install-and-claim-the-login-item.md).

## Context

EchoType controls a global event tap, posts keyboard events, copies through the pasteboard,
captures the microphone and shows a panel without taking focus. Those operations require
macOS APIs even if the UI uses a cross-platform framework.

## Decision

- Build one native Swift package for macOS 26 or later. `EchoTypeApp` uses SwiftUI and
  AppKit, with no third-party runtime or generated Xcode project. `EchoTypeCore` holds
  session, transcript, settings and network protocol code without AppKit or TCC. The
  app target handles the microphone, Keychain, pasteboard, event tap and windows.
- Test session and protocol behavior with recorded event streams and an injected
  clock. Check focus, permissions and paste behavior on the Mac. Do not add
  protocols around `NSPasteboard` merely to test a fake implementation.
- Keep the bundle identifier stable. macOS ties permissions, the Keychain item,
  `UserDefaults` and the login item to it. Keep `LSUIElement` enabled for the usual
  menu bar behavior. The settings window temporarily makes the app regular, as
  [0011](0011-settings-window-activation.md) describes.
- Do not enable App Sandbox. It prevents the global event tap and posted keyboard
  events this app needs. Builds made for local use are not notarized.

## Consequences

- Development and tests run on a Mac. The earlier Linux-compatible core plan was
  dropped when audio conversion and the remaining work became macOS-specific.
- `scripts/run.sh` builds, signs and launches the development app;
  `scripts/install.sh` installs the release app in `/Applications`. A stable Apple
  Development signing identity lets permissions survive rebuilds.
- Secure input can prevent the global hotkey from firing while a password field has
  focus. The event tap also needs to re-enable itself after macOS disables a slow tap;
  its manual verification remains in [0007](0007-known-gaps.md).
