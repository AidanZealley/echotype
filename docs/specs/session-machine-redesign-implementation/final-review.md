# SessionMachine redesign whole-feature review

Status: Accepted, 2026-10-01. Independent whole-feature review and fresh focused closure passed; no correction pass was needed. Workstreams 1 and 2 are Accepted and G1 Passed.

## Reviewer task packet

Review the full branch against the starting commit recorded in the plan and the [approved specification](../session-machine-redesign.md). Read the accepted handoffs, but review the combined diff and surrounding code independently.

Audit:

- Every specification acceptance criterion and "Behavior to preserve" item: name the test that covers each one.
- Finishing lifecycle and cancellation across `SessionMachine`, `STTClient`, `DictationOperation` and `DictationController`.
- Dependency direction: the session makes no calls up into the operation.
- Duplicated state, unowned tasks, stale fakes or helpers left from the old callbacks, and speculative machinery.
- Test value: tests assert outcomes rather than internal ordering.
- Agreement of decision 0024 and code comments with the implementation.

Record findings as Required, Optional or Question, with evidence.

### Whole-feature verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage
swift build -c release --product EchoTypeApp
grep -rnE 'onFinishing|onAbort|finishingEffect|abortTask|finishingTask|closingSend' Sources Tests
git diff --check
```

The `grep` must print nothing. No live xAI calls, installation or publication.

## Initial whole-feature review

- Reviewer: independent whole-feature reviewer, GPT-6.1-Sol through Codex in T3 Code, 2026-10-01. Applied the unslop skill to this record.
- Branch, base and reviewed head: `refactor/macos-lifecycle`, base `256f3bb6cb543292dee7f6e23cf0a72d73b23feb`, head `18a2056f8543c65b6fb3ba22863e1ce120f12ee0`. Read the full combined diff, accepted handoffs, approved specification, workflow, repository README, decisions 0004/0021/0024 and Aidan's preferences. No implementation edits or mutation checks.
- Verification run:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage` passed, 79 core tests and 61 app tests. The two live integration tests skipped because credentials and the recording fixture were unset.
  - `swift build -c release --product EchoTypeApp` passed.
  - The packet's exact obsolete-name `grep` printed nothing, exit 1 as expected for no matches.
  - `git diff --check` passed. No live network requests, app launches or restarts, installation or publication.
- Acceptance-criteria audit:
  - Removed callbacks and four task handles: confirmed by the obsolete-name search and source review. `SessionMachine.conclude` awaits only client teardown, never operation work. `hardCapCommits` proves the session publishes finalizing without sending closing frames itself; `drainsBeforeClosing` proves the operation supplies the drain and closing sequence for all three triggers.
  - One deadline function: the only session `clock.schedule` is in `reschedule()`. State transitions, speech and readiness recompute it. `readinessDeadline`, `quietPausesAndSpeechResumes`, `nothingSaidCancelsSilently`, `hardCapCommits`, `finalizingWithoutAnAnswerTimesOut`, operation `finishingDeadline` and `stalledFinishing` cover readiness, silence, paused hard cap and finishing outcomes.
  - Once-only finishing and the closing-started rule: `drainsBeforeClosing(.stop)` issues two commits and asserts one insertion and one ordered frame sequence. `doneBeforeClosingDoesNotCommit` covers done during drain; `drainsBeforeClosing` covers clean completion after closing; `sendFailure` covers failure before completion. `closingStarted` is set before awaiting the client's finish and the first ending wins. No task identity or callback order assertion remains.
  - Every preserved behavior has a passing deterministic test, listed below. The full suite and release build passed at the reviewed head.
  - Smaller operation harness: accepted workstream 1 replaced 16 bespoke gates and 19 counters/flags/hooks with one point recorder, manual clocks and controllable transport/capture fakes. Fifteen named points now share the same wait/hold mechanism; tests hold only the suspensions relevant to their scenario. The file grew with behavior coverage, but the independent interleaving controls and counters are gone. This meets the accepted interpretation recorded in workstream 1. Its deferred trimming observation remains optional.
  - Workstream 1's test contract is intact. An exact comparison with its accepted file after replacing `closingSend` with `closingFrame` matches HEAD. Dependencies, Result and Presentation are unchanged; controller and speech admission files are unchanged. The accepted twenty-run evidence remains valid, and this review's full suite includes `dictationRemainsBusyThroughStartupFinalRevisionAndInsertion` and `microphoneTestRetainsLastDictationAndIgnoresCommands`.
  - Signed acceptance: G1 already passed on the recorded candidate for normal dictation, stop mid-sentence without losing words, Escape during Transcribing and a reply request. These are external checks, not deterministic test claims. No new manual gate is warranted.
