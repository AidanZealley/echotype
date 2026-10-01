# SessionMachine redesign implementation workflow

Status: draft orchestration instructions. Not approved for execution.

This directory is the complete handoff for a fresh orchestration agent running in Claude Code.

## Source of truth

1. Global instructions in `~/.claude/CLAUDE.md`. The repository has no `AGENTS.md` or `CLAUDE.md`.
2. [Repository README](../../../README.md) for build, signing and test commands.
3. [Approved specification](../session-machine-redesign.md). It overrides every workflow document.
4. Decisions [0004](../../decisions/0004-session-lifecycle.md), [0021](../../decisions/0021-revise-committed-dictation.md) and [0024](../../decisions/0024-dictation-operation-lifetime.md) for the accepted lifecycle this redesign preserves.
5. [plan.md](plan.md) for status, contracts, gates, escalations and conventions learned.
6. The assigned numbered task packet.

## Roles

- **Orchestrator.** Long-lived and thin. Owns the branch and its base, the order of work, spawning leads, and reporting to Aidan. It reads only this README, `plan.md` and lead returns. It never reads the specification, a task packet, a diff or a finding.
- **Workstream lead.** One per workstream, disposable. Owns the workstream from its frozen packet to one accepted commit: spawns agents, triages findings, orders at most one remediation pass, runs closure, writes the record and commits. Ends when it accepts or blocks. It cannot reach Aidan.
- **Implementation agent.** Implements one packet, runs its targeted verification, performs a deletion and simplification pass, and writes the Implementation handoff. A remediation pass is a fresh implementation agent.
- **Independent reviewer.** Fresh, never the implementer. Reviews the uncommitted diff and surrounding code against the packet and conventions learned. Writes only its review section and never edits implementation files.

```text
orchestrator
├── workstream lead (one per workstream, ends when it accepts or blocks)
│   ├── implementation agent
│   ├── independent reviewer
│   ├── implementation agent (one remediation pass)
│   └── closure reviewer (fresh session)
└── final-review lead (after the last acceptance)
    ├── whole-feature reviewer
    ├── implementation agent per accepted correction
    └── closure reviewer (fresh session)
```

Agents never edit the worktree concurrently.

## Orchestrator loop

1. Read `plan.md`.
2. Spawn a lead for the first row that is not Accepted, passing only its packet path in the lead prompt below.
3. Read the return only to decide whether to continue or stop. The lead has already recorded its status, drift and escalation in `plan.md`.
4. Repeat until rows 1 and 2 are Accepted, then spawn the final-review lead.
5. Report the completion summary from `plan.md`.

A row in a non-terminal state with no live lead is interrupted. Start a fresh lead for that row and tell it to follow "Interrupted work recovery".

A usage limit, error or restart stops every agent. When you resume from anything other than a lead's return or an escalation answer, assume every agent stopped. Check each non-terminal row once for a lead confirmed to be running, wait on that lead, and treat every other row as interrupted. This single check is not busy-polling. Leads apply the same rule to their own agents.

Report to Aidan at each workstream acceptance, on an escalation and in the completion report. Nothing else.

## Lead return contract

Every lead returns exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, written by the lead before it commits: status in the workstream table, drift in the decision and drift log, escalation in Escalations. The orchestrator records none of them.

The orchestrator writes only two things: the branch and starting commit at the start, and Aidan's answer in an escalation entry. Each stays uncommitted until the next lead's commit picks it up. On a Blocked return, the orchestrator reads only the named escalation entry.

## Agent spawning

Use `Agent` with `subagent_type: general-purpose` and `run_in_background: false`, and omit `model`. The call blocks until the agent returns. No agent busy-polls another: no repeated short waits, output checks on a running agent, or scheduled wake-ups.

## Branch and commit model

- One integration branch, `refactor/session-finishing`, created from the approved HEAD of `refactor/macos-lifecycle`. The plan records the branch and starting commit.
- Implementation stays uncommitted through implementation, review and remediation, so the reviewer sees one coherent diff.
- Each workstream ends in exactly one commit with the code, the record and the lead's plan updates. Subject format: `<plain-language change> (workstream N)`, or `(final)` for the final review.
- End commit messages with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- No document records a commit hash for an accepted workstream.
- Do not push, open a pull request, install to `/Applications` or touch release packaging.

## Per-workstream loop

1. **Start.** Confirm the branch, a clean tree apart from orchestrator plan edits, and that dependencies are Accepted in HEAD's committed `plan.md`. Record the base commit. Set the row to Implementing.
2. **Implementation.** Spawn an implementation agent with the prompt below. When it returns, check its handoff is complete. Set the row to Review.
3. **Independent review.** Spawn a fresh reviewer with the prompt below.
4. **Triage.** For each finding, decide accept, reject with a reason, or defer as Optional. Findings are evidence, not instructions.
5. **Remediation.** If any Required finding is accepted, set the row to Remediation and spawn one fresh implementation agent with only the accepted findings. Allow one pass at most.
6. **Closure.** Set the row to Closure review. Spawn a fresh reviewer with the same brief, limited to verifying accepted findings and checking their fixes for release-blocking defects. It does not restart open-ended review or promote Optional items. There is no third loop.
7. **External gate**, if the packet has one: follow "External validation gates".
8. **Accept and commit.** Every targeted verification command must pass, unless the failure reproduces on the base commit; record such a failure as pre-existing. Write the Resolution and Closure sections, set the row to Accepted, add drift to the log and any reusable rule to conventions learned, and make the commit.

