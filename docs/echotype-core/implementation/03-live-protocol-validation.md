# Workstream 3: Live protocol validation

Status: accepted. Gate G1 passed. Two live sessions ran on 2026-09-22 against
`wss://api.x.ai/v1/stt` with a working key, the WebSocket-capable libcurl and the 25s fixture.
The full event sequence was recorded and the Findings section below is written from it. The
session exposed one genuine defect in workstream 2's event types, fixed minimally and recorded
as drift. Workstream 4 builds on the Findings section; read it before the session machine.

## Task packet

### Outcome

A recorded, evidence-backed account of how the xAI streaming endpoint actually
behaves, and one integration test that reproduces it. The specification's pause
behaviour was written from documentation; this workstream replaces that assumption
with observation.

### Scope

- One integration test that connects to `wss://api.x.ai/v1/stt` using the transport
  from workstream 2, streams a fixture WAV as 16 kHz PCM through the converter from
  workstream 1, and records the full event sequence.
- The test is skipped unless `XAI_API_KEY` is present in the environment, so the normal
  test run is unaffected and no secret is ever committed.
- A written record, in this document, answering these questions:
  - When does `transcript.partial` arrive, and how often?
  - What exactly distinguishes `is_final` from `speech_final`?
  - Does a `speech_final` reliably follow roughly `endpointing` milliseconds of
    silence, and does the specification's `endpointing=2000` behave as expected across
    a deliberate pause?
  - What does `transcript.done` return after `finalize` then `audio.done`, and does it
    repeat text already delivered or only the remainder?
  - Does anything arrive that the specification does not describe?
- Any contradiction with the specification recorded as drift, with enough evidence for
  Aidan to decide whether to change the specification or the implementation.

### Non-goals

- Building the session machine. That is workstream 4, which consumes these findings.
- Load testing, latency benchmarking or cost measurement.
- Testing the batch endpoint.
- Making the integration test part of the default suite. It costs money and needs a
  network.
- Fixing a specification defect this workstream discovers. Record it; the owning
  workstream or Aidan decides.

### Initial ownership

Creates and owns `Tests/EchoTypeCoreTests/Integration/` and a fixtures directory.

Does not change production code, except to fix a defect the live protocol exposes in
workstream 2's types, which must be recorded as drift and named in the handoff.

### Required seams

Consumes workstream 2's event types, `WebSocketTransport` and its live implementation,
and workstream 1's `AudioConverter`. Produces findings that workstream 4 depends on.

### Acceptance criteria

1. The integration test runs against the live service and passes, or the workstream is
   closed as not run following Aidan's decision at gate G1.
2. `swift test --disable-xctest` still exits 0 with `XAI_API_KEY` unset, with the
   integration test skipped rather than failed.
3. No API key, recording or transcript appears in any committed file.
4. Every question in the Scope section is answered in the Findings section below, from
   observed evidence rather than from the documentation.
5. Any contradiction with the specification is recorded as drift.

### Targeted verification

```bash
swift test --disable-xctest
XAI_API_KEY=<supplied by Aidan> swift test --disable-xctest
```

## External validation

- Gate and placement: G1, before the implementation can be verified.
- Status: `Passed`
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md). The recording half is satisfied: escalation E1 records a 25s 16 kHz
  mono PCM16 sample with two inserted 3.5s silences at `~/echotype-fixtures/`, outside the
  repository, read through `ECHOTYPE_FIXTURE_WAV`. Only a working `XAI_API_KEY` is
  outstanding. The documented command is in the doc comment at the top of
  `Tests/EchoTypeCoreTests/Integration/LiveProtocolTests.swift`.
- Required evidence: the full recorded event sequence from one live session, which the
  harness prints to standard output.
- Attempts and lasting decisions: the gate could not be attempted. Neither the key nor a
  recording is present on this machine, and a second blocker makes the key insufficient
  on its own: `URLSessionWebSocketTask` cannot open a WebSocket here at all. The system
  libcurl is 8.5.0, built without `ws`/`wss`, so every attempt fails immediately with
  `NSURLErrorDomain -1002 "WebSockets not supported by libcurl"`. The lead verified this
  directly against both `wss://echo.websocket.org` and `wss://api.x.ai/v1/stt`, and
  `curl --version` lists no `ws` protocol. This is not a connection or encoding failure
  the lead can diagnose and correct, so it is an escalation rather than a troubleshooting
  loop. Only the live socket is affected; the rest of the package builds and tests here
  normally.
- Attempt 2, 2026-09-22, the first run with every precondition supplied. Aidan provided a
  libcurl built with WebSocket support at `~/.local/curl-ws`, the key in `~/secrets/secrets.env`
  and a 25s 16 kHz mono PCM16 recording with two inserted 3.5s silences. The documented
  command ran the harness end to end. Two results:
  - The libcurl blocker recorded in attempt 1 is gone. With
    `LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib`, `URLSessionWebSocketTask` no longer fails with
    `NSURLErrorDomain -1002`. The handshake reached `api.x.ai` and the server answered, so the
    transport, the WAV reader and the session driver are exercised against a real socket for
    the first time. The loader's `no version information available` warning is benign.
  - The session failed at the handshake in 0.70s, before any audio was sent, with
    `HTTP 400` mapped to `STTError.badRequest`. The response body is
    `{"code":"Client specified an invalid argument","error":"Incorrect API key provided. ..."}`,
    not a rejected query parameter. Confirmed as a credential problem rather than anything in
    this workstream: the same key returns the same 400 from `GET /v1/models` and
    `GET /v1/api-key` with no WebSocket headers involved, and presenting no credential at all
    returns a different status, `401 unauthenticated:no-credentials`, so the key is read and
    then rejected. The key as supplied is well formed: 82 characters, `xai-` prefix, ASCII
    alphanumerics and dashes only, no whitespace, no quoting in the env file.
  - Not a troubleshooting-loop failure. Nothing in the URL, the encoding, the framing or the
    event types can make a rejected credential valid, so no correction was attempted and no
    code was changed. The gate needs a working key from Aidan.
  - Cost: none beyond the handshake. No audio was billed.
- Attempt 3, 2026-09-22, the gate passed. With a working key, the same libcurl and the same
  fixture, the documented command ran two complete live sessions against
  `wss://api.x.ai/v1/stt`, 25s of audio each, paced in real time as 100ms binary frames, closed
  with `finalize` then `audio.done`.
  - Both sessions completed: `transcript.created` in 0.5s, 28 `transcript.partial`, a
    `transcript.done` after `audio.done`, the server closing the socket 2.00s and 2.01s later, no `error`
    and no transport failure. `swift test --disable-xctest` exited 0 with all 27 tests passing
    and the live test taking 28.1s and 28.2s.
  - The first session recorded the full sequence and exposed the defect described under
    Specification drift: `STTEvent.Word` expected a `word` key where the endpoint sends `text`,
    so every frame carrying word timings failed to decode. Those are exactly the `is_final` and
    `speech_final` frames, so 8 of 28 partials were discarded and the assembled transcript was
    the last passage only. This is the documented troubleshooting loop: the smallest correction
    was made and the session rerun.
  - The second session, after the fix, decoded all 30 frames, and the assembled text was the
    complete three-passage dictation. It reproduced the first session's frames, order, flags and
    every `is_final` and `speech_final` boundary, but not its interim timings: six arrivals
    differ by more than 0.1s and two frames declare a different `duration`. The Findings section
    says which of its numbers are reproduced and which are one sample, and the endpointing
    figures are in the reproduced half.
  - Cost: two 25s streaming sessions, about a third of a cent in total.
- Resume condition: satisfied. The sequence is recorded in Findings and the contradictions are
  noted there. Escalations E1 and E2 are discharged and removed from [plan.md](plan.md), with
  their lasting decisions copied into its decision and drift log and into the handoff below.

## Findings

Written from two live sessions on 2026-09-22 against `wss://api.x.ai/v1/stt` with the
specification's query parameters, streaming the 25s fixture in real time as 100ms binary frames
and then sending `{"type":"finalize"}` followed by `{"type":"audio.done"}`. The second session
followed the one production fix this workstream made; see Specification drift in the handoff.

What the numbers below are worth. The recorded sequence table is run 2: **one recorded sample**,
whose load-bearing parts were confirmed by run 1. Reproducible across the two runs: the 30 server
frames, their order, their event types, all nine `is_final` frames and all three `speech_final`
frames with their flags and their declared `start + duration` boundaries, and the two
`speech_final` frames the endpointing analysis rests on, which arrived within 0.04s of the other
run. One sample only: the arrival of every interim partial, including the three resume-lag rows
of the endpointing table, which run 1 puts at 11.61s and 21.64s against run 2's 11.66s and
21.88s; the exact
arrival times of the interim partials, which differ by more than 0.1s on six frames and by 0.81s
on one; the `duration` of two frames, where run 1 declared `1.620-2.900` and `16.740-17.000`
against run 2's `1.620-1.900` and `16.740-16.800`; and the interim text, which differed by one
character on one frame. So treat the endpointing and flag findings as reproduced, and the interim
cadence as indicative.

Transcript text is elided throughout, as the lead decided. Character counts and word counts
stand in for it where the size of a payload is the evidence.

### The fixture, stated first

The fixture is a public-corpus voice, not Aidan's, and its pauses are digital silence rather
than room tone. Measured off the file: the two inserted silences are exact zero samples over
`6.000-9.500s` and `15.500-19.000s`, and the file peak is 8908.

The two pauses are acoustically different, which is what makes them worth comparing.

- Pause 1 is a hard cut. The last non-zero sample is at `5.99994s` with amplitude -2101, and the
  10ms window ending there has an RMS of 1243-1386 depending on where the window is placed.
  Passage 1 is cut to digital zero at speaking volume; it does not trail off.
- Pause 2 has a quiet tail. Speech energy stops at about `14.08s`, and from there to the digital
  silence at `15.500s` the RMS sits between about 5 and 14, roughly 56 to 65 dB below peak. That
  is 1.4s of audio that is very quiet but is not digital silence.

Where a number below could be a property of this fixture rather than of the protocol, it is
named.

### Recorded sequence

Columns are wall clock since connect, audio handed to the socket by then, and the frame.
`sf` is `speech_final`, `fin` is `is_final`, and the segment column is the frame's `start` and
`start + duration`.

