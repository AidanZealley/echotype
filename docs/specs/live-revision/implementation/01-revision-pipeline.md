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

- Base commit: `4c54c61d74bad82c316b0cbe192627fbe28faaaf`.
- Outcome: Committed text revises in the pill while current utterance runs remain visible. Stop cancels the live call and uses one final revision for the pill and insertion. Failed sessions insert the available revised text without a final call. Test sessions bypass revision. The recording buffer and batch path are removed.
- Files changed: `SessionMachine.swift`, `TranscriptAssembler.swift`, `Settings.swift`, new `Reviser.swift` and `RevisionRequest.swift`, `DictationController.swift`, `SettingsView.swift`, related core tests, and decision 0017. Deleted `BatchTranscriber.swift` and its test. Adjacent ownership exceptions: `Pill.swift` updates a settled-text comment that referred to the removed snapshot field, and `docs/decisions/README.md` marks 0017 superseded to match its record.
- Decisions: The reviser keeps `revised`, `covered`, and the last attempted commit length. The latter prevents an immediate retry loop after a failed request; a later commit can retry that text. The app passes separate live and final request closures so the final call uses the specified shorter resource timeout. The old stored `batchOnCommit` key is ignored, with `cleanUp` defaulting on. Revision updates carry only a signal; the controller reads current reviser text and discards a render if its snapshot changed while awaiting that read.
- Verification: `swift build` passed after implementation, cleanup, and race remediation. `swift build --build-tests` compiled the new tests and prompt cases. `rg` found no active `batchOnCommit` or `BatchTranscriber` references in `Sources` or `Tests`; the old key remains only in a settings migration fixture. The test suite was not run, as the packet reserves it for the final gate.
- Known limitations or external checks: The final gate still needs `swift test`, the live prompt cases with `XAI_API_KEY`, endpoint latency measurement, and Mac dictation with pill versus inserted text comparison. These have no recorded result here.
- Specification drift: None.

## Independent review

- Reviewer: Independent workstream reviewer.
- Verdict: Required fix before acceptance.
- Required findings:
  - `DictationController.run` consumes the text carried by `Reviser.updates` and applies it to `currentSnapshot` (`DictationController.swift:303-308`). An update can wait in the stream while a later snapshot adds another committed segment. The snapshot path then shows the new remainder (`:311-317`), but the queued older update can run afterward and replace that display with text that predates the segment. The unrevised segment disappears from the pill until another update or the final call, which breaks the spec's visible remainder requirement. Treat an update as a signal to read the reviser's current `shown` text for the latest snapshot, or otherwise keep the text and snapshot at the same commit version. Add a focused test for this ordering if the controller seam permits it.
- Optional observations:
  - `docs/decisions/README.md` still lists 0017 as Accepted, though the record now says superseded. Updating the index would keep its status accurate. The older key list in 0010 reads as historical context and need not be rewritten for this workstream.
- Questions: None.

Review checks: Read the full diff against `4c54c61d74bad82c316b0cbe192627fbe28faaaf`, the approved spec, packet, and relevant decisions. `git diff --check` passed; `rg` found no active batch references in Sources or Tests. I did not run tests because this packet reserves them for the final gate.

## Resolution

- Finding dispositions: Fixed the required queued-update race by publishing a revision signal and reading the reviser's current text for the current snapshot. Promoted the 0017 index mismatch because the required superseded status should agree across the record and index; fixed it. No questions remained.
- Simplification/deletion pass: Removed the batch request, its test, the recording buffer, and the old settings path. Revision updates no longer carry a second copy of the displayed text. No additional abstraction was needed for the controller ordering fix.
- Final verification: `swift build` and `swift build --build-tests` passed after remediation. `git diff --check` passed. No active batch references remain in `Sources` or `Tests`; the old settings key appears only in the migration fixture. `swift test`, real endpoint prompts, latency, and dictation remain assigned to the final gate.

## Closure review

- Verdict: The accepted fixes are sound. No remaining required findings from this closure.
- Queued revision update: `Reviser.updates` now carries a signal, and the controller reads `reviser.shown` for its current snapshot. After the actor read, it checks that the snapshot is still current before rendering (`DictationController.swift:303-321`). A newer snapshot renders its own committed remainder, so an older queued update cannot leave that remainder hidden.
- Decision 0017: The record and `docs/decisions/README.md` both mark it superseded by live revision.
- Checks: Read the affected controller and reviser paths, the approved spec, and the relevant diff. `git diff --check` passed. No tests were run; the packet reserves the suite for the final gate.
