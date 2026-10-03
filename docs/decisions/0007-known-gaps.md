# 0007 Known gaps handed to later milestones

Status: open. Remove each item as it is resolved.

- **The five-minute dictation cap** was chosen to limit the old batch upload in
  [0017](0017-batch-pass-on-commit.md). The upload is gone under
  [0021](0021-revise-committed-dictation.md); revisit the cap if longer dictation matters.
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
  another microphone, and the pill shows the active input with a headphones icon when
  it is Bluetooth. It does not measure audio quality.
- **Every 400 is worded as a key problem.** Any 400 from `api.x.ai` makes every
  dictation and Test blame the key; a read-aloud 400 does too. The language now comes
  from a fixed list, so an unsupported tag no longer causes one. Other unexpected TTS
  statuses show Swift case names.
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
- **The menu bar menu does not open from a fullscreen app while the settings or Last
  Dictation window is open.** EchoType is a regular app with a Dock icon while either
  window is open, and macOS does not open a regular app's status item menu over a
  fullscreen app. Close the windows or go to the desktop first; Opt+D still works.
  Showing the Dock icon only while EchoType is frontmost would fix it but drop the
  windows' Cmd+Tab entry.
- **Apple provider checks not yet done on a signed install.** Automated and live tests
  cover the adapters, but these need the real app: first-use permission prompts (the
  microphone, and whether Speech asks at all), downloading a missing speech model with
  Settings and the waiting pill following it, keyterm spellings in real jargon dictation,
  a sentence over 250 characters read aloud, and cancelling while a model loads. A
  synthetic recording spelled EchoType, Zustand and TanStack wrong even as keyterms; see
  the [research](../research/apple-on-device-provider.md).
