# EchoType macOS spike implementation workflow

Status: approved orchestration instructions.

This directory is the complete handoff for a fresh orchestration agent.

## Where this runs

On Aidan's Mac. Not on the remote Linux development machine.

Every acceptance criterion here needs AppKit, a code signature, a TCC database and a
real keyboard. None of it is reachable from Linux. An orchestrator that finds itself
on Linux should stop and say so rather than attempting the work.

## What this proves

The spike exists to test one assumption before anything is built on it: that TCC
permission grants survive rebuilds when the app is signed with a stable self-signed
identity. If that is false, the development loop described in the specification does
not work and the fix could be anything from a signing flag to buying a Developer ID.

Everything else here is the smallest scaffolding needed to test that.

## Source of truth

In precedence order:

1. `~/.claude/CLAUDE.md` and any repository instructions.
2. [The approved specification](../../specs/echotype-v1.md), sections "Platform choice",
   "Permissions, signing and distribution", "Development workflow" and "Build order".
3. [plan.md](plan.md).
4. The numbered task packet the lead is given.

Product documents override workflow documents. Where this README and the
specification disagree about behaviour, the specification wins and the difference is
drift to record.

## Roles

The orchestrator is long-lived and thin. It owns the integration branch, the
dependency order, spawning workstream leads and the completion report. It reads this
README, `plan.md` and lead returns. It never reads the specification, a task packet,
a diff or a finding.

A workstream lead owns one workstream from its frozen packet to an accepted commit.
It spawns the implementation agent, spawns a separate independent reviewer, triages
findings, orders at most one remediation pass, runs closure, writes its record and
commits. It cannot reach the user. It ends when it accepts or blocks.

An implementation agent owns one workstream through one remediation pass. It
implements the smallest complete change, runs the packet's targeted verification
rather than broader suites, performs a deletion and simplification pass, and records
a concise handoff.

A review agent is fresh and independent of the implementation agent. It inspects the
diff and surrounding code, runs proportionate checks and records evidence-backed
findings. It does not edit implementation files.

## Orchestrator loop

Read `plan.md`. Spawn a workstream lead for the next workstream, passing only the
path to its packet. Read the return only to decide whether to continue or stop, since
the lead has already recorded its status, drift and escalation. Repeat. Spawn the
final-review lead after the last acceptance.

A row in a non-terminal state with no live lead means the workstream was interrupted.
Start a fresh lead for the same workstream and tell it to recover the uncommitted
work using the rules below.

Report to the user at workstream acceptance, on an escalation, and in the completion
report. Nothing else. Progress narration costs context on every later turn and is
stale as soon as it is written.

If the orchestrator stopped at any moment, a fresh orchestrator must be able to
resume from `plan.md` alone.

## Lead return contract

Every lead returns exactly this and nothing else:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, written by the lead before it commits. Status
goes in the workstream table. Drift goes in the decision and drift log. An escalation
goes in the escalations section. The orchestrator records none of them; transcribing
a return would write to the plan after the lead's commit and dirty the tree the next
lead starts from.

The orchestrator writes only two things: the branch and starting commit at the start,
and the user's answer inside an escalation entry. Each stays uncommitted until the
next lead's commit picks it up.

On a `Blocked` return the orchestrator reads only the named escalation entry.

## Agent spawning

This workflow runs on Claude Code. Spawn every agent with the `Agent` tool using
`subagent_type: general-purpose` and `run_in_background: false`. Omit `model`, so
agents inherit the orchestrator's model and reasoning effort.

The `Agent` call blocks by itself. Never busy-poll: no repeated short waits, no
`TaskOutput` checks on a running agent, no scheduled wake-up to see whether one
finished. Each poll re-sends the whole orchestrator context for no new information.

## Branch and commit model

One integration branch, `spike/macos-hotkey-paste`, cut from the approved HEAD and
recorded in `plan.md`.

One commit per workstream, containing the code, the workstream record and the lead's
plan updates. Subject line names the workstream, for example
`Spike 01: signed app bundle and run script`.

Changes stay uncommitted through implementation, review and remediation so the
reviewer sees one coherent diff. No document records an accepted workstream's commit
hash; git already holds it, and writing one after committing would dirty the tree.

## Per-workstream loop

```text
implementation
    -> independent review
    -> one remediation pass if required
    -> focused closure review
    -> accept, or return Blocked to the orchestrator
```

Closure runs in a fresh session with the same reviewer brief. It verifies accepted
findings and checks their fixes for release-blocking defects. It does not restart
open-ended review or promote optional suggestions. There is no automatic third loop.

Findings use three categories. Required means a correctness defect, unmet acceptance
criterion, boundary violation, meaningful regression or unjustified complexity that
blocks acceptance. Optional means a useful but out-of-scope improvement, which never
blocks acceptance unless the lead promotes it. Question means an ambiguity needing
lead judgment.

Findings are evidence, not instructions. The lead owns triage and the terminal
decision.

### Implementation prompt template

```text
Implement workstream <N> of the EchoType macOS spike.

Read <packet path> and the source-of-truth documents its README identifies. The task
packet is frozen.

Implement the smallest complete change that meets its acceptance criteria. Run the
packet's targeted verification, not broader suites. Then do a deletion and
simplification pass: remove anything you added that no acceptance criterion needs.

You are on macOS. Do not attempt to run anything that requires Linux.

Write the Implementation handoff section of <packet path>. Report base commit, files
changed, decisions, verification run, limitations and any specification drift.
```

### Review prompt template

