# Live revision implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `TBD`
- Starting commit: `TBD`
- Review method: fresh lead subagents
- Approved specification commit: `TBD`
- Started: `TBD`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Live revision pipeline](01-revision-pipeline.md) | Approved spec | Not started |
| 2 | [Scrollable pill](02-scrollable-pill.md) | Workstream 1 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1 and 2 | Not started |

## Why these boundaries

The first stream owns transcript state, the Grok request, lifecycle integration, settings, and
removal of the batch path together. Splitting its core and app changes would force a temporary
adapter that the next stream deletes. The second stream owns the macOS panel and SwiftUI
scrolling, where layout variants and visual approval form a separate acceptance decision.
Run them sequentially because both touch the pill's input contract.

## Cross-workstream contracts

- Workstream 1 supplies one `Pill` value with revised committed text, current settled text,
  provisional text, phase, and session identity. Workstream 2 changes how it renders, not how
  revision decisions are made.
- The text inserted on stop equals the pill's final transcript. A failed or rejected revision
  leaves its streamed input in place. Test sessions never revise.
- `SessionMachine.Snapshot` separates committed text from current utterance runs. Workstream 2
  may consume the assembled `Pill`, but must not duplicate transcript state.
- Scroll follow state belongs in `PillView` for one session. It resets when `startedAt` changes.

## Ownership handoffs

- Workstream 1 initially owns `Sources/EchoTypeCore/SessionMachine.swift`,
  `Sources/EchoTypeCore/Settings.swift`, the new reviser and request code, relevant core tests,
  `Sources/EchoTypeApp/DictationController.swift`, and `Views/SettingsView.swift`; it removes
  `BatchTranscriber` and its tests. It may update related comments and decision records.
- Workstream 2 owns `Sources/EchoTypeApp/Views/PillView.swift`, `Views/PillDemo.swift`, and
  `Sources/EchoTypeApp/OverlayPanel.swift`. It may edit `DictationController.swift` only to
  remove click-to-stop if scrolling conflicts. It updates decision records 0008 and 0009 where
  the new layout or interaction supersedes them. This is a sequential handoff after stream 1.

## Whole-feature acceptance

- Both workstreams accepted with their own reviewed commits.
- The spec's tests run as the final gate, including real prompt cases with `XAI_API_KEY`.
- Mac dictation checks cover pause joins, corrections, insertion parity, and stop latency.
- Aidan has chosen a pill variant and verified the soft scroll edge effect in the actual pill
  in light and dark mode.
- Superseded batch code, settings, comments, and decision status are removed or updated.

## External validation gates

| Gate | Owner | Placement | Status | Candidate and resume condition |
|---|---|---|---|---|
| Pill variant choice | 02 | Before implementation | Pending | A/B/C in `--hud-demo`; resume after Aidan selects one. |
| Pill visual approval | 02 | After closure, before acceptance | Pending | Selected pill on Mac in light and dark mode at overflow; resume after Aidan approves the edges or gives a correction. |
| Final endpoint and dictation | Final | After whole-feature closure, before acceptance | Pending | Final Mac build, prompt cases using `XAI_API_KEY`, timed real dictation; resume when evidence passes or Aidan decides a required adjustment. |

## Escalations

Empty until a lead blocks. Each entry holds the decision needed, realistic options,
recommendation, evidence, what it unblocks, and the user's answer. The resuming lead records
the lasting decision in its packet and the log below when later streams depend on it, then
removes the entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| — | None | — | — | — |
