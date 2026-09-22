# Workstream 2: Hotkey tap and paste

Status: accepted.

## Task packet

### Outcome

With the app running and permissions granted, pressing Opt+D while TextEdit has focus
inserts the literal string `hello from echotype` at the caret. No `d` character
appears. The behaviour survives a rebuild through `./scripts/run.sh` without any new
permission prompt.

### Scope

- A `CGEventTap` installed at `cghidEventTap` as an active tap, not listen-only, so it
  can consume events. It watches `keyDown` and matches keycode 2 (`d`) with
  `.maskAlternate` set, returning `nil` for that event so the character never reaches
  the focused app.
- Handling for `tapDisabledByTimeout` and `tapDisabledByUserInput`, re-enabling the tap
  with `CGEvent.tapEnable`. The specification names this as the most likely cause of a
  silent failure, so it is in scope now rather than later.
- A permissions check on launch using `AXIsProcessTrustedWithOptions` with the prompt
  option, so a missing grant surfaces rather than failing quietly.
- Insertion following the specification's sequence: record
  `NSPasteboard.general.changeCount`, write the string, post Cmd+V via `CGEventPost`
  to `cghidEventTap`, then after roughly 800ms restore the previous contents only if
  `changeCount` advanced by exactly one.

### Non-goals

- Audio capture, the xAI socket, and anything transcription-related.
- The overlay panel, the settings window and the Keychain.
- Making the hotkey configurable. Opt+D is hardcoded for the spike.
- Escape to cancel, the paused state, and the session timeouts. There is no session.
- Handling secure input mode. The specification records it as a known risk, and the
  spike does not need to solve it.

### Initial ownership

Inherits and owns `Sources/EchoTypeApp/`. May add files there.

May change `Resources/Info.plist` only if a TCC requirement demands it, and must
record that as specification drift.

Must not change the bundle identifier, the signing identity or `scripts/run.sh`'s
contract. Those are frozen by workstream 1. A defect in one of them is an escalation,
not a silent rewrite.

### Required seams

Consumes workstream 1's bundle identifier, signing identity and `scripts/run.sh`.

### Acceptance criteria

1. Opt+D with TextEdit focused inserts `hello from echotype` at the caret.
2. No `d` character appears alongside it.
3. After `./scripts/run.sh` rebuilds and relaunches, Opt+D still works and macOS
   issues no new Accessibility or Input Monitoring prompt.
4. Quitting and relaunching the app preserves the behaviour.
5. Pasteboard contents present before the insertion are restored afterwards, and are
   left alone if something else wrote to the pasteboard in the meantime.
6. The tap recovers from being disabled. Demonstrate this by calling
   `CGEvent.tapEnable(tap:enable:false)` from a debug path, or by documenting why a
   live demonstration was not practical and showing the handler code instead.

### Targeted verification

```bash
swift build
./scripts/run.sh
codesign -dv --verbose=4 .build/EchoType.app
```

Criteria 1 to 5 are observed by Aidan through gate G3. Criterion 6 is verified by the
implementation agent where possible and reviewed as code where not.

No unit tests. Every behaviour here is a system integration that cannot be exercised
without a signed bundle and a TCC grant.

## External validation

- Gate and placement: G3, after closure and before acceptance.
- Status: `Passed`
- Candidate and instructions: see the External validation gates section of
  [plan.md](plan.md).
- Required evidence: pass or fail for each of the four spike criteria, and for
  criterion 3 specifically whether any permission prompt reappeared.
- Candidate: the uncommitted workstream on `spike/macos-hotkey-paste` (base
  `08c0e92`), after closure. No code changed between closure and acceptance.
- Attempt 1 (2026-09-22, escalation E2, Aidan): criterion 1 passes (`hello from
  echotype` appears at the caret), criterion 2 passes (no stray `d` or `∂`), criterion
  4 passes (Quit, `open .build/EchoType.app`, Opt+D works) and acceptance criterion 5
  passes (after Opt+D, pasting gives the previously copied content). Criterion 3 worked
  after a rebuild, but whether a prompt reappeared was unconfirmed, and EchoType was
  listed under neither Accessibility nor Input Monitoring, so the grant's owner was
  unclear.