- Behavior-to-test mapping. Unqualified operation names below are in `DictationOperationTests`:
  1. Explicit stop, reply request and hard cap drain the final partial chunk before `finalize` and `audio.done`: `drainsBeforeClosing`, all three `Trigger` cases. Also `STTClientTests.finishWaitsForAudioAlreadyHandedOver` and `SessionMachineTests.hardCapCommits`.
  2. Finishing starts its own timeout and covers drain, closing and done, preserving committed text on failure: `finishingDeadline`, both expiry cases; `stalledFinishing`, capture-stop and closing-frame cases; `SessionMachineTests.finalizingWithoutAnAnswerTimesOut` also proves trailing speech does not reset the deadline.
  3. Stalled binary send, closing send or capture drain ends within that budget and releases capture: `stalledFinishing`, all three points.
  4. Readiness fails at five seconds, held audio is bounded and later flushes in order: `readinessFailure`, both cases; `SessionMachineTests.readinessDeadline` and `handshakeBacklogLimit`; `STTClientTests.audioWaitsForTheSessionToBeReady`, `finishBeforeTheSessionIsReady` and `queuedAudioKeepsItsOrderWhileASendIsInFlight`.
  5. Capture overflow and send failure preserve committed words and never send Return: `captureOverflow` and `sendFailure`, both send points. The latter uses a reply-request transcript and asserts sending is false. `STTClientTests.bufferedSendFailure` also asserts dependent closing frames are absent.
  6. Escape cancels drain and final revision; insertion owns completion after the clipboard boundary: `escapeWhileFinishing`, all three points; `cancellationBeforeClipboard` and `insertionOwnsCompletion`. `SessionMachineTests.cancellationBeforeRun` and `cancellingDiscardsEverything` cover session cancellation and early teardown.
  7. Finishing captures a fresh destination rather than advisory or later focus: `finishingDestinationIsFresh`, available and unavailable cases; `destinationReadiness` covers advisory probing separately.
  8. Unrequested done or socket close while listening fails with committed words: `unrequestedEnd`, both cases; `SessionMachineTests.unsolicitedDoneDoesNotCommit`. `doneBeforeClosingDoesNotCommit` and `closureWithoutProtocolCompletion` cover incomplete finalisation.
  9. Test keeps its five-second timer and has no overlay, insertion or trace: `microphoneTest`; `CoordinatorTests.microphoneTestRetainsLastDictationAndIgnoresCommands` covers controller command isolation and retained Last Dictation.
- Lifecycle, dependency and simplification audit: calls go from controller to operation to session to client/transport. SessionMachine has no operation callback or task. The operation owns and joins its pump, finisher, control tasks, revision updates and final revision; client teardown closes the transport and joins ordered sends and adapter receive work. The one finishing deadline bounds readiness, drain and sends. The post-drain cancellation guard prevents starting closing after Escape. The early-cancel run path protects cancellation before the receive task starts. Removed callback-order tests and helpers have no stale replacements. No new abstraction, duplicated deadline state or speculative machinery needs removal.
- Documentation and authorised corrections: decision 0024 and source comments match the ownership, deadline and closing rules. Electron's AXManualAccessibility request preserves two-sample capture and application/window/target/PID identity checks. The O1 cancellation guard, O3 test-point rename and O4 SessionClock comment are intact. Current draft/proposed status metadata is lead-owned completion documentation; historical records remain historical.
- Required findings by owner: none.
- Optional observations: no new finding. Workstream 1's deferred point-recorder trimming and slow timeout diagnosis remain optional. Workstream 2's accepted O2 remains unchanged: a test solely to pin the finisher teardown join would add little confidence.
- Questions: none.
- Verdict: Pass. All specification acceptance criteria are satisfied under the recorded approvals. No Required finding or additional manual gate.

## Lead triage

- Accepted findings and owners: none. The whole-feature review found no Required defect; no correction pass is needed.
- Rejected findings and reasons: none.
- Deferred optional observations: retain workstream 1's point-recorder trimming and slow timeout diagnosis observations. Retain workstream 2 O2: no test solely to pin the internal finisher join. These do not block acceptance.
- Drift requiring user decision: none. Previously approved destination compatibility and packet-level changes remain intact.

## Focused closure

- Reviewer: fresh focused closure reviewer, GPT-6.1-Sol through Codex in T3 Code, 2026-10-01. Applied unslop to this record.
- Reviewed head: `18a2056f8543c65b6fb3ba22863e1ce120f12ee0`. Reviewed the current diff against HEAD, the approved specification, initial review and lead triage, plan and accepted workstream 2 closure and G1 evidence. Only four documentation files differ from HEAD; no production or test correction followed the initial whole-feature review or signed gate.
- Finding outcomes: the initial Pass verdict stands. No Required finding, new Optional observation or Question. O1's cancellation guard remains immediately after audio drain and before closing; O3's `closingFrame` rename and O4's readiness/silence/hard-cap/finishing clock comment remain intact. Electron's conditional AXManualAccessibility request still preserves two-sample capture and application/window/target/PID identity checks.
- Completion documentation: current status correctly records accepted workstreams and closure in progress. The workflow and final-review provenance name Codex in T3 Code and preserve earlier historical records. G1 records all four signed checks as Passed on the accepted candidate. CI and earlier deferred lifecycle manual checks remain explicitly unverified; the record makes no broader validation claim.
- Verification: `git diff --check` passed. No additional test run was needed for documentation-only changes. The lead and initial reviewer independently passed the full coverage suite and release build at this unchanged implementation head.
- Final simplification assessment: no new code, duplicated state, abstraction or test machinery was introduced during final review. Nothing within closure scope needs deletion. Previously deferred internal-test and harness observations remain optional.
- Remaining blockers: none. No additional manual gate or release-blocking integration issue.
- Verdict: Pass. The bounded final review is complete; the lead can finish the acceptance record and commit.

## Completion record

- Final verification: lead and independent reviewer each passed the full deterministic coverage suite, 79 core and 61 app tests, and the release product build. The exact obsolete-name search printed nothing and `git diff --check` passed. Live integration tests skipped with credentials and fixture unset. CI execution remains unverified; no Actions run was created.
- External validation pending: none for this redesign. G1 passed all four signed checks on the recorded candidate; no production or test change followed it. Earlier lifecycle manual checks deferred in decision 0024 remain unverified under their approved scope.
- Specification drift: approved Electron AXManualAccessibility destination compatibility extends the destination non-goal. Approved packet-level drift includes the closingFrame test-point rename and SessionClock comment correction; the authorised post-drain cancellation guard is preserved. Final review adds no behavior or architecture drift.
- Completion model and harness: GPT-6.1-Sol through Codex in T3 Code. Current-status and execution-provenance corrections preserve the historical workstream reviews.