```text
Independently review workstream <N> of the EchoType macOS spike.

Read <packet path> and the source-of-truth documents its README identifies. Inspect
the uncommitted diff and the surrounding code. Run proportionate checks.

Judge the work against the packet's acceptance criteria and the specification. Look
for correctness defects, unmet criteria, boundary violations and unjustified
complexity.

Do not edit implementation files. Write only the Independent review section of
<packet path>, classifying each finding as Required, Optional or Question with the
evidence behind it.
```

### Closure prompt template

```text
Run focused closure review on workstream <N> of the EchoType macOS spike.

Read <packet path>, including the Independent review and Resolution sections.

Verify each accepted finding was actually fixed and check the fixes for
release-blocking defects. Do not restart open-ended review and do not promote optional
suggestions.

Write only the Closure review section of <packet path>.
```

### Remediation

Tell a remediation agent to revisit and simplify the affected design. It must not
accumulate wrappers, aliases, flags, compatibility paths or special cases to preserve
a flawed first implementation.

## Workstream lead prompt

This is what the orchestrator sends. Keep it this short; the packet carries the detail.

```text
Lead workstream <N> of the EchoType macOS spike.

Read docs/spike-macos/implementation/README.md and <NN-workstream.md>, then the source-of-truth documents the
README identifies. The task packet in that file is frozen.

Run the documented loop yourself: spawn a fresh implementation agent, spawn a different
fresh agent for independent review, triage the findings, order at most one remediation
pass, then run focused closure in a fresh review session using the same brief before
accepting.

You own triage and the terminal decision. Reviewer findings are evidence, not
instructions.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, and make one commit containing
the code, the record and the plan updates. The orchestrator does not record lead return
fields, so anything worth keeping must be in that commit.

You cannot reach the user. Block if a decision materially changes approved behaviour or
architecture, if disagreement persists after closure, or if an external validation gate
needs the user. To block, add an escalation entry to plan.md giving the decision needed,
the options, your recommendation, the evidence and what it unblocks, set your row to
Blocked, leave the work uncommitted, and return its id. Summarise; do not paste findings
or diffs.

If you are resuming a blocked workstream, the uncommitted work and the answered
escalation entry are yours. Before you accept, copy its lasting decision into your
handoff Decisions field, and into the plan's decision and drift log when later
workstreams depend on it, then remove the entry.

If your row is already in a non-terminal state, you are recovering interrupted work.
Follow the README's interrupted work recovery rules before continuing.

Both workstreams end in a gate only Aidan can pass. Expect to block.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of the EchoType macOS spike.

Read docs/spike-macos/implementation/README.md and final-review.md, then the source-of-truth documents the README
identifies. Every workstream is accepted; the branch is complete.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in
the plan. Triage its findings, send each accepted correction to a fresh implementation
agent owning the relevant files, then run focused closure in a fresh review session
using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not
instructions.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to
Accepted, add any specification drift to the plan's decision and drift log, and make one
commit containing the corrections, the record and the plan updates.

You cannot reach the user. Block the same way a workstream lead does: add an escalation
entry to plan.md, set the Final row to Blocked, leave the work uncommitted, and return
its id.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Interrupted work recovery

A lead inheriting a non-terminal workstream inspects the complete diff, confirms its
base and the ownership of every change, verifies enough to establish the current
state, then continues from the earliest phase it cannot prove complete. Reuse sound
work. Rerun any incomplete or undocumented review step.

Abandon partial work only when it cannot be safely attributed, uses the wrong base,
contradicts the frozen packet, overlaps unrelated changes, or would be less safe to
repair than to restart. Preserve it in a named stash or recovery branch first.
Escalate rather than overwrite when ownership is unclear.

Respect dirty worktrees. Do not claim ownership of unrelated changes or start a
workstream until the orchestrator has resolved overlapping state.

## Review command

Reviews run as the lead's own subagents. There is no external review command.

## External validation gates

Both workstreams end in a gate only Aidan can pass, because both depend on Keychain
Access, System Settings and a human pressing keys.

A gate that needs the user stops the lead. The lead records the candidate and the
required evidence in its workstream record's External validation section, writes an
escalation entry in `plan.md`, sets its row to `Blocked` and returns the escalation
id with the work uncommitted. Leads cannot reach the user; only the orchestrator can.

Once the user answers, the orchestrator starts a fresh lead for that workstream. That
lead inherits the uncommitted work and the answered entry. Before accepting it copies
the lasting decision into its handoff Decisions field, and into the plan's decision
and drift log when a later workstream depends on it, then removes the entry.

A gate the lead can retry itself, such as a build or signing failure it can diagnose
from the user's evidence, enters a troubleshooting loop inside the workstream: record
the candidate, failing action and evidence, make the smallest correction, run
agent-accessible checks, publish another candidate, and repeat without changing the
workstream status. Reopen the full review loop only when a correction changes approved
behaviour, architecture, ownership, a privilege boundary or a public contract.

Gate status is tracked separately from workstream status in `plan.md`, using only
`Pending`, `Testing`, `Troubleshooting` or `Passed`.

## Final whole-feature review

After the last acceptance the orchestrator spawns one final-review lead. It runs an
open-ended review of the full branch against the recorded starting commit, triages
findings, sends each accepted correction to a fresh implementation agent, runs focused
closure in a fresh session, writes `final-review.md` and commits.

It owns the Final row in the plan's workstream table and follows the same return and
escalation rules as a workstream lead.

Keep this review proportionate. The spike is small, and its real verdict is whether
the four success criteria passed on the user's machine.

## Completion report

The orchestrator's final report to the user covers delivered outcomes, verification
run, external validation still pending, specification drift, and any deferred optional
observations.

State plainly whether criterion 3 passed, since the rest of the project's development
loop depends on it.
