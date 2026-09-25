# Settings whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved specification, read with the plan's decision and drift log. Inspect the
accepted handoffs, but independently review the combined diff and the surrounding code.

Audit:

- Completeness against "Menu bar and settings" in the specification and the plan's
  decisions: every row, the Settings item, persistence, the Keychain write path and
  launch at login.
- The encoding: that the tests would fail if a stored hotkey decoded differently, and
  that nothing outside the store touches `UserDefaults`.
- The session boundary: settings read once per session, the hotkey read live, and no
  path by which the Test button or a settings change disturbs a running dictation.
- Blocking work on the main actor, where the event tap runs: Keychain, Core Audio and
  `SMAppService` calls.
- Dependency direction: decisions in `EchoTypeCore`, effects in `EchoTypeApp`, and no
  serialisation in the App target that belongs in Core.
- Duplicated state, such as a setting held both in the store and in a view or the
  controller beyond one session's copy, and a second start sequence for the Test run.
- Speculative machinery, tests of fakes, and leftovers: the placeholder keyterms, the
  "no write path" comments, and the controller's `Settings()` constant.
- Documentation agreement: code comments, the specification's error line, and
  [0007](../../decisions/0007-known-gaps.md).

Run `swift build`, `timeout 120 swift test --disable-xctest` and
`xcrun swift-format lint --recursive Sources Tests Package.swift`.

## Initial whole-feature review

