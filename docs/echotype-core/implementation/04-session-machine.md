# Workstream 4: Session machine

Status: not started.

## Task packet

### Outcome

A session state machine implementing the specification's interaction model, driven by
an injected clock so every timeout is tested deterministically. Nothing is ever
committed by a timer except the hard cap.

### Scope

- States `idle`, `listening`, `paused`, `finalizing`, `inserting` and `cancelled`, per
  the specification's state machine section.
- The listening and paused transition in both directions. Ten seconds without new
  transcript activity moves to `paused`; any new partial moves back to `listening`.
  Audio keeps streaming in both, since pausing is a display state.
- The no-speech path. If nothing is ever said, the same ten second setting cancels the
  session silently rather than producing an empty insertion.
- The hard cap. Ten minutes ends the session and commits whatever accumulated.
- Commit entered only by an explicit trigger or the hard cap, sending `finalize` then
  `audio.done` and waiting for `transcript.done`.
- Cancellation discarding everything.
- Socket failure mid-session emitting the finalised segments accumulated so far
  alongside the error, rather than discarding them.
- An injected clock so tests advance time without waiting.

### Non-goals

- The overlay, the menu bar, settings persistence and anything that draws. This
  workstream emits state; it does not render it.
- Pasteboard insertion and `CGEventPost`. Those are macOS-side.
- The event tap and hotkey handling.
- Local voice activity detection or RMS thresholds. The specification deliberately
  drives pausing from server events instead. Only reach for local detection if
  workstream 3 proved the server signal unusable, and then escalate rather than
  deciding alone.
- Making the timeouts configurable beyond the `Settings` fields workstream 1 defined.

### Initial ownership

Creates and owns `Sources/EchoTypeCore/SessionMachine.swift` and its tests.

Consumes workstream 2's event types and assembler without changing them. A defect in
those is an escalation.

### Required seams

Consumes the frozen event types, `TranscriptAssembler` and `Settings`. Emits state
transitions and a final result for a macOS layer to render and insert.

### Acceptance criteria

1. `swift build`, `swift test --disable-xctest` and `swift-format lint` all pass.
2. Ten seconds of quiet moves `listening` to `paused`; a new partial moves it back.
3. Several pause and resume cycles in one session accumulate text correctly and in
   order.
4. A session where nothing is ever said cancels silently at ten seconds and produces
   no insertion.
5. The hard cap ends a ten minute session and commits the accumulated text.
6. No path other than an explicit trigger or the hard cap reaches `finalizing`.
7. Cancelling from `listening` or from `paused` discards everything.
8. A trigger arriving before `transcript.created` is handled without losing the
   session or emitting an empty result.
9. A socket error mid-session yields the accumulated finalised segments and the error.
10. A `transcript.done` resolving to empty text produces no insertion.
11. Every timeout is exercised through the injected clock. No test sleeps.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift-format lint --recursive Sources Tests
```

New focused tests covering criteria 2 to 10. Assert on observable transitions and
emitted results rather than on internal field names, so the tests survive a refactor.

If workstream 3 recorded behaviour contradicting the specification, implement what
workstream 3 observed and record the difference as drift.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`
