# Workstream 1: Trace and revision evidence

Status: accepted.

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

- Base commit: `e7fe4d1b2afa2648f6aee2192ba95e566a130704`
- Outcome: Implemented. `DictationTrace` holds the spec's fields and nested types, and
  `marks` returns `[DictationTrace.Mark]` (`word` is the raw streamed form, `kind` is
  `kept`, `deleted` or `changed(inserted:)`, and `commit`, the index in `commits` of the
  commit starting at that word when a boundary falls before it). `Reviser(request:finalRequest:capture:)`
  records `attempts` when `capture` is true, and records nothing by default.
  `Reviser.firstUnmatchedWord(in:from:)` returns the first unmatched normalised word,
  and `isFaithful` wraps it.
- Files changed: `Sources/EchoTypeCore/DictationTrace.swift` (new),
  `Sources/EchoTypeCore/Reviser.swift`, `Sources/EchoTypeCore/Prose.swift`,
  `Tests/EchoTypeCoreTests/DictationTraceTests.swift` (new),
  `Tests/EchoTypeCoreTests/ReviserTests.swift`.
- Decisions:
  - `Prose.tokens` returns `(raw, word)` pairs and `Prose.words` maps over it, so marks
    and faithfulness share one tokenizer. `Prose` stays internal. Raw forms come from
    the same split, so the stutter `I-I'm` yields raw `I` and `I'm`.
  - `revise` takes `isFinal` in place of the request closure. A private `judge` maps the
    existing guards to a `Result` in their original order: cancelled, superseded,
    failed, empty, rejected, reply request removed, then unchanged or accepted. The
    state updates for each group are unchanged, and the acceptance policy is the same.
  - Attempts are appended when a request completes. Only one request runs at a time,
    because `finish` cancels and awaits the drain task before its final request and
    no request starts after `stop`, so completion order is start order. `Date` and
    `ContinuousClock` are read only when capture is on.
  - `DictationTrace` and `Commit` have public initialisers for the app. `Revision` is
    built only inside Core, so its initialiser stays internal.
  - `rejected(word:)` holds the normalised word (lowercase, punctuation stripped), as
    in the spec's `rejected at "i'm"`.
- Verification: `swift test --filter dictationTraceMarks` passes (1 test).
  `swift test --filter revision` passes (10 tests, including the new `revisionAttempts`).
  A full `swift test` passes all 69 tests with no warnings. The marks test also
  round-trips the trace through `JSONEncoder` and `JSONDecoder`.
- Known limitations or external checks: A `cancelled` attempt is appended only once the
  cancelled call returns, so a trace copied immediately after `stop()` can miss it, as
  the spec allows. When the inserted text is empty, every streamed word is marked
  deleted.
- Specification drift: none. Names follow the spec, plus the new `Mark` type and the
  `capture:` initialiser parameter.

## Independent review

- Reviewer: fresh general-purpose subagent
- Verdict: Accept
- Required findings: none. Checked and holding:
  - Revision behaviour is unchanged. `judge` (`Reviser.swift:108-120`) checks the old
    guards in their old order. For accepted and unchanged, `revise`
    (`Reviser.swift:94-97`) sets `revised`, `covered` and `yield` exactly as the old
    `accepted` branch did. For rejected, reply request removed, empty and failed, it
    keeps the window and advances `covered` (`Reviser.swift:98-103`), as before. For
    cancelled and superseded, it returns early without touching state, as the old
    `guard` did. The reply-request guard sits after faithfulness, which only changes the
    label: acceptance still requires non-empty, faithful and request-preserving.
  - Attempts are complete and in start order. Every request that returns reaches the
    append at `Reviser.swift:86-90`, including cancelled and superseded ones. Only an
    empty window, which makes no request, records nothing. Only one request can run at a
    time: `submit` starts a drain only when `working == nil`, `finish` awaits the drain
    before its final call, and the drain loop exits on `finishing`, so a `submit`
    followed by `stop` in `DictationController.swift:275-276` starts no request.
  - With capture off, nothing is stored. `started` is nil, so there is no append and no
    clock or `Date` read. The error description is still built for `judge` but is not
    kept.
  - Marks and faithfulness share one tokenizer, `Prose.tokens` (`Prose.swift:10`).
    Commit boundaries add up correctly because `TranscriptAssembler.join` joins segments
    with one space, so the word counts of the commit texts sum to the word count of
    `streamed`. The marking walk matches greedily and is equivalent to the
    `firstIndex` walk in `firstUnmatchedWord`.
  - Core imports only Foundation. `Mark` is not Codable, which is correct: it is derived
    data and not part of the JSON. `Prose` stays internal.
  - `revisionAttempts` is deterministic. The window arithmetic checks out, and
    `while attempts.count < 2 { Task.yield() }` always terminates.
  - `swift test` passes all 69 tests, and `swift build` reports no warnings. The
    `dictationTraceMarks` and `revision` filters are both included in that run.
