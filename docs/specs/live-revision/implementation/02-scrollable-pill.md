# Workstream 02: Scrollable pill

Workflow status: draft. Workstream status: accepted after E02-light visual approval.
The task packet below records the original scope; Aidan's later decisions in `plan.md`
and the active validation section supersede its scrolling and soft-edge requirements.

## Task packet

### Outcome

The pill previews the full revised transcript, grows to eight wrapped lines, then scrolls
within its glass outline while the status row and shortcut hint stay fixed.

### Scope

- First, build two or three structurally distinct A/B/C layout variants in `--hud-demo`
  using the real `PillView` tokens and primitives. Each shows eight-line overflow, fixed rows,
  soft top and bottom scroll edges, and text arriving while scrolled up. Present them to Aidan
  and stop for his choice. Keep production behavior unchanged during this candidate stage.
- After the choice, implement only the selected variant and remove unused prototypes. Keep
  the panel anchored to the bottom of the visible screen as it grows.
- Follow the bottom by default, preserve position after the user scrolls up, and follow again
  only when they return to the bottom. Reset on a new session. Include revisions that alter
  text before the viewport in the position check.
- Make trackpad, wheel, and scrollbar scrolling safe during dictation. If click-to-stop
  conflicts, remove it and its dead callback/comments rather than build hit-testing machinery.
  Keep the hotkey, Escape, and read-aloud controls working.
- Use the native soft scroll edge effect above and below the transcript under the fixed rows.
  Keep the existing pill glass as the main surface.

### Non-goals

Revision algorithm, HTTP parameters, settings, transcript storage, and a new glass material
system. Do not add a general scrolling component for other screens.

### Initial ownership

`Sources/EchoTypeApp/Views/PillView.swift`, `Sources/EchoTypeApp/Views/PillDemo.swift`, and
`Sources/EchoTypeApp/OverlayPanel.swift`. `Sources/EchoTypeApp/DictationController.swift`
transfers from stream 01 only if click-to-stop is removed. Update matching comments in files
you own and record superseded portions of `docs/decisions/0008-pill-design.md` and
`docs/decisions/0009-overlay-behaviour.md`. No other source files without a documented
compile or integration need.

### Required seams

- Consume the stream 01 `Pill` value without duplicating transcript or revision state.
- Preserve the current nonactivating panel and target-field focus. Scrolling and layout
  changes must not make it key or main.
- Error and read-aloud pills remain legible and do not inherit dictation scroll position.

### Acceptance criteria

- Aidan chooses a variant before production layout work begins; unchosen prototypes are removed.
- The transcript grows to eight wrapped lines, then scrolls without enlarging the panel.
  Status and hint remain visible. The panel's lower edge stays anchored.
- New words follow at the bottom; scrolling up keeps the reading position through additions
  and revisions; returning to the bottom resumes following. A new session starts at bottom.
- The native soft edge treatment is visible at overflow on both edges without obscuring text.
  Aidan verifies it in the actual Mac pill in light and dark mode after closure.
- Scrolling never stops dictation. Read-aloud and error states remain usable. The app builds.

### Targeted verification

Run `swift build` and `./scripts/run.sh --hud-demo` on the Mac for variants and selected layout.
Check a small visible screen, both themes, wheel/trackpad and any scrollbar, scroll-up while new
text arrives, revision before the viewport, a new session, and continued focus in the target
app. The user visual check is an external gate after closure. Leave `swift test` to the final
gate.

## External validation

- Gate and placement: Design inspection before workstream acceptance.
- Status: Variant choice `Passed: A`; simplified design approved by Aidan for final review.
  Focused closure passed for the 184pt correction. Aidan approved that candidate in light
  and dark appearance.
- Candidate and instructions: The original shared pill layout is back, with one transcript
  `Text` growing to a 184pt cap, then fading and clipping older lines at the top. The
  blue level glow keeps its one-line depth. The 1.5 line height and clearer status,
  hint, and provisional text remain. Run `./scripts/run.sh --hud-demo` and inspect
  one-line growth, overflow, reading, and error in light and dark appearance.
