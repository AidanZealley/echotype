# Batch pass on commit whole-feature review

Status: not started. Begin only after workstreams 1 and 2 are accepted and G1 has passed.

## Reviewer task packet

Review the full branch against the starting commit in `plan.md` and the approved
[specification](../../batch-on-commit.md). Read the accepted handoffs in
[01-batch-transcriber.md](01-batch-transcriber.md) and [02-insert-batch-text.md](02-insert-batch-text.md),
then review the combined diff and surrounding code independently.

Check:

- Every item in the specification's Behaviour, Implementation and Tests sections is delivered, or
  its drift is in the plan's decision and drift log.
- The seam between the two workstreams: the PCM format, the timeout living only in
  `BatchTranscriber`, empty text treated as a fallback by the caller, and the keyterm caps defined
  once.
- Session lifecycle: the recording is collected for every session and released when it ends, the
  Keychain is read once, `test()` is unchanged, and `.nothing` and `.failed` outcomes skip the pass.
- Settings storage: the stored key name, independent decoding, and decision 0010.
- Machinery the specification does not ask for: retries, logging, network mocks, extra state or
  options.
- Test quality: the tests protect the WAV format, the request body and the stored setting, not
  implementation details.
- Documentation agreement: decision 0017, the index, decision 0010, doc comments in
  `DictationController`, and the specification's status.

Run `swift build` and `swift test`. Do not launch the app or change settings; G1 covered it.
Classify evidence as Required, Optional or Question, and name the owning file for each Required
finding.

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
