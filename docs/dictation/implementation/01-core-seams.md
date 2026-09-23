# Workstream 1: Core seams

Status: accepted.

## Task packet

### Outcome

`EchoTypeApp` can import `EchoTypeCore`. A session that finalises against an endpoint
that never answers ends with a failure instead of hanging forever. A handshake rejected
with 401 arrives at the caller as `STTError.unauthorized`, proven against the live
endpoint rather than assumed.

### Scope

**The finalizing deadline.** `SessionMachine.beginFinalizing` sends `finalize` and
`audio.done` and then waits on `transcript.done` with no pending wake-up, because it
cancels the clock on the way in. If the endpoint accepts the closing messages and never
replies, `run()` never returns and the app has no way to notice.

Give `finalizing` a bounded wait on the injected clock. When it expires, conclude with
`Outcome.failed(text:error:)` carrying whatever the assembler had committed, on the same
reasoning the specification already uses for a dropped socket: a visibly truncated
transcript beats losing the speech.

The specification measured the segment boundary landing 2.73 to 2.80 seconds after the
last reported word, with the frame in hand around 3.0 seconds, from inserted digital
silence. A real room is slower. Choose a value with that margin in mind, put the reason
in a comment, and put it beside `silenceTimeout` and `hardCap` in `Settings` if it wants
tuning later.

**The 401 path.** `URLSessionWebSocketTransport.sessionError(from:)` reads
`task.response` to turn a rejected handshake into a typed `STTError`. Whether a
`URLSessionWebSocketTask` populates `response` on a rejected upgrade is an assumption
nothing has tested. Prove it with one live call carrying a deliberately wrong key. No
valid credential is needed.

If the call cannot run, because there is no network or the endpoint answers in some
third way, record what happened. A documented unknown is worth more than a green test
asserting the current behaviour of a code path nobody exercised.

**The package dependency.** Add `EchoTypeCore` to the `EchoTypeApp` target's
dependencies. One line, and it is here so that no later workstream touches
`Package.swift`.

### Non-goals

- Any transcript text, interim text or elapsed time crossing the `SessionMachine` seam.
  The overlay milestone designs that against its own requirements. Adding it now is
  guessing.
- Retrying or reconnecting a failed session.
- Changing `SessionMachine`'s existing public surface, the pause and resume rules, or the
  hard cap.
- Anything in `EchoTypeApp`.

### Initial ownership

- `Package.swift`
- `Sources/EchoTypeCore/SessionMachine.swift`
- `Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift`
- `Sources/EchoTypeCore/Settings.swift`, only if the deadline becomes a setting
- `Tests/EchoTypeCoreTests/`

### Required seams

The deadline's expiry must be reachable in a test through the existing `SessionClock`
protocol, the way `SessionMachineTests` already drives silence and the hard cap. If it
cannot be, the design is wrong rather than the test.

Workstream 3 consumes `SessionMachine` exactly as it stands after this workstream.

### Acceptance criteria

1. A session that triggers finalisation and receives nothing further ends with
   `Outcome.failed`, carrying the text committed before the trigger, within the chosen
   deadline on the injected clock. A test pins this.
2. A session that receives `transcript.done` normally is unaffected, and the existing
   `SessionMachineTests` still pass unchanged.
3. The deadline does not fire after the session has concluded, and does not leave a task
   running past `run()` returning.
4. The live 401 result is recorded in the handoff: either `STTError.unauthorized` reached
   the caller, or what did instead.
5. `swift build` succeeds with `EchoTypeApp` depending on `EchoTypeCore`.

### Targeted verification

```bash
swift build
swift test
```

Add the focused test for criterion 1 to `Tests/EchoTypeCoreTests/SessionMachineTests.swift`.

For criterion 4, one throwaway call against `wss://api.x.ai/v1/stt` with an invalid key.
Write it as a scratch script or a test guarded off by default; do not leave a test in the
suite that needs the network to pass.

```bash
swift-format lint --recursive Sources Tests Package.swift
```

Skip the lint if swift-format is not installed and say so in the handoff.

## Implementation handoff

