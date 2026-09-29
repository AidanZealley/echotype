# Voice replies whole-feature review

Status: accepted.

## Reviewer task packet

Review the full branch against the starting commit recorded in [the plan](plan.md) and
[the specification](../../voice-replies.md). Inspect the accepted handoffs, but independently
review the combined diff and the surrounding code.

Audit completeness against the specification, the seams between the five workstreams, the
lifecycle of a reading and a dictation, dependency direction between `EchoTypeCore` and
`EchoTypeApp`, duplicated state, stale or coupled tests, speculative machinery, documentation
agreement (README, decision 0022, specification status), and behaviour Gates A and B did not
cover. Run `swift test` and `swift build`.

## Initial whole-feature review

- Reviewer: review command (Opus 5.5, medium), read-only
- Branch, base, and reviewed head: `voice-replies`, base `d451a6f`, head `f5504fb` plus the uncommitted fixes A and B
- Verification run: `swift build`, `swift test` (67 tests) passed
- Acceptance-criteria audit: every specified behaviour present, nothing beyond it; core does not depend on the app
- Required findings by owner: two wording findings on `MCPServer.speakGuidance` (fix A): "immediately" could mean calling `speak` before the work is done, and "do not check available apps or tools" would block loading a deferred tool schema
- Optional observations: docs still described the streamed-text send decision; plan log lacked entries for A and B; the Reviser guard runs even when sending is off; a request split by a pause can end a session without sending; stale status lines
- Questions: should Escape cancel a send once decided
- Verdict: Changes required (fix B accepted as written)

## Lead triage

- Accepted findings and owners: both Required wording findings, corrected by one fresh implementation agent. Optional: the spec line saying a hotkey-ended session sends on streamed text, and the plan log entries, were promoted.
- Rejected findings and reasons: none.
- Deferred optional observations: guard running with sending off (harmless, the guard only refuses to drop a request), split-request case (better than before fix B), stale status lines in `plan.md` and the spec, and the older packet `03-sending.md` wording (frozen), Escape during a send (pre-existing behaviour, needs a product decision).
- Drift requiring user decision: none.

## Known defects fixed in this pass

- A. `speakGuidance` hardened (mapping first, wrong actions named, no searching).
- B. Root cause: the send was decided on streamed text, but the inserted text is the final revision, and `Reviser.isFaithful` accepts deletions, so the cleanup model could drop the phrase. Fix: `Reviser` rejects a revision that drops a reply request, and the controller decides the send from the inserted text. Test: `revisionKeepsReplyRequest`. Not reproduced with the real model.

## Focused closure

- Reviewed head: `f5504fb` plus the uncommitted diff
- Finding outcomes: both Required findings resolved; fix B has no release-blocking defect
- Final simplification assessment: no new machinery; one condition in `Reviser`, one moved decision
- Remaining blockers: none from review
- Verdict: Accept

## Completion record

- Final verification: `swift build` and `swift test` (67 tests) passed on the final diff
- External validation: fix A passed on the Mac (wording much more reliable). Fix B (phrase lost before submit) was not reported either way, so it is accepted as unverified against the real cleanup model. Reopen if the user sees it again; the evidence needed is the streamed committed text, each revision result, the inserted text and the Clean up setting.
- Specification drift: send decision on inserted text; see the plan's log
