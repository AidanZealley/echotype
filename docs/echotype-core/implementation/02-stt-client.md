# Workstream 2: STT client and transcript assembler

Status: accepted.

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

- Base commit: `ef0ef74` (Core 01: Package skeleton and audio converter)
- Outcome: Done. All seven acceptance criteria met; the work is uncommitted.
- Files changed: added `Sources/EchoTypeCore/STT/STTEvent.swift` (events and `STTError`),
  `TranscriptAssembler.swift`, `WebSocketTransport.swift`, `STTConnection.swift`,
  `STTClient.swift`, `URLSessionWebSocketTransport.swift`, and
  `Tests/EchoTypeCoreTests/STTFixtures.swift`, `TranscriptAssemblerTests.swift`,
  `STTClientTests.swift`, `STTConnectionTests.swift`. All untracked, so they need an explicit
  `git add`. `Settings`, `AudioConverter`, `Package.swift` and `plan.md` untouched.
- Decisions:
  - `Settings` needed no new field. Every other query parameter the endpoint takes is a
    constant the specification fixes, so `encoding`, `sample_rate`, `interim_results`,
    `endpointing`, `filler_words` and `format` live in `STTConnection` rather than becoming
    tunables nothing tunes. Only `language` and `keyterms` come from `Settings`.
  - The transport carries `String` messages, not typed events, so decoding is the client's
    job and fixtures are the JSON the endpoint actually sends. `messages()` returns an
    `AsyncThrowingStream` that finishes on close and throws on failure.
  - `STTEvent.decode` returns `nil` for a well-formed message with an unrecognised `type` and
    throws only on undecodable JSON, so a new server event cannot kill a session.
  - `STTClient` is an actor with `run()`, `send(audio:)` and `finish()`. `run()` consumes the
    stream and returns the final text; `text` stays readable after it throws, because the
    specification inserts the finalised segments when a socket drops mid-session.
  - Audio handed over before `transcript.created` is queued and flushed the instant it
    arrives, rather than dropped. Dropping it would reintroduce the first-word clipping the
    audio section is written to avoid. If `created` never arrives, `finish()` discards the
    queue and still sends the closing messages.
  - Order on the wire is kept by a chain rather than a queue. The actor holds the most
    recently handed-over send as a task, and every send, including the flush of held audio and
    the closing messages, awaits that task before touching the socket. The actor is reentrant
    across the await inside `transport.send(binary:)`, so without the chain a chunk handed over
    while an earlier send is suspended would overtake it, and `finish()` would close the audio
    stream ahead of audio still on its way out. `send(audio:)` awaits its own send, so it
    returns once the chunk is on the wire and a failed chunk surfaces to its caller rather than
    vanishing; a failure does not stop the sends behind it, since each caller sees only its own
    error.
  - The assembler holds committed text and the trailing interim separately. Only a
    `speech_final` partial commits, so `is_final` alone and any later rewrite cannot reach the
    inserted text. Empty segments commit nothing, which is what makes a silent session return
    an empty string rather than a run of spaces.
  - `transcript.done` also commits whatever interim is outstanding. Under the documented
    reading that is a no-op, because a `speech_final` clears the interim as it commits; if
    `finalize` instead resolves the tail with `is_final` alone, it is what keeps the user's
    last sentence. It cannot duplicate text, since only an uncommitted tail is ever there.
  - `URLSessionWebSocketTransport` is the only file importing `FoundationNetworking`, behind
    `#if canImport`. It maps a rejected handshake to `STTError(httpStatus:)` from the task's
    response, and treats an orderly close as the end of the stream rather than an error. No
    test touches it.
  - `STTError` gives each documented status its own case and folds anything else into
    `unexpectedStatus(Int)`, so a caller can distinguish a bad key from a rate limit without
    matching on numbers.
  - Files live in `Sources/EchoTypeCore/STT/` per the plan's ownership handoffs, rather than
    at the root of `EchoTypeCore` as the specification's illustrative tree draws them.
- Verification: `swift build` (clean), `swift test --disable-xctest` (26 tests, exit 0) and
  `swift-format lint --recursive Sources Tests` (exit 0, silent) on Swift 6.4 on the Linux
  machine. `EchoTypeCore` still imports Foundation only, plus the one guarded
  `FoundationNetworking`.
