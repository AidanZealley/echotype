# Workstream 1: Protect finishing with outcome tests

Status: accepted.

## Task packet

### Outcome

`DictationOperationTests` cover every behavior the redesign must preserve by asserting observable outcomes against today's code: inserted text, frame order on the fake transport, trace contents, presentation reached, and which resources were released. The harness is clearly smaller than today's. No production code changes.

### Scope

- Rewrite the `Harness` in `Tests/EchoTypeAppTests/DictationOperationTests.swift` around three controllable fakes: a transport that records frames and lets the test emit events, a manual clock, and a capture stream the test feeds and finishes. Add a gate only where a test must hold a specific suspension (a stalled binary send, closing send or capture drain, a suspended final revision, or a suspended insertion).
- Write one test per item in the specification's "Behavior to preserve" list that `DictationOperation` can observe. Parameterise only where cases share every step but one input.
- Keep existing operation tests that still assert outcomes, adapted to the new harness. Delete tests that pin internal task ordering or presentation call counts without protecting a listed behavior.
- Keep the readiness tests (Select an input) and Test-mode test, since they protect accepted behavior.

Suggested, not required: express timing as "advance the clock by N" and "finish the capture stream" rather than as sequences of gate openings.

### Non-goals

- Changing any file under `Sources/`.
- Testing `SessionMachine` or `STTClient` directly. Those tests belong to workstream 2.
- Coverage targets, permutation matrices or retry paths beyond the listed behavior.

### Initial ownership

- `Tests/EchoTypeAppTests/DictationOperationTests.swift` only.

### Required seams

- Drive `DictationOperation` only through `Dependencies`, `run()`, `commit()`, `cancel()`, `captureFailed(_:)`, `microphoneReady()` and its published presentation. Do not reference `SessionMachine` internals, `onFinishing`, `onAbort` or `enterFinishing`. Workstream 2 must be able to rewrite those without touching this file.

### Acceptance criteria

