# Workstream 2: Own clipboard and destination

Status: Accepted. G2 and G3 passed; one remediation pass used; fresh closure passed.

## Task packet

### Outcome

The existing app uses one clipboard owner and verifies the editing destination before paste and automatic Return. Lost or unverifiable destinations leave recoverable final text in Last Dictation without stealing focus.

### Scope

Implement a main-actor clipboard service owning selection Copy, insertion, restoration and pending cleanup. Replace the independent `Inserter`/`Pasteboard` coordination rather than preserving facade aliases. Adapt the current controller and Reader to the accepted service; these are permanent integration changes, not a second implementation for the future dictation rewrite.

Implement destination capture and verification with retained application/window/editing-target identity. Public Accessibility APIs and `CFEqual` are a starting implementation approach, not evidence that identity is stable in every editor. Use bounded lookups outside event-tap callbacks. Treat query failure, invalid elements and missing identity as unavailable. Do not compare only application PID or a text value. Preserve the original screen-selection behavior independently of target identity.

Run G2 against the adapter before freezing its concrete handoff. Use a small temporary signed probe or adapter test if needed; remove probe code before acceptance. Keep tested production adapter code. Capture the destination synchronously in operation order when entering finishing, including hard cap/reply commit/failure, before long revision awaits. Queries may be asynchronous but must detect focus changes during capture instead of adopting a later field silently.

Integrate a narrow finishing-transition effect in the current session/controller. Explicit stop and internally triggered hard-cap/failure paths must invoke the same operation-bound capture exactly once before drain/final revision work. Buffered snapshot observation is insufficient for this effect. Keep Accessibility types in the app target and record the callback/dependency contract for workstream 3; do not rewrite the session state machine in this slice.

Define the insertion boundary and perform a final cancellation/destination check immediately before clipboard mutation. Revalidate before Return. A skipped paste is recovery; a skipped Return after paste never repeats insertion. Complete cleanup once transaction ownership starts.

Extend trace outcomes to distinguish final available text from attempted insertion and attempted/skipped sending. Update Last Dictation with explicit Copy and recovery text; its word marks compare cleanup output rather than falsely depicting skipped insertion as total deletion. Preserve trace retention, JSON export and window activation. No automatic window opening or clipboard copying on recovery.

### Non-goals

Do not rewrite STT or revision, introduce persistent history, restore another app's focus, promise editor acknowledgement of synthetic paste, or create a generic clipboard API mirroring `NSPasteboard`. Full finalisation cancellation belongs to workstream 3. Reading playback ownership belongs to 4; this slice only makes its selection path cooperate with shared cleanup.

### Initial ownership

- `Sources/EchoTypeApp/Inserter.swift`, `Pasteboard.swift`, new focus/clipboard adapter files in that target.
- `DictationController.swift`, `Reader.swift` for clipboard integration; `OverlayPanel.swift` only for separating/reusing focus lookup.
- `Sources/EchoTypeCore/DictationTrace.swift`, `Tests/EchoTypeCoreTests/DictationTraceTests.swift`, `Views/LastDictationWindow.swift`.
- `Sources/EchoTypeCore/SessionMachine.swift` and `Tests/EchoTypeCoreTests/SessionMachineTests.swift` only for the finishing-transition effect and its ordering tests; full lifecycle ownership transfers to workstream 3.
- `Tests/EchoTypeAppTests/ClipboardTests.swift` and `DestinationTests.swift`; package test registration if needed.
- Affected decision records 0020/0023 and their index, this record, row 2/G2/G3 and escalations.

### Required seams

Publish concrete declarations and usage in the handoff: opaque destination token, match/changed/unavailable verification, cancellation-aware insertion transaction result and awaitable pending clipboard cleanup. Tests control ownership policy with small closures or a focused dependency, not framework replicas. Once accepted, workstreams 3 and 4 consume this API.

Also publish the finishing-transition dependency and its stop/hard-cap/failure ordering. Workstream 3 preserves that behavior when replacing the session implementation; it must not infer destination from a later presentation snapshot.

Clipboard writes from other apps that invalidate known ownership must not be restored over. A Copy change count cannot prove source attribution. Record late-copy and writer-attribution limits rather than claiming protection unavailable through public APIs. Preserve all saved pasteboard types and the current empty-original behavior.

### Acceptance criteria

- Spec cases 8 and 9 pass with the current app. Same-window field changes, unavailable focus and focus changes before Return produce the specified outcomes.
- Synthetic modifiers remain explicit. Only one paste is attempted per result and Return requires a successful eligible dictation plus matching destination.
- Copy and insertion serialize ownership. A stopped reader's pending Copy cannot corrupt a later insertion or restoration.
- Available final text is recoverable and copyable without claiming delivery. Failed/cancelled/empty/test/reading retention rules remain accurate.
- G2 establishes usable identity in native, terminal and Electron targets, or returns an evidence-backed scope escalation. G3 verifies signed paste/copy/restoration and recovery.
- There are no unused probes, aliases or duplicate restoration state.
- Focus capture runs once at finishing entry on explicit stop, hard cap and recoverable failure, before asynchronous drain/revision; cancellation does not capture a new destination.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'ClipboardTests|DestinationTests|SessionMachineTests|dictationTraceMarks'
swift build --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-workflow.app
git diff --check
```

Create the named app test suites; verify filters with `swift test list` and add actual session-transition and trace test names to the command if their file names are not suite names. Do not accept a zero-test run. The signed build command builds without launching or replacing `/Applications`. Hand off Mac instructions for G2/G3 before interacting with the user's editors.

## Implementation handoff

- Base commit: `70bbbd5fc0b973dbd421be1661f1404dd27035c2` on `refactor/macos-lifecycle`. Read the approved specification, decisions 0020/0023 and accepted workstream 1 handoff. Applied `unslop` to these records.
- Outcome: Completed shared clipboard ownership, finishing-entry destination capture, guarded insertion/Return, trace attempts and Last Dictation recovery. The unchanged production destination adapter passed G2 before integration. Aidan explicitly approved Ghostty 1.3.1 and confirmed its Find switch stayed in the same window; Terminal.app remains unverified. Independent review found R1. Its correction is recorded below; fresh closure and G3 remain pending.
- Files changed: Added app `Clipboard.swift`, retained `Destination.swift` and its tests, deleted `Inserter.swift`/`Pasteboard.swift`, and adapted `DictationController.swift`, `Reader.swift`, `Views/LastDictationWindow.swift`, core `DictationTrace.swift`/`SessionMachine.swift` and their tests. Added `Tests/EchoTypeAppTests/ClipboardTests.swift`. Updated decisions 0020/0023 and their index. The lead authorised a narrow ownership extension to `Views/Pill.swift`/`PillView.swift` so the clipboard transaction has an inserting phase without a cancellation hint. The lead owns `plan.md` and the other record sections.

### Concrete clipboard and destination contract

All clipboard and destination access stays in the app target on the main actor. `Destination` is an opaque retained token for consumers; it holds Accessibility application, window and target objects. It is not a PID-only or text-value identity. The accepted declarations are:

```swift
struct Destination

