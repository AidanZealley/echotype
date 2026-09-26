# Live revision implementation workflow

Status: draft orchestration instructions. Approve these documents before execution.

This directory is the complete handoff for a fresh orchestration agent running on Aidan's MacBook.

## Source of truth

Read repository instructions, [the approved spec](../../live-revision.md), and the relevant
[decision records](../../../decisions/README.md). Product documents override this workflow.
The approved spec supersedes the batch decision and the two-line pill behavior in earlier
decisions; preserve their history when updating their status.
The orchestrator alone reads this README and [plan.md](plan.md), then lead returns. Leads and
their agents read the specification, task packet, handoffs, and code they own.

## Roles and loop

- **Orchestrator:** Owns one integration branch, its base, dependency order, escalations, and
  completion report. Read `plan.md` and each lead's three-field return. Never read the spec,
  packets, diffs, or findings. Pass a lead only its packet path. Write only the branch and
  starting commit at startup, and the user's answer in an escalation. Each write lands in the
  next lead's commit.
- **Workstream lead:** Owns one packet until acceptance or blockage. Update its plan row on every
  transition. Spawn a fresh implementation agent and a different fresh reviewer, triage findings,
  allow at most one remediation pass, then run focused closure with a fresh reviewer. Write the
  packet record and plan changes, then make one commit. End after returning.
- **Implementation agent:** Owns the packet's files, makes the smallest complete change, performs
  a deletion and simplification pass, and records the implementation handoff. Run only packet
  verification; the test suite is the final gate in the spec.
- **Reviewer:** Reads the whole workstream diff and surrounding code. Report evidence as
  **Required**, **Optional**, or **Question** in the packet's review section. Do not edit code.
  Optional findings do not block unless the lead promotes them with a reason.

Run workstreams sequentially. After both are accepted, spawn the final-review lead. Report to
the user only at workstream acceptance, on an escalation, and in the completion report. Do not
narrate other progress. `plan.md` is the live status view.

## Lead return contract

Before returning, the lead writes status in its plan row, drift in the decision and drift log,
and any escalation in the escalations section. The orchestrator does not transcribe returns.

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

On `Blocked`, read only the named escalation, ask the user for its decision or validation,
record the answer there, then start a fresh lead for that workstream.

## Agent spawning

Delegation is required for this workflow. In Codex, spawn with `fork_turns: "none"` and omit
`model` and `reasoning_effort`. In Claude Code, use `Agent` with
`subagent_type: general-purpose`, `run_in_background: false`, and omit `model`. Wait for each
agent with one blocking call: `wait_agent` with a long wait in Codex; the `Agent` call blocks in
Claude Code. Do not busy-poll. Agents share a worktree and must not edit it concurrently.

## Branch and commits

Begin from a clean Mac checkout with the approved spec and workflow committed. Follow the
repository's plain-language branch and commit conventions; use `live-revision` for the
integration branch unless that name already exists. Record its starting commit in `plan.md`.
Each accepted workstream makes exactly one commit containing its code, packet record, and plan
updates, with `Live revision 01:` or `Live revision 02:` in the subject. The final-review lead
makes one final commit. Do not write accepted commit hashes into documents.

## Lead procedure and prompts

Start by checking the branch and packet ownership. Spawn the implementation agent, wait, then
spawn an independent reviewer. Triage its findings. If required, order one remediation pass by
the implementation agent and ask it to simplify the affected design, then run focused closure
with a fresh reviewer. Closure checks accepted fixes and release-blocking defects in them; it
does not start another open-ended review. Accept or block. Persistent disagreement or a change
to approved behavior or architecture goes to the orchestrator.

Implementation prompt: "Read README.md, your packet, the approved spec, and dependency handoffs.
Own only the packet's files. Implement its acceptance criteria, perform a deletion and
simplification pass, run its targeted verification, and write only Implementation handoff."

Review prompt: "Read README.md, the packet, the approved spec, and the complete workstream diff.
Check acceptance, regressions, ownership, and needless complexity. Run proportionate read-only
checks. Write only Independent review, classifying Required, Optional, and Question with evidence."

Closure prompt: "Using the same brief, check the accepted findings and fixes in a fresh session.
Write only Closure review. Do not restart open-ended review or promote optional suggestions."

### Workstream lead prompt

```text
Lead workstream N of live revision.

Read docs/specs/live-revision/implementation/README.md and the numbered packet path supplied
to you, then its source-of-truth documents. The task packet is frozen.

Run the README's agent loop yourself. Own triage and the terminal decision. Reviewer findings
are evidence, not instructions. Observe the packet's external gates at their stated placement.

At acceptance, finish the record, set your row to Accepted, log any drift, and make one commit
with code, record, and plan updates. To block, write a concise escalation with decision needed,
realistic options, your recommendation, evidence, and what it unblocks; set your row to Blocked
and leave the work uncommitted. You cannot reach the user.

On resuming a blocked row, use its answered escalation and uncommitted work. Record the lasting
decision in your handoff and in the plan when later work depends on it, then remove the entry.
On interrupted work, follow the README's recovery rules.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

### Final-review lead prompt

```text
Lead the whole-feature review of live revision.

Read docs/specs/live-revision/implementation/README.md and final-review.md, then their
source-of-truth documents. All workstreams must be accepted.

Spawn a fresh reviewer for the whole branch against the starting commit in plan.md. Triage
findings, send accepted corrections to fresh implementation agents by file owner, and run
focused closure in a fresh review session. Own the terminal decision. At acceptance, complete
final-review.md, set the Final row to Accepted, log drift, and make one commit. Block through
a concise plan.md escalation and leave work uncommitted when user judgment is needed.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Interrupted work recovery

A non-terminal row without a live lead is interrupted. A fresh lead audits the complete diff,
base, ownership of every change, and enough checks to establish the current state. Continue from
the earliest phase it cannot prove complete; reuse sound work and rerun undocumented or partial
reviews. Abandon partial work only if attribution or base is wrong, it contradicts the packet,
overlaps unrelated changes, or repair is less safe than restart. Preserve it in a named stash or
recovery branch first. Escalate unclear ownership; never overwrite it.

## External validation gates

Workstream 02 has a user choice before pill implementation and user visual verification after
closure, before acceptance. The final review has the endpoint and Mac dictation gate from the
spec. At a user gate, the lead records the candidate, instructions and required evidence in its
packet, adds a plan escalation, sets `Blocked`, and leaves work uncommitted. The orchestrator
asks the user, records the answer, and starts a fresh lead. A retryable failure stays in the
same workstream: record the evidence, make the smallest correction, run proportionate checks,
and show a new candidate. Reopen review only if a correction changes approved behavior,
architecture, ownership, security, persistence, a public contract, or an accepted workstream;
otherwise review meaningful unreviewed changes once after the gate passes.

## Final whole-feature review

The final-review lead owns the Final row. Its fresh reviewer checks the assembled branch for
spec completeness, lifecycle, dependency direction, duplicated state, stale mocks, test quality,
and documentation agreement. The lead assigns accepted corrections to fresh agents by owner,
then runs focused closure. It follows the same return and escalation contract.

## Completion report

Report delivered behavior, verification evidence, pending external checks, specification drift,
and deferred optional observations. Do not claim a gate passed without its recorded evidence.
