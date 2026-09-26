# Read aloud implementation workflow

Status: draft orchestration instructions. Aidan must approve this workflow before execution.

This directory is the complete handoff for a fresh Claude Code orchestration agent. It adds read
aloud: select text in any app, press a hotkey, and EchoType reads it in a Grok voice. Run it on
the Mac: the package targets macOS only, so `swift build` and `swift test` do not run elsewhere.

## Source of truth

The orchestrator reads this README, [plan.md](plan.md) and the lead prompts in
[starter-prompt.md](starter-prompt.md) only.

Leads and their agents read the [specification](../../read-aloud.md), the
[settings storage decision](../../../decisions/0010-settings-storage-and-api-key.md), the
[overlay behaviour decision](../../../decisions/0009-overlay-behaviour.md), the
[decisions index](../../../decisions/README.md) for the record format, and their packet. Once
workstream 1 has written it, decision 0018 records the spike and says how audio is fetched.
Product documents override this workflow if they conflict.

## Roles

- The **orchestrator** owns the integration branch, its base, workstream order, escalations and
  the completion report. It reads only this README, `plan.md`, the lead prompts in
  `starter-prompt.md` and the leads' three-field returns. It never reads the specification, a
  packet, a diff or a finding.
- A **workstream lead** owns one packet from the frozen task to one accepted commit. It interprets
  the specification for its workstream, spawns the implementation agent and the reviewers,
  triages findings, owns the terminal decision, writes the record and commits. It ends when it
  accepts or blocks. It cannot reach Aidan.
- An **implementation agent** makes the smallest complete change, runs the packet's targeted
  verification, does a deletion and simplification pass, and writes the implementation handoff.
  It leaves the search for defects beyond its acceptance criteria to the reviewer.
- An **independent reviewer** is a fresh agent. It inspects the workstream diff and surrounding
  code, runs proportionate checks, and writes only its review section of the packet. It never
  edits implementation files. Findings are evidence, not instructions:
  - **Required:** a correctness defect, unmet acceptance criterion, boundary violation,
    meaningful regression or unjustified complexity. Blocks acceptance.
  - **Optional:** useful but out of scope or nonessential. Never blocks unless the lead promotes it.
  - **Question:** an ambiguity the lead must judge before classifying.

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

Only one agent edits the shared worktree at a time. A lead spawns its reviewer only after the
implementation agent has returned.

## Orchestrator loop

1. Read `plan.md`. Spawn a lead for the first row that is not `Accepted`, passing only its packet
   path, using the workstream lead prompt in [starter-prompt.md](starter-prompt.md).
2. Read the return only to decide whether to continue or stop. On `Accepted`, report the
   acceptance to Aidan and go to step 1. On `Blocked`, read only the named escalation entry in
   `plan.md`, put its question to Aidan, record the answer in that entry, and start a fresh lead
   for the same workstream.
3. After workstream 2 is accepted, spawn the final-review lead with the final-review lead prompt.
   Then write the completion report.

Workstream 1's first lead blocks at once on gate G1, the spike, because its result decides what
workstream 1 builds. That is expected.

