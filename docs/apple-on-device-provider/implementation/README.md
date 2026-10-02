# Apple on-device provider implementation workflow

Status: implementation and whole-feature review accepted. G2's remaining external checks are pending by Aidan's 2026-10-02 decision. This file retains the workflow used for the accepted work.

This directory is the complete handoff for a fresh orchestration agent. It implements the approved [Apple on-device provider specification](../../specs/apple-on-device-provider.md).

## Source of truth

In order of precedence:

1. The [specification](../../specs/apple-on-device-provider.md). Product documents override workflow documents.
2. The [provider adapters decision](../../decisions/0025-provider-adapters.md) and the other records in [docs/decisions](../../decisions/README.md) it links.
3. The [feasibility research](../../research/apple-on-device-provider.md): measurements and reasoning behind the specification's policies. Supporting evidence only.
4. [plan.md](plan.md): status, contracts, escalations, conventions learned and drift.
5. The workstream's numbered file: its frozen task packet and record.

Workstream 6 deleted the spike experiments after the production adapters and tests replaced them. Git history retains the reference code.

## Roles

- **Orchestrator.** Long-lived and thin. Owns the integration branch, dependency order, spawning leads, cross-workstream decisions and the completion report. Reads only this README, `plan.md` and lead returns. Never reads the specification, a task packet, a diff or a finding.
- **Workstream lead.** One per workstream, disposable. Owns the workstream from frozen packet to accepted commit: spawns the implementation agent and reviewers, triages findings, orders at most one remediation pass, runs closure, writes the record and commits. Ends when it accepts or blocks. Cannot reach the user.
- **Implementation agent.** Reports to its lead. Reads the packet, dependency handoffs and the plan's conventions learned. Implements the smallest complete change, runs the packet's targeted verification, performs a deletion and simplification pass, and writes the Implementation handoff. Leaves defect hunting beyond the acceptance criteria to review.
- **Reviewer.** Fresh and independent of the implementation agent. Inspects the diff and surrounding code against the packet and conventions learned, runs proportionate checks, and writes only its own review section. Never edits implementation files. Findings are **Required** (a correctness defect, unmet acceptance criterion, boundary violation, meaningful regression or unjustified complexity), **Optional** (useful but non-blocking unless the lead promotes it) or **Question** (needs lead judgment).

```text
orchestrator
├── workstream lead (one per workstream, ends when it accepts or blocks)
│   ├── implementation agent
│   ├── independent reviewer
│   ├── implementation agent (one remediation pass)
│   └── closure reviewer (fresh session)
└── final-review lead (after the last acceptance)
    ├── whole-feature reviewer
    ├── implementation agent per owner (accepted corrections)
    └── closure reviewer (fresh session)
```

Agents never edit the shared worktree concurrently.

## Orchestrator loop