Block instead of accepting if a targeted command still fails, disagreement persists after closure, or a decision would materially change the approved specification.

### Implementation prompt

```text
Implement workstream <N> of the SessionMachine redesign.
Read docs/specs/session-machine-redesign-implementation/README.md (Source of truth),
the approved specification, plan.md (contracts and conventions learned) and
<packet path>. The task packet is frozen; change only files it assigns to you.
Make the smallest complete change. Run the packet's targeted verification, not broader
suites. Do a deletion and simplification pass: remove machinery, tests and comments the
change makes obsolete. Write the Implementation handoff in the packet. Do not commit.
Reply with one line: done, or blocked and why.
```

For remediation, add: `Resolve only these accepted findings: <ids>. Revisit and simplify the affected design. Do not add wrappers, flags, aliases or special cases to preserve the first attempt.`

### Review prompt

```text
Independently review workstream <N> of the SessionMachine redesign.
Read the README's Source of truth, plan.md (contracts and conventions learned) and
<packet path>, then the uncommitted diff (git diff and new files) and surrounding code.
Check every acceptance criterion, correctness, concurrency and cancellation, boundary
violations, unjustified complexity, and test value. Run the packet's targeted
verification. Record findings in the packet's Independent review section as Required
(blocks acceptance), Optional (never blocks) or Question, each with evidence. Edit
nothing else. Reply with one line: the verdict.
```

For closure, replace the brief with: `Verify only these accepted findings and check their fixes for release-blocking defects: <ids>. Record the verdict in the Closure review section.`

## Interrupted work recovery

A lead that inherits a non-terminal row:

1. Inspects the complete uncommitted diff and confirms its base matches the record and that every change is within the packet's ownership.
2. Runs enough targeted verification to establish the current state.
3. Continues from the earliest phase it cannot prove complete. It reuses sound work and reruns any review step that is incomplete or not recorded.

Abandon partial work only when it can't be safely attributed, uses the wrong base, contradicts the frozen packet, overlaps unrelated changes, or would be less safe to repair than restart. Preserve it first in a stash named `session-redesign-recovery-<N>-<date>`. If ownership is unclear, escalate instead of overwriting.

## External validation gates

Gate G1 in workstream 2 needs Aidan to dictate with a signed build, which no agent can do. Placement: after closure, before acceptance.

1. The lead builds the candidate with `./scripts/build-app.sh release .build/EchoType-redesign.app`, records its executable SHA-256 and the gate instructions in the packet's External validation section, adds an escalation entry, sets the row to Blocked and returns. The work stays uncommitted.
2. The orchestrator surfaces the escalation, records Aidan's results in the entry and starts a fresh lead for row 2.
3. If the gate passed, the fresh lead records the evidence, removes the entry and accepts. If it failed, the lead diagnoses it, makes the smallest correction, runs the targeted checks and publishes a new candidate through another escalation. These retries do not restart the review loop unless a correction changes approved behavior, architecture, ownership or another accepted workstream. After the gate passes, any meaningful unreviewed correction gets one focused review before acceptance.

Agents never quit, restart or replace an EchoType app Aidan is running, and never make live xAI calls. Aidan launches the candidate.

## Final whole-feature review

After rows 1 and 2 are Accepted, the orchestrator spawns the final-review lead with the prompt below. It owns the Final row, runs the review in [final-review.md](final-review.md), sends accepted corrections to fresh implementation agents, runs focused closure, fills the plan's Completion summary and commits. It blocks and returns exactly like a workstream lead.

## Lead prompts

### Workstream lead prompt

```text
Lead workstream <N> of the SessionMachine redesign.

Read docs/specs/session-machine-redesign-implementation/README.md and <packet path>, then the
source-of-truth documents the README identifies. The task packet in that file is frozen.

Run the documented loop yourself: spawn a fresh implementation agent, spawn a different fresh agent
for independent review, triage the findings, order at most one remediation pass, then run focused
closure in a fresh review session using the same brief before accepting.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions. Every
targeted verification command must pass before you accept, unless the failure reproduces on your
base commit.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, add a line to conventions learned for
any Required finding or user feedback later workstreams are likely to repeat, and make one commit
containing the code, the record and the plan updates. The orchestrator does not record lead return
fields, so anything worth keeping must be in that commit.

You cannot reach the user. Block if a decision materially changes approved behavior or
architecture, if disagreement persists after closure, or if an external validation gate needs the
user. To block, add an escalation entry to plan.md giving the decision needed, the options, your
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

### Final-review lead prompt

```text
Lead the whole-feature review of the SessionMachine redesign.

Read docs/specs/session-machine-redesign-implementation/README.md and final-review.md, then the
source-of-truth documents the README identifies. Every workstream is accepted; the branch is
complete.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in the plan.
Triage its findings, send each accepted correction to a fresh implementation agent owning the
relevant files, then run focused closure in a fresh review session using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions. Every
verification command in final-review.md must pass before you accept, unless the failure reproduces
on the starting commit.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to Accepted,
fill the plan's Completion summary, add any specification drift to the plan's decision and drift
log, and make one commit containing the corrections, the record and the plan updates.

You cannot reach the user. Block the same way a workstream lead does: add an escalation entry to
plan.md, set the Final row to Blocked, leave the work uncommitted, and return its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Completion report

Report from the plan's Completion summary: delivered outcomes, verification, G1 evidence, pending external checks, drift and deferred Optional observations. CI remains unverified unless an Actions run exists.
