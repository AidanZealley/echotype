# EchoTypeCore implementation workflow

Status: approved orchestration instructions.

This directory is the complete handoff for a fresh orchestration agent.

## Where this runs

On the remote Linux machine. Everything here is pure Swift with no Apple-framework
imports, so it builds and tests without AppKit.

Swift 6.4 is installed via swiftly and symlinked into `~/.local/bin`, which is on the
default PATH. No setup step is needed.

## Two traps specific to this machine

`swift test` exits 2 even when every test passes. Running both suites, the empty
XCTest suite reports "Executed 0 tests" and poisons the exit code while the Swift
Testing tests pass. **Always run `swift test --disable-xctest`**, which exits 0
correctly. An agent running plain `swift test` will conclude the build is broken when
it is not.

The toolchain's optional system dependencies are not installed, because `sudo` needs a
password here. Building and testing work without them. If something fails at link time
referencing `libpython3`, `libxml2` or `libcurl`, that is the cause, and it is an
escalation rather than something to work around.

## What must never appear in this package

`EchoTypeCore` imports Foundation and nothing else from Apple. No `import AppKit`,
`SwiftUI`, `AVFoundation`, `CoreGraphics` or `ApplicationServices`. Any of those makes
the package uncompilable here and defeats the reason it exists.

`URLSessionWebSocketTask` is available on Linux through `FoundationNetworking`, and
this has been verified on this machine. It is still reached through a protocol rather
than directly, so the client's logic is testable without a live socket.

## Relationship to the macOS spike workflow

[The macOS spike](../../spike-macos/implementation/README.md) runs on a different
machine and a different branch. The two do not share code, but both create
`Package.swift`, so merging the branches requires reconciling that one file.

This workflow's manifest declares `EchoTypeCore` and its tests only. The
specification's illustrative snippet shows a conditional macOS app target under
`#if os(Linux)`, which is correct for the merged manifest and premature here, because
the app target does not exist on this branch. That difference is deliberate and
already decided. Do not record it as drift and do not try to resolve it.

## Source of truth

In precedence order:

1. `~/.claude/CLAUDE.md` and any repository instructions.
2. [The approved specification](../../specs/echotype-v1.md). Most relevant are
   "Transcription", "Audio", "Silence, pausing and the hard cap", "Architecture" and
   "What is tested where".
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

Read `plan.md`. Spawn a workstream lead for the next workstream, passing only the path
to its packet. Read the return only to decide whether to continue or stop, since the
lead has already recorded its status, drift and escalation. Repeat. Spawn the
final-review lead after the last acceptance.

A row in a non-terminal state with no live lead means the workstream was interrupted.
Start a fresh lead for the same workstream and tell it to recover the uncommitted work
using the rules below.

Report to the user at workstream acceptance, on an escalation, and in the completion
report. Nothing else.

If the orchestrator stopped at any moment, a fresh orchestrator must be able to resume
from `plan.md` alone.

## Lead return contract

Every lead returns exactly this and nothing else:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, written by the lead before it commits. Status
goes in the workstream table. Drift goes in the decision and drift log. An escalation
goes in the escalations section. The orchestrator records none of them; transcribing a
return would write to the plan after the lead's commit and dirty the tree the next lead
starts from.

The orchestrator writes only two things: the branch and starting commit at the start,
and the user's answer inside an escalation entry. Each stays uncommitted until the next
lead's commit picks it up.

On a `Blocked` return the orchestrator reads only the named escalation entry.

## Agent spawning

This workflow runs on Claude Code. Spawn every agent with the `Agent` tool using
`subagent_type: general-purpose` and `run_in_background: false`. Omit `model`, so
agents inherit the orchestrator's model and reasoning effort.

The `Agent` call blocks by itself. Never busy-poll: no repeated short waits, no
`TaskOutput` checks on a running agent, no scheduled wake-up to see whether one
finished.

## Branch and commit model

One integration branch, `feat/echotype-core`, cut from the approved HEAD and recorded
in `plan.md`.

One commit per workstream, containing the code, the workstream record and the lead's
plan updates. Subject line names the workstream, for example
`Core 02: STT client and transcript assembler`.

Changes stay uncommitted through implementation, review and remediation so the reviewer
sees one coherent diff. No document records an accepted workstream's commit hash.

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
blocks acceptance unless the lead promotes it. Question means an ambiguity needing lead
judgment.

Findings are evidence, not instructions. The lead owns triage and the terminal decision.

### Implementation prompt template

