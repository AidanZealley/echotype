# Debug window whole-feature review

Status: accepted, 2026-09-29. Covers workstreams 1–3.

## Reviewer task packet

Review the whole integration branch against the starting commit in `plan.md` and the
[approved spec](../../specs/debug-window.md). Read accepted handoffs, then inspect the
combined diff and surrounding code independently. Check behavior, cross-workstream
seams, session and window lifecycle, Core/App dependency direction, reply-request
behavior, duplicated state, speculative machinery, test value and documentation.
Verify the G1 evidence and identify any unverified external behavior. Run `swift test`
and a proportionate app build if the environment permits. Findings are Required,
Optional or Question, with file and behavior evidence.

The final-review lead assigns accepted corrections to fresh implementation agents by
the ownership in `plan.md`, then asks a fresh reviewer for focused closure. Do not
start another open-ended review after closure. Record optional improvements without
making them automatic work.

## Initial whole-feature review

- Reviewer: fresh whole-feature reviewer subagent.
- Branch, base, and reviewed head: `debug-window`, base `e7fe4d1`, reviewed head
  `e052dcc` (workstreams 1–3). The only uncommitted changes are the Final row and this
  file's status line.
- Verification run: `swift build` completes cleanly. `swift test` passes 69 tests. The app
  was not launched, because that needs the microphone, xAI and desktop focus. A repo-wide
  `git grep` for `--debug`, `DebugWindow`, `capture:` and "debug gate" outside this
  directory finds only the intentional history in 0023 ("Change of decision") and the
  spec's status line and Decision record section. Scripts never had a `--debug` path:
  `run.sh` passes its arguments through, and no script changed.
- Acceptance-criteria audit:
  - Ungated recording and menu item: met. `App.swift:46` and `:116` show **Last
    Dictation…** below **Settings…** whenever a controller exists, so `--hud-demo` has no
    item. `DictationController.swift:256` starts a trace on every `running` session.
  - Launch state and restoration: met. `.defaultLaunchBehavior(.suppressed)` and
    `.restorationBehavior(.disabled)` are at `App.swift:68-70`. The old launch-time
    `.regular` policy was removed with the gate. The app targets macOS 26, so both
    modifiers are available.
  - Activation with both windows: met. `presentWindow` (`App.swift:127`) is shared.
    `windowClosed` (`App.swift:146`) returns to `.accessory` only when no main-capable
    window is visible or minimised. It checks on the next turn and is wired to both
    scenes.
  - Last dictation of any outcome: met. `publishTrace` runs after `finish`, while `phase`
    is still `.running` (the `defer` at `:245`). A new dictation therefore cannot replace
    `trace` mid-publish. `.cancelled` comes from the snapshot state (`:431`), and
    `test()` passes through `run` with `trace == nil`. A cancellation does not wait for
    in-flight requests, because `Reviser.stop()` does not await `working`.
  - Updates without focus: met. The window only observes `lastTrace` and makes no
    ordering calls.
  - In memory only: met. There is no persistence or logging. Only Copy as JSON writes to
    the pasteboard.
  - Layout: met. The summary line, the marks (red strikethrough, amber changes with a
    streamed-form tooltip, commit bar with a gap tooltip), the request rows with a
    `rejected at "word"` label that expand to window and reply, Copy as JSON, and system
    colours all match the spec. "No dictation yet" shows before the first trace.
  - Reviser mapping and the 0022 safeguard: met. `judge` (`Reviser.swift:104`) keeps
    the old accept rule exactly: not cancelled, not superseded, not thrown, non-empty,
    faithful, and keeps any reply request. Only accepted and unchanged update `revised`
    and yield. The other results keep the window and advance `covered` as before.
    `replyRequestRemoved` is checked after faithfulness (`:114`), so the outcome is the
    same as the old combined boolean.
  - Core/App direction: met. `DictationTrace`, `Prose.tokens` and `attempts` live in
    Core with no App dependency. Marking reuses the shared tokenizer, so there is one
    normalisation.
  - Tests: met. There is one marks test (the spec's example, an empty-word commit and a
    JSON round trip) and one attempts test (accepted, rejected at the added word,
    failed, in order). Both protect contracts the window depends on.
  - Docs agree with the code: met for the spec, 0023, its index row and the README. See
    O1 for 0011.
  - G1 and G2 evidence: recorded. G1 passed on `d34e023` plus workstream 2's diff, on
    Aidan's aggregate "all passed" report without per-item notes. G2 passed on `d8d334d`
    plus workstream 3's diff, with per-item evidence for launch state, menu item, empty
    window and one recorded dictation. `git show e052dcc` matches the G2 candidate
    described. Not re-observed on the ungated build: `--hud-demo` having no item, two
    windows open at once, Escape cancellation, themes, and no restore after quitting with
    the window open. Workstream 3 did not change any of that code except removing the
    launch-time `.regular` policy, which G2's launch-state check covered, so I judge the
    remaining risk low.