enum DestinationVerification: String {
  case matching, changed, unavailable
}

@MainActor struct DestinationFocus {
  init()
  func capture() -> Destination?
  func verify(_ destination: Destination?) -> DestinationVerification
}

@MainActor final class Clipboard {
  struct InsertionResult: Equatable {
    var insertion: DictationTrace.Insertion
    var sending: DictationTrace.Sending
  }

  init(access: Access = .system)
  func waitForCleanup() async
  func copySelection(cancelled: @escaping @MainActor () -> Bool) async -> String?
  func insert(
    _ text: String, destination: Destination?, sends: Bool,
    verify: @escaping @MainActor (Destination?) -> DestinationVerification = DestinationFocus().verify,
    cancelled: @escaping @MainActor () -> Bool,
    onBegin: @escaping @MainActor () -> Void = {}
  ) async -> InsertionResult
  func copy(_ text: String) async
}
```

`Clipboard.Access` is the focused test dependency: change count, save all items, restore items, read text, write text, post a key and wait. It uses actual `NSPasteboardItem` values rather than a second pasteboard framework. System save copies every available type from every item. Production consumers use the default access.

The service serializes transactions by chaining owned tasks. The cancellation closure reads the caller's operation state, not the service task's cancellation. A queued cancelled selection does not issue Copy. Once Copy is posted, its entire 300 ms response window and necessary restoration finish even if its reader stops. Reader checks cancellation after acquiring text. Insertion waits for earlier cleanup, checks cancellation/focus, saves contents, and checks again immediately before its write. `onBegin` runs synchronously at that boundary; the controller then stops handling/advertising Escape. Empty text never writes or posts keys. Once ownership starts, the service completes eligible Return and restoration without consulting cancellation again.

Command+C and Command+V use explicit Command flags; Return uses empty flags. Paste is posted once. Eligible Return waits 200 ms, revalidates the destination, and records attempted or skipped sending. Restoration follows the full 800 ms paste window and runs only if the saved snapshot stayed valid through the pre-write checks and the service still owns its write count. An empty original pasteboard leaves inserted text, preserving baseline behavior. Explicit Last Dictation Copy queues after synthetic cleanup and has no restoration.

`waitForCleanup()` awaits transactions queued at call time. Workstream 4 can await it when replacing a reader; selection Copy and insertion already serialize internally. No consumer should create its own restoration state or synthetic paste/Return path.

### Finishing-transition contract for workstream 3

The platform-neutral dependency added to the current session is:

```swift
public init(
  transport: any WebSocketTransport, settings: Settings, clock: any SessionClock,
  onFinishing: @escaping @Sendable () async -> Void = {}
)
public func enterFinishing() async
```

The callback has one retained, awaitable task per session. Repeated/concurrent finishing requests await that same task. Cancellation joins an effect already requested but never starts another. The app callback performs synchronous double-sampled `DestinationFocus.capture()` on the main actor, skips capture if cancellation has already won, and stops capture. It performs no work in the event-tap callback. Original `NSScreen.forFocusedWindow()` selection remains separate.

Explicit stop and detected reply call `await session.enterFinishing()` before stopping/draining capture. The audio pump triggers protocol finalisation after the remaining chunks. Hard cap calls the same effect before finalizing and sending closing frames. Recoverable audio failure invokes it before trigger; unsolicited transcription/socket/malformed-frame failure or closure invokes it before returning the outcome and before final revision. No buffered snapshot supplies the destination. Workstream 3 must preserve those entry points and once-only ordering while replacing the broader session/protocol implementation. Existing RelayTransport, send-error/drain ordering, deadlines and full revision cancellation remain that packet's work; this slice does not claim to fix them.

The current controller keeps a narrow insertion cancellation latch through final revision and supplies it at the clipboard boundary. During a started transaction Escape belongs to the focused editor. The service returns insertion/sending results after cleanup. Later work should move this latch and destination into its operation owner while consuming the same boundary contract.

### Trace and recovery

`DictationTrace.finalText` holds available cleanup output. `insertion` is notAttempted, attempted, cancelled or skipped with changed/unavailable destination; `sending` is notRequested, attempted or skipped. Transcript success is `Outcome.completed`, independent of delivery. The obsolete `inserted` field/outcome are removed, and word marks use finalText with changed words named `revised`. No persistent history requires decoding old exports.

Last Dictation displays final text and explicit Copy text, retains JSON export, and explains attempted/skipped paste or Return. Marks compare streamed words against cleanup output even when paste was skipped. Recovery updates the last trace and shows a brief pill message, without opening a window, stealing focus or copying automatically. Cancellation retains diagnostics but clears final recovery text. Failed and empty dictations retain their existing trace policy; tests and readings do not replace Last Dictation. Failed dictations never qualify for Return.

### Verification and remaining limits

- `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` confirmed 30 selected test declarations. `swift test --filter 'ClipboardTests|DestinationTests|SessionMachineTests|dictationTraceMarks'` passed 20 core tests and 10 app tests. These include four finishing path arguments, retained-effect ordering, stopped Copy versus queued insertion/explicit Copy, external ownership loss, all saved item types, empty-original behavior, boundary cancellation, destination recovery, Return suppression, flags and JSON recovery marks. Tests use explicit stream acknowledgements and one-minute suite limits, without desktop services or real clipboard writes. A session-only run after adding its actor-local trigger acknowledgement passed all 18 session tests.
- `swift build --product EchoTypeApp`, `./scripts/build-app.sh debug .build/EchoType-workflow.app`, strict deep signature verification and `git diff --check` passed. Logs are `.build/clipboard-focused-tests.log`, `.build/clipboard-session-tests.log`, `.build/clipboard-build.log` and `.build/clipboard-signed-build.log`; test names are in `.build/clipboard-test-list.txt`. The initial signed candidate was Apple Development, team `LJHNNE925Q`, bundle `com.aidanzealley.echotype`. Its `Contents/MacOS/EchoTypeApp` SHA-256 is `145898115a750539774bc9645c4eebebd80713d61041dc25f312de9289fef28a`.
- Destination adapter SHA-256 remains `ea177e90f8911626459331320e08683bdc53bd64fa82e690c52e6bcafeef0b3b`; its tests remain `2162bd3b28661fc351d13e64d9a6217101fdcff28d1a9c5fe50e28aa7ff8edbe`. G2's successful logs and original failures remain preserved. Removed temporary `.build/destination-probe/Probe.swift` and `.build/EchoType-Destination-Probe.app` after G2 evidence was retained. No probes, aliases or duplicate restore state remain in production.
- Public change counts cannot attribute a first Copy response to its writer. An external write observed first can be mistaken for Copy. A second observed write invalidates restoration. A late Copy response after 300 ms may still affect a later operation. Tests protect known ownership without claiming source attribution or arbitrary late-response protection. Synthetic keys establish attempts, not editor acknowledgement.
- No app/editor interaction, app launch, permissions change, real API-key access, live request, installed-app replacement or run.sh occurred in this implementation pass. Signed clipboard/restoration, recovery UI in both themes and actual target behavior require the lead's G3 gate after closure.
- Simplification: removed both old clipboard owners, delayed DispatchQueue restoration, the polling waitForRestore loop, independent controller Return logic and obsolete trace delivery names. Kept one task chain, one destination token and the narrow finishing callback. No production target, generic effect framework, framework replica, compatibility facade or second pending-restoration record was added.
- Specification drift: none. Ghostty's accepted G2 scope decision and all earlier evidence remain below. Work is uncommitted. The initial implementation was reviewed; the correction below is ready for closure.


### R1 remediation, 2026-09-30

- Used the one authorised remediation pass. Changed only `Clipboard.swift`, `ClipboardTests.swift` and this implementation handoff. Applied `unslop`; left work uncommitted.
- Insertion records the pasteboard count before saving. Immediately before its own write, after final focus verification and `onBegin`, it checks that count again. Restoration requires both that valid saved snapshot and continued ownership of the subsequent write. A detectable external change during save or revalidation now prevents stale restoration. The transaction still posts one paste and preserves final cancellation/focus checks, Return revalidation and cleanup. No retry, second owner or new API was needed.
- Added `externalWriteDuringFinalVerificationInvalidatesSavedSnapshot`. Its matching second verification writes external content and increments the fake board count. The test requires one insertion attempt, one paste and no stale restoration. Existing valid-snapshot and post-write ownership tests remain. `swift test list` confirmed the new declaration; `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter ClipboardTests` passed all seven clipboard tests.
- `swift build --product EchoTypeApp`, `./scripts/build-app.sh debug .build/EchoType-workflow.app`, strict deep signature verification and `git diff --check` passed. Logs are `.build/clipboard-remediation-tests.log`, `.build/clipboard-remediation-build.log` and `.build/clipboard-remediation-signed-build.log`; names are in `.build/clipboard-remediation-test-list.txt`. Rebuilt candidate executable SHA-256 is `4bdd633e56cff9fcabfab85c2963bff142c3ac4703445738c2b9099491a443e8`, superseding the initial candidate hash above. The bundle identity and signing team are unchanged.
- No launch, desktop interaction, permission change, API-key access, live request or installed-app change occurred. Public pasteboard operations remain non-atomic across processes; this correction protects the observed snapshot invalidation rather than claiming writer attribution or an external lock. Fresh closure and G3 remain pending with the lead.

### G2 troubleshooting retry, 2026-09-30

- Observed evidence: `.build/g2-native-stable-1.log` contains twelve appended probe launches, all with unavailable capture. It is not one stable native-editor trial. Initial focused-target queries return API disabled `-25211`. Later TextEdit and Ghostty targets expose AXTextArea and AXWindow but return attribute unsupported `-25205` for AXEnabled. TextEdit's Find field later exposes AXTextField with enabled true. Code and T3 Code Nightly return no value `-25212`; one Code sample returns cannot complete `-25204`. The empty stderr file does not make these successful trials. Logs contain no proven target identity or sufficient editor/version/settings observations for G2.
- Correction and rationale: The enabled check previously turned an unsupported capability into failed destination identity. The retry tolerates exactly AXEnabled attributeUnsupported after the existing role and retained window checks. It still rejects explicit disabled values and every other enabled failure. The installed public SDK `AXError.h` distinguishes unsupported attributes from invalid elements, messaging failures, API disabled and no value. `AXAttributeConstants.h` describes enabled as an interaction flag. Apple's [enabled attribute documentation](https://developer.apple.com/documentation/applicationservices/kaxenabledattribute) describes the same flag and expects views to implement it. The observed TextEdit/Ghostty omission is an interoperability inference, not a promise from the documentation that every focused text area is enabled. Retained application/window/target identity, double sampling, bounded lookups and frontmost PID checks remain intact. No application names or PID-only fallbacks were added. G2 must still establish real-editor stability and rejection on field changes.
- Probe feedback: Temporary probe output now uses direct standard-output writes for each line, so redirected logs are readable while it runs. Startup, capture, each one-second result and all original diagnostic error codes remain present. A final COMPLETE line identifies normal completion. Probe source remains ignored and temporary.
- Focused checks: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter DestinationTests` passed four tests. `swift build --product EchoTypeApp`, probe compilation/signing, `codesign --verify --deep --strict --verbose=2 .build/EchoType-Destination-Probe.app` and `git diff --check` passed. No editor trial was run by the agent. This is a gate troubleshooting retry before independent review, not remediation or a G2 pass.
- Retry SHA-256: Adapter `ea177e90f8911626459331320e08683bdc53bd64fa82e690c52e6bcafeef0b3b`; temporary probe source `7b26d111d9fcb95d6e7fef68976995e0f3342ae29adbbca57677792a67862abb`; signed executable `811439d9ceaa4af99fbe06c7ef801f6f8a0491d98255be3716b4e4bbeac6d2b5`. Signed identity remains `Apple Development: aidan@zealley.com (3MQK9CND62)`, team `LJHNNE925Q`, bundle id `com.echotype.destination-probe`.
- Original evidence preserved byte-for-byte: `.build/g2-native-stable-1.log` SHA-256 `1b92b9442a49029cb1a113d81ea748b29a98eea56bf488c29bcf782513733142`; `.build/g2-native-stable-1.err` SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

