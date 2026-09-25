# Starter prompt

```text
Orchestrate the complete implementation of EchoType v1's local install step.

Read docs/specs/install/implementation/README.md and plan.md. Do not read the specification, task packets, diffs or findings; the workstream leads own those.

Create codex/install-echotype-v1 from the current approved HEAD and record its base in the plan. Then loop: read the plan, spawn a workstream lead for the next workstream, passing only its packet path. Read its return only to decide whether to continue or stop. Wait for each lead in one blocking call. Do not busy-poll.

If a row is non-terminal with no live lead, start a fresh lead for that row and tell it to recover the uncommitted work using the README's rules. After the workstream is accepted, spawn the final-review lead documented in the README.

Report to the developer at workstream acceptance, on an escalation and at completion. Do not narrate progress otherwise. When a lead returns Blocked, read only its escalation entry in plan.md, ask the developer for the needed decision or G1 login evidence, record the answer there and start a fresh lead for that workstream.

Delegate this work to sub-agents as documented. Spawn every agent with fork_turns "none" and no model or reasoning_effort override. Continue autonomously. Ask only when a lead blocks. Execute the workflow now rather than restating it.
```

## Workstream lead prompt

```text
Lead workstream 1 of EchoType v1 local install.

Read docs/specs/install/implementation/README.md and 01-local-install.md, then the source-of-truth documents named in the README. The packet is frozen.

Run the documented loop: spawn a fresh implementation agent, spawn a different fresh agent for independent review, triage findings, order at most one remediation pass, then run focused closure in a fresh review session. You own the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write the packet record, set your row in plan.md to Accepted, record drift, and make one commit containing code, record and plan. You cannot reach the developer. For a material decision, persistent closure disagreement or G1 user action, add a concise escalation in plan.md with options, recommendation, evidence and what it unblocks. Set your row Blocked, leave work uncommitted, and return its id. On resumption, audit inherited work and record the lasting answer before removing the escalation.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of EchoType v1 local install.

Read docs/specs/install/implementation/README.md and final-review.md, then the source-of-truth documents named in the README. Spawn a fresh reviewer to inspect the full branch against the starting commit in plan.md. Triage findings, send each accepted correction to a fresh implementation agent owning the relevant files, then run focused closure in a fresh review session. You own the terminal decision.

At acceptance, write final-review.md, set the Final row in plan.md to Accepted, record drift, and make one commit with corrections and records. For a material decision or unresolved blocker, add an escalation, set Final to Blocked, leave work uncommitted, and return its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```
