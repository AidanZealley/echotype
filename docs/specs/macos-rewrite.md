# EchoType macOS lifecycle rewrite

Status: approved scope for workflow planning, 2026-09-29. The destination, cancellation and incoming-speech rules below were agreed with Aidan. Implementation has not started. The [execution workflow](macos-rewrite-implementation/README.md) remains draft until reviewed.

## Goal and scope

Keep EchoType's current macOS feature set while making operation ownership, cancellation, failure handling and cleanup explicit. Each implementation slice must leave a usable app and remove the old code it replaces.

Preserve the native SwiftUI/AppKit app, macOS 26 minimum, Swift 6.2 minimum, package-based build and signed-bundle launch. Start with the existing `EchoTypeCore` and `EchoTypeApp` production targets. Add another production target only if a concrete build or testing constraint requires it.

The [README](../../README.md) and [decision records](../decisions/README.md) describe the shipped baseline. This spec takes precedence for the changes it explicitly describes. Update affected decision records when their replacement behavior lands; retain the historical records with links to their successors.

Outside scope: new features, visual redesign, iOS implementation, persistent dictation history, new providers, changes to agent summarisation behavior, notarisation and a general-purpose action/effect or dependency framework.

## Feature contract

- Dictation uses the configured global hotkey, shows live settled and provisional text, and inserts one final result. Silence pauses the presentation without stopping capture. Speech resumes it. No speech ends silently, and the hard cap finishes the session.
- Keep the current defaults of ten seconds for silence and five minutes for the hard cap. A hotkey commit, detected reply request or hard cap enters the same finishing path.
- Open the microphone only for capture. Preserve the chosen-device fallback, one reopen per session after loss, format conversion and partial-chunk flushing described in [0012](../decisions/0012-capture-with-avcapturesession.md). Stop capture before draining audio and sending protocol closing frames.
- With cleanup enabled, revise committed text while showing the current utterance separately, then make a final revision before insertion. Preserve word order and faithfulness validation, reply-request protection and fallback to available words when revision fails. Reuse the existing rules and fixtures rather than rewriting them incidentally.
- Decide automatic sending from the final text and the Send reply requests setting. Only a successful dictation result may send. On capture or transcription failure, preserve available committed text and attempt insertion if the destination check passes, with a visible error. Failed dictations must never press Return automatically.
- Read aloud accepts a selection or MCP-supplied text, streams PCM playback, supports pause/resume and stops on Escape or the read-aloud hotkey. Preserve the voice, speed, language and text-cap behavior. Empty selection reports an error; selection semantics remain those of the source app's Copy command.
- Preserve the five-second microphone Test operation. It inserts nothing, shows no dictation pill and does not replace Last Dictation. Dictation/read-aloud hotkeys and Escape do not control it.
- Preserve menu-bar status, hotkey enablement, settings, launch at login, permissions, API-key management, updates link, agent setup copy, overlay demo and Last Dictation. The overlay must not take focus. Its hints must reflect the configured hotkey and commands available in the current phase.
- Preserve settings storage keys and compatible decoding, bundle identity, Keychain identity, entitlements and login-item behavior. Settings changes affect the next operation, except for the existing live hotkey behavior.

Preserve command arbitration:

| Command | Behavior |
|---|---|
| Dictation hotkey while idle | Reserve and start dictation |
| Dictation hotkey while capturing | Commit once |
| Dictation hotkey while reading | Stop reading, complete required cleanup and start dictation |
| Dictation hotkey during dictation startup/finishing/insertion or Test | Ignore |
| Read-aloud hotkey while idle | Reserve and read the selection |
| Read-aloud hotkey while reading | Stop reading |
| Read-aloud hotkey during dictation or Test | Ignore |
| Space while reading | Toggle pause; consume repeats without toggling again |
| Test requested while another operation is active | Decline without starting capture |

Consume configured hotkey repeats without repeating commands. Escape and Space belong to the focused app when the active operation does not handle them.

## Agreed behavior changes

### Destination and automatic Return

Record the destination when dictation enters finishing, not when recording starts. This includes hotkey commit, automatic commit and the hard cap. For an unsolicited capture/transcription failure, record the destination when the operation enters its failure-finishing path.