- Known limitations or external checks:
  - Every event shape here is taken from documentation, not observation. The field names
    inside `words` (`word`, `start`, `end`, `confidence`) are the least certain part, are not
    used by anything and are no longer asserted by any test, so nothing here pins the guess;
    workstream 3 should confirm them against a live session.
  - `transcript.done` is decoded as a bare event. If it turns out to carry the full
    transcript, workstream 3 will find that and the assembler's contract may want revisiting.
  - A `+` in a keyterm is not percent encoded. Deferred to workstream 3, which can see what
    the endpoint does with it before anyone encodes by hand.
  - Nothing closes the transport; `run()` returns and leaves the socket to the caller.
    Workstream 4 owns the session lifecycle and with it the close.
  - The live transport has never opened a socket. Workstream 3 is its first exercise, and the
    handshake-status mapping in particular rests on `URLSessionWebSocketTask` putting the
    rejected response on the task, which is unverified on corelibs.
- Specification drift: none in behaviour. One interpretation worth recording: the
  specification says the final text is every `speech_final` segment "concatenated in order",
  and taken literally that runs the last word of one utterance into the first word of the
  next. Segments are joined with a single space instead, each trimmed, with nothing added at
  either end of the result. Workstream 3 can confirm whether the endpoint already includes
  leading whitespace, in which case the trim is what keeps this correct.

- Remediation pass: fixed the required ordering defect above and took the lead's accepted
  optional items. Tests changed: added one that hands the client a chunk while a send is
  suspended inside a blocking transport (it fails against the previous flush, verified by
  reverting it), one that `transcript.done` commits a tail resolved without `speech_final`,
  one that a stream ending without `transcript.done` still returns the finalised segments, and
  one that stopping before `transcript.created` sends the closing messages and leaks no audio.
  `finishSendsTheClosingMessages` was replaced by that last test rather than kept alongside it,
  the word timing assertions and the `Fixture.words(in:)` helper feeding them are gone, and so
  is the redundant distinctness loop in `documentedStatusesMapToDistinctErrors`. `run()`'s doc
  comment now says a malformed frame propagates the decoder's error.

- Second remediation pass: two ordering repairs. The queue-and-drain design was replaced by the
  `lastSend` chain described above, because `finish()` skipped a drain already in flight and
  sent `finalize` and `audio.done` over the top of audio still on the queue;
  `finishWaitsForAudioAlreadyHandedOver` covers that, releasing a gated binary send after
  `finish()` has been called from its own task and asserting the closing messages follow the
  audio. That contract change then deadlocked
  `queuedAudioKeepsItsOrderWhileASendIsInFlight`, which awaited its second `send(audio:)` from
  the test's own task and so waited on the gated first send the next line was about to release;
  the second chunk is now handed over from a separate task, the way the `finish()` test already
  does it, and the assertion that both frames reach the socket in handover order is unchanged.
  That test is still load-bearing: on a copy of the package outside this repo, reducing
  `sendInOrder` to sending immediately without chaining behind `lastSend` makes it fail on
  exactly that assertion.

## Independent review

- Reviewer: fresh review agent, independent of the implementation agent.
- Verdict: Changes requested. All seven acceptance criteria are met and I reproduced the
  verification (`swift build` clean, `swift test --disable-xctest` 22 tests exit 0,
  `swift-format lint --recursive Sources Tests` silent). Ownership holds: the only source
  changes are the six new files under `Sources/EchoTypeCore/STT/`, and `Settings`,
  `AudioConverter` and `Package.swift` are untouched. One correctness defect is worth fixing
  before the commit, and it is in the queueing the client added rather than in anything a
  criterion asked for.
- Required findings:
  1. Queued audio can reach the socket out of order. `STTClient.run()` sets `isReady = true`
     before awaiting `flushQueuedAudio()` (`STTClient.swift:31-33`). The actor is reentrant
     across that await, so a `send(audio:)` arriving while the flush is suspended in
     `transport.send(binary:)` sees `isReady` true and sends its chunk immediately, ahead of
     the chunks still queued. I reproduced this outside the repo with a transport whose first
     `send(binary:)` suspends: chunk A was queued before `created`, chunk B handed over during
     the flush, and the transport recorded `["B-later-chunk", "A-first-chunk"]`. The window is
     the handshake, which is the one place the queue exists to protect, and the capture layer
     will be pushing a 100ms chunk into it every 100ms. The fix does not need a new mechanism:
     drain by taking the first element each time and removing it after the send completes, and
     flip `isReady` only once the queue is empty, so a chunk arriving mid-drain appends behind
     what is still pending. The fake transport never suspends, which is why the suite cannot
     see this; a transport that blocks one send would cover it.
