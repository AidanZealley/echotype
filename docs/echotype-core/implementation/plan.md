# EchoTypeCore implementation plan

Status: approved; implementation in progress.

## Orchestration record

- Runs on: the remote Linux machine.
- Integration branch: `feat/echotype-core`
- Starting commit: `2c57765`
- Review command: `lead subagents`
- Specification approved at commit: `bbb5f41`
- Started: `2026-09-21`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Package skeleton and audio converter](01-package-and-audio-converter.md) | Approved spec | Accepted |
| 2 | [STT client and transcript assembler](02-stt-client.md) | Workstream 1 | Accepted |
| 3 | [Live protocol validation](03-live-protocol-validation.md) | Workstream 2 | Not started |
| 4 | [Session machine](04-session-machine.md) | Workstreams 2, 3 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-4 | Not started |

## Why these boundaries

Workstream 1 establishes the package and delivers the audio converter, which is pure
numeric work with no dependency on anything else. It is the natural place to prove the
build and test setup on a trivially verifiable piece of logic.

Workstream 2 owns everything about interpreting the xAI protocol: the event types, the
query string, the transport seam and the assembler that turns events into text. These
belong together because they are one contract with one external service, and splitting
them would mean freezing a seam between halves of the same idea.

Workstream 3 runs the real protocol and records what it actually does. It is separate
because its deliverable is knowledge rather than product code, and because it depends
on a key and a recording that only Aidan can supply.

Workstream 4 builds the session machine on top of observed behaviour rather than
documented behaviour. The specification's pause logic rests on `speech_final` meaning
what the documentation says, and the specification names that as a known risk.

The order puts validation before the component that depends on it. If workstream 3
blocks for want of a key, the user decides whether to supply one or have workstream 4
proceed on documented semantics.

## Cross-workstream contracts

Frozen by workstream 1:

- `Package.swift` declares the `EchoTypeCore` library and `EchoTypeCoreTests`. Swift
  tools version 6.2. No external dependencies.
- `EchoTypeCore` imports Foundation only. `FoundationNetworking` is permitted behind
  `#if canImport(FoundationNetworking)` in the one file that constructs a real socket.
- The `Settings` value type is the single source of every tunable the specification
  names.

Frozen by workstream 2 and relied on by workstreams 3 and 4:

- The decoded event types for `transcript.created`, `transcript.partial`,
  `transcript.done` and `error`, including `text`, `words`, `is_final` and
  `speech_final`.
- The `WebSocketTransport` protocol, which is how every consumer reaches a socket.
- The `TranscriptAssembler` contract: given an ordered event stream, produce the final
  text.

A lead that finds a defect in a frozen contract raises an escalation rather than
rewriting it, because the fix belongs to the owning workstream and may already be
accepted.

## Ownership handoffs

Workstream 1 creates `Package.swift`, `Sources/EchoTypeCore/Settings.swift`,
`Sources/EchoTypeCore/AudioConverter.swift` and their tests.

Workstream 2 adds files under `Sources/EchoTypeCore/STT/` and its tests. It may extend
`Settings` with fields the query string needs, recording that in its handoff.

Workstream 3 adds an integration test and a fixture directory. It does not change
production code except to fix a defect the live protocol exposes, which it records as
drift.

Workstream 4 adds `Sources/EchoTypeCore/SessionMachine.swift` and its tests. It
consumes workstream 2's types without changing them.

## Whole-feature acceptance

Final review begins after all four workstreams are accepted.

```bash
swift build
swift test --disable-xctest
swift-format lint --recursive Sources Tests
```

Pending and explicitly not covered here: everything requiring macOS. Audio capture,
the event tap, the overlay panel, pasteboard insertion and TCC behaviour belong to the
macOS spike workflow and to later milestones.

## External validation gates

| Gate | Owning workstream | Placement | Status |
|---|---|---|---|
| G1 xAI API key and a sample recording | 3 | Before implementation can be verified | Pending |

G1 candidate and instructions: Aidan supplies an xAI API key as `XAI_API_KEY` in the
environment on this machine, and a short WAV recording of himself speaking, roughly 15
to 30 seconds, containing at least two deliberate pauses of three seconds or more. The
pauses are the point: they are what makes `speech_final` observable.

Required evidence: the recorded event sequence from a live session, showing when
`transcript.partial` arrives, when `is_final` and `speech_final` are set, how
`endpointing` affects segmentation, and what `transcript.done` returns after
`finalize` and `audio.done`.

Resume condition: the event sequence is recorded in the workstream record and any
contradiction with the specification is noted as drift.

If Aidan declines to supply a key, workstream 3 is closed as not run and workstream 4
proceeds on documented semantics, with the risk recorded in the decision and drift log.
That is a user decision, not a lead decision.

## Escalations

Empty until a lead blocks.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-21 | Manifest declares EchoTypeCore only, with no conditional macOS app target | The app target does not exist on this branch; the specification's snippet describes the merged manifest | Aidan | 1 |
| 2026-09-21 | The roughly 100ms chunk cadence is the macOS capture layer's obligation, not `AudioConverter`'s | The specification assigns chunking to the `AVAudioEngine` tap; the converter returns what is ready for the buffer it is handed, and `installTap` treats buffer size as a hint | Lead, workstream 1 | 1, and the later macOS capture milestone |
| 2026-09-22 | `speech_final` segments are joined with a single space, each trimmed, with nothing added at either end | The specification says "concatenated in order", which taken literally runs the last word of one utterance into the first word of the next | Lead, workstream 2 | 2, 3, 4 |
| 2026-09-22 | `TranscriptAssembler` commits a trailing interim when `transcript.done` arrives | A no-op under the documented reading, since a `speech_final` clears the interim as it commits, and it recovers the user's last sentence if `finalize` instead resolves the tail with `is_final` alone. The assembler contract freezes here, so the choice had to be made before workstreams 3 and 4 build on it | Lead, workstream 2 | 2, 3, 4 |
| 2026-09-22 | `STTClient.send(audio:)` returns only once its chunk is on the wire; every send, including the closing messages, is chained behind the send handed over before it | Ordering is the correctness property that matters: `finalize` and `audio.done` must not overtake audio still in flight, and awaiting is what surfaces a failed chunk to its own caller and gives the capture layer back pressure | Lead, workstream 2 | 2, 4 |
| 2026-09-22 | `STTClient` neither opens nor closes the socket; `WebSocketTransport.close()` exists on the seam for workstream 4's session machine | The specification bills streaming time for an open socket, so lifecycle belongs with the session machine rather than the protocol client | Lead, workstream 2 | 2, 4 |
