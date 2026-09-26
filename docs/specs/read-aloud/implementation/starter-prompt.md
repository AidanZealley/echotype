# Starter prompt

Status: draft.

Paste this into a fresh Claude Code session on the Mac, in the repository root.

```text
Orchestrate the complete implementation of read aloud.

Read docs/specs/read-aloud/implementation/README.md and plan.md. Do not read the specification,
task packets, diffs or findings; the workstream leads own those.

Create feat/read-aloud from the current approved HEAD and record the branch and starting commit in
the plan.

Then loop: read the plan and spawn a workstream lead for the next workstream, passing only its
packet path, using the workstream lead prompt in starter-prompt.md. The lead records its own
status, drift and escalation before committing, so read its return only to decide whether to
continue or stop. Wait for each lead in one blocking call. Do not busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that workstream
and tell it to recover the uncommitted work using the README's recovery rules.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put that question
to Aidan, record the answer in the entry, and start a fresh lead for that workstream. Two blocks
are expected, both external validation gates that need Aidan on the Mac: G1, where workstream 1's
first lead asks him to run the spike before any code is written, and G2, where workstream 2 asks
him to try reading aloud. Give him the steps from the entry, record his results there, then start
a fresh lead.

After workstream 2 is accepted, spawn the final-review lead with the final-review lead prompt in
starter-prompt.md.

Report to Aidan at each workstream acceptance, on an escalation, and in the completion report the
README describes. Do not narrate progress otherwise.

Continue autonomously. Ask only when a lead blocks. Execute the workflow now rather than restating
it.
```

## Workstream lead prompt

Replace `<N>` and `<packet>` with the row's number and packet path.

```text
Lead workstream <N> of read aloud.

Read docs/specs/read-aloud/implementation/README.md and <packet>, then the source-of-truth
documents the README names. The task packet is frozen.

Run the README's per-workstream loop yourself: spawn a fresh implementation agent, spawn a
different fresh agent for independent review, triage the findings, order at most one remediation
pass, then run focused closure in a fresh review session using the same brief before accepting.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, and make one commit containing the code,
the record and the plan updates. The orchestrator does not record lead return fields, so anything
worth keeping must be in that commit.

You cannot reach Aidan. Block if a decision materially changes approved behaviour or architecture,
if disagreement persists after closure, or if gate G1 or G2 needs Aidan. To block, add an
escalation entry to plan.md giving the decision needed, the options, your recommendation, the
evidence and what it unblocks, set your row to Blocked, leave the work uncommitted, and return its
id. Summarise; do not paste findings or diffs.

If you are resuming a blocked workstream, the uncommitted work and the answered escalation entry
are yours. Before you accept, copy its lasting decision into your handoff Decisions field, and
into the plan's decision and drift log when a later workstream or the final review depends on it,
then remove the entry.

If your row is already in a non-terminal state, you are recovering interrupted work. Follow the
README's interrupted work recovery rules before continuing.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of read aloud.

Read docs/specs/read-aloud/implementation/README.md and final-review.md, then the source-of-truth
documents the README names. Every workstream is accepted; the branch is complete.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in the plan.
Triage its findings, send each accepted correction to a fresh implementation agent owning the
relevant files, then run focused closure in a fresh review session using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to Accepted,
add any specification drift to the plan's decision and drift log, and make one commit containing
the corrections, the record and the plan updates.

You cannot reach Aidan. Block the same way a workstream lead does: add an escalation entry to
plan.md, set the Final row to Blocked, leave the work uncommitted, and return its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```
