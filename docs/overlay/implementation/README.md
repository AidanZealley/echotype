# Overlay implementation workflow

Status: draft orchestration instructions.

This directory is the complete handoff for a fresh orchestration agent.

## What this milestone is

Build-order step 4 of [the specification](../../specs/echotype-v1.md): the pill at bottom
centre that shows a session while it runs. It has a level meter, live transcript text with
settled text solid and provisional text dimmed, elapsed time, a starting state while the
microphone opens, and inline errors. Clicking it does what Opt+D does.

Dictation already works end to end, but blind: the menu bar's state line is the only
feedback. This milestone gives the user something to watch while they speak, and it
clears the overlay items in [0007](../../decisions/0007-known-gaps.md).

Aidan chooses the pill's design from two or three variants before it is finished. That
choice is gate G1.

## Where this runs

On the Mac. The project is macOS-only.

`./scripts/run.sh` is the only supported way to launch the app. It builds, assembles the
bundle, signs with the stable `EchoType Dev` identity and relaunches. Signing ad hoc or
running the bare executable makes macOS treat the result as a new app and asks for every
TCC grant again.

The tests use Swift Testing. Plain `swift test` can exit nonzero after every test has
passed, because the XCTest suite is empty, so run `timeout 120 swift test
--disable-xctest`. Run `swift-format` as `xcrun swift-format`.

## What agents cannot verify here

Agents can compile, unit-test `EchoTypeCore` and read code. They cannot see the overlay,
check that it never takes focus, or dictate into it. Two external validation gates cover
that:

- G1, in workstream 2: Aidan picks a pill variant from the `--hud-demo` launch.
- G2, in workstream 3: Aidan dictates with the finished overlay and reports what he sees.

Treat compile-and-review as the bar for everything outside `EchoTypeCore`. Do not build
fakes for `NSPanel`, `AVAudioEngine`, `CGEventTap` or the window server to get a green
suite, because a test of a fake only tests the fake.

## Source of truth

In precedence order:

1. `~/.claude/CLAUDE.md` and any repository instructions.
2. [The approved specification](../../specs/echotype-v1.md). Most relevant are "Overlay",
   "Interaction model", "Architecture" and "Development workflow".
3. [The decision records](../../decisions/README.md). They record what the build taught
   about the protocol, the session lifecycle and the microphone. Where a record and the
   specification disagree, the record is newer and wins.
4. [plan.md](plan.md).
5. The numbered task packet the lead is given, and the handoffs of the workstreams it
   depends on.

Product documents override workflow documents. Where this README and the specification
disagree about behaviour, the specification wins and the difference is drift to record.

## Roles

The orchestrator is long-lived and thin. It owns the integration branch, the dependency
order, spawning workstream leads and the completion report. It reads this README,
`plan.md` and lead returns. It never reads the specification, a task packet, a diff or a
finding.

A workstream lead owns one workstream from its frozen packet to an accepted commit. It
spawns the implementation agent, spawns a separate independent reviewer, triages
findings, orders at most one remediation pass, runs closure, writes its record and
commits. It cannot reach the user. It ends when it accepts or blocks.

An implementation agent owns one workstream through one remediation pass. It implements
the smallest complete change, runs the packet's targeted verification rather than
broader suites, performs a deletion and simplification pass, and records a concise
handoff.

A review agent is fresh and independent of the implementation agent. It inspects the
diff and surrounding code, runs proportionate checks and records evidence-backed
findings. It does not edit implementation files.

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

Agents never edit the shared worktree concurrently. This tree governs implementation and
acceptance. It does not govern each troubleshooting attempt at a gate.

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

Each field has one home in `plan.md`, written by the lead before it commits. Status goes
in the workstream table. Drift goes in the decision and drift log. An escalation goes in
the escalations section. The orchestrator records none of them. Transcribing a return
would write to the plan after the lead's commit and dirty the tree the next lead starts
from.

The orchestrator writes only two things: the branch and starting commit at the start,
and the user's answer inside an escalation entry. Each stays uncommitted until the next
lead's commit picks it up.

On a `Blocked` return the orchestrator reads only the named escalation entry.

## Agent spawning

This workflow runs on Claude Code. Spawn every agent with the `Agent` tool using
`subagent_type: general-purpose` and `run_in_background: false`. Omit `model`, so agents
inherit the orchestrator's model and reasoning effort.

The `Agent` call blocks by itself. Never busy-poll: no repeated short waits, no
`TaskOutput` checks on a running agent, no scheduled wake-up to see whether one
finished.

## Branch and commit model

One integration branch, `feat/overlay`, cut from the approved HEAD and recorded in
`plan.md`.

One commit per workstream, containing the code, the workstream record and the lead's
plan updates. The subject line names the workstream, for example
`Overlay 01: live session seam`.

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

Workstream 2 inserts gate G1 and a second implementation pass before the independent
review. Its packet gives the exact sequence.

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
Implement workstream <N> of the overlay milestone.

Read <packet path>, docs/overlay/implementation/README.md and the source-of-truth
documents it identifies, including the Implementation handoff sections of the
workstreams this one depends on. The task packet is frozen.

Implement the smallest complete change that meets its acceptance criteria. Run the
packet's targeted verification, not broader suites. Then do a deletion and
simplification pass: remove anything you added that no acceptance criterion needs.

