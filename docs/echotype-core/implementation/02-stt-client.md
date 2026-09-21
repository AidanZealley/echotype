# Workstream 2: STT client and transcript assembler

Status: not started.

## Task packet

### Outcome

A client that connects to the xAI streaming endpoint through a transport protocol,
sends audio, interprets the event stream, and produces final text. Its logic is fully
tested against recorded event fixtures with no live socket.

### Scope

- Decoded event types for `transcript.created`, `transcript.partial`,
  `transcript.done` and `error`, matching the specification's API facts section.
  `transcript.partial` carries `text`, `words`, `is_final` and `speech_final`.
- Encoded client messages `{"type":"finalize"}` and `{"type":"audio.done"}`.
- A query string builder producing the connection URL from `Settings`:
  `encoding=pcm`, `sample_rate=16000`, `interim_results=true`, `endpointing=2000`,
  `filler_words=false`, `format=true`, the language, and one repeated `keyterm`
  parameter per term. It caps at 100 terms and 50 characters per term, and percent
  encodes terms containing spaces.
- `WebSocketTransport`, a protocol covering sending binary frames, sending text
  frames, receiving a stream of messages and closing. One conforming implementation
  backed by `URLSessionWebSocketTask` under
  `#if canImport(FoundationNetworking)`, and one fake used by tests.
- `STTClient`, which waits for `transcript.created` before sending any audio, forwards
  binary frames, sends `finalize` then `audio.done` when asked to finish, and
  surfaces a typed error for the documented HTTP statuses.
- `TranscriptAssembler`, producing final text as every `speech_final` segment in order
  plus whatever trailing partial the `finalize` resolves into.

### Non-goals

- Session lifecycle, pausing, timeouts and the hard cap. That is workstream 4.
- Running against the live service. That is workstream 3.
- Reconnection and backpressure. The specification keeps one socket per session and
  opens it on trigger.
- Batch transcription against `POST /v1/stt`. The settings Test button needs it, but
  that is a later milestone and no acceptance criterion here depends on it.
- Retry policy. A failed session surfaces its error.

### Initial ownership

Creates and owns `Sources/EchoTypeCore/STT/` and its tests. May extend `Settings` with
fields the query string needs, recording the addition in its handoff.

Must not change `AudioConverter` or the package layout. Those are frozen by
workstream 1.

### Required seams

Freezes for workstreams 3 and 4: the event types, the `WebSocketTransport` protocol
and the `TranscriptAssembler` contract.

### Acceptance criteria

1. `swift build`, `swift test --disable-xctest` and `swift-format lint` all pass.
2. The assembler produces correct text for each of these, driven by fixtures: a
   partial superseded by a later partial; several `speech_final` segments accumulating
   in order; a `finalize` resolving a trailing partial; events arriving after
   `audio.done`; a session yielding no text at all.
3. Interim text is never treated as committed. A test proves that text which is later
   rewritten does not appear in the final output.
4. The client sends no audio before `transcript.created` arrives.
5. The query builder enforces the 100 term and 50 character caps and encodes terms
   containing spaces correctly.
6. Each documented error status maps to a distinguishable typed error.
7. The live transport compiles on Linux and is never exercised by the unit tests.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift-format lint --recursive Sources Tests
```

New focused tests using the fake transport and fixture event streams. Test the
observable contract, not the client's internal state names.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`
