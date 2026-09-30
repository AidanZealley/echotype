# Workstream 5: Acknowledge MCP admission

Status: Accepted. Implementation, independent review, D1 documentation resolution, fresh closure and final signed G6 audit complete.

## Task packet

### Outcome

The real `--mcp` process reports success only after the running app admits a reading. Dictation/Test return busy; replacement reading starts after necessary cleanup; no request queues for later speech.

### Scope

Extend existing distributed notifications into correlated request/reply delivery. Keep the narrow transport implementation in `EchoTypeApp`; move/remove `SpeakNotification` from core if it becomes solely an app transport detail. Preserve the hand-written modern/legacy MCP parser and tool guidance. Core only needs delivery success or a typed/localised error, not macOS notification details.

Use a UUID request id, intended running app PID and expiry on the shared system-uptime timeline. Register reply observation before posting. Bound the client wait to five seconds and service the main run loop while receiving replies. Standard-input reads must not starve that run loop. No `NSApplication`, settings store, login claim, hotkey monitor or audio initialisation in the MCP-only process.

On the app's main actor, validate request shape/expiry/target and atomically apply the spec admission table. Busy must leave the current operation alone. Accepted reserves a reading for immediate startup or replacement and replies before playback completion. Expired requests never start reading. Reject malformed text rather than crashing; do not expand tool semantics or introduce automatic retries.

Match replies to the pending request and ignore unrelated/late replies. Observer and timeout cleanup happen once. Missing app is unavailable; missing/lost reply is unconfirmed, since admission may already have happened. Do not describe timeout as proof of rejection. A repeated notification for the same live request must not create repeated playback; keep any necessary deduplication bounded by active requests/expiry rather than persistent history.

Run G6 early enough to prove the actual two-process loop before finalising implementation. Distributed notifications can be delayed or dropped and need a running main run loop. The protocol handles uncertainty; a passing round-trip is not a delivery guarantee. See Apple's [distributed notification documentation](https://developer.apple.com/documentation/foundation/distributednotificationcenter). If this mechanism cannot meet the agreed contract, escalate evidence and alternatives rather than silently adding a daemon, TCP listener or XPC service.

### Non-goals

No app launch, automatic replay, delayed speech queue, new agent configuration changes, summarisation model, general RPC framework, signing/entitlement changes or extra executable. No dual support for obsolete fire-and-forget delivery unless a concrete required external compatibility consumer is identified and approved.

### Initial ownership

- `Sources/EchoTypeApp/MCPProcess.swift`, `main.swift`, coordinator speech admission/observer code, new app-local request/reply types.
- `Sources/EchoTypeCore/SpeakNotification.swift` removal/move, `MCPServer.swift` only for delivery/error integration preserving protocol compatibility.
- `Tests/EchoTypeCoreTests/MCPServerTests.swift`, `Tests/EchoTypeAppTests/SpeechAdmissionTests.swift`, `MCPDeliveryTests.swift`.
- `Views/SettingsView.swift`/README only if setup text or error explanations need synchronization; preserve copyable registration commands.
- Decision 0022 and index, this record, row 5/G6 and escalations.

### Required seams

Consume the accepted coordinator/reading boundary from 4. Atomically reserve on the main actor before replying. Declare accepted/busy/expired admission outcomes inside the app transport; map unavailable/unconfirmed/invalid input to MCP tool errors. Preserve stdout exclusively for JSON-RPC responses and stderr for diagnostics.

No independent transport actor may decide whether dictation is busy from a stale state copy. Multiple clients may be active, but each admission is serialized by the coordinator. Register/cancel pending reply state safely across timeout, EOF and late notification delivery.

### Acceptance criteria

