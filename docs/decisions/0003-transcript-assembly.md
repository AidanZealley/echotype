# 0003 Transcript assembly rules

Status: accepted, 2026-09-22 (EchoTypeCore workstream 2), extended 2026-09-24 (overlay)
and 2026-09-27 (live revision).

## Context

The specification says `speech_final` segments are "concatenated in order". Taken
literally, that runs the last word of one utterance into the first word of the next.

The overlay then needed the live transcript split into settled text, rendered solid, and
provisional text, rendered dimmed. Live revision also needs committed segments separate
from the current utterance, whose settled runs can still be replaced by `speech_final`.

## Decision

- Each `speech_final` segment is trimmed and segments are joined with a single space,
  with nothing added at either end.
- `SessionMachine` owns the session's one `TranscriptAssembler`. The machine already
  decodes every frame to drive pausing, so a second assembler in `STTClient` would hold
  the same transcript twice. `STTClient` keeps only the socket protocol: holding audio
  until `transcript.created`, send ordering and the closing messages.
- The machine publishes `snapshots`, each holding the state, `committed`, `utterance` and
  `provisional`.
  A snapshot is published on every state transition and every transcript change,
  never twice in a row with the same value, and the stream finishes when `run()` does.
- The recorded frames show how `is_final` runs compose. Within an utterance each partial
  carries only the run since the last `is_final`. An `is_final` frame carries that run in
  its final form and starts the next. `speech_final` resends the whole utterance. So the
  assembler appends each non-empty `is_final` run to the current utterance, replaces the
  provisional tail with each non-final partial, and on `speech_final` replaces the runs
  with the frame's text.
- `committed` contains the append-only segments closed by `speech_final` or
  `transcript.done`. `utterance` contains the current utterance's `is_final` runs, and
  `provisional` is the run since the last `is_final`. The overlay joins the committed
  text, possibly revised under [0021](0021-revise-committed-dictation.md), with the
  current runs. The final revised text is inserted when cleanup is on.
- On `transcript.done`, the assembler commits the whole unfinished utterance: its
  `is_final` runs plus the provisional tail. Under the observed protocol this never
  fires, because `finalize` resolves the tail into a `speech_final` first (see
  [0002](0002-speech-signal-from-observed-protocol.md)).

## Consequences

- `utterance` is not append-only, because `speech_final` replaces its runs wholesale.
  Only `committed` can be used as the reviser's growing input.
- The `done` fallback cannot commit a fragment. It is still untested against the live
  endpoint.
- After a failure, the pill can show `is_final` runs of the unfinished utterance that
  `Outcome.failed(text:)` does not insert, since only committed segments are inserted.
