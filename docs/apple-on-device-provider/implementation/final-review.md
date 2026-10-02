# Apple on-device provider whole-feature review

Status: not started. Begin only after every workstream is accepted. G2's remaining external checks follow this review and do not block review acceptance.

## Reviewer task packet

Review the full branch against the starting commit in [plan.md](plan.md) and the approved [specification](../../specs/apple-on-device-provider.md). Read the accepted handoffs, but review the combined diff and surrounding code independently.

Audit:

- **Completeness.** Every specification requirement is met, or explicitly pending external validation.
- **Containment.** No Apple-specific branch, type or wording outside `Providers/Apple/` and `Providers.swift`. Every other change appears in the extensibility report with its reason.
- **Seams.** The readiness contract is used consistently by dictation, Test, reading, MCP speech and Settings. xAI's behaviour is unchanged.
- **Lifecycle.** Setup runs at most once at a time. Cancellation and joining hold in each adapter. Change streams do not leak across provider switches.
- **Dependency direction.** Duplicated state, stale fakes or mocks, and speculative machinery.
- **Tests.** They protect behaviour rather than implementation details. Live checks skip by default.
- **Documentation.** The specification, decision 0025, the research document and `README.md` agree with the code. No reference to the deleted spike remains outside git history.

### Verification

```bash
swift test
swift build -c release --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-final.app
git diff --check
```

For any correction that touches behaviour Aidan verified at G2, mark the affected item numbers for re-checking in the plan's [G2 end checklist](plan.md#g2-end-checklist) and link them under Completion record. The checklist is the canonical record for the remaining external checks after this review; keep them pending until Aidan supplies evidence. Review acceptance does not claim full external verification.

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
