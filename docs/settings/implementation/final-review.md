# Settings whole-feature review

Status: not started. Begin only after every workstream is accepted.

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

- Reviewer: `TBD`
- Branch, base, and reviewed head: `TBD`
- Verification run: `TBD`
- Acceptance-criteria audit: `TBD`
- Required findings by owner: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`
- Verdict: `TBD`

## Lead triage

- Accepted findings and owners: `TBD`
- Rejected findings and reasons: `TBD`
- Deferred optional observations: `TBD`
- Drift requiring user decision: `TBD`

## Focused closure

- Reviewed head: `TBD`
- Finding outcomes: `TBD`
- Final simplification assessment: `TBD`
- Remaining blockers: `TBD`
- Verdict: `TBD`

## Completion record

- Final verification: `TBD`
- External validation pending: `TBD`
- Specification drift: `TBD`