| wall | audio | frame | fin | sf | segment | words | text |
|---|---|---|---|---|---|---|---|
| 0.52 | 0.00 | `transcript.created` | - | - | - | - | carries `id` only |
| 1.69 | 1.20 | `transcript.partial` | false | false | 0.001-0.900 | 0 | 19 chars, passage 1 opening |
| 2.56 | 2.10 | `transcript.partial` | **true** | false | 0.001-1.620 | 3 | 18 chars, rewritten and number-normalised |
| 2.80 | 2.30 | `transcript.partial` | false | false | 1.620-1.900 | 0 | 10 chars |
| 4.86 | 4.40 | `transcript.partial` | false | false | 1.620-3.900 | 0 | 20 chars |
| 5.08 | 4.60 | `transcript.partial` | **true** | false | 0.001-4.160 | 4 | 15 chars, normalised again |
| 6.68 | 6.20 | `transcript.partial` | false | false | 4.160-5.900 | 0 | 10 chars |
| 7.48 | 7.00 | `transcript.partial` | **true** | false | 0.001-6.700 | 2 | 13 chars |
| | | *pause 1: nothing for 1.98s* | | | | | |
| 9.46 | 9.00 | `transcript.partial` | **true** | **true** | 0.001-8.900 | 9 | 48 chars, the whole of passage 1 |
| 9.52 | 9.00 | `transcript.partial` | false | false | 8.900-8.900 | 0 | empty, no `language` key |
| 10.53 | 10.00 | `transcript.partial` | false | false | 8.900-9.900 | 0 | empty |
| 11.66 | 11.20 | `transcript.partial` | false | false | 10.080-10.900 | 0 | 6 chars, passage 2 opens |
| 12.68 | 12.20 | `transcript.partial` | false | false | 10.080-11.900 | 0 | 21 chars |
| 13.69 | 13.20 | `transcript.partial` | false | false | 10.080-12.900 | 0 | 28 chars |
| 14.71 | 14.20 | `transcript.partial` | false | false | 10.080-13.900 | 0 | 47 chars |
| | | *pause 2: nothing for 2.88s* | | | | | |
| 17.59 | 17.10 | `transcript.partial` | **true** | false | 10.080-16.740 | 8 | 47 chars, the whole of passage 2 |
| 17.59 | 17.10 | `transcript.partial` | **true** | **true** | 10.080-16.740 | 8 | byte-identical to the frame above but for `speech_final` |
| 17.59 | 17.10 | `transcript.partial` | false | false | 16.740-16.800 | 0 | empty |
| 18.53 | 18.00 | `transcript.partial` | false | false | 16.740-17.900 | 0 | empty |
| 19.52 | 19.00 | `transcript.partial` | false | false | 16.740-18.900 | 0 | empty |
| 19.52 | 19.00 | `transcript.partial` | **true** | false | 16.740-18.900 | 0 | empty, and `is_final` on empty text |
| 20.52 | 20.00 | `transcript.partial` | false | false | 16.740-19.900 | 0 | empty |
| 21.88 | 21.40 | `transcript.partial` | false | false | 19.460-20.900 | 0 | 14 chars, passage 3 opens |
| 22.80 | 22.30 | `transcript.partial` | false | false | 19.460-21.900 | 0 | 24 chars |
| 23.72 | 23.20 | `transcript.partial` | false | false | 19.460-22.900 | 0 | 31 chars |
| 24.76 | 24.30 | `transcript.partial` | false | false | 19.460-23.900 | 0 | 44 chars |
| 25.55 | 25.00 | *client sends `finalize` then `audio.done`* | | | | | |
| 25.73 | 25.00 | `transcript.partial` | false | false | 19.460-24.900 | 0 | 63 chars |
| 25.97 | 25.00 | `transcript.partial` | **true** | false | 19.460-25.000 | 12 | 63 chars, the whole of passage 3 |
| 25.97 | 25.00 | `transcript.partial` | **true** | **true** | 19.460-25.000 | 12 | identical but for `speech_final` |
| 25.97 | 25.00 | `transcript.done` | - | - | `duration` 25.0 | 0 | **empty** |
| 27.98 | 25.00 | *server closed the socket* | | | | | |

Totals: 1 `transcript.created`, 28 `transcript.partial`, 1 `transcript.done`, no `error`, no
non-JSON frame, no frame the event types could not read once the fix below was in. Three
`speech_final` segments, one per passage, and concatenating their three texts in order
reproduces the whole dictation exactly. Run 1 produced the same 30 frames in the same order.

### Partial cadence

`transcript.partial` runs at roughly 1 Hz while there is speech to report. The gaps between
consecutive text-bearing partials in passage 3 were 0.92s, 0.92s and 1.04s; in passage 2, 1.02s,
1.01s and 1.02s. The endpoint is not echoing the 100ms send cadence back, so a partial is not a
response to a frame.

The `audio` column is not a latency. It is the position the streaming loop had reached when the
frame arrived, so `wall - audio` is the harness's own pacing offset, a constant `~0.47s` in run 2
and `~0.42s` in run 1, being how long after connect the loop started, plus up to one 100ms chunk
of rounding. Workstream 4 should not budget it as endpoint latency. The real lag, from the audio
a frame describes being handed to the socket to the frame arriving, is roughly 0.3s to 0.5s with
a mean near 0.38s across the text-bearing partials. The offset is still used below as a
wall-clock conversion, which is the one thing it is good for.

Three deviations matter for a session machine:

- **Silence does not stop partials.** Once an utterance has been closed by `speech_final`, the
  endpoint keeps emitting `transcript.partial` at the same ~1 Hz with `"text":""`, `words` empty
  and `start` pinned to the boundary while `duration` counts up. Five such frames arrived across
  pause 2. Arrival of a partial therefore says nothing about whether anyone is speaking.
- **The endpointing window is silent.** Between the last text partial of a passage and the
  `speech_final` that closes it, nothing arrives at all: 1.98s of dead air before pause 1's
  `speech_final` and 2.88s before pause 2's. The endpoint goes quiet while it decides, then
  emits a burst.
- **Endpoints arrive as bursts with near-identical timestamps.** At pause 2, three frames landed
  within 10ms of each other, which is as tight as the harness's two-decimal wall clock can
  resolve: an `is_final` frame, a byte-identical frame with `speech_final` also true, and an
  empty partial opening the next segment. At `finalize` the same first two frames arrived
  together, but the third frame of that burst was `transcript.done`, and no empty partial
  followed the final burst at all. Pause 1 sent only the combined `is_final` + `speech_final`
  frame with no twin. A consumer must tolerate all three shapes and must not treat the duplicate
  pair as two segments.

### `is_final` versus `speech_final`

`speech_final` always implied `is_final` in both sessions, and the reverse never held. Nine
frames carried `is_final`, three of them with `speech_final` as well. The two flags mean
different things.

- `is_final` alone marks a stabilised run of words inside an utterance. Those frames are the
  only ones that ever carry a populated `words` array, and they are where the text is rewritten
  into its final form. Within passage 1 the interim spelled a date and a time out in words and
  the `is_final` frame replaced both with numerals. Passage 1 produced three such frames and
  passage 2 produced one. A frame with `is_final` true and empty text also arrived in the middle
  of pause 2, so `is_final` does not imply content.
- `speech_final` marks the end of an utterance, and its frame carries the full text of that
  utterance rather than the run since the last `is_final`. Passage 1's `speech_final` frame carried all
  48 characters and all 9 words of the passage, although the three `is_final` frames before it
  had carried 18, 15 and 13 characters covering successive runs.

That difference is the trap. The `is_final` texts are not fragments to concatenate with the
`speech_final` text, because the `speech_final` frame resends the whole utterance. Committing on
`speech_final` only, which is what `TranscriptAssembler` does and what the specification says,
produced the exact dictation. Any scheme that also committed `is_final` runs would duplicate
every word.

**Interim text resets inside an utterance, not only at `is_final`.** The non-final partials reset
too, and this is what the dimmed overlay line will actually show. Passage 1's partial texts run
19 chars, 18 (`is_final`), 10, 20, 15 (`is_final`), 10, 13 (`is_final`), and only the
`speech_final` frame at 9.46s carries all 48. `TranscriptAssembler.applyPartial` assigns
`interim = segment` on every non-`speech_final` partial, so the dimmed line drops back to the
current run twice inside passage 1 and recovers the passage only at `speech_final`: words
stabilised at 2.56s vanish from the interim at 2.80s and do not reappear until 9.46s, 6.9s later.
Words already correctly transcribed visibly disappear and come back. Nothing in v1's committed
text is affected and `TranscriptAssembler` is correct as it stands, but workstream 4 owns what
the overlay is handed and could not predict this from the flag semantics alone.

`start` and `duration` on an `is_final` frame cannot be used to locate its text. Within passage
1 all three `is_final` frames reported `start` 0.001, the start of the whole session, while
their texts covered successive runs beginning at 1.62 and 4.16. `start` on a **non**-final
partial does track the run being reported *within a passage*, moving to the previous `is_final`
boundary each time, but not across a pause: after pause 1 closed at 8.900 the empty partials
reported `start` 8.9, while the first text partial of passage 2 reported `start` 10.080, the
speech onset rather than the boundary. The same happens at 19.460 after pause 2. Workstream 4
should read `text` and the two flags and ignore `start` and `duration` when assembling.

Word timings are absolute `start` and `end` in seconds, mostly plausible but not trustworthy at
the edges. In passage 1 the second `is_final` frame reported a word starting at 0.241 whose audio
starts at about 1.5s. Nothing in v1 depends on word timings.

### Endpointing across the two inserted pauses

This is the risk the workstream existed to retire, and `endpointing=2000` behaved. Both pauses
produced exactly one `speech_final`, both fired comfortably inside the 3.5s of silence, and no
`speech_final` ever fired inside a passage. Every row down to the last `speech_final` row was
confirmed by run 1 to within 0.04s. The three resume-lag rows at the foot of the table were not:
run 1's first text-bearing partials arrived at 11.61s and 21.64s, which moves pause 2's lag by
0.24s, and run 1 had handed over 17.20s of audio when pause 2's frame arrived rather than 17.10s,
leaving 1.80s of silence. Read those four figures as one sample and the rest as reproduced.

| | pause 1 | pause 2 |
|---|---|---|
| Speech energy ends (audio timeline) | 6.000s, a hard cut | 14.08s, then a quiet tail |
| Inserted digital silence | 6.000-9.500s | 15.500-19.000s |
| Last word `end` the endpoint reported | 6.097s | 14.012s |
| Boundary the `speech_final` frame declared (`start + duration`) | **8.900s** | **16.740s** |
| Boundary minus the endpoint's own last word `end` | **2.803s** | **2.728s** |
| Boundary minus end of speech in the fixture | 2.90s | 2.66s |
| Audio handed over when the frame arrived | 9.00s | 17.10s |
| Wall clock when the frame arrived | 9.46s | 17.59s |
| Wall clock when that audio had been handed over | ~6.47s | ~14.54s |
| End of speech to frame in hand, wall clock | **2.99s** | **3.05s** |
| Silence remaining when the frame arrived | 0.50s | 1.90s |
| Speech resumes after the pause (audio timeline) | ~10.4-10.5s | ~19.1-19.7s |
| First text-bearing partial after the pause | 11.66s | 21.88s |
| Lag behind resumed speech, wall clock | ~0.7-0.8s | ~1.7-2.3s |

So `endpointing=2000` is a floor, not the latency.

**The figure to budget against is 2.73-2.80s**, the gap between the endpoint's own last reported
word `end` and the boundary it then declares: `8.900 - 6.097 = 2.803s` and
`16.740 - 14.012 = 2.728s`. Both come straight out of the logs with no fixture analysis, they
agree to 75ms across two acoustically different pauses, and they are the endpoint's own account
of its own latency.

The external check, measured off the fixture rather than the endpoint's own timeline, is
2.66-2.90s from where speech energy stops to the declared boundary, about 660-900ms more than
the 2000ms asked for. That is a 240ms spread, wider than the endpoint's own account, because the
"end of speech" it is measured from is a judgement about audio rather than a reported number.

Measured from the last speech to the `speech_final` frame being readable by the client, the two
pauses gave 2.99s and 3.05s, both within 50ms of 3.0s. Workstream 4 should budget about 3s of
wall clock from the end of speech to the `speech_final` at `endpointing=2000`, and should not
expect a boundary at 2.0s.