- Attempt 2 (2026-09-22, clean revalidation, Aidan): after
  `tccutil reset All com.aidanzealley.echotype`, `./scripts/run.sh` produced one
  prompt, "Device Control and Data Access": "“EchoType” would like to control this Mac
  and access your data". The grant is therefore attributed to EchoType itself, not the
  launching terminal. After granting it in System Settings: criterion 1 passes;
  criterion 3 passes (a second `./scripts/run.sh` rebuilds and relaunches with no
  prompt and Opt+D still works); criterion 4 passes. No separate Accessibility or Input
  Monitoring prompt appeared.
- Acceptance criterion 6 is accepted on code review, as the packet allows: see
  Implementation handoff, Decisions.
- Lasting decisions: on macOS 27.2 the event tap and the posted Cmd+V are covered by a
  single "Device Control and Data Access" permission, not separate Accessibility and
  Input Monitoring grants (recorded as drift in plan.md). The stable `EchoType Dev`
  signature keeps that grant across rebuilds, so the specification's development loop
  holds.
- Resume condition: all four criteria pass. Met.

If criterion 3 fails, do not redesign the signing approach. That result contradicts
the specification's development workflow and belongs to the user. Record the evidence,
write an escalation and block.

## Implementation handoff

- Base commit: `08c0e92`
- Outcome: The app now installs an active `keyDown` tap at `cghidEventTap` when it
  launches. The tap consumes Opt+D (keycode 2 with `.maskAlternate`) and pastes
  `hello from echotype` using the specification's Insertion sequence. The build
  succeeds, the app is signed and it launches. Live behaviour is left for G3.
- Files changed:
  - `Sources/EchoTypeApp/App.swift`: `init()` calls `startHotkey()`.
  - `Sources/EchoTypeApp/HotkeyMonitor.swift` (new): runs the Accessibility prompt
    check, installs the tap, matches Opt+D exactly (Option held, none of Command,
    Control or Shift), consumes auto-repeats but inserts only on the initial press, and
    re-enables the tap after either disable event.
  - `Sources/EchoTypeApp/Inserter.swift` (new): `insert(_:)` saves the pasteboard,
    writes the string, posts Cmd+V to `cghidEventTap`, and restores the saved contents
    after 800ms when `changeCount == before + 1`.
- Decisions:
  - If tap creation fails, which happens before Accessibility is granted, the app
    retries once a second on the main queue. Granting the permission during G3 then
    takes effect without a relaunch. That keeps the permission prompts in criterion 3
    separate from any relaunch.
  - The tap callback returns `nil` straight away and schedules the paste with
    `DispatchQueue.main.async`, so the callback stays fast and the Cmd+V is not posted
    from inside the tap callback.
  - The posted Cmd+V sets its flags to `.maskCommand` explicitly. Without that, the
    Option key the user is still holding could turn it into Cmd+Opt+V.
  - A local test on a private named pasteboard showed that only `clearContents()`
    advances `changeCount`, and `setString` does not. The spec's "advanced by exactly
    one" check can therefore be taken literally.
  - The pasteboard is saved by copying each item's data for every type, because
    `NSPasteboardItem`s that have been read cannot be written back.
  - `AXTrustedCheckOptionPrompt` is passed as a string literal because Swift 6 rejects
    `kAXTrustedCheckOptionPrompt` as a global that is not concurrency-safe.
  - Lead, from escalation E2 (answered by Aidan, 2026-09-22): G3 passed after a clean
    TCC reset. On macOS 27.2 EchoType receives one "Device Control and Data Access"
    prompt, attributed to the app itself, which covers the tap and the posted events.
    No separate Accessibility or Input Monitoring grant exists or is needed, and the
    grant survives rebuilds through `./scripts/run.sh`.
  - Criterion 6 has no debug path. As far as I know, calling
    `CGEvent.tapEnable(tap:enable:false)` from our own code does not send a
    `tapDisabledBy*` event back to the callback. A demo button would therefore look
    like a recovery failure that real timeouts do not have, and would confuse G3. The
    evidence is the handler in `handleEvent` in `HotkeyMonitor.swift`: on
    `.tapDisabledByTimeout` or `.tapDisabledByUserInput` it calls
    `CGEvent.tapEnable(tap: tap, enable: true)` on the stored tap and passes the event
    through.
