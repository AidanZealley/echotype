# Provider adapters implementation workflow

Status: draft orchestration instructions, awaiting Aidan's approval. Execute on Aidan's Mac; implementation has not started.

This directory is the complete handoff for a fresh orchestration agent.

## Source of truth

Repository instructions and Aidan's global agent instructions apply. Workstream leads, implementation agents and reviewers read:

- the [approved specification](../provider-adapters.md)
- the [decision records](../../decisions/README.md) their packet names
- the [repository README](../../../README.md)
- the [plan](plan.md) and their assigned packet

The specification overrides the workflow documents. Each numbered file's Task packet is frozen once the workflow is approved; agents write only its record sections.

The orchestrator reads only this README, `plan.md` and lead returns. It never reads the specification, packets, diffs or findings. On a Blocked return it reads only the escalation entry the lead names.

## Roles

| Role | Owns |
|---|---|
| Orchestrator | The integration branch and its starting commit, dependency order, spawning leads, cross-workstream decisions and the completion report |
| Workstream lead | One workstream, from frozen packet to accepted commit: interpretation, spawning, triage, at most one remediation pass, closure, record and commit. Ends when it accepts or blocks |
| Implementation agent | The packet's scope in its owned files, targeted checks, a deletion and simplification pass, and the Implementation handoff. Does not commit |
| Review agent | A fresh, independent read of the diff and surrounding code, proportionate checks and its assigned review section. Edits no implementation files |

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

Work is sequential. Agents never edit the shared worktree concurrently.

## Agent spawning

| Harness | Rule |
|---|---|
| Claude Code | `Agent` with `subagent_type: general-purpose` and `run_in_background: false`. Omit `model`. |
| Codex | `spawn_agent` with `fork_turns: "none"`. Omit `model` and `reasoning_effort`. Wait with one long `wait_agent` call measured in minutes. |

Every agent inherits the spawning agent's model and reasoning effort. Each spawn passes a packet path, never pasted packet or record content. Wait for each agent in one blocking call. Do not busy-poll, ask a running agent for status or schedule wake-ups. If a blocking wait times out, wait again.

## Orchestrator loop

