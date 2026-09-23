# Workstream 4: Session machine

Status: accepted. The session machine is built on the behaviour workstream 3 observed rather
than on the specification's predicted silence signal; see the drift note at the end of the
Implementation handoff. Review found no Required finding, the lead promoted four Optional
observations, and closure accepted the remediation with none remaining.

## Task packet

### Outcome

A session state machine implementing the specification's interaction model, driven by
an injected clock so every timeout is tested deterministically. Nothing is ever
committed by a timer except the hard cap.

### Scope

- States `idle`, `listening`, `paused`, `finalizing`, `inserting` and `cancelled`, per
  the specification's state machine section.
- The listening and paused transition in both directions. Ten seconds without new
  transcript activity moves to `paused`; any new partial moves back to `listening`.
  Audio keeps streaming in both, since pausing is a display state.
- The no-speech path. If nothing is ever said, the same ten second setting cancels the
  session silently rather than producing an empty insertion.
- The hard cap. Ten minutes ends the session and commits whatever accumulated.
- Commit entered only by an explicit trigger or the hard cap, sending `finalize` then
  `audio.done` and waiting for `transcript.done`.
- Cancellation discarding everything.
- Socket failure mid-session emitting the finalised segments accumulated so far
  alongside the error, rather than discarding them.
- An injected clock so tests advance time without waiting.

### Non-goals

- The overlay, the menu bar, settings persistence and anything that draws. This
  workstream emits state; it does not render it.
- Pasteboard insertion and `CGEventPost`. Those are macOS-side.
- The event tap and hotkey handling.
- Local voice activity detection or RMS thresholds. The specification deliberately
  drives pausing from server events instead. Only reach for local detection if
  workstream 3 proved the server signal unusable, and then escalate rather than
  deciding alone.
- Making the timeouts configurable beyond the `Settings` fields workstream 1 defined.

### Initial ownership

Creates and owns `Sources/EchoTypeCore/SessionMachine.swift` and its tests.

Consumes workstream 2's event types and assembler without changing them. A defect in
those is an escalation.

### Required seams

Consumes the frozen event types, `TranscriptAssembler` and `Settings`. Emits state
transitions and a final result for a macOS layer to render and insert.

### Acceptance criteria

1. `swift build`, `swift test --disable-xctest` and `swift-format lint` all pass.
2. Ten seconds of quiet moves `listening` to `paused`; a new partial moves it back.
3. Several pause and resume cycles in one session accumulate text correctly and in
   order.
4. A session where nothing is ever said cancels silently at ten seconds and produces
   no insertion.
5. The hard cap ends a ten minute session and commits the accumulated text.
6. No path other than an explicit trigger or the hard cap reaches `finalizing`.
7. Cancelling from `listening` or from `paused` discards everything.
8. A trigger arriving before `transcript.created` is handled without losing the
   session or emitting an empty result.
