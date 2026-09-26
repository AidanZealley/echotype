# Live revision whole-feature review

Workflow status: draft. Review status: not started. Begin after both workstreams are accepted.

## Reviewer task packet

Review the full integration branch against the starting commit in `plan.md` and the approved
specification. Inspect both accepted handoffs, then independently inspect the combined diff and
surrounding code. Check complete behavior, actor and cancellation lifetimes, single-flight
windowing, snapshot-to-pill and pill-to-insertion agreement, settings migration, nonactivating
panel behavior, dependency direction, duplicated state, stale batch code, meaningful tests, and
documentation agreement. Classify findings as Required, Optional, or Question with evidence.
This is the one open-ended whole-feature review; closure checks accepted fixes only.

The final gate follows whole-feature closure. Run `swift build` and `swift test` on the Mac.
Run the real prompt cases with `XAI_API_KEY` set; a skipped prompt suite does not pass the gate.
Run the signed app through `./scripts/run.sh`, dictate pauses and corrections, compare the
pill's final text with inserted text, and record stop-to-insertion timing against the draft's
three-second final timeout. Check the cleanup toggle off and Test button. Verify the pill
scrolled-up behavior while new words and revisions arrive. Use the visual approval recorded by
workstream 02; do not ask Aidan to repeat it without a concrete change affecting the result.

If the Mac or key is unavailable to the lead, record the exact candidate and missing evidence,
add a plan escalation, and return Blocked. Aidan or a fresh local lead supplies the result.
When prompt cases or timings fail, diagnose and make a focused correction. Keep the gate in
`Troubleshooting`; review meaningful unreviewed corrections once. Reopen the normal loop only
for the boundary changes listed in the README. Do not weaken the faithfulness rule merely to
make an expected string pass.

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

## External validation

- Gate and placement: Endpoint and real dictation after closure, before final acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`; include branch head, `swift test` result with live cases,
  `./scripts/run.sh` build, dictation phrases, and timing method.
- Required evidence: Prompt cases ran against the endpoint, all required tests passed, the
  inserted text matched the pill, and observed stop latency supports the chosen timeout.
- Attempts and lasting decisions: `TBD`
- Resume condition: The lead records passing evidence or the orchestrator records Aidan's
  answer to a blocking escalation, then a fresh lead audits and continues.

## Completion record

- Final verification: `TBD`
- External validation pending: `TBD`
- Specification drift: `TBD`
