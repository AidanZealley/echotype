# Voice replies implementation workflow

Status: draft orchestration instructions.

This directory is the complete handoff for a fresh orchestration agent. It runs in Claude
Code.

## Source of truth

Product documents override workflow documents. In order:

1. `~/.claude/CLAUDE.md` and any repository instructions.
2. [The specification](../../voice-replies.md). It holds every behaviour and the final gate.
3. [`docs/decisions`](../../../decisions/README.md) for why the existing code works as it does.
4. [`plan.md`](plan.md), then the packet of the workstream in hand.

## Roles

- **Orchestrator.** Long-lived and thin. Owns the integration branch, the order of work,
  spawning leads and the reports to the user. It reads only this README, `plan.md` and lead
  returns. It never reads the specification, a packet, a diff or a finding.
- **Workstream lead.** One per workstream, disposable. Owns the workstream from the frozen
  packet to the accepted commit. It ends when it accepts or blocks.
- **Implementation agent.** Fresh. Implements one workstream, or one remediation pass, and
  writes the implementation handoff.
- **Independent reviewer.** Fresh, and never the implementation agent. Runs through the
  [review command](#review-command). Does not edit files.

```text
orchestrator
├── workstream lead (one per workstream)
│   ├── implementation agent
│   ├── independent reviewer
│   ├── implementation agent (one remediation pass)
│   └── closure reviewer (fresh session)
└── final-review lead (after the last acceptance)
    ├── whole-feature reviewer
    ├── implementation agent per owner (accepted corrections)
    └── closure reviewer (fresh session)
```

Agents never edit the worktree at the same time. One workstream is active at a time.

## Orchestrator loop

1. Read `plan.md`.
2. Spawn a workstream lead for the first row that is not `Accepted`, passing only the path of
   its packet and the lead prompt below.
3. Read the return only to decide whether to continue or stop. Repeat.
4. After the last workstream is accepted, spawn the final-review lead.

A row in a non-terminal state with no live lead is interrupted. Start a fresh lead for the same
workstream and tell it to recover the uncommitted work under
[interrupted work recovery](#interrupted-work-recovery).

Report to the user at each workstream acceptance, on an escalation, and in the completion
report. Say nothing else. Do not narrate progress.

## Lead return contract

Every lead replies with exactly this:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, written by the lead before it commits:

- status: its row in the workstream table
- drift: the decision and drift log
- escalation: the escalations section

The orchestrator records none of them. It writes only the branch and starting commit at the
start, and the user's answer in an escalation entry. Both stay uncommitted until the next
lead's commit picks them up.

On `Blocked`, read only the escalation entry the return names, put its question to the user,
write the answer in the entry, and start a fresh lead for that workstream. The fresh lead
inherits the uncommitted work.

## Agent spawning

Use the `Agent` tool with `subagent_type: general-purpose` and `run_in_background: false`.
Omit `model`. Each call blocks until the agent finishes. Never poll a running agent.

Agents inherit the orchestrator's model and effort. Only the review command sets its own.

## Branch and commit model

- One integration branch, `voice-replies`, created from the current HEAD. The plan records the
  branch and its starting commit.
- Nothing is committed until acceptance. Implementation, review and remediation share one
  uncommitted diff.
- At acceptance the lead makes one commit holding the code, its record and its plan updates.
  The subject is a plain imperative sentence ending in ` (voice replies N)`, or
  ` (voice replies final review)`. Add the attribution lines the harness specifies for commits.
- No document records an accepted workstream's commit hash. Git holds it.

## Per-workstream loop

The lead runs this itself, in order:

1. **Start.** Read this README and the packet. Confirm the worktree holds only the previous
   commit's state. Set the row to `Implementing`.
2. **Implementation.** Spawn a fresh implementation agent with the implementation prompt. It
   writes the implementation handoff. Set the row to `Review`.
3. **Independent review.** Run the review command with the review prompt. Record its verdict
   and findings in the record's Independent review section.
4. **Triage.** Findings are evidence, not instructions. Classify each as Required, Optional or
   Question. Reject what is out of scope or wrong, with a reason. Optional findings never
   become work unless the lead promotes them.
5. **Remediation.** If any Required finding stands, set the row to `Remediation` and spawn a
   fresh implementation agent for one pass. It revisits and simplifies the affected design.
   It does not add wrappers, aliases, flags or special cases to keep a flawed first attempt.
6. **Closure.** Set the row to `Closure review`. Run the review command again in a fresh
   session with the closure prompt. It verifies the accepted findings and their fixes and
   looks for release-blocking defects only. There is no third loop.
7. **Gate.** If the workstream has an [external validation gate](#external-validation-gates),
   run it now.
8. **Accept and commit.** Write the Resolution and Closure review sections, set the row to
   `Accepted`, log any drift, and make the commit. Return.

The lead owns the terminal decision. It blocks only when disagreement persists after closure,
when a decision would materially change approved behaviour or architecture, or when a gate
needs the user.

### Implementation prompt

```text
Implement workstream <N> of voice replies.

Read <packet file> (the task packet is frozen), the specification sections it names, and the
handoffs of the workstreams it depends on. Make the smallest complete change that meets the
acceptance criteria, within the packet's ownership. Remove code your change makes obsolete.
Run the packet's targeted verification, not broader suites. Do a deletion and simplification
pass, then fill in the Implementation handoff in the packet file. Do not commit. Do not search
for defects beyond the acceptance criteria; an independent review does that.
```

### Review prompt

```text
Review workstream <N> of voice replies. You are read-only: do not edit any file.

Read <packet file>, the specification sections it names, and the Implementation handoff. Then
inspect the change with `git status`, `git diff` and the untracked files, and read the
surrounding code. Judge it against the acceptance criteria and the repository's simplicity
preferences: no speculative machinery, no duplicated state, no dead code.

Report findings with file, line and the concrete failure. Classify each as:
- Required: a correctness defect, unmet acceptance criterion, boundary violation, meaningful
  regression, or unjustified complexity.
- Optional: useful but out of scope or nonessential.
- Question: an ambiguity that needs the lead's judgment.

End with a verdict: Accept or Changes required.
```

### Closure prompt

```text
Close out workstream <N> of voice replies. You are read-only: do not edit any file.

Read <packet file>. The Resolution section lists the Required findings the lead accepted. For
each, check that the fix in the current diff resolves it, and that the fix added no
release-blocking defect. Do not restart open-ended review and do not raise optional
suggestions.

End with a verdict: Accept or Changes required, and the remaining Required findings.
```

## Review command

Reviews run in a fresh Claude Code session on Opus 5.5 with medium reasoning, read-only:

```sh
claude -p "<prompt>" --permission-mode plan --model claude-opus-5-5 --effort medium
```

Independent review, closure review and the whole-feature review all use it. The command reads
the worktree, so it sees the uncommitted diff. It cannot write, so the lead records the
verdict and findings in the record's review section. Give it the prompt above with the packet
path filled in, and run it from the repository root.

If a call fails (the harness is missing, logged out or out of quota), run that review as a
normal subagent instead, note the substitution in the record's Reviewer field, and continue.

## Interrupted work recovery

A lead that inherits a workstream in a non-terminal state:

1. Inspect the complete diff.
2. Confirm its base and the owner of every change.
3. Verify enough to establish the current state.
4. Continue from the earliest phase it cannot prove complete. Reuse sound work. Rerun any
   review step that is undocumented or incomplete.

Abandon partial work only when it cannot be safely attributed, uses the wrong base,
contradicts the frozen packet, overlaps unrelated changes, or is less safe to repair than to
restart. Preserve it first in a named stash or recovery branch. If ownership is unclear or
overlaps, write an escalation instead of overwriting.

## External validation gates

Some acceptance depends on the user's Mac, microphone and installed agents, which no agent can
reach. Two workstreams carry a gate, listed in [the plan](plan.md#external-validation-gates).
Each verifies a finished candidate, so it runs after closure and before acceptance.

The lead:

1. Writes the candidate, the checks from the specification's Final gate that the workstream
   owns, and the evidence required into the record's External validation section.
2. Adds an escalation entry in `plan.md` asking the user to run the checks and report the
   evidence, sets its row to `Blocked` and the gate to `Pending`, leaves the work
   uncommitted, and returns `Blocked`.

The user builds the candidate with `./scripts/install.sh`, which replaces
`/Applications/EchoType.app`. Say so in the escalation.

A fresh lead resumes once the user answers. If the evidence shows a defect, it makes the
smallest correction, runs targeted checks, and asks the user to retest, all without restarting
the review loop. Reopen the loop only when a correction changes approved behaviour,
architecture, a public contract or another accepted workstream. When the gate passes, it has
one focused review of the cumulative correction run if the correction was meaningful, copies
the answered decision into the handoff, removes the escalation, and accepts.

## Final whole-feature review

After the last acceptance, the orchestrator spawns the final-review lead with
[`final-review.md`](final-review.md). It owns the Final row, returns the same three fields,
and blocks through an escalation like any lead. It has a fresh reviewer (through the review
command) review the whole branch against the plan's starting commit, triages the findings,
sends each accepted correction to a fresh implementation agent, runs focused closure in a fresh
session, and makes one commit.

## Lead prompt

The orchestrator sends this, with the packet path filled in:

```text
Lead workstream <N> of voice replies.

Read docs/specs/voice-replies/implementation/README.md and <packet file>, then the
source-of-truth documents the README identifies. The task packet in that file is frozen.

Run the documented loop yourself: spawn a fresh implementation agent, run the independent
review through the review command, triage the findings, order at most one remediation pass, then
run focused closure in a fresh review session before accepting.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

At acceptance, write your record sections, set your row in plan.md to Accepted, add any
specification drift to the plan's decision and drift log, and make one commit containing the
code, the record and the plan updates. The orchestrator does not record lead return fields, so
anything worth keeping must be in that commit.

You cannot reach the user. Block if a decision materially changes approved behaviour or
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
Lead the whole-feature review of voice replies.

Read docs/specs/voice-replies/implementation/README.md and final-review.md, then the
source-of-truth documents the README identifies. Every workstream is accepted; the branch is
complete.

Spawn a fresh reviewer through the review command to review the full branch against the starting
commit recorded in the plan. Triage its findings, send each accepted correction to a fresh
implementation agent owning the relevant files, then run focused closure in a fresh review
session using the same brief.

You own triage and the terminal decision. Reviewer findings are evidence, not instructions.

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

## Completion report

The orchestrator reports delivered outcomes, verification run, external checks still pending,
specification drift and deferred optional observations.