- Required evidence: Aidan's design approval is recorded in `plan.md` as the E02-visual
  decision. He then checked the 184pt candidate in both appearances and approved its fade,
  newest-line readability, and indicator-to-label gaps. The built-in display has a
  1512pt by 890pt visible frame, leaving ample height for the pill's 184pt transcript cap,
  rows, and padding. Real dictation focus belongs to the final gate.
- Attempts and lasting decisions: Candidate build and review passed on 2026-09-26. Aidan chose
  A and asked for translucent blur under the rows and looser line height. After a hands-off
  recheck, Aidan approved a local AppKit text view to anchor the visible glyph. The selected
  demo and focused closure now pass. The apparent change in the first line's opening words
  came from text rewrapping; the same glyph stayed at the same reading height.
- Resume condition: Met. Aidan approved the latest candidate and asked to proceed to final
  review once this gate passed.

### Native soft edge probe after E02-render

- Aidan chose a two-to-eight-line preview that keeps the newest text visible without user
  scrolling. The full transcript still goes to insertion; older corrections may leave the
  preview. Text should continue under the fixed header and fade and blur toward the pill's
  top edge. This supersedes the scrolling and reading-position behavior in the current spec,
  pending a spec update with the full implementation.
- Only `PillDemo.swift` changed for this probe. Its separate `ProbePanel` leaves the production
  `PillView` and `OverlayPanel` untouched. Run `./scripts/run.sh --hud-demo` to see two lines
  grow to an eight-line viewport, then follow new lines through line 12 without user scrolling.
- `swift build -q`, the demo launch, and `git diff --check` passed. In the actual Mac pill in
  light appearance, the header and hint stayed pinned, and the newest line remained visible.
  The scroll view uses `.scrollDisabled(true)` and a programmatic bottom anchor. Native
  `.scrollEdgeEffectStyle(.soft, for: .vertical)` needed `.safeAreaBar` to show a blurred edge.
  It also drew shaded header and footer bands with straight boundaries before overflow. At
  overflow, older text blurred under the header, but did not visibly fade to zero at the
  pill's top edge. The effect's entrance animation was not established; the explicit
  animation in the probe only moves the scroll position. Dark appearance was not checked.
- Independent review saw the bands and incomplete fade, but Aidan inspected the probe and
  said the native effect at the top is what he wants. For the eventual design, remove the
  footer effect because text never passes behind it, and add bottom padding to the header
  and padding to the footer. Keep this probe uncommitted. The full implementation and its
  light/dark visual approval remain pending. The native effect's entrance animation has not
  been established by the probe.

## Implementation handoff

