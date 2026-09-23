# EchoType macOS spike whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and
the approved specification. Inspect the accepted handoffs, but review the combined
diff and surrounding code independently.

Keep this proportionate. The spike is around a hundred lines and its real verdict came
from the four criteria Aidan ran on his machine. The review is not an excuse to grow it.

Audit:

- Whether the four spike success criteria are recorded as passed with evidence, and
  what the answer to criterion 3 was.
- Whether the frozen contracts held: bundle identifier, signing identity,
  `scripts/run.sh` as the only build and launch path.
- The event tap lifecycle, including the `tapDisabledByTimeout` path.
- The pasteboard restore logic against the specification's `changeCount` rule.
- Whether anything was built that no acceptance criterion needed. Speculative
  machinery is the main risk in a spike, since it is tempting to start the real app.
- Whether the documents agree with the code, and whether recorded drift is real.

## Initial whole-feature review

- Reviewer: fresh general-purpose subagent
- Branch, base, and reviewed head: `spike/macos-hotkey-paste`, base `2c57765`
  (plan.md starting commit), head `d0a758c`. Working tree was clean before this
  section was written.
- Verification run: `swift build` completes with no errors or warnings (Xcode
  toolchain). `git diff --stat 08c0e92 HEAD` over `Package.swift`, `Resources/`,
  `scripts/` and `.gitignore` is empty, so workstream 2 did not touch workstream 1's
  frozen files. Read the whole combined diff (`git diff 2c57765 HEAD`), both workstream
  records and plan.md. Not run, as the brief says: `scripts/run.sh`, relaunching the
  app, or anything touching TCC or Keychain.