Exact retry compile and sign commands, from the repository root:

```sh
swiftc -parse-as-library Sources/EchoTypeApp/Destination.swift .build/destination-probe/Probe.swift -o .build/EchoType-Destination-Probe.app/Contents/MacOS/DestinationProbe
codesign --force --options runtime --timestamp=none --sign 'Apple Development: aidan@zealley.com (3MQK9CND62)' .build/EchoType-Destination-Probe.app
codesign --verify --deep --strict --verbose=2 .build/EchoType-Destination-Probe.app
```

### Recovery checks before desktop G2, 2026-09-30

- Audited the complete tracked and untracked diff against HEAD `70bbbd5fc0b973dbd421be1661f1404dd27035c2` on `refactor/macos-lifecycle`. Ownership matches the partial handoff: destination adapter/tests and packet belong to workstream 2; the lead owns `plan.md`. The frozen Task packet is unchanged. Read the approved spec, decisions 0020/0023 and workstream 1's accepted handoff. Applied `unslop` to this record.
- `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` confirmed the four DestinationTests; the matching filtered run passed all four. `swift build --product EchoTypeApp` and `./scripts/build-app.sh debug .build/EchoType-workflow.app` passed. Strict signature verification passed for both the rebuilt app candidate and existing probe.
- Adapter, probe source, signed probe executable and original evidence hashes still match the troubleshooting record above. Probe signing identity, team and bundle identifier also match. The adapter remains isolated from insertion and session code; no duplicate restoration state, compatibility alias or removable production probe was introduced. No code changes were needed for these checks.
- These are recovery checks only. No contract defect was established by static inspection or focused tests, and no editor identity or clipboard gate passed in this pass. The lead owns desktop evidence. G2 still precedes integration and independent review; no remediation pass was consumed. Left work uncommitted and changed only this subsection.
- Fresh implementer recovery for the foreground retry reconfirmed the same base and file ownership, read the complete adapter/test candidate and surrounding insertion/focus code, and reran `swift test list` plus the filtered DestinationTests. All four passed. Strict signatures on the existing app and probe passed; adapter/probe source/executable and original evidence hashes still match. The Task packet is unchanged. No contract defect or useful deletion was found in this partial adapter, so production code and the provisional contract remain unchanged. This pass changed only this handoff subsection and did not build, launch or operate an editor.