- Base commit: `ae3bba84c4ac4e608653ac6006b152f530534c34`. I audited the interrupted diff and kept the stream 01 `Pill` integration, nonactivating `OverlayPanel`, and click-to-stop removal.
- Outcome: Aidan's E02-render decision supersedes the earlier scroll and reading-position candidate. The production pill now starts at two wrapped lines, grows to eight, and follows the newest text without user scrolling. The full `Pill` text remains available to the controller for insertion. Older corrections can leave the preview. The fixed header uses the native top `.soft` effect; the footer sits outside the scroll view, with no footer edge effect. Header and footer have symmetric 12pt vertical padding. Transcript line height is 1.5; the rows and provisional text have stronger contrast.
- Files changed in this pass: `PillView.swift`, `PillDemo.swift`, `live-revision.md`, and decisions 0008/0009. Earlier uncommitted `OverlayPanel.swift` and `DictationController.swift` changes remain part of this workstream. The packet's prior probe notes and earlier review remain as history; this handoff describes the replacement candidate.
- Simplification: Removed the AppKit text view, visible-glyph anchoring, scroll coordinator, custom edge mask and blur, user scroll state, and separate `ProbePanel`. `--hud-demo` again uses production `OverlayPanel` and `PillView`.
- Verification: `swift build -q`, `./scripts/run.sh --hud-demo`, and `git diff --check` passed on the Mac. A screen capture of the running production demo showed the fixed header, newest text at overflow, and compact lower hint. Aidan's initial screenshot exposed a clipped first line at the two-line size. The height calculation now reserves the native-bar inset and an 8pt initial text gap; `/tmp/echotype-two-gap.png` shows both initial lines fully readable with space below the header. `/tmp/echotype-two-fixed.png` shows eight full lines at overflow with older text blurred beneath the header. The native effect's entrance animation and dark appearance still need a focused visual check. No test suite was run; the final gate owns it.
- Remaining external checks: After closure, Aidan must inspect the actual pill's top effect in light and dark mode. The small-screen and real dictation focus checks are still pending. No commit was made.
- Specification drift: The approved spec now records Aidan's superseding E02-render choice. The packet's original task and earlier review text remain historical and should not be used as current acceptance behavior.
- Interrupted-work recovery: On `live-revision` at `ae3bba8`, the uncommitted source and document changes remain attributable to workstream 02. Aidan's latest direction in `plan.md` supersedes this handoff's two-line minimum, eight-line measurement, and height animation. A fresh implementation-agent spawn failed with `agent thread limit reached`, so this recovery pass made no source changes or review claim. Preserve the diff and resume at implementation when a fresh agent slot exists.
- Resumed implementation after Aidan's natural-height direction: Replaced the two-to-eight-line height calculation with a single wrapped-text measurement and a tunable 180pt cap on the transcript area. The status and hint keep their own measured heights and symmetric 12pt vertical padding. Removed the pill and panel height animations. The native top `.soft` effect, bottom following, disabled user scrolling, fixed rows, and nonactivating panel remain. The demo starts with one line, then exercises overflow, an earlier correction, transcribing, reading, and error states. Updated the approved spec and decisions 0008/0009 to reflect the superseding pixel cap. No new state or source file was added.
- Resumed verification: `swift build` passed. `./scripts/run.sh --hud-demo` launched the production panel after the final demo wording change. Mac screenshots at `/tmp/echotype-natural-one-final.png` and `/tmp/echotype-natural-latest.png` showed natural growth, fixed rows, and the newest complete line at overflow beneath the native top edge. The running demo also showed a legible compact error pill. The actual light/dark visual gate, focus during real dictation, and small-screen check remain for the lead and Aidan. No test suite or commit was run in this pass.
- Review remediation: Updated only the active External validation instructions and evidence to describe the one-line start, 180pt transcript cap, newest-text following, fixed rows, and native top edge in both themes. The earlier A/B choice and probe notes remain as history. No source change was needed. Focused closure caught a 240pt documentation error in the first remediation and a missing overflow entrance check; both are corrected in the active gate and implementation record.
- Final simplified candidate: I audited the workstream diff at `ae3bba8` against Aidan's E02-visual answer. The one-`Text` preview starts at its natural height, caps at 180pt, follows new text at the bottom, and fades older text over the top 20pt. The status and hint retain their shared layout; the glow uses a fixed one-line depth. Click-to-stop, user scrolling, the native soft edge, AppKit anchoring, and unused layout variants are absent. I found no source change needed. Aidan likes this candidate and says it is ready for final review.
- Documentation cleanup: Updated the approved spec and decisions 0008/0009 to describe that behavior and the final indicator opacities. These amend the existing records without a new ADR. The original task packet and earlier review remain historical; this bullet supersedes the earlier candidate descriptions in this handoff.
- Final implementation verification: `swift build -q`, `./scripts/run.sh --hud-demo` launch, and `git diff --check` passed on the Mac. This pass did not repeat visual inspection or run the test suite. Aidan's answer does not say whether he checked light appearance; small-screen fit and real dictation focus also have no recorded evidence. The lead should resolve those gate details during review.
- Fade remediation: Independent review found that the bottom-aligned 180pt mask dimmed content once it grew past 160pt, before overflow. `Transcript` now measures the existing text view's rendered height and applies the 20pt mask only when it exceeds 180pt. This adds one derived Boolean and no extra text view or measurement copy; short transcripts remain fully opaque. The approved spec and decision record already describe this behavior. `swift build -q`, `./scripts/run.sh --hud-demo` launch, and `git diff --check` passed. I did not claim a new visual check or edit the active gate record.
- E02-light correction: Removed the indicators' shared 18pt width so the existing 8pt status-row spacing follows each indicator's natural width. The waveform, spinner, and error triangle can place their labels independently. Raised the transcript cap from 180pt to 184pt and the mask's top alpha from zero to 0.35; the 20pt fade still starts only after overflow. Aidan's 180pt screenshot showed only bottom strokes of the clipped line, while 188pt showed too much. The 184pt demo screenshot at `/tmp/echotype-e02-gap-fade-184.png` cuts through roughly half the top lowercase glyphs and keeps the newest line visible. The simplification pass found no extra state or wrapper to remove. `swift build`, `./scripts/run.sh --hud-demo`, and `git diff --check` passed. The latest candidate still needs Aidan's light and dark visual check; no test suite or commit was run.

