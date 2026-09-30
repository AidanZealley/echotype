# EchoType macOS rewrite whole-feature review

Status: not started. Begin only after every numbered workstream is Accepted.

## Reviewer task packet

Read the workflow README, [specification](../macos-rewrite.md), plan and accepted handoffs. Review the complete integration branch against the starting commit recorded in the plan, including surrounding code. Do not infer correctness from accepted slice verdicts.

Audit every feature-contract item, agreed behavior and required spec case. Focus on cross-feature seams: command reservation, cancellation up to insertion, clipboard cleanup during reading replacement/dictation takeover, destination capture on every finishing path, Return suppression, trace final-text accuracy, expiry at actual MCP admission, bounded queues and teardown. Verify the Test/demo entry points remain isolated and dual MCP compatibility remains intentional.

Check dependency direction, duplicated mutable state, unowned tasks, old relay/clipboard/notification aliases, stale mocks, unjustified infrastructure, meaningful tests and documentation agreement. Optional findings remain optional. Run one whole-feature review, then focused closure of accepted corrections; do not create an open-ended implementation-review cycle.

Assign accepted corrections to fresh implementers with exact sequential file ownership. A changed accepted contract needs evidence-backed escalation and coordinated owner correction, not an unnoticed downstream patch. Perform a final deletion/simplification pass.

### Whole-feature verification

Run on the Mac after accepted corrections:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --enable-code-coverage
swift build -c release --product EchoTypeApp
./scripts/build-app.sh release .build/EchoType-workflow.app
git diff --check
```

Verify actual CI status and G1 through G6 evidence. Record the current Actions run or any approved publication/configuration follow-up. No live xAI test or installation is implied. G7 checks the signed candidate in the user's real editors and hardware, following the spec checklist and any explicitly settled supported-target limits.

### Acceptance

Every specification case has a tested outcome or explicit approved external-scope decision. All required findings are resolved, mandatory external gates pass, public contracts and persistence remain compatible, and the source/docs no longer describe replaced behavior. If mandatory evidence is missing, set Final to Blocked with a named escalation. Do not mark complete on the strength of unit tests alone.

## Initial whole-feature review

- Reviewer: TBD, lead subagent
- Branch, base and reviewed head: TBD
- Verification run: TBD
- Acceptance-criteria audit: TBD
- Required findings by owner: TBD
- Optional observations: TBD
- Questions: TBD
- Verdict: TBD

## Lead triage

- Accepted findings and owners: TBD
- Rejected findings and reasons: TBD
- Deferred optional observations: TBD
- Drift requiring user decision: TBD

## Focused closure

- Reviewed head: TBD
- Finding outcomes: TBD
- Final simplification assessment: TBD
- Remaining blockers: TBD
- Verdict: TBD

## External validation

- Gate and placement: G7, after focused closure before acceptance
- Status: Pending
- Candidate and instructions: Record signed release candidate, exact real-editor/hardware checks and needed user action
- Required evidence: Complete spec Mac checklist, command arbitration, both themes/changed accessibility, window focus, truthful trace/recovery and no stale operation effects
- Attempts and lasting decisions: TBD
- Resume condition: Mandatory evidence passes or an explicit scope decision resolves an unavailable check; meaningful gate corrections receive focused review

## Completion record

Before acceptance, copy a concise, self-contained summary of these facts into the plan's Completion summary. The orchestrator cannot read this packet.

- Delivered outcomes: TBD
- Final verification: TBD
- External validation pending: TBD
- Specification drift: TBD
- Deferred optional observations: TBD