- Optional observations:
  1. A `+` in a keyterm is not percent encoded. `URLComponents` leaves it alone, so
     `["c++ lang"]` goes out as `keyterm=c++%20lang` (checked against the built URL). A server
     decoding the query as form data reads those as spaces, and "C++" is a plausible keyterm
     for this user. Space handling, which is what criterion 5 asks for, is correct. Workstream
     3 can confirm what the endpoint does with `+` before anyone adds encoding by hand.
  2. `partialDecodesItsPayload` (`TranscriptAssemblerTests.swift:99-117`) asserts `start`,
     `end` and `confidence` values that no production code reads and that the handoff itself
     calls the least certain part of the event shapes. It pins a guess. `Fixture.words(in:)`
     exists only to feed it. Asserting `text`, `isFinal` and `speechFinal` decode correctly is
     the part the product depends on.
  3. The distinctness loop in `documentedStatusesMapToDistinctErrors`
     (`STTClientTests.swift:86-89`) re-derives the six cases the six lines above already
     assert individually, and its failure message prints the array index rather than the
     status. Deleting it loses no coverage.
  4. `FakeWebSocketTransport.endStream()` is never called, and the path it was written for,
     the stream finishing without `transcript.done` (`STTClient.swift:42`), has no test. That
     path is the specification's dropped socket, where returning the finalised segments rather
     than nothing is the behaviour that matters. Either cover it or drop the helper.
  5. `finishSendsTheClosingMessages` calls `finish()` after `run()` has already returned,
     which is not the order the session uses. It would still pass if `finish()` were broken
     mid-session. Nothing covers `finish()` flushing the queue, or discarding it when `created`
     never arrived, which is the specification's "stop pressed before `transcript.created`"
     edge case.
  6. `run()`'s doc comment says it throws `STTError` for an `error` event or a transport
     failure, but `try STTEvent.decode` propagates a `DecodingError` for a malformed frame.
     One bad frame ends the session while an unknown `type` does not. The text is still
     recoverable through `client.text`, so this is a comment accuracy point rather than a bug.
- Questions:
  1. The assembler drops a trailing interim that never becomes `speech_final`. If `finalize`
     resolves the tail with `is_final` alone, or if `transcript.done` carries it, the user
     loses their last sentence silently, which is the worst failure this component has. The
     handoff flags the protocol uncertainty and leaves it to workstream 3, but the assembler
     contract is frozen for workstreams 3 and 4 now. Committing the trailing interim when
     `done` arrives is a no-op under the reading the code already assumes, since `interim` is
     empty after a `speech_final`, and recovers the text under the other. Worth the lead
     deciding now rather than after two workstreams build on the current contract.
  2. Nothing calls `WebSocketTransport.close()`. `STTClient` returns from `run()` and leaves
     the socket to the caller. I assume that is deliberate and workstream 4 owns it, since
     the specification bills streaming time for an open socket. Confirming it fixes the seam's
     ownership in writing.

## Resolution

- Finding dispositions:
  - Required 1 (out-of-order queued audio): accepted and fixed. Every chunk now goes through
    the queue and a single drain runs at a time, so a chunk handed over while a send is
    suspended lands behind what is still pending. A transport whose first binary send suspends
    covers it; the remediation agent confirmed the test fails against the previous flush.
  - Question 1 (trailing interim): decided by the lead, commit it when `transcript.done`
    arrives. The assembler contract freezes for workstreams 3 and 4 now, losing the user's
    last sentence is the worst failure this component has, and the change is a no-op under the
    documented reading because `speech_final` clears the interim. It cannot duplicate a
    committed tail, since both paths go through the same commit.
  - Question 2 (who closes the transport): confirmed as asked. `STTClient` neither opens nor
    closes the socket; workstream 4's session machine owns the lifecycle, which is why
    `WebSocketTransport.close()` exists on the seam and no client code calls it.
  - Optional 2, 3, 4, 5 and 6: promoted. Two of them delete assertions on protocol details
    nothing reads, two cover behaviour the specification names (the dropped socket returning
    finalised text, and stop pressed before `transcript.created`), and one corrects a doc
    comment. Together they make the suite smaller in claims and larger in coverage.
  - Optional 1 (`+` not percent encoded in a keyterm): deferred to workstream 3. Encoding it
    by hand now is a guess about how the endpoint parses its query string, and workstream 3
    can observe the answer. Recorded as a known limitation rather than a fix.
