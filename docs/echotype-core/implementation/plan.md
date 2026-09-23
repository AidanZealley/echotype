# EchoTypeCore implementation plan

Status: approved; all workstreams and the whole-feature review accepted.

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
| 3 | [Live protocol validation](03-live-protocol-validation.md) | Workstream 2 | Accepted |
| 4 | [Session machine](04-session-machine.md) | Workstreams 2, 3 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-4 | Accepted |

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
| G1 xAI API key and a sample recording | 3 | Before implementation can be verified | Passed |

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

None open. E1 and E2 were answered and discharged at workstream 3's acceptance;
their lasting decisions are in the decision and drift log below.

## Carry-forward

Items that outlive this workflow were reconciled with the macOS spike's own list, once
the two branches met, into [docs/open-items.md](../../open-items.md). Nothing there
blocks this branch.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-21 | Manifest declares EchoTypeCore only, with no conditional macOS app target | The app target does not exist on this branch; the specification's snippet describes the merged manifest | Aidan | 1 |
| 2026-09-21 | The roughly 100ms chunk cadence is the macOS capture layer's obligation, not `AudioConverter`'s | The specification assigns chunking to the `AVAudioEngine` tap; the converter returns what is ready for the buffer it is handed, and `installTap` treats buffer size as a hint | Lead, workstream 1 | 1, and the later macOS capture milestone |
| 2026-09-22 | `speech_final` segments are joined with a single space, each trimmed, with nothing added at either end | The specification says "concatenated in order", which taken literally runs the last word of one utterance into the first word of the next | Lead, workstream 2 | 2, 3, 4 |
| 2026-09-22 | `TranscriptAssembler` commits a trailing interim when `transcript.done` arrives | A no-op under the documented reading, since a `speech_final` clears the interim as it commits, and it recovers the user's last sentence if `finalize` instead resolves the tail with `is_final` alone. The assembler contract freezes here, so the choice had to be made before workstreams 3 and 4 build on it | Lead, workstream 2 | 2, 3, 4 |
| 2026-09-22 | `STTClient.send(audio:)` returns only once its chunk is on the wire; every send, including the closing messages, is chained behind the send handed over before it | Ordering is the correctness property that matters: `finalize` and `audio.done` must not overtake audio still in flight, and awaiting is what surfaces a failed chunk to its own caller and gives the capture layer back pressure | Lead, workstream 2 | 2, 4 |
| 2026-09-22 | `STTClient` neither opens nor closes the socket; `WebSocketTransport.close()` exists on the seam for workstream 4's session machine | The specification bills streaming time for an open socket, so lifecycle belongs with the session machine rather than the protocol client | Lead, workstream 2 | 2, 4 |
| 2026-09-22 | The live session runs on this machine, not the Mac: curl 8.11.1 built from source with `--enable-websockets` lives at `~/.local/curl-ws`, and any command opening a real socket is prefixed with `LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib` | Ubuntu 24.04's only libcurl is built without websockets, so `URLSessionWebSocketTask` fails with `NSURLErrorDomain -1002` unprefixed. Verified end to end against `echo.websocket.org` and `api.x.ai`. The loader's `no version information available` warning is benign | Aidan, via E1 | 3, and anything later that opens a socket here |
| 2026-09-22 | The gate's inputs live outside the repository: the key as `XAI_API_KEY` in `~/secrets/secrets.env`, read or sourced rather than exported, and the recording at `~/echotype-fixtures/sample-with-pauses.wav`, passed through `ECHOTYPE_FIXTURE_WAV` | Criterion 3 forbids a key, recording or transcript in any committed file, and the key must never be printed, logged or committed | Aidan, via E1 and E2 | 3 |
| 2026-09-22 | The fixture is public-corpus speech with two inserted 3.5s digital silences, not Aidan's voice and not room tone | Aidan chose a public sample over recording himself. Digital silence is the easiest case a voice activity detector will ever get, so the observed 2.7-2.9s endpointing window is the shortest it gets; a room floor may push it later. Anomalous behaviour is a property of the fixture before it is a property of the protocol | Aidan, via E1 | 3, 4 |
| 2026-09-22 | Drift: `STTEvent.Word`'s word is `text`, not `word`. Workstream 2's type was corrected | The endpoint sends `{"text":...,"start":...,"end":...}`, so `decode` threw on every frame with a populated `words` array. Since `words` arrives only on `is_final` frames and every `speech_final` frame is one, the failure discarded exactly the frames the transcript is assembled from: 8 of 28 partials in the first live session, leaving only the last passage. Fixed and verified by the rerun | Lead, workstream 3, under the packet's Initial ownership | 2, 3, 4 |
| 2026-09-22 | `confidence` stays on `STTEvent.Word` although the endpoint never sent it in 30 frames | An unused optional field that decodes correctly either way is not a defect the live protocol exposed, which is the only licence workstream 3 has to touch a frozen contract. Workstream 4 must not expect it to be populated | Lead, workstream 3 | 4 |
| 2026-09-22 | Drift: the specification's silence detection is false as written and must change. "No new partials means silence" (lines 85-87) and its restatement for the `listening`/`paused` transition (lines 382-385) both assume partials stop during silence | Observed: partials keep arriving at ~1 Hz with `"text":""` throughout a silence, and nothing arrives at all during the ~2-3s the endpoint spends deciding where an utterance ends, so the documented detector sees activity during silence and silence during speech. The signal is a partial with **non-empty text**, or the last `speech_final`. Entering paused lags the end of speech by about 3s and leaving it lags resumed speech by 0.7-2.3s, both comfortable against the ten second threshold. Wording, not code; Aidan decides whether it lands in workstream 4 or 5 | Lead, workstream 3, recorded not fixed per the packet's non-goals | 4, 5, and the specification |
| 2026-09-22 | Clarification: `endpointing=2000` is a floor, not the boundary. Budget 2.73-2.80s from the endpoint's own last reported word `end` to the declared boundary, and about 3.0s of wall clock to the `speech_final` frame being in hand | Measured across two acoustically different pauses, agreeing to 75ms. The specification never claims a 2000ms boundary, so this is not a contradiction, but any timing written against 2000ms is wrong by a second | Lead, workstream 3 | 4, and the specification |
| 2026-09-22 | Clarification: `transcript.done` is empty. `finalize` resolves the tail into a further `speech_final` partial that arrives before `done` | `{"type":"transcript.done","text":"","words":[],"duration":25.0}`. `TranscriptAssembler` is correct and its `done` fallback never fired, but that fallback commits `interim`, which holds only the run since the last `is_final`, so it would commit a fragment if it ever fired mid-utterance. Workstream 4 must not rely on it | Lead, workstream 3 | 4 |
| 2026-09-22 | Known gap, left for the final review: nothing in the committed suite constructs or decodes an `STTEvent.Word` | That untested path is exactly what the live endpoint exercises on every frame the transcript is assembled from, which is how the `text`/`word` defect reached a paid session. Closing it means one optional `words` argument on `Fixture.partial` and one expectation, but `STTEventTests` belongs to workstream 2, which is accepted, and workstream 3's ownership does not reach it | Lead, workstream 3 | Final review |
| 2026-09-22 | Workstream 3's silence drift is now implemented, not merely recorded: `SessionMachine` treats a partial with non-empty text, or a `speech_final`, as speech, and ignores `start` and `duration` | The specification's "no new partials means silence" (lines 85-87, restated at 382-385) sees activity during silence and silence during speech against the real endpoint. The code follows the observation; the specification's wording is still wrong and still needs Aidan's edit, which remains open between workstream 5 and the final review | Lead, workstream 4 | 4, 5, and the specification |
| 2026-09-22 | A `transcript.done` arriving outside `finalizing` does not commit. It ends the session the same way a dropped socket does, as `failed(text:error:)` carrying whatever was finalised | The specification's rule that text reaches the target app only on an explicit trigger or the hard cap outranks the observed endpoint never sending `done` early. The accumulated text still survives, and the macOS layer is told the session ended without being asked rather than being handed a clean commit it never triggered | Lead, workstream 4 | 4, and the macOS insertion layer |
| 2026-09-22 | Known gap, left for the macOS layer: nothing bounds the wait for `transcript.done` after `finalize`, so a hung endpoint leaves a session in `finalizing` | Workstream 3 saw `done` arrive within 10ms and the server close 2s later, so a timeout here would be machinery for a failure never observed. Session supervision belongs to the layer that owns the overlay and can tell the user | Lead, workstream 4 | The macOS milestone |
| 2026-09-22 | Drift: the specification lists "Settings and Keychain-adjacent serialisation round trips" under what is tested here, and `Settings` has neither serialisation nor a test | Workstream 1 scoped persistence out deliberately and the scope call never reached this log, so both documents read as if the list were satisfied. A `Codable` conformance written now would guess at the `UserDefaults` and Keychain encoding the macOS layer owns. The round trip is still where the real bugs live: whoever writes that encoding owes it a test, or a hotkey that silently stops firing after an upgrade surfaces as a mystery | Lead, final review | The macOS settings and Keychain milestone |
| 2026-09-22 | Known gap, left for the overlay milestone: no live transcript text crosses the session seam. `SessionMachine` exposes states and the final outcome, and the committed and interim text are reachable only inside it | Designing that seam now means guessing what the overlay needs, which is the kind of extension point this review exists to reject. The overlay milestone designs it against its own requirements, including the level meter and dimmed interim text. It must extend `SessionMachine`, not open a second read of the socket: a WebSocket message goes to one reader. Two comments claiming the overlay already rendered these fields have been corrected | Lead, final review | The overlay milestone |
| 2026-09-22 | Closed: workstream 3's known gap around `STTEvent.Word`. `Fixture.partial` now emits `words` in the live shape and `partialDecodesItsPayload` asserts decoded `Word` values | Renaming `text` back to `word` fails that test with `keyNotFound`, and fails the undecodable-frame test with it, so the defect that reached a paid session cannot recur silently | Lead, final review | 2, 3, 4 |
| 2026-09-22 | Clarification: an unsolicited `transcript.done` changed the ending's classification, not whether the text reaches the editor. `failed(text:error:)` still carries the transcript, and the session still passes through `inserting` when there is text, exactly as a dropped socket does | The specification tells the macOS layer to insert the text carried by a failure alongside the error, so the user keeps a minute of dictation instead of losing it. What the rule prevents is the layer being handed a clean commit it never triggered | Lead, final review | 4, and the macOS insertion layer |
| 2026-09-22 | Drift: one frame the session cannot decode ends the session as a socket failure rather than being skipped | `SessionMachine.readUntilEnd` swallowed the decode failure with `try?` while `STTClient.run` rethrew it, so the client task died unnoticed while the session kept reporting `listening` and the trigger reported a truncated transcript as a clean insert. The two now agree that an undecodable frame is fatal and that an unrecognised event `type`, which `decode` returns `nil` for, is not | Lead, final review | 4, and the macOS insertion layer |
