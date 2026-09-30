# EchoType macOS rewrite implementation workflow

Status: draft. Prepare for execution on Aidan's local Mac; implementation has not started.

## Source of truth

Repository and global `AGENTS.md` instructions apply. Workstream leads, implementers and reviewers read the [specification](../macos-rewrite.md), relevant [decision records](../../decisions/README.md), [repository README](../../../README.md), [plan](plan.md) and assigned packet. The specification overrides workflow documents. The numbered packet's Task packet is frozen after workflow approval; agents write only its record sections.

The orchestrator reads only this README, `plan.md` and lead returns. It never reads the specification, packets, diffs or findings. On a Blocked return it reads the named escalation entry in the plan. Leads own detailed interpretation and evidence; the orchestrator routes cross-workstream decisions and user input from their summaries.

## Roles and spawning

- Orchestrator: owns the integration branch, starting commit, order, spawning and completion report.
- Disposable workstream lead: owns implementation, independent review, finding triage, at most one remediation pass, closure, records and one accepted commit.
- Implementation agent: implements its assigned files, performs targeted checks and simplification, and writes its implementation handoff. It does not commit.
- Fresh review agent: reads the diff and relevant context, runs proportionate checks and writes its assigned review section. It edits no implementation files.

Execute sequentially. Before spawning, assign file and state ownership. Never have agents edit this shared worktree concurrently. Implementation and review agents inherit model and reasoning effort.

| Harness | Rule |
|---|---|
| Codex | Use `spawn_agent` with `fork_turns: "none"`; omit model and reasoning-effort overrides. Wait with one long `wait_agent` call, measured in minutes. |
| Claude Code | Use blocking `Agent` with `subagent_type: general-purpose` and `run_in_background: false`; omit model. |

Every spawn uses a path to its packet rather than pasted packet contents. Do not poll, request routine status from running agents or schedule wake-ups to check completion. If a blocking wait times out, wait again without polling or reconstructing the agent's work. Follow higher-priority harness requirements for user updates.

## Orchestrator loop

1. Confirm workflow approval in the plan. If it remains draft, request approval of these concrete documents before execution.
2. On the Mac, confirm a clean integration base. The planning documents may already be committed; if they remain uncommitted, include only these authorised documents in a preparation commit before recording the base. Unrelated or overlapping changes require an ownership decision, never automatic stashing or deletion. Create `refactor/macos-lifecycle` unless it is already the recorded integration branch. Record branch, starting commit, specification-approval reference and start date once.
3. Read the plan and spawn a workstream lead for the next dependency-ready row using the lead prompt below. Pass only the packet path. Wait for the lead to return.
4. Read its three-field return only to decide continue or stop. The lead already recorded status, drift and escalation; the orchestrator must not transcribe them or dirty the accepted tree.
5. Report acceptance and continue. On Blocked, read only the named plan escalation, surface its decision or external check to Aidan, write the answer in that entry and start a fresh lead for the same row.
6. A non-terminal row with no live lead is interrupted. An Accepted row is durable only when the committed HEAD version of `plan.md` also records it as Accepted. Read that version with `git show HEAD:docs/specs/macos-rewrite-implementation/plan.md`; do not inspect diffs. If acceptance exists only in the working plan, restart that lead to recover the pending acceptance commit. Never start its dependent row first.
7. After rows 1 through 6 are durably Accepted, spawn the final-review lead. After Final is durably Accepted, report delivered outcomes, verification, external checks still pending, drift and deferred optional observations from the plan's Completion summary.

Report to Aidan at workstream acceptance, on escalation and at completion. Do not narrate routine progress. `plan.md` is the live status channel.

## Lead return and durable state

Return exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home, written by the lead: status in the workstream table, drift in the decision and drift log, escalation in the escalations section. The orchestrator writes only its initial orchestration fields and user answers in escalation entries. These writes land before the next lead's acceptance commit.

When blocking, write a short escalation containing the decision needed, realistic options, recommendation, evidence, what it unblocks and the user's-answer field. Set the row to Blocked and leave work uncommitted. A lead has no user channel. On resumption, preserve the lasting answer in the handoff and, if downstream work relies on it, the decision log; remove the resolved escalation before acceptance.

## Implementation and review loop

```text
implementation -> independent review -> one remediation pass if required
               -> focused closure review -> accept or Blocked
```

The lead updates its plan row at each transition. Each agent records concise facts in the numbered file, without raw logs or chronological diaries. The lead records base, changed files, decisions, commands/results, limitations and drift before acceptance.

Classify findings as Required, Optional or Question. Required means a real defect, unmet criterion, boundary violation, meaningful regression or unjustified complexity blocking acceptance. Optional never blocks unless the lead explicitly promotes it with a scope-based reason. The lead validates findings and records accepted/rejected dispositions. Persistent disagreement or a material change to approved behavior/architecture becomes an escalation.

Remediation revisits the affected design and removes flawed first-pass machinery. It must not accumulate wrappers, flags, aliases or compatibility layers solely to appease a finding. Closure uses a fresh reviewer, the same brief and inherited configuration. It checks accepted findings and release-blocking defects introduced by fixes, without restarting broad review or promoting optional observations. There is no automatic third loop.

Implementation prompt:

