# Dictation whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved specification. Inspect the accepted handoffs, but review the combined diff and
surrounding code independently.

Most of this milestone has no automated test and never will. The review is the main
defence, so read the AppKit and AVFoundation paths as production code that nothing
guards, and weigh a finding by whether it could produce a mystery failure rather than by
whether a test would have caught it.

Audit:

- Whether each workstream's acceptance criteria are met, and whether G1's evidence
  actually supports criterion 1 of workstream 3 rather than merely being present.
- The session lifecycle end to end: who owns the socket, who owns the audio device, what
  happens to each when a session cancels, fails or hits the hard cap, and whether
  anything leaks across two consecutive dictations.
- The event tap lifecycle, including the disabled-by-timeout path and whether Escape is
  consumed only while a session is open.
- The pasteboard sequence against the specification's `changeCount` rule, and the restore
  under two overlapping insertions.
- Dependency direction: whether any decision that could live in `EchoTypeCore` was left
  untestable in `EchoTypeApp`, and conversely whether anything in Core exists only to be
  mocked.
- Speculative machinery. This milestone sits next to three deferred ones, so the main
  risk is the overlay, the settings window or a device picker arriving early in
  fragments.
- Whether the documents agree with the code, and whether recorded drift is real.

Run `swift build`, `swift test`, and `swift-format lint --recursive Sources Tests
Package.swift` if it is installed. Do not run `./scripts/run.sh`; the branch is known to
work from G1 and relaunching it costs Aidan's TCC state for nothing.

## Initial whole-feature review

- Reviewer: fresh general-purpose subagent.
- Branch, base, and reviewed head: `feat/dictation`, base `1ae5dda`, reviewed head
  `19fe132`, tree clean at the start of the review. Reviewed as one diff
  (`git diff 1ae5dda..HEAD`) plus the surrounding `EchoTypeCore` code the app consumes
  (`STTClient`, `URLSessionWebSocketTransport`, `SessionMachine`). The handoffs were read,
  not relied on. Whether `19fe132` is byte-identical to G1's candidate 4 cannot be checked
  from the repository; the records say nothing changed in code after candidate 4 was
  published.
- Verification run:
  - `swift build` after touching every source file: clean, no warnings.
  - `timeout 120 swift test --disable-xctest`: 35 tests in 1 suite passing, exit 0.
    `pgrep` found no `swiftpm-testing-helper` or test process afterwards.
  - `swift-format` is not installed, so lint was skipped. A column check found one line over
    100 (O4).
  - The app was not launched and the Keychain item was not read.