Two readings of the reference point, and why the endpoint's own voice activity detection is the
answer. Measured from the start of the inserted *digital silence*, the same two frames give
`8.900 - 6.000 = 2.90s` and `16.740 - 15.500 = 1.24s`. Pause 1 discriminates between the two
readings not at all, because its speech is cut to digital zero at volume, so both references are
the same instant. The argument rests on pause 2 alone, and pause 2 carries it: 1.24s is below the
configured 2000ms and therefore impossible, so the endpoint must have counted the quiet tail from
14.08s as silence. Detection keys off its own voice activity detection, not off digital zeros,
which is the answer that generalises to a microphone.

**How late "speech resumed" is.** This matters because the recommended replacement for the
specification's silence signal, below, is the last partial with non-empty text. Speech resumes in
the fixture at about `10.4-10.5s` and `19.1-19.7s` on the audio timeline; the ranges are wide
because the onset is threshold-sensitive, both passages opening on a low-energy consonant, and a
precise figure would be false. The harness had handed that audio to the socket about 0.47s after
its timeline position. The first text-bearing partial of each passage arrived at wall `11.66s`
and `21.88s` in run 2, and `11.61s` and `21.64s` in run 1, so the signal lagged resumed speech by
about 0.7-0.8s after pause 1 and by 1.7-2.3s after pause 2. The spread is the point: an overlay
that un-pauses on the first non-empty partial can sit in its paused state for around two seconds
after the user has started speaking again, a fifth of the specification's ten second pause
threshold.

Two fixture caveats on this section. Digital silence is the easiest case a voice activity
detector will ever get, so treat the observed window as the shortest it gets. A room floor, a fan
or a keyboard may push the boundary later, and the ten second paused-overlay threshold has plenty
of room either way. The fixture also says nothing about the space between 1s and 2.7s of silence,
since the longest gap inside a passage is about 0.9s. The session shows that `endpointing=2000`
does not chop at sub-second thinking pauses, and does not show where between 1s and 2.7s it
starts to.

What the pause did not do matters just as much. The socket stayed open across both pauses, no
`transcript.done` arrived, no `error` arrived, the session continued straight into the next
passage, and the segment after each pause opened at the declared boundary. Going quiet pauses
the session exactly as the specification assumes.

### What `transcript.done` returns

Nothing. The frame is `{"type":"transcript.done","text":"","words":[],"duration":25.0}`. The
text is empty, `words` is empty, and `duration` is the total audio streamed. It repeats nothing
and it returns no remainder.

The remainder arrives before it, not in it. `finalize` and `audio.done` went out at 25.55s; at
25.73s a plain interim partial carried the full 63 characters of passage 3; at 25.97s the
`is_final` frame and then the `speech_final` frame for that passage arrived, and `transcript.done`
arrived within 10ms behind them. So `finalize` resolved the trailing partial into a real
`speech_final` segment rather than leaving it interim, and by the time `done` lands the
transcript is already complete. `transcript.done` is a terminator and a total, nothing more.
That is what the specification describes, "plus whatever trailing partial the `finalize`
resolves into", so nothing here contradicts it.

One thing for workstream 4. `TranscriptAssembler`'s fallback of committing `interim` at `done`
never fired in either session, and it is worth keeping, since it costs nothing and covers a
`finalize` that resolves with `is_final` alone. But it is a fallback rather than the normal path,
and a risky one: `interim` holds only the run since the last `is_final`, not the whole utterance,
so if that path ever did fire mid-utterance it would commit a fragment.

Ordering held: `transcript.done` never arrived before the client sent `audio.done`, in either
session.

### Undocumented behaviour

Everything the specification describes was observed. These were observed in addition.

- `transcript.created` carries an `id`, a UUID. The specification describes it as a bare ready
  signal. Nothing required the id later, and it was never echoed back.
- `transcript.partial` carries three fields the specification does not list: `start` and
  `duration`, floats on the audio timeline, and `language`, a string. `language` is present only
  on frames with non-empty text; the empty partials emitted during silence omit the key
  entirely.
- `transcript.done` carries `text`, `words` and `duration`, all of which the specification omits.
  All three were empty or a total here.
- A word object is `{"text": ..., "start": ..., "end": ...}`. The key is `text`, not `word`, and
  no `confidence` was ever sent. This is the defect described under drift. Workstream 4 must not
  expect `confidence` to be populated.
- `words` arrives only on `is_final` frames. Every non-final partial sent `"words":[]`, including
  ones carrying 44 characters of text.
- Empty-text `transcript.partial` frames during silence are not described anywhere. They are the
  endpoint's heartbeat, and they contradict the specification's silence detection. See below.
- `is_final` can be true on a frame with empty text and no words, as at 19.52s inside pause 2.
- The endpoint can emit two frames identical but for `speech_final` within 10ms of each other.
- The server closed the socket 2.00s after `transcript.done` in run 1 and 2.01s in run 2, rather
  than immediately. The harness kept listening for three seconds past `done` and nothing else
  arrived in the gap. A client that tears down the socket the instant `done` lands loses nothing,
  but one that waits for a close should allow at least 2.5s.
- No keepalive, ping or other frame type was seen in 28s. No frame in either session was
  anything other than JSON with one of the three documented `type` values.

### `endpointing=2000` does not mean a 2000ms boundary

A clarification rather than a contradiction: the specification's "Connection parameters" section
says only that `endpointing` "is set high deliberately" and that "the default 400ms would chop a
prompt into fragments", and nowhere claims a 2000ms boundary. Nothing in it is falsified.

But the observed number is load-bearing for workstream 4 and the specification does not carry it.
Observed, the boundary lands 2.73-2.80s after the endpoint's own last reported word and the frame
is in hand at about 3.0s of wall clock. Nothing in v1 breaks, because utterance boundaries are
the hotkey's job and the overlay pauses at ten seconds. But any timing written against 2000ms,
particularly anything that decides whether the last sentence made it before the user pressed the
hotkey, must use the observed 3s. Worth writing into the specification.

### Contradiction with the specification

One, and it is load-bearing.

**Silence detection cannot key off the arrival of partials.**
[The specification](../../specs/echotype-v1.md), lines 85-87, says of the paused overlay: "The
server's own voice activity detection is already the signal: no new partials means silence, new
partials mean speech resumed". That is false as written. Partials keep arriving at ~1 Hz
throughout a silence, carrying `"text":""`. Five arrived across pause 2 and two across pause 1,
in both runs. The signal is still there, but it is a partial with non-empty text, not a partial.

It inverts the other way too. While the endpoint was deciding where to end each utterance, 1.98s
before pause 1 and 2.88s before pause 2, no frames arrived at all, so a detector watching for
"nothing for N seconds" sees activity during silence and silence during speech.

The fix is small: a paused state driven by the last partial with non-empty text, or by the last
`speech_final`. Workstream 4 should know what that mechanism costs in latency. Entering the
paused state lags the real end of speech by about 3s of wall clock, and leaving it lags resumed
speech by 0.7s to 2.3s, both measured above. Against a ten second threshold that is comfortable,
but it is not free, and the un-pause lag is the one a user can see.

The specification's sentence still has to change, and so does its restatement in the session
machine section, where lines 382-385 say the `listening` and `paused` transition is "driven by
whether transcript events are still arriving, with ten seconds of quiet moving to `paused` and
any new partial moving back". Same assumption, same correction: the trigger is a partial with
non-empty text. This is wording rather than code, since nothing in workstream 2 depends on it,
and it lands in workstream 4 or 5. Aidan should decide which.

Nothing else in the specification's Transcription section was contradicted. No event type
outside the documented four was sent, and three of the four appeared, `error` being the one a
healthy session never produces. The client messages are accepted as documented, `finalize` then
`audio.done` in that order works, `transcript.done` follows `audio.done`, configuration is
entirely query parameters with no setup message, `interim_results=true` produces interim text,
and `format=true` is doing the number normalisation described above.

## Implementation handoff

- Base commit: `56b18ea`
- Outcome: the harness is built and remediated, and every part of it that can run without a
  socket is verified. The live half was not run: gate G1 is unmet, and this machine turns
  out to have a second blocker described under limitations. The Findings section is
  deliberately left `TBD` for whoever runs the live session.
- Files changed:
  - `Tests/EchoTypeCoreTests/Integration/LiveProtocolTests.swift`, new: the skipped
    integration test, the session log and the report it prints.
  - `Tests/EchoTypeCoreTests/Integration/WAVRecording.swift`, new: a minimal 16-bit PCM
    RIFF reader that feeds the recording to `AudioConverter`.
  - `.gitignore`: ignores `*.wav` and `Tests/Fixtures/`, so a recording dropped in the
    working tree cannot be committed.
  - No production code changed, and no fixture directory is committed, since the
    recording lives outside the repository.
- Decisions:
  - The recording is located by `ECHOTYPE_FIXTURE_WAV`, an absolute path to a WAV
    outside the repository. The test is enabled only when both `XAI_API_KEY` and
    `ECHOTYPE_FIXTURE_WAV` are set, through `@Test(.enabled(if:))`, so an unconfigured
    run reports the test as skipped with a message naming exactly what to supply. One
    command then runs the whole session, teeing the report to a path outside the
    repository so a long log survives scrollback:
    `XAI_API_KEY=... ECHOTYPE_FIXTURE_WAV=/path/to/dictation.wav swift test --disable-xctest 2>&1 | tee ~/echotype-live-session.log`
  - The recorded sequence goes to standard output, not to a file in the tree, so the
    evidence is visible in the run that produced it and nothing can be committed by
    accident. Each line carries wall-clock time since connect and how much audio had been
    handed over when the frame arrived, which is what makes partial cadence and the
    endpointing window readable. The report prints before the expectations, so a failed
    session still explains itself.
  - The test drives `URLSessionWebSocketTransport` directly rather than through
    `STTClient`. `STTClient` silently ignores an unrecognised event `type` and returns
    at `transcript.done`, which would hide two of the questions the session exists to
    answer. Raw frames are logged verbatim, with an annotation separating a frame that is
    not JSON at all, a JSON frame the event types cannot decode, and JSON whose `type` is
    not one of the four documented events. A `TranscriptAssembler` runs alongside the log,
    so the report also shows what workstream 2 would assemble from the real stream.
  - The receive loop runs until the socket genuinely closes, never stopping at the first
    `transcript.done`, and the session waits a three second grace after `done` for the
    endpoint to close. Anything the endpoint sends after `done` is therefore evidence
    rather than something teardown swallowed, and the log claims the server closed the
    stream only when it did. A `done` that arrives before the client sent `audio.done`
    is flagged in the report and fails its own expectation, so an endpoint that ends the
    session early cannot pass on a truncated log.
  - A missing `transcript.created` no longer ends the run. The wait expiring is recorded
    and the recording is streamed anyway, through `finalize` and `audio.done`, because
    that is what separates an endpoint waiting for audio before it says anything from an
    endpoint that is simply silent. An `error` event, by contrast, settles the wait
    immediately and ends the session without sending audio, and it appears in the
    failure summary alongside any transport failure.
  - The report and the session state are read before the receiving task is cancelled and
    the socket closed, so the harness's own teardown can never be recorded or reported as
    an endpoint failure.
  - Audio is paced in real time, one roughly 100ms chunk per 100ms against a fixed
    schedule rather than a sleep per chunk. A recorded pause only reaches the endpoint
    as a pause if it is not delivered inside a burst, and `endpointing=2000` is the
    thing being observed.
  - Assertions are limited to what the specification actually claims: a
    `transcript.created`, at least one `transcript.partial`, a `transcript.done` that did
    not precede `audio.done`, and non-empty assembled text. Anything finer would be
    asserting the documentation this workstream exists to check. Waits are bounded (15s
    for `transcript.created`, 20s for `transcript.done`, 3s for the close) so a silent
    endpoint fails with the log rather than hanging.
  - The WAV reader accepts 16-bit PCM at any rate and channel count, including
    `WAVE_FORMAT_EXTENSIBLE`, which recorders write for ordinary PCM as soon as a file is
    multichannel or high resolution. Anything else is rejected with a message naming what
    is actually wrong. Writing 90 lines of RIFF was cheaper than the alternatives, since
    Foundation has no audio decoder and the package may not import `AVFoundation`.
  - `*.wav` stays in `.gitignore` rather than a narrower pattern. No recording in this
    project is meant to be committed, and criterion 3 is a hard acceptance criterion.
  - Lead decisions carried in from remediation: the harness stays in this package and
    this test target, since it is Foundation-only and builds on macOS unchanged; and when
    the Findings section is written it may quote event types, flags, ordering, timings and
    counts, but not the verbatim text of Aidan's speech, which is elided.