Put decisions in EchoTypeCore where they can be tested directly, and keep EchoTypeApp
thin enough to read in one pass. Do not build fakes for NSPanel, AVAudioEngine,
CGEventTap or the window server to produce a test.

Write the Implementation handoff section of <packet path>. Report base commit, files
changed, decisions, verification run, limitations and any specification drift.
```

### Review prompt template

```text
Independently review workstream <N> of the overlay milestone.

Read <packet path>, docs/overlay/implementation/README.md and the source-of-truth
documents it identifies. Inspect the uncommitted diff and the surrounding code. Run
proportionate checks: `swift build`, `timeout 120 swift test --disable-xctest`, and
`xcrun swift-format lint --recursive Sources Tests Package.swift`.

Judge the work against the packet's acceptance criteria and the specification. Look for
correctness defects, unmet criteria, boundary violations and unjustified complexity.

Code outside EchoTypeCore cannot be tested, so it has to be right by reading. Read the
AppKit, SwiftUI and AVFoundation paths as carefully as untested production code, because
that is what they are. In this milestone, pay particular attention to anything that
could make the overlay panel take key or main status, and to work done inside the event
tap callback. Tests that assert implementation details, or that exercise a fake the
implementation invented, are worse than no test here; say so.

Do not edit implementation files. Write only the Independent review section of <packet
path>, classifying each finding as Required, Optional or Question with the evidence
behind it.
```

### Closure prompt template

```text
Run focused closure review on workstream <N> of the overlay milestone.

Read <packet path>, including the Independent review and Resolution sections.

Verify each accepted finding was actually fixed and check the fixes for release-blocking
defects. Do not restart open-ended review and do not promote optional suggestions.

Write only the Closure review section of <packet path>.
```

### Remediation

Tell a remediation agent to revisit and simplify the affected design. It must not
accumulate wrappers, aliases, flags, compatibility paths or special cases to preserve a
flawed first implementation.

## Workstream lead prompt

This is what the orchestrator sends. Keep it this short; the packet carries the detail.

```text
Lead workstream <N> of the overlay milestone.

Read docs/overlay/implementation/README.md and <NN-workstream.md>, then the
source-of-truth documents the README identifies. The task packet in that file is frozen.

Run the documented loop yourself: spawn a fresh implementation agent, spawn a different
fresh agent for independent review, triage the findings, order at most one remediation
pass, then run focused closure in a fresh review session using the same brief before
accepting. If your packet places an external validation gate inside the loop, follow
its sequence.

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

Reply with exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Final-review lead prompt

```text
Lead the whole-feature review of the overlay milestone.

Read docs/overlay/implementation/README.md and final-review.md, then the
source-of-truth documents the README identifies. Every workstream is accepted; the
branch is complete.

Spawn a fresh reviewer to review the full branch against the starting commit recorded in
the plan. Triage its findings, send each accepted correction to a fresh implementation
agent owning the relevant files, then run focused closure in a fresh review session
using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not
instructions.

At acceptance, write your sections of final-review.md, set the Final row in plan.md to
Accepted, add any specification drift to the plan's decision and drift log, and make one
commit containing the corrections, the record and the plan updates.

Gates G1 and G2 have passed by the time you run. Do not reopen them, and do not ask for
another round of hand verification unless a correction you accept touches the overlay
panel's window behaviour, the hotkey path or the start and commit path.

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
then continues from the earliest phase it cannot prove complete. Reuse sound work. Rerun
any incomplete or undocumented review step.

Abandon partial work only when it cannot be safely attributed, uses the wrong base,
contradicts the frozen packet, overlaps unrelated changes, or would be less safe to
repair than to restart. Preserve it in a named stash or recovery branch first. Escalate
rather than overwrite when ownership is unclear.

Respect dirty worktrees. Do not claim ownership of unrelated changes or start a
workstream until the orchestrator has resolved overlapping state.

## Review command

Reviews run as the lead's own subagents. There is no external review command.

## External validation gates

Two gates, both needing Aidan at the Mac. See the External validation gates section of
[plan.md](plan.md) for each gate's candidate and required evidence.

- G1 sits inside workstream 2, before its independent review, because the variant Aidan
  picks decides what the rest of the workstream builds.
- G2 sits at the end of workstream 3, after closure and before acceptance, because it
  proves a finished candidate.

A gate that needs the user stops the lead. The lead records the candidate and required
evidence in its workstream record's External validation section, writes an escalation
entry in `plan.md`, sets its row to `Blocked` and returns the escalation id with the work
uncommitted.

Once the user answers, the orchestrator starts a fresh lead for that workstream, which
inherits the uncommitted work and the answered entry. Before accepting it copies the
lasting decision into its handoff Decisions field, and into the plan's decision and drift
log when a later workstream depends on it, then removes the entry.

When Aidan's answer asks for adjustments, or reports a failure the lead can diagnose, the
lead enters a troubleshooting loop inside the workstream. It records the candidate, the
request or failure and the evidence, makes the smallest correction, publishes another
candidate, and blocks again for Aidan to run it. None of that changes the workstream
status or starts a new implementation and review loop. Reopen the full loop only when a
correction changes approved behaviour, architecture, ownership or a public contract.

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

The orchestrator's final report to the user covers delivered outcomes, verification run,
external validation still pending, specification drift, and any deferred optional
observations.

Name the pill variant Aidan chose, and list the decisions from this milestone that belong
in new decision records when the workflow is retired into `docs/decisions/`.