Before insertion, verify that the same destination is focused. Identify the application, window and editing target sufficiently to detect switching fields within the same window. Do not activate an app or restore focus on the user's behalf. If the destination changed or cannot be verified, skip insertion, retain the final text in Last Dictation and show a brief message explaining where to recover it.

Check the destination again immediately before automatic Return. If focus changed after pasting, suppress Return, retain the text and record that sending was skipped. Do not repeat the paste. The paste and Return cannot be atomic across applications; this second check is required even after insertion has begun.

Prove destination identity and revalidation in the supported Mac editors during slice 3. An application-only check is insufficient. Unsupported Accessibility data must produce recovery behavior rather than silently weakening the check. Record the tested applications and any limits.

### Cancellation boundary

Escape cancels dictation during startup, capture, audio drain, transcript finalisation and final revision. Until insertion begins, cancellation wins over a queued successful result. Recheck cancellation at the insertion boundary.

Cancellation inserts nothing and presses no Return. Preserve the existing diagnostic trace policy, including marking a cancelled dictation as cancelled, without treating its text as a result awaiting insertion.

Insertion begins when the clipboard service starts its write-and-paste transaction. From that point, Escape does not interrupt the transaction. Complete restoration and any eligible Return, still subject to destination revalidation. Stop advertising cancellation once insertion begins.

### Incoming MCP speech

| Current operation | Incoming `speak` request |
|---|---|
| Idle | Accept and start reading |
| Reading, including startup or pause | Stop the old reading, complete required cleanup, and start its replacement |
| Dictation, including startup, finishing and insertion | Return a busy tool error |
| Microphone Test | Return a busy tool error |

Nothing queues for later playback. A replacement is accepted for immediate startup, although required clipboard cleanup can briefly delay acquiring its text or audio resources.

The `--mcp` process must receive the app's admission result before reporting success. Existing fire-and-forget notification delivery cannot satisfy this contract. Extend the current distributed-notification mechanism with correlated requests and replies, a bounded acknowledgement wait and rejection of expired requests before admission. The MCP process must service notification delivery while awaiting a reply, without creating `NSApplication`. Keep IPC in the app target and prove the two-process exchange on a signed Mac build before accepting it. If the mechanism cannot meet the contract, escalate with observed evidence before substituting another transport.

Success means the app admitted the reading, not that playback completed. Playback failures use the existing UI error path. No app, busy, and unconfirmed delivery produce distinguishable tool errors. If an acknowledgement is lost, report delivery as unconfirmed and do not automatically retry. Preserve current modern and legacy MCP compatibility and the tool-first written-answer guidance. The MCP process must not launch the app or initialise its UI, capture or hotkey services.

## Ownership and architecture

The names below describe responsibilities, not mandatory declarations or file names.

| Owner | Responsibility |
|---|---|
| App coordinator, main actor | Admit commands, reserve one active operation, own its task, arbitrate replacement and publish presentation state |
| Dictation operation | Own startup, capture, protocol work, revision, final result, insertion eligibility and cleanup through one lifetime |
| Reading operation | Own text acquisition, speech request, PCM decoding, bounded playback, pause, stop and cleanup |
| Protocol handling | Decode each received frame once and preserve ordered sends; report every send/receive failure to dictation |
| Clipboard service, main actor | Serialize selection copy and insertion, own pending restoration and coordinate with destination checks |
| Domain values | Transcript assembly, revision validation, reply detection, settings and trace transformations |
| macOS adapters | Capture, playback, focus lookup, event tap, clipboard, Keychain, windows and local IPC |

Keep domain and protocol logic in `EchoTypeCore` without AppKit or TCC. Keep macOS adapters and SwiftUI/AppKit presentation in `EchoTypeApp`. Operation logic may live in core when its dependencies are platform-neutral; framework-specific orchestration stays in the app. Do not move code across the boundary merely to meet a file-layout diagram.

### Concurrency and completion

