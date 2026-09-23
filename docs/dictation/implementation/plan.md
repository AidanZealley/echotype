# Dictation implementation plan

Status: approved; implementation in progress.

## Orchestration record

- Integration branch: `feat/dictation`
- Starting commit: `1ae5dda`
- Review command: `lead subagents`
- Specification approved at commit: `47e3fa1`
- Started: `2026-09-23`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Core seams](01-core-seams.md) | Approved spec | Accepted |
| 2 | [Audio capture](02-audio-capture.md) | 1 | Accepted |
| 3 | [Dictation end to end](03-dictation-end-to-end.md) | 1, 2 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-3 | Not started |

## Why these boundaries

Workstream 1 is the only work in this milestone with fast automated tests, and it is
small on purpose. A hang in `finalizing` and a mis-mapped 401 are both defects you
cannot see from the app, and both are cheap to pin with an injected clock and one live
call. Doing them first also means the app target picks up its `EchoTypeCore` dependency
before anything needs it, so no later workstream edits `Package.swift`.

Workstream 2 is split from 3 because audio capture is a different subsystem with
different failure modes: sample rate conversion, device acquisition latency and buffer
cadence have nothing to do with event taps or the pasteboard. It is the largest single
piece of unfamiliar API surface in the milestone and deserves its own review.

Workstream 3 is deliberately one unit rather than three. A hotkey monitor with nothing to
trigger, a Keychain reader with nothing to authenticate, and a controller with no hotkey
are each unshippable alone, and splitting them would mean the earlier half building stubs
for the later half to delete. Their acceptance is a single observable fact: pressing
Opt+D twice puts what you said at the caret.

Gate G1 sits at the end of workstream 3 rather than being spread across 2 and 3, because
one hand-run session is the only evidence that exists for both the audio path and the
insertion path, and asking Aidan to sit down twice for the same sentence buys nothing.

## Cross-workstream contracts

Frozen once workstream 1 is accepted:

- `EchoTypeApp` depends on the `EchoTypeCore` target. No workstream after 1 edits
  `Package.swift`.
- `SessionMachine`'s public surface is `run()`, `send(audio:)`, `trigger()`, `cancel()`,
  `states` and `Outcome`. Workstream 3 consumes it as it is. A defect in it is an
  escalation, not a rewrite.
- `SessionMachine` gains a bounded wait in `finalizing`. Its expiry produces
  `Outcome.failed(text:error:)`, not a hang and not a silent success.

Frozen once workstream 2 is accepted:

- Audio reaches the session as `Data` holding 16 kHz mono little-endian Int16, in chunks
  of roughly 100ms, in capture order. Workstream 2 chooses the exact API and records it
  in its handoff; workstream 3 reads that handoff rather than assuming a shape.
- Acquiring and releasing the input device is separate from starting and stopping
  delivery, because the first costs 100 to 300ms and would clip the first word.

Held by the specification and not open to a workstream:

- The bundle identifier is `com.aidanzealley.echotype`. TCC grants, the Keychain item and
  `UserDefaults` all key off it.
- `scripts/run.sh` is the only supported build and launch path.
- Nothing is inserted by a timer except the ten minute hard cap.

## Ownership handoffs

| File | Owner | Notes |
|---|---|---|
| `Package.swift` | 1 | Frozen after acceptance |
| `Sources/EchoTypeCore/SessionMachine.swift` | 1 | |
| `Sources/EchoTypeCore/STT/URLSessionWebSocketTransport.swift` | 1 | |
| `Sources/EchoTypeCore/Settings.swift` | 3 | The hotkey matching predicate |
| `Sources/EchoTypeApp/AudioCapture.swift` | 2 | 3 may correct it during G1 troubleshooting |
| `Resources/Info.plist` | 2 | |
| `Sources/EchoTypeApp/HotkeyMonitor.swift` | 3 | Rewritten, not extended |
| `Sources/EchoTypeApp/Keychain.swift` | 3 | New |
| `Sources/EchoTypeApp/DictationController.swift` | 3 | New |
| `Sources/EchoTypeApp/Inserter.swift` | 3 | |
| `Sources/EchoTypeApp/App.swift` | 3 | |

Workstream 3 may change `AudioCapture.swift` only while troubleshooting gate G1, and
records each such change in its handoff as a correction to workstream 2's work.

## Whole-feature acceptance

- Workstreams 1 to 3 accepted.
- Gate G1 passed, with Aidan's evidence recorded in
  [03-dictation-end-to-end.md](03-dictation-end-to-end.md).
- `swift build` clean and `swift test` green.
- No overlay, settings window, level meter, launch-at-login or `install.sh` in the diff.
  Those are later milestones and their appearance here is scope creep to reject.

