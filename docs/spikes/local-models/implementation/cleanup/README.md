# Local cleanup (slice 1) implementation workflow

Status: draft orchestration instructions.

This directory is the complete handoff for a fresh orchestration agent. It builds slice 1 of the
local models spike: the experimental local provider's model downloads and its cleanup service,
measured in the EchoTypeBench against Apple and xAI. Transcription and read aloud are later
slices with their own workflows.

## Source of truth

1. Repository instructions: the user's global instructions loaded by your harness. The repository
   has no `AGENTS.md` or `CLAUDE.md` of its own.
2. [Local models spike spec](../../spec.md) and its [research](../../research.md).
3. [Test harness spec](../../../../specs/test-harness.md): the bench, its commands and scoring.
4. [Decision 0025](../../../../decisions/0025-provider-adapters.md): provider boundaries and
   readiness.
5. [plan.md](plan.md), then the next workstream's task packet.

Product documents override workflow documents. A conflict between them is drift: record it, do
not resolve it silently.

## Roles

- **Orchestrator.** Long-lived and thin. Reads only this README, `plan.md` and lead returns.
  Never reads a specification, task packet, diff or finding. Chooses the next workstream, spawns
  its lead, surfaces escalations to the user and writes the completion report.
- **Workstream lead.** One per workstream, disposable. Owns its workstream from the frozen
  packet to one accepted commit: spawns the implementation agent and reviewers, triages
  findings, orders at most one remediation pass, runs closure, writes the record, updates
  `plan.md` and commits. Ends when it accepts or blocks. It cannot reach the user.
- **Implementation agent.** Implements one workstream, or one remediation pass, for its lead.
  Reads the packet, dependency handoffs and the plan's conventions learned, makes the smallest
  complete change, runs the packet's targeted verification, does a deletion and simplification
  pass, and writes the implementation handoff.
- **Independent reviewer.** Fresh, never the implementation agent. Reviews the uncommitted diff
  and surrounding code against the packet and conventions learned, runs proportionate checks and
  writes its review section. Edits no implementation files.

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

1. Read `plan.md`. Record the integration branch and starting commit if they are `TBD`.
2. Spawn a lead for the first workstream not `Accepted`, using the lead prompt below with only
   that workstream's packet path.
3. Read the return only to decide whether to continue or stop. The lead has already recorded
   everything in `plan.md`.
4. Repeat. After the last workstream is accepted, spawn the final-review lead.

A row left in a non-terminal state with no live lead is interrupted. Start a fresh lead for that
workstream and tell it to recover the uncommitted work under "Interrupted work recovery".

A usage limit, error or restart stops every agent in the tree. When you resume from anything
other than a lead's return or the user's answer to an escalation, such as the user saying
"continue", assume every agent stopped. Check each non-terminal row once, using the harness's
agent status where it has one. Wait on a lead confirmed to be running; treat every other row as
interrupted. This single check is not busy-polling. Leads apply the same rule to their agents.

Report to the user at each workstream acceptance, on an escalation, and in the completion
report. Nothing else.

## Lead return contract

Every lead returns exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field already has a home in `plan.md`, written by the lead before it commits: status in the
workstream table, drift in the decision and drift log, escalation in the escalations section. The
orchestrator records none of them.

The orchestrator writes only the branch and starting commit at the start, and the user's answer
in an escalation entry. Each stays uncommitted until the next lead's commit picks it up. On a
`Blocked` return it reads only the named escalation entry, puts the question to the user, records
the answer there and starts a fresh lead for that workstream.

## Agent spawning

| Harness | Spawning rule |
|---|---|
| Claude Code | `Agent` with `subagent_type: general-purpose` and `run_in_background: false`. Omit `model`. The call blocks until the agent returns. |
| Codex | `spawn_agent` with `fork_turns: "none"`, omitting `model` and `reasoning_effort`, then one `wait_agent` call with a wait of many minutes. Delegation to sub-agents is required by this workflow. |

Agents inherit the orchestrator's model and reasoning effort. No agent busy-polls another: no
repeated short waits, no output checks on a running agent, no scheduled wake-ups.

## Branch and commit model

- Integration branch: `spike/local-models`, which already exists. Do not create another branch.
- Starting commit: `HEAD` of that branch when the orchestrator starts, recorded in `plan.md`.
- One commit per workstream, made by its lead at acceptance, containing the code, the workstream
  record and the lead's `plan.md` updates. The final-review lead makes one more.
- Commit subjects start with the workstream, such as `Local cleanup 2: MLX cleanup candidates`.
  End every commit message with the co-author line the harness specifies, if any.
- No document records an accepted workstream's commit hash; git holds it.
- Do not push. Do not open a pull request.

Respect a dirty worktree. Do not claim changes outside your ownership, and do not start a
workstream over unrelated uncommitted changes; escalate instead.

## Per-workstream loop

The lead runs these phases, updating its row in `plan.md` on each transition (`Implementing`,
`Review`, `Remediation`, `Closure review`, then `Accepted` or `Blocked`):

1. **Start.** Read this README, the packet, the source-of-truth documents it names and the
   handoffs of the workstreams it depends on. Confirm the tree is clean apart from expected
   orchestrator edits to `plan.md`, and record the base commit in the handoff.
2. **Implementation.** Spawn a fresh implementation agent with the implementation prompt.
3. **Independent review.** Spawn a different fresh agent with the review prompt.
4. **Remediation.** If any finding is accepted as Required, spawn one fresh implementation agent
   with the accepted findings. Tell it to revisit and simplify the affected design rather than
   add wrappers, flags, aliases or special cases that preserve a flawed first version.
