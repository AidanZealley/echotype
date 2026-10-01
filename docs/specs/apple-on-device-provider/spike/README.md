# Apple provider spike workflow

Status: draft for review. Execution has not started.

This workflow investigates feasibility only. It ends with measured evidence and Aidan's recorded decision, before production implementation.

## Source of truth

Repository AGENTS.md instructions supplied by Aidan, the [feature specification](../../apple-on-device-provider.md), the [adapter decision](../../../decisions/0025-provider-adapters.md) and `Sources/EchoTypeCore/Providers/Provider.swift` govern the work. Product requirements override workflow packets. Leads read these sources, their packet and relevant code. The orchestrator reads only this README, [plan.md](plan.md) and lead returns, including the named escalation when blocked.

The acceptance gate is feature completeness and containment. All three services must be feasible on a supported, configured Mac. Quality below xAI is acceptable. xAI stays the default. Unavailable services may fall back as the specification describes; intentionally omitting cleanup is not approved.

## Roles and execution

The orchestrator owns the integration branch, dependency order and user decisions. A disposable lead owns each workstream from its frozen packet to acceptance. Its implementation agent owns experiments and targeted verification. A different, fresh reviewer independently assesses evidence and code. Reviewers do not edit experiments; they write only their review sections. Run sequentially. No agents edit the worktree concurrently.

At startup, confirm workflow approval, resolve overlapping dirty changes and create `spike/apple-on-device-provider` from the approved HEAD. Record the branch, starting commit, specification approval reference and start date in the plan before a lead starts. Do not commit unrelated work or discard the existing specification changes. If these documents are uncommitted, include their approved baseline in a setup documentation commit before recording the starting commit.

Read the plan and spawn the next lead with only its packet path using the lead prompt below. The lead writes its own status, drift and escalation. Read its return only to continue or stop; do not transcribe it into the plan. On Blocked, read the named escalation, surface it to Aidan, record the answer there and start a fresh lead. After all three streams are accepted, spawn the final-review lead.

Report to Aidan at workstream acceptance, on escalation and at completion. Do not narrate routine progress. A non-terminal row with no live lead is interrupted: spawn a fresh lead to audit and resume it.

## Agent spawning

All agents inherit model and effort. Codex uses `spawn_agent` with `fork_turns: "none"`, omitting model and reasoning effort. Wait in one long `wait_agent` call; do not busy-poll. Claude Code uses `Agent`, `subagent_type: general-purpose`, `run_in_background: false`, omitting model. If a wait returns early, handle messages or interruption before waiting again.

The tree is orchestrator → workstream lead → implementation agent, independent reviewer, one remediation agent if needed, fresh closure reviewer. After the streams, orchestrator → final-review lead → whole-spike reviewer, correction agents as needed, fresh closure reviewer. End each lead when it accepts or blocks. Reviews use lead subagents, not an external CLI.

## Lead loop and return

Update your row on each transition: Implementing → Review → Remediation if required → Closure review → Accepted or Blocked. Spawn implementation, then independent review. Triage findings as Required, Optional or Question. Required means an unmet criterion, real defect, containment violation or unjustified complexity. Optional never blocks unless the lead explicitly promotes it. Validate findings against the source of truth; reviewers provide evidence, not instructions.

Permit at most one remediation pass. It should simplify the affected approach rather than accumulate wrappers or exceptions. Use a fresh closure reviewer with the same brief to verify fixes and release-blocking defects, without restarting open-ended review. Persistent disagreement or a scope/architecture decision blocks to the orchestrator. No automatic third loop.

At acceptance, write the handoff, review, resolution and closure record, set the plan row, record lasting drift and make one commit containing experiments, evidence and those records. Follow the repository's plain-language subjects, ending with `(spike N)` or `(final spike review)`. Do not store accepted commit hashes in documents; git records them. Base commits and reviewed candidate references are allowed.

Return exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home before commit: status in the workstream table, drift in the decision and drift log, escalation in Escalations. The orchestrator writes only startup metadata and user answers. Those edits land before the next lead's commit.

## Lead prompt

```text
Lead the Apple provider spike workstream at the supplied packet path.
Read this workflow README, your packet, plan.md and the source-of-truth documents.
The task packet is frozen. Run the documented implementation, independent review,
one remediation if required and fresh focused closure loop. You own triage and acceptance.
Record all durable evidence in your packet and assigned specification results section.
Update your plan row and drift before making one acceptance commit.
You cannot reach the user. If external evidence needs Aidan, scope changes or disagreement
persists after closure, write a concise escalation with options, recommendation, evidence
and what it unblocks; set Blocked and leave work uncommitted.
On resume, audit inherited work, preserve the lasting user decision in your handoff and
plan drift log where relevant, and remove its resolved escalation.
Return exactly the documented status, drift and escalation fields.
```

