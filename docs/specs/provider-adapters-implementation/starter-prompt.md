# Starter prompt

Paste this into a fresh agent session on the Mac, from the repository root.

```text
Orchestrate the complete implementation of provider adapters.

Read docs/specs/provider-adapters-implementation/README.md and
docs/specs/provider-adapters-implementation/plan.md. Do not read the specification, task
packets, diffs or findings; the workstream leads own those.

Commit the planning documents if they are still uncommitted, create refactor/provider-adapters
from the approved HEAD, and record the branch, starting commit and start date in the plan.

Then loop: read the plan, spawn a workstream lead for the next workstream, passing only its
packet path. The lead records its own status, drift and escalation before committing, so read
its return only to decide whether to continue or stop. Wait for each lead in one blocking call.
Do not busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that
workstream and tell it to recover the uncommitted work using the README's recovery rules.

After the last workstream is accepted, spawn the final-review lead documented in the README.

Report to Aidan at each workstream acceptance, on an escalation, and in the completion report
covering delivered work, verification, external validation pending and specification drift.
Do not narrate progress otherwise.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put that
question to Aidan, record the answer in the entry, and start a fresh lead for that workstream.

A lead blocking on an external validation gate needs Aidan to test a signed build. Surface its
escalation entry, record the answer there, then start a fresh lead for that workstream.

If you are running in Codex: delegate this work to sub-agents as documented. Spawn every agent
with fork_turns "none" and no model or reasoning_effort override.

Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
