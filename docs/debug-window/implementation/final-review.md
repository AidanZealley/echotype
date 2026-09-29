# Debug window whole-feature review

Status: not started. Begin only after both workstreams are accepted.

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
