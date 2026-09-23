# 0005 Open the microphone per session and release it when the session ends

Status: accepted, 2026-09-23 (dictation gate G1). Replaces the specification's
original warm idle hold.

## Context

The specification originally held the input device warm through a few minutes of
idle to avoid the 100 to 300ms open cost. A warm microphone keeps the orange macOS
indicator lit after dictation ends, which Aidan found disconcerting.

## Decision

- `AudioCapture.stop()` ends delivery and closes the device. There is no idle hold and
  no separate acquire step.
- The controller opens the microphone before the socket, so a denied grant never opens
  a billed socket.
- Opt+D commits by stopping capture first, so the pump drains the tail before
  `trigger()`. Otherwise the last word can be dropped after `audio.done`.
- Audio reaches the session as 16 kHz mono little-endian Int16 `Data` in roughly 100ms
  chunks. The chunk cadence is the capture layer's job, not `AudioConverter`'s.
- The app follows the system default input.

## Consequences

- Every session pays the device open. On the MacBook Pro microphone that caused no
  first-word clipping, cold or back to back.
- The specification's overlay gains a starting state between Opt+D and audio flowing,
  so the user sees when to speak. The overlay milestone implements it.
- Bluetooth earbuds produce wrong transcripts. The endpoint gets faint headset-profile
  audio and returns guesses or the keyterm prompt, and the profile switch loses the
  opening seconds. Input device choice or a warning belongs with settings.