- Each "Behavior to preserve" item observable at the operation level has a named test asserting its outcome. The handoff lists the mapping from item to test.
- No test asserts internal call order, task identity, or a presentation count, except where the order is the behavior (closing frames after the last audio chunk).
- The harness has fewer gates and counters than today's 11 gates and about 20 counters.
- `DictationOperationTests` pass 20 consecutive runs, with no flaky timing.
- The full deterministic suite passes.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter DictationOperationTests
for i in $(seq 20); do XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter DictationOperationTests > /dev/null || echo "failed run $i"; done
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
git diff --check
```

## Implementation handoff

- Base commit: `256f3bb6cb543292dee7f6e23cf0a72d73b23feb`
- Outcome: `DictationOperationTests` rewritten around outcomes (inserted text and Return, frames on the fake transport, trace, presentation reached, capture released). 19 tests, 30 cases, against unchanged production code. The harness replaces the 16 named gates (13 harness, 3 transport) and 19 counters, flags and hooks with one `Points` recorder: fakes record named points, tests wait for a point or hold one to keep the operation suspended there. Remaining harness state: frames, insertions, presented phases, focus and inserted destination, and the final capture chunk. Holding a point is the one way to keep the operation suspended: a stalled binary or closing send, a stalled capture drain (`.captureStop`), the final revision, insertion and the clipboard boundary, and capture start and key fetch in the startup tests. The file is 586 lines against 518: fewer concepts and more behavior covered, not fewer lines.
- Files changed: `Tests/EchoTypeAppTests/DictationOperationTests.swift`
- Behavior-to-test mapping:
  - Stop, reply request and hard cap drain audio, including the final partial chunk, before `finalize` and `audio.done`: `drainsBeforeClosing` (`stop`, `replyRequest`, `hardCap`). An earlier chunk is held in the transport while finishing begins. The `stop` case calls `commit()` twice, so the exact frames and insertions also cover a repeated stop finishing and inserting once. The hard cap advances by `operation.settings.hardCap`.
  - The finishing deadline starts when finishing begins, covers `transcript.done`, and fails with committed text on expiry: `finishingDeadline` (`expires` true or false). Nine seconds of listening come first, so the deadline is measured from the stop.
  - A stalled binary send, closing send or capture drain ends within the deadline and releases capture: `stalledFinishing` (`binarySend`, `closingSend`, `captureStop`).
  - Readiness: no `transcript.created` within five seconds fails the session, and held audio is bounded: `readinessFailure` (`noCreated`, `backlog`). Held audio sent in order once ready is protocol behavior that the operation can't observe deterministically: whether the pump hands a chunk over before or after `created` is a race. Existing `STTClientTests` cover it ("No audio is sent before transcript.created arrives", "Audio handed over during the flush stays behind what was already queued").
  - Capture overflow and send failures preserve committed text and never send Return: `captureOverflow`, `sendFailure` (`binarySend`, `closingSend`, using reply-request words).
  - Escape cancels through drain and final revision; after the clipboard boundary insertion owns completion: `escapeWhileFinishing` (`captureStop`, `closingSend`, `revision`), `cancellationBeforeClipboard`, `insertionOwnsCompletion`.
  - The destination is captured fresh when finishing begins: `finishingDestinationIsFresh` (`available` true or false). Focus differs at the advisory probe, at stop, and after finishing has begun (closing send held); insertion must target the focus at stop.
  - An unrequested `transcript.done` or socket close while listening is `closed`, with committed text: `unrequestedEnd` (`disconnect` true or false).
  - Test mode keeps its five-second timer and has no overlay, insertion or trace: `microphoneTest`.
  - Kept accepted behavior outside the list: `destinationReadiness`, `microphoneReadinessPrecedence`, `cancelledBeforeRun`, `cancelledStartup`, `captureFailureDuringStartup`, `finalRevisionDeadline`, `recovery`.
- Decisions: Deleted `cancelledDuringCleanup`. From the operation's view it is identical to `cancelledBeforeRun`, since `run()` starts after `cancel()`. Folded `orderedCompletion` (including its repeated stop), `hardCapFlushesTail` and `binaryFailure` into the parameterised drain and send-failure tests. Dropped call-count totals (captures, opens, destination totals) and kept only the advisory-probe throttle counts that the readiness tests protect. `destinationReadiness` now waits for `.finishing` before checking that probes stop, so it doesn't depend on `commit()` publishing synchronously. `ManualClock.advance` still awaits the due wake-up. The hard-cap trigger advances in its own task because today's hard-cap wake-up awaits the drain. `ManualClock.armed` opens on the first schedule, so the readiness timeout test waits until the deadline is armed. The capture fake passes `.captureStop` in its own task and finishes its stream afterwards, so holding that point stalls the drain like any other hold. The transport answers `audio.done` with `transcript.done` unless told to withhold it. Its `close()` releases held sends, as a real socket does. A mutation check (removing the drain wait in `enterFinishing`) failed `drainsBeforeClosing`, `stalledFinishing` and `sendFailure`. Sources were restored and are unchanged. A second mutation check (moving `captureDestination()` from `enterFinishing` to just before `dependencies.insert`) failed both `finishingDestinationIsFresh` cases; Sources were restored and `git diff --stat -- Sources` is empty.
- Verification: `swift test --filter DictationOperationTests` passed (19 tests). 20 consecutive filtered runs: no failures. Full deterministic suite: 80 + 61 tests passed. `git diff --check`: clean.
- Known limitations: Held audio sent in order once ready is not asserted at the operation level (see the mapping). `readinessFailure` relies on the session's first clock schedule being the readiness deadline. `stalledFinishing` and `finishingDeadline` rely on capture stopping or the closing frames being sent only after the finishing deadline is armed, which the specification's `finish()` order preserves.
- Specification drift: none.

## Independent review

- Reviewer: independent reviewer, fresh session (Claude Opus 5.5, Claude Code)
- Verdict: Changes required (R1, R2). Everything else meets the packet: no file under `Sources/` changed, the seam is respected (`grep` finds no `SessionMachine`, `onFinishing`, `onAbort`, `enterFinishing` or `trigger(` in the file), and all targeted verification passed. `--filter DictationOperationTests`: 19 tests passed. 20 consecutive filtered runs: no failures. Full deterministic suite: 80 + 61 tests passed. `git diff --check`: clean. Mutation checks, each restored with `git diff --stat -- Sources` empty afterwards: arming the finishing deadline at `startedAt` instead of `clock.now` fails `finishingDeadline(expires: false)`; inserting with Return on reply-request failures fails both `sendFailure` cases.
- Required findings:
  - R1. `finishingDestinationIsFresh` does not assert "captured fresh when finishing begins", only "not the advisory probe". Focus changes before `commit()` and never after, so a destination captured any time up to insertion passes. Evidence: mutating `DictationOperation` to drop `captureDestination()` from `enterFinishing` and call it immediately before `dependencies.insert` left all 19 tests passing. This is the line workstream 2 moves (finish step 2), and the regression is user visible: text switching apps during Transcribing would paste into the new app instead of being skipped as `.changed`. Fix: hold a point after finishing has begun (for example `.closingSend`), change `focusedDestination` to a third destination, release, and assert the inserted destination is the one focused at stop.
  - R2. Folding `orderedCompletion` into `drainsBeforeClosing` dropped its double `commit(); commit()` and its "inserts once" outcome, without a reason in the handoff. The packet keeps existing outcome tests. Workstream 2 replaces today's layered idempotence (`canCommit` after a synchronous `.finishing` publish, `trigger` guarding `ending`, the once-only `closingSend`) with a `finish()` started "at most once" from three places, and `commit()` may no longer publish `.finishing` synchronously. A repeated Opt+D is the realistic way to start it twice. Fix: call `commit()` twice in the `.stop` case of `drainsBeforeClosing`; the exact `frames` and `insertions` assertions then cover it.
- Optional observations:
  - O1. The gate and counter reduction is mostly a renaming. `Points` gives each of the 14 `Point` cases a counter, an arrival gate and an optional hold, and the file grew from 518 to 592 lines. Tests no longer hand-drive interleavings, which is the real gain, so this meets the criterion in spirit. Trimming points that only one test uses would make the reduction real.
  - O2. Tests mix `h.stall(at:)` and `h.points.hold(_:)` for the same purpose. `stall` exists only to send `.captureStop` to `drainStalls`. A single spelling (either always `stall`, or `drainStalls = true` set directly) would be one concept fewer.
  - O3. Several regressions show up as a hang until the one-minute suite time limit rather than as a failed expectation: a deadline armed after the drain in `stalledFinishing`, a readiness timeout longer than five seconds in `readinessFailure`, and a hard cap above 300 seconds in `drainsBeforeClosing(.hardCap)`. This is acceptable for a safety net but slow to diagnose. `300` could read `Settings().hardCap` so a settings change fails loudly instead of hanging.
  - O4. `releaseCapture` is called unconditionally at the end of `run()`, so `count(.captureRelease) == 1` holds whenever the task returns. The real "releases capture" evidence in `stalledFinishing` and `escapeWhileFinishing` is that the task returns at all. The assertion is harmless but adds little.
  - O5. Accepted the handoff's limitation that held pre-handshake audio sent in order is not asserted at the operation level. The race is real (no observable point marks a chunk as queued rather than sent), and `STTClientTests` cover it. Workstream 2 should keep those tests, since it changes `STTClient` for `sendClosing()`.
- Questions:
  - Q1. `readinessFailure(.noCreated)`, `stalledFinishing` and `finishingDeadline` depend on the first clock schedule being the readiness deadline and on the finishing deadline being armed before capture stops. The specification's `reschedule()` and `finish()` order preserve both. Should the plan record them as a contract for workstream 2, so a reordering there is treated as drift rather than a test edit?

## Resolution

- Finding dispositions: R1 accepted and fixed: a mutation moving destination capture to insertion time now fails `finishingDestinationIsFresh`. R2 accepted and fixed: the repeated stop is the realistic way workstream 2's once-only `finish()` could start twice. O2 accepted and fixed: one way to hold a point. O3 accepted for the hard-cap literal only, now read from settings. The rest of O3 (other regressions surface as a suite time-limit hang rather than a failed expectation) deferred: acceptable for a safety net. O1 deferred: the harness replaces 16 bespoke gates and 19 counters with one generic point recorder and no hand-driven interleavings, which meets the criterion; the line count grew because coverage grew. O4 rejected: the assertion is harmless and the real evidence (the task returning) is already present. O5 agreed: in-order delivery of held audio stays covered by `STTClientTests`. Q1 answered yes: the ordering assumptions are recorded as a contract for workstream 2 in `plan.md`.
- Simplification/deletion pass: remediation removed `stall(at:)` and `drainStalls`. `cancelledDuringCleanup` deleted as a duplicate of `cancelledBeforeRun`; `orderedCompletion`, `hardCapFlushesTail` and `binaryFailure` folded into parameterised tests. No `Sources/` changes.
- Final verification (lead, at the remediated head): `--filter DictationOperationTests` 19 tests passed; 20 consecutive filtered runs, no failures; full deterministic suite 80 + 61 tests passed; `git diff --check` clean.

## Closure review

- Verdict: Accepted. R1: `finishingDestinationIsFresh` now holds `.closingSend` after `commit()`, moves focus to a third destination and asserts insertion targets the focus at stop. Mutation check (dropping `captureDestination()` from `enterFinishing` and calling it just before `dependencies.insert`) failed both cases; Sources restored and `git diff --stat -- Sources` is empty. R2: the `.stop` case of `drainsBeforeClosing` calls `commit()` twice and the exact `frames` and `insertions` assertions cover a single finish and insertion. O2: `stall`/`drainStalls` are gone; `h.points.hold(_:)` is the one spelling. O3: the hard-cap trigger advances by `operation.settings.hardCap`; no `300` literal remains. No release-blocking defects in the fixes. Targeted verification: `--filter DictationOperationTests` 19 tests passed; 20 consecutive filtered runs, no failures; full deterministic suite 80 + 61 tests passed; `git diff --check` clean.
- Remaining required findings: none.