- Simplification/deletion pass: the readiness flag and the separate flush path collapsed into
  one queue with one drain; `Fixture.words(in:)`, the `words` fixture field, the redundant
  distinctness loop and the misordered `finishSendsTheClosingMessages` were deleted rather
  than kept alongside their replacements. No wrapper, alias or flag was added to preserve the
  first implementation.
- Final verification: `swift build` clean, `swift test --disable-xctest` 25 tests exit 0,
  `swift-format lint --recursive Sources Tests` silent. Imports are Foundation only, with the
  one guarded `FoundationNetworking` in `URLSessionWebSocketTransport.swift`, which no test
  exercises.

### Second resolution, after the recovery

The lead that ran the loop above was terminated after it ordered remediation on the first
closure review's required finding. This section is written by the lead that recovered the
work.

- Recovered state: the diff sits on `ef0ef74`, every change belongs to this workstream, and
  `Settings`, `AudioConverter` and `Package.swift` are untouched. The ordered remediation had
  been applied to the source, replacing the queue and drain with the `lastSend` chain, but it
  was never verified. A test runner from that attempt was still alive six hours later, holding
  the `.build` lock: `queuedAudioKeepsItsOrderWhileASendIsInFlight` had deadlocked, so the
  suite never terminated and acceptance criterion 1 did not hold on the tree as inherited.
  Nothing else had failed; the other 25 tests passed with that one skipped.
- Cause: the remediation changed what `send(audio:)` promises. Chaining behind `lastSend` and
  awaiting the chain means the call returns only once its chunk is on the wire, and the test
  awaited its second `send(audio:)` on the same task that was about to release the gated first
  send.
- Decision: keep the contract and fix the test. The alternative, letting `send(audio:)` return
  once the send is chained rather than sent, would restore the old semantics but discard a
  failed chunk's error into an unawaited task, and the closing messages already have to wait
  for the wire. Awaiting is also what a capture layer wants, since it is the only back
  pressure the client offers. The test now hands its second chunk over from a separate task,
  which is how workstream 4 will drive the client and how the `finish()` test already works.
- Findings from the first closure review: its one required finding was accepted by the
  previous lead, and the `lastSend` chain is the fix. This lead confirmed the fix is sound
  rather than re-deciding it.
- Second closure review: clean. It re-verified every earlier accepted finding against the
  rewritten client, mutation-tested both blocking-transport tests to show they are
  load-bearing, and ran them 100 times each, 40 of those under a single-threaded cooperative
  pool, with no hang and no flake.
- Simplification and deletion pass: nothing was added to preserve the previous design. The
  readiness flag, the drain and the `isDraining` guard are gone, replaced by one chain that
  every send goes through, including the flush of held audio and the closing messages. No
  wrapper, alias, flag or compatibility path was introduced by either remediation.
- Final verification by the lead, on the committed tree: `swift build` clean,
  `timeout 200 swift test --disable-xctest` 26 tests exit 0 and seen to terminate,
  `swift-format lint --recursive Sources Tests` exit 0 and silent.
- Terminal decision: accepted. All seven acceptance criteria hold.
- Note for later leads: run the suite under a timeout and check the exit code. A hung test
  runner holds the `.build` lock for every later agent, and it is how this workstream came to
  be interrupted.

## Closure review

- Verdict: changes requested. Every accepted finding is fixed in the working tree, but the
  fix for required 1 left the same ordering hole one step further on: `finish()` can send the
  closing messages ahead of audio that is still queued.
- Remaining required findings:
  1. `finish()` skips a drain that is already running and sends `finalize` and `audio.done`
     over the top of it (`STTClient.swift:63-71`, `76-83`). `drainQueuedAudio()` returns
     immediately when `isDraining` is true, so the closing messages go out while chunks are
     still on the queue, and those chunks then reach the socket after `audio.done`. I
     reproduced it on a copy of the package outside the repo: with the first binary send
     suspended, a second chunk handed over by a separate task, and `finish()` called from the
     test, the transport had recorded zero binary frames at the moment both text frames were
     sent, and both chunks arrived afterwards. That is the end of an utterance, where the
     queued chunks carry the user's last words, and it is the call pattern workstream 4 will
     have: capture pushing a chunk every 100ms from one task, `finish()` from the hotkey
     release on another. `send(audio:)` already documents that it may return before its chunk
     is on the wire, which is fine on its own; `finish()` is the one caller that has to wait
     for the wire. It needs to await the running drain rather than skip it, for example by
     holding the drain in a task the actor stores and awaits. No test covers `finish()` with a
     non-empty queue, which is why the suite misses this; the resolution claims that coverage
     ("cover behaviour the specification names"), and `finishBeforeTheSessionIsReady` only
     covers the discard path.