- Required findings by owner: none.
- Optional observations:
  - O1 (docs, 0011 has no owner in plan.md, so the final lead assigns it):
    `docs/decisions/0011-settings-window-activation.md:20` still says `SettingsButton`
    sets `.regular` and the scene's `onDisappear` sets `.accessory`. Its index row
    (`docs/decisions/README.md:23`) still reads plain "Accepted". 0023 replaces that
    helper and the unconditional `.accessory`. The decisions README says a reversed
    record should be marked superseded and linked. Suggested fix: "Accepted; activation
    helper superseded by 0023" in both places. Similarly,
    `docs/decisions/0007-known-gaps.md:41` names only the settings window for the
    fullscreen menu gap, which now applies to either window.
  - O2 (spec, workstream 3): `docs/specs/debug-window.md:117` still describes "a flag
    for a commit boundary". The code uses `Mark.commit: Int?`, which is logged as drift
    and allowed by the spec's naming latitude. A one-phrase update would keep the spec
    exact.
  - O3 (`Sources/EchoTypeApp/Views/LastDictationWindow.swift:103`): `updateNSView`
    replaces the attributed string on every update, which drops a selection in the
    paragraph when a new trace arrives. This is harmless and probably expected, since
    the content changed.
  - O4 (`LastDictationWindow.swift:63`): a row's word count splits on whitespace, but
    the summary counts `Prose` words, so a stutter like `I-I'm` counts as 1 word in a
    row and 2 in the summary. This is cosmetic.
  - O5: `Result.failed(String)` encodes as `{"failed":{"_0":"…"}}` in Copy as JSON. It
    is readable enough, and G1 accepted the JSON, but a labelled associated value would
    read better. This is a preference.
  - O6: the spec, decision and implementation directory keep "debug-window" in their
    file names. Renaming would churn links for no behavioural gain, so I would keep them.
- Questions: none that block. Q1 (informational): G1's evidence is Aidan's aggregate
  pass with no per-item notes. Does the lead consider this sufficient for the record, as
  plan.md already does?
- Verdict: Pass. No Required findings. The branch implements the revised spec. The
  Core/App seam, session and window lifecycle, and the 0022 safeguard are sound, and no
  debug-gate remnants remain beyond the intentional history. The optional observations
  are documentation polish.

## Lead triage

- Accepted findings and owners: no Required findings. Two documentation-only
  Optional findings were accepted to keep records in sync with the code, given to one
  fresh implementation agent. O1: final lead assigned 0011, its index row and 0007;
  0011's helper and close rule are marked superseded by 0023, and 0007's fullscreen menu
  gap names both windows. O2: workstream 3's spec Marking bullet now describes the
  commit index instead of a boundary flag. Neither changes Mac-visible behavior.
- Rejected findings and reasons: Q1 is answered, not a defect. plan.md records Aidan's
  G1 pass as sufficient and the G2 per-check evidence covers the ungated launch path.
- Deferred optional observations: O3 (a new trace clears the paragraph's selection),
  O4 (request rows count words by whitespace while the summary uses the shared
  tokenizer; fixing it would widen Core's public API), O5 (`failed` encodes its message
  under `_0` in JSON; G1 found the JSON readable) and O6 (file names keep
  "debug-window" to preserve links). Each would change validated behavior or links for
  little gain.
- Drift requiring user decision: none.

## Focused closure

- Reviewed head: `e052dcc` plus the uncommitted doc corrections to 0011, 0007, the
  decisions README and the spec. `git status` shows only docs changed (those four, this
  file and plan.md's Final row); no `Sources/`, `Tests/` or script file changed.
  `swift test` passes 69 tests.
- Finding outcomes:
  - O1: resolved. 0011's status line and its index row now mark the activation helper
    and close rule superseded by 0023, following the README's partial-supersession form
    (as 0001, 0009 and 0013 do). The parenthetical on 0011's `SettingsButton` bullet
    matches `presentWindow` and `windowClosed` in `App.swift` (one shared helper; close
    returns to `.accessory` only when no main-capable window is visible or minimised) and
    agrees with 0023's "The window activates like Settings" bullet. 0007's fullscreen
    menu gap now names both windows, which matches the shared `.regular` policy.
  - O2: resolved. The spec's Marking bullet now describes "the index of the commit that
    starts at it, if any", which matches `Mark.commit: Int?` and its doc comment in
    `DictationTrace.swift`.
- Final simplification assessment: the corrections are minimal and add no new concepts.
  0011 keeps its original text with a short superseded note rather than a rewrite, which
  preserves history as the README asks. Nothing further to remove.
- Remaining blockers: none.
- Verdict: Pass.

## Completion record

- Final verification: `swift build` clean and `swift test` passes 69 tests at
  `e052dcc` and again with the documentation corrections. The corrections touch no code.
- External validation pending: none required. G1 and G2 passed with Aidan's recorded
  evidence, and the final review changed no Mac-visible behavior, so neither needs a
  re-check. Not re-observed on the ungated build, in code workstream 3 did not change:
  `--hud-demo` with no item, both windows open at once, Escape cancellation, both themes,
  and no restore after quitting with the window open.
- Specification drift: the spec's Marking bullet now describes `Mark.commit`, the
  index already logged in plan.md. 0011 is marked partly superseded by 0023 and 0007's
  fullscreen menu gap names both windows. No new behavior drift.
