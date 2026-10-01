# EchoType macOS rewrite whole-feature review

Status: Accepted 2026-10-01. Whole-feature review, a post-closure simplification pass and G7 are complete.

## Reviewer task packet

Read the workflow README, [specification](../macos-rewrite.md), plan and accepted handoffs. Review the complete integration branch against the starting commit recorded in the plan, including surrounding code. Do not infer correctness from accepted slice verdicts.

Audit every feature-contract item, agreed behavior and required spec case. Focus on cross-feature seams: command reservation, cancellation up to insertion, clipboard cleanup during reading replacement/dictation takeover, destination capture on every finishing path, Return suppression, trace final-text accuracy, expiry at actual MCP admission, bounded queues and teardown. Verify the Test/demo entry points remain isolated and dual MCP compatibility remains intentional.

Check dependency direction, duplicated mutable state, unowned tasks, old relay/clipboard/notification aliases, stale mocks, unjustified infrastructure, meaningful tests and documentation agreement. Optional findings remain optional. Run one whole-feature review, then focused closure of accepted corrections; do not create an open-ended implementation-review cycle.

Assign accepted corrections to fresh implementers with exact sequential file ownership. A changed accepted contract needs evidence-backed escalation and coordinated owner correction, not an unnoticed downstream patch. Perform a final deletion/simplification pass.

### Whole-feature verification

Run on the Mac after accepted corrections:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage
swift build -c release --product EchoTypeApp
./scripts/build-app.sh release .build/EchoType-workflow.app
git diff --check
```

Verify actual CI status and G1 through G6 evidence. Record the current Actions run or any approved publication/configuration follow-up. No live xAI test or installation is implied. G7 checks the signed candidate in the user's real editors and hardware, following the spec checklist and any explicitly settled supported-target limits.

### Acceptance

Every specification case has a tested outcome or explicit approved external-scope decision. All required findings are resolved, mandatory external gates pass, public contracts and persistence remain compatible, and the source/docs no longer describe replaced behavior. If mandatory evidence is missing, set Final to Blocked with a named escalation. Do not mark complete on the strength of unit tests alone.

## Initial whole-feature review

- Reviewer: fresh whole-feature review subagent, 2026-09-30. Read the workflow, approved specification, plan, repository/user instructions, accepted numbered handoffs, relevant decisions and complete integration diff with surrounding code. Applied `unslop` and `writing-for-agents` to this record. Edited only this section.
- Branch, base and reviewed head: `refactor/macos-lifecycle`, base `2e17817246749f626ce36c90823dee2b4ef0d5fb`, head `c4b8e970554fae6d9bebd3a408a7b222058f054f`. The lead's uncommitted Final-row transition is outside this review's ownership.
- Verification run: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'DictationOperationTests|ClipboardTests|ReadingOperationTests|SpeechAdmissionTests|CoordinatorTests|MCPDeliveryTests|SpeechPlayerTests|DestinationTests'` exited 0, with 60 declarations in eight suites passing. Log `.build/final-independent-seams.log`. `git diff --check` passed. The lead owns the one complete deterministic coverage run and final release/package builds. No live calls, key inspection/export, GUI interaction/restart, permissions, installation or publication occurred.
- Acceptance-criteria audit:
  - Cases 1 and 2: one operation result, at-most-once insertion, empty/cancelled outcomes, capture/key suspension and cancelled predecessor-cleanup startup are covered by `DictationOperationTests`. The coordinator reserves synchronously and stays busy through insertion cleanup. Cancellation is synchronous operation state; Clipboard checks it at the write boundary. Test/read/demo entry points remain isolated.
  - Cases 3 through 5: `SessionMachineTests`, `STTClientTests` and operation fixtures protect silence/resumption, no-speech completion, hard-cap tail flushing, ordered buffered/live audio and closing frames, visible send/receive failures, readiness and the finishing deadline. The actual code arms finishing before the once-only capture/drain effect. Closing a stalled transport aborts capture and releases pump/sender joins; success requires closing sends and `transcript.done`. One typed receive path replaces RelayTransport.
  - Cases 6 and 7: finalisation/revision cancellation, simultaneous queued success at insertion, completion after the clipboard boundary, revision deadlines, word-order/faithfulness fallback and spoken-reply protection retain observable tests. Failure text can be inserted but cannot request Return. Cancellation preserves diagnostic commits/revisions while clearing result text.
  - Cases 8 and 9: destination identity includes retained application, window and editing target. The once-only finishing callback captures a fresh token for explicit/reply/hard-cap/failure paths before drain or revision. Clipboard independently revalidates before its write and before Return, reports recovery/attempts truthfully and never repeats paste. It serializes selection, insertion and explicit recovery Copy, completes stopped-Copy cleanup and avoids restoration after observed ownership loss. Double-sampled focus tests and accepted G2/G3 signed evidence supplement fakes. Empty-original insertion deliberately leaves the transcript, as frozen in packet 2. Copy source attribution and late-response limitations remain explicit.
  - Case 10: the coordinator retains predecessor joins across rapid replacements and dictation takeover. Operation identity excludes old presentation/level/completion callbacks. Selection/request/playback/pause/completion boundaries, startup pause, consumed Space repeats, cleared takeover hints and cancellation are tested. Playback stays within 500 ms; copied REST buffers stay within the accepted 320 KiB queue-plus-consumer bound. Foundation callback/network buffering remains outside that bound, with the accepted localhost backpressure evidence preserved.
  - Case 11: incoming speech uses actual synchronous coordinator reservation. Dictation startup/capture/finishing/insertion and Test decline without changing the owner. App admission validates expiry on the main actor before reservation; intended PID, UUID correlation, finite acknowledgement wait, no retry and replay expiry are explicit. Modern/legacy errors and exchanges remain deliberate compatibility boundaries. The `--mcp` branch creates no NSApplication/capture/hotkey/UI services and services notifications while stdin stays open. Reviewed deterministic tests and accepted signed G6 evidence establish their respective claims.
  - Case 12: unchanged storage keys, field-by-field fallback and finite/ranged speed policy are covered at decoding, both encoding boundaries and request construction. Operation settings are snapshots; hotkeys remain live. Successful Test and actual coordinator busy/Test fixtures protect five-second timing, no overlay/insertion/trace and retention of a nonempty Last Dictation.
  - Presentation/recovery and simplification: menu/pill state derive from owned typed presentation, insertion removes cancellation hints, and Last Dictation separates final text from paste/Return attempts with explicit Copy. Overlay focus, login identity, Keychain identity and entitlements retain their established adapters. Removed clipboard owners, relay, fire-and-forget speech notification and duplicate pause/session state stay removed. Focused protocols/closures correspond to real resources or test boundaries; no additional production target, registry, retry or general lifecycle framework was added. No Required simplification found.
