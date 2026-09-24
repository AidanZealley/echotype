# Workstream 1: Live session seam

Status: accepted.

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

- Base commit: `d0139bc`
- Outcome: `SessionMachine` owns the session's one `TranscriptAssembler` and publishes
  `snapshots` in place of `states`. `STTClient` keeps only the protocol. The controller
  mirrors `snapshot.state`. Dictation behaves as before.
- Files changed:
  - `Sources/EchoTypeCore/SessionMachine.swift`: `Snapshot`, `snapshots`, the assembler,
    `publish()`. `conclude` no longer awaits the client, because the text is already in hand.
    Remediation: every write to `ending` goes through `decide(_:)`, where the first ending
    wins (O1).
  - `Sources/EchoTypeCore/STT/TranscriptAssembler.swift`: `settled` and `provisional` in place
    of `interim`. Remediation: `settled`'s doc comment, and `Snapshot.settled`'s, no longer
    promise append-only text (O3).
  - `Sources/EchoTypeCore/STT/STTClient.swift`: no assembler; `run()` returns `Void`, `text`
    is gone.
  - `Sources/EchoTypeApp/DictationController.swift`: iterates `snapshots`.
  - `Tests/EchoTypeCoreTests/SessionMachineTests.swift`: `StateLog` became `SnapshotLog`
    (its `next()` and `rest()` still return state transitions, so the existing tests read
    unchanged); four new tests.
  - `Tests/EchoTypeCoreTests/TranscriptAssemblerTests.swift`: `interim` assertions now read
    `settled`/`provisional`; one new composition test.
  - `Tests/EchoTypeCoreTests/STTClientTests.swift`: dropped assertions on the client's text,
    and deleted `streamEndingWithoutDoneReturnsFinalisedText`, which only tested client
    assembly. The machine's socket failure and unsolicited `done` tests cover that survival.
  - `docs/decisions/0007-known-gaps.md`: removed the live text item.
- Decisions:
  - The machine applies every decoded event to its assembler before the pause logic runs,
    in every state, so the partial `finalize` resolves into reaches the text during
    `finalizing`. The outcome's text is `transcript.text`.
  - `publish()` builds the snapshot from the current state and assembler and yields only if
    it differs from the last one published. That drops the 1 Hz empty heartbeat partials and
    `transcript.created`, and means a frame that both resumes from `paused` and changes the
    text produces one snapshot, not two.
  - The client's `run()` task is started and not awaited. Its failures always reach the
    machine as the frame or socket error behind them, and the machine no longer needs its
    text.
  - `Snapshot` has a public memberwise init so tests compare whole snapshots.
  - Remediation (O1): the first decided ending wins. `decide(_:)` records an ending only if
    none is set, and it replaces every direct assignment (`cancel`, `observe`'s `done` and
    `error`, the finalize send failure, the finalize timeout, `conclude`). Closing the real
    socket does not discard frames `URLSessionWebSocketTransport` has already yielded, so a
    `transcript.done` or `error` read after Escape used to overwrite `.cancelled` and insert
    text. It now leaves the cancel standing and the outcome is `.nothing`. The same rule stops
    a late frame overturning a timeout or a finalize send failure, and a send failure
    overturning a `done` that arrived while `finalize` was being sent.
