# Debug window implementation plan

Status: implementation in progress.

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
| 2 | [Capture and show the last dictation](02-debug-window.md) | Workstream 1 accepted | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1–2 accepted | Not started |

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
  to complete the trace. Attempt capture is enabled only in debug mode.
- The controller publishes only the last dictation that reached `running`; tests and
  read-aloud never create a trace. Debug off retains no trace.

## Ownership handoffs

- Workstream 1 owns `Sources/EchoTypeCore/DictationTrace.swift`,
  `Sources/EchoTypeCore/Reviser.swift`, focused Core tests, and `Prose.swift` only if
  shared tokenization needs a focused change. Its accepted API is frozen for workstream
  2. A contract defect returns to its owner through escalation; workstream 2 does not
  silently rewrite it.
- Workstream 2 owns `Sources/EchoTypeApp/DictationController.swift`,
  `Sources/EchoTypeApp/App.swift`, `Sources/EchoTypeApp/Views/DebugWindow.swift`,
  `README.md`, and the new decision record plus index. No workstream overlaps these
  files. The final review may correct either owner after its lead assigns the fix.

## Whole-feature acceptance

- The approved [spec](../../specs/debug-window.md) is implemented without changing
  the behavior of normal dictation, read-aloud, reply requests or Settings.
- Focused Core tests and `swift test` pass; the app builds through the development
  script. Review records explain any unavailable command.
- Gate G1 passes with recorded evidence for the spec's Mac Final gate before
  workstream 2 is accepted.
- Decision record `0023-debug-window.md` and the README agree with the code.

## External validation gates

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1: Mac behavior | Workstream 2 | After closure, before acceptance | Pending | Signed development build from `./scripts/run.sh --debug`, with branch/head recorded in workstream 2 | Every Final gate check in the approved spec has evidence, including Aidan's evidence where the agent lacks microphone, xAI or desktop access |

## Escalations

Empty until a lead blocks. A blocking lead creates `E1`, then `E2` as needed, with
the decision needed, realistic options, recommendation, evidence and what it unblocks.
The orchestrator writes Aidan's answer into that entry. The resuming lead records the
lasting decision in its handoff and, if downstream work relies on it, in the log below,
then removes the resolved entry before acceptance.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-29 | `DictationTrace.Mark` carries `commit: Int?`, the index into `commits` starting at that word, in place of the spec's boundary flag. `Reviser` opts in with `init(..., capture: Bool = false)`. | The app needs the commit index for the gap hover and cannot count boundaries when a commit has no words. | Workstream 1 lead (spec allows adjusting names) | 1, 2 |
