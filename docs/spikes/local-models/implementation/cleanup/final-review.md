# Local cleanup (slice 1) whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 1 requirement in the spec's "Provider and candidate selection", "Native
  integration" (cleanup), "Model delivery experiment", "Evaluation" (cleanup) and "Build
  verification";
- seams between the store, the local provider and the bench, and that the plan's
  cross-workstream contracts hold;
- model and download lifecycle, cancellation and teardown;
- dependency direction: no candidate or model named outside `Providers/Local/` and the bench, and
  no local provider in `Providers.all`;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md`, the spec, the research and the test harness spec;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh debug .build/local-cleanup/EchoType.app
codesign --verify --deep --strict .build/local-cleanup/EchoType.app
```

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