- How `is_final` runs compose in the recorded frames: the fixtures and live test do not
  record a live sequence, but the retired live protocol record (`git show
  bc0fea8^:docs/echotype-core/implementation/03-live-protocol-validation.md`, "Recorded
  sequence" and "`is_final` versus `speech_final`") does. Within an utterance every partial
  carries only the run since the last `is_final` boundary. An `is_final` frame carries that
  run, rewritten into its final form (for example numerals), and starts the next run. The
  `speech_final` frame resends the whole utterance: passage 1's three `is_final` runs of 18,
  15 and 13 characters, joined with single spaces, are exactly its 48 character
  `speech_final` text. `speech_final` always implies `is_final`; the endpoint sometimes sends
  an `is_final` frame and a twin identical but for `speech_final`; `is_final` can arrive with
  empty text. So the assembler appends each non-empty `is_final` run to the current
  utterance, replaces the provisional tail with each non-final partial, and on `speech_final`
  commits the frame's text and discards the runs, which is what prevents duplication.
- Snapshot API:
  - `SessionMachine.snapshots: AsyncStream<SessionMachine.Snapshot>`, `nonisolated`.
  - `SessionMachine.Snapshot { state: State; settled: String; provisional: String }`.
    `settled` is committed segments plus the current utterance's `is_final` runs, joined
    with single spaces, rendered solid. The utterance's `speech_final` text replaces its runs
    wholesale, so `settled` is not guaranteed to only grow at its end; do not treat it as
    append-only. `provisional` is the run since the last `is_final`,
    rendered dimmed after `settled`. Either can be empty.
  - Published on every state transition and every change to either text, never twice in a
    row with the same value. The first snapshot is `listening` with empty text. The stream
    finishes when `run()` returns; the last snapshot is `idle` (or `cancelled`) and still
    carries the final text. During `finalizing` snapshots keep arriving as `finalize`
    resolves the tail.
  - `TranscriptAssembler.settled` and `.provisional` replace `.interim`; `.text` is still
    the only inserted text.
- Verification: `swift build` clean; `timeout 120 swift test --disable-xctest` 39 tests
  passed (run four times); `swift-format lint --recursive Sources Tests Package.swift` clean.
  No live session was run. After remediation: `swift build` clean, `timeout 120 swift test
  --disable-xctest` 39 tests passed, `xcrun swift-format lint --recursive Sources Tests
  Package.swift` exit 0.
- Known limitations or external checks:
  - `swift-format` is not at `~/.local/bin/swift-format` on this Mac as the README says; I
    ran `xcrun swift-format`.
  - After a failure, `settled` can show `is_final` runs of the unfinished utterance that
    `Outcome.failed(text:)` does not insert, since only committed segments are inserted. The
    overlay shows slightly more than lands at the caret in that case. That follows the packet
    and was left untested on purpose.
  - The app change is compile-checked only.
  - The O1 fix has no test. `ScriptedTransport` cannot deliver a frame after close:
    `close()` ends it and drops its queue, and `emit` after that is ignored. Making the
    scenario deterministic would also need a frame queued but not yet taken when `cancel()`
    runs, and the fake wakes its consumer on every `emit`, so ordering the two would mean
    adding a gate the real transport does not have. The fix was left to reading and the
    existing cancel, timeout and failure tests.
- Specification drift: the `transcript.done` fallback from 0003 now commits the whole
  uncommitted utterance (its settled runs plus the provisional tail) rather than only the
  latest partial. 0003 records that the old fallback would commit a fragment; the new one
  cannot, and the fallback has never fired against the live endpoint. The existing test for
  it passes unchanged. 0003's Consequences line is now stale and needs updating when this
  milestone retires into decision records. Otherwise none: the recorded frames did answer how
  `is_final` runs compose, so the fallback rendering was not needed.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5.5), 2026-09-24.
- Verdict: accept. No required findings. Every acceptance criterion is met.
- Checks run: `swift build` clean; `timeout 120 swift test --disable-xctest` 39 tests passed,
  four runs; `xcrun swift-format lint --recursive Sources Tests Package.swift` exit 0, no
  output (`~/.local/bin/swift-format` is absent, as the handoff says).