### Recovery audit of supplied terminal-labelled logs, 2026-09-30

- Applied `unslop` and audited the complete adapter/test candidate against base `70bbbd5fc0b973dbd421be1661f1404dd27035c2` on `refactor/macos-lifecycle`. The frozen Task packet matches the base. Read the specification, decisions 0020/0023, repository README, plan and accepted workstream 1 handoff. No adapter contract defect or useful deletion was found. Clipboard and finishing integration remain pending; this audit changes only this appended handoff subsection.
- `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` confirmed all four DestinationTests, and the filtered run passed all four. Strict signature verification passed for the existing app and probe. Adapter, probe source/executable, original evidence and all ten real-foreground evidence hashes match the recorded values. Probe identity remains `com.echotype.destination-probe`, Apple Development `aidan@zealley.com (3MQK9CND62)`, team `LJHNNE925Q`. DestinationTests source SHA-256 is `2162bd3b28661fc351d13e64d9a6217101fdcff28d1a9c5fe50e28aa7ff8edbe`.
- The four `.build/g2-retry-terminal-*.log` files identify Ghostty `com.mitchellh.ghostty`, not Terminal.app. Each stable trial has available AXTextArea capture, twelve matching samples and COMPLETE. The switch has seven matching samples followed by five changed samples; later diagnostics expose AXTextField. Stable log suffixes are `stable-1-20260930-094224-4948-31848`, `stable-2-20260930-094259-4948-5224` and `stable-3-20260930-094326-4948-21007`; each SHA-256 is `60f84fb4af395989bb7ec47f115fed0cc5c81eab9bb1a5674f04c2ff12ac391e`. Switch suffix is `switch-20260930-094408-4948-5705`, SHA-256 `f9afc7ed817c36614f28f3dcd78322924a68938be8dcad0a3d00a00d44b257fd`. All four stderr files are empty with the recorded empty-file hash. These logs establish Ghostty stability and rejection after a control change, but do not record its version, Find action or whether the switch stayed in the same window.
- E2-G2-TERMINAL specifically requests Terminal.app, and E2-G2 excludes automatic Ghostty substitution. Aidan's reported completion supplies evidence, not an explicit scope decision. The lead must settle the target mismatch before clearing G2. Existing native/Electron and ancillary evidence remains valid. No desktop interaction, probe launch, permission change, implementation correction, independent review or remediation occurred in this audit. No remediation pass was consumed; work remains uncommitted.

## Independent review

- Reviewer: fresh independent subagent, 2026-09-30. Applied `unslop` to this record. Read the workflow, approved specification, plan, decisions, repository README and accepted workstream 1 handoff.
- Reviewed base: `70bbbd5fc0b973dbd421be1661f1404dd27035c2`. Inspected the complete tracked and untracked workstream diff and surrounding controller, Reader, session, clipboard, focus and presentation code. The lead's narrow Pill/PillView ownership extension is within this review. G2 Passed with Aidan's approved Ghostty target and same-window Find confirmation; the adapter and tests retain their recorded hashes.
- Verdict: Required finding R1 blocks code acceptance. G3 remains a separate pending gate after closure.
- Required findings:
  - R1: Insertion can restore a stale snapshot over a newer external clipboard write made during its final destination lookup. `Sources/EchoTypeApp/Clipboard.swift:101-111` saves the board, then runs another destination verification before writing. That verification makes bounded synchronous Accessibility calls, during which another process can change the board. The service records only the count after its own write. At `:125` that count can still match, so it restores the snapshot from before the external write. Concrete sequence: save content A at count 1; another app writes B at count 2 during the second verification; EchoType writes its transcript at count 3; no later change occurs; restoration returns A and loses B. This is a detectable clipboard snapshot invalidation, separate from the documented unknown writer of a synthetic Copy response. Protect the saved snapshot across the save-to-write interval so an observed newer write cannot later cause stale restoration. Keep final cancellation/focus checks and single-paste behavior. Add one focused test that changes the fake board count during the second verification; the existing external-writer test at `Tests/EchoTypeAppTests/ClipboardTests.swift:68-77` changes it only after insertion has written.