- Required findings by owner: none.
- Optional observations:
  - O1, preserved from packet 4: the saturated response-queue cancellation fixture acknowledges producer entry before the actual capacity wait. The independent stalled-consumer cancellation probe supplies the stronger wait/cancellation evidence. This remains Optional; no production observation hook or repeated broad test work is requested.
  - O2, core documentation: `Sources/EchoTypeCore/Settings.swift` describes `finalizeTimeout` as time after the closing frames have gone out. `SessionMachine.enterFinishing()` now starts it before capture drain and closing sends. The behavior and accepted decision 0024 are correct; updating this API comment would remove a stale description. This is Optional and does not change the contract or justify more lifecycle machinery.
- Questions: none. Existing G1 Actions/configuration follow-up, G2 Ghostty substitution/Terminal.app limit, G4 reduced-core deferrals, G5 signed takeover deferrals and G6 signed busy-operation deferral remain accepted. G5/G6 live allowances are exhausted and were not reset. G7 is still pending, including the assembled settings/UI and any whole-feature Mac checks not covered by those approved decisions.
- Verdict: whole-feature code review passes with no Required finding. This is not final workflow acceptance. The lead still needs the final complete deterministic/release/package checks and G7 evidence or an explicit user scope decision for unavailable mandatory checks.

## Lead triage

- Accepted findings and owners: O2 accepted as a small documentation correction, not a release-blocking defect. Fresh implementer exclusively owned the `finalizeTimeout` comment in `Sources/EchoTypeCore/Settings.swift`. Lead validated `SessionMachine.enterFinishing()` starts the timer before capture drain, ordered sends and final transcript receipt. The corrected comment states that budget and removes obsolete timing speculation. Values, declarations and behavior are unchanged; `git diff --check` passes.
- Rejected findings and reasons: none. No Required finding was reported. Existing deliberate empty-original clipboard behavior and finishing capture ownership match the accepted contracts.
- Deferred optional observations: O1 retained from packet 4. Producer-entry acknowledgement does not establish actual saturated-capacity waiting; the separate stalled-consumer probe supplies cancellation evidence. No production hook is warranted.
- Drift requiring user decision: no implementation or architecture drift. G7 needs a candidate-specific external-evidence disposition, preserving all prior approved deferrals and exhausted live allowances.

## Focused closure

- Reviewed head: `c4b8e970554fae6d9bebd3a408a7b222058f054f` on `refactor/macos-lifecycle`, plus the uncommitted O2 comment correction in `Sources/EchoTypeCore/Settings.swift`. Fresh reviewer read the workflow, specification, accepted findings and lead resolutions, original audit, decision 0024 and surrounding Settings, SessionMachine and DictationOperation code. Applied `unslop` and `writing-for-agents`; edited only this section.
- Finding outcomes: O2 resolved. The comment now describes the budget from entering finishing, covering capture drain, queued audio, ordered `finalize`/`audio.done` and final `transcript.done`. `SessionMachine.enterFinishing()` schedules the deadline before awaiting the finishing effect; `DictationOperation` stops capture and joins the audio pump there, and closing sends follow. Expiry produces a failed outcome with committed text. The correction changes no declaration, value or behavior and introduces no release-blocking defect. O1 remains Optional and deferred.
- Final simplification assessment: the correction removes obsolete endpoint-timing speculation and adds no machinery, state, compatibility layer or tests. No further deletion or simplification is needed within this correction.
- Verification: `git diff --check` passed. No tests were needed for the comment-only correction. No GUI/restart, key access/export, live call, permission change, installation, publication or commit occurred.
- Remaining blockers: G7 is still pending. Final acceptance also requires the lead's complete deterministic coverage, release/package verification and explicit CI disposition. Existing approved G1/G2/G4/G5/G6 deferrals, the Foundation buffering limitation and exhausted live allowances remain unchanged.
- Verdict: focused code-review closure passes with no Required finding. Whole-feature workflow acceptance remains pending mandatory external evidence or an explicit user scope decision.