- Acceptance-criteria audit:
  - Workstream 1: met. 1 is pinned by `finalizingWithoutAnAnswerTimesOut`, which scripts the
    trailing partial that broke the first attempt and uses the existing harness, not a new
    fake. 2 holds (existing tests unchanged and green). 3 holds by reading: `conclude`
    cancels the clock, and `beginFinalizing` does not arm after an ending
    (`SessionMachine.swift:297`). 4 is recorded, and the 400/401 drift is real and matches
    the transport comment and the menu wording (`DictationController.swift:159-161`). 5
    holds.
  - Workstream 2: 1, 2, 3, 4, 6 and 7 met on reading. 3 and 4 also rest on the lead's offline
    conversion probe recorded at G1 attempt 3. 5, the warm idle hold, is deliberately
    unmet: G1 correction T4 replaced it with release on session end, approved by Aidan and
    now in the specification's Audio section. The code matches the new rule
    (`AudioCapture.swift:43-49`) and no idle release remains.
  - Workstream 3: 2, 3, 5, 6, 8 and 9 met on reading and, where G1 covered them, by G1. 3's
    tests check only the pure predicate. 4 is the spike's re-enable carried over unchanged
    (`HotkeyMonitor.swift:70-73`). No G1 observation exercises it, so it rests on reading,
    as the specification's hand-verified list anticipated. 7 is correct on reading: a second
    insertion that finds the first transcript still on the pasteboard inherits its saved
    items, the first restore sees it has been superseded, and each saved copy is written at
    most once (`Inserter.swift:34-50`). G1 observation 6 does not exercise it, because two
    dictations cannot land within 800ms of each other in practice.
  - G1 against criterion 1: the evidence supports it. Candidate 4's check 2 is exactly
    "Opt+D, speak, Opt+D, text lands in TextEdit", twice, on the post-T4 audio path, and
    T4 is the only code change since candidate 3 passed all eight observations. The evidence
    is recorded as the lead's summary rather than in Aidan's words (Q2).
  - Session lifecycle: sound. The `SessionMachine` owns the socket. Every ending reaches
    `conclude`, which closes the transport, and `cancel()` closes it at once. The
    controller owns the device. Every successful `start()` reaches the `audio.stop()` at
    `DictationController.swift:111`, whether the session ends by commit, cancel, silence,
    hard cap, socket failure, finalize timeout or microphone failure. The missing-key path
    stops at line 79. Across two consecutive dictations nothing survives: both tasks are
    awaited, the clock's pending wake-up is cancelled, the stream is finished, the engine
    and its observer are released, and a mid-session reopen that loses the race closes
    again (`AudioCapture.swift:91-92`).
  - Event tap: the timeout and user-input re-enable is intact. Escape is consumed only when
    `phase` is `.running` (`DictationController.swift:56-60`), and otherwise passes through.
    Two edges remain. During `.starting` it passes through (O2). During `finalizing` it is
    consumed as a no-op, which follows the specification's state diagram and was triaged in
    workstreams 1 and 3.
  - Pasteboard: the specification's `changeCount == before + 1` rule is unchanged
    (`Inserter.swift:45`). The overlap logic and the empty-pasteboard skip do not weaken it.
  - Dependency direction: sound. The only new Core surface is `Hotkey.matches` and
    `finalizeTimeout`, both used by the app and neither existing to be mocked. The
    decisions left in App are the pasteboard supersede rule (a two-line `changeCount`
    comparison) and the commit sequencing, which is bound to `AudioCapture`. Neither is
    worth a Core type.
  - Speculative machinery: none. There is no overlay, panel, settings scene, device picker,
    level meter, launch at login, `install.sh` or `--hud-demo`. `Settings.inputDeviceID`
    and the placeholder keyterms predate the branch.
  - Recorded drift: every row in the plan's log matches the code and the specification's
    diff. See O3 for the places where the documents still disagree.