## External validation gates

### G1 Real dictation on Aidan's Mac

- Owning workstream: 3
- Placement: after focused closure, before acceptance
- Status: `Passed` (candidate 4, 2026-09-24; evidence in the workstream record)
- Candidate: the uncommitted workstream 3 branch state, launched with `./scripts/run.sh`
- Resume condition: Aidan reports every required observation below, or reports a failure
  the lead can correct and republish

Required evidence, in Aidan's words:

1. The app launches, prompts for Microphone and for Device Control and Data Access, and
   both grants stick across a subsequent `./scripts/run.sh`.
2. Opt+D in TextEdit, one spoken sentence, Opt+D again, and that sentence appears at the
   caret.
3. Whether the first word was clipped.
4. Escape mid-session discards and inserts nothing.
5. The clipboard contents from before the dictation come back afterwards.
6. Two dictations back to back both land, the second within a second or two of the
   first.
7. The menu bar icon changes while a session is running.

Before the gate, Aidan must seed the Keychain item once. The lead publishes the exact
command with its candidate.

## Escalations

None open.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-23 | Errors surface in the menu bar menu, not an overlay | The overlay is a later milestone, and `Outcome.failed` still has to go somewhere the user can see | Aidan, before the workflow | 3 |
| 2026-09-23 | The API key is read from the Keychain with no UI to write it | Storage is the real one from the start, so the settings milestone adds only the editor; an `LSUIElement` app launched by `open` inherits no shell environment, so an environment variable was never an option | Aidan, before the workflow | 3 |
| 2026-09-23 | Specification drift: `api.x.ai` answers a wrong key with 400 (`"Incorrect API key provided"`) and sends 401 only when no credentials are presented, not "401 bad key" as the spec says. A bad Keychain key therefore arrives as `STTError.badRequest` | Observed live by workstream 1's probe; `STTError(httpStatus:)` stays faithful to HTTP | Workstream 1 lead | 3: word both `.badRequest` and `.unauthorized` in the menu bar as a key problem |
| 2026-09-23 | Superseded by the release-on-end row below. `AudioCapture` releases a warm, idle device when the input configuration changes, instead of reopening it for the rest of the idle window. The spec's "hold through a few minutes of idle" still holds otherwise | Reopening while idle would grab newly connected AirPods into headset mode and restart the idle timer on unrelated output changes. The next session after such a change pays the 100 to 300ms open cost | Workstream 2 lead | 3: every stream `start()` returns must be ended by `stop()`, including when the session ended while `start()` was still awaiting; see the workstream 2 handoff |
| 2026-09-23 | Specification drift: the menu's state line reports the running state, every session failure and a missing API key, work the specification gives to the overlay and the settings window. The controller also opens the microphone before the socket, and Opt+D commits by stopping capture so the pump drains the tail before `trigger()` | The menu is the only surface in this milestone. Microphone first means a denied grant never opens a billed socket; draining first stops the last word being dropped after `audio.done` | Workstream 3 lead | Overlay and settings milestones take over the error and key reporting |
| 2026-09-23 | Specification drift: the microphone is released as soon as a session ends, not held warm through a few minutes of idle. `AudioCapture.stop()` ends delivery and closes the device; workstream 2's 180 s idle release and `acquire()` are gone (G1 correction T4). No delay before closing, because delivery already ends first and a delay would only keep a quick second session warm | A warm microphone keeps the orange macOS indicator on after dictation ends, which Aidan finds disconcerting. Every session now pays the 100 to 300ms device open before audio flows | Aidan, at gate G1 | 3; the overlay and settings milestones inherit a cold start on every session |
| 2026-09-23 | Known limitation: Bluetooth earbud input produces wrong transcripts (keyterms or guesses) because the endpoint receives faint, headset-profile audio. Opening the earbuds' microphone also restarts the engine during the profile switch, which now loses the opening seconds of every session. The app keeps following the system default input | Diagnosed at G1 attempt 3 and confirmed by Aidan: the MacBook Pro Microphone passed every observation | Aidan, at gate G1 | Later milestones: input device choice or a warning belongs with settings |
| 2026-09-24 | Specification change: the Audio section releases the microphone when each session ends (replacing the warm idle hold), and the Overlay section gains a starting state shown between Opt+D and audio flowing, so the user sees when to speak and a clipped first word is never silent. Workstream 3 does not implement the starting state | G1 correction T4 made every session pay the device open; candidate 4 showed no clipping on a cold start or back to back and the indicator clearing after Opt+D and Escape | Aidan, at gate G1 | Overlay milestone implements the starting state |
