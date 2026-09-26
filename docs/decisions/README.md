# Decisions

Short records of why EchoType works as it does, what observations led to those
choices, and which gaps remain. The code and tests define current behavior. Draft
specifications in `docs/specs/` describe possible future work.

Each record has a status, the context, the decision and its consequences. When a
decision is reversed, mark the old record superseded and link the new one. Don't
delete it.

| # | Decision | Status |
|---:|---|---|
| 0001 | [Build on the Mac and sign with a self-signed certificate](0001-build-and-sign-on-the-mac.md) | Accepted; certificate choice superseded by 0014 |
| 0002 | [Detect speech from what the endpoint actually sends](0002-speech-signal-from-observed-protocol.md) | Accepted |
| 0003 | [Transcript assembly rules](0003-transcript-assembly.md) | Accepted |
| 0004 | [Session and socket lifecycle belong to the session machine](0004-session-lifecycle.md) | Accepted |
| 0005 | [Open the microphone per session and release it when the session ends](0005-microphone-per-session.md) | Accepted; device choice superseded by 0012 |
| 0006 | [API key in the Keychain, errors in the menu bar until the overlay exists](0006-api-key-and-error-surface.md) | Accepted; error surface superseded by 0009, hand-seeded key by 0010 |
| 0007 | [Known gaps handed to later milestones](0007-known-gaps.md) | Open |
| 0008 | [The pill: a text-first layout with a level glow](0008-pill-design.md) | Accepted |
| 0009 | [How the overlay behaves during a session](0009-overlay-behaviour.md) | Accepted; meter input superseded by 0012 |
| 0010 | [How settings and the API key are stored](0010-settings-storage-and-api-key.md) | Accepted |
| 0011 | [The settings window makes EchoType a regular app while it is open](0011-settings-window-activation.md) | Accepted |
| 0012 | [Capture the microphone with AVCaptureSession on the chosen input](0012-capture-with-avcapturesession.md) | Accepted |
| 0013 | [The Test button, launch at login and the permission rows](0013-test-button-and-system-rows.md) | Accepted; key field superseded by 0015 |
| 0014 | [Sign with Apple Development](0014-sign-with-apple-development.md) | Accepted |
| 0015 | [Settings in tabs, with a masked saved key](0015-settings-window-layout.md) | Accepted |
| 0016 | [Install to /Applications and claim the login item there](0016-install-and-claim-the-login-item.md) | Accepted |
| 0017 | [Re-transcribe the whole recording when a dictation stops](0017-batch-pass-on-commit.md) | Accepted |
| 0018 | [Read aloud fetches audio over REST](0018-read-aloud-audio-fetch.md) | Accepted |
| 0019 | [Build a native macOS app with a small testable core](0019-native-macos-app-and-core-boundary.md) | Accepted |
| 0020 | [Insert through the pasteboard and copy selections after pending pastes](0020-pasteboard-insertion-and-selection-copy.md) | Accepted |
