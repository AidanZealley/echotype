# Debug window implementation plan

Status: accepted, 2026-09-29.

## Orchestration record

- Integration branch: `debug-window`
- Starting commit: `e7fe4d1b2afa2648f6aee2192ba95e566a130704`
- Review command: lead subagents
- Specification approved at commit: `e7fe4d1b2afa2648f6aee2192ba95e566a130704`
- Started: 2026-09-29

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Trace and revision evidence](01-trace-core.md) | Approved spec | Accepted |
| 2 | [Capture and show the last dictation](02-debug-window.md) | Workstream 1 accepted | Accepted |
| 3 | [Make Last Dictation a normal feature](03-remove-debug-gate.md) | Workstream 2 accepted | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1–3 accepted | Accepted |

## Why these boundaries

Workstream 1 owns the Core trace value, word matching and request evidence as one
reviewable contract. Workstream 2 consumes that contract in the macOS lifecycle and
delivers the complete window. The boundary follows the existing Core/App packages;
it avoids concurrent edits to shared files and leaves one Mac validation gate with
the app owner. Documentation follows the app workstream that makes it true.

## Cross-workstream contracts

- `DictationTrace` is a `Codable`, `Equatable`, `Sendable` value in EchoTypeCore. It
  carries the spec's commits, revisions, streamed and inserted text, session outcome
  and timestamps. The app renders and JSON-encodes this one value.
- `DictationTrace.marks` uses the same word normalization as `Reviser.isFaithful`,
  currently implemented in `Prose.words`. Both owners preserve the reply-request
  safeguard from decision [0022](../../decisions/0022-voice-replies.md).
- `Reviser.attempts` is ordered by request start. Each settled attempt contains its
  request window, raw reply when one arrived, result and measured duration. A
  deliberately cancelled dictation need not wait for an in-flight model response just
  to complete the trace. Workstream 3 makes attempt capture unconditional and removes
  the `capture` parameter.
- The controller publishes only the last dictation that reached `running`; tests and
  read-aloud never create a trace. Workstreams 1 and 2 gate the trace on `--debug`.
  Workstream 3 removes the gate, so every launch with a controller retains the last
  trace in memory, and `--debug` no longer exists.

## Ownership handoffs

- Workstream 1 owns `Sources/EchoTypeCore/DictationTrace.swift`,
  `Sources/EchoTypeCore/Reviser.swift`, focused Core tests, and `Prose.swift` only if
  shared tokenization needs a focused change. Its accepted API is frozen for workstream
  2. A contract defect returns to its owner through escalation; workstream 2 does not
  silently rewrite it.
- Workstream 2 owns `Sources/EchoTypeApp/DictationController.swift`,
  `Sources/EchoTypeApp/App.swift`, `Sources/EchoTypeApp/Views/DebugWindow.swift`,
  `README.md`, and the new decision record plus index. Workstreams 1 and 2 overlap in no
  files.
- Workstream 3 takes over both accepted workstreams' files for this change:
  `Reviser.swift`, `DictationTrace.swift` (comments only), `ReviserTests.swift`,
  `DictationController.swift`, `App.swift`, `Views/DebugWindow.swift` (renamed to
  `Views/LastDictationWindow.swift`), `README.md`, `docs/specs/debug-window.md`,
  decision 0023 and its index entry. The final review may correct any owner after its
  lead assigns the fix.

## Whole-feature acceptance

- The approved [spec](../../specs/debug-window.md) is implemented without changing
  the behavior of normal dictation, read-aloud, reply requests or Settings, with Aidan's
  2026-09-29 change: Last Dictation, including its diagnostic detail, is a normal
  feature with no debug gate.
- Focused Core tests and `swift test` pass; the app builds through the development
  script. Review records explain any unavailable command.
- Gate G1 passes with recorded evidence for the spec's Mac Final gate before
  workstream 2 is accepted. Gate G2 passes with recorded evidence for workstream 3's
  External validation before workstream 3 is accepted.
- The spec, decision record `0023-debug-window.md` and the README agree with the code.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1: Mac behavior | Workstream 2 | After closure, before acceptance | Passed | Signed development build from `./scripts/run.sh --debug`, with branch/head recorded in workstream 2 | Passed 2026-09-29: Aidan ran every Final gate check on `debug-window` at `d34e023` plus workstream 2's diff, and all passed. Evidence is in workstream 2's External validation. |
| G2: Ungated Mac behavior | Workstream 3 | After closure, before acceptance | Passed | `debug-window` at `45c7c05` plus the layout correction to `Views/LastDictationWindow.swift`, built with `./scripts/run.sh` | Passed on `d8d334d` plus workstream 3's diff. Aidan then found two layout defects on the accepted build (paragraph overlapping the summary on resize; centred expanded rows). Passed again 2026-09-29: Aidan re-checked the correction and both checks passed. Evidence is in workstream 3's External validation, G2 re-check. |

## Escalations

A blocking lead creates `E1`, then `E2` as needed, with
the decision needed, realistic options, recommendation, evidence and what it unblocks.
The orchestrator writes Aidan's answer into that entry. The resuming lead records the
lasting decision in its handoff and, if downstream work relies on it, in the log below,
then removes the resolved entry before acceptance.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-29 | `DictationTrace.Mark` carries `commit: Int?`, the index into `commits` starting at that word, in place of the spec's boundary flag. `Reviser` opts in with `init(..., capture: Bool = false)`. | The app needs the commit index for the gap hover and cannot count boundaries when a commit has no words. | Workstream 1 lead (spec allows adjusting names) | 1, 2 |
| 2026-09-29 | Workstream 2 renders the marked paragraph as a non-editable, selectable `NSTextView` built from one attributed string, in place of the spec's SwiftUI `Text`. | SwiftUI `Text` has no hover for part of a paragraph, and the spec requires tooltips on changed words and commit marks. Wrapping and selection are kept; copying the paragraph includes the `\|` marks. Recorded in 0023. | Workstream 2 lead | 2 |
| 2026-09-29 | Last Dictation becomes a normal feature for everyone. The debug gate is removed from the whole window, including the diagnostic detail. Workstream 2 is accepted exactly as validated, with the gate. A new workstream 3 removes the gate and updates the spec, decision 0023 and the README before the final review. | Aidan's follow-up to E1, after G1 passed on the gated candidate. | Aidan | 3, Final |
| 2026-09-29 | Final review found no Required defects. Docs synced: the spec's Marking bullet describes the commit index, 0011's helper and close rule are marked superseded by 0023, and 0007's fullscreen menu gap names both windows. | Keep records in sync with the accepted code; no behavior change. | Final-review lead | Final |