## Independent review

- Reviewer: Fresh review of the complete workstream diff against `ae3bba84c4ac4e608653ac6006b152f530534c34` after Aidan's E02-light direction. I read the approved spec, current gate and decisions 0008/0009, checked source ownership and the 184pt demo screenshot, and ran `swift build -q` and `git diff --check`; both passed.
- Verdict: No code finding blocks this candidate. `PillView.swift` uses natural indicator widths with the status row's 8pt spacing, caps the single bottom-aligned transcript at 184pt, and enables its 20pt mask only after measured overflow. The screenshot at `/tmp/echotype-e02-gap-fade-184.png` shows the clipped top line cut through lowercase glyphs and the newest line readable at the bottom. `OverlayPanel` remains nonactivating and bottom anchored. Click forwarding, scrolling machinery, and unused variants are absent.
- Required: Aidan's visual check in the actual pill in both light and dark appearance remains open under E02-light. The screenshot supports the proposed cut but does not establish both appearances or the indicator gaps across listening, transcribing, and error states. Keep workstream acceptance behind that recorded gate.
- Optional: `PillDemo.swift` no longer cycles through starting, paused, empty, or elapsed-warning states. Its current sequence covers overflow, transcribing, reading, and error, so restoring those scenes is outside this correction.
- Question: The spinner's `scaleEffect(1.15)` paints slightly outside its natural layout width, so its visible gap may be smaller than the status row's 8pt spacing. The code alone cannot settle the visual result; include it in Aidan's phase-by-phase gate check. The small-screen fit check is still unrecorded. Real-dictation focus remains in the final Mac gate.

## Resolution

- Finding dispositions: The production review's combined revision and append finding was
  accepted. The AppKit repair anchors a visible glyph through the combined update. Focused
  closure confirmed that its screen position holds; a changed line prefix comes from rewrapping.
  The independent review's width question was addressed by removing AppKit's horizontal text
  padding and checking eight fully readable lines in the demo.
- Simplification/deletion pass: B and C, the two-line tail layout, and click forwarding were
  removed. The selected view reads the stream 01 `Pill` directly.
- Final verification: `swift build -q`, selected demo launch, `git diff --check`, and focused
  closure passed. Aidan's visual approval remains pending.
- Latest candidate: Aidan confirmed the 180pt transcript cap. The independent review's
  240pt references were inaccurate; focused closure caught them in the active gate and
  handoff. The corrected gate checks the native top effect's entrance at overflow in
  both themes. Visual approval remains pending.
- Current resolution: Accepted the review finding about premature fading and fixed it by
  applying the mask only after text exceeds 180pt. The current focused closure passed.
  Aidan approved the simplified design and asked to proceed to final review, but the
  required visual check of this final fade behavior in both appearances is not recorded.
  The new E02-light gate in `plan.md` holds workstream acceptance; no commit was made.
- E02-light triage: The latest independent review found no code defect in the 184pt and
  indicator-gap correction. The phase-by-phase spinner gap is a visual question for Aidan,
  not a basis for more code before his inspection. The reduced demo scene list is optional
  and stays outside this correction. Light and dark approval and small-screen fit remain
  at the external gate; real dictation focus remains in the final Mac gate.
- E02-light acceptance: Aidan checked the final 184pt pill in light and dark appearance and
  approved the fade, newest-line readability, and indicator-to-label gaps. The 14-inch
  built-in screen's visible frame is 1512pt by 890pt, sufficient for the capped pill.
  The final Mac gate still owns focus during real dictation. No further source change was
  needed after focused closure.

## Closure review

