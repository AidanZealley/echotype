# 0013 The Test button, launch at login and the permission rows

Status: accepted, 2026-09-25 (settings gate G2). Key field handling superseded by
[0015](0015-settings-window-layout.md).

## Context

The specification wants one Test click to validate the microphone, the device choice,
the key and the socket, and suggests the batch endpoint for it. Only the streaming path
covers the socket.

## Decision

- Test runs a real streaming session through `DictationController.test()` for five
  seconds, then commits it as the hotkey would and shows the outcome inline: the
  transcript, a key error, a failure, or that nothing was heard. It never inserts and shows
  no pill. It does not use the batch endpoint.
- Test uses the saved key. (Until [0015](0015-settings-window-layout.md) it saved the key
  field first.) Test and dictation exclude each other: the controller's `.testing` phase makes the hotkey, Escape and pill
  clicks do nothing, and the button is disabled while a dictation runs.
- Launch at login is read from and written to `SMAppService.mainApp`, never stored,
  because the user can change it in System Settings. The window rereads it when it appears
  and when the app becomes active.
- The permission rows read `AVCaptureDevice.authorizationStatus(for: .audio)` and
  `AXIsProcessTrusted()` at the same moments, each with a button that opens its pane of
  System Settings.

## Consequences

- Test cuts off after five seconds even if the user is still speaking. That is by design.
- The login item records the path of the copy that last registered it or read its status,
  while `status` answers by bundle identifier, so the development and installed bundles
  share one item. On macOS 27.2, reading `status` from another copy moved the item to that
  copy and kept its enabled or disabled state. The installed app registers again at launch
  when the item is enabled, so the item points back at `/Applications/EchoType.app`, and it
  leaves a disabled item alone. Opening Settings in the development bundle moves the item to
  `.build/EchoType.app` until the installed app next launches. See
  [0016](0016-install-and-claim-the-login-item.md).