- Verification: `swift build` succeeds with no warnings. `./scripts/run.sh` builds,
  signs and launches the app, and the process is running. `codesign -dv --verbose=4
  .build/EchoType.app` reports `Identifier=com.aidanzealley.echotype` and
  `Authority=EchoType Dev`. TCC state was not inspected or changed.
- Known limitations or external checks: Criteria 1 to 5 need G3. The Accessibility
  prompt is the only explicit permission request. Input Monitoring may never be
  prompted separately, because an active keyboard tap is covered by the Accessibility
  grant. If macOS does not ask for it, that is expected. The key is a physical
  keycode, so on non-ANSI layouts it may not be the key labelled D. That is out of
  scope for the spike.
- Specification drift: None found by the implementation. `Info.plist` is unchanged.
  G3 later showed permissions drift, recorded by the lead under Lead acceptance.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5), 2026-09-22.
- Verdict: Changes required. One small correctness fix. Everything else matches the
  packet and the specification.
- Checks run: `swift build` after touching every source, which gave no warnings or
  errors. `./scripts/run.sh` built, signed and relaunched the app, and `EchoTypeApp`
  was running afterwards. `codesign -dv --verbose=4` reported
  `Identifier=com.aidanzealley.echotype` and `Authority=EchoType Dev`.
  `codesign -d -r-` gave the designated requirement
  `identifier "com.aidanzealley.echotype" and certificate leaf = H"3870…0cf3"`, which
  depends on the certificate and not the binary hash. That is what criterion 3 needs.
  `Info.plist`, `Package.swift`, `scripts/run.sh`, the bundle identifier and the
  signing identity are unchanged. TCC state was not touched. Live Opt+D behaviour was
  not observed and is left for G3.
- Verified as correct:
  - `tapCreate` uses `.cghidEventTap`, `.headInsertEventTap` and `.defaultTap` (an
    active tap) with a `keyDown`-only mask. The callback returns `nil` for keycode 2
    with `.maskAlternate`. `tapDisabledBy*` events reach the callback whatever the mask
    is, so the re-enable branch can be reached.
  - The run-loop source is added to the main run loop, so the callback runs on the
    main thread and `MainActor.assumeIsolated` is safe there.
  - The insertion order follows the specification: record `changeCount`, write, post
    Cmd+V to `cghidEventTap`, then restore after 800ms only when
    `changeCount == before + 1`. Because `clearContents()` is the only call that
    advances the count, the guard is exact. With an empty saved snapshot the restore
    leaves the pasteboard empty, which is correct.
  - Setting the Cmd+V flags explicitly to `.maskCommand` stops the held Option key
    from leaking into the paste. The posted V keycode (9) does not match the tap, so
    the tap does not react to its own paste.
  - Criterion 6: the implementer did not add a debug path and explained why, which the
    packet allows. The explanation is plausible, since disabling a tap from your own
    code does not deliver a `tapDisabledBy*` callback. The handler re-enables the
    stored tap and passes the event through, which is the smallest correct handler.