- Acceptance-criteria audit:
  - Spike criteria (plan.md "Whole-feature acceptance"). All four are recorded as
    passed on Aidan's machine, in 02-hotkey-and-paste.md External validation. Criteria
    1, 3 and 4 were re-observed in attempt 2, the clean revalidation after
    `tccutil reset All com.aidanzealley.echotype`. Criterion 2 (no stray `d` or `∂`)
    and workstream criterion 5 (pasteboard restored) were observed in attempt 1. No
    code changed between the two attempts, so that evidence still applies.
  - Criterion 3 answer: passed. After the reset, macOS showed one prompt ("Device
    Control and Data Access"), attributed to EchoType itself. A second
    `./scripts/run.sh` rebuilt and relaunched with no prompt, and Opt+D still worked.
    The stable-identity development loop in the specification holds. WS2 review's
    `codesign -d -r-` evidence supports this: the designated requirement is
    `identifier "com.aidanzealley.echotype" and certificate leaf = H"…"`, not a
    cdhash.
  - Frozen contracts held. `Resources/Info.plist:8` keeps
    `com.aidanzealley.echotype`. `scripts/run.sh:18` signs with `"EchoType Dev"`.
    `scripts/run.sh` is the only build and launch path, and no second path, Xcode
    project or install script was added. `Package.swift:10` declares one executable
    target on `.macOS(.v26)`.
  - Event tap lifecycle. `HotkeyMonitor.swift:28-41` creates an active
    (`.defaultTap`) keyDown tap at `.cghidEventTap` and adds it to the main run loop.
    That makes `MainActor.assumeIsolated` at `:54` sound. `:52-57` re-enables the
    stored tap on `tapDisabledByTimeout` and `tapDisabledByUserInput` and passes the
    event through. Disable events arrive whatever the mask is, so this branch can be
    reached. Acceptance on code review, with no debug path, is allowed by the packet,
    and the reason is recorded. `:23-26` retries tap creation every second until the
    grant exists. That is cheap and has a stated purpose: the grant takes effect
    without a relaunch, which keeps the criterion 3 observation clean.
  - Pasteboard restore. `Inserter.swift:9-25` records `changeCount`, writes, posts
    Cmd+V to `cghidEventTap`, and after 0.8 s restores only if
    `changeCount == before + 1`. This matches the specification's Insertion steps 1
    to 4 (echotype-v1.md:318-322). The `+ 1` is exact because `clearContents()` is
    the only increment (`:10`), which the handoff established with a local test.
    Saving the snapshot before recording `changeCount` (`:7`) is harmless, because
    reading does not advance the count. Holding the chord cannot corrupt the restore,
    since repeats are consumed without inserting (`HotkeyMonitor.swift:61-67`).
  - Speculative machinery: none found. Each piece traces to a criterion or to a
    finding accepted in review: the autorepeat guard (WS2 R1), the exact modifier
    match (WS2 O1, one `where` clause), the explicit `.maskCommand` on the posted
    event, and the retry loop. The spike adds no configuration, abstraction, debug
    flag, entitlements file or extra target. The production code is 125 lines of Swift
    across three files, plus a 24-line script.
  - Docs against code. The handoffs describe the committed code, with file names
    `HotkeyMonitor.swift` and `Inserter.swift` and function `insert(_:)`. The older
    names `Hotkey.swift` and `paste` survive only in the historical WS2 review text,
    which is correct as history. Both drift items that come from Aidan's own
    observation are real: the Always Trust step and the macOS 27.2 single "Device
    Control and Data Access" grant. The Xcode-toolchain entry is a decision, not
    drift. See Q1 for the one inferred part of the drift log.
- Required findings by owner: none.
- Optional observations:
  - O1 (Sources owner). `HotkeyMonitor.swift:14` and `:17` say "Accessibility not
    granted" and "Surfaces the Accessibility prompt". On macOS 27.2 the recorded
    behaviour is a single "Device Control and Data Access" prompt (plan.md:111). The
    API really is the AX trust check, so the comments are not wrong about the call.
    They are wrong about what the user sees. WS2 Lead acceptance already deferred
    this. A one-word comment tweak is the most it would need. It does not block.
  - O2 (specification, not the spike). echotype-v1.md:324-326 says "Either way the
    transcript stays on the pasteboard". That contradicts step 4 (:321-322), which
    restores the previous contents when nothing else wrote. `Inserter.swift:21-26`
    correctly follows step 4. Worth clarifying in the specification before
    build-order step 3 reuses `Inserter`. This is not spike drift.
- Questions:
  - Q1 (lead, plan.md:111). The drift entry says the specification's escape hatch
    `tccutil reset Accessibility com.aidanzealley.echotype` (echotype-v1.md:433)
    "should become" `tccutil reset All com.aidanzealley.echotype`. The evidence shows
    that `reset All` clears the grant. Nobody tested whether `reset Accessibility`
    also clears the macOS 27.2 "Device Control and Data Access" grant. The
    recommendation is sound, since `All` is a superset. Should the entry say
    "verified with `reset All`; `reset Accessibility` untested" so that a later
    specification edit does not treat it as proven?
- Verdict: pass. No Required findings. All four spike criteria passed on Aidan's
  machine, and criterion 3 passed. The frozen contracts held. The tap lifecycle and
  the `changeCount` restore match the packet and the specification. The spike carries
  no speculative machinery. O1, O2 and Q1 are small documentation points for lead
  triage.

## Lead triage

- Recovery: two earlier final-review leads were interrupted, the first after the
  initial review was written and the second after this triage was written, both
  uncommitted on `d0a758c`. The accepting lead re-checked the initial review's factual
  claims against the code and the specification (file and line references, the
  `changeCount` rule, the tap lifecycle, the frozen contracts), confirmed the triage
  below matched the evidence, reused both, and reran focused closure, the one phase it
  could not prove complete. The
  uncommitted `.vscode/` line in `.gitignore` was written an hour after the review,
  one minute after `.vscode/launch.json` appeared. It is Aidan's editor setup, not
  review work, so it stays out of this commit and is left untouched.
- Accepted findings and owners: Q1, owned by the lead. The plan's macOS 27.2 drift
  entry now says `reset All` is verified and `reset Accessibility` is untested. No
  source file changes, so no implementation agent was needed.
- Rejected findings and reasons: none.
- Deferred optional observations: O1. `AXIsProcessTrustedWithOptions` is still the
  Accessibility trust check, so the comments describe the call correctly. What the
  user sees on macOS 27.2 is already recorded in the drift log. Revisit when build-order
  step 3 rewrites the hotkey code.
- Drift requiring user decision: O2 is recorded in the plan's drift log as pending
  Aidan. The specification's Insertion section contradicts itself on whether the
  transcript stays on the pasteboard. The spike follows the numbered step 4. This does
  not block the spike, but it should be settled before `Inserter` is reused.

## Focused closure

- Reviewed head: `spike/macos-hotkey-paste` at `d0a758c`, base `2c57765`, plus the
  uncommitted working tree. Three files are modified: plan.md (the Q1 fix and the O2
  drift row), final-review.md (the review text itself) and `.gitignore` (Aidan's
  `.vscode/` line, left untouched as the lead decided). No source file, `Package.swift`,
  `Resources/` or `scripts/` file is modified, which matches the triage claim that Q1
  needed no implementation agent.
- Finding outcomes:
  - Q1, accepted, fixed. plan.md:111 now ends "Verified with `reset All` only; whether
    `reset Accessibility` clears the 27.2 grant is untested". That says exactly what the
    evidence supports and marks the untested half, which is what the question asked for.
    The recommendation to switch the specification's escape hatch to `reset All` still
    stands, and now reads as a recommendation rather than a tested fact. The row keeps
    its five columns and its cells contain no stray pipes, so the table still renders.
    No release-blocking defect in the fix.
  - O2, recorded, not fixed here. A new drift row sits below the 27.2 row, owned by
    "Pending Aidan". The contradiction it describes is real: the specification's step 4
    (specs/echotype-v1.md:321-322) restores the previous contents, and the paragraph at
    :324-326 says the transcript stays on the pasteboard either way. `Inserter.swift:21-26`
    follows step 4. The row is a faithful record of a specification question, not a spike
    defect, and does not block.
  - O1, deferred, unchanged. `HotkeyMonitor.swift:14` and `:17` still say "Accessibility".
    The call really is `AXIsProcessTrustedWithOptions` (`:19`), so the comments describe
    the API correctly and only the user-visible prompt name has moved on. The 27.2
    behaviour is recorded in the drift log. Deferring is proportionate.
- Final simplification assessment: nothing to remove. The spike is 125 lines of Swift
  across `App.swift`, `HotkeyMonitor.swift` and `Inserter.swift`, plus the 24-line
  `scripts/run.sh`, which matches the initial review's count. Every construct earns its
  place: the retry loop so a fresh grant takes effect without a relaunch, the autorepeat
  guard so a held chord cannot snapshot the app's own string as the previous pasteboard,
  the exact modifier intersection so Cmd+Opt+D and friends pass through, and the explicit
  `.maskCommand` so the held Option key does not turn the synthetic paste into Cmd+Opt+V.
  There is no configuration, no abstraction layer, no debug flag and no second build path.
  The Q1 fix adds words to one table cell and no code.
- Remaining blockers: none. `swift build` was re-run on this working tree with Xcode's
  toolchain (`xcode-select -p` is `/Applications/Xcode.app/Contents/Developer`), from a
  removed `.build` directory, and completed with no errors and no warnings, which confirms
  the initial review's verification claim on a clean build rather than an incremental one.
  Not run here, as the brief says: `scripts/run.sh`, relaunching the app, or anything
  touching TCC. O2 is a specification question for Aidan that must be settled before
  build-order step 3 reuses `Inserter`, and it does not hold up the spike.
- Verdict: pass. The one accepted finding is fixed in the working tree and its fix is
  sound. The deferred and pending items are correctly recorded and carry no release risk.
  No release-blocking defect found. Review closed, with no further rounds.

## Completion record

- Final verification: clean `swift build` under Xcode's toolchain, no errors and no
  warnings, run from a removed `.build` directory during closure. The combined diff
  `2c57765..d0a758c` was read in full, and `git diff --stat 08c0e92 HEAD` over
  `Package.swift`, `Resources/`, `scripts/` and `.gitignore` is empty, so workstream 2
  never touched workstream 1's frozen files. The live behaviour was not re-run here; it
  was validated by Aidan at gates G2 and G3 and no code has changed since.
- External validation pending: none. G1, G2 and G3 all passed on Aidan's machine, and
  all four spike success criteria are recorded as passed with evidence in
  [02-hotkey-and-paste.md](02-hotkey-and-paste.md) External validation.
- Specification drift: three entries stand in the plan's decision and drift log. The
  `EchoType Dev` certificate needs Always Trust for Code Signing, which the
  specification's creation steps omit. On macOS 27.2 the event tap and the posted Cmd+V
  are covered by one "Device Control and Data Access" grant rather than separate
  Accessibility and Input Monitoring grants, so the escape hatch should become
  `tccutil reset All com.aidanzealley.echotype`, verified with `reset All` only. Final
  review added a third: the specification's Insertion section contradicts itself about
  whether the transcript stays on the pasteboard, and the spike follows the numbered
  step 4. That one is pending Aidan and should be settled before build-order step 3
  reuses `Inserter`.
- Criterion 3 outcome and what it means for the specification's development
  workflow: passed. After `tccutil reset All com.aidanzealley.echotype`, one permission
  prompt appeared, attributed to EchoType itself rather than the launching terminal, and
  a second `./scripts/run.sh` rebuilt, resigned and relaunched with no new prompt and a
  working Opt+D. The designated requirement is the bundle identifier and the certificate
  leaf, not a cdhash, which is why the grant survives rebuilds. The specification's
  development loop holds as written: a stable self-signed identity means each permission
  is granted once, and no Developer ID is needed for v1. The assumption the spike exists
  to test is confirmed.