- Spec case 11 and every admission-table row pass, including dictation startup/finalisation/insertion and paused/startup reading.
- MCP replies follow admission, remain bounded, and do not wait for playback. Busy does not cancel dictation or Test.
- Main-actor expiry prevents a delayed request from starting reading. Unconfirmed delivery never automatically retries.
- Modern/legacy existing exchanges retain their response semantics and guidance. `--mcp` never starts the app services.
- Signed G6 proves reply receipt while the menu-bar app is inactive, concurrent clients, restart/no-app behavior and cleanup.
- The old silent-drop/fire-and-forget path is removed. Any deduplication state is bounded and tied to request expiry.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'SpeechAdmissionTests|MCPDeliveryTests|legacyExchangeDeliversText|modernRequestDeliversText|unsupportedVersionIsRejected|failedDeliveryIsAToolError'
swift build --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-workflow.app
git diff --check
```

Create named app suites and select actual new core tests too. Use fake notification timing/admission for deterministic tests. G6 must exercise the signed executable's real `--mcp` mode in two processes; write exact candidate-specific commands into External validation once built. Successful admission may trigger paid playback, so obtain authorisation before using the live speech path. Do not treat a fake parser test as proof of distributed delivery.

## Implementation handoff

- Base commit: `9bc33362ab06cf3e0e7f1bd5bae61ce6c3f6ad08` on `refactor/macos-lifecycle`. The only existing tracked change was the lead's row-5 Implementation transition. Read the workflow, frozen packet, approved specification, plan, repository README, relevant decisions and accepted packet-4 handoff. Applied `unslop` and `writing-for-agents` to these records. All implementation work remains uncommitted.
- Outcome: The real stdio server waits for correlated admission before reporting Speaking. The app validates and admits synchronously on its main actor through the accepted `speak(_:) -> Bool` boundary. Idle and reading replacement reserve immediately; every dictation phase and Test remain busy. No speech is queued or retried after failed or unconfirmed delivery.
- Files changed: `Sources/EchoTypeApp/MCPProcess.swift`, `DictationController.swift`, new `SpeechDelivery.swift`; removed `Sources/EchoTypeCore/SpeakNotification.swift`; one guidance sentence in `MCPServer.swift`; new `Tests/EchoTypeAppTests/SpeechAdmissionTests.swift` and `MCPDeliveryTests.swift`; decision 0022 and its index; this handoff and External validation. The lead owns plan/status/review/acceptance records. Entry-point dispatch, registration commands, settings, signing and entitlements are unchanged.
- Actual request/reply fields: request notification `com.aidanzealley.echotype.speak.request` carries UUID-string `id`, Int32 `target`, finite system-uptime `expiry` and string `text`. Reply notification `com.aidanzealley.echotype.speak.reply` carries the same `id` and `target`, plus `outcome` of accepted, busy, expired or invalid. The intended GUI PID prevents a restarted app admitting its predecessor's requests. Shape and expiry validation precede cached replies or coordinator reservation. Requests with uncorrelatable identity or another target are ignored.
- Process loop: one background reader owns stdin and hands the main thread one buffered line, with semaphore backpressure. The main thread handles lines serially and pumps its run loop both while idle and during the five-second acknowledgement wait. It registers each reply observer before posting, ignores malformed/unrelated/late replies and settles once. `defer` removes that observer on every outcome. EOF drains the current and buffered requests before exit, so a piped request still receives a reply. Only JSON-RPC responses reach stdout. No `NSApplication`, settings store, login claim, hotkey, capture or audio service is constructed in `--mcp`.
- Deduplication: the main-actor admission owner stores only accepted/busy UUID outcomes through their original expiry. Duplicate live notifications repeat that outcome without reserving again. Each request purges expired entries. One retained, cancellation-aware suspending-clock cleanup task clears remaining entries at the last live expiry, including when no further request arrives. No durable request history, compatibility observer, daemon or alternate transport was added.
- Decisions: App-local errors distinguish unavailable, busy, expired, invalid input and unconfirmed delivery. Unconfirmed explicitly allows that admission may already have happened and forbids automatic retry. Core still knows only a throwing delivery closure. Success and modern/legacy JSON-RPC semantics stay unchanged; guidance now says the tool returns after admission. The existing coordinator initializer gained one optional dictation factory so actual busy-phase tests can drive real operations without constructing capture/Keychain/network adapters. Testing a separate copied admission table would not verify the coordinator. The production operation construction remains the existing implementation.
- Verification: `swift test list` confirmed all selected declarations in `.build/mcp-test-list.txt`. `XAI_API_KEY= swift test --filter 'SpeechAdmissionTests|MCPDeliveryTests|legacyExchangeDeliversText|modernRequestDeliversText|unsupportedVersionIsRejected|failedDeliveryIsAToolError|ReadingOperationTests'` passed four core and 25 app declarations, 29 total. Eight new app declarations cover immediate startup/paused replacements, actual dictation startup/final revision/insertion busy responses, untouched Test, malformed/expired input, bounded replay, matching live replies, exact unconfirmed/no-repost behavior and distinct delivery errors in both modes. The accepted reading suite additionally covers playing/replacement cleanup and predecessor joining. Explicit fake acknowledgements replace scheduler guesses; suites have one-minute limits. Log `.build/mcp-tests.log`.
- Build/signing: `swift build --product EchoTypeApp`, `./scripts/build-app.sh debug .build/EchoType-workflow.app`, `codesign --verify --deep --strict .build/EchoType-workflow.app` and `git diff --check` pass. Logs `.build/mcp-build.log` and `.build/mcp-signed-build.log`. Final candidate executable SHA-256 `68b2a44d44c88fd5c3775e68b64d8db36351184bb60640b903eb44a9b6526ef3`, bundle `com.aidanzealley.echotype`, team `LJHNNE925Q`. It is built without GUI launch.
- Simplification/deletion: removed the core notification type and obsolete fire-and-forget notification name/observer. Kept the hand-written parser, one throwing delivery closure, the existing coordinator admission method and accepted predecessor/Clipboard joins. Stdin has one pending line rather than an unbounded line queue. No generic RPC protocol, transport actor, fallback delivery, retry scheme or new configuration was added. Reader, request/backpressure, player, Clipboard, Destination and DictationOperation files are unchanged.
- Known limitations or external checks: The signed actual CLI exchange with a separate fake responder proves notification receipt, open-stdin run-loop service, concurrent clients, both modes and bounded unconfirmed response. It cannot prove the running GUI's admission callback, inactive-app receipt, restart/unavailable behavior or busy-operation preservation on the signed app. G6 remains pending before independent review. The exact candidate and needed user gate are below. No existing GUI quit/restart, accepted live reading, Test, capture, key inspection/export, permission/settings/hardware change, installation or production write occurred. Existing G1/G2/G4/G5 deferrals and exhausted paid-test authority remain unchanged. Separately authorised summaries belong to the orchestrator.
- Specification drift: none. Signed-app G6 evidence requires user action or an explicit validation-scope decision; no passing-app claim is inferred from the fake responder.

## Independent review

- Reviewer: fresh independent lead subagent, 2026-09-30. Applied `unslop` and `writing-for-agents`. Reviewed the complete tracked diff against `9bc33362ab06cf3e0e7f1bd5bae61ce6c3f6ad08`, new `SpeechDelivery.swift` and both new app-test files, surrounding coordinator/reading/stdio/parser code, workflow, approved specification, repository README, relevant decisions and accepted dependency handoffs. Changed only this section.
- Verdict: no Required implementation defect found. One documentation finding remains before acceptance. Main-actor admission uses the actual synchronous coordinator reservation, declines every dictation/Test phase without touching the operation, and preserves accepted predecessor/Clipboard joins. Correlated replies precede MCP success; expiry prevents late admission; timeout remains unconfirmed with no repost. The real stdio loop services notifications with open stdin, drains piped requests before EOF exit and keeps stdout for JSON-RPC. IPC remains app-local and the obsolete notification path is removed.
- Required D1, documentation only: synchronize current gate/decision records before acceptance. Decision 0022's Admission rewrite candidate section still says signed-app G6 is pending before independent review and needs restart authority; its index repeats pending G6. The plan's Execution pause and next action still says row 5 is Blocked before review, and its G6 candidate still says actual GUI admission is unverified. These statements contradict this packet's Authorised G6 recovery and the row's Review state. Record actual inactive-GUI concurrent modern/legacy acknowledgement, unavailable/restart and rejection results, the explicit signed busy deferral and remaining final-candidate recheck. Preserve earlier implementation/probe history as historical evidence. This requires record synchronization, not a transport or acceptance-scope change.
- Optional observations: none. The explicit dictation factory isolates a real framework boundary and lets tests exercise actual startup/final revision/insertion ownership. The stdin semaphore permits one buffered line; replay state lasts only through live expiry with one retained cleanup task. No generic RPC machinery, fallback transport, duplicate admission table or speculative compatibility layer needs removal.
- Questions: none. Audited `.build/g6-live.py`, `.build/g6-app-probe.swift` and their retained logs. The actual GUI was inactive; two real clients received Speaking in 0.034/0.095 seconds with stdin held open and exited zero on EOF. Expired/numeric-text requests received expired/invalid and the predecessor PID received no reply. These demonstrate admission and rejection, not audible completion. Signed busy preservation remains explicitly deferred to reviewed deterministic evidence. Final reviewed-candidate G6 recheck is still the lead's acceptance gate.
- Independent verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SpeechAdmissionTests|MCPDeliveryTests|legacyExchangeDeliversText|modernRequestDeliversText|unsupportedVersionIsRejected|failedDeliveryIsAToolError|ReadingOperationTests'` passed four core and 25 app declarations, 29 total. `git diff --check` passed. Source search found no old `SpeakNotification` or fire-and-forget notification name. Inspected recorded app-build/signing evidence. No live speech/dictation/Test, GUI interaction/restart, key inspection, permission/settings change, signing rebuild, installation or commit occurred in this review.

