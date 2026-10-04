# Local transcription (slice 2) whole-feature review

Status: not started. Begin only after every workstream is accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [plan.md](plan.md) and the
approved [spec](../../spec.md). Read the accepted handoffs, but review the combined diff and the
code around it independently.

Audit:

- every slice 2 requirement in the spec's "Provider and candidate selection", "Native
  integration" (transcription), "Model delivery experiment", "Evaluation" (transcription and the
  concurrent check) and "Build verification";
- the plan's cross-workstream contracts, especially the transcriber behaviour contract in both
  adapters: committed text only grows, rescoring never rewrites it, the tail resolves before
  `.finished`, and `close()` and `waitForClose()` are safe at any time;
- model and download lifecycle, loaded-model reuse, teardown, and that only selected candidates
  are prepared;
- dependency direction: no candidate or model named outside `Providers/Local/` and the bench,
  and app code that treats Local as any other provider;
- duplicated state, speculative machinery, and comparison machinery that should not become
  permanent;
- test value: focused tests for real risks, no ceremonial ones;
- agreement between the code, `results.md`, the spec, the research and the test harness spec,
  including every run id `results.md` cites;
- external behaviour still unverified.

Verification:

```bash
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-transcription/EchoType.app
codesign --verify --deep --strict .build/local-transcription/EchoType.app
```

Do not launch the app or run xAI.

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
