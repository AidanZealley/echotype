# 0004 Session and socket lifecycle belong to the session machine

Status: accepted, 2026-09-22 (EchoTypeCore), extended 2026-09-23 (dictation).

## Context

Streaming is billed while the socket is open, sends must not reorder, and any failure
has to reach the user without losing text they already spoke.

## Decision

- `STTClient` neither opens nor closes the socket. `SessionMachine` owns the lifecycle
  through `WebSocketTransport.close()`.
- `STTClient.send(audio:)` returns once its chunk is on the wire, and every send,
  including `finalize` and `audio.done`, is chained behind the previous one. That
  keeps closing messages from overtaking audio, surfaces a failed chunk to its caller
  and gives capture back pressure.
- Text reaches the target app only on an explicit trigger or the ten minute hard cap.
  A `transcript.done` outside `finalizing` ends the session as
  `failed(text:error:)`. The accumulated text is still inserted, but the macOS layer is
  never handed a clean commit it didn't trigger.
- One undecodable frame ends the session as a socket failure. An unrecognised event
  `type` is skipped.
- The wait in `finalizing` is bounded by `Settings.finalizeTimeout` (8s). Expiry
  produces `failed(text:error:)`, not a hang.

## Consequences

- The overlay must extend `SessionMachine` to read live text. It must not open a second
  reader on the socket, because a WebSocket message goes to one reader.
- A dictation committed before `transcript.created` arrives inserts nothing and reports
  nothing. That doesn't matter for 20 to 60 second prompts, and the overlay's starting
  state tells the user when to speak.