- Reviewer: fresh general-purpose subagent
- Branch, base, and reviewed head: `feat/settings`, `086af98`, `4117635`, clean tree.
- Verification run: `swift build` clean; `timeout 120 swift test --disable-xctest` 45
  passing; `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.
- Acceptance-criteria audit:
  - Completeness: every row of "Menu bar and settings" is present in one grouped `Form`
    (`SettingsView.swift:15-38`), with the Settings item (`App.swift:26`), the double tap
    deferred in 0007 as approved. Settings persist through `SettingsStore`, the key through
    `Keychain.save`/`clear`, and launch at login mirrors `SMAppService.mainApp`.
  - Encoding: per-field fallback decoding in Core (`Settings.swift:120-130`) and a pinned
    byte test. Only `SettingsStore.swift` touches `UserDefaults`; no `@AppStorage`. The
    pinned bytes leave one hotkey remapping undetected (R1).
  - Session boundary: `dictate()` copies `store.settings` once (`DictationController.swift:126`),
    `test()` once (`:149`); the tap matches `store.settings.hotkey` per event
    (`HotkeyMonitor.swift:78`). Test is refused unless `phase` is idle (`:144`), the
    hotkey is consumed and ignored while testing (`:80`), Escape and pill clicks ignore it
    (`:91`, `:109`), the five-second commit is cancelled before `phase` returns to idle
    (`:165`), and a test never calls `finish` or `showStarting`, so it cannot insert or
    show the pill. No path found by which a settings change or Test disturbs a running
    dictation.
  - Main actor: Keychain reads and writes, `InputDevice.all()`, `SMAppService`
    status/register/unregister, and every `AVCaptureSession` start/stop and device lookup
    run detached or on the `Microphone` actor's own queue. Remaining main-actor calls are
    `UserDefaults` writes, `AVCaptureDevice.authorizationStatus` and `AXIsProcessTrusted()`
    (`SettingsView.swift:300-301`), all cheap preflights; not a finding.
  - Dependency direction: encoding, presets and matching in Core; the App target has no
    serialisation. One start sequence (`start(_:)`, `:183`) serves dictation and Test.
  - Duplication and leftovers: the view-held text in `LanguageRow`/`KeytermsRow` is
    justified by their comments. Placeholder keyterms, the "no write path" comments and the
    controller's `Settings()` constant are gone. No tests of fakes; the new tests exercise
    real Core behaviour.
  - Documentation: the spec's error line and 0007 are updated. Stale product lines, left
    for the retirement list rather than this milestone: spec `echotype-v1.md:556`
    ("`EchoTypeCore` deliberately has no serialisation"), 0006 lines 16-17 (key "seeded once
    by hand") and its Consequences (error line now fixed), plus the `AVAudioEngine`,
    0005 and 0009 wording already covered by E6.
- Required findings by owner:
  - R1 (workstream 1). The stored-bytes tests only pin `"modifiers":6` (Ctrl+Opt+D),
    whose bits are symmetric in control and option (`SettingsTests.swift:23`, `:39`).
    Swapping the raw values of `.control` and `.option` (`Settings.swift:49-50`) still
    decodes 6 to Ctrl+Opt+D, so every test passes, while every install that stored the
    default Opt+D (`"modifiers":4`) would decode to Ctrl+D after the upgrade: Opt+D types
    a character and the hotkey silently stops, the failure 0007 and spec step 5 name this
    test for. Fix: also pin the default's stored form,
    `{"hotkey":{"keyCode":2,"modifiers":4}}` decoding to `Settings()` hotkey `.optionD`.
- Optional observations:
  - O1 (workstream 2). The converter's resampler tail (roughly 20 to 30ms) is never
    flushed at `stop()` (`AudioCapture.swift:273-279`, `:380-409`). Pre-existing at
    `086af98` and no clipping seen at G1 or G2; out of scope.
  - O2 (workstream 1). `Keychain.save` deletes before it adds (`Keychain.swift:31-40`), so
    a dictation whose key read lands between the two fails with the missing-key error, and
    a failed add leaves no key. The window is microseconds and the UI reports the failure;
    note only.
- Questions:
  - Q1 (workstream 1). Language is free text saved on every keystroke
    (`SettingsView.swift:147-150`), and any 400 is worded "xAI rejected the API key"
    (`DictationController.swift:329-330`). If `api.x.ai` answers an unsupported language
    tag (for example "english") with 400, every dictation and Test blames the key, pointing
    the user at the wrong row. Whether it does is unverified; the lead should decide
    whether this needs checking or a note in 0007.
- Verdict: changes requested for R1 only, a test-only addition in workstream 1's file.
  Everything else is acceptable as is.

## Lead triage

- Accepted findings and owners: R1, owned by workstream 1's
  `Tests/EchoTypeCoreTests/SettingsTests.swift`, sent to a fresh implementation agent.
  `storedValueDecodes` now also pins `{"hotkey":{"keyCode":2,"modifiers":4}}` to
  `.optionD`; a temporary swap of the control and option bits fails the suite. Test-only,
  so the encoding is unchanged and no hand verification is owed.
- Rejected findings and reasons: none.
- Deferred optional observations:
  - O1: pre-existing at `086af98`, outside this milestone, and no clipping was heard at
    either gate.
  - O2: delete-then-add is the documented reason the app owns the item it reads without a
    prompt, proven at G1. The gap is microseconds, a save failure is shown in the window,
    and changing it would touch the Keychain calls and reopen hand verification.
  - Q1: whether `api.x.ai` answers an unsupported language tag with 400 is unverified.
    The language field and the 400 wording both predate this milestone's decisions, so it
    is a follow-up to check against the live endpoint, not a correction here.
  - Stale product lines for the retirement list: spec `echotype-v1.md:556`
    ("`EchoTypeCore` deliberately has no serialisation"), 0006's "seeded once by hand"
    line and its Consequences note about the error line, and the `AVAudioEngine`, 0005
    and 0009 wording already superseded by E6.
- Drift requiring user decision: none.

## Focused closure

- Reviewed head: `4117635` plus the uncommitted correction to
  `Tests/EchoTypeCoreTests/SettingsTests.swift` (the only code change; `git diff Sources`
  empty).
- Finding outcomes:
  - R1: fixed. `storedValueDecodes` now also expects
    `{"hotkey":{"keyCode":2,"modifiers":4}}` to decode to `.optionD`, and its doc comment
    says why both chords are pinned. Swapping the raw values of `.control` and `.option` in
    `Settings.swift` temporarily failed the suite (45 tests, 1 issue); the file was
    restored and `git diff Sources` is empty.
  - O1, O2, Q1 and the stale product lines stay deferred as triaged; not reopened.
- Final simplification assessment: the fix is one assertion in the existing test, with no
  new test, helper or production change. Nothing to remove.
- Remaining blockers: none. `swift build` clean; `timeout 120 swift test --disable-xctest`
  45 passing; `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.
- Verdict: accepted. The correction closes R1 and introduces no release-blocking defect.

## Completion record

- Final verification: `swift build` clean, `timeout 120 swift test --disable-xctest` 45
  passing, `xcrun swift-format lint --recursive Sources Tests Package.swift` clean, at
  `4117635` plus the R1 correction.
- External validation pending: none. G1 and G2 passed; the only correction is test-only
  and touches none of the hand-verified paths.
- Specification drift: none beyond the plan's decision and drift log. The stale product
  lines listed under Lead triage belong to the retirement of this workflow.
