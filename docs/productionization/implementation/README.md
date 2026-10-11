# Local models productionization workflow

Status: approved by Aidan on 2026-10-09. Streams 1–4 and their required functional/UI
gates are Accepted. Combined-model evidence is recorded and the bench is retired.
Whole-feature review, bounded F-R1/F-R2 corrections and independent focused closure
are Accepted on 2026-10-11. No merge or publication occurred. Public release remains held for licensing/provenance
and Developer ID/notarization checks.

## Role files

- [Lead guide](lead-guide.md)
- [Implementation brief](implementation-brief.md)
- [Live plan](plan.md)
- Numbered workstream packets and durable records
- [Whole-feature review](final-review.md)
- [Starter prompt](starter-prompt.md)

## Orchestrator responsibilities

Own branch/base recording, dependency order, cross-workstream decisions and the completion
report. Read only this README, plan.md and lead returns, not specifications, packets,
source diffs or findings. Only the orchestrator communicates with Aidan. Report at
acceptance, on escalation and at completion. Follow active harness communication requirements.

## Agent spawning

Use Codex `spawn_agent` with `fork_turns: "none"`; omit model and reasoning_effort.
Spawn a fresh lead per workstream, naming its instruction paths. Leads delegate implementation
and independent reviews. Use one long `wait_agent` call, capped at 60 seconds when required
by the active harness; resume the wait only for a confirmed running agent. Do not busy-poll
or schedule wake-ups. Inherit model and effort. No external review command is configured.

Run sequentially. No concurrent Swift builds, model inference or shared-file edits.
Do not start implementation while overlapping dirty changes lack recorded ownership.

## Start and orchestrator loop

1. Verify the approval recorded in plan.md and record the execution start date before handoff.
2. Reuse `feat/local-models-productionization`, already branched from the completed spike.
   Do not create a fresh branch from main or discard current trial work. If the checkout
   differs, resolve its state before switching. Record the actual branch and starting HEAD
   in plan.md. Do not commit the entire dirty tree merely to make it clean.
3. Existing overlapping trial changes go to the first relevant lead for explicit recovery
   and review, as recorded in the plan. Unrelated dirty changes remain untouched. The
   workflow does not regard trial work as accepted implementation.
4. Choose the next dependency-ready row and spawn its lead with the prompt below and
   the packet path. Do not paste packet content. Wait for Accepted or Blocked.
5. After all numbered rows are Accepted, start the final-review lead.

Leads write their own statuses, drift and escalations. Do not transcribe their returns.
The orchestrator writes only branch/base and user answers. Leads include those changes
in their next accepted commit. The terminal return is exactly:

```text
status: Accepted | Blocked
drift: one line, or none
escalation: plan.md escalation id, or none
```

On Blocked, read only the named plan escalation, obtain the user's decision, record it,
and start a fresh lead for the same packet. Never reinterpret an unanswered gate as approval.

## Lead prompts

For a numbered stream, replace N and the packet filename in this prompt:

```text
Lead workstream N of local models productionization.
Read docs/productionization/implementation/lead-guide.md,
docs/productionization/implementation/plan.md and the assigned numbered packet,
then the source documents the guide identifies. Run its execution and recovery procedures.
Reply with exactly:
status: Accepted | Blocked
drift: one line, or none
escalation: plan.md escalation id, or none
```

```text
Lead whole-feature review of local models productionization.
Read docs/productionization/implementation/lead-guide.md,
docs/productionization/implementation/plan.md and
docs/productionization/implementation/final-review.md, then the identified source documents.
Run final review and common lead procedures. Reply with exactly:
status: Accepted | Blocked
drift: one line, or none
escalation: plan.md escalation id, or none
```

## Interrupted recovery

Check each non-terminal agent once. Wait only for leads confirmed running. Otherwise
start a fresh lead with its packet and an instruction to recover under lead-guide.md.
A fresh orchestrator recovers status, dependency readiness, gates and decisions from plan.md.

## Completion report

Report delivered behavior, verification, external checks, drift and deferred observations.
Retire the bench in workstream 4 after its validation evidence is recorded. Do not merge
or publish a release as part of this workflow.
