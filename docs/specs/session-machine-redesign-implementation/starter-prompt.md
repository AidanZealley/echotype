# Starter prompt

Paste this into a fresh Claude Code session in the repository root. To work on a separate branch instead, replace "Work directly on refactor/macos-lifecycle" with "Create refactor/session-finishing from the current HEAD of refactor/macos-lifecycle". You then fast-forward `refactor/macos-lifecycle` to it after the workflow completes.

```text
Orchestrate the complete implementation of the SessionMachine redesign.

Read docs/specs/session-machine-redesign-implementation/README.md and plan.md. Do not read the
specification, task packets, diffs or findings; the workstream leads own those.

This work completes the macOS lifecycle rewrite on refactor/macos-lifecycle. Work directly on
refactor/macos-lifecycle. Record the branch and starting commit in the plan. Do not merge
anything into main.

Then loop: read the plan, spawn a workstream lead for the next workstream passing only its packet
path. The lead records its own status, drift and escalation before committing, so read its return
only to decide whether to continue or stop. Wait for each lead in one blocking call. Do not
busy-poll a running agent.

If a row is in a non-terminal state and has no live lead, start a fresh lead for that workstream
and tell it to recover the uncommitted work using the README's recovery rules.

If you resume after a usage limit, error or restart, or the user says to continue without a lead
having returned, assume every agent stopped. Check each non-terminal row once for a lead confirmed
to be running; wait on that lead and recover every other row. Never wait on a lead you have not
confirmed.

After the last workstream is accepted, spawn the final-review lead documented in the README.

Report to the user at each workstream acceptance, on an escalation, and in the completion report
covering delivered work, verification, external validation pending, and specification drift. Do not
narrate progress otherwise.

When a lead returns Blocked, read only the escalation entry it names in plan.md, put that question
to the user, record the answer in the entry, and start a fresh lead for that workstream.

A lead blocking on an external validation gate needs an answer from the user. Surface its
escalation entry, record the answer there, then start a fresh lead for that workstream.

Continue autonomously. Ask only when a lead blocks.

Execute the workflow now rather than restating it.
```
