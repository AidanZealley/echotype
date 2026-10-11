# Local models productionization lead guide

Status: archived workflow instructions. Approved by Aidan on 2026-10-09; all workstreams
and whole-feature review were accepted on 2026-10-11. See [the plan](plan.md) for results.
The instructions below record the completed workflow; they do not reopen accepted work.

## Source of truth and ownership

Read your packet, plan.md and [the specification](../../specs/local-models-productionization.md).
Read applicable repository/harness instructions. No repository AGENTS.md was present when
this workflow was prepared; use any instructions present at execution time. Required context
is listed in each packet. Product requirements override workflow text. Approved packets and cross-stream contracts
are frozen. Escalate defects rather than silently
changing an accepted owner's work or the model choice.

Aidan prefers the smallest complete implementation, native macOS controls and clear
writing. Apply `/Users/aidanzealley/.agents/skills/unslop/SKILL.md` to user-facing prose.
Own interpretation, triage and acceptance for your stream, then end your session.
Only the orchestrator contacts the user; record questions as plan escalations.

## Agent spawning and role delivery

Use `spawn_agent` with `fork_turns: "none"`; omit model and reasoning_effort. Spawn a
fresh implementation agent and fresh reviewers independent of that implementation.
The implementation agent owns its changes through at most one remediation pass.
Wait with one long `wait_agent`, capped at 60 seconds under the active harness; continue
only while the child is confirmed running. Do not busy-poll or schedule wake-ups.
No concurrent shared-file edits, Swift builds or inference runs.

Give implementation agents this prompt with exact assigned paths and context:

```text
Implement the assigned local models productionization workstream or accepted corrections.
Read docs/productionization/implementation/implementation-brief.md, your assigned packet,
the productionization specification, the packet's required context, accepted dependency
handoffs and the Conventions learned section of plan.md. Follow the brief. Write your
Implementation handoff or Resolution section. Leave changes uncommitted. For corrections,
address only the supplied accepted findings and file ownership; report contract conflicts.
```

Reviewers read the code-review skill at
`/Users/aidanzealley/code/agent-config/skills/common/code-review/SKILL.md`, their packet,
applicable repository instructions, specification, required context, relevant dependency
contracts/handoffs and plan.md Conventions learned. Supply the base, reviewed HEAD/diff,
review stage, scope and record section explicitly. Include the applicable complete stage
brief below directly in the reviewer prompt, since they do not read this guide. Closure
prompts also include the original findings, the lead's dispositions and the corrections.
They need neither this guide nor README.
They may write only their assigned review section. General review rules live in that skill.

## Execution and review briefs

Update your plan row at each transition. Run implementation, independent review, at most
one remediation pass, then fresh focused closure. Triage advisory findings. Optional items
stay outside remediation unless explicitly promoted. There is no automatic third loop.

- Independent review inspects the entire owned change, including recovered trial edits,
  against packet acceptance and contracts. Write Independent review.
- Closure verifies dispositions and fixes in the original scope, checking fixes for new
  blocking defects. Do not restart full review or promote optional suggestions. Write Closure review.
- Whole-feature review inspects from the recorded starting commit, including all adopted
  dirty trial work, and also audits the net merge diff against the recorded main comparison
  base. Check the complete spec, cross-stream seams, lifecycle and simplification. Write
  Initial whole-feature review with findings by owner.
- Whole-feature closure verifies accepted findings and effects across boundaries. Write Focused closure.

All packet commands and meaningful new focused tests must pass. Exempt a failure only
with reproduction on the base commit and recorded evidence. Block on remaining required
findings, failing verification, unresolved disagreement, changed architecture/product
behavior or a user gate. Do not reopen model experimentation without evidence and escalation.

## Dirty work and interrupted recovery

Record your base before implementation. Inspect the complete owned diff, including untracked
files and earlier trial edits. Reuse sound work but review it as implementation, not evidence
of acceptance. Inventory unrelated dirty paths and leave them uncommitted. The plan records
initial allocation. Own new files only within your packet's responsibility.

On interruption, check child status once; wait only if running. Otherwise inspect changes,
verify enough to establish current state, and resume from the earliest unproven phase.
Rerun incomplete or undocumented reviews. If attribution or recovery is unsafe, preserve
work in a named recovery branch or stash and escalate; never overwrite it.

## Gates

Details live in plan.md and the owning packet. A user gate records candidate, instructions
and required evidence, then blocks through the normal escalation path. A retryable technical
gate remains within the stream: record the failure, correct proportionately and produce
another candidate. This does not create another review loop.
Reopen focused review when corrections change approved behavior, architecture, persistent
data, public contracts, security boundaries or accepted workstreams. Review meaningful
unreviewed gate corrections once after the gate passes. Preserve lasting decisions.

## Records, commits and terminal return

Integration branch: `feat/local-models-productionization`. Use plain imperative commit
subjects including the stream name, such as `Package production Kokoro speech assets`,
`Split Dictation and Read Aloud providers`, `Add explicit local setup and native Settings`,
`Prune local model experiments and validate production stack`, and
`Complete local models whole-feature review`. Read the git skill before committing.

Leave code uncommitted through review/remediation. Each accepted stream, including Final,
gets one scoped commit containing its implementation, packet record and plan updates.
Do not commit unrelated dirty work or record accepted commit hashes back in documents.

At acceptance, complete records, set the plan row Accepted, log drift and recurring lessons,
commit and return. At blocking, leave work uncommitted, set Blocked and create a plan escalation
with decision, options, recommendation, evidence, what it unblocks and user-answer field.
On resume, retain the lasting answer in the handoff/decision log before removing the resolved entry.
Return exactly:

```text
status: Accepted | Blocked
drift: one line, or none
escalation: plan.md escalation id, or none
```

## Final-review lead

Begin only after streams 1–4 are Accepted. Own Final and final-review.md. Delegate fresh
whole-feature review, triage accepted findings by ownership, assign corrections to fresh
implementation agents, and run fresh closure. Apply the same bounded remediation,
verification, record and commit rules. Public-release obligations may remain pending only
as the explicitly recorded release hold; functional acceptance checks may not be waived.
Final verification runs after bench retirement;
use its recorded earlier measurements as evidence, not a nonexistent final executable.