## Resolution

- Finding dispositions: D1 accepted and resolved by the lead in the sole documentation remediation pass. Decision 0022/index and plan now distinguish passed early actual-app G6, approved signed busy deferral and pending final recheck. No implementation correction or architecture change was needed.
- Simplification/deletion pass: independently confirmed obsolete notification path/core transport type removed, one bounded stdin slot, expiry-bound replay state and actual coordinator admission. No extra abstraction, duplicated phase table, fallback, queue or retry remains.
- Final verification: independent 29-declaration targeted run and whitespace checks pass. Final actual signed inactive-GUI concurrent modern/legacy recheck and expiry/malformed/stale-target probes pass on unchanged executable hash `68b2a44d…`; strict deep signing passes.

## Closure review

- Reviewer: fresh focused closure agent, 2026-09-30. Read the workflow and original reviewer brief, frozen packet, approved specification, repository README, relevant decisions and accepted reading handoff. Applied `unslop` and `writing-for-agents`. Reviewed accepted D1 and its documentation resolution; changed only this section.
- Verdict: D1 resolved. Decision 0022 and its index record passed early signed G6 and pending final recheck. The plan's current execution record, row 5 and G6 candidate agree with the packet's Authorised G6 recovery: actual inactive-GUI concurrent modern/legacy admission, unavailable/no-launch behavior, expired/malformed rejection and old-PID ignore. Earlier probe and restart-authority records remain historical evidence.
- Remaining required findings: none from focused closure. The fixes introduce no release-blocking defect and change no implementation or admission contract. Signed busy-operation preservation remains explicitly deferred under Aidan's answer, supported by independently reviewed coordinator phase/Test evidence. Two of four authorised G6 requests remain for the lead's final reviewed-candidate recheck; closure does not mark that gate passed or accept the workstream.
- Verification: compared the repaired records with the accepted finding and recorded actual-app evidence; `git diff --check` passed. The independent 29-declaration targeted run remains the implementation evidence. Documentation-only remediation did not justify repeating it. No live requests, GUI interaction, dictation, Test, state changes or commit occurred.