- Required findings by owner: none.
- Optional observations:
  - **O1. Opening and closing the audio device run on the main thread that services the
    event tap, and the commit press closes the device inside the tap callback itself.**
    Owner: workstream 3 files. `handle` says "Keep it fast: the system disables a slow tap"
    (`HotkeyMonitor.swift:67`). On a commit press it calls `onHotkey()` synchronously
    (line 79), which calls `audio.stop()` (`DictationController.swift:51`). That runs
    `chunker.end()` under the lock the audio thread converts under, then
    `engine.stop()` and `removeTap` (`AudioCapture.swift:47-48, 100-101`), all before the
    callback returns. The spike deferred its work out of the callback on purpose.
    `engine.start()` at the start of every session (T4) also blocks the main run loop for
    the 100 to 300ms device open, with any keyboard event queued behind it. Failure
    scenario: on a slow teardown, such as a Bluetooth input switching profile back, the
    callback overruns. The system disables the tap, and the Opt+D that timed out may reach
    the focused app as "∂" ahead of the pasted transcript. The re-enable limits this to
    one event, but it is the "stopped working and I don't know why" class the
    specification names first. The cheap part of the fix is to defer the stop out of the
    callback (`Task { audio.stop() }`, or `DispatchQueue.main.async`), as the idle case
    already does with `Task { await dictate() }`. Moving the engine off the main actor is
    not worth it now.
  - **O2. Escape passes through during `.starting`, and after T4 every session has a
    `.starting` window.** Owner: workstream 3 files. `escapePressed` returns `false` unless
    `phase` is `.running` (`DictationController.swift:57`). `.starting` now covers the
    device open on every session, the Keychain read and any Keychain access prompt after
    a rebuild. It is no longer only "the first-use permission prompt", as the comment at
    lines 17-18 still says. Failure scenario: in a coding agent, Aidan presses Opt+D, then
    Escape straight away to abandon it. The Escape interrupts the agent, the session opens
    anyway with a live microphone, and it cancels itself after ten seconds of silence.
    The minimum fix is to correct the comment. The behavioural fix is to consume Escape
    during `.starting` and have `dictate()` stop instead of opening the socket. That adds
    one flag, so the lead should weigh it against how often this happens.
  - **O3. Three documents still disagree with the code.** Owner: final-review lead.
    `03-dictation-end-to-end.md:3` reads "Status: blocked on gate G1 (escalation E1)",
    while `plan.md` has it Accepted, G1 Passed and no escalation open. Workstream 2's
    closure caught the same stale line in its own record. `plan.md:62-63` still lists
    "Acquiring and releasing the input device is separate from starting and stopping
    delivery" as a frozen contract, which T4 removed. Only the drift log says so, and a
    later milestone reading the contracts would be misled; point that line at the
    release-on-end row. Workstream 2's handoff API (`acquire()`, the 3-minute idle
    release) is history that the superseded row already flags, so it can stay.
  - **O4. `SessionMachine.swift:334` is 103 columns**, from workstream 1's `.timedOut`
    case. swift-format's default limit is 100 and it is not installed here, so nothing
    caught it.
  - Tests: `HotkeyTests.swift` and the new `SessionMachineTests` case assert behaviour
    through the pure predicate and the existing harness. Neither invents a fake or asserts
    an implementation detail. The Ctrl+Opt+D self-match in `hotkeyMatchesItsChord` adds
    little over the Opt+D case but costs nothing. No test doubles for the tap, pasteboard,
    Keychain or `AVAudioEngine` were added.
- Questions:
  - **Q1. A short dictation committed before `transcript.created` inserts nothing, silently.**
    `STTClient.finish()` drops audio still held for `transcript.created`
    (`STTClient.swift:71-79`). The controller opens the microphone first, then reads the
    Keychain, then starts the socket handshake (`DictationController.swift:73-86`). So
    `created` arrives only after the device open, the Keychain read, TLS, the upgrade
    and server setup. Failure scenario: Opt+D, "yes", Opt+D inside that window (plausibly
    around a second). The session finalises with nothing sent, the outcome is `.nothing`,
    and the menu reads "Ready", with no error and nothing on the pasteboard. This is
    pre-existing Core behaviour the specification lists as an edge case, and changing it
    would be an escalation under the frozen `SessionMachine` contract. It barely matters
    for 20 to 60 second prompts. Should it be recorded as a known limitation, or deferred
    to the overlay milestone, whose starting state already marks when to speak?
  - **Q2. Is the lead's paraphrase acceptable as G1 evidence?** `plan.md:111` asks for the
    observations "in Aidan's words". The record summarises them instead
    (`03-dictation-end-to-end.md:259-263, 279-282`). The substance supports every criterion
    G1 was meant to prove. This is a question about the record, not about the build.
- Verdict: Accept. No required findings. The lifecycle, tap, pasteboard and dependency
  direction hold up on a full read, and nothing from the deferred milestones has arrived.
  O1 and O2 are cheap hardening on the paths most likely to produce a mystery failure. O3
  is a documentation fix the final-review commit should carry.

## Lead triage

- Accepted findings and owners:
  - O2, comment only: the `.starting` comment in `DictationController.swift` now says
    every session spends time there and Escape passes through. Implementation agent.
  - O3: `03-dictation-end-to-end.md` status line set to accepted (implementation agent);
    the stale frozen-contract line in `plan.md` now points at the release-on-end row
    (final-review lead).
  - O4: the `.timedOut` line in `SessionMachine.swift` wrapped under 100 columns.
    Implementation agent.