## Post-closure simplification, 2026-10-01

After focused closure, Aidan asked for an adversarial review focused on over-engineering. A fresh Claude Code (Opus 5.5) session reviewed the branch. It found the core ownership design sound: synchronous reservation, one operation owning its result and cleanup, one serialised clipboard service, AX-identity destinations and one typed receive loop. It also found edge-case machinery protecting against failures that do not occur. Changes, commit `ea861da`:

- MCP admission is stateless. Removed the replay cache, its expiry cleanup task and the far-future expiry rejection. Distributed notifications are not duplicated, so there is nothing to replay.
- Removed the `MCPInput` background stdin thread and semaphore. Replies are only awaited inside `deliver`, which pumps the run loop itself, so the original blocking `readLine` loop starves nothing. The signed candidate answered piped requests, skipped blank lines and exited on EOF; G7 MCP checks below passed with it.
- `Clipboard.insert` checks the destination once at the write boundary (after saving) and again before Return, instead of also before saving.
- Dictation readiness is one `Readiness` value instead of microphone/destination flags repeated across two presentation cases.

One review test for duplicate replay and one trivial message assertion were removed. Decisions 0020 and 0022 record the changes. Not changed: the `SessionMachine` finishing/abort lifecycle, which the review judged the hardest code to read. Its redesign is specified separately in [session-machine-redesign.md](../session-machine-redesign.md) for a later branch.

## External validation

- Gate and placement: G7, after focused closure before acceptance
- Status: Passed
- Candidate: signed release `.build/EchoType-final.app` built with `./scripts/build-app.sh release`. Checks ran on candidates from `ea861da` and then the pill correction; final executable SHA-256 `ac141350f5cf1c0b…` at `af38ee8`. Run by Aidan on 2026-10-01, with Claude Code running the MCP commands, screenshots and candidate restarts.
- Results:
  - Permissions carried over to the new signed bundle without prompts.
  - Dictation into T3 Code pasted once and restored the prior clipboard.
  - Select an input appeared with no focused field, switched to Listening after focusing one, and Escape removed the pill.
  - Focus change after stop, during Transcribing: paste skipped, text kept in Last Dictation, Copy worked. Aidan confirmed this is the preferred behavior for an accidental alt-tab. Focus changed before stop pastes into the new field, which Aidan also wants. Pasting into the original window after an accidental switch was considered and rejected: it needs app reactivation or an AX-only insertion path that Electron and terminals do not support.
  - Reply request ("reply with EchoType") pasted and sent Return; the agent replied through EchoType.
  - Escape while Transcribing inserted nothing.
  - Selection reading: audio, Space pause/resume, Escape stop and pill removal, clipboard unchanged.
  - Dictation takeover during reading was clean, then showed Select an input until a field was focused.
  - MCP modern and legacy modes against the running candidate returned Speaking in about 30 ms each. Readings were confirmed by screenshot (pill Reading, then cleared); the Mac's output was muted at the time.
  - MCP during dictation returned the busy tool error, and nothing was queued.
  - Last Dictation and Settings are legible in light and dark mode.
- Correction found: in light mode over dark windows, the glass turns mid-grey and orange "Select an input" text was illegible. Aidan compared variants on real glass in both themes and chose a fixed orange dot (sRGB 0.91, 0.42, 0) beside plain text, with an orange level glow. Dictation's final-minute timer uses the same treatment, and readings no longer show it. Commit `af38ee8`; decisions 0009 and 0024 updated.
- Not checked: the final-minute timer dot on screen (it needs a four-minute dictation), VoiceOver names, and the hardware/permission items already deferred at G4/G5.
- Lasting decisions: destination identity verification stays; paste follows focus at stop and is skipped after a later change. Warnings use a dot and glow, never coloured text.

## Completion record

Before acceptance, copy a concise, self-contained summary of these facts into the plan's Completion summary. The orchestrator cannot read this packet.

- Delivered outcomes: see plan Completion summary.
- Final verification: 80 core and 61 app deterministic tests and the release build pass at `af38ee8`; signed G7 candidate checks pass as recorded above.
- External validation pending: CI execution and required-check configuration (approved deferral); on-screen final-minute dot and VoiceOver; the earlier G2/G4/G5/G6 deferrals.
- Specification drift: none in architecture. Presentation drift approved by Aidan: warning dot and glow instead of orange text.
- Deferred optional observations: O1 fixture limitation; SessionMachine lifecycle redesign specified separately.