- Optional observations: none.
- Questions: none.
- Checks and positive evidence:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'ClipboardTests|DestinationTests|SessionMachineTests|dictationTraceMarks'` passed all 20 selected core tests and 10 app tests. `swift build --product EchoTypeApp` and `git diff --check` passed. Existing signed candidate passed `codesign --verify --deep --strict --verbose=2`; its executable SHA-256 matches `145898115a750539774bc9645c4eebebd80713d61041dc25f312de9289fef28a`.
  - Clipboard task chaining serializes stopped selection Copy, insertion and explicit Copy. Cleanup survives caller cancellation. Empty-original behavior, explicit key modifiers, one paste, Return revalidation and post-write external ownership loss are covered by meaningful deterministic tests. Public Copy attribution and late-response limits are documented without claiming stronger guarantees.
  - Finishing requests retain and await one callback task, run it before protocol closure/final revision, and avoid starting it for cancellation. The app captures synchronously within that callback and keeps screen selection separate. Broader session cancellation, hard-cap drain/send ordering and lifecycle replacement remain workstream 3 responsibilities; this review does not reopen them.
  - Available final text, paste/Return attempts and recovery are separate trace fields. Last Dictation exposes explicit queued Copy without automatic activation/copy, and marks compare cleanup output. The insertion boundary removes Escape handling and its hint. The old clipboard owners and independent controller Return path are deleted without aliases or duplicate restoration state.
  - No desktop interaction, app launch, permission change, real key access, live API request, installed-app replacement or launcher was used. Deterministic checks and signature verification do not establish signed clipboard delivery or the pending G3 behavior.

## Resolution

- Finding dispositions: Required R1 accepted. A saved pasteboard snapshot can become stale during bounded AX revalidation before the service's write. The post-write count cannot establish the earlier snapshot's ownership. Protect the snapshot across save and final verification, retain final cancellation/destination checks, and restore only a snapshot whose pre-write count remained valid. This is a detectable external-write boundary, separate from Copy source-attribution limits. One remediation pass authorised and consumed by the following assignment.
- Simplification/deletion pass: Removed Inserter/Pasteboard and independent Return/restoration state, without aliases. R1 adds only snapshot validity and a meaningful external-writer test. The final lead pass found no duplicate ownership, hypothetical retry machinery or unused production probes. Temporary G2/G3 probes removed; all gate logs preserved. Pill/PillView ownership extension is limited to hiding Escape at the existing insertion boundary.
- Final verification: R1 remediation and fresh closure passed all seven ClipboardTests. Lead reran the complete selected filter with live variables empty: 20 core tests and 11 app tests passed. App build, strict production candidate signature and diff checks passed. G2 and G3 passed at their required placement. Complete changed-file ownership and frozen Task packet audited against base `70bbbd5`. One remediation pass used; no further implementation change. Terminal.app remains unverified.

## Closure review

- Reviewer: fresh closure subagent, 2026-09-30. Applied `unslop`. Read the workflow, approved specification, packet, dependency handoff and accepted R1/resolution. Reviewed the correction and its affected insertion/restoration path without reopening broad review.
- Verdict: R1 resolved. Code closure passes. G2 remains Passed; G3 remains pending with the lead before acceptance.
- Remaining required findings: none. No release-blocking defect introduced by the correction was found.
- Evidence: Insertion records the change count before saving and compares it again after final destination verification and `onBegin`, immediately before writing. A detectable external change during that interval makes `snapshotValid` false. Restoration now requires both that valid snapshot and ownership of the later insertion write, so the accepted A/B/transcript sequence cannot restore stale A. The correction preserves final cancellation/focus checks, one paste, Return revalidation, serialized cleanup and empty-original behavior. It adds no retry, API or second restoration owner.
- Checks: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` confirmed all seven ClipboardTests, including `externalWriteDuringFinalVerificationInvalidatesSavedSnapshot`. The same environment with `swift test --filter ClipboardTests` exited 0 with all seven passing. The new test changes external content/count during the second verification and observes one paste with no stale restoration. Existing tests cover valid-snapshot restoration and ownership loss after the service's write. `git diff --check` passed. The rebuilt candidate executable SHA-256 matches `4bdd633e56cff9fcabfab85c2963bff142c3ac4703445738c2b9099491a443e8`.
- Limits: Public pasteboard operations remain non-atomic across processes. The check detects observed snapshot invalidation; it does not establish Copy writer attribution or lock out an external write between individual API calls. No implementation, plan or other record section was edited. No desktop interaction, synthetic keys, app launch, permission change, key access, live API request, installation or launcher was used. Signed clipboard delivery and recovery UI remain G3 checks.

## External validation

- Gate and placement: G2 passed during implementation before independent review. G3 passed after fresh closure and before acceptance.
- Status: G2 and G3 Passed. G2 uses native TextEdit, Electron VS Code and Aidan-approved Ghostty, including confirmed same-window Find. Terminal.app remains unverified. G3 uses reviewed production service code in a separately signed controlled driver. Earlier troubleshooting entries below are historical evidence, not current blockers.
- Candidate: Uncommitted destination adapter/tests on `refactor/macos-lifecycle`, base `70bbbd5fc0b973dbd421be1661f1404dd27035c2`. Adapter SHA-256 `ea177e90f8911626459331320e08683bdc53bd64fa82e690c52e6bcafeef0b3b`. Signed probe `.build/EchoType-Destination-Probe.app`, bundle identifier `com.echotype.destination-probe`, signed by Apple Development with team `LJHNNE925Q`. Executable SHA-256 `811439d9ceaa4af99fbe06c7ef801f6f8a0491d98255be3716b4e4bbeac6d2b5`. Probe source is `.build/destination-probe/Probe.swift`; compile command is `swiftc -parse-as-library Sources/EchoTypeApp/Destination.swift .build/destination-probe/Probe.swift -o .build/EchoType-Destination-Probe.app/Contents/MacOS/DestinationProbe`. Rebuild and sign only if the adapter changes, then record new candidate hashes.

### Earlier bound-window retry, superseded by real foreground evidence

- Authorisation: Aidan explicitly authorised direct editor testing in E2-G2. The lead used the native computer-use API with an empty disposable TextEdit `Untitled 2`, preserving the existing document. No user text was typed or read, clipboard operation performed, permission changed, editor setting changed, installed app replaced or live API request made. The disposable window was closed without changing the original.
- Trials: Launched the existing signed probe twice through the packet's separate LaunchServices helper. Clicking TextEdit's text view and invoking its exposed Raise action both produced native UI state showing the intended field focused. Both probes instead reported T3 Code Nightly `com.t3tools.t3code`, CAPTURE available, twelve matching samples and COMPLETE. Neither trial counts toward G2; they sampled the wrong foreground app. A native Command+F exposed TextEdit's separate Find field, but bound focus is insufficient evidence of production destination focus. The optional documented `cua.computer.launch_app` method is unavailable in this runtime.
- Evidence: `.build/g2-agent-native-stable-1.log` and `.build/g2-agent-native-raised.log` each have SHA-256 `3120bbcc02a146bd801fdb40ca49d8924c1765c5608f5998717ec16308f83d05`. Their separate `.err` files are empty, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Existing candidate and original evidence hashes remain unchanged. Installed TextEdit version is 1.21 and VS Code is 1.139.1; no VS Code or Terminal trials were attempted once the foreground mismatch was established.
- Earlier disposition: Bound-window interaction did not establish foreground identity. The real foreground retry below resolves this limitation; it did not prove TextEdit unsupported or justify relaxing retained identity. The adapter remains provisional. The now-resolved E2-G2-FOREGROUND requested real foreground activation. The retry below supplies successful native/Electron evidence. No gate pass, supported-scope waiver, independent review or remediation is claimed. Temporary probe artifacts remain available for the required retry.

### Real foreground retry, 2026-09-30