- Verification:
  - `swift test --disable-xctest` with `XAI_API_KEY` and `ECHOTYPE_FIXTURE_WAV` unset:
    exit 0, 27 tests, the live test reported as
    `skipped: "Set XAI_API_KEY to an xAI key and ECHOTYPE_FIXTURE_WAV to the path of a
    16-bit PCM WAV..."`. Also exit 0 with only `XAI_API_KEY` set, so a key alone never
    turns the test into a failure.
  - `swift-format lint --recursive Sources Tests`: clean.
  - The live path was exercised as far as a machine without a key can take it. Against a
    synthetic WAV and a scripted in-process transport, five sessions were driven through
    the real session code: a normal session, a `done` before `audio.done`, an endpoint
    that says nothing for 15 seconds, an `error` frame, and a `WAVE_FORMAT_EXTENSIBLE`
    recording. They confirmed 20 binary frames of 3200 bytes each, which is exactly 100ms
    of 16 kHz mono Int16 per frame, then `{"type":"finalize"}` and `{"type":"audio.done"}`
    in that order; pacing held to the audio timeline; frames arriving after `done`
    recorded, with the three annotations distinguished; the close logged only when the
    stream actually ended; the early `done` flagged; the silent endpoint streamed to
    anyway; and the `error` frame ending the session in 0.14s with no audio sent and the
    code in the failure summary. That scaffolding was temporary and is not committed.
  - `URLSessionWebSocketTransport` itself was exercised against both a local WebSocket
    server and `wss://api.x.ai/v1/stt` with a placeholder key. Both fail identically, for
    the reason below.
- Known limitations or external checks:
  - `URLSessionWebSocketTask` does not work on this machine. Every connection attempt
    fails immediately with `NSURLErrorDomain Code=-1002, "WebSockets not supported by
    libcurl"`. The system libcurl is 8.5.0 and its protocol list contains no `ws` or
    `wss`, so swift-corelibs-foundation has nothing to open a socket with. This is not a
    key problem and a key will not fix it. The README's claim that
    `URLSessionWebSocketTask` was verified on this machine does not hold. Two ways out,
    given the lead's decision that the harness stays in this package: install a libcurl
    built with WebSocket support, which needs the `sudo` password this machine does not
    have, or run this one test on Aidan's Mac, where `URLSessionWebSocketTask` is native
    and the package builds unchanged because it imports Foundation only.
    Resolved on 2026-09-22 by the first route: a WebSocket-capable libcurl now lives in
    `~/.local/curl-ws`, and prefixing the run with `LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib`
    opens real sockets from this machine, verified against `api.x.ai`. The live session is no
    longer Mac-only. What blocks it now is the key, not the transport.
  - Every Findings entry is still `TBD`, so acceptance criteria 1 and 4 are unmet. The
    harness is the deliverable that was achievable without the key and the recording.
  - Endpointing may key off the audio timeline rather than wall clock, in which case the
    real-time pacing is belt and braces rather than a requirement. Cheap either way, and
    the report records both clocks so the live run can tell them apart.
- Specification drift: none. Nothing about the live protocol was observed, so nothing
  could contradict the specification. The libcurl limitation above contradicts the
  workflow README rather than the specification, so it is recorded here rather than in
  the drift log.

### Live run, 2026-09-22

Appended after the live sessions recorded in Attempt 3. The entries above describe the harness
as built, before it had ever reached a working endpoint; these are the only things the live run
changed. Where they disagree with the entries above, they supersede them: the Findings section
is no longer `TBD`, acceptance criteria 1 and 4 are met, and the drift line is no longer `none`.

- Findings written from observation. Every `TBD` is replaced, and the recorded sequence is in
  the table there, condensed enough for workstream 4 to build a session machine from without
  the raw log. The log itself stayed at `~/echotype-live-session.log`, outside the repository.
- One production file changed, `Sources/EchoTypeCore/STT/STTEvent.swift`. `STTEvent.Word` is now
  `text`, `start`, `end`, `confidence` rather than `word`, `start`, `end`, `confidence`. Nothing
  else was touched, in this file or anywhere in `Sources`.
- The harness itself is unchanged. It behaved as designed on the first live contact: it recorded
  the frames it could not decode with the right annotation, which is how the defect was found at
  all, and it kept reading past `transcript.done` until the server closed the socket, which is
  how the 2.01s close delay was measured.
- Specification drift, superseding the line above:
  - **Defect in workstream 2's event types, fixed.** The endpoint spells a word object's word
    `text`, not `word`. `Word` required `word`, so `STTEvent.decode` threw on every frame with a
    populated `words` array. Because the endpoint sends `words` only on `is_final` frames, and
    every `speech_final` frame is an `is_final` frame, the failure discarded precisely the frames
    the transcript is assembled from: 8 of 28 partials in session one, leaving the assembled text
    as the last passage alone. This is the sole change to production code this workstream made,
    it is the kind of defect the packet's Initial ownership allows fixing, and it is named here
    as required. Verified by the rerun: 0 rejected frames and the complete transcript.
  - **One specification contradiction, recorded not fixed**, per the packet's non-goals: the
    silence-detection sentence in "Silence, pausing and the hard cap". Partials keep arriving at
    ~1 Hz with empty text throughout a silence, so "no new partials means silence" is false and
    the paused overlay needs a different signal, which Findings names along with how far behind
    resumed speech that signal lags. Two further observations were drafted as contradictions and
    reclassified at triage, because the specification does not in fact claim either: that
    `endpointing=2000` yields a boundary at 2.66-2.90s and a frame in hand at about 3.0s, and
    that `transcript.done` is empty rather than carrying the tail. Both are in Findings with the
    evidence and both are worth writing into the specification.
- Decisions carried in from escalations E1 and E2, which are now removed from `plan.md` and whose
  lasting parts are in its decision and drift log:
  - The live session runs on this machine rather than the Mac. Ubuntu 24.04's only libcurl is
    built without websockets, so any command that opens a real socket is prefixed with
    `LD_LIBRARY_PATH=$HOME/.local/curl-ws/lib`, pointing at a source build of curl 8.11.1 with
    `--enable-websockets`. Verified against `echo.websocket.org` and `api.x.ai`. The loader's
    `no version information available` warning is benign.
  - The key lives in `~/secrets/secrets.env` as `XAI_API_KEY` and is read or sourced from there,
    never exported into a transcript, printed, logged or committed. The first two keys Aidan
    supplied were rejected by xAI with `HTTP 400 Incorrect API key provided.`; the third returns
    `200` from `GET /v1/api-key` and is what these sessions ran on.
  - The recording lives at `~/echotype-fixtures/sample-with-pauses.wav`, outside the repository,
    and reaches the harness through `ECHOTYPE_FIXTURE_WAV`.
  - The fixture is public-corpus speech rather than Aidan's voice, and its pauses are digital
    silence rather than room tone. The Findings section names that wherever a number could be a
    property of the fixture instead of the protocol.
  - Closing this workstream as not run, with workstream 4 proceeding on documented
    `speech_final` semantics, was explicitly rejected by Aidan.
- Verification after the change: `swift test --disable-xctest` with `XAI_API_KEY` and
  `ECHOTYPE_FIXTURE_WAV` unset exits 0 with 27 tests and the live test skipped with the message
  naming both variables, so criterion 2 still holds. `swift-format lint --recursive Sources
  Tests` is clean. No key, recording, transcript or session log is in the working tree: the only
  changed or untracked paths are `.gitignore`, `Sources/EchoTypeCore/STT/STTEvent.swift`, this
  document, `plan.md` and `Tests/EchoTypeCoreTests/Integration/`, and the one key-shaped string
  in the tree is the `xai-123` placeholder that `STTConnectionTests` has always asserted on.
  Criterion 3 still holds.

## Independent review

- Reviewer: independent review agent, uncommitted diff at base `56b18ea`.
- Verdict: changes required. Two Required findings, both in the live path, both of a kind
  that only shows up in the paid session this harness exists to run. Everything that can be
  checked without a socket checks out: `swift test --disable-xctest` exits 0 with 27 tests
  and the live test skipped with the message naming both variables, and it still exits 0
  with `XAI_API_KEY` alone or `ECHOTYPE_FIXTURE_WAV` alone, so a half-configured run never
  becomes a failure. `swift-format lint --recursive Sources Tests` is clean. No key,
  recording or transcript is committed or committable: nothing is written to disk, the
  connection URL carries no secret (the key is a header), and `git check-ignore` confirms
  both new patterns bite. Criterion 2 and criterion 3 are met. Criteria 1 and 4 are unmet
  for the reason the handoff gives, which is the G1 block and not a finding here. The
  assertions are proportionate and behavioural: four claims the specification actually
  makes, and nothing asserting the documentation this session exists to check.

### Required findings

1. **The receive loop stops at the first `transcript.done`, so an early `done` produces a
   truncated log and a passing test.** `LiveProtocolTests.swift:56` breaks out of the
   message loop as soon as `SessionLog.record` returns true, which it does on `sawDone`
   (`:180`). Failure scenario: the endpoint sends `transcript.done` mid-stream, before
   `audio.done`, which is exactly the specification contradiction this workstream exists to
   catch (`docs/specs/echotype-v1.md:256` claims `transcript.done` follows `audio.done`).
   The loop breaks at that point, the audio loop keeps pacing the remaining chunks into a
   socket nobody is reading, `finalize` and `audio.done` go out unobserved, the wait at
   `:110` returns immediately, and all four expectations pass. The recorded evidence stops
   partway through the recording and the report says the session behaved as documented. Two
   further consequences of the same `break`: nothing arriving after `transcript.done` is
   ever recorded, which is one of the five Scope questions and the one a reader cannot
   recover from any other source, since `STTClient.run` returns at `done` too; and
   `:58` then logs `-- the server closed the stream` when the client stopped reading and the
   server did nothing of the sort, which puts a false statement in the artefact. Suggested
   shape: record `sawDone` but keep consuming until the stream ends or a short grace period
   after `done` expires, and note the close only when the stream genuinely finishes.

2. **A missing `transcript.created` ends the session with no audio sent and no evidence
   recorded.** `LiveProtocolTests.swift:93`: after the 15s wait, `guard await log.sawCreated
   else { return }` returns without sending a single chunk, without `finalize` or
   `audio.done`, and without noting why it gave up. Failure scenario: the endpoint emits
   `transcript.created` only after it receives audio, or names the ready event something
   else, or emits nothing until the first frame. The run then answers none of the five Scope
   questions, and the log holds only whatever arrived in the first 15s. This is the one
   branch where the specification's assumption at `docs/specs/echotype-v1.md:254` is wrong,
   and it is the branch that records least. The specification does say to wait for
   `transcript.created`, so waiting first is right; bailing is the problem. Suggested shape:
   note that the wait expired and stream anyway, so the run distinguishes "the endpoint
   needs audio before it says anything" from "the endpoint is silent". Cheap, and the
   difference decides whether workstream 4 can hold audio behind `created` at all.

