# Starter prompt

Paste this into a fresh session on the Mac, from the repository root.

```text
Orchestrate the complete implementation of the settings milestone.

Read docs/settings/implementation/README.md and docs/settings/implementation/plan.md.
Do not read the specification, task packets, diffs or findings; the workstream leads own
those.

Create feat/settings from the current approved HEAD and record its base in the plan.

Then loop: read the plan, spawn a workstream lead for the next workstream passing only
its packet path. The lead records its own status, drift and escalation before committing,
so read its return only to decide whether to continue or stop. Wait for each lead in one
blocking call. Do not busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that
workstream and tell it to recover the uncommitted work using the README's recovery rules.

After the last workstream is accepted, spawn the final-review lead documented in the
README.

Report to the user at each workstream acceptance, on an escalation, and in the completion
report covering delivered work, verification, external validation pending, and
specification drift. Do not narrate progress otherwise.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put that
question to the user, record the answer in the entry, and start a fresh lead for that
workstream.

Workstream 1 blocks at gate G1 for Aidan to check that settings and the key persist, and
workstream 2 blocks at gate G2 for him to check the device picker, the Test button, the
permission rows and launch at login. Surface each escalation entry, record his answer
there, then start a fresh lead for that workstream.

Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