- Base commit: `1ae5dda`
- Outcome: Done. `finalizing` waits on the injected clock and fails instead of hanging,
  `EchoTypeApp` depends on `EchoTypeCore`, and the 401 path was probed live: the mechanism
  works, but a bad key is not a 401.
- Files changed:
  - `Package.swift`: `EchoTypeApp` gains its `EchoTypeCore` dependency.
  - `Sources/EchoTypeCore/Settings.swift`: new `finalizeTimeout`, defaulting to 8 seconds.
  - `Sources/EchoTypeCore/SessionMachine.swift`: bounded wait in `finalizing`, new private
    `Ending.timedOut`, and `observe(_:)` ignores speech in partials once the session is no
    longer listening or paused.
  - `Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift`: comment only, recording
    what the live probe showed about `task.response` and about the endpoint's status codes.
  - `Tests/EchoTypeCoreTests/SessionMachineTests.swift`: one test for the deadline, scripted
    with the trailing partial a `finalize` resolves into before the endpoint goes silent.
- Decisions:
  - **8 seconds.** How long a forced `finalize` takes has not been measured. The nearest
    measured figure is the specification's ~3s budget for endpointing to close a segment on
    its own, and forcing the segment closed should be no slower than that. Eight leaves wide
    margin for a real room and a slow network, while a user who pressed Opt+D against a
    stuck endpoint still sees an error rather than an app that appears stuck. It sits in
    `Settings` beside `silenceTimeout` and `hardCap`.
  - **Scheduled, not cancelled.** `beginFinalizing` no longer calls `clock.cancel()` on the
    way in; the `clock.schedule` at the end replaces the pending silence or hard cap
    wake-up, which is the protocol's documented behaviour. The old wake-up can still fire
    while `client.finish()` is awaited, and `deadlineReached` already rejects that because
    `isActive` is false in `finalizing`. On the `client.finish()` failure path the session
    ends immediately and `conclude` cancels the clock, so nothing is scheduled there.
  - **Speech bookkeeping only while streaming.** A partial's `heardSpeech`, `lastSpeechAt`,
    pause/resume and `reschedule()` only mean anything while listening or paused, so
    `observe(_:)` guards that branch on `isActive`. Without it, the trailing partial that
    arrives after `finalize` reached `reschedule()`, which cancels the clock in `finalizing`
    and destroyed the deadline. With the guard, `reschedule()` is only reached while
    listening or paused.
  - **A distinct `Ending.timedOut` rather than `.failed(some Error)`.** `conclude` maps
    `.failed` through `SessionError(_:)`, which stringifies any non-`STTError` into
    `.socket`, so reusing it would have produced a nested, unreadable message. `.timedOut`
    maps directly to `.failed(text:error: .socket("the endpoint never answered the finalize
    request"))`, keeping the committed segments on the same reasoning the specification uses
    for a dropped socket.
  - **The deadline cannot outlive the session.** `conclude` already calls `clock.cancel()`,
    which cancels `SystemClock`'s pending task, and `finalizingDeadlineReached` re-checks
    `ending == nil, state == .finalizing` before acting. Expiry sets `ending` and closes the
    transport, which is exactly how `cancel()` unblocks the message loop.
- Verification:
  - `swift build`: clean. `swift test`: 33 tests, all passing, in one suite. The suite's
    exit code was 0, so `--disable-xctest` was not needed.
  - The revised test was checked against the defect it pins: with the `isActive` guard in
    `observe(_:)` removed, `timeout 60 swift test --filter finalizingWithoutAnAnswerTimesOut`
    hung and was killed (exit 124). With the guard restored it passes. The test fails only
    by hanging, which is the defect it pins.
  - `swift-format` is not installed on this machine, so the lint step was skipped. Nothing
    was installed to run it.
  - The live 401 probe ran twice as throwaway binaries compiled outside the repository, both
    since deleted. Nothing in the test suite touches the network. First probe: the real
    `URLSessionWebSocketTransport` against `wss://api.x.ai/v1/stt` with an invalid key, whose
    `messages()` stream threw `STTError.badRequest`. Second probe: the same handshake done
    by hand, printing `closeCode: 0` (`.invalid`) and `status: 400`, then the same request
    over HTTPS with `curl` to read the body.