Implementation prompt: read the packet and dependencies, implement only its experiments, run targeted checks, simplify, record evidence and limitations in Implementation handoff. Do not commit or change production behavior.

Review prompt: read the same packet and source of truth, inspect the complete workstream diff and relevant surrounding code, run proportionate checks, distinguish measured results from assumptions, and record Required, Optional and Question findings in Independent review. Do not edit implementation files.

Closure prompt: use that review brief in a fresh session, verify accepted findings and fixes for blockers, and write Closure review. Do not promote optional suggestions or reopen exhaustive review.

## Interrupted work recovery

Inspect the complete diff, confirm base and ownership of every change, and verify enough to establish what is complete. Reuse sound work and resume from the earliest unproven phase. Rerun undocumented evidence or incomplete review. Abandon work only if it has the wrong base, contradicts the packet, overlaps unrelated changes, cannot be attributed or is less safe to repair than restart. Preserve it in a named stash or recovery branch first. Escalate unclear ownership rather than overwrite it.

## Mac evidence gates

Real Apple measurements on Aidan's Mac are required before accepting each service spike. These results shape future implementation, so gather them before independent review. First determine whether the agent can run on that Mac through available tools. If not, prepare the opt-in candidate and exact commands, then block with a candidate reference, prerequisites, instructions and required output. Do not substitute fake measurements or infer framework behavior from docs.

Normal tests remain opt-in and disabled without `ECHOTYPE_APPLE_SPIKE=1`. Recording-based tests also require `ECHOTYPE_FIXTURE_WAV`; xAI comparison additionally requires `XAI_API_KEY`. Record OS, hardware, Swift/SDK, language, installed assets and Apple Intelligence state with measurements. Keep raw speech, logs and secrets outside the repo; commit concise summaries and synthetic cases only. Lack of a key does not prevent Apple-only tests, but any missing comparison evidence stays explicit.

Try framework experiments from SwiftPM first. If signed context or permissions are necessary, the owning lead may add a minimal opt-in experimental host inside its test ownership. It must supply exact build/sign/run instructions before the Mac gate. Do not add Apple test modes to the production app or alter its plist/entitlements in this spike. Record required production permission changes for the decision gate. Ask before removing assets, toggling system settings or replacing/launching a running app; prefer nondestructive observations. Do not use deploy/install scripts for these experiments.

For diagnostic failures, record the candidate and failure, make the smallest correction, run targeted checks and obtain new Mac evidence. These retries do not restart the review loop unless they change approved behavior, architecture, ownership, privileges, persistent data, public contracts or another accepted stream. Review meaningful unreviewed corrections once. Keep gate status Pending, Testing, Troubleshooting or Passed, separately from workstream status.

If Aidan must act or judge, record an escalation, return Blocked and leave the candidate uncommitted. Resume only with the required evidence or an explicit approved requirement change. Unsupported environment states cannot count as proof that a supported configuration works.

## Final review and decision gate

After all streams are accepted, spawn the final lead with [final-review.md](final-review.md). It reviews the assembled evidence and feature matrix against the starting commit, sends accepted corrections to fresh agents owning the relevant files, and runs focused closure. It follows the same return, escalation and commit rules.

The final decision requires Aidan's judgment after technical review and before final acceptance. Present the feasibility recommendation, limitations, proposed shared changes and provisional policies. Record his answer in the specification and durable handoff. If a required feature is infeasible, seek a decision rather than silently omit it. Completion means the investigation and decision are recorded, not necessarily that Apple was approved to ship. Never proceed into production work or generate its execution packets in this workflow.

## Final-review lead prompt

```text
Lead the final Apple provider spike review.
Read this README, final-review.md, plan.md and the source-of-truth documents.
All service streams are accepted. Spawn a fresh reviewer against the plan's starting commit.
Triage findings, send accepted corrections to fresh agents with explicit file ownership,
then run focused closure in a fresh review session using the same brief.
Complete the feature-feasibility matrix and recommendation. Block for Aidan's recorded
decision as the final gate requires, with concise options, evidence and a recommendation.
On resume, audit the candidate, record the lasting decision in the spec, handoff and plan,
remove the resolved escalation, set Final Accepted and make one acceptance commit.
Return exactly the documented status, drift and escalation fields.
```

The completion report states delivered experiments, measurements, verification, feature feasibility, Aidan's decision, drift and deferred optional observations. Identify any unresolved evidence and do not describe production features as implemented.
