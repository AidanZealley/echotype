# 0003 Transcript assembly rules

Status: accepted, 2026-09-22 (EchoTypeCore workstream 2), extended 2026-09-24 (overlay).

## Context

The specification says `speech_final` segments are "concatenated in order". Taken
literally, that runs the last word of one utterance into the first word of the next.

The overlay then needed the live transcript split into settled text, rendered solid, and
provisional text, rendered dimmed, from the same assembler that produces the inserted
text.

## Decision

- Each `speech_final` segment is trimmed and segments are joined with a single space,
  with nothing added at either end.
- `SessionMachine` owns the session's one `TranscriptAssembler`. The machine already
  decodes every frame to drive pausing, so a second assembler in `STTClient` would hold
  the same transcript twice. `STTClient` keeps only the socket protocol: holding audio
  until `transcript.created`, send ordering and the closing messages.
- The machine publishes `snapshots`, each holding the state, `settled` and `provisional`.
  A snapshot is published on every state transition and every change to either text,
  never twice in a row with the same value, and the stream finishes when `run()` does.
- The recorded frames show how `is_final` runs compose. Within an utterance each partial
  carries only the run since the last `is_final`. An `is_final` frame carries that run in
  its final form and starts the next. `speech_final` resends the whole utterance. So the
  assembler appends each non-empty `is_final` run to the current utterance, replaces the
  provisional tail with each non-final partial, and on `speech_final` replaces the runs
  with the frame's text.
- `settled` is the committed segments plus the current utterance's `is_final` runs.
  `provisional` is the run since the last `is_final`. `text` is still the only inserted
  text.
- On `transcript.done`, the assembler commits the whole unfinished utterance: its
  `is_final` runs plus the provisional tail. Under the observed protocol this never
  fires, because `finalize` resolves the tail into a `speech_final` first (see
  [0002](0002-speech-signal-from-observed-protocol.md)).

## Consequences

- `settled` is not append-only, because `speech_final` replaces an utterance's runs
  wholesale. Nothing should treat it as growing only at its end.
- The `done` fallback cannot commit a fragment. It is still untested against the live
  endpoint.
- After a failure, the pill can show `is_final` runs of the unfinished utterance that
  `Outcome.failed(text:)` does not insert, since only committed segments are inserted.
