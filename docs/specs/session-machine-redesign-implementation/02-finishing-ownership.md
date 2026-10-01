# Workstream 2: Invert finishing ownership

Status: accepted, 2026-10-01.

## Task packet

### Outcome

The specification's Design is implemented. `SessionMachine` never calls into its owner. `DictationOperation` sequences finishing in one `finish()` routine. One `reschedule()` computes the next deadline from state, and `transcript.done` uses the `closingStarted` rule. Behavior is unchanged, as shown by workstream 1's tests passing without weakened assertions and by a signed smoke check.

### Scope

- `SessionMachine`:
  - Remove `onFinishing`, `onAbort`, `finishingEffect`, `abortTask`, `finishingTask` and `closingSend`.
  - Expose `run()`, `send(audio:)`, `beginFinishing()`, `sendClosing()`, `cancel()`, `fail(_:)` and `snapshots`, as the specification defines them.
  - On the hard cap, call `beginFinishing()` internally and publish the `finalizing` snapshot.
  - Replace the scattered `clock.schedule` calls with one `reschedule()` covering readiness, silence and hard cap, paused hard cap, and the finishing deadline.
  - Apply the `closingStarted` rule for `transcript.done`.
  - Remove `hasRun` and the early-ending path in `run()` if they are no longer needed. Keep them only if a listed behavior requires them, and say why in the handoff.
- `STTClient`: adjust only what `sendClosing()` needs, such as waiting for readiness when audio is held.
- `DictationOperation`:
  - Add one `finish()` routine, started at most once from the stop hotkey, reply-request detection, or a `finalizing` snapshot it didn't request. It runs the specification's four steps in order.
  - After `session.run()` returns, stop capture, cancel the pump and the finish routine, then join both.
  - Remove `enterFinishing` and `abortCapture`, now that the session no longer calls them.
- Update `SessionMachineTests` and `STTClientTests` for the new API. Keep tests of protocol and transcript behavior, and delete tests that only pin removed task ordering.
- Update decision 0024 to describe finishing ownership after this change.
- Run gate G1.

### Non-goals

- Clipboard, destination, reading, MCP, `TranscriptAssembler`, `Reviser`, settings or presentation changes.
- Changing `SessionClock` beyond what one `reschedule()` needs.
- New configuration, retries, logging or observation hooks.

### Initial ownership

- `Sources/EchoTypeCore/SessionMachine.swift`
- `Sources/EchoTypeCore/STT/STTClient.swift`
- `Sources/EchoTypeApp/DictationOperation.swift`
- `Tests/EchoTypeCoreTests/SessionMachineTests.swift`
- `Tests/EchoTypeCoreTests/STTClientTests.swift`
- `Tests/EchoTypeCoreTests/Support/` only if a fake needs the new API
- `docs/decisions/0024-dictation-operation-lifetime.md`
- Exception: `Tests/EchoTypeAppTests/DictationOperationTests.swift` may change only to follow a renamed or removed API, under the plan's contract. Each such edit is listed in the handoff.

### Required seams

- `DictationOperation.Dependencies`, `Result` and `Presentation` stay unchanged. See the plan's cross-workstream contracts.
- `DictationController` and `SpeechAdmissionTests` need no changes. If either does, record it as drift.

### Acceptance criteria