### Optional observations

1. **An `error` event neither settles the wait nor ends the session.**
   `LiveProtocolTests.swift:178` logs the frame and falls through to `break`. If an `error`
   arrives first, for instance a rejected parameter, `isSettled` (`:151`) stays false, the
   harness burns the 15s wait, returns without audio, and reports `transcript.created never
   arrived. No stream failure was reported.` while the error frame sits in the log above it.
   If it arrives mid-stream the harness pays the full recording plus the 20s `done` wait.
   The raw frame makes it diagnosable, so this costs time and a misleading headline rather
   than evidence.
2. **Teardown runs before the evidence is read, so a cancellation can be recorded as a
   stream failure.** `:70` cancels the receiving task and `:71` closes the transport, then
   `:75` and `:78` read `report()` and `failureDescription`. On the timeout path the
   cancelled `task.receive()` throws with `closeCode == .invalid`, which
   `URLSessionWebSocketTransport.swift:56` turns into a thrown stream error, so
   `recordFailure` may land a `-- stream failed: CancellationError()` line in the report and
   in every expectation message, attributing the test's own teardown to the endpoint. It is
   a race, so it will be intermittent and confusing. Reading the report and the state before
   cancelling removes it.
3. **`NOT DECODABLE AS JSON` mislabels well-formed frames of an unexpected shape.**
   `STTEvent.Envelope.type` is non-optional (`STTEvent.swift:101`), so any valid JSON without
   a `type` key, a keepalive or a differently shaped error envelope, throws and is annotated
   as undecodable. A reader would conclude the endpoint sent garbage. Distinguishing "not
   JSON" from "JSON without a recognised `type`" is a better answer to the undocumented
   behaviour question.
4. **The `sawDone` expectation message claims ordering nothing checks.** `:81` reads
   `transcript.done never arrived after audio.done`, but `sawDone` records only that a
   `done` arrived. The timestamps and the `sent finalize then audio.done` note make the real
   ordering readable, so this is wording, not logic, though it is the wording the live run
   will be read through.
5. **`WAVE_FORMAT_EXTENSIBLE` is rejected as "not uncompressed PCM".** Verified against
   synthesised files: a 16-bit PCM WAV with format tag `0xFFFE` and the PCM subformat GUID
   is rejected at `WAVRecording.swift:28`, telling Aidan to export as 16-bit PCM WAV when he
   already has. Standard tag-1 files, stereo, 44.1 kHz, a preceding odd-sized `LIST` chunk,
   `data` before `fmt `, an empty `data` chunk and 24-bit rejection all behave correctly.
   This fails before the socket opens, so it costs a re-export rather than a session, but
   the message names the wrong problem. Accepting tag `0xFFFE` when `bits == 16` is two
   lines.
6. **Standard output is the only artefact.** A 30 second recording may produce well over a
   hundred partials, each carrying a `words` array, so the report can run to hundreds of
   kilobytes and outlive terminal scrollback. The evidence is unrecoverable if it scrolls
   away. Worth adding `| tee /tmp/echotype-session.log` to the command in the doc comment at
   `:12`, keeping the file outside the repository so criterion 3 still holds.
7. **`*.wav` is broader than the requirement.** The recording lives outside the repository
   and `Tests/Fixtures/` already covers a stray drop. A repository-wide `*.wav` will also
   silently swallow a fixture a later workstream means to commit, and the macOS spike branch
   merges into this one.

### Questions

1. Criterion 3 forbids a transcript in any committed file; criterion 4 requires every Scope
   question answered from observed evidence. The observed evidence is Aidan's speech. How
   much verbatim frame content may the Findings section carry, and should the answers quote
   timings, flags and event types with the text elided?
2. Given the libcurl blocker, the live run happens on the Mac or not at all. Is the harness
   expected to stay in this package and this test target when it runs there, or does the
   lead want it reduced to a script once the findings exist? This changes whether the two
   Required findings are worth fixing now or only before the session.

## Resolution

### Finding dispositions

Both Required findings accepted. Four of the seven Optional observations accepted, two of
them promoted to Required because they would corrupt or mislead the one paid session this
harness exists to run; one rejected.

| Finding | Disposition | Reason |
|---|---|---|
| Required 1, receive loop stops at the first `transcript.done` | Accepted | An early `done` would have produced a truncated log and a green test, which is precisely the specification contradiction the session exists to catch. The loop now runs until the socket closes, waits a grace period past `done`, flags an early `done` and fails on it, and claims the server closed the stream only when it did. |
| Required 2, a missing `transcript.created` ends the session silently | Accepted | Bailing records least on the one branch where the specification's assumption is wrong. The harness now notes that the wait expired and streams anyway, which separates "the endpoint waits for audio" from "the endpoint is silent". |
| Optional 1, an `error` event neither settles the wait nor ends the session | Promoted to Required | A rejected parameter would have burned the full wait and reported no failure with the error frame sitting in the log above it. |
| Optional 2, teardown recorded as a stream failure | Promoted to Required | An intermittent `CancellationError` attributed to the endpoint is exactly the kind of noise that makes a single live session unreadable. Reading the report and one outcome snapshot before teardown also removed five async reads from the expectations. |
| Optional 3, `NOT DECODABLE AS JSON` mislabels valid JSON | Accepted | Cheap, and it is one of the annotations the undocumented-behaviour question is answered from. Now three distinct labels. |
| Optional 4, `sawDone` message claims ordering nothing checks | Accepted | Wording the live run will be read through. Ordering now has its own expectation. |
| Optional 5, `WAVE_FORMAT_EXTENSIBLE` rejected | Accepted | Two lines, and the old message told Aidan to export what he had already exported. Sample width now decides readability. |
| Optional 6, standard output is the only artefact | Accepted | Doc comment only. The documented command tees to a path outside the repository, so criterion 3 still holds. |
| Optional 7, `*.wav` is broader than the requirement | Rejected | Criterion 3 is a hard acceptance criterion and no recording in this project is ever meant to be committed. A later workstream wanting a committed WAV is hypothetical; the guard is not. |

Lead answers to the reviewer's two questions, which needed no code change:

1. The Findings section may quote event types, flags, ordering, timings and counts, but not
   verbatim transcript text of Aidan's speech. Text is elided. That satisfies criterion 4
   from observed evidence without putting a transcript in a committed file.
2. The harness stays in this package and this test target. It is Foundation-only and builds
   on macOS unchanged, so it runs wherever the live session happens, and the Required
   findings were therefore worth fixing now rather than later.

### Simplification/deletion pass

The remediation replaced five async property reads in the expectations with one `Outcome`
snapshot, which is both the fix for the teardown race and less machinery than before. The
scaffolding used to exercise the live path against a scripted in-process transport was
deleted after each scenario. No production code was changed, so the workstream remains
test-only as the packet intends.

### Final verification

`swift test --disable-xctest` exits 0 with 27 tests and the live test skipped, with the
environment unset and with each variable set alone. `swift-format lint --recursive Sources
Tests` is clean. Rerun by the lead after remediation.

The live half of the targeted verification has not run. See External validation above and
escalation E1 in [plan.md](plan.md).

## Closure review

- Verdict: approved, blocked at G1. Every accepted finding is fixed in the code, not only in
  the prose, and the fixes introduce no release-blocking defect. The workstream cannot close
  because acceptance criteria 1 and 4 need the live session, which is the G1 block recorded
  above rather than a closure finding.
- Remaining required findings: none.

### Accepted findings, verified

| Finding | Verified |
|---|---|
| Required 1, receive loop stops at the first `transcript.done` | Fixed. `record` no longer returns a stop signal and the loop at `LiveProtocolTests.swift:63` runs until `messages()` finishes. `noteStreamEnded("the server closed the stream")` is reachable only from the loop ending normally (`:66`), so the artefact claims a close only when the stream ended. An early `done` sets `doneArrivedEarly` (`:237`), which surfaces in the report header and fails its own expectation (`:95`). Anything arriving after `done` is still recorded, and the three second grace at `:140` gives it time to arrive. |
| Required 2, a missing `transcript.created` ends the session silently | Fixed. `:111` notes that the wait expired and falls through to the streaming loop, so the run distinguishes an endpoint waiting for audio from a silent one. |
| Optional 1 promoted, an `error` event neither settles the wait nor ends the session | Fixed. `serverError` feeds `hasFailed` (`:193`), which feeds both `isSettled` and `isFinished`, so an error settles the wait immediately; `:110` and `:126` end the session before and during streaming; and the error, with its code, heads `failureDescription` (`:285`). |
| Optional 2 promoted, teardown recorded as a stream failure | Fixed twice over. `report()` and `outcome()` are read at `:82` and `:83`, before `receiving.cancel()` and `transport.close()`, and the receive task's catch skips `recordFailure` when the task is cancelled (`:70`). The five async reads in the expectations are now one `Outcome` snapshot. |
| Optional 3, `NOT DECODABLE AS JSON` mislabels valid JSON | Fixed. Three labels: an undocumented `type` (decode returns nil), JSON the event types rejected, and a frame that is not JSON, split by `isJSON` at `:223`. |
| Optional 4, `sawDone` message claims ordering nothing checks | Fixed. `:94` now claims only that `done` arrived, and ordering has its own expectation at `:95`. |
| Optional 5, `WAVE_FORMAT_EXTENSIBLE` rejected | Fixed. `WAVRecording.swift:52` accepts tag 1 and tag `0xFFFE`, and the following guard makes sample width the thing that decides readability, so the message names the real problem. |
| Optional 6, standard output is the only artefact | Fixed. The doc comment at `LiveProtocolTests.swift:11` tees to `~/echotype-live-session.log`, outside the repository. |
| Optional 7, `*.wav` broader than the requirement | Rejected, and the rejection holds: both patterns are still in `.gitignore` and `git check-ignore` confirms they bite. |

### Verification rerun

- `swift test --disable-xctest`: exit 0, 27 tests, the live test reported as
  `skipped` with the message naming both variables. Exit 0 with `XAI_API_KEY` alone and with
  `ECHOTYPE_FIXTURE_WAV` alone, so a half-configured run is never a failure.
- `swift-format lint --recursive Sources Tests`: clean.
- The live path was reviewed by reading. It cannot be executed here: system libcurl 8.5.0
  carries no `ws` or `wss` protocol, so `URLSessionWebSocketTask` fails instantly with
  `NSURLErrorDomain -1002`. That is the established limitation recorded in the handoff.

### Non-blocking observations, not findings

- A server that closes the socket before `transcript.created` sets `streamEnded` but not
  `isSettled`, so the run still waits the full 15s and then streams into a dead socket. The
  send throws, the report is printed first and names the close, so the evidence survives; it
  costs 15s on a branch the live session is unlikely to take.
- `doneArrivedEarly` is decided by `audioStreamClosed`, which is set after both control frames
  are sent. A `done` landing inside the microseconds between the last send returning and the
  actor hop would be flagged early. Network round trip makes this unreachable in practice.

Both are cheaper to leave than to guard, and neither affects the recorded evidence.

## Independent review, live run