- Criteria:
  1. Met. `states` is gone; `snapshots: AsyncStream<Snapshot>` carries `state`, `settled`
     and `provisional`.
  2. Met. `SessionMachine.transcript` is the only assembler in production code. `Outcome`
     reads `transcript.text`, snapshots read `settled` and `provisional`. `STTClient` holds
     no text.
  3. Met. The four new `SessionMachineTests` cover superseded provisional text, two
     `speech_final` segments (including the recorded twin), pause cycles and the final
     snapshot. The existing `socketFailureKeepsFinalisedSegments` covers socket failure
     through the machine. All drive `ScriptedTransport` and `TestClock`, which predate this
     workstream, and assert on `Snapshot` and `Outcome`, which the overlay reads. No test
     exercises a fake invented here or asserts storage details.
  4. Met, and the reasoning holds against the retired record (`git show
     bc0fea8^:docs/echotype-core/implementation/03-live-protocol-validation.md`). Passage 1's
     `is_final` runs of 18, 15 and 13 characters plus two joining spaces are exactly the 48
     character `speech_final`. The record also shows each non-final partial's `start` moving
     to the previous `is_final` boundary within a passage, which independently supports
     "a partial carries only the run since the last `is_final`". Passages 2 and 3 have one
     run each, followed by an identical `speech_final` twin, which the model also handles.
     `is_final` on empty text adds nothing. One caveat: the record elides text, so "joined
     runs equal the `speech_final` text" rests on character counts. That is the best
     available evidence and the packet forbids a live session to find out more.
  5. Met. `STTClientTests` changed only by removing reads of the client's text and deleting
     one test that only covered client assembly. Survival is still covered through the
     machine by `socketFailureKeepsFinalisedSegments`, `serverErrorKeepsFinalisedSegments`
     and `unsolicitedDoneDoesNotCommit`. `SessionMachineTests` changed only in the log
     helper that read `states`. The `TranscriptAssemblerTests` edits replace `interim`
     reads.
  6. Met by reading. `DictationController.run` mirrors `snapshot.state` and still starts the
     pump on the first snapshot, which is still `listening`. Text-only snapshots arrive at
     about 1 Hz and write the same `state` again. The Swift 6.4 `@Observable` macro
     generates `shouldNotifyObservers`, so an equal value does not invalidate the menu. This
     workstream adds no panel, window or event tap code, so key or main status and event
     tap work are unaffected.
  7. Met.
- Required findings: none.
- Optional observations:
  - O1, pre-existing and outside the diff: a buffered `error` or `transcript.done` frame
    after `cancel()` overrides the cancel and inserts text. `cancel()` sets `ending =
    .cancelled` and closes the transport. `URLSessionWebSocketTransport.messages()` yields
    into an unbounded `AsyncThrowingStream`, so frames already received are still delivered
    to `readUntilEnd`. `observe` then assigns `ending` unconditionally on `.done`
    (`.closed`, because the state is `cancelled` rather than `finalizing`) and on `.error`
    (`.failed`). `conclude` then produces `.failed(text:)`, `settle` walks `cancelled` to
    `inserting` to `idle`, and `DictationController.finish` inserts the text after the
    user pressed Escape. This is rare, since an unsolicited `done` or a server error has to
    land in the gap. `ScriptedTransport.close()` drops its queue, so the suite cannot show
    it. The contract freezes `cancel()`'s meaning and routes later defects to escalation.
    The fix is one guard (`guard ending == nil` before those assignments, or before
    `observe`) in a file this workstream owns. I recommend the lead fix it here or add it
    to 0007.
  - O2, simplification: `STTClient.run()` now exists only to notice `transcript.created`
    and flush held audio. That costs a second decode of every frame, the `RelayTransport`
    class, and an unawaited `Task` whose result is discarded. The machine already decodes
    `.created`, so it could call a client method directly, and `RelayTransport` and the
    client's read loop could go. The packet offered its mechanics only as a suggestion, but
    this goes further than it asked, and it touches `STTClientTests` and 0004's wording.
    Worth doing when the seam is next opened, not a blocker. The unawaited task is correct
    as written: the relay never throws, the client throws only on an `error` event or an
    undecodable frame, and the machine sees both itself. `relay.finish()` in `conclude`
    ends the task.
  - O3, contract wording: `Snapshot.settled` is documented as "text the model will not
    revise", but the joined `is_final` runs are replaced wholesale by the `speech_final`
    text, and nothing proves the two are identical (see the caveat under criterion 4).
    Workstream 3 should not treat `settled` as append-only, for example by animating only a
    suffix. A line in the handoff's Snapshot API would stop that assumption.
- Questions:
  - Q1: the `transcript.done` fallback now commits `utterance + provisional` where it used
    to commit `interim`. For a tail that ends in an `is_final` run with no `speech_final`,
    the old code inserted only the last run and the new code inserts the whole utterance.
    That contradicts "What gets inserted does not change" and 0003's Consequences, although
    it is strictly better and never observed live. The handoff records it as drift. The
    lead should decide whether to accept it and log it in the plan's drift log. I recommend
    accepting. The lead should also decide whether 0003 is updated now or at retirement.
    0003 is a source-of-truth record, so leaving it stale means later readers are told the
    fallback commits a fragment.

