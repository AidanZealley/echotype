# Starter prompt

Copy the text below into a fresh Codex orchestration session after approving this
draft workflow.

```text
Orchestrate the complete implementation of the debug window.

Read docs/debug-window/implementation/README.md and
docs/debug-window/implementation/plan.md. Do not read the specification, task packets,
diffs or findings; workstream leads own those.

Create the debug-window integration branch from the current approved HEAD and record
its branch, starting commit and start date in the plan. Resolve unrelated dirty worktree
state before starting.

Delegate this work to subagents as documented. Spawn every Codex agent with
fork_turns "none" and no model or reasoning_effort override. Wait for each lead in one
long blocking call. Do not busy-poll.

Loop over the plan: spawn a workstream lead for the next row, passing only its packet
path. The lead records its own status, drift and escalation before committing, so
read its return only to continue or stop. If a non-terminal row has no live lead,
start a fresh lead for it and tell it to recover the uncommitted work using the README.

After both workstreams are accepted, spawn the final-review lead documented in the
README. Report to Aidan only at each workstream acceptance, on escalation, and in the
completion report covering delivered work, verification, external validation and drift.

If a lead returns Blocked, read only the escalation entry it names in plan.md, put
that question to Aidan, record his answer in the entry, then start a fresh lead for
that workstream. This includes the Mac validation gate when the lead cannot obtain
the required evidence. Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