- Applied `unslop`. A fresh implementer audited the owned diff and retained contract, reran all four DestinationTests, verified app/probe signatures and all recorded candidate/original hashes. No implementation correction was needed. Base remains `70bbbd5` on `refactor/macos-lifecycle`; frozen Task packet unchanged. No review or remediation pass was consumed.
- Aidan's E2-G2 and E2-G2-FOREGROUND answers explicitly authorise disposable editor interaction and foreground activation. Standard `/usr/bin/open -a TextEdit` and `/usr/bin/open -a 'Visual Studio Code'` solved actual activation. The existing signed probe then captured the intended bundle identities. Bound native APIs handled disposable windows, Find switches and cleanup. No AppleScript, permission changes, synthetic text, clipboard changes, live requests or installed EchoType replacement were used.
- Native evidence: `.build/g2-open-native-stable-{1,2,3}.log` each captured TextEdit `com.apple.TextEdit`, available AXTextArea and twelve matching samples. Version 1.21. Each SHA-256 is `882ba289b3b516795aa7e099cacb3637ce1f65e037dd620873797e79cf7f4c1a`. `.build/g2-open-native-switch.log` shows ten matching samples then two changed after native Command+F focused the separate Find AXTextField in the same empty `Untitled 2` window. Its SHA-256 is `696b895dd5a99aa7f2b4429d4bdaf3e6398d5eb93779716640e5b60c470f54d3`. The tool call followed observed capture and two samples; probe evidence places the effective switch before sample eleven. This satisfies post-capture rejection without claiming an exact ten-second switch.
- Electron evidence: `.build/g2-open-electron-stable-{1,2,3}.log` each captured Code `com.microsoft.VSCode`, available AXTextArea and twelve matching samples. Version 1.139.1. Each SHA-256 is `e3d3fe64502b3d9a8f97c3204046fe313f7fdc11823c08deb80fad780d94d488`. `.build/g2-open-electron-switch.log` has ten matching then two changed after Command+F focused the separate Find control in empty `Untitled-1`; hash `368c1cca119fd45cddc3c969724acd4593ac69a9b49267a4f6a240df3d458989`. The existing user setting is `editor.accessibilitySupport: off`, confirmed by a targeted read; it was not changed. Native UI describes the editor as not accessible in screen-reader mode, but the production probe exposes usable AXTextArea identity. Gate evidence comes from the production adapter, not that label.
- Ancillary evidence: `.build/g2-open-focus-away.log` captured TextEdit, matched four times, then changed for eight samples after standard open activated Code at ten seconds after launch. SHA-256 `1e3c6b9d267100112885487496b5a55dac8ee2fd9a2e1266a01826417e8073db`. `.build/g2-open-unavailable.log` captured System Settings `com.apple.systempreferences` sidebar AXOutline as unavailable and returned twelve unavailable samples; hash `000902502b26938a91b383d9477cd2dce4331215e679ffa543918150e01a5ce9`. No settings were changed. All ten trials ended COMPLETE, and all separate `.err` files are empty with SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
- Remaining blocker: `cua.getApp("Terminal")` returned `Computer Use is not allowed to use the app 'com.apple.Terminal' for safety reasons.` No Terminal window was opened or manipulated through another tool. This explicit denial is distinct from the resolved foreground issue. E2-G2-TERMINAL asks Aidan for three stable Terminal trials and one same-window Find switch. G2 cannot pass before those results or an evidenced user scope decision.
- Cleanup: Closed only the empty disposable TextEdit `Untitled 2` and VS Code `Untitled-1`. Native state confirmed the original TextEdit document and `test.txt` tab remain. No user document content was edited. Probe artifacts and logs remain for the unfinished gate. E2-G2-FOREGROUND is resolved into this record and the plan decision log. No independent review/closure was spawned because G2's required placement precedes them.

### G2 instructions for Aidan

The probe never types, copies, pastes or activates a target. It takes a destination snapshot five seconds after launch, then prints twelve once-per-second comparisons. Logs contain app identity, target role, enabled/window availability and Accessibility error codes. They contain no field text. The probe exits at about seventeen seconds; logs are complete after it exits.

1. If needed, add `.build/EchoType-Destination-Probe.app` to System Settings > Privacy & Security > Device Control and Data Access, called Accessibility on older macOS versions. The probe has a separate identity from EchoType. In the file picker, Command+Shift+G can navigate to `/Users/aidanzealley/code/echotype/.build/EchoType-Destination-Probe.app`. Do not grant microphone access or launch the normal EchoType candidate for G2. A permission failure must be recorded and retried after the grant, rather than counted as an unsupported editor.
2. Prepare disposable targets in TextEdit, Terminal.app and Visual Studio Code. In TextEdit use an untitled document; Command+F exposes a separate editable Find field in the same document window. In Terminal use a disposable local shell window; Command+F exposes its separate editable Find field. A split view can show the same shell session, so it is not evidence of a different editing target. In Visual Studio Code use an untitled text editor; Command+F exposes its separate editable Find field. Record the actual app names/versions. If VS Code is unavailable, ask to settle an installed Electron editor before substituting it. Record current editor accessibility settings; do not silently enable a different mode to hide an initial failure.
3. Use the complete `run_g2` function retained below. It generates fresh filenames, streams visible results and reports counts after twenty-five seconds. Keep Terminal visible alongside the editing target if possible; watching output must not change focus during a stable trial.
4. Run the nine stable trials, three same-window switch trials, focus-away and unavailable-control trial listed in that escalation. Focus the intended target within five seconds; switch trials change focus after capture at about ten seconds. Retain both files for every attempt, including failures. Each stable trial needs CAPTURE available and twelve matching samples. Switched focus must stop matching.
5. Return the new logs plus actual editor names/versions, focused controls, switch timing and Electron accessibility settings. The escalation specifies permission retry steps and what to do when capture remains unavailable.

G2 passes only when unchanged editing-target identity is stable in all three editor categories, same-window changes are detected, and unsupported focus fails conservatively. These checks establish the focus adapter only. They do not prove synthetic paste delivery or clipboard behavior. An editor that cannot expose usable identity needs evidence and a supported-scope decision before proceeding.

### Earlier remaining gate work, resolved by the acceptance evidence below

- G3 instructions will accompany the completed reviewed clipboard/controller candidate. Required checks include signed selection Copy and all-type restoration, an external clipboard write during pending cleanup, stopped reading during Copy followed by insertion, destination loss before paste and destination loss between paste and Return. No live xAI request is implied; a temporary controlled result driver may be needed.
- Attempts and lasting decisions: Twelve user attempts share the original native-stable log; none captures usable identity. Preserve API-disabled, unsupported-enabled and Electron no-value failures as detailed in the troubleshooting handoff. Aidan's answer reports attempted testing, not a gate pass or supported-scope waiver. The corrected probe flushes progress and prints COMPLETE. Repeat only unresolved trials with unique filenames using the helper below. Adapter remains provisional; no clipboard contract is frozen.
- Resume condition: Aidan resolves E2-G2-TARGET by approving Ghostty and confirming its same-window Find switch, or supplies the requested Terminal.app trials. Resume implementation from the adapter candidate, finish the clipboard/controller/session/trace/UI work, remove probe code after the gate, run targeted tests and then proceed to independent review. G3 must pass on the final candidate before acceptance.

### Audit of Aidan's four terminal-labelled trials, 2026-09-30

