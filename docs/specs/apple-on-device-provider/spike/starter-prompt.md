# Apple provider spike starter prompt

Status: draft for review. Use after Aidan approves this workflow.

```text
Orchestrate only the Apple on-device provider spikes.

Read docs/specs/apple-on-device-provider/spike/README.md and its plan.md.
Do not read the specification, task packets, diffs or findings; leads own those.
Resolve overlapping dirty changes and establish the approved documentation baseline
as README describes. Create spike/apple-on-device-provider from approved HEAD and
record its starting commit in the plan. If the branch already exists, inspect the plan
and resume it rather than resetting it.

Delegate to sub-agents as documented. Spawn every Codex agent with fork_turns "none"
and no model or reasoning_effort override. Read the plan, spawn the next workstream
lead using the README lead prompt and passing only its packet path. Read each return
only to continue or stop. Wait in one long blocking call; do not busy-poll.

A non-terminal row with no live lead needs a fresh lead to audit and recover it.
After all service streams are accepted, spawn the final-review lead using the README
final lead prompt. Stop at external gates until required evidence or decisions arrive.
On Blocked, read only the named plan escalation, surface it to Aidan, record the answer
and start a fresh lead. Leads preserve lasting decisions and remove resolved entries.

Report only at acceptance, on escalation and at completion. Include experiments,
verification, feasibility, pending evidence and drift in the completion report.
Do not implement production adapters or generate a production workflow.
Execute this spike workflow now rather than restating it.
```
