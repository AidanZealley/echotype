# EchoTypeCore whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and
the approved specification. Inspect the accepted handoffs, but review the combined diff
and surrounding code independently.

Audit:

- Whether the specification's "What is tested where" list is actually covered, and
  whether anything claimed as tested is only asserted trivially.
- The seams between the converter, the client, the assembler and the session machine.
  Look for duplicated state, particularly transcript text held in two places.
- Dependency direction. Nothing in `EchoTypeCore` may reach toward a macOS layer.
- The Foundation-only rule, across every file.
- Test quality over test count. Tests coupled to internal field names, permutation
  tests that assert nothing a user would notice, and ceremonial smoke tests are
  findings, not coverage.
- Speculative machinery. Extension points, protocols with one conformer that no
  acceptance criterion needed, and configuration nobody sets.
- Whether workstream 3's findings were actually applied to workstream 4, or merely
  recorded.
- Whether the documents agree with the code, and whether recorded drift is real.

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
- What live protocol validation changed, if anything: `TBD`