```text
Read the workflow README, your assigned packet and its source-of-truth documents.
Implement only the frozen packet's scope in its owned files. Inspect dependency handoffs.
Run its targeted checks and new focused tests, simplify/delete obsolete code, and write
Implementation handoff. Leave all work uncommitted. Raise contract defects to your lead.
```

Independent review prompt:

```text
Read the workflow README, assigned packet, approved spec and dependency handoffs.
Independently inspect the complete workstream diff and surrounding code. Verify acceptance,
lifecycle, boundaries, meaningful tests and simplification. Record Required, Optional and
Question findings with evidence in Independent review. Do not edit implementation files.
```

Closure prompt:

```text
Use the same packet, spec and reviewer brief in this fresh session. Read the accepted
findings and resolutions. Verify their fixes and check for release-blocking defects those
fixes introduced. Write Closure review. Do not restart broad review or promote optional work.
```

## Branches, commits and recovery

Use one integration branch. Keep each slice uncommitted through implementation, review, remediation and validation. At acceptance the lead makes one commit containing code, its complete record and plan updates. Follow the repository's plain-language commit subjects and append `(workstream N)`; final review uses `(final review)`. Never put an accepted workstream's commit hash in documents. Base and reviewed-head evidence is allowed.

A recovering lead inspects the complete diff, confirms its base and every changed file's ownership, runs enough checks to establish what exists, then continues from the earliest phase it cannot prove complete. Reuse sound work. Rerun partial or undocumented review conclusions. Do not reset the remediation limit simply by spawning a new lead; the durable record shows passes already used.

If acceptance was recorded but its commit was interrupted, verify the recorded review, closure, gates and file ownership, then finish the one acceptance commit. Reopen only phases whose completion cannot be established. A committed Accepted row needs no repeated review merely because its lead's return was interrupted.

Abandon work only if attribution is unsafe, the base is wrong, it contradicts the packet, overlaps unrelated changes or repair is less safe than restarting. Preserve it in a named recovery branch or stash first. Unclear ownership escalates instead of overwriting. Do not claim unrelated changes in a workstream commit.

## External validation gates

The plan names gate owners, placement and resume conditions. On a gate requiring Aidan, the lead records the candidate, exact actions and required evidence, writes an escalation and returns Blocked. The row stays Blocked and work stays uncommitted. A fresh lead resumes from the answer and audits the candidate.

Gates that shape implementation run before independent review. Gates that verify a finished candidate run after closure and before acceptance. A candidate is identified by branch/base and a concise description of the uncommitted state; do not invent an accepted commit hash.

If the lead can retry a gate itself, keep its workstream phase while recording a troubleshooting attempt, making the smallest correction, running proportionate checks and retesting. Diagnostic retries do not restart the implementation/review loop. Reopen review when corrections change approved behavior, architecture, ownership, privilege/security boundaries, persistent data, public contracts or an accepted dependency. Review meaningful unreviewed changes once after the gate passes. Collapse superseded attempts while preserving failures that explain lasting decisions.

The Mac can run compile/tests, signing and some interaction checks when available. Microphone/Accessibility grants, physical Bluetooth or disconnect checks, editor interaction and live xAI requests may need Aidan. Do not access the real API key or run billed live tests merely to satisfy a gate. Default to fake network data for deterministic tests. User permission for live testing is a separate gate.

`./scripts/run.sh` is the existing development launcher and quits every running EchoType copy. Before invoking it, name that impact to Aidan. Prefer building with `./scripts/build-app.sh debug .build/EchoType-workflow.app` and handing off the candidate when session interruption is undesirable. Do not run `install.sh`, replace `/Applications/EchoType.app` or touch live/production environments for this workflow.

## Workstream lead prompt

```text
Lead the workstream identified by the supplied packet path.
Read this workflow README, that packet and its source-of-truth documents. The Task packet
is frozen. Recover interrupted work according to the README, including an uncommitted Accepted row.
Spawn a fresh implementer, a different independent reviewer, at most one remediation pass,
and a fresh closure reviewer using the documented briefs. You own triage and acceptance.
Run the packet's external gates at their stated placement. Findings are evidence, not orders.
At acceptance, complete your record, update your row/drift in plan.md, resolve answered
escalations into durable decisions and make one commit containing code and records.
You cannot reach the user. Block for a user gate, material scope/contract change or persistent
disagreement; write a concise plan escalation, leave work uncommitted and return its id.
Return exactly the README's three fields and nothing else.
```

## Final-review lead prompt

```text
Lead the whole-feature review using final-review.md.
Read this README, that packet and its source-of-truth documents. All numbered rows are Accepted.
Spawn a fresh whole-feature reviewer against plan.md's starting commit. Validate/triage findings,
assign accepted corrections to fresh implementers with explicit sequential file ownership,
then run fresh focused closure. Use the same review configuration and brief.
Run the final external gate. Own the Final row, final-review.md, escalation and drift records.
Write the plan's Completion summary with outcomes, verification, limits and deferred observations.
Commit accepted corrections and records once. Block through plan.md when required, leaving
work uncommitted. Return exactly the README's three fields and nothing else.
```

## Completion

Final acceptance requires all numbered rows, Final and mandatory validation gates to pass. Report concrete implemented behavior, tested evidence, limitations, approved drift and deferred Optional findings. If a required Mac check is unavailable, record a gate and remain Blocked rather than claiming the rewrite complete.
