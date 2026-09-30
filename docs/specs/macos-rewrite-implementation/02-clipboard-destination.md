# Workstream 2: Own clipboard and destination

Status: not started.

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

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Concrete destination/clipboard declarations and usage: TBD
- Decisions: TBD
- Verification: TBD
- Known limitations or external checks: TBD
- Specification drift: TBD

## Independent review

- Reviewer: TBD, lead subagent
- Verdict: TBD
- Required findings: TBD
- Optional observations: TBD
- Questions: TBD

## Resolution

- Finding dispositions: TBD
- Simplification/deletion pass: TBD
- Final verification: TBD

## Closure review

- Verdict: TBD
- Remaining required findings: TBD

## External validation

- Gate and placement: G2 during implementation before independent review; G3 after closure before acceptance
- Status: Pending
- Candidate and instructions: Record adapter/probe, exact native/terminal/Electron editors and steps for repeated identity, same-window field switches, before-paste/before-Return focus loss, Copy/restoration and external writes
- Required evidence: Stable matching identity where supported; changed fields detected; unknown identity conservatively recovered; signed clipboard behavior and truthful trace
- Attempts and lasting decisions: TBD
- Resume condition: Evidence meets contract, or Aidan explicitly settles a supported-editor limitation; G3 passes on the final candidate