- Verdict: Focused closure passes. The two required documentation corrections are present, with no remaining required finding in this fix.
- The active `External validation` gate and resumed implementation handoff now state the 180pt cap used by `PillView.swift:69`. The gate instructions and required evidence now include the top effect's entrance at overflow in both themes.
- `git diff --check` passed. This documentation recheck did not rerun the build or demo. The small-screen, real-dictation focus, and Aidan light/dark checks remain external gates.

### Simplified candidate closure, 2026-09-27

- Verdict: Focused closure passes for the two required findings in the latest independent review. No release-blocking defect was found in their fixes.
- `Transcript` measures the rendered height of its existing `Text` and uses an opaque rectangle until that height exceeds 180pt. The 20pt gradient appears only after overflow, so the pre-overflow lines no longer enter the fade region. The error branch does not use the mask.
- The active visual gate and `plan.md` record Aidan's approval of the simplified design and his request to proceed to final review after this gate. Both leave the light-appearance check of the latest fade fix open. That check still needs evidence before workstream 02 acceptance; the existing small-screen and real-dictation focus checks remain outstanding at their recorded gates.
- Read-only verification: inspected the accepted source and document changes; `git diff --check` passed. The implementation handoff records a passing build and demo launch after the fade fix. This closure did not repeat the visual check or test suite.

### E02-light correction closure, 2026-09-27

- Verdict: Focused closure passes for the accepted 184pt fade and indicator-gap correction. I found no release-blocking defect in those changes.
- `Transcript` caps the bottom-aligned single `Text` at 184pt and applies its 20pt, 0.35-to-opaque top mask only when the measured text exceeds the cap. The error branch keeps its two-line limit without that mask. The 184pt demo screenshot shows the top edge crossing roughly half of the clipped lowercase line while the newest line remains readable.
- The status row retains 8pt spacing and no longer gives the waveform, spinner, and error triangle a shared 18pt slot. The approved spec, decisions 0008/0009, active packet gate, and E02-light plan entry describe the current cap and layout. Earlier 180pt records remain dated history.
- Read-only verification: inspected the workstream diff against `ae3bba84c4ac4e608653ac6006b152f530534c34`, the current source and screenshot, and ran `git diff --check`, which passed. The independent review records a passing `swift build -q`; this closure did not repeat the build, demo launch, or test suite.
- Aidan's check of the latest production pill in light and dark appearance remains required before workstream acceptance. That check includes the visual gaps in listening, transcribing, and error states; the spinner's scaled optical gap cannot be settled from code alone. Small-screen fit stays with this visual gate, and real-dictation focus stays with the final Mac gate. The reduced demo scene list remains optional and does not block this correction.

## Later design iteration

- On 2026-09-27 Aidan replaced the native-edge candidate with the original shared pill
  layout as a simpler design base. `PillView` now uses one `Text` transcript inside a
  bottom-anchored 180pt-capped layout. It has no scroll view, hidden measurement views,
  separate phase header, or top fade/blur. The 1.5 line height and stronger small-text
  contrast remain. `PillDemo` describes clipping rather than a native soft edge.
- The earlier review and closure apply to the previous candidate. `swift build -q`,
  `./scripts/run.sh --hud-demo`, and `git diff --check` passed. The dark-appearance demo
  showed natural growth and clipping at the 180pt cap. Aidan's visual inspection and any
  later review remain open. The final whole-feature review stays paused at his request.
- After Aidan liked the simplified layout, a 20pt alpha fade was added at the top of the
  capped transcript. Its mask is aligned to the bottom so short transcripts stay opaque.
  The level glow now uses a fixed 96pt reference height for its wave depth and gradient.
  `swift build -q` and the production demo launch passed. Dark-appearance captures showed
  an opaque first line and the fade at overflow. Aidan has not inspected this revision yet.
- Aidan then requested one opacity for provisional text, status, time, and hint, with the
  meter and transcribing spinner below it. His correction kept the original bar width and
  height mapping and set the trial opacities to 0.65 for supporting text and 0.40 for the
  indicators. The spinner is scaled 1.15 times. `swift build -q` and demo launch passed;
  listening and transcribing were inspected in dark appearance. Visual approval remains open.
