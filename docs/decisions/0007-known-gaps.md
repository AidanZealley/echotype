# 0007 Known gaps handed to later milestones

Status: open. Remove each item as it is resolved.

- **The right Option double-tap hotkey** from the original design is deferred. The
  settings dropdown offers Opt+D and Ctrl+Opt+D only. A double tap is not a
  keycode-plus-modifiers chord, so it needs `flagsChanged` events in the tap, a timing
  window to tell a double tap from two presses, and a second stored hotkey shape.
- **The pill's stop hint is hard-coded to ⌥D.** With Ctrl+Opt+D chosen it names the
  wrong chord, and pressing ⌥D as it says types a character into the target app instead
  of committing. The hint should follow the chosen hotkey.
- **Verified only by reading:** tap re-enable after `tapDisabledByTimeout`, two
  insertions within the 800ms pasteboard restore window, and the pill appearing on the
  second display when that display holds the focused window.
- **Bluetooth input** runs in the headset profile, which gave wrong transcripts before
  [0012](0012-capture-with-avcapturesession.md). See
  [0005](0005-microphone-per-session.md). The settings input picker lets the user choose
  another microphone, but nothing warns that a Bluetooth input is in use.
- **Every 400 is worded as a key problem.** Language is free text, saved on every
  keystroke. If `api.x.ai` answers an unsupported language tag (say "english") with 400,
  every dictation and Test blames the key; a read-aloud 400 does too. Unverified
  against the live endpoint. Other unexpected TTS statuses show Swift case names.
- **Long readings can queue substantial audio.** The REST response arrived about
  five times faster than playback in the read-aloud spike. Each decoded buffer is
  scheduled as it arrives, with no limit on audio held ahead of playback. At the
  60,000-character cap, the measured sample suggests roughly 300 MB of Float32
  buffers. Revisit if long readings show memory pressure.
- **The rapid dictation-to-reading clipboard sequence has not been checked by hand.**
  [0020](0020-pasteboard-insertion-and-selection-copy.md) makes reading wait for a
  pending paste window. Build and tests pass, but the two hotkeys in quick succession
  still need a real-app check.
- **The resampler's tail is not flushed** when capture stops, so roughly the last 20 to
  30ms of audio is not sent. No clipping has been heard.
- **Inputs with more than two channels** are not mixed properly. Without a channel
  layout from the system the session fails to convert; with one, the mix to mono keeps
  only the first channel.
- **The menu bar menu does not open from a fullscreen app while the settings window is
  open.** EchoType is a regular app with a Dock icon while the window is open, and macOS
  does not open a regular app's status item menu over a fullscreen app. Close the window
  or go to the desktop first; Opt+D still works. Showing the Dock icon only while
  EchoType is frontmost would fix it but drop the window's Cmd+Tab entry.