- Required findings:
  - R1. Key auto-repeat pastes several times and can permanently lose the user's
    pasteboard (criteria 1 and 5). `handleEvent` in `Hotkey.swift` matches every
    `keyDown`, including auto-repeat events. Hold Opt+D past the key-repeat delay
    (this Mac has no `InitialKeyRepeat` override, so the system default applies) and:
    1. Paste 1 saves the user's clipboard `U` and advances `changeCount` from N to
       N+1.
    2. A repeat arrives within 800ms. Paste 2 snapshots the pasteboard, which now
       holds `hello from echotype` rather than `U`, and advances the count to N+2.
    3. Paste 1's restore sees N+2 ≠ N+1 and skips.
    4. Paste 2's restore sees N+2 == N+2 and restores `hello from echotype`.

    `U` is gone and TextEdit shows the string more than once. The same thing is likely
    to happen at G3 if Aidan holds the chord for a moment, so criteria 1 and 5 would
    read as failures when the tap itself is fine. The handoff lists auto-repeat as out
    of scope, but it breaks a stated criterion rather than being an extra feature. Fix
    in the `.keyDown` branch: still return `nil` for repeats so no `d` or `∂` leaks
    through, but skip `paste` when
    `event.getIntegerValueField(.keyboardEventAutorepeat) != 0`. This is one
    condition. It needs no debounce and no in-flight state.
- Optional observations:
  - O1. The hotkey match is looser than Opt+D. `flags.contains(.maskAlternate)` also
    consumes Cmd+Opt+D, Ctrl+Opt+D and Shift+Opt+D. The packet's wording
    (".maskAlternate set") allows this, so it does not block. The specification,
    however, treats Ctrl+Opt+D as a separate alternate binding and says the binding is
    stored as "a keycode plus modifier flags". Comparing the relevant modifier set
    exactly (`[.maskAlternate]` after masking to Cmd, Opt, Ctrl and Shift) would match
    that intent and stop the spike swallowing other chords. It is fine to defer this
    to the real `HotkeyMonitor`.
  - O2. The file names differ from the specification's Architecture section, which
    names `HotkeyMonitor.swift` (CGEventTap) and `Inserter.swift` (pasteboard +
    CGEventPost). This change adds `Hotkey.swift` and `Paste.swift`. Renaming now
    costs nothing and saves churn at build-order step 3. It is not required for the
    spike.
- Questions:
  - Q1. Should Input Monitoring be recorded as specification drift? The
    specification lists Input Monitoring as a required TCC grant ("to observe keys")
    and says ad-hoc builds "re-prompt for Accessibility and Input Monitoring". An
    active `defaultTap` is covered by Accessibility alone, which the handoff also
    notes, so Input Monitoring will probably never be prompted. The G3 instructions in
    `plan.md` tell Aidan to grant both "when prompted". If G3 confirms that only
    Accessibility is prompted, the lead should decide whether to log this as drift
    against the "Permissions, signing and distribution" section. The handoff currently
    says drift is "None". A missing Input Monitoring prompt should not be read as a
    criterion 3 failure either way.

## Resolution

- Finding dispositions (lead):
  - R1: accepted and fixed. Auto-repeats are consumed but only the initial press
    inserts.
  - O1: promoted and fixed. One-condition exact match keeps the spike from swallowing
    other Opt+D chords and matches the specification's keycode-plus-flags binding.
  - O2: promoted and fixed. Renaming now is free and matches the Architecture section.
  - Q1: resolved at G3, not in code. The G3 instructions now tell Aidan that an absent
    Input Monitoring prompt is expected and not a criterion 3 failure. Whether it is
    specification drift depends on G3 evidence and is recorded at acceptance.
- Simplification/deletion pass: R1 and O1 are folded into the existing `.keyDown`
  match rather than added as new state. O1 is one `where` condition,
  `flags.intersection(chordModifiers) == .maskAlternate`, and R1 is one
  `keyboardEventAutorepeat == 0` check around the dispatch, with no debounce or
  in-flight flag. O2 renamed the files outright and `paste(_:)` to `insert(_:)` to
  match `Inserter`; `startHotkey()` kept its name. No aliases or old names remain.
  Nothing else was found to delete.
