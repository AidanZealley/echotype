# Provider adapters whole-feature review

Status: not started. Begin only after rows 1 to 5 are Accepted.

## Reviewer task packet

Review the full branch against the plan's starting commit and the [approved specification](../provider-adapters.md). Read the accepted handoffs, but review the combined diff and surrounding code independently.

Audit:

- **Completeness.** Every specification section, including the agreed product changes and documentation.
- **Contracts.** The transcription, read-aloud and cleanup contracts as implemented, against the guarantees in the specification, and whether a second provider could implement them without touching shared code.
- **Dependency direction.** Nothing outside `Providers/XAI/` reaches xAI except through the selected `Provider`. The provider-name search is clean.
- **Behaviour with xAI.** Matches the starting commit apart from the agreed changes. Fixtures stay authoritative.
- **Simplification.** Duplicated state, leftover shims, stale mocks, speculative machinery (batch mode, capability flags, availability) and tests coupled to implementation details.
- **Storage.** Compatibility and migration, including decoding settings written by the starting commit.
- **Documentation.** Decision records and the README agree with the code.

Run the complete deterministic suite and the release build once:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
swift build -c release --product EchoTypeApp
```

After closure, build the G3 candidate with `./scripts/build-app.sh debug .build/EchoType-workflow.app` and run gate G3 as the README describes. Tell Aidan the candidate migrates stored settings to the new format.

## Initial whole-feature review

- Reviewer: `TBD`
- Branch, base and reviewed head: `TBD`
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

## External validation

- Gate and placement: G3, after focused closure before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: the G3 entry in the plan
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan reports every G3 check passing

## Completion record

- Final verification: `TBD`
- External validation pending: `TBD`
- Specification drift: `TBD`