- Reviewer: independent review agent, second review of this workstream, uncommitted diff at
  base `56b18ea`. Scope as briefed: the Findings section against the two raw logs, the one
  production change, the three claimed contradictions, criteria 2 and 3, lint, and whether
  transcript text leaked. The harness code covered by the first review and its closure was not
  re-reviewed; it is unchanged.
- Verdict: changes required. The recorded sequence table is accurate frame by frame, and the
  headline conclusions hold: `endpointing=2000` behaved, neither pause closed the session,
  `speech_final` implies `is_final`, `transcript.done` is empty, and committing on
  `speech_final` alone reproduces the dictation. Four Required findings, all in the Findings
  section rather than the code: one reproducibility claim the two logs falsify, one fixture
  measurement that is wrong and that the whole endpointing table is built on, and two
  behaviours in the logs that workstream 4 needs and the section does not record.
- Checks run. `swift test --disable-xctest` with `XAI_API_KEY` and `ECHOTYPE_FIXTURE_WAV`
  unset: exit 0, 27 tests, the live test reported as
  `skipped: "Set XAI_API_KEY to an xAI key and ECHOTYPE_FIXTURE_WAV to the path of a 16-bit
  PCM WAV of 15 to 30 seconds of speech containing at least two pauses of three seconds or
  more."` Criterion 2 holds. `swift-format lint --recursive Sources Tests`: clean.
- Criterion 3 holds. The tracked and untracked set is `.gitignore`,
  `Sources/EchoTypeCore/STT/STTEvent.swift`, this document, `plan.md`,
  `Tests/EchoTypeCoreTests/Integration/LiveProtocolTests.swift` and
  `Tests/EchoTypeCoreTests/Integration/WAVRecording.swift`. No `.wav` and no `.log` exists
  anywhere in the tree. `git check-ignore` confirms `*.wav` and `Tests/Fixtures/` both bite.
  The only key-shaped string is the pre-existing `xai-123` placeholder at
  `STTConnectionTests.swift:53`.
- No transcript text leaked. Searching the whole tree for every distinctive word of the three
  passages returns nothing. The Findings section keeps to character counts, word counts, flags,
  timings and segment boundaries, which is the lead's standing decision. Two content
  descriptions sit at the edge of it, "passage 1 opening" and the note that an interim spelled a
  date and a time in words before `format=true` normalised them to numerals, but neither
  reproduces text and the second is the only way to evidence what `format=true` does.
- Verified accurate, so the lead does not have to recheck it. Every row of the recorded sequence
  table matches `~/echotype-live-session.log` exactly: all 30 wall clocks, all 30 audio
  positions, every `is_final` and `speech_final` flag, every `start + duration` boundary, every
  word count, and all 22 character counts. Both pause gaps (1.98s, 2.88s), both cadence sets
  (0.92/0.92/1.04 and 1.02/1.01/1.02), the nine `is_final` frames and three `speech_final`
  frames, the two byte-identical twins, the `language`-on-non-empty-text rule, the absence of
  `confidence`, the `words`-only-on-`is_final` rule, and the totals are all borne out. The
  fixture's two digital silences are exactly `6.000-9.500s` and `15.500-19.000s`, zero samples
  throughout, as claimed.

### Required findings

1. **The reproducibility claim is false, and it is the stated reason the Findings state timings
   without hedging.** Findings, opening paragraph: "Both sessions produced the same 30 server
   frames in the same order, with every segment boundary identical to the millisecond and every
   arrival within 0.1s of wall clock". The frame count and order do match. The other two claims
   do not. Segment boundaries differ on two frames: the third partial (10 chars, passage 1) is
   `1.620-1.900` in run 2 and `1.620-2.900` in run 1, and the empty partial after pause 2's burst is
   `16.740-16.800` in run 2 and `16.740-17.000` in run 1. Arrivals differ by more than 0.1s on
   six frames: 0.81s on that same third partial (2.80s against 3.61s), then 0.24s, 0.24s,
   0.16s, 0.13s and 0.12s. Two frames also differ in text. The same sentence appears in External
   validation, Attempt 3, as "It reproduced the first session's timings exactly". Nothing in the
   table is wrong because of this, and nothing in the endpointing analysis changes, since all
   the endpointing frames did land within 0.04s across the two runs. What changes is the warrant:
   the numbers are one sample confirmed in its load-bearing parts by a second, not two identical
   runs, and the section should say so. As written a reader of workstream 4 will treat every
   number in the table as reproducible to the millisecond, including the six that are not.

2. **The fixture's end of speech before pause 1 is wrong, and the whole endpointing table is
   built on it.** Findings, "The fixture, stated first": "Speech energy stops a little before
   each of them, at `6.04s` and `14.08s`". That is impossible for pause 1 as written, because
   the same paragraph states the digital silence begins at `6.000s`, and `6.04` is after it.
   Measured off `~/echotype-fixtures/sample-with-pauses.wav`, the last non-zero sample before
   pause 1 is at `6.0000s` with amplitude -2101, and the 10ms window ending there has an RMS of
   1243 against a peak of 3876. Passage 1 is not trailing off into the pause, it is cut to
   digital zero at full volume. `14.08s` for pause 2 is right: from there to `15.500s` the RMS
   sits at 4 to 11, about -50 to -60 dB below peak, which is the "1.4s of very quiet audio" the
   section describes.
   Corrections that follow, all inside the endpointing table and the paragraphs under it:
   - "Speech energy ends (audio timeline)" for pause 1 is `6.000s`, not `6.04s`.
   - "Boundary minus end of speech" for pause 1 is `8.900 - 6.000 = 2.90s`, not `2.86s`. The
     observed range is `2.65-2.90s`, not `2.66-2.86s`, which also corrects "about 700-900ms
     more than the 2000ms asked for" to about 650-900ms, and the same `2.66-2.86s` figure
     quoted in contradiction 2 and again in the Implementation handoff's Live run note.
   - "Wall clock when that audio had been handed over" for pause 1 is `~6.47s`, not `~6.50s`,
     and "End of speech to frame in hand" is `2.99s`, not `2.96s`. This moves the conclusion in
     the right direction: both pauses are now within 50ms of 3.0s, so "budget about 3s of wall
     clock" is better supported than the section claims, not worse.
   - The "Two readings of the reference point" paragraph needs rewriting. It argues that the
     digital-silence reference gives inconsistent results (2.90s and 1.24s) while the
     speech-energy reference gives agreeing ones (2.86s and 2.66s). With the correct figure the
     two references coincide at pause 1, both giving 2.90s, so pause 1 discriminates between
     them not at all and the entire argument rests on pause 2. The conclusion still stands, and
     pause 2 alone is enough to carry it: a 1.24s boundary would be below the configured 2000ms,
     which is impossible, so the endpoint must have counted the quiet tail from 14.08s as
     silence. It keys off its own voice activity detection, not off digital zeros. But the
     section should not claim two agreeing measurements when it has one measurement and one
     tautology, and 2.90s against 2.66s is a 240ms spread rather than the near-agreement implied.
   - Recommended replacement number for workstream 4 to budget against, because it needs no
     fixture analysis at all and is tighter than anything derived from one: the declared boundary
     lands `8.900 - 6.097 = 2.803s` and `16.740 - 14.012 = 2.728s` after the endpoint's own last
     reported word `end`. Both values come straight out of the log, they agree to 75ms across two
     acoustically different pauses, and they are the endpoint's own account of its own latency.
     The fixture-derived 2.65-2.90s belongs beside it as the external check.

3. **How late the "speech resumed" signal is, unrecorded.** Contradiction 1 tells workstream 4
   to drive the paused state from "the last partial with non-empty text or ... the last
   `speech_final`", and the Findings never say how far behind resumed speech that signal is. It
   is in the logs. Speech resumes in the fixture at about `10.41s` and `19.10s` on the audio
   timeline, which the harness had handed to the socket by wall clock `~10.88s` and `~19.57s`.
   The first text-bearing partial of each passage arrived at `11.66s` and `21.88s`, so the signal
   lagged resumed speech by `0.78s` and `2.31s`. The spread is the point: at `endpointing=2000`
   an overlay that un-pauses on the first non-empty partial may sit in its paused state for over
   two seconds after the user starts speaking again. That is a third of the specification's ten
   second pause threshold and the only latency in the recommended mechanism that the section does
   not quantify. Worth a row in the endpointing table or a short paragraph under contradiction 1.

4. **The interim text resets several times inside an utterance, which the section does not
   record and which changes what the overlay can display.** The Findings establish that an
   `is_final` frame carries the run since the previous `is_final` rather than the whole
   utterance, and warn correctly against concatenating those runs. What they do not say is that
   the *non-final* partials reset too. In passage 1 the partial texts run 19 chars, 18 chars
   (`is_final`), then 10 chars, 20, 15 (`is_final`), then 10, 13 (`is_final`), and only the
   `speech_final` frame at 9.46s carries all 48. `TranscriptAssembler.applyPartial` assigns
   `interim = segment` on every non-`speech_final` partial, so the dimmed line the specification
   describes would drop back to the current run twice inside passage 1 and recover the passage
   only at `speech_final`, up to 6.9s after its first word. Words already correctly transcribed
   would visibly disappear from the overlay and come back. Nothing in v1's committed text is
   affected, and `TranscriptAssembler` is right as it stands, but this is a live-protocol
   behaviour that shapes what workstream 4 hands the overlay, it is visible in the recorded
   sequence, and a reader of the current section would not predict it.

### Optional observations

1. **The burst shape at `finalize` is misdescribed.** Findings, Partial cadence: "At pause 2 and
   again at `finalize`, three frames landed in the same millisecond: an `is_final` frame, a
   byte-identical frame with `speech_final` also true, and an empty partial opening the next
   segment." At `finalize` the third frame was `transcript.done`, not an empty partial, and no
   empty partial followed the final burst at all. The table is right; the prose generalises one
   burst onto the other.
2. **`0.45-0.5s` is the harness's pacing offset, not endpoint latency.** Findings, Partial
   cadence: "each frame describes audio that was handed to the socket about 0.45-0.5s earlier".
   The log's `audio` column is the position reached when the frame arrived, so `wall - audio` is
   a constant 0.46-0.50s across the whole session, which is just how long after connect the
   streaming loop started. The real lag, from the audio a frame describes being handed over to
   the frame arriving, is 0.29s to 0.51s with a mean near 0.37s. The endpointing table's
   arithmetic is unaffected, since it uses the offset correctly as a wall-clock conversion, but
   the sentence as written invites workstream 4 to add a 0.45s latency that is not there.