5. **Closure.** Spawn a fresh reviewer with the closure prompt. It checks the accepted findings
   and their fixes for release-blocking defects only. There is no third loop.
6. **Accept and commit,** or block.

Findings are evidence, not instructions. Required means a correctness defect, unmet acceptance
criterion, boundary violation, meaningful regression or unjustified complexity. Optional never
blocks unless the lead promotes it. Questions need the lead's judgement before classification.

Every targeted verification command in the packet must pass before acceptance. A failure that
reproduces on the workstream's base commit is pre-existing: record it in the handoff and
continue. Otherwise a failure after closure blocks.

When a Required finding reflects a pattern later workstreams are likely to repeat, the lead adds
one line to the plan's conventions learned before committing.

### Implementation prompt

```text
Implement workstream <N> of the local cleanup workflow.

Read docs/spikes/local-models/implementation/cleanup/README.md, then <packet path>, the
source-of-truth documents it names, the handoffs of the workstreams it depends on, and the
conventions learned in plan.md. The task packet is frozen.

Make the smallest complete change that meets the acceptance criteria within the packet's
ownership. Run its targeted verification, not broader suites. Then do a deletion and
simplification pass: remove duplicated state, dead code, speculative machinery and tests coupled
to implementation details.

Write the Implementation handoff section of the packet file with facts the next agent needs, not
a diary. Do not commit. Reply with one line saying whether verification passed.
```

For remediation, add: "Address only these accepted findings: <list>. Revisit and simplify the
affected design. Update the Resolution section instead of the handoff."

### Review prompt

```text
Review workstream <N> of the local cleanup workflow independently.

Read docs/spikes/local-models/implementation/cleanup/README.md, <packet path>, the
source-of-truth documents it names and the conventions learned in plan.md. Inspect the
uncommitted diff (git diff and git status, including untracked files) and the code around it.

Check the acceptance criteria one by one, boundaries and ownership, correctness, lifecycle and
cancellation, and unjustified complexity. Run proportionate checks, including the packet's
targeted verification. Classify each finding as Required, Optional or Question, with evidence.

Write only the Independent review section of the packet file. Edit no other file. Reply with
the verdict in one line.
```

### Closure prompt

```text
Run focused closure review for workstream <N> of the local cleanup workflow.

Read docs/spikes/local-models/implementation/cleanup/README.md and <packet path>, including
the Independent review and Resolution sections. Verify that each accepted finding is fixed and
that the fixes introduce no release-blocking defect. Rerun the packet's targeted verification.
Do not start a new open-ended review or promote optional observations.

Write only the Closure review section. Reply with the verdict in one line.
```

## Interrupted work recovery

A lead that finds its row in a non-terminal state is recovering interrupted work. Before
continuing it:

1. Inspects the complete uncommitted diff, including untracked files.
2. Confirms the base commit and that every change belongs to this workstream's ownership.
3. Runs enough verification to establish the current state.
4. Continues from the earliest phase it cannot prove complete, reusing sound work and rerunning
   any review whose record is missing or partial.

Abandon partial work only when it cannot be attributed, sits on the wrong base, contradicts the
frozen packet, overlaps unrelated changes, or would be less safe to repair than to restart.
Preserve it first in a named stash or a `recovery/local-cleanup-<N>` branch. When ownership is
unclear, escalate rather than overwrite.

## External validation gates

One gate: the paid xAI cleanup baseline in workstream 4. Agents cannot run it, because the xAI
key lives in Aidan's Keychain and reading it may raise a macOS prompt only Aidan can answer.

- The lead places it after the local and Apple evaluation runs and before writing results.
- To open it, the lead writes the exact command and what to send back into its record's
  External validation section, adds an escalation entry to `plan.md`, sets its row to `Blocked`,
  leaves its work uncommitted and returns.
- The orchestrator puts the escalation to Aidan and records the answer, which names the run id.
  A fresh lead resumes the workstream with the uncommitted work and that answer.
- If the command fails, the resuming lead diagnoses it, corrects the bench if needed with the
  smallest change, and reopens the gate with a new candidate command. Diagnostic retries do not
  restart the workstream's review loop unless a correction changes approved behaviour, a public
  contract or another accepted workstream.

## Final whole-feature review

After every workstream is accepted, the orchestrator spawns one final-review lead with the
prompt below. It owns the Final row in `plan.md`, runs a whole-feature review against the
recorded starting commit, sends each accepted correction to a fresh implementation agent owning
those files, runs focused closure in a fresh session with the same brief, writes
[final-review.md](final-review.md) and commits. It blocks and returns exactly as a workstream
lead does.

## Lead prompts

### Workstream lead

```text
Lead workstream <N> of the local cleanup workflow.

Read docs/spikes/local-models/implementation/cleanup/README.md and <packet path>, then the
source-of-truth documents the README identifies. The task packet in that file is frozen.

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

You cannot reach the user. Block if a decision materially changes approved behaviour or
architecture, if disagreement persists after closure, or if an external validation gate needs
the user. To block, add an escalation entry to plan.md giving the decision needed, the options,
your recommendation, the evidence and what it unblocks, set your row to Blocked, leave the work
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

### Final-review lead

```text
Lead the whole-feature review of the local cleanup workflow.

Read docs/spikes/local-models/implementation/cleanup/README.md and
docs/spikes/local-models/implementation/cleanup/final-review.md, then the source-of-truth
documents the README identifies. Every workstream is accepted; the branch is complete.

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

## Completion report

After the Final row is accepted, report to Aidan:

- What was delivered, and the cleanup recommendation from `results.md` in one or two sentences.
- Verification run, and what passed.
- External validation still pending, from `plan.md`'s whole-feature acceptance.
- Specification drift from the decision and drift log.
- Optional observations deferred by the leads.