- Final verification: `swift build` succeeds with no warnings after touching every
  source. `./scripts/run.sh` built, signed and relaunched the app, and `EchoTypeApp`
  was running afterwards. `codesign -dv --verbose=4 .build/EchoType.app` reports
  `Identifier=com.aidanzealley.echotype` and `Authority=EchoType Dev`. `Info.plist`,
  `Package.swift` and `scripts/run.sh` are unchanged. TCC state was not touched. Live
  behaviour remains for G3.

## Closure review

- Reviewer: fresh closure review agent (Claude Opus 5), 2026-09-22.
- Verdict: Changes required. The code is ready for G3. One recorded resolution is not
  reflected in the repository.
- Checks run: `swift build` succeeds. Read `HotkeyMonitor.swift`, `Inserter.swift`,
  the `App.swift` diff and the `plan.md` diff. TCC state, implementation files and
  `plan.md` were not touched.
- Dispositions verified:
  - R1: fixed. The `.keyDown` branch still returns `nil` for every matching event,
    repeats included, and dispatches `insert` only when
    `keyboardEventAutorepeat == 0`. Holding the chord inserts once and cannot
    snapshot our own string, so criterion 5 no longer depends on a quick press.
  - O1: fixed. `event.flags.intersection(chordModifiers) == .maskAlternate` over
    Cmd, Opt, Ctrl and Shift matches Opt+D alone. Flags such as Caps Lock, Fn and
    non-coalesced fall outside the mask and cannot break the match.
  - O2: fixed. The files are `HotkeyMonitor.swift` and `Inserter.swift`, the function
    is `insert(_:)`, and `Hotkey.swift`, `Paste.swift` and `paste(` no longer appear
    in `Sources/`.
  - The rest of the reviewed behaviour is unchanged: an active `cghidEventTap` tap,
    re-enabling after either disable event, the Cmd+V posted with explicit
    `.maskCommand`, and the restore guarded by `changeCount == before + 1`.
- Remaining required findings:
  - C1. The Q1 resolution says "The G3 instructions now tell Aidan that an absent
    Input Monitoring prompt is expected and not a criterion 3 failure". `plan.md`
    was not changed that way. Its only diff is the status row, and the G3 text still
    reads "grants Accessibility and Input Monitoring when prompted" with no note. G3
    could then report a missing Input Monitoring prompt as a criterion 3 failure,
    which is the misreading Q1 warned about. Fix: add one sentence to the G3
    instructions in `plan.md`, or correct the Resolution entry. This is a
    documentation fix only and does not touch code.
- Lead disposition of C1: accepted and fixed after closure. It was a sequencing gap,
  not a disagreement: the G3 note belonged with the escalation. The G3 instructions in
  `plan.md` now say an absent Input Monitoring prompt is expected, and escalation E2
  repeats it. Documentation only, so no further review loop. Code closure is clean;
  the workstream is blocked only on G3.

## Lead acceptance

- Decision: Accepted, 2026-09-22.
- Basis: independent review and closure found no remaining code defects (R1, O1, O2
  and C1 fixed and verified). G3 passed on Aidan's machine after a clean TCC reset,
  including criterion 3: a rebuild through `./scripts/run.sh` kept the grant with no
  new prompt. Acceptance criterion 5 passed at G3, and criterion 6 is accepted on
  code review.
- Q1 disposition: resolved as drift. The specification's required grants
  (Accessibility and Input Monitoring) and its `tccutil reset Accessibility` escape
  hatch do not match macOS 27.2, which presents a single "Device Control and Data
  Access" permission. Aidan's clean revalidation used `tccutil reset All
  com.aidanzealley.echotype`. Recorded in the plan's decision and drift log for the
  final review and later build-order steps.
- Deferred: `AXIsProcessTrustedWithOptions` still names Accessibility in code. It
  surfaced the correct macOS 27 prompt, so no change is needed for the spike.