- Applied `unslop`. E2-G2-TERMINAL's answer was "All done, and I think everything passed." The logs do pass their sample checks, but identify Ghostty `com.mitchellh.ghostty` throughout, not Terminal.app. Installed Ghostty's Info.plist reports 1.3.1, build 15212. No desktop interaction was used to obtain that version.
- Stable logs are `.build/g2-retry-terminal-stable-1-20260930-094224-4948-31848.log`, `...stable-2-20260930-094259-4948-5224.log` and `...stable-3-20260930-094326-4948-21007.log`. Each has available AXTextArea capture, twelve matches, no changed/unavailable samples and COMPLETE. Each SHA-256 is `60f84fb4af395989bb7ec47f115fed0cc5c81eab9bb1a5674f04c2ff12ac391e`.
- Switch log `.build/g2-retry-terminal-switch-20260930-094408-4948-5705.log` has seven matches followed by five changed samples and COMPLETE. Later diagnostics identify AXTextField instead of AXTextArea. SHA-256 is `f9afc7ed817c36614f28f3dcd78322924a68938be8dcad0a3d00a00d44b257fd`. Effective switch occurred between samples seven and eight, about twelve to thirteen seconds after launch. Logs omit window identity diagnostics, so Aidan must confirm the same-window Find action. All four corresponding stderr files are empty with the previously recorded empty-file hash.
- Lead and fresh implementer re-audited all ten native/Electron/ancillary logs. Counts, app identities, COMPLETE markers, stderr and hashes match the real foreground record. Candidate adapter, source, executable and original failure-evidence hashes remain unchanged; strict signed-probe verification passes. HEAD is the recorded base `70bbbd5`; all changes belong to packet 2 and its plan records. Frozen Task packet unchanged. Fresh implementer reran the four DestinationTests successfully. No production change was needed.
- G2 remains Troubleshooting. Earlier instructions explicitly requested Terminal.app and rejected automatic Ghostty substitution. E2-G2-TARGET asks to approve Ghostty for the terminal category and confirm same-window Find, or supply the Terminal.app trials. This is a tested-target decision, not proof that Terminal.app is unsupported. The resolved E2-G2 and E2-G2-TERMINAL answers remain in this record; foreground authority remains in the plan decision log.
- No editor/probe/app was launched, Terminal accessed, clipboard changed, permission changed or live request made. Computer-use denial was not bypassed. Independent review and closure remain unstarted because G2 precedes them; remediation passes consumed: zero. Preserve the provisional adapter and probe uncommitted until the gate is resolved.

### Retained G2 helper

Run this block once in Terminal. It defines a helper that opens only the separate signed probe through LaunchServices. Each call uses a distinct timestamped `.log` and `.err`, streams output into Terminal and prints a summary. Keep Terminal visible beside the target if practical. Click the intended editing control within five seconds and keep it focused until COMPLETE. Output finishes in about seventeen seconds; the helper prints its summary after twenty-five seconds. Do not start the next trial until the summary appears.

```sh
cd /Users/aidanzealley/code/echotype
run_g2() {
  local trial="$1"
  local stamp="$(date +%Y%m%d-%H%M%S)-$$-$RANDOM"
  local log="$PWD/.build/g2-retry-${trial}-${stamp}.log"
  local err="$PWD/.build/g2-retry-${trial}-${stamp}.err"
  touch "$log" "$err"
  echo "Starting $trial. Click target within 5 seconds. Logs: $log and $err"
  open -n -g --stdout "$log" --stderr "$err" .build/EchoType-Destination-Probe.app || return
  tail -n +1 -f "$log" "$err" &
  local watcher=$!
  sleep 25
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  awk '/^CAPTURE / {capture=$2} /^\+[0-9]+s matching$/ {matching++} /^\+[0-9]+s changed$/ {changed++} /^\+[0-9]+s unavailable$/ {unavailable++} /^COMPLETE / {complete=1} END {printf "RESULT capture=%s matching=%d changed=%d unavailable=%d complete=%d\n", capture, matching, changed, unavailable, complete}' "$log"
  echo "Finished $trial. Retain $log and $err, including any failures."
}
```

1. Check System Settings > Privacy & Security > Device Control and Data Access, called Accessibility on older macOS versions. Enable the separate `.build/EchoType-Destination-Probe.app`; it is distinct from EchoType. To find it in the add dialog use Command+Shift+G and `/Users/aidanzealley/code/echotype/.build/EchoType-Destination-Probe.app`. If a trial reports `-25211`, retain its files, check the grant and retry as a fresh call. Do not grant microphone access. The agent has not changed permissions.
2. Prepare disposable editing controls in an untitled TextEdit document, a separate Terminal.app local-shell window and an untitled VS Code editor. Record actual app names/versions and VS Code's current accessibility settings. Keep existing settings for the first attempt. If VS Code is unavailable, name an installed Electron editor for a supported-scope decision before substituting it. Ghostty/T3 Code evidence is retained but does not substitute for these trials automatically.
3. Run these calls one at a time, clicking the named target within five seconds after each starts. Stable trials must show `capture=available matching=12 changed=0 unavailable=0 complete=1`.

```sh
run_g2 native-stable-1
run_g2 native-stable-2
run_g2 native-stable-3
run_g2 terminal-stable-1
run_g2 terminal-stable-2
run_g2 terminal-stable-3
run_g2 electron-stable-1
run_g2 electron-stable-2
run_g2 electron-stable-3
```

4. Run the next calls separately. Start in each editor's original target, then at about ten seconds after launch press Command+F to focus its separate Find field. Leave Find focused. Earlier samples must match; later samples must become changed or unavailable and never match that new field. Terminal split view alone is not a different target. Repeat with a new call if you switched before capture.

```sh
run_g2 native-switch
run_g2 terminal-switch
run_g2 electron-switch
```

5. For `focus-away`, begin in a previously successful editing target and switch to another app at about ten seconds. Later samples must change or become unavailable. For `unavailable`, focus a non-editing control within five seconds, such as the System Settings sidebar, and keep it focused. Capture must be unavailable.

```sh
run_g2 focus-away
run_g2 unavailable
```

### G2 accepted target decision and recovery, 2026-09-30

- Applied `unslop`. Aidan explicitly answered E2-G2-TARGET, "Yes, accept Ghostty; Find opened in the same window." Ghostty 1.3.1 satisfies the terminal category with the retained three stable trials and same-window Command+F switch. Terminal.app remains unverified. This decision does not weaken retained application/window/target identity or bypass the native tool denial.
- Lead re-audited fourteen successful native/Electron/Ghostty/ancillary logs and empty stderr. All recorded hashes, counts, COMPLETE markers, adapter/probe source/executable hashes and base `70bbbd5` match. Frozen Task packet matches HEAD. G2 Passed before remaining implementation or review. No remediation pass consumed. Original failure evidence and successful logs remain preserved.
- Ownership transfers to a fresh implementer for packet production/test/decision files and Implementation handoff only. Lead exclusively owns plan and desktop gate state. G3 remains pending after closure.

### G3 signed clipboard validation, 2026-09-30

