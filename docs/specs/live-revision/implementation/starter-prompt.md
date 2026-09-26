# Starter prompt

Status: draft. Use after Aidan approves this workflow and the specification and workflow
documents are committed in a clean Mac checkout.

```text
Orchestrate the complete implementation of live revision.

Read docs/specs/live-revision/implementation/README.md and plan.md. Do not read the
specification, task packets, diffs, or findings; the workstream leads own those.

Create the live-revision integration branch from the current approved HEAD and record its
branch and starting commit in plan.md.

Then loop: read plan.md, spawn a lead for the next workstream passing only its packet path,
and read its return only to decide whether to continue or stop. The lead records its own
status, drift, and escalation before committing. Wait for each lead with one blocking call;
do not busy-poll. If a non-terminal row has no live lead, start a fresh lead for it and tell
it to recover using the README's rules.

After both workstreams are accepted, spawn the final-review lead from the README. Report to
Aidan only at each workstream acceptance, on an escalation, and in the completion report.
Do not narrate other progress.

When a lead returns Blocked, read only its named escalation in plan.md, put the decision or
validation request to Aidan, record the answer there, and start a fresh lead. The variant
choice, pill visual approval, and final endpoint and dictation checks are external gates.

Delegate this work to subagents as documented. In Codex, spawn every agent with
fork_turns "none" and no model or reasoning_effort override.

Continue autonomously. Ask only when a lead blocks. Execute the workflow now rather than
restating it.
```
