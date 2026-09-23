# 0007 Known gaps handed to later milestones

Status: open. Remove each item as it is resolved.

- **Settings persistence has no round trip test.** `Settings` has no serialisation
  yet. Whoever writes the `UserDefaults` and Keychain encoding owes it a test, or a
  hotkey that silently stops firing after an upgrade will be hard to trace.
- **No live text crosses the session seam.** The overlay milestone designs that API
  against its own needs (level meter, dimmed interim text) by extending
  `SessionMachine`. See [0004](0004-session-lifecycle.md).
- **Escape during the starting state passes through** to the focused app. Decide what
  it should do when the overlay adds the starting state.
- **`audio.stop()` runs inside the event tap callback.** Moving it out is plausible
  hardening. Do it with the overlay work, which touches the same start and commit
  path, and rerun the hand test afterwards.
- **Verified only by reading:** tap re-enable after `tapDisabledByTimeout`, and two
  insertions within the 800ms pasteboard restore window.
- **Bluetooth input** gives wrong transcripts. See
  [0005](0005-microphone-per-session.md).
