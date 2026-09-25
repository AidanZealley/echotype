# 0007 Known gaps handed to later milestones

Status: open. Remove each item as it is resolved.

- **The right Option double-tap hotkey** from the specification is deferred. The
  settings dropdown offers Opt+D and Ctrl+Opt+D only. A double tap is not a
  keycode-plus-modifiers chord, so it needs `flagsChanged` events in the tap, a timing
  window to tell a double tap from two presses, and a second stored hotkey shape.
- **The pill's stop hint is hard-coded to ⌥D.** With Ctrl+Opt+D chosen it names the
  wrong chord, and pressing ⌥D as it says types a character into the target app instead
  of committing. The hint should follow the chosen hotkey.
- **Verified only by reading:** tap re-enable after `tapDisabledByTimeout`, two
  insertions within the 800ms pasteboard restore window, and the pill appearing on the
  second display when that display holds the focused window.
- **Bluetooth input** gives wrong transcripts. See
  [0005](0005-microphone-per-session.md).