- Known limitations or external checks:
  - Criterion 4's answer is that `sessionError(from:)` works and its premise is wrong.
    `URLSessionWebSocketTask` does populate `task.response` on a rejected upgrade and leaves
    `closeCode` at `.invalid`, so the HTTP status reaches the caller as a typed `STTError`;
    that assumption is now proven rather than assumed. But `api.x.ai` answers a well-formed
    but incorrect key with **400**, body `{"code":"Client specified an invalid argument",
    "error":"Incorrect API key provided. You can obtain an API key from
    https://console.x.ai."}`. It returns 401 only when no credentials are presented at all
    (`"No credentials presented. [WKE=unauthenticated:no-credentials]"`). So a wrong key
    reaches the caller as `STTError.badRequest`, not `.unauthorized`.
  - Workstream 3 renders `Outcome.failed` in the menu bar. A user with a bad Keychain entry
    will see whatever `.badRequest` is worded as, so that wording should not say "bad
    request"; both statuses mean "your key is wrong" in practice.
  - The 8 second deadline has never been reached against the real endpoint. Only a session
    where xAI accepts `finalize` and then goes silent would exercise it, and nothing observed
    so far does that.
- Specification drift: the specification's "Errors: 400 bad request, 401 bad key" is wrong
  about 401. Observed live, a bad key is 400 and 401 means no credentials at all. The status
  mapping in `STTError(httpStatus:)` is unchanged, since it is faithful to HTTP; only the
  meaning the specification attaches to each status is off. Recorded in a comment on
  `URLSessionWebSocketTransport.sessionError(from:)`.

## Independent review

- Reviewer: independent review agent, fresh session, base commit `1ae5dda` with the
  workstream's changes uncommitted.
- Verdict: **Changes required.** The deadline is cancelled by the first frame the endpoint
  sends after `finalize`, which is the frame the specification says to expect, so the hang
  the workstream exists to remove is still reachable. Criteria 2, 4 and 5 are met; criterion
  3 holds; criterion 1 is met only for the case the new test scripts.
- Verification run:
  - `swift build`: clean.
  - `swift test`: 33 tests in 1 suite, all passing, exit code 0. `--disable-xctest` was not
    needed, matching the handoff.
  - `swift-format`: not installed on this machine (`which swift-format` finds nothing), so
    the lint was skipped, as the handoff records. Nothing was installed.
  - One throwaway test file was added under `Tests/EchoTypeCoreTests/` to reproduce the
    required finding and deleted again. The working tree is as the implementation agent left
    it; no implementation file was edited.

### Required findings

**R1. A trailing partial after `finalize` cancels the deadline, and the session hangs
forever again.**

`observe(_:)` handles `.partial` the same way in every state
(`Sources/EchoTypeCore/SessionMachine.swift:219-226`): once `isSpeech` is true it sets
`lastSpeechAt` and calls `reschedule()`, with no check that the session is still listening.
`reschedule()` (`SessionMachine.swift:252-263`) treats `.finalizing` as one of the states
with no wake-up and calls `clock.cancel()` before returning. So the very first partial
carrying text or `speech_final` that arrives after `beginFinalizing` has scheduled the
deadline destroys it, and nothing schedules another. The message loop is then suspended on
`transport.messages()` with no pending wake-up, which is precisely the state the packet's
Scope section describes.

This is the normal shape of a finalisation rather than an edge case. The specification says
the final text is "every `speech_final` segment concatenated in order, plus whatever trailing
partial the `finalize` resolves into" (`docs/specs/echotype-v1.md:303-304`), so a partial
between `finalize` and `transcript.done` is the expected traffic, not a surprise. The
handoff's "Scheduled, not cancelled" reasoning accounts for `deadlineReached` firing during
`client.finish()`, which is correct, but not for `reschedule()` being reachable from the
read loop while the session is in `finalizing`.

Reproduced. A throwaway test in the existing harness, identical to
`finalizingWithoutAnAnswerTimesOut` except for one added frame:

```swift
await session.trigger()
#expect(await log.next() == .finalizing)
// The trailing partial the finalize resolves into.
await transport.emit(Fixture.partial("said and done then some", isFinal: true, speechFinal: true))
await clock.advance(by: 8)
let outcome = await running.value
```

`swift test --filter trailingPartial` was killed by `timeout 90` without producing a result,
the same hang the handoff describes when it checked the new test for false greenness.

**R2. The new test scripts the one arrival order that cannot happen in practice, so it
reports green over R1.**

`finalizingWithoutAnAnswerTimesOut`
(`Tests/EchoTypeCoreTests/SessionMachineTests.swift:309-329`) triggers and then emits
nothing at all before advancing the clock. Against a live endpoint that accepted `finalize`,
at least one trailing partial is expected before it goes quiet, and that is the case that
fails. The test is well built otherwise: it drives the existing `ScriptedTransport`,
`TestClock` and `StateLog` rather than inventing a double, it asserts the outcome and the
committed text rather than internal state, and it was checked against a mutant. Its problem
is coverage, not construction. Whatever fixes R1 should pin the trailing-partial ordering,
since that is the ordering the fix is for.

### Optional observations

**O1. The deadline is armed after `client.finish()` returns, so a send that never returns is
still unbounded.** `beginFinalizing` awaits `client.finish()`
(`SessionMachine.swift:281-289`) and only then schedules
(`SessionMachine.swift:293`). `client.finish()` sends two text frames through
`sendInOrder`, which awaits a `URLSessionWebSocketTask.send` with no deadline of its own. A
socket that has stalled without failing leaves `beginFinalizing` suspended and no wake-up
scheduled. The packet's criterion is about an endpoint that accepts the closing messages and
then says nothing, which this does not contradict, so this is out of scope. Arming the
deadline before the send rather than after would cover both shapes for no extra machinery,
if the fix for R1 touches this code anyway.

**O2. `Escape` does nothing once the session is finalizing.** `cancel()` guards on `isActive`
(`SessionMachine.swift:173`, `:186-188`), which is false in `finalizing`, so a user who
presses Escape against a silent endpoint waits out the full `finalizeTimeout` and then gets
a failure carrying text they asked to discard. This is pre-existing behaviour and changing
it is an explicit non-goal of this packet, but the new deadline makes the wait long enough
to be noticed for the first time. Worth carrying into the overlay milestone rather than
fixing here.

**O3. Criterion 3 is argued rather than pinned.** The reasoning is sound: `conclude` calls
`clock.cancel()` before anything else (`SessionMachine.swift:310-311`), `SystemClock.cancel`
cancels the pending `Task`, and `finalizingDeadlineReached` re-checks `ending == nil,
state == .finalizing`. I could not construct a path that violates it. `TestClock` cannot
observe a leaked wake-up, so no test would add much here, and I do not think one is worth
writing.

### Questions

**Q1. Is eight seconds the number, given what it is measuring?** The `Settings` comment and
the handoff both justify 8 as "roughly three times" the specification's 3 second budget, but
that budget is for when a segment closes on its own through `endpointing`
(`docs/specs/echotype-v1.md:287-293`). A forced `finalize` is a different operation and the
recorded live sessions would show how long it actually takes. Eight seconds is defensible
either way, and it is a `Settings` field, so this is a question about the comment's reasoning
rather than the value. Lead's call whether it is worth correcting.

**Q2. Does the drift note belong in the plan as well as in the code comment?** The 401
finding is real, well evidenced and recorded in two places
(`Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift:72-77` and the handoff's
Specification drift field). The README asks the lead to put drift in the plan's decision and
drift log too, and workstream 3 needs it when it words the menu bar's error text, per the
handoff's own limitation note. Flagging so it is not lost at acceptance.

## Resolution

- Recovery: this lead took over after the previous lead was interrupted while triaging. The
  uncommitted diff was on base `1ae5dda` (equal to HEAD), and every change was within the
  packet's Initial ownership. `Settings.swift` is assigned to workstream 3 in the plan's
  ownership table, but this packet allows it "only if the deadline becomes a setting", which it
  did. The edit adds `finalizeTimeout` and touches nothing workstream 3 owns there. Implementation
  and independent review were complete and documented, so work resumed at triage. `swift build`
  was clean and 33 tests passed before remediation.
