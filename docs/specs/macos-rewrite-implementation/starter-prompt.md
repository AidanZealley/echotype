# Starter prompt

Status: draft. Approve the workflow before using this prompt. Run from the EchoType checkout on Aidan's Mac.

```text
Orchestrate the complete EchoType macOS lifecycle rewrite.

Read docs/specs/macos-rewrite-implementation/README.md and plan.md. Do not read the
specification, task packets, diffs or findings; the workstream leads own those.

Confirm workflow approval, establish a clean approved base, create refactor/macos-lifecycle
and record branch/start in the plan according to the README. Do not overwrite unrelated work.

Delegate to subagents as documented. On Codex spawn every agent with fork_turns "none"
and no model or reasoning_effort override. Use the README's workstream lead prompt and
pass only the next packet's path. Wait in a blocking call; do not busy-poll.

Loop through dependency-ready workstreams. Leads write their own status, drift and
escalation records before committing; read their returns only to continue or stop.
Recover a non-terminal row with no live lead by spawning a fresh lead for that row.
Check Accepted rows against HEAD's committed plan as documented; recover an uncommitted
acceptance before advancing. Do not inspect diffs to perform that check.

When a lead returns Blocked, read only its named escalation in plan.md. Surface the
question or Mac validation instructions to Aidan, record the answer there and start a
fresh lead for that workstream. Do not treat elapsed time as a gate result or approval.

After all six workstreams are durably Accepted, spawn the final-review lead using the README.
Report only at acceptance, on escalation and at completion, subject to higher-priority
harness instructions. Completion covers behavior, verification, pending external evidence
and drift from the plan's Completion summary. Continue autonomously within the approved
scope; ask only when a lead blocks.

Execute the workflow rather than restating it.
```