1. At the start, record the integration branch, starting commit, specification commit and date in `plan.md`.
2. Read `plan.md`. Spawn a lead for the next workstream whose dependencies are accepted, passing only its packet path in the [workstream lead prompt](#workstream-lead-prompt).
3. Read the return only to decide whether to continue or stop. The lead has already recorded it.
4. On `Blocked`, read only the named escalation entry in `plan.md`, put it to the user, record the answer in that entry, and spawn a fresh lead for the same workstream.
5. Repeat until every workstream is accepted, then spawn the final-review lead with the [final-review lead prompt](#final-review-lead-prompt).
6. Report whole-feature review results and pending external checks. Complete the remaining [G2 end checklist](plan.md#g2-end-checklist) after that review when Aidan is ready, then write the [completion report](#completion-report).

A row in a non-terminal state with no live lead is interrupted. Start a fresh lead for that workstream; it recovers the uncommitted work using [interrupted work recovery](#interrupted-work-recovery).

A usage limit, error or restart stops every agent in the tree. When the orchestrator resumes from anything other than a lead's return or the user's answer to an escalation, such as the user saying "continue", it checks each non-terminal row once, using the harness's agent status. It waits on a lead confirmed to be running and treats every other row as interrupted. This one check is not busy-polling. Leads apply the same rule to their own agents.

Report to the user at workstream acceptance, on an escalation, and in the completion report. Nothing else.

## Lead return contract

Every lead returns exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, which the lead writes before committing: status in the workstream table, drift in the decision and drift log, escalation in the escalations section. The orchestrator records none of them.

The orchestrator writes only the orchestration record at the start and the user's answer in an escalation entry. Each stays uncommitted until the next lead's commit picks it up.

## Agent spawning

Claude Code: use `Agent` with `subagent_type: general-purpose` and `run_in_background: false`. Omit `model`; agents inherit the orchestrator's model and effort. The call blocks until the agent returns.

No agent busy-polls another: no repeated short waits, no output checks on a running agent and no scheduled wake-ups.

## Branch and commit model

- One integration branch, `feature/apple-on-device-provider`, created from the approved HEAD. Its starting commit is recorded in `plan.md`.
- Implementation, review and remediation stay uncommitted so reviewers see one coherent diff.
- At acceptance the lead makes one commit containing the code, its record and its `plan.md` updates. Subject: a plain-language description followed by `(workstream N)`, or `(final review)`, for example `Gate operations on provider readiness (workstream 1)`.
- No document records an accepted workstream's commit hash.
- End each commit message with the actual contributing model. Codex commits in this workflow use `Co-Authored-By: GPT-6.1-Sol <noreply@openai.com>`.
- Respect unrelated dirty state: do not claim it or start a workstream over it. Escalate when ownership overlaps.

## Per-workstream loop

The lead runs these phases, updating its row in `plan.md` at each transition.

1. **Start.** Set the row to `Implementing`. Record the base commit in the handoff.
2. **Implementation.** Spawn a fresh implementation agent with the implementation prompt. It writes the Implementation handoff.
3. **Independent review.** Set `Review`. Spawn a different fresh agent with the review prompt. It writes the Independent review section.
4. **Remediation.** If any finding is accepted as Required, set `Remediation` and spawn one implementation agent to address exactly those findings. There is at most one remediation pass.
5. **Closure.** Set `Closure review`. Spawn a fresh reviewer with the same brief, limited to verifying accepted findings and checking their fixes for release-blocking defects. It does not restart open-ended review or promote optional items.
6. **External validation**, only where the packet has a pre-acceptance gate. See [external validation gates](#external-validation-gates). G2's remaining items follow whole-feature review and do not block workstream 6 acceptance.
7. **Accept and commit.** Write the Resolution and, where relevant, External validation sections. Set the row to `Accepted`, add drift and conventions learned, and make the one commit.

Every targeted verification command in the packet must pass before acceptance. A failure that reproduces on the base commit is pre-existing: record it in the handoff and continue. If a command still fails after closure, block.

The lead escalates only when disagreement persists after closure, when a decision materially changes approved behaviour or architecture, or when a gate needs the user. There is no automatic third loop.

### Implementation prompt

```text
Implement workstream <N> of the Apple on-device provider.

Read docs/apple-on-device-provider/implementation/README.md, plan.md (including conventions
learned and cross-workstream contracts), your packet <NN-name.md>, the handoffs of the
workstreams it depends on, and the specification sections the packet names.

Implement the smallest complete change that meets the acceptance criteria within the packet's
ownership. Match the surrounding code's style, naming and comment density. Run the packet's
targeted verification and add focused tests for the behaviour you add. Then do a deletion and
simplification pass: remove duplicated state, dead code and machinery added for hypothetical
failures.

Leave changes uncommitted. Write the Implementation handoff section of your packet: base,
changed files, decisions, verification results, limitations and any specification drift. Facts
for the next agent only, no diary.
```

For remediation, append: `Address only these accepted findings: <ids>. Revisit and simplify the affected design rather than adding wrappers, aliases, flags or special cases that preserve a flawed first version. Append your changes and verification to the handoff.`

### Review prompt

```text
Independently review workstream <N> of the Apple on-device provider.

Read docs/apple-on-device-provider/implementation/README.md, plan.md (including conventions
learned and cross-workstream contracts), the packet <NN-name.md> and its Implementation handoff,
and the specification sections it names. Inspect the uncommitted diff against the base commit in
the handoff, and the surrounding code.

Check the acceptance criteria, ownership and containment boundaries, lifecycle and cancellation,
test value, and unjustified complexity. Run the packet's targeted verification and any
proportionate extra check. Do not edit implementation files.

Write the Independent review section: verdict, Required findings, Optional observations and
Questions, each with file and line evidence.
```

The closure prompt is the review prompt with: `This is focused closure. Verify only that these accepted findings are resolved and that their fixes introduce no release-blocking defect: <ids>. Write the Closure review section.`

## Interrupted work recovery

A lead that finds its row already in a non-terminal state is recovering interrupted work:

1. Inspect the complete uncommitted diff and the record.
2. Confirm the base commit and that every change belongs to this workstream.
3. Run enough verification to establish the current state.
4. Continue from the earliest phase it cannot prove complete. Reuse sound work; rerun any undocumented conclusion or partial review.

Abandon partial work only when it cannot be safely attributed, uses the wrong base, contradicts the frozen packet, overlaps unrelated changes, or would be less safe to repair than restart. Preserve it first in a stash or branch named `recovery/apple-ws<N>-<date>`. When ownership is unclear, escalate rather than overwrite.

## External validation gates

Aidan is the only one who can judge visual taste, listen to voices and drive signed-app dictation on a real microphone. Gates and their placement are in [plan.md](plan.md#external-validation-gates).

A pre-acceptance gate that needs Aidan stops the lead:

1. After closure, record the candidate, instructions and required evidence in the packet's External validation section.
2. Add an escalation entry in `plan.md` naming the gate, set the row and gate status, leave the work uncommitted, and return `Blocked`.
3. A fresh lead inherits the work and Aidan's answer. If he reports problems, it runs a troubleshooting loop inside the workstream: record the failure, make the smallest correction, run proportionate checks, and publish another candidate through a new escalation. This does not change the workstream status or rerun implementation and review.
4. Reopen the normal loop only when a correction changes approved behaviour, architecture, ownership, a public contract or another accepted workstream.
5. After the gate passes, review meaningful unreviewed corrections once, record the final evidence and lasting decisions, remove the resolved escalation, and accept.

For G2, Aidan explicitly moved remaining items after whole-feature review. Record the existing passes and pending items in the plan's canonical end checklist. Accept WS6 on its reviewed implementation and recorded decision; accept Final on whole-feature review and closure. Neither acceptance claims full external verification. Complete the remaining checks afterward, using the final reviewed candidate.

Collapse superseded troubleshooting attempts once they no longer explain a decision.

## Final whole-feature review

After every workstream is accepted, the orchestrator spawns one final-review lead. It owns the Final row, follows the same return and escalation rules, and runs [final-review.md](final-review.md): a whole-feature review against the starting commit, owner-assigned corrections through fresh implementation agents, and focused closure.

## Completion report

The orchestrator reports:

- delivered outcomes,
- verification run,
- external validation passed and pending, including any gate items the final review's corrections require re-checking,
- specification drift,
- deferred optional observations.

## Workstream lead prompt

```text
Lead workstream <N> of the Apple on-device provider.

Read docs/apple-on-device-provider/implementation/README.md and <NN-name.md>, then the
source-of-truth documents the README identifies. The task packet is frozen except for recorded
user-authorized amendments, including G2's remaining checks moving after whole-feature review.

Run the documented loop yourself: spawn a fresh implementation agent, spawn a different fresh
agent for independent review, triage the findings, order at most one remediation pass, then run
focused closure in a fresh review session using the same brief before accepting.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions. Every
targeted verification command must pass before you accept, unless the failure reproduces on your
base commit.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, add a line to conventions learned for
any Required finding or user feedback later workstreams are likely to repeat, and make one commit
containing the code, the record and the plan updates. The orchestrator does not record lead
return fields, so anything worth keeping must be in that commit.

You cannot reach the user. Block if a decision materially changes approved behavior or
architecture, if disagreement persists after closure, or if an external validation gate needs the
user at its recorded placement. G2's pending end checks do not block acceptance. To block, add
an escalation entry to plan.md giving the decision needed, the options, your
recommendation, the evidence and what it unblocks, set your row to Blocked, leave the work
uncommitted, and return its id. Summarise; do not paste findings or diffs.

If you are resuming a blocked workstream, the uncommitted work and the answered escalation entry
are yours. Before you accept, copy its lasting decision into your handoff Decisions field, and
into the plan's decision and drift log when later workstreams depend on it, then remove the
entry.

If your row is already in a non-terminal state, you are recovering interrupted work. Follow the
README's interrupted work recovery rules before continuing.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of the Apple on-device provider.

Read docs/apple-on-device-provider/implementation/README.md and final-review.md, then the
source-of-truth documents the README identifies. Every workstream is accepted; the branch is
ready for code review; the plan's G2 end checklist still has pending external checks.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in the
plan. Triage its findings, send each accepted correction to a fresh implementation agent owning
the relevant files, then run focused closure in a fresh review session using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions. Every
verification command in final-review.md must pass before you accept, unless the failure
reproduces on the starting commit.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to Accepted,
add any specification drift to the plan's decision and drift log, and make one commit containing
the corrections, the record and the plan updates.

You cannot reach the user. Block the same way a workstream lead does: add an escalation entry to
plan.md, set the Final row to Blocked, leave the work uncommitted, and return its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```
