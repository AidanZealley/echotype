# Live revision implementation plan

Status: accepted. Whole-feature review and the final endpoint and dictation gate passed.

## Orchestration record

- Integration branch: `live-revision`
- Starting commit: `4c54c61d74bad82c316b0cbe192627fbe28faaaf`
- Review method: fresh lead subagents

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Live revision pipeline](01-revision-pipeline.md) | Approved spec | Accepted |
| 2 | [Pill layout](02-scrollable-pill.md) | Workstream 1 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1 and 2 | Accepted |

## Why these boundaries

The first stream owns transcript state, the Grok request, lifecycle integration, settings, and
removal of the batch path together. Splitting its core and app changes would force a temporary
adapter that the next stream deletes. The second stream owns the macOS panel and SwiftUI
pill layout, where design choices and visual approval form a separate acceptance decision.
Run them sequentially because both touch the pill's input contract.

## Cross-workstream contracts

- Workstream 1 supplies one `Pill` value with revised committed text, current settled text,
  provisional text, phase, and session identity. Workstream 2 changes how it renders, not how
  revision decisions are made.
- The text inserted on stop equals the pill's final transcript. A failed or rejected revision
  leaves its streamed input in place. Test sessions never revise.
- `SessionMachine.Snapshot` separates committed text from current utterance runs. Workstream 2
  may consume the assembled `Pill`, but must not duplicate transcript state.
- The preview follows newest text without user scroll state.

## Ownership handoffs

- Workstream 1 initially owns `Sources/EchoTypeCore/SessionMachine.swift`,
  `Sources/EchoTypeCore/Settings.swift`, the new reviser and request code, relevant core tests,
  `Sources/EchoTypeApp/DictationController.swift`, and `Views/SettingsView.swift`; it removes
  `BatchTranscriber` and its tests. It may update related comments and decision records.
- Workstream 2 owns `Sources/EchoTypeApp/Views/PillView.swift`, `Views/PillDemo.swift`, and
  `Sources/EchoTypeApp/OverlayPanel.swift`. It may edit `DictationController.swift` only to
  remove click-to-stop. It updates decision records 0008 and 0009 where
  the new layout or interaction supersedes them. This is a sequential handoff after stream 1.

## Whole-feature acceptance

- Both workstreams accepted with their own reviewed commits.
- The spec's tests run as the final gate, including real prompt cases with `XAI_API_KEY`.
- Mac dictation checks cover pause joins, corrections, insertion parity, and stop latency.
- Aidan has verified the simplified pill in light and dark mode.
- Superseded batch code, settings, comments, and decision status are removed or updated.

## External validation gates

| Gate | Owner | Placement | Status | Candidate and resume condition |
|---|---|---|---|---|
| Pill variant choice | 02 | Before implementation | Passed: A | Aidan chose A and requested translucent blur under the rows and looser line height. |
| Pill visual check | 02 | After closure, before acceptance | Passed | Aidan approved the 184pt candidate's fade, newest-line readability, and indicator-to-label gaps in light and dark appearance. |
| Final endpoint and dictation | Final | After whole-feature closure, before acceptance | Passed | Aidan reports prompt tests passed, insertion took under one second, and all requested manual observations passed. |

## Escalations

None open. The answered final gate is recorded in [final-review.md](final-review.md).

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-26 | Choose layout A; keep text visible beneath translucent, increasingly blurred header and footer edges; loosen line height | Variant gate answer | Aidan | 02 |
| 2026-09-26 | Recheck the scroll shift with no input; correct it if reproduced and keep the approved reading-position behavior | E02-scroll answer | Aidan | 02 |
| 2026-09-26 | Use a local AppKit text view to anchor the visible glyph while keeping layout A and its soft edges | E02-anchor answer; focused closure confirmed the anchor | Aidan | 02, Final |
| 2026-09-26 | Use a two-to-eight-line preview that follows newest text without user scrolling; retain full text for insertion | E02-render answer; older corrections may be out of view | Aidan | 02, Final |
| 2026-09-26 | Use the native top effect shown in the isolated probe; remove the footer effect and add row padding in the final layout | Aidan inspected the probe | Aidan | 02 |
| 2026-09-26 | Start at one natural transcript line, cap transcript growth in pixels, and follow newest text without user scrolling or height animation | Aidan's later layout direction; supersedes the two-to-eight-line size rule | Aidan | 02, Final |
| 2026-09-26 | Use a 180pt transcript cap for the current pill candidate | Aidan confirmed his change from 240pt to 180pt | Aidan | 02, Final |
| 2026-09-27 | Return to the original shared pill layout, grow the transcript to 180pt, and clip older lines at the top; keep 1.5 line height and clearer small text | Aidan wants a simpler base before exploring fades or blur | Aidan | 02, Final |
| 2026-09-27 | Add a short alpha fade at the transcript's top and keep the blue glow at its one-line depth | Aidan liked the simplified layout and requested both visual adjustments | Aidan | 02, Final |
| 2026-09-27 | Use 0.65 opacity for provisional, status, time, and hint; use 0.40 for the original-width meter and spinner | Aidan corrected the first contrast trial and kept the original bar shape | Aidan | 02 |
| 2026-09-27 | Approve the simplified pill design for final review and document its final behavior in the existing spec and decisions, with no new ADR | E02-visual answer; light-appearance verification remains open | Aidan | 02, Final |
| 2026-09-27 | Keep a consistent icon-to-label gap and show about half of clipped lowercase glyphs at a 184pt cap | E02-light visual corrections; 180pt and 188pt clipped too much and too little | Aidan | 02, Final |
| 2026-09-27 | Approve the 184pt pill in light and dark appearance | E02-light final visual check passed for the fade, newest line, and indicator gaps | Aidan | 02, Final |
| 2026-09-27 | Final review found no specification drift; endpoint and dictation gate passed | Local checks and independent review passed; Aidan confirmed the endpoint, timing, and manual observations | Aidan | Final |