- None of `onFinishing`, `onAbort`, `finishingEffect`, `abortTask`, `finishingTask` or `closingSend` remains (`grep` finds none in `Sources` or `Tests`). `conclude` joins nothing owned by the operation.
- Deadlines are scheduled only from `reschedule()`.
- Workstream 1's `DictationOperationTests` pass with no assertion removed or weakened.
- Every "Behavior to preserve" item is covered by a passing test in either the operation or core suites.
- The full suite and release build pass. `DictationOperationTests` and `SessionMachineTests` pass 20 consecutive runs.
- Decision 0024 matches the code.
- G1 Passed.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachineTests|STTClientTests|DictationOperationTests|SpeechAdmissionTests|CoordinatorTests'
for i in $(seq 20); do XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'DictationOperationTests|SessionMachineTests' > /dev/null || echo "failed run $i"; done
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
swift build -c release --product EchoTypeApp
grep -rnE 'onFinishing|onAbort|finishingEffect|abortTask|finishingTask|closingSend' Sources Tests
git diff --check
```

The `grep` must print nothing.

## Implementation handoff

- Base commit: `b18d07b05d67144ab21133550ade69b7c4b1c632`
- Outcome: The specification's Design is implemented. `SessionMachine` takes no callbacks and holds no task handles; its surface is `run()`, `send(audio:)`, `beginFinishing()` (synchronous, idempotent, arms the finishing deadline), `sendClosing()`, `cancel()`, `fail(_:)` and `snapshots`. The hard cap calls `beginFinishing()` itself and the `finalizing` snapshot is the operation's cue. One `reschedule()`, called from `transition(to:)` and from the two inputs that move a deadline (speech and `transcript.created`), is the only `clock.schedule` call; one `deadlineReached()` dispatches on state (readiness, silence/pause/hard cap, finishing). `transcript.done` is `finalised` only once `closingStarted` is set, otherwise `closed`. `conclude` decides, cancels the clock, closes the client and builds the outcome; it joins nothing owned by the operation. `DictationOperation` has one `finish()` routine (stored in `finisher`) started at most once from `commit()` (stop hotkey, reply request, Test timer) or a `finalizing` snapshot, running `beginFinishing()`, destination capture plus `.finishing`, stop capture plus pump drain, then `sendClosing()`. After `run()` returns, `releaseCapture()` stops capture, cancels the pump and `finisher`, and joins both. `enterFinishing`, `abortCapture` and `trigger()` are gone.
- Files changed:
  - `Sources/EchoTypeCore/SessionMachine.swift`: rewrite of finishing, deadlines and teardown as above; doc comments updated.
  - `Sources/EchoTypeApp/DictationOperation.swift`: `finish()`/`finisher`, hard-cap cue in the snapshot loop, teardown joins `finisher`; removed `enterFinishing`, `abortCapture`, the session callbacks, and the now-pointless cancellation of `controls` in `cancel()` (it existed for the old trigger task; actor calls ignore task cancellation).
  - `Tests/EchoTypeCoreTests/SessionMachineTests.swift`: `trigger()` calls now use a private `finish()` helper (`beginFinishing()` then `sendClosing()`, as the operation does); the hard-cap test now asserts the session sends no closing frames itself and the owner's `sendClosing()` sends them; deleted `finishingEffectOrdering`, `finishingEffectIsAwaited`, `FinishingLog` and `startTriggering` (they pinned the removed callback ordering); added "A transcript.done before closing begins is not a finalised transcript" for the `closingStarted` rule.
  - `Tests/EchoTypeAppTests/DictationOperationTests.swift`: identifier rename only, `Point.closingSend` to `Point.closingFrame` (9 occurrences: the enum case, the fake transport's `pass`/`release`, and the `stalledFinishing`, `sendFailure`, `finishingDestinationIsFresh` and `escapeWhileFinishing` arguments/holds). No assertion, argument set or flow changed. Reason below.
  - `docs/decisions/0024-dictation-operation-lifetime.md`: status note; SessionMachine timing bullet describes `reschedule()`; finishing bullet rewritten for calls-only-go-down ownership, `finish()` order, the `closingStarted` rule and teardown on `run()` return; overflow sentence and Consequences test description updated.
  - Not changed: `STTClient.swift` (its `finish()` already waits for readiness when audio is held, which is all `sendClosing()` needs), `STTClientTests.swift`, `Support/`, `DictationController`, `SpeechAdmissionTests`.
- Decisions:
  - `hasRun` removed: the operation runs the session once (and `DictationOperation.run()` already preconditions single use). The early-ending path is kept, restructured as `if ending == nil { begin(); await readUntilEnd() }`, because Escape's `session.cancel()` task can reach the actor before the operation's `run()` task; without it the session would publish `listening` after `cancelled` and arm a readiness deadline on a cancelled session. Covered by `SessionMachineTests` "Cancellation before run still completes teardown and snapshots" and the operation's Escape tests.
  - `commit()` keeps its synchronous `publish(.finishing)` before starting `finish()`, so the stop is acknowledged and `canCommit` drops immediately, as before; `finish()` then captures the destination and publishes `.finishing` again (spec step 2), matching the old double publish.
  - `finish()` does not start once cancelled, and Escape does not cancel `finisher` (cancelling it mid readiness-wait could let `client.finish()` send closing frames ahead of held audio); it is cancelled and joined only after `run()` returns, when the client is closed.
  - Readiness deadline is computed as `startedAt + readinessTimeout` while listening and not ready, so a stray speech partial before `transcript.created` can no longer replace it (previously it could). Not observable in practice; noted for completeness.
  - Grep conflict: the packet's grep must print nothing, but workstream 1's harness used `closingSend` as a fake-transport point name, which the regex matches. I renamed it to `closingFrame` rather than leave the targeted check failing. This exceeds the plan's "only to follow a renamed or removed API" allowance for that file; the lead should accept it or record it as drift.
  - G1 decision, 2026-10-01: accept G1 on the supplied signed candidate. Aidan explicitly reported checks 1, 2 and 3 passed. Check 4 was dictated ending with "reply with EchoType" and arrived as a submitted user message in this thread, confirming paste and Return. All four outcomes passed without changing the approved gate.
- Verification (all at the working tree above):
  - Targeted filter `SessionMachineTests|STTClientTests|DictationOperationTests|SpeechAdmissionTests|CoordinatorTests`: passed (29 tests in 2 suites; 23 tests in 3 suites).
  - 20 consecutive runs of `DictationOperationTests|SessionMachineTests`: no failures (run twice, before and after adding the new core test).
  - Full `swift test`: passed (79 tests in 4 suites; 61 tests in 9 suites).
  - `swift build -c release --product EchoTypeApp`: passed.
  - `grep -rnE 'onFinishing|onAbort|finishingEffect|abortTask|finishingTask|closingSend' Sources Tests`: no output.
  - `git diff --check`: clean.
  - Mutation M1, drain-before-closing order: moved `await session.sendClosing()` ahead of `stopCapture()`/`await pump?.value` in `finish()`. Failed: "Stop, reply request and hard cap drain captured audio before the closing frames" (all three triggers), "A stalled send or capture drain ends at the finishing deadline" (all three points), and "A send failure preserves committed words" (`.binarySend`). Restored.
  - Mutation M2, `closingStarted` rule: changed `decide(closingStarted ? .finalised : .closed)` to `decide(state == .finalizing ? .finalised : .closed)`. The new core test "A transcript.done before closing begins is not a finalised transcript" failed; the operation suite did not catch it, which is why that test was added. Restored.
  - After both, `cmp` confirmed `Sources/` matches the pre-mutation copies exactly.
- Behavior to preserve, mapped to passing tests:
  1. Stop, reply-request stop and hard cap drain captured audio, including the final partial chunk, before `finalize` and `audio.done`: `DictationOperationTests.drainsBeforeClosing` (`.stop`, `.replyRequest`, `.hardCap`); core `hardCapCommits` (session sends no closing frames itself).
  2. Finishing deadline starts when finishing begins and covers drain, closing sends and `transcript.done`; expiry fails with committed text: `finishingDeadline(expires:)` (both), `stalledFinishing` (`.captureStop` drain, `.closingFrame`), core `finalizingWithoutAnAnswerTimesOut`.
  3. Stalled binary send, closing send or capture drain ends within the finishing deadline and releases capture: `stalledFinishing` (`.binarySend`, `.closingFrame`, `.captureStop`).
  4. Readiness: no `transcript.created` in five seconds fails; held audio bounded at five seconds and sent in order once ready: `readinessFailure` (`.noCreated`, `.backlog`), core `readinessDeadline`, `handshakeBacklogLimit`; `STTClientTests` `audioWaitsForTheSessionToBeReady`, `finishBeforeTheSessionIsReady`, `queuedAudioKeepsItsOrderWhileASendIsInFlight`.
  5. Capture overflow and send failures fail with committed text and never send Return: `captureOverflow`, `sendFailure` (`.binarySend`, `.closingFrame`, both with a reply-request transcript); `STTClientTests.bufferedSendFailure`.
  6. Escape cancels through drain and final revision; after the clipboard boundary insertion owns completion: `escapeWhileFinishing` (`.captureStop`, `.closingFrame`, `.revision`), `cancellationBeforeClipboard`, `insertionOwnsCompletion`; core `cancellationBeforeRun`, `cancellingDiscardsEverything`.
  7. Destination captured fresh when finishing begins, never from the readiness probe: `finishingDestinationIsFresh` (both), `destinationReadiness`.
  8. Unrequested `transcript.done` or socket close while listening is `closed` with committed text: `unrequestedEnd` (both), core `unsolicitedDoneDoesNotCommit`, plus `doneBeforeClosingDoesNotCommit` for `done` during finishing before closing.
  9. Test mode keeps its five-second timer with no overlay, insertion or trace: `microphoneTest`.
- Original handoff limitations: G1 and signing were left to the lead; the SessionClock comment was outside the original packet. Later authorised corrections and the candidate are recorded below.
- Specification drift: Aidan authorised the Electron destination compatibility addition described under Resolution. Packet-level drift also includes the `closingSend` to `closingFrame` test-point rename and the SessionClock comment correction. Finishing behavior follows the approved specification.

## Independent review

- Reviewer: fresh independent review agent (not the implementer), diff against `b18d07b`.
- Verdict: Accept. No Required findings. Gate G1 still pending (lead's step).
- Evidence and acceptance criteria:
  - Removed names: the packet's `grep` prints nothing (exit 1). `conclude` now only decides, cancels the clock, closes the client and builds the outcome; it awaits no operation-owned work.
  - Deadlines: `SessionMachine.swift` has exactly one `clock.schedule`, in `reschedule()`; `transition(to:)`, speech and `transcript.created` call it. The readiness, silence/hard-cap, paused and finishing cases match the specification, and the base's equivalents are preserved (stop before readiness replaces the readiness deadline, as `readinessExpired`'s `state != .finalizing` guard did; `.created` while finalising re-arms the same finishing deadline).
  - `DictationOperationTests`: the diff is the `Point.closingSend` to `.closingFrame` identifier rename only (9 sites); no assertion, argument or flow changed.
  - Behavior-to-preserve mapping in the handoff checked against the tests; each item has a passing test. `doneBeforeClosingDoesNotCommit` is a valuable addition (the operation suite cannot see the `closingStarted` rule, per the implementer's M2).
  - Decision 0024's revised bullets match the code, including overflow now stopping capture when `run()` returns rather than via `onAbort`.
  - Targeted verification rerun by the reviewer: filter suite passed (29 tests in 2 suites; 23 tests in 3 suites); 20 consecutive `DictationOperationTests|SessionMachineTests` runs with no failure; full `swift test` passed (79 tests in 4 suites; 61 tests in 9 suites); `swift build -c release --product EchoTypeApp` passed; `grep` printed nothing; `git diff --check` clean.
  - Reviewer mutations (Sources restored and confirmed identical with `cmp` against pre-mutation copies): (A) removing the hard-cap cue `if snapshot.state == .finalizing { finish() }` makes `drainsBeforeClosing(.hardCap)` hang waiting for `.captureStop`, so it is detected, though as a hang rather than a failure. (B) removing `finisher?.cancel()` and `await finisher?.value` from `releaseCapture()` leaves all 19 operation tests passing; see O2.
- Required findings: none.
- Optional observations:
  - O1. Escape during drain can still let closing frames go out. Escape does not cancel `finisher`, so once the cancelled pump ends, `finish()` calls `session.sendClosing()`, which races the `controls` task carrying `session.cancel()` to the actor. If `sendClosing()` wins, `finalize`/`audio.done` are sent after Escape. The outcome is unaffected (operation-side `cancelled` forces `.nothing` and blocks insertion, and `escapeWhileFinishing` passes), and the base had the same race between `beginFinalizing`'s resumption and `cancel()`, so this is not a regression. A one-line `guard !cancelled else { return }` before `sendClosing()` in `finish()` would remove it deterministically, keeping the documented reason for not cancelling `finisher`.
  - O2. The teardown join of `finisher` (`releaseCapture()`) is required by the specification but no test fails without it (mutation B). After `run()` returns, an unjoined finisher can only make no-op actor calls on the ended session, so the product risk is low; a test is not recommended just to pin it.
  - O3. The `closingSend` to `closingFrame` rename in `DictationOperationTests` exceeds the plan's "only to follow a renamed or removed API" allowance, but is forced by the packet's own `grep` and changes no assertion. The lead should record it as packet-level drift.
  - O4. `SessionClock.swift`'s doc comment still describes only silence and hard-cap wake-ups. Outside this packet's ownership; a candidate for the final review.
- Questions: none.

## Resolution

- Finding dispositions: No Required findings. Aidan approved resolving optional O1, O3 and O4 on 2026-10-01.
  - O1 resolved: `finish()` checks `cancelled` after the pump drains and before calling `sendClosing()`. Cancellation during drain now skips closing messages without cancelling the finishing task mid-drain. Closing messages already in progress when Escape arrives remain governed by session cancellation.
  - O2 agreed, no change: keep the finishing-task teardown join. A test solely to pin that internal structure would add little confidence.
  - O3 resolved: the test point rename from `closingSend` to `closingFrame` is recorded as packet-level drift in the plan. Assertions and test behavior are unchanged.
  - O4 resolved: the SessionClock comment now includes readiness, silence, hard-cap and finishing deadlines. Aidan authorised this comment-only extension beyond the packet's original file ownership.
- Lead spot check: `reschedule()` holds the only `clock.schedule`, `transition(to:)`, speech and `transcript.created` call it, and `finish()` is guarded by `finisher == nil`.
- Optional-item verification, 2026-10-01: `swift test --filter 'DictationOperationTests|SessionMachineTests'` and `git diff --check` passed after the cancellation guard and comment update. This does not complete closure review or gate G1.
- Simplification/deletion pass: the implementation removed `trigger()`, `enterFinishing()`, `finishEffect()`, `beginFinalizing()`, `readinessExpired()`, `finalizingDeadlineReached()`, `abortWork()`, `hasRun`, the six callbacks and task handles, the operation's `abortCapture()` and the now-pointless cancellation of `controls` in `cancel()`, plus the core tests that pinned callback ordering (`finishingEffectOrdering`, `finishingEffectIsAwaited`, `FinishingLog`, `startTriggering`). Net 194 insertions, 249 deletions including records. Nothing further to remove.
- Interrupted recovery, 2026-10-01: HEAD matches the handoff base, `b18d07b05d67144ab21133550ade69b7c4b1c632`, on `refactor/macos-lifecycle`; workstream 1 is Accepted in the committed plan. The complete uncommitted diff is attributable to the recorded implementation, O1/O3/O4 and the authorised Electron correction. Reused the complete implementation and independent-review evidence and resumed at the undocumented closure phase with a fresh Codex reviewer.
- Authorised scope addition: `Sources/EchoTypeApp/Destination.swift` requests `AXManualAccessibility` when the frontmost application's attribute is false, before looking up its focused field. T3 had returned AX `noValue`; the rewrite correctly rejected that unavailable destination. The correction enables Electron's accessibility tree and preserves all destination identity checks. Root's production-source probes captured and matched T3 five consecutive times; Aidan confirmed the rebuilt app detects its input. This proves input detection only, not G1 dictation outcomes. The addition is recorded as specification and packet drift in the plan.
- Recovery verification: fresh closure's 30 destination/clipboard/operation tests passed. The full deterministic `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test` passed on the recovered tree, 79 core tests and 61 app tests. `DictationOperationTests|SessionMachineTests` passed 20 consecutive runs after closure. The signed release candidate built successfully and `codesign --verify --deep --strict` passed. The obsolete-name search returned no matches and `git diff --check` passed. All automated acceptance checks are satisfied; G1 alone remains pending.
- Acceptance recovery, 2026-10-01: confirmed the branch and base still match, read the complete uncommitted diff and retained all recorded implementation and closure work. No production or test correction was needed after the signed gate. Reused the completed full suite, twenty repeated lifecycle runs, focused closure and release-build evidence. The targeted five-suite filter passed again, 29 core and 23 app tests. The candidate executable hash still matches the recorded SHA-256, strict deep codesign verification passed again, the obsolete-name search found no matches and `git diff --check` passed.
- Final acceptance: G1 passed on the supplied candidate, with all four outcomes recorded below. No Required finding remains. Workstream 2 is Accepted; the resolved escalation is removed. Final whole-feature review remains the next workstream.
- Acceptance model and harness: GPT-6.1-Sol through Codex in T3 Code.

## Closure review

- Reviewer: fresh closure reviewer, 2026-10-01. Scope limited to authorised O1, O3, O4 and the Electron destination correction against base `b18d07b05d67144ab21133550ade69b7c4b1c632`.
- Verdict: Pass. The authorised corrections are complete; no release-blocking defect found in their integration. Workstream acceptance still requires G1.
- O1: `finish()` checks `!cancelled` immediately after `await pump?.value` and before `session.sendClosing()`. The operation's main-actor cancellation signal therefore prevents starting closing after cancellation during drain. The finishing task still drains and remains joined during teardown; closing already in progress keeps the existing session cancellation behavior.
- O3: Compared the entire operation test file with the base after replacing `closingSend` with `closingFrame`; the files match exactly. No assertion or test behavior changed. The plan records the authorised packet-level drift.
- O4: The SessionClock comment now names readiness, silence, hard-cap and finishing deadlines. Its protocol and implementation match the base exactly.
- Electron correction: `focusedDestination()` requests `AXManualAccessibility = true` only when the attribute read succeeds and equals false, before focused-window and focused-field lookup. Removing this one inserted block reproduces the base file exactly. Two-sample capture, retained application/window/target and PID comparison, supported text roles, target-window equality, enabled-capability checks and final frontmost-PID validation all remain. Attribute lookup applies the existing 0.1-second messaging timeout before the request; failed or unsupported requests proceed through the same conservative focus checks.
- Reviewer verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'DictationOperationTests|DestinationTests|ClipboardTests'` passed, 30 tests in 3 suites, including cancellation during drain/closing/revision, ordered tail delivery, fresh finishing destination, focus-change rejection and clipboard/Return revalidation. Exact-file comparison checks for O3, O4 and the destination insertion passed. `git diff --check` passed.
- External evidence supplied by the lead: production focus probes captured and matched T3 five times, the focused 30-test run and release build passed, and Aidan confirmed input detection in the rebuilt app. That confirmation covers input detection only. None of G1's four dictation scenarios has a recorded pass for this candidate.
- Remaining required findings: none within closure scope. G1 remains pending. No live STT/TTS, app launch, quit or restart, code edit or mutation check was performed by this reviewer.