## External validation

- Gate and placement: G6 during implementation before independent review; recheck the reviewed candidate after fixes.
- Status: Passed under the authorised scope, including final reviewed-candidate recheck. Signed busy-during-dictation is explicitly deferred using reviewed deterministic coordinator phase/Test evidence.
- Candidate: `refactor/macos-lifecycle`, base `9bc33362ab06cf3e0e7f1bd5bae61ce6c3f6ad08`, uncommitted acknowledged transport and named tests described above. Signed executable `.build/EchoType-workflow.app/Contents/MacOS/EchoTypeApp`, SHA-256 `68b2a44d44c88fd5c3775e68b64d8db36351184bb60640b903eb44a9b6526ef3`. The currently running packet-4 GUI remained PID 93537. Reconfirm that PID before any authorised restart.

### Completed feasibility probe

The temporary responder uses only Foundation and distributed notifications. It answers text marked `G6-NO-AUDIO-` with accepted or busy, or intentionally omits the reply. It never calls the coordinator or any network/audio/key API. The packet-4 GUI does not observe this new notification name. The signed production executable selects that GUI's PID, while a separate responder supplies acknowledgements. Four concurrent actual `--mcp` processes keep stdin open until after their reply. The legacy process first sends initialize; the modern process supplies its version in `_meta`.

Exact local probe commands, run before any candidate GUI launch:

```sh
swiftc .build/mcp-responder.swift -o .build/mcp-responder
codesign --force --sign 'Apple Development' .build/mcp-responder
python3 .build/mcp-probe.py
```

