# Overlay whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved specification's Overlay section. Read the accepted handoffs, then review the
combined diff and surrounding code independently.

Audit:

- Completeness against the specification's Overlay section and the plan's whole-feature
  acceptance.
- The seams: snapshots from `SessionMachine`, the pill value, `OverlayPanel`, and the
  level from `AudioCapture`. Look for state held twice, for example a phase the
  controller tracks that a snapshot already carries.
- Lifecycle: the pill, the microphone and the socket each end on every path (insert,
  nothing, failure, Escape during starting and during a session, the silence close, the
  hard cap).
- Focus: nothing anywhere can make the panel key or main.
- The event tap callback does no work beyond deciding whether to consume.
- Dependency direction: `EchoTypeCore` has no UI, no global state and no I/O.
- Leftovers from the variants: labels, switches, dead layouts or demo-only branches in
  live code.
- Tests: meaningful, not coupled to implementation details, no fakes of AppKit.
- Documentation: 0007 matches what is still open, and comments match the code.

Verification: `swift build`, `timeout 120 swift test --disable-xctest`, and
`swift-format lint --recursive Sources Tests Package.swift`.

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