- Reserve an operation synchronously before leaving a command callback. Event-tap callbacks only decide consumption and reserve or signal work. They perform no Accessibility queries, Keychain access, capture setup or playback setup.
- An operation produces exactly one outcome. Control commands express commit, cancel, pause or stop without exposing internal state to unrelated services.
- Use structured child tasks for work sharing an operation's lifetime. Retain and explicitly cancel/await unstructured tasks needed at synchronous entry points. Cancellation must close or stop the underlying resource; a timer racing work that never resumes is insufficient.
- A completed or replaced operation cannot mutate its successor's UI, microphone, transport, playback or trace. Use operation identity at asynchronous boundaries where actor isolation alone cannot establish ownership.
- One receive loop decodes typed STT events and applies transcript/protocol decisions. Remove `RelayTransport` and duplicate message decoding when this path replaces them. Retain an explicit ordered send path; actor isolation alone does not prevent sends overtaking suspended sends.
- Binary-send failure, buffered-audio flush failure, malformed JSON, server error and abnormal socket closure all reach the operation's failure path. Unknown event types remain ignorable. Preserve committed text; do not claim successful finalisation without the required protocol completion.
- Release capture promptly when recording stops. Outcome completion includes required resource teardown and transfer of clipboard cleanup ownership. Do not wait for an obsolete network request merely to fill in diagnostic history.

### Deadlines and buffering

- Use a monotonic clock for lifecycle deadlines. Retain the injected clock or an equally testable Swift clock seam.
- Apply the existing eight-second finalisation budget from entering finishing. It covers capture drain, queued sends, closing frames and the final transcript. The existing final revision budget remains separate and bounded. A suspended send must not bypass either cleanup or the deadline.
- Bound waiting for protocol readiness after microphone/key setup. User interaction with permission or Keychain prompts is distinct from a network handshake; do not time out the user while they are answering a system prompt.
- Put explicit finite limits on capture backlog, pre-handshake audio and queued playback. Select small named constants during implementation and document them with the relevant tests. Exhausted capture capacity fails visibly and preserves committed text rather than silently dropping audio.
- Bound playback by queued audio duration. Pausing must not permit the response to accumulate without limit. Stop must release both queued playback and the request.
- Run blocking capture work on its dedicated executor. Keep conversion and PCM decoding off the main actor; retain only necessary framework/UI work there. Reuse revision network sessions while preserving distinct live/final request deadlines.

### Presentation and diagnostics

Publish typed operation presentation state and derive menu-bar and pill state from it. Preserve real distinctions such as microphone readiness and protocol readiness, but remove independently mutable copies of the same fact. Presentation streams can coalesce obsolete updates; protocol events and audio must retain their required ordering.

Last Dictation keeps the last dictation that reached running, in memory only. Preserve commits, revision attempts, timings and JSON export. Distinguish available final text, insertion attempted, sending attempted, cancellation, failure and recovery after destination loss. A synthetic paste cannot prove that the editor accepted text; do not describe an attempted insertion as confirmed delivery.

For recovery, show the available final text and provide Copy in Last Dictation. Opening the window and copying remain explicit user actions. A recovery result must not look as though cleanup deleted every word merely because no insertion occurred. Do not add history storage or automatically open the window.

Validate externally sourced settings before encoding or requesting speech, including finite speed in the supported range. Keep field-by-field persistence fallback and deliberate compatibility boundaries. Use focused protocols for resources with lifetimes and closures for single operations; construct dependencies explicitly without a global service registry.

## Verification

### Automated coverage

Build tests around observable behavior with controlled capture, transport, revision, player, focus and insertion dependencies. Prefer existing deterministic fixtures. Test ownership decisions around a fake clipboard without building a facade that merely reproduces every `NSPasteboard` method. Actual paste/copy behavior still needs Mac checks.

Clipboard change counts do not identify the writer of a synthetic Copy response. Document the remaining source-attribution and late-copy limits in real applications; tests must not imply guarantees the macOS adapter cannot provide.

Required cases:

