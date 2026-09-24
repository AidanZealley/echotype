# 0007 Known gaps handed to later milestones

Status: open. Remove each item as it is resolved.

- **Settings persistence has no round trip test.** `Settings` has no serialisation
  yet. Whoever writes the `UserDefaults` and Keychain encoding owes it a test, or a
  hotkey that silently stops firing after an upgrade will be hard to trace.
- **Verified only by reading:** tap re-enable after `tapDisabledByTimeout`, and two
  insertions within the 800ms pasteboard restore window.
- **Bluetooth input** gives wrong transcripts. See
  [0005](0005-microphone-per-session.md).