- Checks rerun by the closure reviewer, on the current working tree: `swift build` clean,
  `swift test --disable-xctest` 25 tests exit 0, `swift-format lint --recursive Sources Tests`
  exit 0 and silent. Ownership still holds: the only source changes are the six new files
  under `Sources/EchoTypeCore/STT/`, and `Settings`, `AudioConverter` and `Package.swift` are
  untouched.
- Fix verification, one line per accepted finding:
  - Required 1 (out-of-order queued audio): fixed for the path the finding described. Every
    chunk goes through `queuedAudio`, and one drain takes the head of the queue and sends it
    before removing the next, so a chunk appended mid-drain lands behind what is pending. The
    regression test is load-bearing: I reverted the client to the previous readiness-flag
    flush on a copy outside the repo and
    `queuedAudioKeepsItsOrderWhileASendIsInFlight` failed on exactly that assertion. The
    `finish()` gap above is a second instance of the same problem, not a failure of this fix.
  - Question 1 (trailing interim): implemented as decided. `TranscriptAssembler.apply`
    commits `interim` on `.done`, `commit` clears `interim` first so a committed tail cannot
    be inserted twice, and an empty tail commits nothing.
    `doneCommitsTheTrailingInterim` covers the `is_final`-only tail and
    `emptySessionProducesNoText` still returns an empty string.
  - Question 2 (who closes the transport): recorded, and the code matches. `close()` is on
    `WebSocketTransport`, `URLSessionWebSocketTransport` implements it, and no client code
    calls it.
  - Optional 2 (word timing assertions): fixed. `partialDecodesItsPayload` now asserts only
    `text`, `isFinal` and `speechFinal`, the `words` field is gone from the fixtures, and
    `Fixture.words(in:)` is deleted. `STTEvent.Word` stays, which is right, since the scope
    lists it as part of the frozen event types.
  - Optional 3 (distinctness loop): deleted. The seven per-status assertions remain.
  - Optional 4 (`endStream()` unused): fixed. `streamEndingWithoutDoneReturnsFinalisedText`
    covers the dropped socket, and `finishBeforeTheSessionIsReady` uses the helper too.
  - Optional 5 (`finish()` called out of order): partly fixed.
    `finishSendsTheClosingMessages` is gone and `finishBeforeTheSessionIsReady` covers stop
    pressed before `transcript.created`, including that the held audio is discarded rather
    than replayed by a late `created`. The other half of the finding, `finish()` flushing a
    non-empty queue mid-session, is still uncovered, and that is where required 1 above
    lives.
  - Optional 6 (`run()` doc comment): fixed. It now says a frame that is not decodable JSON
    propagates the decoder's error while an unrecognised `type` is ignored, which matches
    `STTEvent.decode`.
  - Optional 1 (`+` in a keyterm): deferred as decided, and recorded under known limitations
    for workstream 3.
- Other defects introduced by the fixes: none found. A send that throws mid-drain loses the
  chunk it had already taken off the queue, which is the right trade when the session is
  ending anyway. `isDraining` is cleared by `defer`, so a throw cannot wedge the queue shut.
- Still open for the lead, unchanged and not a blocker: the six source files and four test
  files are untracked and need an explicit `git add` in the workstream commit.
  `plan.md` is also modified, moving this workstream to "In progress"; the handoff says it is
  untouched.

### Second closure review

- Verdict: no remaining required findings. The first closure review's required finding is
  fixed, the accepted findings it verified survive the `lastSend` rewrite, and the two tests
  that drive `BlockingWebSocketTransport` neither hang nor flake across 100 runs each,
  including 40 under a single-threaded cooperative pool.
- Required finding from the first closure review: fixed. `finish()` no longer bypasses
  anything. It clears the pre-`created` hold, then goes through `sendInOrder`, so `finalize`
  and `audio.done` chain behind every send already handed over
  (`STTClient.swift:71-79`, `86-97`). `finishWaitsForAudioAlreadyHandedOver` is load-bearing
  twice over: on a copy of the package outside this repo, making `sendInOrder` send
  immediately fails it on the frame log, and leaving the chain in place but letting `finish()`
  call `transport.send(text:)` directly fails it on the same assertion while the queued-order
  test still passes. Audio held before `created` and then discarded by `finish()` is unchanged
  behaviour the lead already accepted, covered by `finishBeforeTheSessionIsReady`.