- Rejected findings and reasons:
  - Q2: the paraphrase stands. The lead recorded Aidan's reports as he gave them during
    troubleshooting, the substance covers every required observation, and G1 is not to
    be re-opened.
- Deferred optional observations:
  - O1, deferring `audio.stop()` out of the tap callback: plausible hardening, but it
    changes the hotkey and audio path that G1 just proved, and would need another hand
    run to accept. No G1 run showed a disabled tap or a leaked "∂". Worth doing alongside
    the overlay milestone, which will touch the same start and commit path.
  - O2 behaviour, consuming Escape during `.starting`: same reasoning. It changes the
    hotkey path and adds state; the overlay's starting state is the natural place to
    decide what Escape means before audio flows.
  - Q1, a very short dictation committed before `transcript.created` inserting nothing:
    recorded as a known limitation. It is pre-existing `EchoTypeCore` behaviour under a
    frozen contract, irrelevant for 20 to 60 second prompts, and the overlay's starting
    state tells the user when to speak.
- Drift requiring user decision: none. No correction changes behaviour, and no new
  specification drift was found; the reviewer confirmed every existing drift row.

## Focused closure

- Reviewed head: `19fe132` with uncommitted corrections (`git diff`: `DictationController.swift`,
  `SessionMachine.swift`, `03-dictation-end-to-end.md`, `plan.md`, plus this file).
- Finding outcomes:
  - O2 (comment): fixed. The `.starting` doc comment now says the phase takes a noticeable
    moment every session, presses are ignored and Escape passes through. That matches
    `hotkeyPressed` (`.starting` breaks) and `escapePressed` (returns `false` unless
    `.running`). No behaviour changed.
  - O3: fixed. `03-dictation-end-to-end.md` reads "Status: accepted.", agreeing with
    `plan.md`. The stale frozen-contract line in `plan.md` now says T4 superseded it and
    points at the release-on-end row, which exists in the drift log (2026-09-23, G1
    correction T4).
  - O4: fixed. The `.timedOut` case is wrapped. A column scan of `Sources`, `Tests` and
    `Package.swift` finds no line over 100.
  - Verification: `swift build` clean. `timeout 120 swift test --disable-xctest`: 35 tests
    in 1 suite passing, exit 0. `pgrep` found no test or `swiftpm-testing-helper` process
    afterwards. `swift-format` not installed, so lint skipped. The app was not launched and
    the Keychain was not read.
- Final simplification assessment: nothing to remove. The corrections are one comment, one
  line wrap and two documentation lines. They add no code paths, state or abstractions.
  Deferred O1, O2 behaviour and Q1 stay deferred.
- Remaining blockers: none.
- Verdict: Accept. Every accepted finding is fixed as triaged, and the fixes introduce no
  defect.

## Completion record

- Final verification: `swift build` clean; `timeout 120 swift test --disable-xctest` 35
  tests passing, run by both the implementation agent and closure after the corrections.
  `swift-format` is not installed, so lint was replaced by a column scan. The corrections
  are a comment, a line wrap and documentation, so the app was not relaunched and G1 was
  not re-opened.
- External validation pending: none for this milestone. Unexercised by G1 and resting on
  reading: the tap re-enable after a timeout (workstream 3 criterion 4) and two insertions
  within 800ms (criterion 7).
- Specification drift: nothing new. The drift log rows written by workstreams 1 to 3 and
  at G1 stand, and the reviewer confirmed each against the code and the specification.
  Known limitation, not drift: a dictation committed before `transcript.created` arrives
  inserts nothing and reports nothing (Q1).
- What G1 showed about first-word clipping and real dictation: on the MacBook Pro
  Microphone, candidate 4 showed no first-word clipping on a cold start or back to back,
  even though every session now pays the device open, and no last-word clipping. Real
  dictation came back correct, and all eight observations passed across candidates 3
  and 4. Bluetooth earbuds produced wrong transcripts: the endpoint returns guesses or the
  keyterm prompt for faint headset-profile audio, and the profile switch loses the opening
  seconds. That is recorded as a known limitation for the settings milestone.