```text
Implement workstream <N> of EchoTypeCore.

Read <packet path> and the source-of-truth documents its README identifies. The task
packet is frozen.

Implement the smallest complete change that meets its acceptance criteria. Run the
packet's targeted verification, not broader suites. Then do a deletion and
simplification pass: remove anything you added that no acceptance criterion needs.

Run tests with `swift test --disable-xctest`. Plain `swift test` exits 2 on this
machine even when everything passes.

EchoTypeCore imports Foundation only. No AppKit, SwiftUI, AVFoundation, CoreGraphics
or ApplicationServices.

Write the Implementation handoff section of <packet path>. Report base commit, files
changed, decisions, verification run, limitations and any specification drift.
```

### Review prompt template

```text
Independently review workstream <N> of EchoTypeCore.

Read <packet path> and the source-of-truth documents its README identifies. Inspect the
uncommitted diff and the surrounding code. Run proportionate checks with
`swift test --disable-xctest` and `swift-format lint --recursive Sources Tests`.

Judge the work against the packet's acceptance criteria and the specification. Look for
correctness defects, unmet criteria, boundary violations and unjustified complexity.
Pay particular attention to tests that assert implementation details rather than
behaviour the product depends on.

Do not edit implementation files. Write only the Independent review section of <packet
path>, classifying each finding as Required, Optional or Question with the evidence
behind it.
```

### Closure prompt template

```text
Run focused closure review on workstream <N> of EchoTypeCore.

Read <packet path>, including the Independent review and Resolution sections.

Verify each accepted finding was actually fixed and check the fixes for
release-blocking defects. Do not restart open-ended review and do not promote optional
suggestions.

Write only the Closure review section of <packet path>.
```

### Remediation

Tell a remediation agent to revisit and simplify the affected design. It must not
accumulate wrappers, aliases, flags, compatibility paths or special cases to preserve a
flawed first implementation.

## Workstream lead prompt

This is what the orchestrator sends. Keep it this short; the packet carries the detail.

```text
Lead workstream <N> of EchoTypeCore.

Read docs/echotype-core/implementation/README.md and <NN-workstream.md>, then the source-of-truth documents the
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

Run tests with `swift test --disable-xctest`. Plain `swift test` exits 2 on this
machine even when everything passes.

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of EchoTypeCore.

Read docs/echotype-core/implementation/README.md and final-review.md, then the source-of-truth documents the README
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
base and the ownership of every change, verifies enough to establish the current state,
then continues from the earliest phase it cannot prove complete. Reuse sound work.
Rerun any incomplete or undocumented review step.

Abandon partial work only when it cannot be safely attributed, uses the wrong base,
contradicts the frozen packet, overlaps unrelated changes, or would be less safe to
repair than to restart. Preserve it in a named stash or recovery branch first. Escalate
rather than overwrite when ownership is unclear.

Respect dirty worktrees. Do not claim ownership of unrelated changes or start a
workstream until the orchestrator has resolved overlapping state.

## Review command

Reviews run as the lead's own subagents. There is no external review command.

## External validation gates

Workstream 3 cannot run without an xAI API key and a sample recording, neither of which
an agent can produce. See the External validation gates section of [plan.md](plan.md).

A gate that needs the user stops the lead. The lead records the candidate and required
evidence in its workstream record's External validation section, writes an escalation
entry in `plan.md`, sets its row to `Blocked` and returns the escalation id with the
work uncommitted.

Once the user answers, the orchestrator starts a fresh lead for that workstream, which
inherits the uncommitted work and the answered entry. Before accepting it copies the
lasting decision into its handoff Decisions field, and into the plan's decision and
drift log when a later workstream depends on it, then removes the entry.

A gate the lead can retry itself, such as a connection or encoding failure it can
diagnose from the response, enters a troubleshooting loop inside the workstream: record
the candidate, failing action and evidence, make the smallest correction, run
agent-accessible checks, and repeat without changing the workstream status. Reopen the
full review loop only when a correction changes approved behaviour, architecture,
ownership or a public contract.

Gate status is tracked separately from workstream status in `plan.md`, using only
`Pending`, `Testing`, `Troubleshooting` or `Passed`.

## Final whole-feature review

After the last acceptance the orchestrator spawns one final-review lead. It runs an
open-ended review of the full branch against the recorded starting commit, triages
findings, sends each accepted correction to a fresh implementation agent, runs focused
closure in a fresh session, writes `final-review.md` and commits.

It owns the Final row in the plan's workstream table and follows the same return and
escalation rules as a workstream lead.

## Completion report

The orchestrator's final report to the user covers delivered outcomes, verification
run, external validation still pending, specification drift, and any deferred optional
observations.

State explicitly what workstream 3 learned about the real streaming protocol, since the
specification's pause behaviour was written from documentation rather than observation.
