# Workstream 01: Live revision pipeline

Workflow status: draft. Workstream status: not started.

## Task packet

### Outcome

Dictation revises committed text as it arrives and inserts the pill's final text on stop.
The General setting controls it. The old batch pass and recording buffer are gone.

### Scope

- Implement the spec's windowing, single-flight/cancellation behavior, HTTP request, prompt,
  timeout fallback, and word-subsequence faithfulness check. Use `grok-4.3` with
  `reasoning_effort: "none"` and `temperature: 0`. Keep the request callable through the
  injected closure described in the spec.
- Separate committed text from current utterance runs in `SessionMachine.Snapshot`, then
  integrate the reviser into `DictationController` and its pill updates. Preserve cancel,
  `.failed(text:)`, empty, and Test button behavior.
- Replace `batchOnCommit` with `cleanUp`, default on, in settings storage and General UI. Ignore
  the old stored key. Remove batch code, tests, recording collection, dead comments, and mark
  [0017](../../../decisions/0017-batch-pass-on-commit.md) superseded.
- Author focused core tests and real prompt cases from the spec. Leave their execution to the
  final gate.

### Non-goals

Pill height, scrolling, scroll edge treatment, hard-cap change, model picker, and changes to
read-aloud behavior.

### Initial ownership

`Sources/EchoTypeCore/SessionMachine.swift`, `Sources/EchoTypeCore/Settings.swift`, new
reviser/request files in `Sources/EchoTypeCore`, `Sources/EchoTypeApp/DictationController.swift`,
`Sources/EchoTypeApp/Views/SettingsView.swift`, matching tests in `Tests/EchoTypeCoreTests`,
`Sources/EchoTypeCore/STT/BatchTranscriber.swift`, its test, and
`docs/decisions/0017-batch-pass-on-commit.md`. Edit adjacent files only when a direct compile
or obsolete-reference fix requires it; record each exception in the handoff. Do not edit the
PillView, PillDemo, or OverlayPanel files owned by stream 02.

### Required seams

- Preserve one assembled `Pill` transcript for stream 02 to render. Do not put revision logic
  in the view.
- The settings value is read once per session; the existing API key from session start is
  reused. No second Keychain read.
- The reviser owns `revised` and `covered`; one network call is active at a time. On stop,
  cancel it and make the final request. The final text shown and inserted must agree.

### Acceptance criteria

- Committed stretches visibly revise; unrevised settled and provisional text remain visible.
- Faithful revisions replace their window; failed, timed-out, and unfaithful revisions leave
  streamed text. Later windows can cover it again.
- Stop returns final revised text, `.failed(text:)` inserts the available revised text without
  a final call, and Test sessions do no revision.
- `cleanUp` on/off paths and stored defaults match the spec. No batch path or audio recording
  buffer remains.
- The app builds on macOS. New focused tests and prompt cases are ready for the final gate.

### Targeted verification

Run `swift build` on the Mac after the implementation and after any remediation. Inspect the
new test fixtures and cases, but run `swift test` only in the final gate. Use `rg` to confirm
`batchOnCommit` and `BatchTranscriber` have no active references. Record any build failure;
do not claim endpoint or dictation verification here.

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