1. A dictation produces one outcome and inserts at most once; empty and cancelled results insert nothing.
2. Startup cancelled while permissions, device opening or key access is suspended cannot later start a socket or affect a new operation.
3. Silence, resumed speech and hard-cap behavior preserve the current feature contract. Hard-cap finishing drains the final chunk before protocol closure.
4. Live and buffered audio-send failures fail the operation visibly while preserving committed text. Closing frames stay behind queued audio.
5. Stalled drain, binary send, closing-frame send and missing final transcript each terminate within the finishing budget. Abnormal closure is a failure.
6. Escape during finalisation or revision prevents insertion and Return, including when completion and cancellation are ready together. Once insertion begins, restoration completes.
7. Revision failure/unfaithfulness preserves words, and removal of a spoken reply request is rejected. Failed dictations never automatically send.
8. Destination loss before insertion produces recovery; loss after paste suppresses Return. Switching fields within one app is covered, as is unverifiable focus.
9. Copy, insertion and reading replacement respect pending clipboard ownership. A newer external clipboard write is not overwritten by restoration when ownership is lost. Cancellation still allows necessary copy cleanup.
10. Reading stop/replacement works during text acquisition, request, playback and pause. Old callbacks cannot change the replacement. Queued audio remains within its limit.
11. MCP admission covers the table above, unavailable app and missing acknowledgement. Success follows app acceptance and does not wait for playback. Both supported protocol modes remain usable.
12. Existing stored settings survive upgrades. Malformed or invalid fields fall back without discarding valid fields. Test operations do not insert or replace Last Dictation.

Replace scheduler guesses such as repeated `Task.yield()` with explicit acknowledgements. A fake request starting does not prove its caller processed the reply. Give asynchronous suites time limits and ensure fake continuations can be released during teardown. Preserve useful existing tests and delete tests tied solely to removed machinery.

### CI and Mac checks

Add a required pull-request GitHub Actions job on macOS 26 with an explicit installed Xcode selection supporting Swift 6.2 or later. Log toolchain versions, run `swift test --enable-code-coverage` and build the release `EchoTypeApp` executable. Keep live xAI tests disabled in the required job. No signing identity is needed to compile or run deterministic tests; signed packaging remains separate. Making the job a required merge check is a repository setting, not an effect of adding its workflow.

Use coverage to identify missing behavior rather than introducing a percentage target. Keep paid live protocol/prompt checks opt-in and outside the required PR job.

Check the signed app on a Mac for permission prompts, secure-input behavior, event-tap recovery, chosen input and disconnect fallback, Bluetooth format changes, clipboard restoration and destination checks in a native text field, a terminal and an Electron editor. Include same-window field changes, focus loss during final revision, focus loss between paste and Return, back-to-back operations and reading replacement during Copy. Check both themes, configured hints, keyboard access and VoiceOver names for changed UI.

Record actual results and limitations. A Linux compilation failure or a fake-adapter test is not evidence that the signed Mac app passed.

## Implementation slices

Use one continuing primary agent to own interpretation and integration. Delegate genuinely independent work or review after assigning file/state ownership. Reviewer findings are evidence to validate, not instructions to expand scope.

| Slice | Deliverable | Completion condition |
|---|---|---|
| 1. Verification baseline | macOS CI, deterministic async test fixes, feature-preservation fixtures | Workflow runs on macOS; existing deterministic tests pass; current manual baseline and verification gaps are recorded |
| 2. Clipboard and destination | Shared clipboard ownership, destination capture/revalidation, recovery UI and truthful trace outcomes | Cases 8 and 9 pass; destination checks are proved in the Mac editors before later work consumes their contract |
| 3. Dictation lifetime | One operation owner, one typed receive path, propagated failures, bounded finishing, cancellation through revision, derived dictation presentation | Cases 1 through 7 pass; final audio order is preserved; obsolete session/relay coordination is removed; signed dictation remains usable |
| 4. Reading lifetime | Bounded playback, replacement cleanup and derived reading presentation | Case 10 passes; selection reading remains usable in the signed app |
| 5. MCP admission | Acknowledged local speech requests integrated with the coordinator | Case 11 passes in both supported MCP protocol modes and in the signed two-process exchange |
| 6. Settings compatibility | Settings validation and remaining compatibility checks | Case 12 passes; invalid speed cannot crash encoding or reach the speech endpoint |

Presentation and documentation changes land with the feature that owns them. After these slices, run one whole-feature review and the complete signed-app checklist. Do not postpone recovery, trace accuracy or cancellation hints to a final cleanup slice.

Keep commits or PRs focused on the slices. Establish the small shared contracts before parallel implementation. Temporary transition boundaries must be named and removed by the slice that replaces them.

At each slice, run targeted checks, obtain useful independent review, resolve real defects, and perform a deletion/simplification pass. Do not start an open-ended review loop or add infrastructure for hypothetical future requirements. Keep the app usable at each checkpoint; complete the full acceptance contract before calling the rewrite finished.
