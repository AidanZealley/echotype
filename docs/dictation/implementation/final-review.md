# Dictation whole-feature review

Status: not started. Begin only after every workstream is accepted and gate G1 has
passed.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved specification. Inspect the accepted handoffs, but review the combined diff and
surrounding code independently.

Most of this milestone has no automated test and never will. The review is the main
defence, so read the AppKit and AVFoundation paths as production code that nothing
guards, and weigh a finding by whether it could produce a mystery failure rather than by
whether a test would have caught it.

Audit:

- Whether each workstream's acceptance criteria are met, and whether G1's evidence
  actually supports criterion 1 of workstream 3 rather than merely being present.
- The session lifecycle end to end: who owns the socket, who owns the audio device, what
  happens to each when a session cancels, fails or hits the hard cap, and whether
  anything leaks across two consecutive dictations.
- The event tap lifecycle, including the disabled-by-timeout path and whether Escape is
  consumed only while a session is open.
- The pasteboard sequence against the specification's `changeCount` rule, and the restore
  under two overlapping insertions.
- Dependency direction: whether any decision that could live in `EchoTypeCore` was left
  untestable in `EchoTypeApp`, and conversely whether anything in Core exists only to be
  mocked.
- Speculative machinery. This milestone sits next to three deferred ones, so the main
  risk is the overlay, the settings window or a device picker arriving early in
  fragments.
- Whether the documents agree with the code, and whether recorded drift is real.

Run `swift build`, `swift test`, and `swift-format lint --recursive Sources Tests
Package.swift` if it is installed. Do not run `./scripts/run.sh`; the branch is known to
work from G1 and relaunching it costs Aidan's TCC state for nothing.

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
- What G1 showed about first-word clipping and real dictation: `TBD`