- Optional observations:
  - `Mark.startsCommit` is a `Bool` (`DictationTrace.swift:95`). Workstream 2 has to
    pair the nth boundary with `commits[n]` to show the commit-gap hover, and the app
    cannot tell which commits contain no words without tokenizing. `Prose` is internal,
    and the packet forbids exposing it. Scenario: commit texts `["Hello", "…", "world"]`.
    The boundary before `world` is the first boundary, so the app pairs it with
    `commits[1]` (`…`) and shows the wrong gap. Such commits are rare, but a
    `commit: Int?` on `Mark` (the index into `commits` when a commit starts at this word)
    removes the pairing rule for about the same amount of code. This is the one change I
    would make before workstream 2 builds on the API.
  - Hyphens and dashes are separators, so they appear in no raw form. If the model turns
    `wait no` into `wait—no`, or `well known` into `well-known`, the words mark as kept
    and the dash does not show. The stutter `I-I'm` also renders as two marks, `I` and
    `I'm`, so workstream 2 will draw a space where the hyphen was. Both follow from the
    spec's rule, so neither blocks acceptance. Workstream 2 should know about them.
  - `Revision` has no public initialiser, so the app cannot build sample traces with
    requests for SwiftUI previews. Leave it until a preview needs one.
- Questions: none.

## Resolution

- Finding dispositions:
  - Optional 1 (`startsCommit` pairing): accepted as the one remediation item because
    the API freezes for workstream 2 and the app cannot detect wordless commits without
    tokenizing. `Mark.startsCommit: Bool` became `commit: Int?`, the index into
    `commits` of the commit that starts at that word. A wordless commit yields to the
    next, so `["Hello", "…", "world"]` marks `world` with commit 2. This is a shape
    adjustment within the spec's "adjust names as the code suggests".
  - Optional 2 (hyphens and dashes absent from marks): no change. It follows the
    spec's word rule; workstream 2 should render marks with that in mind.
  - Optional 3 (no public `Revision` initialiser): deferred until a preview needs it.
- Simplification/deletion pass: `marks` builds one word-index to commit-index map in a
  single loop; no other state or wrappers were added. `Prose.tokens` is the one
  tokenizer behind `words`, marks and faithfulness.
- Final verification: `swift test --filter dictationTraceMarks` (1 test) and
  `swift test --filter revision` (10 tests) pass after remediation. The closure
  reviewer's full `swift test` passes all 69 tests after remediation.

## Closure review

- Verdict: Accept
- Remaining required findings: none. The `commit: Int?` fix
  (`DictationTrace.swift:93-113`) holds. The first word always gets nil because
  `count > 0` guards the map entry, and that also covers leading wordless commits such
  as `["…", "Hello"]`. Words inside a commit have no entry, so they get nil. A wordless
  commit in the middle is overwritten by the next commit at the same word index, so
  `["Hello", "…", "world"]` gives `world` commit 2, as the test asserts. A trailing
  wordless commit maps to an index past the last word and is never read. The whole diff
  has no release-blocking defects. A full `swift test` passes 69 tests after
  remediation.
