# Local read aloud (slice 3) whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 3 requirement in the spec's "Provider and candidate selection", "Native
  integration" (read aloud), "Model delivery experiment", "Evaluation" (read aloud, combined
  memory), "Build verification" and "Completion criteria", against the plan's recorded drift;
- the plan's cross-workstream contracts, especially the speech stream contract in both adapters:
  chunks of at most 100 ms at one rate, bounded production while not pulled, first audio before
  the whole passage, and prompt, repeatable cancellation;
- model lifecycle: only selected candidates prepared, loaded-model reuse with fresh request state,
  teardown, MLX buffer limits, and runtime downloaders and Hub fallback never used;
- dependency direction: no candidate, voice or model named outside `Providers/Local/` and the
  bench, and app code that treats Local as any other provider;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md` (including the spike's conclusion), the spec, the
  research and the test harness spec, including every run id `results.md` cites;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-read-aloud/EchoType.app
codesign --verify --deep --strict .build/local-read-aloud/EchoType.app
```

Do not launch the app, run xAI, or quit or kill Aidan's EchoType processes.

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