3. **Contradiction 2 is a clarification, not a contradiction.** The specification's connection
   parameters section says only that `endpointing` "is set high deliberately" and that "the
   default 400ms would chop a prompt into fragments". It nowhere states that `endpointing=2000`
   produces a 2000ms boundary, and no sentence of it is quoted in the finding. Nothing in the
   specification is falsified, so this reads better as an entry under undocumented behaviour with
   the recommendation to write the observed number into the specification. Contrast contradiction
   1, which quotes the specification exactly (`docs/specs/echotype-v1.md:85-87`, "The server's
   own voice activity detection is already the signal: no new partials means silence, new
   partials mean speech resumed") and is a real, load-bearing, correctly scoped contradiction.
   Confirmed against both logs: partials kept arriving at ~1 Hz with empty text throughout both
   silences, two across pause 1 and five across pause 2, and nothing arrived at all during the
   1.98s and 2.88s the endpoint spent deciding.
4. **Contradiction 3 is not a contradiction either, and the entry says so.** The specification's
   sentence, "plus whatever trailing partial the `finalize` resolves into", is quoted correctly
   and describes exactly what happened: `finalize` resolved the tail into a further
   `speech_final` partial. The entry concedes this ("That is right in substance"). The two
   genuinely useful parts of it, that `transcript.done` is empty and that the assembler's `done`
   fallback would commit a run rather than an utterance if it ever fired mid-utterance, are
   already covered by the `transcript.done` section and belong as a note to workstream 4. As it
   stands the drift log will carry three contradictions when the evidence supports one.
5. **A `start` generalisation that does not hold across a pause.** Findings: "`start` on a
   **non**-final partial does track the run being reported, moving to the previous `is_final`
   boundary each time." True within a passage (1.620 then 4.160 in passage 1). Not true across
   one: after pause 1 closed at 8.900 the empty partials reported `start` 8.9, but the first text
   partial of passage 2 reported `start` 10.080, the speech onset, not the previous boundary. The
   same happens at 19.460 after pause 2.
6. **The close delay in run 1 was 2.00s, not 2.01s.** Findings, Undocumented behaviour: "The
   server closed the socket 2.01s after `transcript.done` in the first session and 2.01s in the
   second". Run 1 is `27.88 - 25.88 = 2.00s`; run 2 is `27.98 - 25.97 = 2.01s`. The
   recommendation to allow at least 2.5s is unaffected.
7. **"In the same millisecond" overstates the log's resolution.** The harness prints wall clock
   to two decimals, so the tightest claim the evidence supports for the bursts is "within 10ms".
   The millisecond claim is sound only where it refers to the JSON `start` and `duration` fields,
   which is not how the Partial cadence and External validation sentences read.
8. **Nothing in the committed suite covers a `words` array, which is why the defect survived to
   a paid session.** `Fixture.partial` emits `type`, `text`, `is_final` and `speech_final` and no
   `words` key, and no test anywhere constructs or decodes an `STTEvent.Word`. `STTEvent.decode`
   therefore has a path that no test reaches, which is precisely the path the endpoint exercises
   on every frame the transcript is assembled from. The fix is verified by the rerun, so the
   defect is gone, but the gap that hid it is still open and a future rename would reach the live
   session the same way. One optional `words` argument on `Fixture.partial` and one expectation
   in the existing "A partial decodes its text and flags" test would close it. Out of this
   packet's scope, since workstream 2 owns those tests, which is why it is Optional rather than
   Required.
9. **`*.log` is not ignored.** `git check-ignore` confirms a `session.log` dropped in the tree is
   committable. Criterion 3 holds today only because the documented command tees to
   `~/echotype-live-session.log`, outside the repository, and that path lives in a doc comment.
   Given the first review's Optional 7 was rejected on the grounds that criterion 3 is a hard
   criterion, the asymmetry is worth noting. The session log is the artefact most likely to be
   created by hand during a rerun.
10. **`plan.md` still contradicts this packet.** The workstream table reads `Blocked (E2)` and
    gate G1 reads `Pending (E2)`, while the Status line here reads "gate G1 passed" and External
    validation reads `Passed`. External validation already says the lead owns discharging E1 and
    E2; flagging it so it is not lost before the commit.
11. **The fixture's source filename in `plan.md` reproduces a phrase of the dictation.** The E1
    answer names the public-corpus source file by its original name, and that name is a phrase
    from passage 2. It is public-corpus audio rather than Aidan's speech, so it is outside the
    letter of the standing decision, and it is the provenance record for the fixture, which is
    worth keeping. Noted only because the decision was framed as no verbatim transcript text.

### The `STTEvent.Word` change

Correct, minimal and well evidenced. Every word object in both logs is exactly
`{"text":...,"start":...,"end":...}`, so `text` is right and `word` was wrong. The diff is the
property, the initialiser label, the assignment and the doc comment, and `git diff --stat`
confirms `Sources` is otherwise untouched. `keyDecodingStrategy = .convertFromSnakeCase` does not
interact with a single-word key, so nothing else in `decode` shifts. The failure mode described
in the handoff is exactly what run 1 shows: eight frames annotated `JSON THE EVENT TYPES
REJECTED`, all eight `is_final`, including all three `speech_final` frames, and an assembled text
of passage 3 alone. Run 2 has no rejected frame and the complete three-passage text. The
packet's Initial ownership allows this fix and the handoff names it as drift, as required.

### Questions

1. `confidence` survives on `Word` although the endpoint never sent it in 30 frames, and the
   Findings record its absence. Keep it or drop it? It is one line, workstream 4 consumes this
   type, and the doc comment already justifies optional timings. Either answer is defensible; the
   lead should pick one rather than let it drift into workstream 4 unexamined.
2. Required findings 1 and 2 are corrections to the Findings section, which this review may not
   edit and which the packet treats as the deliverable. Does the lead want a remediation pass to
   apply them in place, or a short correction note appended under Findings? Required findings 3
   and 4 are additions rather than corrections and could go either way.

## Resolution, live run

### Finding dispositions

All four Required findings accepted. Six of the eleven Optional observations accepted, two
reclassified rather than fixed, three rejected or handled by the lead outside the code. The
lead verified the three load-bearing claims against the fixture and the two logs before
triaging rather than taking them on trust.

| Finding | Disposition | Reason |
|---|---|---|
| Required 1, the reproducibility claim is false | Accepted | Verified: run 1's third partial is `1.620-2.900` at `3.61s` against run 2's `1.620-1.900` at `2.80s`. The one text difference is elsewhere, a trailing character on the 12.6s partial, as the remediation established and this row originally overstated. The Findings state their numbers without hedging *because* of that sentence, so a false warrant is worse than a weak one. Rewritten to say what is true: one recorded sample, with the endpointing frames confirmed by a second run to within 0.04s. |
| Required 2, the fixture's end of speech before pause 1 is wrong | Accepted | Verified off the fixture: the last non-zero sample before pause 1 is at `5.99994s` with the preceding 10ms window at RMS 1386 against a peak of 8908. Passage 1 is cut to digital zero at volume, so `6.04s` is both wrong and after the silence it claims to precede. The whole endpointing table is arithmetic on that number. The corrected figures and the rewritten "two readings" argument are in Findings. |
| Required 3, how late the "speech resumed" signal is, unrecorded | Accepted | Contradiction 1 tells workstream 4 to drive its paused state from the last non-empty partial without saying how far that lags resumed speech. It is in the logs and it is up to about two seconds, a fifth of the specification's ten second threshold. Recorded with the onset measurement's sensitivity stated, since the lead's own measurement put the onsets between `10.40-10.54s` and `19.09-19.71s` depending on the energy threshold. |
| Required 4, interim text resets inside an utterance | Accepted | Verified in both logs: passage 1's non-final partials run 19, 18, 10, 20, 15, 10, 13 characters and only the `speech_final` frame carries all 48. `TranscriptAssembler` is right as it stands, but the dimmed overlay line drops back to the current run twice inside one passage and recovers only at `speech_final`. Workstream 4 hands that to the overlay and could not predict it from the section as written. |
| Optional 1, the burst shape at `finalize` is misdescribed | Accepted | The third frame at `finalize` was `transcript.done`, not an empty partial. The Findings are the deliverable; a factual error in its prose is not optional. |
| Optional 2, `0.45-0.5s` is the harness's pacing offset | Accepted | As written it invites workstream 4 to budget a latency that is not there. The offset is still the right wall-clock conversion in the endpointing table and stays there, labelled for what it is. |
| Optional 3, contradiction 2 is a clarification | Accepted, reclassified | Confirmed against the specification: "Connection parameters" says only that `endpointing` "is set high deliberately" and that "the default 400ms would chop a prompt into fragments". It nowhere claims a 2000ms boundary, so nothing is falsified. The observed number is load-bearing for workstream 4 and keeps its prominence; it moves out of the contradictions list, which now carries the one contradiction the evidence supports. |
| Optional 4, contradiction 3 is not a contradiction | Accepted, reclassified | The specification's "plus whatever trailing partial the `finalize` resolves into" describes exactly what happened, and the entry concedes it. Its two useful parts, that `transcript.done` is empty and that the assembler's `done` fallback would commit a run rather than an utterance if it ever fired mid-utterance, are kept as a note to workstream 4 where they will be read. |
| Optional 5, a `start` generalisation that does not hold across a pause | Accepted | One clause, and the first text partial after each pause reports the speech onset rather than the previous boundary in both logs. |
| Optional 6, the close delay in run 1 was 2.00s | Accepted | Free to correct, and the section's own claim to accuracy is what the rest of it rests on. |
| Optional 7, "in the same millisecond" overstates the log's resolution | Accepted | The harness prints wall clock to two decimals. The millisecond claim is sound for the JSON `start` and `duration` fields and is kept there. |
| Optional 8, nothing in the committed suite covers a `words` array | Rejected, noted | Correct and worth closing, but `STTEventTests` belongs to workstream 2, which is accepted, and this packet's Initial ownership allows this workstream into `Sources` only to fix a defect the live protocol exposed. Reaching into another workstream's tests is not that. Recorded in the drift log so the final review can close it, which is the cheapest place it can be done without reopening an accepted workstream. |
| Optional 9, `*.log` is not ignored | Accepted | One line, and it is the artefact most likely to be created by hand during a rerun, in a workstream whose criterion 3 is absolute. The same reasoning that rejected narrowing `*.wav` argues for adding it. |
| Optional 10, `plan.md` still contradicts this packet | Accepted, lead's own | Discharged at acceptance: the row goes to `Accepted`, gate G1 to `Passed`, and E1 and E2 are removed with their lasting decisions copied into the drift log. |
| Optional 11, the fixture's source filename in `plan.md` reproduces a phrase of the dictation | Rejected | The standing decision covers verbatim transcript text of Aidan's speech. This is public-corpus audio, the filename is the fixture's provenance, and provenance is what makes the fixture caveat checkable. Kept deliberately. |

Lead answers to the reviewer's two questions:

1. `confidence` stays on `STTEvent.Word`. The endpoint sent no `confidence` in 30 frames, and
   YAGNI argues for dropping it, but `Word` is workstream 2's frozen contract and this packet
   lets this workstream into `Sources` only to fix a defect the live protocol exposed. An unused
   optional field that decodes correctly either way is not a defect. It is decided rather than
   drifting: workstream 4 must not expect `confidence` to be populated, and the Findings record
   that it was never sent.
2. The corrections are applied in place. The Findings section is this workstream's deliverable
   and workstream 4 reads it as the account of record, so a correction note appended underneath
   would leave the wrong numbers where they will be read first. Required 3 and 4 are added in
   place for the same reason.

### Simplification/deletion pass

No code was added by this remediation. One line entered `.gitignore` and the rest is the
Findings section stating what the logs show. The harness is unchanged from its accepted closure
review, and the single production change remains the one-property `STTEvent.Word` fix.

## Closure review, live run

- Reviewer: fresh closure session, same brief, uncommitted diff at base `56b18ea`. Scope: the
  fourteen accepted dispositions in "Resolution, live run" against the Findings section, the two
  logs and the fixture, plus criteria 2 and 3 and lint. The harness is unchanged and was not
  re-reviewed. No live session was run.
- Verdict: one Required finding, otherwise accept. Thirteen of the fourteen accepted
  dispositions are applied in the Findings section rather than acknowledged, and every corrected
  figure I checked against `~/echotype-live-session.log`, `~/echotype-live-session-run1.log` and
  `~/echotype-fixtures/sample-with-pauses.wav` is right, including the two the reviewer got wrong
  (the fixture peak is 8908, not 3876, and the corrected external check is `2.66-2.90s`, not
  `2.65-2.90s`). The remaining finding is the reproducibility warrant from Required 1 reappearing
  in narrower form: the section twice claims the endpointing analysis reproduced to within 0.04s,
  and two rows of that table do not.
- Checks rerun. `swift test --disable-xctest` with `XAI_API_KEY` and `ECHOTYPE_FIXTURE_WAV`
  unset: exit 0, 27 tests, the live test skipped with the message naming both variables.
  Criterion 2 holds. `swift-format lint --recursive Sources Tests`: clean, exit 0.
- Criterion 3 holds. Changed or untracked paths are `.gitignore`,
  `Sources/EchoTypeCore/STT/STTEvent.swift`, this document, `plan.md` and
  `Tests/EchoTypeCoreTests/Integration/`. No `.wav` and no `.log` anywhere in the tree, and the
  new `*.log` line means a session log dropped by hand during a rerun cannot be committed either.
  The only key-shaped string is the pre-existing `xai-123` placeholder in `STTConnectionTests`.
  Searching the tree for every distinctive word of the three passages returns nothing: the
  Findings keep to counts, flags, timings and boundaries. `git diff Sources/` is the
  `STTEvent.Word` property, its initialiser label, the assignment and the doc comment, nothing
  else.

### Accepted findings, verified

| Finding | Applied? | What I verified |
|---|---|---|
| Required 1, reproducibility claim | Partly | The "what the numbers below are worth" paragraph replaces the false claim and its specifics are exact: run 1 declared `1.620-2.900` and `16.740-17.000` against run 2's `1.620-1.900` and `16.740-16.800`; arrivals differ by more than 0.1s on exactly six frames (0.81, 0.24, 0.24, 0.16, 0.13, 0.12) with the 0.81s on the third partial (`3.61s` against `2.80s`); interim text differs on one frame by one character. The residual overclaim is finding 1 below. |
| Required 2, fixture end of speech before pause 1 | Yes | Measured off the fixture: last non-zero sample at `5.9999375s`, amplitude `-2101`, peak `8908`, silences exactly `6.000-9.500` and `15.500-19.000` with zero samples throughout. The 10ms window ending at `6.000s` has RMS `1386`. The table now reads `6.000s`, `2.90s`, `~6.47s` and `2.99s`, and `8.900 - 6.000 = 2.90s`, `16.740 - 14.08 = 2.66s` and "about 660-900ms more" all check. The "two readings" paragraph is rewritten to rest on pause 2 alone and says so, and the 240ms spread is stated rather than implied away. The recommended `2.73-2.80s` figure is `8.900 - 6.097` and `16.740 - 14.012` straight from both logs. |
| Required 3, how late "speech resumed" is | Yes | Onsets are threshold-sensitive as the section says: at thresholds 50 to 800 I measure `10.407-10.543s` and `19.105-19.718s`, against the stated `~10.4-10.5s` and `~19.1-19.7s`. With the `0.47s` pacing offset the lags are `0.65-0.79s` and `1.69-2.31s`, against the stated `0.7-0.8s` and `1.7-2.3s`. "A fifth of the ten second threshold" is right and corrects the reviewer's "a third". |
| Required 4, interim text resets inside an utterance | Yes | Passage 1's partial texts are 19, 18, 10, 20, 15, 10, 13 and only the `speech_final` frame carries all 48; `2.56s` to `9.46s` is 6.90s. Matches `TranscriptAssembler.applyPartial`, and the section correctly leaves the assembler alone and hands the consequence to workstream 4. |
| Optional 1, burst shape at `finalize` | Yes | The three shapes now read as the logs have them: pause 2's triple, `finalize`'s pair plus `transcript.done` with no empty partial after, and pause 1's single combined frame with no twin. |
| Optional 2, `0.45-0.5s` is the pacing offset | Yes | `wall - audio` is `0.46-0.49s` in run 2 and `0.41-0.48s` in run 1, consistent with a fixed loop start plus one chunk of rounding. The real lag over the 21 text-bearing partials is `0.29-0.51s`, mean `0.378s`, against the stated "roughly 0.3s to 0.5s" and "mean near 0.38s". The offset is kept only as the wall-clock conversion, which is the correct use. |
| Optional 3, `endpointing=2000` is a clarification | Yes | Moved out of the contradictions list into its own section, which quotes "Connection parameters" accurately (`docs/specs/echotype-v1.md:280-281`) and keeps the observed number prominent. The contradictions list now carries one entry. |
| Optional 4, `transcript.done` is not a contradiction | Yes | Folded into the `transcript.done` section, which concludes "nothing here contradicts it" and keeps both useful parts, including the warning that the assembler's `done` fallback would commit a run rather than an utterance. |
| Optional 5, `start` across a pause | Yes | Both logs: empty partials report `start` 8.9 after pause 1 while passage 2's first text partial reports `start` 10.080, and the same at 19.460. |
| Optional 6, run 1 closed in 2.00s | Yes in Findings | `27.88 - 25.88 = 2.00s` and `27.98 - 25.97 = 2.01s`. Findings now say so; External validation does not, see the stale list. |
| Optional 7, "in the same millisecond" | Yes | The bursts now read "within 10ms", and the millisecond claim survives only where it describes the JSON `start` and `duration` fields. |
| Optional 9, `*.log` not ignored | Yes | One line in `.gitignore` with a comment; `git status` shows no other change to the file. |
| Optional 10, `plan.md` contradicts the packet | Outstanding by design | Still `Blocked (E2)` and `Pending (E2)`. The disposition defers this to acceptance, which is where it belongs. |
| Optional 8 and 11 | Rejected, correctly | `STTEventTests` belongs to workstream 2 and the packet's ownership does not reach it; the fixture's provenance filename is public-corpus audio, not Aidan's speech. Neither is promoted here. |

Also spot-checked and correct, so the lead need not recheck: all 30 rows of the recorded sequence
against run 2, including every wall clock, audio position, flag, `start + duration` boundary, word
count and character count; the pause gaps of 1.98s and 2.88s; the cadence sets; the nine `is_final`
and three `speech_final` frames; `language` present only on non-empty text; `confidence` never
sent; `words` only on `is_final`; the totals; and run 1's identical 30 frames in the same order
with 8 rejected frames leaving passage 3 alone as the assembled text.

### Required findings

1. **"Within 0.04s" is claimed for the whole endpointing analysis, and two of its rows are not.**
   Findings, opening: "every frame in the endpointing analysis, which landed within 0.04s of the
   other run", and again under "Endpointing across the two inserted pauses": "Every row below was
   confirmed by run 1 to within 0.04s." True for the frames the endpointing conclusion rests on,
   the two `speech_final` frames, which arrived at `9.42s` and `17.63s` in run 1 against `9.46s`
   and `17.59s` in run 2, with identical boundaries and identical last-word `end` values. Not
   true for three rows of that table. "First text-bearing partial after the pause" is `11.61s`
   and `21.64s` in run 1 against `11.66s` and `21.88s`, a 0.24s difference at pause 2, and "Lag
   behind resumed speech" moves with it. "Audio handed over when the frame arrived" is `17.20s`
   in run 1 against `17.10s`, which also makes "Silence remaining" 1.80s rather than 1.90s. The
   section contradicts itself two paragraphs later, where it correctly reports `11.61s` and
   `21.64s` as run 1's figures, and the 21.88/21.64 gap is one of the six arrivals the opening
   paragraph already classes as one sample. This is the defect Required 1 existed to remove,
   reasserted over a narrower set, and it is the sentence that licenses workstream 4 to trust the
   table. Fix by scoping the claim to what reproduces: the `speech_final` frames, their declared
   boundaries and the last-word `end` values they are measured against. The endpointing
   conclusion itself is unaffected and needs no change.

### Stale elsewhere, for the lead

Beyond the two sentences already known to be the lead's, External validation Attempt 3's "Three
specification contradictions" and "reproduced the first session's timings exactly":

- External validation, Attempt 3: "the server closing the socket 2.01s later" is stated of both
  sessions. Run 1 was 2.00s, which is the correction Optional 6 accepted and Findings applied.
- Resolution, live run, the Required 1 row: "run 1's third partial is `1.620-2.900` at `3.61s`
  against run 2's `1.620-1.900` at `2.80s`, and its text differs too". The boundary and arrival
  are right; the text is not. That frame reads the same in both runs. The one text difference
  between the runs is a trailing character on the 12.6s partial, which is what Findings says.
- The specification's silence assumption appears twice, not once. Findings quote lines 85-87
  correctly, but `docs/specs/echotype-v1.md:384` repeats it as "any new partial" moving the
  overlay out of `paused`. Whoever changes the wording in workstream 4 or 5 has two places to
  change, and the Findings entry should say so.

### Non-blocking observations, not findings

- "Wall clock when that audio had been handed over" for pause 2 reads `~14.54s`; `14.08 + 0.47`
  is `14.55`, which makes "End of speech to frame in hand" 3.04s rather than 3.05s. Both are
  inside the 100ms quantisation of the `audio` column and neither touches "within 50ms of 3.0s".
- The fixture's quiet tail is stated as "RMS between about 5 and 14, roughly 56 to 65 dB below
  peak". Measured over `14.10-15.50s` in 10ms windows it is 3.0 to 16.0, or 55 to 69 dB below the
  8908 peak. Wider than stated, in the direction that strengthens the point, and the argument
  only needs the tail to be non-zero and far below speech.

## Acceptance

Accepted by the lead on 2026-09-22.

This workstream was interrupted twice, once by each escalation and once by an infrastructure
failure mid-remediation. The recovering lead confirmed the diff's base as `56b18ea`, that every
change belongs to this workstream, and that the two live logs and the fixture were still on
disk, then re-derived the three load-bearing claims of the second review from the fixture and the
logs before triaging them. No third live session was run: the evidence was already captured, and
rerunning it would have cost money to learn nothing.

What the workstream retires. `speech_final` behaves across a pause: `endpointing=2000` closed
each of the two inserted pauses with exactly one `speech_final`, fired comfortably inside the
3.5s of silence, never fired inside a passage, kept the socket open throughout, and committing on
`speech_final` alone reproduced the dictation exactly. The window is wider than the parameter
suggests, about 2.73-2.80s to the declared boundary and about 3.0s of wall clock to the frame
being in hand. The one thing the specification got wrong is silence detection, which cannot key
off the arrival of partials, and that is recorded as drift for workstream 4 or 5 to fix in
wording.

One remediation pass ran, applying all four Required and six Optional dispositions in
"Resolution, live run", plus two reclassifications that reduced the contradictions list from
three to the one the evidence supports. Closure raised one Required finding, an over-broad
reproducibility claim covering three table rows that do not reproduce; the lead applied the
narrow correction itself rather than opening a third loop, since it is a wording fix to the
lead's own deliverable with the underlying conclusion untouched. Closure's three stale-record
notes were fixed in the same pass.

Final verification: `swift test --disable-xctest` with `XAI_API_KEY` and `ECHOTYPE_FIXTURE_WAV`
unset exits 0 with 27 tests and the live test skipped, so criterion 2 holds.
`swift-format lint --recursive Sources Tests` is clean. No key, recording, transcript or session
log is in the tree and `*.wav`, `*.log` and `Tests/Fixtures/` are all ignored, so criterion 3
holds. Criteria 1, 4 and 5 are met by the live sessions, the Findings section and the drift log.