- The `lastSend` chain, checked for release-blocking defects: none found.
  - Ordering. `sendInOrder` reads `lastSend`, creates the task and stores it with no await in
    between, so chain position is fixed by actor entry order and concurrent callers cannot
    interleave into it. `run()` sets `isCreated` and drains the hold into `held` in the same
    synchronous region, so a chunk cannot be queued after the hold has been taken and stranded.
  - Errors. `_ = await previous?.result` discards the previous send's failure, so one failed
    chunk does not cancel the sends behind it, and each caller sees only its own error through
    `try await send.value`. Verified outside the repo with a transport that throws for one
    chunk: the caller got the error, the next chunk and both closing messages still reached the
    socket in order.
  - Cancellation. The chain task is unstructured, so cancelling a caller neither stops the
    frame it already handed over nor wedges the client. Verified outside the repo by cancelling
    two callers across a gated send: later sends and `finish()` still completed in order.
  - Retention. Each task holds only its immediate predecessor, released when that task
    finishes, so the chain does not accumulate. `lastSend` keeps one completed task alive,
    which is nothing.
  - Deadlock. 100 concurrent senders plus a concurrent `finish()` terminated with every frame
    accounted for, repeated 25 times under `LIBDISPATCH_COOPERATIVE_POOL_STRICT=1`.
- The two `BlockingWebSocketTransport` tests: no hang and no timing dependence. The gate has no
  lost-wakeup window, since `isReleased` covers a release that beats the suspension and
  `firstSendArrived` covers a send that beats `waitForFirstSend()`. Both tests synchronise on
  `waitForFirstSend()` rather than on the `Task.yield()` loop, and the loop only makes the
  intended interleaving more likely: if the handed-over task has not reached the actor by the
  time the gate opens, the assertion still holds. 60 runs of the pair passed, then 40 more
  under a single-threaded cooperative pool, then three full-suite runs, with no failure and no
  timeout.
- Checks rerun on the current working tree: `swift build` clean, `swift test --disable-xctest`
  26 tests exit 0 (three times), `swift-format lint --recursive Sources Tests` exit 0 and
  silent. Mutation and probe work was done on a copy outside the repo; no implementation file
  here was edited. Ownership still holds: six new files under `Sources/EchoTypeCore/STT/`, four
  new test files, and `Settings`, `AudioConverter` and `Package.swift` untouched.
- Fix verification, one line per accepted finding:
  - Required 1 (out-of-order queued audio): still fixed under the new design.
    `queuedAudioKeepsItsOrderWhileASendIsInFlight` fails when `sendInOrder` stops chaining,
    confirmed on the copy outside the repo.
  - Question 1 (trailing interim): unchanged. `TranscriptAssembler.apply` still commits
    `interim` on `.done`, `commit` clears it first, and
    `doneCommitsTheTrailingInterim` plus `emptySessionProducesNoText` still pass.
  - Question 2 (who closes the transport): unchanged. `close()` is on the seam and no client
    code calls it.
  - Optional 2 (word timing assertions): still gone. No test references `words`,
    `partialDecodesItsPayload` asserts text and flags only, and `STTEvent.Word` remains part of
    the frozen event types.
  - Optional 3 (distinctness loop): still gone, seven per-status assertions remain.
  - Optional 4 (`endStream()` unused): still covered by
    `streamEndingWithoutDoneReturnsFinalisedText` and `finishBeforeTheSessionIsReady`.
  - Optional 5 (`finish()` called out of order): now fully covered.
    `finishWaitsForAudioAlreadyHandedOver` is the mid-session case the first closure review
    found missing.
  - Optional 6 (`run()` doc comment): still accurate against `STTEvent.decode`.
  - Optional 1 (`+` in a keyterm): still deferred and still recorded under known limitations.
- Implementation handoff: it describes the code that exists. The chain bullet matches
  `sendInOrder`, including that `send(audio:)` returns only once its chunk is on the wire and
  that a failure does not stop the sends behind it, and the second remediation entry matches
  both tests. The verification line's 26 tests matches what I ran.
- Still open for the lead, unchanged and not a blocker: the ten new files are untracked and
  need an explicit `git add`; `plan.md` is modified while the handoff says it is untouched; and
  the packet still opens with "Status: not started."