The three temporary probe sources remain in `.build` for evidence. `mcp-probe.py` starts the responder, waits for its ready line, runs `mcp-loop.py` and terminates/awaits only that responder in `finally`. It captures `.build/mcp-loop-final.log` and `.build/mcp-responder-final.log`. Do not run this fake-success probe against the candidate GUI, which would also receive its requests and could begin live speech.

The final candidate returned modern accepted in 0.319 seconds, legacy accepted in 0.026 seconds, busy in 0.317 seconds and unconfirmed in 5.308 seconds. These timings start before process launch and include app lookup; the admission wait itself is five uptime seconds. All four exits were zero and stderr was empty. Each observed request targeted GUI PID 93537 with a distinct UUID. EOF after the response released each process. The temporary responder was terminated. An initial probe used the wrong executable basename and failed before launching a client; correcting the path to EchoTypeApp resolved it. The earlier successful candidate and final candidate produced the same response meanings.

This demonstrates the agreed transport can receive real replies without NSApplication while stdin remains open. The fake accepted/busy replies do not demonstrate GUI admission or operation preservation. Distributed delivery can still be delayed or dropped; timeout remains unconfirmed and never causes replay.

### Original user gate before independent review, resolved below

The lead must obtain an idle-time GUI restart and agree the remaining validation scope. There is no remaining paid TTS/STT/cleanup/Test authority. GUI binding has repeatedly timed out in earlier packets. Use the user's own observations or reliable native controls; a fresh permission grant is outside scope.

1. Once idle-only restart is authorised, quit only the confirmed GUI process, preserving existing stdio processes. Check no GUI remains. With no app, the following candidate command must return the unavailable tool error, exit after EOF and launch no GUI:

   ```sh
   printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"speak","arguments":{"text":"G6 no-app probe"}}}' | .build/EchoType-workflow.app/Contents/MacOS/EchoTypeApp --mcp
   ```

2. Launch the signed candidate with `open .build/EchoType-workflow.app`. Confirm its GUI PID and executable path; keep it inactive for reply checks. Recheck candidate hash and signature. Requests targeted at the previous PID must be ignored. A directly posted request for the new PID with `expiry` at or before current system uptime must return expired and start no reading. Post malformed string/text and unrelated replies to confirm harmless rejection. These rejection probes need no accepted reading or paid network path.

3. Actual idle/concurrent/reading-replacement admission requires separate authorisation for short live speech, or an explicit user decision to rely on the reviewed deterministic coordinator evidence for these rows. A fake responder alone cannot satisfy this step. If live scope is approved, use distinct short texts and fresh candidate stdio processes in both modes, hold stdin open and capture exact tool responses. The modern command is:

   ```sh
   printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28"},"name":"speak","arguments":{"text":"MCP admission works."}}}' | .build/EchoType-workflow.app/Contents/MacOS/EchoTypeApp --mcp
   ```

   The legacy exchange sends `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}` followed by a tools/call with id 2. Verify success arrives after admission and before playback completion. Two simultaneous clients must receive their own replies; replacement may supersede the earlier admitted reading.

4. Signed busy validation requires an authorised or user-owned active dictation/Test operation, or an explicit scope decision to use the deterministic phase tests. A rejected speak must leave that operation alone. Do not run Settings Test or start another billed dictation under historical authority. Observe missing/lost reply as unconfirmed, without retry, and cleanup after success/error/EOF. Preserve existing deferrals.

- Required evidence: Actual running-app admission acknowledgement, inactive-menu-app delivery, correlation under concurrent clients, unavailable/restart behavior, expiry rejection and pending-observer cleanup. Distinguish CLI feasibility and fake replies from actual app admission throughout.
- Resume condition: User supplies idle-restart authority and either bounded live admission/busy-check authority or an explicit validation-scope decision. Execute that scope against the identified candidate, then independent review. If actual distributed delivery fails, retain evidence and escalate transport alternatives before adding another mechanism.

### Lead gate triage

