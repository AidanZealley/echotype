# 0003 Transcript assembly rules

Status: accepted, 2026-09-22 (EchoTypeCore workstream 2).

## Context

The specification says `speech_final` segments are "concatenated in order". Taken
literally, that runs the last word of one utterance into the first word of the next.

## Decision

- Each `speech_final` segment is trimmed and segments are joined with a single space,
  with nothing added at either end.
- On `transcript.done`, `TranscriptAssembler` commits any trailing interim text. Under
  the observed protocol this never fires, because `finalize` resolves the tail into a
  `speech_final` first (see [0002](0002-speech-signal-from-observed-protocol.md)).

## Consequences

The `done` fallback commits only the run since the last `is_final`. If it ever fired
mid-utterance it would commit a fragment, so nothing should depend on it.