1. Confirm the plan records workflow approval. If it doesn't, ask Aidan to approve these documents before starting.
2. Confirm a clean worktree. If the specs and this directory are still uncommitted, commit only those documents as a preparation commit. Unrelated or overlapping changes need Aidan's decision; never stash or delete them automatically. Create `refactor/provider-adapters` from that commit, and record the branch, starting commit and start date in the plan.
3. Read the plan and spawn a lead for the next dependency-ready row with the [workstream lead prompt](#workstream-lead-prompt), passing only its packet path.
4. Read the lead's three-field return only to decide whether to continue or stop.
5. On Accepted, report the acceptance to Aidan in one line and continue. On Blocked, read only the named escalation entry, put its question to Aidan, write the answer in that entry and spawn a fresh lead for the same row.
6. After rows 1 to 5 are durably Accepted, spawn the final-review lead with the [final-review lead prompt](#final-review-lead-prompt). After Final is durably Accepted, report from the plan's Completion summary: delivered behaviour, verification, external checks still pending, drift and deferred optional observations.

An Accepted row is durable only when the committed plan also says Accepted. Check with `git show HEAD:docs/specs/provider-adapters-implementation/plan.md`. A row that is Accepted only in the working plan, or is in any other non-terminal state with no live lead, is interrupted work. Spawn a fresh lead for that row to recover it, and never start a dependent row first.

Report to Aidan only at workstream acceptance, on an escalation and at completion. `plan.md` is the live status channel.

## Lead return contract

Every lead returns exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in the plan, written by the lead before it commits:

- status in the workstream table
- drift in the decision and drift log
- escalation in the escalations section

The orchestrator records none of them. It writes only the orchestration record at the start and Aidan's answers in escalation entries; the next lead's commit picks those writes up.

To block, a lead writes an escalation entry holding the decision needed, realistic options, its recommendation, the evidence, what it unblocks and an empty User's answer. It sets its row to Blocked, leaves the work uncommitted and returns the entry id. Leads have no channel to Aidan.

A lead resuming a blocked row inherits the uncommitted work and the answered entry. Before accepting, it copies the lasting decision into its handoff, and into the decision and drift log when later rows depend on it, then removes the entry.

## Branch and commit model

- Integration branch: `refactor/provider-adapters`, from the commit recorded in the plan.
- Each workstream stays uncommitted through implementation, review, remediation and its gate, so reviewers see one coherent diff.
- At acceptance the lead makes one commit containing the code, its complete record and its plan updates. Use a plain-language subject ending in `(workstream N)`; the final review uses `(final review)`.
- No document records an accepted workstream's commit hash. Base and reviewed-head references in records are fine.
- Do not push or open a pull request; Aidan decides that after completion.

## Per-workstream loop

```text
implementation
    -> independent review
    -> one remediation pass if required
    -> focused closure review
    -> external gate, when the packet has one
    -> accept, or return Blocked
```

The lead updates its plan row at each transition: Implementing, Review, Remediation, Closure review, then Accepted or Blocked.

Findings are Required, Optional or Question:

- **Required:** a correctness defect, unmet acceptance criterion, boundary violation, meaningful regression or unjustified complexity. Blocks acceptance.
- **Optional:** useful but out of scope or nonessential. Never blocks unless the lead promotes it with a scope-based reason.
- **Question:** an ambiguity the lead must judge before classifying.

Findings are evidence, not instructions. The lead validates each one and records its disposition. Remediation revisits and simplifies the affected design; it must not add wrappers, aliases, flags or compatibility paths only to satisfy a finding. Closure runs in a fresh session with the same brief and checks accepted findings and release-blocking defects introduced by their fixes. It does not restart broad review or promote optional items. There is no automatic third loop. The lead escalates only when disagreement persists after closure or a decision materially changes approved behaviour or architecture.

Records hold facts the next agent needs, not diaries or pasted tool output.

Implementation prompt:

```text
Read the provider adapters workflow README, your assigned packet and the source-of-truth
documents they name. Implement only the frozen packet's scope in its owned files, using
earlier workstreams' handoffs. Run its targeted verification plus any focused tests you add,
do a deletion and simplification pass, and write the Implementation handoff. Leave all work
uncommitted. Raise contract defects to your lead instead of working around them.
```

Independent review prompt:

```text
Read the provider adapters workflow README, the assigned packet, the approved specification
and earlier workstreams' handoffs. Independently inspect the complete uncommitted diff and the
code around it. Check acceptance criteria, contracts, lifecycle, dependency direction,
meaningful tests and simplification. Record Required, Optional and Question findings with
evidence in Independent review. Do not edit implementation files.
```

Closure prompt:

```text
In this fresh session, use the same packet, specification and reviewer brief. Read the accepted
findings and their resolutions. Verify the fixes and check for release-blocking defects they
introduced. Write Closure review. Do not restart broad review or promote optional observations.
```

## Interrupted work recovery

A lead that inherits a non-terminal row:

1. Inspects the complete diff, confirms its base is the previous accepted commit and attributes every changed file to this workstream's ownership.
2. Runs enough targeted checks to establish what works.
3. Continues from the earliest phase the record cannot prove complete. It reuses sound work and reruns any partial or undocumented review.

The record shows remediation passes already used; a new lead does not reset the limit. If acceptance was recorded but the commit didn't happen, verify the recorded review, closure and gate, then make the one acceptance commit.

Abandon partial work only when it cannot be safely attributed, uses the wrong base, contradicts the frozen packet, overlaps unrelated changes or is less safe to repair than to restart. Preserve it first in a stash or branch named `recovery/provider-adapters-wsN`. Escalate when ownership is unclear rather than overwriting.

## Verification commands

Run on the Mac. Live xAI tests stay disabled by clearing their variables:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SessionMachine'
swift build --product EchoTypeApp
git diff --check
```

- Many tests are top-level functions, so find the identifiers a packet needs with `swift test list` and record the exact filter used.
- The complete deterministic suite is `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test`, and the release check is `swift build -c release --product EchoTypeApp`. Workstreams run targeted filters; the final review runs both.
- A signed candidate for a gate is built with `./scripts/build-app.sh debug .build/EchoType-workflow.app`.
- `./scripts/run.sh` quits every running EchoType, including Aidan's installed copy. Don't run it.
- Don't run `install.sh` or replace `/Applications/EchoType.app`.

## External validation gates

Gates are listed in the plan, with their owner, placement and resume condition. Each one needs Aidan to run a signed candidate on the Mac, using Aidan's real key and paid xAI requests. Agents don't read the Keychain key or run live xAI tests themselves.

At a gate, the lead:

1. Builds the candidate after closure.
2. Records in its External validation section the candidate (branch, base and a short description of the uncommitted state), the exact steps for Aidan and the evidence needed.
3. Writes an escalation entry and returns Blocked.

The fresh lead that resumes reads Aidan's answer:

- **Pass.** It records the evidence and accepts.
- **Failure.** It enters a troubleshooting loop without changing the row's phase: record the failure, make the smallest correction, run targeted checks, and present a new candidate through another escalation.

Reopen the review loop only if a correction changes approved behaviour, architecture, ownership, persistent data, a public contract or an accepted workstream. Otherwise, review meaningful unreviewed corrections once after the gate passes. Collapse superseded attempts and keep only failures that explain a lasting decision.

The candidate shares the installed app's bundle identifier, so it reads the same Keychain item and `UserDefaults`. Before a gate that runs settings migration, the lead tells Aidan that the candidate rewrites stored settings in the new format.

## Final whole-feature review

After rows 1 to 5 are Accepted, one final-review lead runs [final-review.md](final-review.md). It is a lead in every respect: it owns the Final row, spawns a fresh whole-feature reviewer, triages findings, sends each accepted correction to a fresh implementation agent owning the affected files, runs focused closure in a fresh session and runs gate G3. It writes the plan's Completion summary, makes one commit, blocks through an escalation and returns the same three fields.

## Workstream lead prompt

```text
Lead workstream <N> of the provider adapters implementation, packet <path to NN-*.md>.

Read docs/specs/provider-adapters-implementation/README.md and that packet, then the
source-of-truth documents the README identifies. The task packet is frozen.

Run the documented loop yourself: spawn a fresh implementation agent, spawn a different fresh
agent for independent review, triage the findings, order at most one remediation pass, then
run focused closure in a fresh review session using the same brief. Run the packet's external
gate at its stated placement.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, and make one commit containing the
code, the record and the plan updates. The orchestrator records nothing from your return, so
anything worth keeping must be in that commit.

You cannot reach the user. Block if a decision materially changes approved behaviour or
architecture, if disagreement persists after closure, or if a gate needs Aidan. To block, add an
escalation entry to plan.md with the decision needed, options, your recommendation, the
evidence and what it unblocks; set your row to Blocked, leave the work uncommitted and return
its id. Summarise; do not paste findings or diffs.

If you are resuming a blocked workstream, the uncommitted work and the answered escalation are
yours. Before accepting, copy its lasting decision into your handoff Decisions, and into the
decision and drift log when later workstreams depend on it, then remove the entry.

If your row is already in a non-terminal state, follow the README's interrupted work recovery
rules before continuing.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of the provider adapters implementation.

Read docs/specs/provider-adapters-implementation/README.md and final-review.md, then the
source-of-truth documents the README identifies. Every numbered workstream is accepted.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in the
plan. Triage its findings, send each accepted correction to a fresh implementation agent owning
the relevant files, then run focused closure in a fresh review session using the same brief.
Run gate G3 as the plan places it.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to Accepted,
add any drift to the decision and drift log, write the plan's Completion summary, and make one
commit containing the corrections, the record and the plan updates.

You cannot reach the user. Block the same way a workstream lead does: add an escalation entry
to plan.md, set the Final row to Blocked, leave the work uncommitted and return its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Completion report

Report:

- delivered behaviour
- verification run, with results
- gates passed and any still pending
- approved drift
- deferred optional observations

If a required gate hasn't passed, report the feature as incomplete.
