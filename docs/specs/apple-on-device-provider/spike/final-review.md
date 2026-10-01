# Apple provider combined spike review

Status: not started. Begin after all three service spikes are accepted.

## Reviewer task packet

Review the whole branch against the plan's starting commit and source-of-truth specification. Inspect accepted records, combined diff and surrounding caller code independently. This is a feasibility review, not a production implementation review.

Audit all S1/S2/S3 answers, genuine opt-in behavior, absence of production changes, lifecycle and bounded buffering evidence, meaningful cleanup, unsupported states, and containment. Verify every feature is represented, distinguishing measured adapter compatibility from future app wiring. Lower quality than xAI is acceptable; completeness, safety of original text and contracts still matter. Assess whether proposed shared changes are justified. Identify missing evidence rather than infer success.

The final lead owns this file, combined specification corrections, its `Feature feasibility` results section and decision gate record, the Final plan row and gate, and owner-assigned corrections to test files. Corrections use fresh agents with exclusive file ownership. No production changes are allowed.

Create a compact matrix in the spec with requirement, evidence, supported-path feasibility, limitation and future verification. Include transcription and transcript/speech event mapping; Test; built-in and saved keyterms; language; read aloud and MCP speech; voice/speed choices; pause/resume and bounded audio; startup/finish/cancellation; real cleanup and faithfulness/failure behavior; offline operation after setup; asset installation and availability. Retained per-provider settings and UI/MCP wiring remain future production checks, supported here by reading the shared callers.

Summarize recommended voices, locale/setup policy, cleanup context handling, availability needs and any necessary shared changes beyond availability. Do not silently remove cleanup or another feature. If framework support fails, present evidence and realistic options to Aidan.

### Verification

On Aidan's Mac, run the normal suite with ECHOTYPE_APPLE_SPIKE, XAI_API_KEY and ECHOTYPE_FIXTURE_WAV unset in that shell:

```bash
swift test --disable-xctest
git diff --check
```

Repeat live checks only for changed experiments or unresolved concerns, using accepted exact commands. No release build or deployed app is needed for this test-only investigation. Any missing live evidence blocks rather than being represented as a passing test.

## Initial whole-spike review

- Reviewer: TBD
- Branch, base and reviewed candidate: TBD
- Verification: TBD
- Acceptance audit and feature matrix: TBD
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

- Reviewed candidate: TBD
- Finding outcomes: TBD
- Simplification assessment: TBD
- Remaining blockers: TBD
- Verdict: TBD

## External validation

- Gate and placement: Aidan's decision, after closure before final acceptance
- Status: Pending
- Candidate and instructions: matrix and concise feasibility recommendation in the spec
- Required evidence: Aidan's explicit decision on proceeding, policies and any limitations/shared changes
- Attempts and lasting decisions: TBD
- Resume condition: answer recorded in plan escalation, then preserved in spec and completion record

A user gate returns Blocked and leaves work uncommitted. On resume, record the decision even if it defers the provider. A negative feasibility finding can complete the investigation once Aidan's decision is recorded; it cannot authorize a reduced feature set by itself. Do not build the production workflow here.

## Completion record

- Final verification: TBD
- Feature feasibility and recorded user decision: TBD
- External evidence pending: TBD
- Specification drift: TBD