## Resolution

- Finding dispositions:
  - O1: promoted to Required by the lead and fixed. Escape must insert nothing, the fix is
    small and in an owned file, and it restores `cancel()`'s intended meaning rather than
    changing it. Every assignment of `ending` now goes through `decide(_:)`, so the first
    decided ending wins; a late `done` or `error` frame can no longer overturn a cancel, a
    timeout or a send failure. No test: `ScriptedTransport` drops its queue on close and
    delivers frames immediately, so showing a frame buffered behind `cancel()` would need a
    gate the real transport does not have. Verified by reading.
  - O2: rejected. Folding `STTClient`'s read loop and `RelayTransport` into the machine goes
    beyond the packet, which keeps the client's protocol jobs where they are. The current
    code is correct. Worth revisiting the next time the seam opens.
  - O3: accepted as wording. The `Snapshot` and `TranscriptAssembler.settled` doc comments
    and the handoff's Snapshot API now say that `speech_final` replaces an utterance's
    settled runs wholesale, so `settled` is not append-only.
  - Q1: accepted as drift and logged in plan.md. The `done` fallback now commits the whole
    unfinished utterance (settled runs plus provisional tail) rather than the latest run.
    It is simpler than preserving the old fragment behaviour, never fires under the observed
    protocol, and cannot insert a fragment. 0003's Consequences line is out of date; it is
    outside this workstream's ownership, so the drift log flags it for the decision records
    written at retirement.
- Simplification/deletion pass: the implementation removed the client's assembler, its
  `text` accessor, the machine's `clientTask` and `finalText()`, and the await in
  `conclude`. Remediation replaced six scattered `ending` assignments with one rule.
- Final verification: `swift build` clean; `timeout 120 swift test --disable-xctest` 39
  tests passed; `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.

## Closure review

- Reviewer: closure review agent (Claude Opus 5.5), 2026-09-24.
- Verdict: accept once R1 is done. The code is ready to close. R1 is a missing drift log row.
- Checks run: `swift build` clean; `timeout 120 swift test --disable-xctest` 39 tests passed;
  `xcrun swift-format lint --recursive Sources Tests Package.swift` exit 0.
- Accepted findings, verified:
  - O1: fixed. `ending` is written only in `decide(_:)`, which keeps the first ending. It is
    called from `cancel`, `observe` (`done` and `error`), the finalize send failure, the
    finalize timeout and `conclude`. `readUntilEnd` returns `ending ?? ...` on every path, so
    the `conclude(ending)` argument always matches the stored ending. After `cancel()`, a
    buffered `done` or `error` frame still goes to `observe`, but `decide` ignores it. The
    loop then returns `.cancelled` and the outcome is `.nothing`. A frame read after a cancel
    can still update the text and publish a `cancelled` snapshot. That snapshot is harmless
    because nothing is inserted. The fix adds no defects: `beginFinalizing` still closes the
    transport after a send failure, which ends the loop even when an earlier `done` has
    already won. The missing test is justified by the fake transport's limitations, as the
    Resolution explains.
  - O3: fixed. `Snapshot.settled`, `TranscriptAssembler.settled` and the handoff's Snapshot
    API all say that `speech_final` replaces the runs wholesale and that `settled` is not
    append-only.
  - Q1: not done as recorded. The Resolution says the `done` fallback drift was logged in
    plan.md, but the plan's Decision and drift log has no row for it. The only workstream 1
    row covers assembler ownership. That row is the only place that flags 0003's stale
    Consequences line for retirement.
- Remaining required findings:
  - R1: add the Q1 drift row to `docs/overlay/implementation/plan.md`'s Decision and drift
    log. It should say that the `transcript.done` fallback now commits the whole unfinished
    utterance rather than the latest run, and that 0003's Consequences line needs updating at
    retirement. It affects workstream 1. Documentation only; no code change.
- Lead disposition: R1 resolved at acceptance by adding the drift row to plan.md's decision
  and drift log. Accepted.