A row left in a non-terminal state with no live lead is interrupted. Start a fresh lead for that
workstream and tell it to follow [interrupted work recovery](#interrupted-work-recovery).

Report to Aidan at workstream acceptance, on an escalation, and in the completion report. Nothing
else. `plan.md` is the live status view; leads update their own row on every transition.

## Lead return contract

Every lead, including the final-review lead, returns exactly:

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Each field has one home in `plan.md`, written by the lead before it commits or returns: status in
the workstream table, drift in the decision and drift log, escalation in the escalations section.
The orchestrator records none of them. It writes only the branch and starting commit at the start,
and Aidan's answer in an escalation entry. Those edits stay uncommitted until the next lead's
commit picks them up.

## Agent spawning

This workflow runs on Claude Code. Spawn every agent with the `Agent` tool using
`subagent_type: general-purpose` and `run_in_background: false`, so the call blocks until the agent
returns. Omit `model`; agents inherit the orchestrator's model and effort. Never busy-poll a running
agent: no `TaskOutput` or `BashOutput` checks and no scheduled wake-ups.

## Branch and commit model

- Integration branch: `feat/read-aloud`, created from the approved HEAD. The orchestrator records
  the branch and starting commit in `plan.md`.
- Respect unrelated dirty changes. Resolve overlapping state before a workstream starts.
- Implementation changes stay uncommitted through implementation, review and remediation, so each
  reviewer sees one coherent diff.
- At acceptance the lead makes one commit containing the code, its packet record and its
  `plan.md` updates. Subject: `Read aloud NN: <workstream name>`, or
  `Read aloud final: whole-feature review`.
- No document records an accepted workstream's commit hash.

## Per-workstream loop

The lead runs these phases and sets its `plan.md` row at each transition.

1. **Start.** Confirm the branch, a clean tree apart from orchestrator edits to `plan.md`, and
   that dependencies are `Accepted`. Workstream 1 also needs G1 `Passed`; see
   [external validation gates](#external-validation-gates). Set the row to `Implementing`.
2. **Implementation.** Spawn a fresh implementation agent with the implementation prompt. It
   writes the implementation handoff and returns.
3. **Independent review.** Set `Review`. Spawn a different fresh agent with the review prompt.
4. **Remediation.** Triage every finding in the Resolution section. If any Required finding is
   accepted, set `Remediation` and spawn a fresh implementation agent with the remediation prompt
   for one pass. Skip this phase when nothing is accepted.
5. **Closure.** Set `Closure review`. Spawn a fresh reviewer with the closure prompt. There is no
   automatic third loop. If a Required finding remains and you judge it valid, or it needs a
   decision that changes approved behaviour or architecture, block.
6. **External validation.** Workstream 2 runs gate G2 here.
7. **Accept and commit.** Complete the Resolution section, set the packet status and the row to
   `Accepted`, add drift to the decision and drift log, and make the one commit.

To block, add an escalation entry to `plan.md` with the decision needed, realistic options, your
recommendation, the evidence and what it unblocks, in a handful of lines. Set the row to
`Blocked`, leave the work uncommitted, and return the entry's id. Summarise; never paste findings
or diffs.

A lead resuming a blocked workstream inherits its uncommitted work and the answered entry. Before
accepting, it copies the lasting decision into the handoff's Decisions field, and into the
decision and drift log when a later workstream or the final review depends on it, then removes
the entry.

### Implementation prompt

```text
Read docs/specs/read-aloud/implementation/README.md, then <packet path> and the source-of-truth
documents the README names. The task packet is frozen.

Implement the packet with the smallest complete change. Run its targeted verification and add the
new tests it names. Then do a deletion and simplification pass over your diff. Write only the
Implementation handoff section of the packet: facts the next agent needs, not a diary. Leave all
changes uncommitted.
```

### Review prompt

```text
Read docs/specs/read-aloud/implementation/README.md, then <packet path> and the source-of-truth
documents the README names.

Review the complete uncommitted diff and the code around it against the packet's acceptance
criteria and the specification. Run proportionate checks. Write only the Independent review
section of the packet, with Required, Optional and Question findings, each backed by evidence
such as a file and line, a command and its result, or a quoted requirement. Do not edit
implementation files.
```

### Remediation prompt

```text
Read docs/specs/read-aloud/implementation/README.md, then <packet path>, including the review and
the lead's dispositions in Resolution.

Fix only the findings the lead accepted. Revisit and simplify the affected design rather than
adding wrappers, flags, compatibility paths or special cases to preserve a flawed first version.
Rerun the targeted verification. Append what changed to the Implementation handoff. Leave all
changes uncommitted.
```

### Closure prompt

```text
Read docs/specs/read-aloud/implementation/README.md, then <packet path>.

Use the same review brief as the independent review. Check that each accepted finding is fixed
and that the fixes introduce no release-blocking defect. Do not restart an open-ended review or
promote Optional observations. Write only the Closure review section.
```

## Interrupted work recovery

A lead that finds its row in a non-terminal state is recovering interrupted work. Before
continuing it:

1. Inspects the complete uncommitted diff and confirms it sits on the recorded base.
2. Confirms every change belongs to this workstream's ownership.
3. Runs enough verification to establish the current state.
4. Continues from the earliest phase it cannot prove complete. It reuses sound work and reruns any
   review whose conclusion is not recorded.

Abandon partial work only when it cannot be safely attributed, sits on the wrong base,
contradicts the frozen packet, overlaps unrelated changes, or would be less safe to repair than
redo. Preserve it first in a stash or branch named `recovery/read-aloud-NN`. When ownership is
unclear, escalate instead of overwriting.

## External validation gates

Two gates need Aidan. Agents cannot hear audio, and the spike needs his API key in a shell.

### G1: the spike, before workstream 1's implementation

The specification's Spike section decides whether reading fetches audio over REST or the
WebSocket, which `optimize_streaming_latency` setting it uses, and whether `text_normalization`
is on. Workstream 1 builds whichever the spike chooses, so nothing starts until it passes.

The first workstream 1 lead:

1. Adds an escalation entry asking Aidan to run the Spike section of `docs/specs/read-aloud.md`
   on the Mac and report four facts: whether REST streams (with the timestamps of the request,
   the headers, the first and the last audio bytes), the time to first audio with and without
   `optimize_streaming_latency`, the setting he wants, and whether `text_normalization` is on.
2. Sets G1 to `Testing` in `plan.md`, sets its row to `Blocked`, and returns.

The resuming lead checks the answer covers all four facts, sets G1 to `Passed`, and gives the
implementation agent the answer through the packet: the agent writes decision 0018 from it before
writing code. If the answer is incomplete or ambiguous, block again with a narrower question
rather than guessing. If the results fit neither branch the specification describes, that changes
the design: block with options.

### G2: reading on the Mac, after workstream 2's closure

G2 proves the finished candidate; nothing in the implementation waits on it. The lead:

1. Launches the candidate with `./scripts/run.sh` and records in the packet's External validation
   section the base, the fact that the running app is the current diff, and the steps: 2 to 7 of
   the specification's "Checking it on the Mac", plus the Read Aloud tab's three settings and the
   60,000-character message if Aidan has a long enough selection to hand.
2. Adds an escalation entry asking for pass or fail on each step and the time to first audio,
   sets G2 to `Testing`, sets its row to `Blocked`, leaves the work uncommitted and returns.

If G2 fails, the resuming lead sets G2 to `Troubleshooting`, records the failure, makes the
smallest correction, reruns agent-accessible checks and offers a new candidate through another
escalation. This does not restart the implementation and review loop. Reopen a focused review
only when a correction changes approved behaviour, architecture, persisted settings, a public
`EchoTypeCore` contract, or accepted workstream 1 code.

When G2 passes, set it to `Passed`, review any meaningful unreviewed change once, record the final
evidence and accept. Collapse superseded attempts once they no longer explain a decision.

## Final whole-feature review

After workstream 2 is accepted, the orchestrator spawns one final-review lead with
[final-review.md](final-review.md). It spawns a fresh reviewer for the whole branch against the
starting commit, triages findings, sends each accepted correction to a fresh implementation agent
owning the affected files, and runs focused closure in a fresh review session with the same brief.
It owns the Final row and follows the same return, escalation and commit rules as a workstream
lead.

## Completion report

Report to Aidan, briefly:

- What read aloud now does, and how audio is fetched (REST or WebSocket, from decision 0018).
- Verification run, including the `swift test` count.
- G1 and G2 results, including the time to first audio.
- Specification drift from the decision and drift log.
- Deferred Optional observations worth knowing about.
- That the branch is ready to merge, and that `./scripts/install.sh` puts it in `/Applications`.