- Candidate: Reviewed/remediated production app `.build/EchoType-workflow.app` on `refactor/macos-lifecycle`, base `70bbbd5`, executable SHA-256 `4bdd633e56cff9fcabfab85c2963bff142c3ac4703445738c2b9099491a443e8`. Strict signing passes. Production Clipboard SHA-256 is `5bd42c45707d6b67012c98da6ac17865d6f321c7f9f091cf1ffe244dd41924f3`; Destination retains its G2 hash. No production code changed after closure.
- Driver: Temporary `.build/EchoType-G3-Probe.app` compiled the exact production Clipboard/Destination with the built core objects, using Swift 6. Its bundle identity `com.echotype.destination-probe` and Apple Development signer reuse the already-authorised probe identity. `AXIsProcessTrusted()` returned true; no grant or permission change occurred. Strict signing passed. Final driver source SHA-256 `81f87208273e0079fc050091593d74829697cbb427070421ebe4324bc1e4fbe7`, executable `0dcad99d965f79219923cb1a4c16b3c96e34cbe7ff0c87eca7a6d4dc0ce5dc5a`. Compile command used `swiftc -swift-version 6 -parse-as-library -I .build/out/Products/Debug Sources/EchoTypeApp/Clipboard.swift Sources/EchoTypeApp/Destination.swift .build/g3-driver/Driver.swift .build/out/Intermediates.noindex/EchoType.build/Debug/EchoTypeCore-t.build/Objects-normal/arm64/*.o`. Signed with the existing Apple Development identity and hardened runtime. Temporary driver source/bundle removed after evidence recording; all logs remain.
- Actual target: Disposable TextEdit 1.21 `Untitled`, prepared through native computer use and activated with standard `open -a TextEdit`. Signed synthetic paste produced `G3 inserted text` followed by Return in the editor. Selection Copy returned exactly `G3 selected text`. Seeded original string and HTML bytes both restored, including after stopped Copy followed by insertion. Stop was signalled only after the driver acknowledged posting Copy, so this trial establishes cleanup of an already-started Copy before insertion. The driver restored the user's saved all-item/all-type clipboard after each controlled trial without logging its contents.
- External writer: A separate signed executable process wrote `G3 external writer` during the real pending restoration interval. Cleanup left that value intact rather than restoring the seeded snapshot. The driver then explicitly restored the user's clipboard as test cleanup. This is separate from the deterministic R1 test of an external write during final focus verification.
- Destination recovery: Native Command+F switched the same TextEdit window from its editing area to Find after available capture. The signed service reported insertion skipped with changed destination and issued no BEGIN. A separate trial visibly pasted exactly once, then the same Find switch occurred before eligible Return; the result reported attempted insertion and skipped sending, with seeded types restored. Closing Find showed exactly one pasted result and no newline. System Settings' existing General sidebar produced unavailable capture and skipped insertion with unavailable destination. No setting was changed.
- Timing: The first before-paste switch attempt missed its ten-second window and pasted normally; it is retained as a failed gate attempt. The corrected before-paste and before-Return trials held only the driver at explicit acknowledgment points, with a 45-second bound, until native state confirmed Find focus. Production 200 ms Return and 800 ms restoration constants were unchanged. These trials prove ordering/revalidation and actual adapter behavior, not a measured guarantee about editor acknowledgment or focus-switch speed. The original stopped-Copy attempt cancelled before Copy posted and does not count; the acknowledged retry passed. Source updates affected only this temporary driver, requiring no reopening of production review.
- UI cleanup: The disposable document still contains only `G3 inserted text` and remains open. TextEdit's close sheet offered permanent Delete with no undo, so the lead cancelled the sheet rather than taking that action without the user's confirmation. No original document was changed. System Settings remained on its existing General page. All probes exited; no production EchoType copy was quit or installed. No Terminal access, real key, microphone, live xAI request, permissions/settings change or `run.sh` invocation occurred.
- Scope of proof: G2 proves target identity in the recorded three editor categories. G3 proves signed service Copy/paste/restoration/recovery in TextEdit and unavailable focus in System Settings. Full dictation network/device lifetime, Reader playback/replacement and assembled recovery-window interaction remain their later gates. Copy change counts cannot attribute the writer and a response after 300 ms can still affect a later operation.

Retained G3 evidence, SHA-256:

| Log | Result | SHA-256 |
|---|---|---|
| `.build/g3-insert.log` | Paste and Return attempted; seeded types restored | `9e952180dc8d9c96a020cae3341b89f30540f9cbf687014c6da92f0723e38518` |
| `.build/g3-copy.log` | Selected text matched; seeded types restored | `79ef785d182452a5d734156e67ea3129711ee837c529996d14a5e8140dad8edb` |
| `.build/g3-stopped-copy-ack.log` | Copy posted then stopped; next insertion completed; seeded types restored | `9afb19dc4e42c53eaf5b67e3666d002e4d9ce7265b7b674df40ae7bfd6f86f36` |
| `.build/g3-external.log` | New separate-process clipboard value preserved | `bbecc05f3b76e30511a3d7a029b8037a4da652bc884dd0071f4493c9e6772e21` |
| `.build/g3-preloss-ack.log` | Changed destination skipped paste | `4ad59a997833d0e3f738ae58dda23c799c17afb969db15d1f7038de652f4d6f4` |
| `.build/g3-postswitch.log` | One paste; changed destination skipped Return | `f214dd2054c3d94998e488e01b14a0f55bb9281700cc99d87796268106653e18` |
| `.build/g3-unavailable.log` | Unavailable destination skipped paste | `a00ff02c488f4b1b7fef679ecb4867756c58ff6e7f41b1cdab32f8e2138058f0` |
| `.build/g3-stopped-copy.log` | Superseded: cancellation preceded actual Copy | `aaa26624949c6eeee00eb2f358f621368f12006a8006504cac714e73f432160b` |
| `.build/g3-preloss.log` | Superseded: switch missed its timed window | `4d331cf24b523df192a67cc29736d374b125948e33f051323be9c131b32ea89f` |

All nine separate stderr files are empty, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Earlier gate failures remain preserved with their limitations.

### Acceptance audit

- Accepted against base `70bbbd5fc0b973dbd421be1661f1404dd27035c2`. Lead read the complete diff, independent R1 finding, one remediation and fresh closure. Every changed production/test/decision file is packet-owned; the two Pill files have the recorded narrow ownership extension needed by the explicit cancellation boundary. Lead exclusively owns the packet records and plan. No unrelated changes exist. Task packet matches HEAD byte-for-byte.
- Destination adapter remains the exact G2-tested code. Final Clipboard candidate matches the signed G3 driver source. Lead's final targeted suite passed 31 tests, app build and strict production-bundle signature passed, and `git diff --check` passed. No broad suite rerun was needed for this bounded slice. Full deterministic and assembled Mac review belong to Final.
- Aidan's answered E2-G2-TARGET is durable in the target decision, G2 audit and plan log; the resolved escalation was removed. Approved validation-target drift is Ghostty instead of Terminal.app. No architecture drift. G3 driver timings are explicit test holds, not product changes. CI remains unverified under the existing workstream 1 deferral.
- Workstream 3 consumes the concrete Clipboard/Destination/trace APIs and preserves the once-only finishing effect and operation order. Workstream 4 consumes shared Copy cleanup. No live key, API request, permission change or production install occurred. The disposable TextEdit test document remains open for Aidan to discard; the tool's permanent-deletion confirmation rule prevented automatic discard.
