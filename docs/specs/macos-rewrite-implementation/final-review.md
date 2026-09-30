# EchoType macOS rewrite whole-feature review

Status: focused closure. All six numbered workstreams are durably Accepted. Whole-feature code review found no Required defect; final Mac gate remains pending.

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

## External validation

- Gate and placement: G7, after focused closure before acceptance
- Status: Pending
- Candidate and instructions: Record signed release candidate, exact real-editor/hardware checks and needed user action
- Required evidence: Complete spec Mac checklist, command arbitration, both themes/changed accessibility, window focus, truthful trace/recovery and no stale operation effects
- Attempts and lasting decisions: none yet. Deterministic prerequisite recorded 2026-09-30: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test` passed 80 core and 62 app tests; `swift build -c release` passed. Signing, packaging and G7 Mac checks have not run.
- Resume condition: Mandatory evidence passes or an explicit scope decision resolves an unavailable check; meaningful gate corrections receive focused review

## Completion record

Before acceptance, copy a concise, self-contained summary of these facts into the plan's Completion summary. The orchestrator cannot read this packet.

- Delivered outcomes: TBD
- Final verification: TBD
- External validation pending: TBD
- Specification drift: TBD
- Deferred optional observations: TBD
