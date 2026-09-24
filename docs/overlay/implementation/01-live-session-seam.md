# Workstream 1: Live session seam

Status: not started.

## Task packet

### Outcome

`SessionMachine` publishes what the overlay renders: its state, the settled transcript
and the provisional tail, as one stream of snapshots. The text it inserts and the text it
shows come from one assembler. The app builds and dictates exactly as before.

### Scope

**One assembler per session.** `SessionMachine` already decodes every frame in `observe`
to drive pausing, and `STTClient` decodes the same frames again to assemble the text.
Make the machine own the session's `TranscriptAssembler`: apply each decoded event to it,
and take the final text for `Outcome` from it. `STTClient` keeps its protocol jobs
(holding audio until `transcript.created`, ordering sends, sending `finalize` and
`audio.done`) and stops assembling. This is a suggestion for the mechanics; the hard
requirement is that one session holds its transcript once.

Keep the survival rule from [0004](../../decisions/0004-session-lifecycle.md): a session
that fails, times out or closes early still inserts the segments committed before the
failure.

**Settled and provisional text.** The specification renders text that arrived with
`is_final` solid and interim text dimmed. Today `TranscriptAssembler` exposes `text`
(committed `speech_final` segments) and `interim` (the latest partial), and nothing
marks `is_final` runs inside a segment as settled.

Before coding, work out from the recorded frames how `is_final` runs compose within a
segment. Sources: `Tests/EchoTypeCoreTests/STTFixtures.swift`, the live protocol test in
`Tests/EchoTypeCoreTests/Integration/`, and
[0002](../../decisions/0002-speech-signal-from-observed-protocol.md) and
[0003](../../decisions/0003-transcript-assembly.md). Record what you found in the
handoff. Then give the assembler what the overlay needs: settled text (committed
segments plus any settled runs of the current segment, joined the way committed text is
joined) and the provisional tail. What gets inserted does not change: committed
`speech_final` segments, plus the `done` fallback from 0003.

If the recorded frames cannot tell you how `is_final` runs compose, render only
committed segments solid and the whole current partial dimmed, and record that as drift.
Do not spend a live session to find out.

**The snapshot stream.** Replace `states: AsyncStream<State>` with one stream of
snapshots holding the state, the settled text and the provisional text. Publish a
snapshot on every state transition and on every change to either text, and finish the
stream when the session ends. The final snapshot carries the last text, so the pill can
keep showing it through `transcribing`. Name things well and record the names in the
handoff; workstream 3 reads them there.

Keep one stream. A second stream for text alongside `states` would make the overlay
merge two orderings of the same session.

**The controller, adapted.** `DictationController` consumes `states` today. Change it to
consume the snapshots and mirror only the state into its `state` property, as it does
now. Nothing else in the app changes.

**The gap list.** Remove the "No live text crosses the session seam" item from
`docs/decisions/0007-known-gaps.md`.

### Non-goals

- Any overlay, view or panel code.
- Elapsed time or input level in the snapshot. Elapsed time is the app's to compute from
  when the session started. The level comes from the microphone, not the socket.
- A `starting` state in `SessionMachine`. The machine starts at `listening`; the time
  before audio flows belongs to the controller, in workstream 3.
- Changing pause, cancel, finalize or hard cap behaviour, or any `Settings` value.
- Changing `Outcome`.

### Initial ownership

- `Sources/EchoTypeCore/SessionMachine.swift`
- `Sources/EchoTypeCore/STT/TranscriptAssembler.swift`
- `Sources/EchoTypeCore/STT/STTClient.swift`, only to stop it assembling
- `Tests/EchoTypeCoreTests/`
- `Sources/EchoTypeApp/DictationController.swift`, only to consume the new stream
- `docs/decisions/0007-known-gaps.md`, for the one item above

### Required seams

- Consumed: `STTEvent` and its decoding, `WebSocketTransport`, `SessionClock`, `Settings`.
- Produced: the snapshot stream described in the plan's cross-workstream contracts.

### Acceptance criteria

1. `SessionMachine` publishes snapshots carrying state, settled text and provisional
   text, and no longer exposes `states`.
2. Each session holds its transcript in one assembler. The inserted text and the
   displayed settled text are read from it.
3. Tests, driven through recorded-shape frames and the injected clock, cover:
   provisional text shown and then superseded; settled text accumulating across two
   `speech_final` segments; text surviving several pause and resume cycles; the final
   snapshot carrying the last text; and a socket failure still inserting committed text.
4. `is_final` handling follows what the recorded frames show, and the handoff says what
   that was.
5. Every existing test either still passes unchanged or was changed only because it read
   `states` or the client's assembled text.
6. The app builds, and `DictationController` mirrors state from the snapshots.
7. The 0007 item is removed.

### Targeted verification

```bash
swift build
timeout 120 swift test --disable-xctest
swift-format lint --recursive Sources Tests Package.swift
```

Put new tests beside the existing ones in `SessionMachineTests.swift` and
`TranscriptAssemblerTests.swift`. Test what the overlay will read, not how the machine
stores it.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- How `is_final` runs compose in the recorded frames: `TBD`
- Snapshot API (names and when snapshots are published): `TBD`
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
