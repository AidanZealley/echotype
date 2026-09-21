# Starter prompt

Run this on the remote Linux machine, from the repository root.

```text
Orchestrate the complete implementation of EchoTypeCore.

Read docs/echotype-core/implementation/README.md and
docs/echotype-core/implementation/plan.md. Do not read the specification, task packets,
diffs or findings; the workstream leads own those.

Create the branch feat/echotype-core from the current approved HEAD and record the
branch and starting commit in the plan.

Then loop: read the plan, spawn a workstream lead for the next workstream passing only
its packet path. The lead records its own status, drift and escalation before
committing, so read its return only to decide whether to continue or stop. Wait for
each lead in one blocking call. Do not busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that
workstream and tell it to recover the uncommitted work using the README's recovery
rules.

After the last workstream is accepted, spawn the final-review lead documented in the
README.

Report to the user at each workstream acceptance, on an escalation, and in the
completion report covering delivered work, verification, external validation pending
and specification drift. Do not narrate progress otherwise.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put
that question to the user, record the answer in the entry, and start a fresh lead for
that workstream.

Workstream 3 needs an xAI API key and a sample recording that only Aidan can supply, so
expect it to block. Surface its escalation entry, record the answer, then start a fresh
lead.

Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
