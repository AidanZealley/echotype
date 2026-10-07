# Starter prompt

Give this to a fresh orchestration agent in the repository root.

```text
Orchestrate the complete implementation of local cleanup, slice 1 of the local models spike.

Read docs/spikes/local-models/implementation/cleanup/README.md and
docs/spikes/local-models/implementation/cleanup/plan.md. Do not read the specification, task
packets, diffs or findings; the workstream leads own those.

Work on the existing branch spike/local-models; do not create a branch. Record its HEAD as the
starting commit in the plan.

Then loop: read the plan, spawn a workstream lead for the next workstream passing only its
packet path. The lead records its own status, drift and escalation before committing, so read
its return only to decide whether to continue or stop. Wait for each lead in one blocking call.
Do not busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that workstream
and tell it to recover the uncommitted work using the README's recovery rules.

If you resume after a usage limit, error or restart, or the user says to continue without a lead
having returned, assume every agent stopped. Check each non-terminal row once for a lead
confirmed to be running; wait on that lead and recover every other row. Never wait on a lead you
have not confirmed.

After the last workstream is accepted, spawn the final-review lead documented in the README.

Report to the user at each workstream acceptance, on an escalation, and in the completion report
covering delivered work, verification, external validation pending, and specification drift. Do
not narrate progress otherwise.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put that
question to the user, record the answer in the entry, and start a fresh lead for that workstream.

A lead blocking on an external validation gate needs an answer from the user. Surface its
escalation entry, record the answer there, then start a fresh lead for that workstream.

If you are Codex: delegate this work to sub-agents as documented. Spawn every agent with
fork_turns "none" and no model or reasoning_effort override.

Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