- Confirmed clean packet-5 base `9bc33362ab06cf3e0e7f1bd5bae61ce6c3f6ad08` and durable Accepted rows 1 through 4 before implementation. Complete changed-file ownership matches the packet; Reader/request/player/Clipboard/Destination/DictationOperation files are untouched. No interrupted acceptance or used remediation pass exists.
- Inspected the complete implementation diff and new transport/tests, accepted reading admission/join boundary, test log and signed fake-responder evidence. The eight new app declarations plus existing MCP/reading declarations pass, 29 total. `git diff --check` passes. Full independent review remains a fresh next phase after early G6, rather than being inferred from this lead audit.
- E5-G6-ADMISSION requests concrete idle restart and bounded admission scope. Empty supplied text cannot bypass live request construction, so it is not used as an unpaid accepted probe. The recommended four-request ceiling includes any final post-review recheck. No additional live authority is consumed or reset.
- G6 is Testing with CLI feasibility established and actual GUI evidence pending. Specification drift remains none; an explicit reduced signed scope would be recorded as validation drift on resumption. Existing G1/G2/G4/G5 deferrals, exhausted historical allowances and Foundation buffering limitation persist. Work remains uncommitted. No review/remediation/closure completion is claimed.

### Authorised G6 recovery, 2026-09-30

- Aidan answered "do it" to the recommended idle GUI restart and four-request ceiling. Audited PID 93537 and exact workflow executable, terminated only that GUI through NSRunningApplication and preserved all six existing MCP processes. No new evidence of active dictation appeared. The no-app candidate call returned unavailable and exited on EOF without launching a GUI. Open launched signed candidate PID 38796, inactive, with the unchanged hash `68b2a44d…`. Actual GUI replies returned expired for past uptime, invalid for numeric text, and no reply for previous PID 93537. Signed probe `.build/g6-app-probe` and log `.build/g6-app-probe.log`.
- Before attempts, reserve requests 1 and 2 of the cumulative four-request G6 allowance. Texts are "MCP modern admission check." and "MCP legacy concurrent admission check.", both below 120 characters. Use only normal saved-key handling. Two requests remain for post-review recheck; no STT/cleanup/Test authority is added.
- Early live result: the actual candidate GUI, inactive, admitted two concurrent real CLI requests. Modern returned Speaking in 0.034 seconds and legacy in 0.095 seconds with stdin held open; both exited zero on EOF with empty stderr. No fake responder ran. Actual admission follows synchronous reservation and does not await playback. Logs `.build/g6-live-early.log`; probe command `python3 .build/g6-live.py`. Audible playback is not claimed by these acknowledgements. Missing/lost reply remains supported by the signed CLI five-second unconfirmed probe and deterministic matching/cleanup tests, not a delivery guarantee. Signed busy-operation preservation is explicitly deferred by the answered recommendation; ordinary user-owned dictation was unavailable.

### Final G6 audit

- Fresh closure verifies D1 resolved, no remaining Required finding and no implementation change after independent review. Before final attempts reserve requests 3 and 4 of the cumulative four-request ceiling using the same two short modern/legacy concurrent texts. The G6 live allowance is now fully charged and is not reset on recovery. Signed GUI PID 38796 remains the exact workflow candidate; no responder or extra GUI runs.
- Final result: actual inactive GUI returned expired/invalid again and ignored predecessor PID. Concurrent modern and legacy clients returned Speaking in 0.024/0.071 seconds, both exited zero after EOF with empty stderr. Exact commands `.build/g6-app-probe` and `python3 .build/g6-live.py`; logs `.build/g6-app-probe-final.log` and `.build/g6-live-final.log`. Hash stays `68b2a44d44c88fd5c3775e68b64d8db36351184bb60640b903eb44a9b6526ef3`; strict signature and whitespace checks pass. All six pre-existing MCP PIDs remain; another user/harness MCP PID appeared and was untouched.
- Accepted validation drift: signed busy-during-dictation/Test operation preservation is deferred by Aidan's recommended-scope "do it" answer using reviewed deterministic actual coordinator phase/Test evidence. No ordinary user-owned dictation was available. Signed concurrent app admission, rejection, inactive receipt and restart/no-app behavior are actual-app evidence; five-second unconfirmed transport and matching/late-reply cleanup combine real signed CLI feasibility with reviewed deterministic evidence. No delivery guarantee or audible-completion claim is made. No implementation/architecture drift. G1/G2/G4/G5 deferrals and Foundation buffering limitation remain unchanged. Four of four authorised G6 TTS requests are conservatively charged; no remaining G6 live authority. No key inspection/export, agent-started dictation/STT/cleanup/Test, grants, settings/configuration changes, production replacement, installation or publication occurred.
- Acceptance audit: recovered exact base/branch and packet-owned diff; sound implementation reused. Independent review found only D1, resolved in one documentation pass and verified by fresh closure with no Required findings. Task packet unchanged. One acceptance commit contains code and owned records; no new implementation pass or remediation reset.
