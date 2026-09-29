# Workstream 1: Trace and revision evidence

Status: not started.

## Task packet

### Outcome

EchoTypeCore can represent one dictation trace, mark streamed words against inserted
text, and report each completed revision attempt with its actual result. The app can
consume the accepted API without reimplementing word matching or request accounting.

### Scope

- Add `DictationTrace` and its nested commit, revision and outcome values from the
  [spec](../../specs/debug-window.md). Keep a single value suitable for JSON encoding
  and the window.
- Implement `marks` with kept, deleted and changed words and a commit boundary flag.
  Use the existing `Prose.words` normalization, preserving raw display forms. The
  spec's repeated-word ambiguity is acceptable.
- Add ordered request attempts to `Reviser` and classify accepted, unchanged,
  rejected, reply-request-removed, empty, failed, cancelled and superseded outcomes.
  Measure each request with `ContinuousClock` only when capture is enabled. Keep
  request text and replies out of stored trace state when capture is off. Return the
  first unmatched revision word for rejection while retaining `isFaithful` for
  existing callers. Preserve the reply-request protection added in decision
  [0022](../../decisions/0022-voice-replies.md).
- Add the two focused tests named in the spec. Name the marks test
  `dictationTraceMarks` for the command below. Use existing scripted request helpers
  where useful. Do not expand this into a retry or timing test suite.

### Non-goals

No app window, launch flag, controller capture, persistence, history, network changes,
or changes to the revision acceptance policy.

### Initial ownership

- `Sources/EchoTypeCore/DictationTrace.swift` (new)
- `Sources/EchoTypeCore/Reviser.swift`
- `Sources/EchoTypeCore/Prose.swift` only for a necessary shared word-token rule
- `Tests/EchoTypeCoreTests/DictationTraceTests.swift` (new)
- `Tests/EchoTypeCoreTests/ReviserTests.swift`

No other production files. Raise an ownership change to the lead before editing one.

### Required seams

- Expose the trace and attempts as public Core API for workstream 2. Do not expose
  `Prose` merely to let the app tokenize words; marks supply the presentation data.
- Provide a simple opt-in at Reviser initialization for attempt capture; the app will
  pass its debug flag. The default path records no attempts.
- Preserve `Reviser.finish`, `stop`, `shown`, `updates` and the current reply-request
  acceptance guard. A cancelled session need not wait for an outstanding model call
  before its trace is published; record a cancellation when that call has completed
  cancellation handling.
- Word boundaries in marks and faithfulness must agree, including hyphenated stutters,
  punctuation at word edges and case changes. Commit boundaries derive from the same
  tokenization applied to each commit text.

### Acceptance criteria

- The spec's `I-I'm never sure. Why it fails` example marks the stutter deletion,
  punctuation and case changes, and the boundary before `Why`.
- Accepted, rejected and thrown requests appear in start order with raw window/reply,
  latency and the correct result. A rejection names the first added or substituted
  word. Existing revision behavior and reply-request protection still pass their
  tests.
- Core stays independent of AppKit and SwiftUI. The public trace JSON encodes.

### Targeted verification

```sh
swift test --filter dictationTraceMarks
swift test --filter revision
```

Run the newly added focused test by its actual name if it differs from the filter.
The lead records the commands and results in this file.

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