- Finding dispositions:
  - R1, accepted. Fixed by limiting a partial's speech bookkeeping to an active session
    (`guard isActive, isSpeech(partial)` in `observe(_:)`), so a trailing partial during
    `finalizing` can no longer cancel the finalize deadline.
  - R2, accepted. `finalizingWithoutAnAnswerTimesOut` now emits the trailing partial after the
    trigger and then goes silent, and expects the committed text including that partial. It hangs
    without the R1 fix.
  - O1, deferred. A `send` that stalls without failing is outside criterion 1, which covers an
    endpoint that accepts the closing messages. Arming the deadline before `client.finish()` would
    race the `catch` path's `ending` assignment, so it is not free.
  - O2, deferred to the overlay milestone. Escape during `finalizing` is an explicit non-goal
    here. Workstream 3 should know that a stuck finalize now takes up to `finalizeTimeout` to
    surface, and Escape does not shorten it.
  - O3, rejected, as the reviewer suggested. `TestClock` cannot observe a leaked wake-up, and the
    guard in `finalizingDeadlineReached` plus `conclude`'s `clock.cancel()` carry criterion 3.
  - Q1, accepted as a comment fix. The `finalizeTimeout` comment now says the forced `finalize`
    latency is unmeasured and uses the endpointing figure only as the nearest bound. The value stays
    8 seconds.
  - Q2, accepted. The 400/401 drift is in the plan's decision and drift log for workstream 3.
- Simplification/deletion pass: the remediation replaced the test rather than adding a second
  one. `reschedule()`'s cancel branch for non-active states is now unreachable from `observe`,
  but stays because the switch has to be exhaustive and removing it buys nothing.
- Closure note on criterion 3, applied by the lead after closure: `beginFinalizing` now checks
  `guard ending == nil` before arming the deadline. Without it, a session that concluded while
  the closing sends were in flight could leave a no-op wake-up sleeping past `run()`. This is
  the one-line fix the closure named, and nothing else changed.
- Final verification: `swift build` is clean. `swift test` passes 33 tests with exit code 0.
  `swift-format` is not installed, so the lint did not run.

## Closure review

- Verdict: **Accepted.**
- Remaining required findings: none.
- Verification: `swift build` clean. `swift test` passes 33 tests in 1 suite, exit code 0.
  `swift-format` is not installed, so the lint was skipped.
- R1 fixed. `observe(_:)` now guards on `isActive, isSpeech(partial)`, so a partial arriving
  in `finalizing` never reaches `reschedule()` and cannot cancel the finalize deadline.
  `reschedule()` is now reached only from `begin()`, `deadlineReached()` while active, and
  active partials.
- R2 fixed. `finalizingWithoutAnAnswerTimesOut` emits the trailing partial after the trigger,
  then advances by `finalizeTimeout` and expects `.failed(text: "said and done then some",
  .socket)`. Mutation check in a scratch copy outside the repository: with the `isActive`
  guard removed, `timeout 60 swift test --filter finalizingWithoutAnAnswerTimesOut` hung and
  was killed (exit 124). The test pins the defect.
- Q1 fixed. The `finalizeTimeout` comment in `Settings.swift` now says forced `finalize`
  latency is unmeasured and treats the endpointing figure as the nearest bound only.
- Q2 is not yet in `plan.md`'s decision and drift log. The lead adds it at acceptance, so
  this does not block, but the Resolution's "is in the plan" is true only once that entry is
  written.
- Non-blocking note on criterion 3: `beginFinalizing` schedules the deadline after awaiting
  `client.finish()` without re-checking `ending`. If the loop ends (`transcript.done`, a server
  error or a close) while the closing sends are in flight and both sends still succeed,
  `conclude` has already cancelled the clock and the deadline is armed afterwards. The only
  effect is one sleeping task of up to `finalizeTimeout` whose fire is a no-op, because
  `finalizingDeadlineReached` checks `ending == nil`. The window is narrow and the effect
  harmless, so this is not release-blocking. A `guard ending == nil` before the `schedule`
  would close it.