9. A socket error mid-session yields the accumulated finalised segments and the error.
10. A `transcript.done` resolving to empty text produces no insertion.
11. Every timeout is exercised through the injected clock. No test sleeps.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift-format lint --recursive Sources Tests
```

New focused tests covering criteria 2 to 10. Assert on observable transitions and
emitted results rather than on internal field names, so the tests survive a refactor.

If workstream 3 recorded behaviour contradicting the specification, implement what
workstream 3 observed and record the difference as drift.

## Implementation handoff

- Base commit: `bb8b43b`
- Outcome: `SessionMachine` implements the specification's state machine over an injected
  clock. It owns the socket for the life of a session, reads it, drives workstream 2's
  `STTClient` over it, and ends in exactly one outcome: `insert(text)`, `nothing`, or
  `failed(text:error:)` carrying whatever was finalised before the socket died. Pausing is
  driven by the signal workstream 3 observed, not the one the specification describes. All
  eleven acceptance criteria are met. Eight tests cover criteria 2 to 10; criterion 6 is
  covered by the transition logs those tests assert, which never reach `finalizing`
  without a trigger or the cap.
- Files changed: `Sources/EchoTypeCore/SessionMachine.swift` and
  `Tests/EchoTypeCoreTests/SessionMachineTests.swift`, both new. Nothing else was touched.
- Decisions:
  - **The clock seam schedules a callback rather than sleeping.** `SessionClock` is
    `now` plus one replaceable wake-up: `schedule(at:fire:)` and `cancel()`. A session only
    ever needs the sooner of the silence timeout and the hard cap, so there is no timer
    identity on either side. The test clock's `advance(by:)` runs each deadline it passes and
    awaits the session's reaction, so a timeout's effect is in place by the time `advance`
    returns and the test asserts on it with no sleep, poll or yield. A `sleep(until:)` seam
    would have looked equally injectable and raced, because the woken timer task resumes after
    the test has already moved on. `SystemClock` is the real implementation, a cancellable
    `Task.sleep`.
  - **The session reads the socket and relays every message to `STTClient`.** The client
    exposes only the final text, and pausing needs the partials, so the machine decodes each
    frame for its own state and hands the raw message to a private `RelayTransport` the client
    reads. That keeps the client's audio queueing, send ordering and assembly untouched, which
    the packet requires, without a second assembler in the machine.
  - **Speech means a partial with non-empty text, or a `speech_final`.** Workstream 3 observed
    empty partials arriving at about 1 Hz throughout a silence, so their arrival is not
    activity. Recorded as drift below.
  - **`inserting` is entered only when there is text.** An empty `transcript.done` goes
    `finalizing` to `idle`, so the macOS layer is never handed an empty string. A session that
    kept text through a socket failure still passes through `inserting`, because the
    specification says to insert those segments alongside the error.
  - **A socket that closes cleanly while finalising counts as finalised.** It has said
    everything it is going to say. A close before that is `failed`, so a dropped connection
    still yields the accumulated segments rather than nothing.
  - **`SessionError` is `stt(STTError)` or `socket(String)`.** A `Sendable`, `Equatable`
    outcome cannot carry `any Error`, and the overlay needs the 401 case distinguishable from
    a dropped connection.
  - Timers are cancelled the moment `finalizing` or `cancelled` is entered, so the hard cap
    cannot fire into a session that is already ending.
- Verification: `swift build` clean, `swift test --disable-xctest` passing 35 tests in 0.07s
  including the eight new ones, and `swift-format lint --recursive Sources Tests` silent. The
  suite was run ten times in a row to check the concurrency in the tests is deterministic
  rather than lucky; no flake. Tests assert on the transition stream and the returned outcome,
  never on the machine's fields, and `state` is private for that reason.
- Known limitations or external checks:
  - `SystemClock` is not covered, because testing it means sleeping and criterion 11 forbids
    it. It is roughly fifteen lines with no branching beyond cancellation.
  - `send(audio:)` is a guarded pass-through to `STTClient`, whose own tests cover delivery
    and ordering. Asserting delivery here would mean asserting on when the client's task has
    drained the relay, which is exactly the racy test the packet warns against.
  - Nothing bounds the wait for `transcript.done` after `finalize`. Workstream 3 saw it arrive
    within 10ms and the server close 2s later. A hung endpoint would leave the session in
    `finalizing`; if that matters it belongs to the macOS layer's session supervision, not
    here.
  - The relay means the client sees `transcript.created` one task hop after the machine does.
    A trigger inside that window drops queued audio, which is `STTClient`'s documented
    behaviour for a stop before the session is ready, and is criterion 8's case.
- Specification drift: the specification's silence detection is wrong as written and the
  machine deliberately does not implement it. Lines 85-87 say "no new partials means silence,
  new partials mean speech resumed", and lines 382-385 restate it for the `listening` and
  `paused` transition. Workstream 3 observed partials arriving at about 1 Hz with `"text":""`
  throughout a silence, and nothing at all for 2 to 3 seconds while the endpoint decides where
  an utterance ends, so the documented detector sees activity during silence and silence
  during speech. The machine uses a partial with non-empty text, or a `speech_final`, and
  ignores `start` and `duration`. Entering `paused` therefore lags the end of speech by about
  3s and leaving it lags resumed speech by 0.7 to 2.3s, both comfortable against ten seconds.
  This is already in the plan's drift log from workstream 3; the wording in the specification
  still needs changing, which is Aidan's call between this workstream and workstream 5.

### Remediation pass

The lead promoted Optional 1, 3, 4 and 5 to Required and declined the rest. All four are
applied; nothing else in the machine changed, and no file outside the two this workstream
owns was touched.

- **An unsolicited `transcript.done` no longer commits** (Optional 1). `observe(.done)` now
  resolves to `.finalised` only while `finalizing`, and to `.closed` otherwise, so a `done`
  with no trigger or hard cap behind it ends the session as `.failed(text:error:)` carrying
  the accumulated text. The specification's rule that text reaches the target app only on an
  explicit trigger or the cap outranks the fact that the observed endpoint never sends one
  early. `.closed`'s message is now "the transcript ended before the session did", which
  covers both routes into that ending.
- **A late `cancel()` or `trigger()` is rejected** (Optional 3). `conclude` records the
  ending it was handed before it suspends at `await finalText()`, and the three guards that
  were `state == .listening || state == .paused` are now one `isActive`, which is that state
  check plus `ending == nil`. `ending` was already the field that says the outcome is
  decided, so the fix is the existing state carrying the condition rather than a new flag,
  and the guards read as one idea in one place.
- **The transport is closed before the client is awaited** (Optional 4). `conclude` now
  closes, then awaits, so a client suspended in a send on a dead socket is unblocked rather
  than waited on.
- **Two tests added** (Optional 5, plus one for Optional 1). `serverErrorKeepsFinalisedSegments`
  drives an `error` frame mid-session and asserts the outcome is `.failed` with the text
  finalised before it and a `.stt(.server(...))` error, and that the transitions are
  `inserting` then `idle`. `unsolicitedDoneDoesNotCommit` covers the behaviour change above,
  matching the outcome's shape rather than the error's message string, and asserts no
  `finalize` frame went out. Both run on the injected clock with no sleep, yield or poll.

Declined and not implemented: Optional 2, 6, 7 and both Questions.

Verification: `swift build` clean, `swift test --disable-xctest` green with 37 tests in 0.06s,
and `swift-format lint --recursive Sources Tests` silent. The suite was run eight times with
no flake. `git status` shows only the two owned files and this packet.

## Independent review

- Reviewer: fresh review agent, independent of the implementation agent.
- Verdict: **Accept.** All eleven acceptance criteria are met and no Required finding was
  found. Checks run from a clean tree at base `bb8b43b` with only the two new files present:
  `swift build` clean in 1.9s; `swift test --disable-xctest` green, 35 tests in one suite, exit
  0; `swift-format lint --recursive Sources Tests` silent, exit 0. The suite was run eight more
  times end to end with no flake and no variation in duration beyond 0.04s, which matches the
  handoff's claim about the concurrency in the tests.

  Criteria verified individually. 2 and 3 by `quietPausesAndSpeechResumes` and
  `pauseCyclesAccumulateText`; the first is a genuinely discriminating test, because an
  implementation that counted an empty partial as activity would push the deadline to 15 and
  the test would hang on `log.next()` until the suite's one minute limit rather than pass. 4 by
  `nothingSaidCancelsSilently`, which also asserts no `finalize` went out. 5 by `hardCapCommits`,
  which walks the clock through both deadlines in one `advance`. 6 by the exact-log assertions in
  the pause, cancel and no-speech tests: each asserts the complete remaining transition list, so
  a stray `finalizing` would fail them, and the implementation has exactly two call sites for
  `beginFinalizing()`. 7 by the parameterised cancel test over both source states. 8, 9 and 10 by
  their named tests. 11 by inspection: no sleep, yield or poll anywhere in the file, and every
  timeout runs through `TestClock.advance`, which fires each deadline it passes and awaits the
  reaction before returning.

  The drift is correctly implemented rather than merely described. `isSpeech` keys off non-empty
  text or `speech_final` and ignores `start` and `duration`, which is what workstream 3's Findings
  section recommends, and the drift is already in the plan's log from workstream 3, so nothing
  needed re-recording. The relay keeps `STTClient`'s queueing, send ordering and assembly
  untouched, so the packet's "consumes workstream 2 without changing them" boundary holds, and
  `git status` confirms nothing outside the two new files was touched. No Apple framework import
  beyond Foundation.

- Required findings: none.
- Optional observations:
  1. **An unsolicited `transcript.done` inserts text the user never asked to commit.**
     `observe(_:)` sets `ending = .finalised` for `.done` regardless of state
     (`SessionMachine.swift:206-207`). If the endpoint ever sent `transcript.done` while the
     session is `listening`, `conclude` would produce `.insert(text)` and `settle` would emit
     `inserting`, pasting into the user's editor without a trigger. That is the one outcome the
     specification's "Nothing is ever inserted by a timer. Text reaches the target app only when
     the user presses Opt+D or clicks the overlay" rules out. Not reachable against the observed
     server: workstream 3 recorded that `transcript.done` never arrived before the client sent
     `audio.done`, in either session, so this is defence against an undocumented server change
     rather than a live defect. Treating a `done` outside `finalizing` as `.closed` would close
     it in one line. Left Optional because the evidence is against it happening; the lead may
     reasonably promote it, since the cost of being wrong is text in someone's editor.
  2. **Audio handed over before `run()` reaches `begin()` is dropped rather than queued.**
     `send(audio:)` guards on `state == .listening || state == .paused`
     (`SessionMachine.swift:154`), and `state` is `.idle` until `begin()` runs. `STTClient` was
     built specifically to hold audio that arrives before the session is ready, so "the first
     words of an utterance are not lost to the connection handshake"
     (`STTClient.swift:5-8`), and the guard discards exactly that audio for the window between
     constructing the machine and its `run()` task being scheduled. The window is short and the
     macOS layer will almost certainly start `run()` before the tap, but the guard silently
     undoes a property workstream 2 was deliberately given. Allowing `.idle` through, or
     starting the session in `init`, would restore it.
  3. **A late `cancel()` is accepted but does not prevent the insertion.** `conclude` suspends at
     `await finalText()` (`SessionMachine.swift:271`) with `state` still `.listening` or
     `.paused` on the socket-failure path. A `cancel()` landing in that window passes its guard,
     emits `.cancelled`, and then `settle(text:)` emits `inserting` and `idle` behind it, so the
     overlay sees cancelled followed by an insertion. The window is one task hop against a human
     pressing Escape, so this is robustness rather than a live defect. Entering a terminal state
     before the await would reject the late call, the way `beginFinalizing` already does by
     setting `.finalizing` before its first suspension.
  4. **`transport.close()` runs after the await that may need it.** `conclude` calls
     `relay.finish()`, awaits the client task, and only then closes the socket
     (`SessionMachine.swift:270-272`). If the client is suspended inside a real
     `URLSessionWebSocketTask.send` on a socket that has already failed, `finalText()` waits on a
     send that closing would have unblocked. Narrow, since the failure path that gets here
     usually means the send has already thrown, and reordering the two lines costs nothing.
  5. **The server `error` event path is untested at this level.** `observe(.error)` maps an
     `error` frame to `.failed(.stt(.server(...)))` (`SessionMachine.swift:208-209`), and nothing
     in `SessionMachineTests` exercises it. `socketFailureKeepsFinalisedSegments` covers a
     transport throw, which is a different branch, and `STTClientTests` covers the client's own
     handling rather than the machine's. The missing case is the one where the accumulated text
     must survive alongside a typed server error, which is criterion 9's spirit if not its
     letter. `Fixture.error` already exists, so the test is three lines.
  6. **Nothing checks that audio still streams while paused.** The packet's scope says audio
     keeps streaming in both states, and `send(audio:)` does allow `.paused`, but
     `ScriptedTransport.send(binary:)` discards frames and no test asserts on the guard. The
     handoff's reason for not asserting delivery is sound, since that would mean asserting on
     when the client's task has drained the relay. Asserting that `send(audio:)` while paused
     does not throw would be weak. Noted as a visible-by-inspection gap rather than a
     recommendation to add a ceremonial test.
  7. On the failure paths the machine goes `listening` or `paused` straight to `inserting`,
     skipping `finalizing`. That edge is not in the specification's diagram, but the
     specification's instruction to insert the accumulated segments after a socket failure does
     not route through `finalizing` either, so this reads as correct rather than as drift. Worth
     knowing for whoever writes the overlay, which will see `inserting` without a preceding
     `finalizing`.

- Questions:
  1. **Is the relay the seam the packet intended?** Required seams names "the frozen event types,
     `TranscriptAssembler` and `Settings`", not `STTClient`. The implementation consumes
     `STTClient` and reaches the assembler through it, which costs a private `RelayTransport`,
     a second decode of every frame, an extra task, and the one-task-hop window the handoff
     documents under limitations. The alternative, owning a `TranscriptAssembler` directly and
     talking to the transport, would delete the relay but would duplicate the client's pre-
     `created` audio queueing, send ordering and `finalize`/`audio.done` framing, which is worse.
     The choice looks right to me and the handoff argues it explicitly. Flagging it only because
     it is the one place the implementation reads the seam more broadly than the packet wrote it,
     and that is the lead's call rather than mine.
  2. **Does the paused overlay land where the specification means?** `isSpeech` accepts
     `speech_final`, and workstream 3 measured that frame arriving about 3s after speech actually
     stops, so `lastSpeechAt` is reset 3s late and the overlay dims at roughly 13s of real quiet
     rather than 10s. The handoff discloses this and workstream 3 calls it comfortable against a
     ten second threshold, which I agree with. Accepting `speech_final` is also the right
     defensive choice, because a short utterance can close in the endpointing burst without a
     text-bearing interim before it. The question is whether the specification's "after ten
     seconds without new transcript activity" should be restated to say what the ten seconds is
     measured from. That is the same wording decision workstream 3 left to Aidan between this
     workstream and workstream 5, so it needs no code change here.

## Resolution

- Finding dispositions: no Required findings were raised. Of the seven Optional observations the
  lead promoted four and declined three, and answered both Questions without a code change.
  - **Promoted, Optional 1.** An unsolicited `transcript.done` could insert text the user never
    triggered. The specification's rule that text reaches the target app only on an explicit
    trigger or the hard cap outranks the fact that the observed endpoint never sends `done`
    early, and the cost of being wrong is text in somebody's editor. A `done` outside
    `finalizing` now resolves to the `closed` ending, so the accumulated text still survives but
    as `failed` rather than as an insertion.
  - **Promoted, Optional 3.** A `cancel()` landing while `conclude` was suspended passed its
    guard and then had `settle` emit `inserting` behind the `cancelled` transition, so pressing
    Escape at the wrong instant still pasted. `conclude` now records its ending before it
    suspends, and the three duplicated state guards collapsed into one `isActive` property that
    reads that field. No new flag: `ending` already meant the outcome was decided.
  - **Promoted, Optional 4.** `conclude` now closes the transport before awaiting the client, so
    a client suspended in a send on a dead socket is unblocked rather than waited on. Free, and
    it removes a hang path.
  - **Promoted, Optional 5.** The machine's own handling of a server `error` frame was untested;
    the similarly named passing test belongs to `STTClientTests` and covers a different branch.
    `serverErrorKeepsFinalisedSegments` now drives an `error` frame mid-session and asserts the
    accumulated text survives alongside a typed `.stt(.server(...))`, which is criterion 9's
    intent. The remediation agent added `unsolicitedDoneDoesNotCommit` alongside it to lock the
    first change; accepted, since it protects the invariant rather than the implementation.
  - **Declined, Optional 2.** Audio handed over before `run()` reaches `begin()` is dropped
    rather than queued. The window is between constructing the machine and its `run()` task being
    scheduled, and the documented usage starts `run()` first. Letting `.idle` through would admit
    audio to a session that does not exist yet, to protect a caller ordering the macOS layer
    controls. Out of scope for this packet.
  - **Declined, Optional 6.** No test asserts audio still streams while paused. The only
    observable is delivery through the relay, and asserting on when the client's task has drained
    it is exactly the racy, implementation-coupled test the packet warns against. The guard
    admits `.paused` by inspection; a test that only proves `send(audio:)` does not throw would
    be ceremony. The reviewer agreed.
  - **Declined, Optional 7.** The failure paths going straight to `inserting` without a preceding
    `finalizing` is correct: the specification routes a socket failure's accumulated segments to
    insertion without finalisation. Recorded for the overlay author, no change.
  - **Question 1, answered, no change.** Consuming `STTClient` rather than `TranscriptAssembler`
    directly reads Required seams more broadly than it is written, but the packet's binding
    constraint is consuming workstream 2 without changing it, which holds. The alternative
    duplicates the client's pre-`created` queueing, send ordering and closing framing, which is
    more machinery, not less. The relay stands.
  - **Question 2, answered, no change.** Accepting `speech_final` as activity dims the overlay at
    roughly 13s of real quiet rather than 10s, because that frame lands about 3s late. Workstream
    3 measured it and called it comfortable against a ten second threshold, and accepting it also
    catches a short utterance that closes without a text-bearing interim before it. The open item
    is specification wording, already in the plan's drift log and already Aidan's call between
    this workstream and workstream 5. No new escalation.
- Simplification/deletion pass: the remediation collapsed three copies of the
  `state == .listening || state == .paused` guard into one `isActive` property rather than adding
  a flag beside `ending`, and widened two doc comments to match the new `closed` semantics.
  Nothing was added that an acceptance criterion does not need; no wrapper, alias or
  compatibility path was introduced to preserve the first implementation.
- Final verification: from a clean tree at base `bb8b43b` with only the two owned files and this
  packet modified. `swift build` clean, `swift test --disable-xctest` green with 37 tests in one
  suite in about 0.07s, `swift-format lint --recursive Sources Tests` silent. The suite was run
  repeatedly with no flake and no sleep, yield or poll anywhere in the tests.

## Closure review

- Verdict: **Accept.** All four promoted findings are fixed in the code, none of the fixes
  breaks a previously passing behaviour or an acceptance criterion, and the tree is clean at
  base `bb8b43b` with only the two owned files and this packet touched. `swift build` clean in
  2.0s; `swift test --disable-xctest` green, 37 tests in one suite, exit 0; `swift-format lint
  --recursive Sources Tests` silent, exit 0. The suite was run eight more times end to end with
  no flake, between 0.06s and 0.09s.

  Fixes verified individually.

  **Optional 1.** `observe(.done)` is now `ending = state == .finalizing ? .finalised : .closed`
  (`SessionMachine.swift:221`), so only a `done` behind a trigger or the hard cap can reach
  `.insert`. The three tests that finalise deliberately (`pauseCyclesAccumulateText`,
  `hardCapCommits`, `triggerBeforeTheSessionIsReady`) all enter `finalizing` before emitting
  `Fixture.done`, and `emptyTranscriptInsertsNothing` does too, so criteria 3, 5, 8 and 10 take
  the `.finalised` branch exactly as before. The `.closed` branch already existed for a stream
  that ends without a `done`, and its outcome shape is unchanged, so nothing that passed before
  now fails. `unsolicitedDoneDoesNotCommit` locks the new route and matches on the outcome's
  shape rather than the message string.

  **Optional 3.** The three duplicated guards are one `isActive`
  (`SessionMachine.swift:180-182`), and `conclude` sets `self.ending` before its only suspension
  (`SessionMachine.swift:285`). The added `ending == nil` term only ever rejects input the old
  guard would have accepted in states where the outcome is already decided: `observe` setting
  `.closed` or `.failed` while still `listening` or `paused`, and `conclude` waiting on the
  client. Every other writer of `ending` also leaves `listening` and `paused`, so the term is
  redundant there rather than restrictive. Nothing legitimate is rejected: `begin()` enters
  `listening` before `run()`'s first suspension, so a trigger before `transcript.created` still
  passes, and `deadlineReached`'s no-speech path calls `cancel()` while `ending` is still nil,
  so criteria 4 and 7 are unaffected.

  **Optional 4.** `conclude` closes then awaits (`SessionMachine.swift:290-291`). This cannot
  lose text on any path that finalises: `client.finish()` queues behind every send already
  handed over, so by the time `transcript.done` arrives the client has nothing in flight and
  `run()` returns the assembled text from the already-buffered relay stream, which `close()` on
  the real socket does not touch. The only window where the reorder changes anything is a
  `.closed` or server-`error` ending landing while `run()` is still inside its
  `transcript.created` audio flush: the close would fail that send, `run()` would throw early,
  and `finalText()` would fall back to `client.text`, the assembler's text so far. That window
  is the first moments of a session, when the flush holds only the audio that arrived before
  `created` and no segment has been finalised yet, so there is no text to lose. Weighed against
  the hang it removes, the reorder is right.

  **Optional 5.** `serverErrorKeepsFinalisedSegments` drives a real `error` frame through the
  machine and asserts `.failed(text: "half a sentence", error: .stt(.server(...)))` plus the
  `inserting`, `idle` transitions, which is the branch `socketFailureKeepsFinalisedSegments`
  does not cover. Both new tests run on the injected clock; no sleep, yield or poll anywhere in
  the file, so criterion 11 still holds.

- Remaining required findings: none.
- Note for the overlay author, no change asked for here. Optional 1 reclassifies an unsolicited
  `transcript.done` rather than suppressing the insertion: `.closed` still calls `settle`, which
  emits `inserting` when there is text, and `.failed(text:)` is the outcome the specification
  tells the macOS layer to insert (`docs/specs/echotype-v1.md:391`). So the text still reaches
  the target app, now labelled a failure and routed through the same path as a dropped socket.
  That matches the Resolution's wording, "still survives but as `failed` rather than as an
  insertion", and it is the behaviour the specification already sanctions for a session that
  ends without a trigger, so it is not a defect. It does mean the promoted fix changes how the
  event is classified rather than whether text is pasted.