## External validation

- Gate and placement: G1, after closure before acceptance
- Status: Passed, 2026-10-01. Closure passed before the gate.
- Candidate: `.build/EchoType-redesign.app`, built on 2026-10-01 with `./scripts/build-app.sh release .build/EchoType-redesign.app`; not launched by any agent.
- Executable SHA-256: `3dd36a71ba580cd3ae1d9fdfb307c13edb87fdb90f5e7c96084d549547f45415` for `Contents/MacOS/EchoTypeApp`.
- Signing: Apple Development, team `LJHNNE925Q`; hardened runtime; strict deep verification passed.
- Instructions for Aidan: quit the running EchoType, run `open .build/EchoType-redesign.app`, then in TextEdit or any text field:

  1. Dictate a sentence and stop. It pastes once.
  2. Stop while still speaking the last words. No final words are lost.
  3. Press Escape while Transcribing. Nothing is inserted.
  4. Dictate ending with "reply with EchoType". It pastes and sends Return.

  Afterwards, quit the candidate and relaunch your usual EchoType.
- Results supplied by Aidan, 2026-10-01:

  1. Normal dictation pastes once: Passed, explicitly reported.
  2. Stop while speaking the last words, without losing final words: Passed, explicitly reported.
  3. Escape while Transcribing inserts nothing: Passed, explicitly reported.
  4. Dictation ending with "reply with EchoType" pastes and sends Return: Passed. Aidan dictated this test and it arrived as a submitted user message in this thread.

- Lasting decision: accept all four outcomes on candidate 1, including O1/O4 and the authorised Electron fix. The candidate executable hash matches the recorded SHA-256 and its signature passed strict deep verification again during acceptance recovery. No gate scope reduction was needed. Escalation `G1-WS2-1` is resolved and removed from the plan.
