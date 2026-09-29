# Debug window implementation workflow

Status: draft orchestration instructions.

This directory is the handoff for a fresh orchestration agent. The workstreams run
sequentially because the app consumes the Core trace contract.

## Source of truth

Read the repository instructions supplied by Aidan, [the approved specification](../../specs/debug-window.md),
the relevant [decisions](../../decisions/README.md), this README and [the plan](plan.md).
Product documents override this workflow. The orchestrator reads only this README,
`plan.md` and lead returns. It never reads the specification, packets, diffs or findings.
Leads and their agents read the source documents and their packets.

## Roles and ownership

- The orchestrator owns the integration branch, starting commit, dependency order,
  escalations and completion report. It does not implement or review code.
- A disposable lead owns one workstream from its frozen packet to acceptance or a
  blocked return. It makes the terminal decision.
- A fresh implementation agent writes the assigned code, checks it, simplifies it and
  records its handoff. The same agent may make one remediation pass.
- A separate fresh reviewer inspects the uncommitted diff and surrounding code. It
  records Required defects, Optional improvements and Questions with evidence, and
  edits no implementation files. Findings are evidence for the lead to triage.

Do not edit the shared worktree concurrently. Use one lead at a time.

## Orchestrator loop

Read `plan.md`, then spawn the next workstream lead using the lead prompt below and
pass only its packet path. Read its return only to continue or stop; its row, drift and
escalation are already in the plan. After workstreams 1 and 2 are accepted, spawn the
final-review lead. Report to Aidan only at workstream acceptance, on escalation, and
in the completion report. Do not narrate progress between those points.

The orchestrator writes only the branch and starting commit at the start, and Aidan's
answer in an escalation entry. These changes are picked up by the next lead's commit.
If a row is non-terminal with no live lead, treat it as interrupted and start a fresh
lead for that same packet. A fresh orchestrator must be able to resume from `plan.md`
alone.

## Lead return contract

Before returning, the lead writes status in its plan row, drift in the decision and
drift log, and any escalation in the escalations section. At acceptance these updates
join the lead's one commit. On a block the work remains uncommitted. The orchestrator
does not transcribe the return.

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Spawning and waiting

This workflow explicitly requires delegation to subagents. In Codex, use
`spawn_agent` with `fork_turns: "none"`; omit `model` and `reasoning_effort`. Wait for
each agent with one long `wait_agent` call measured in minutes, never repeated short
polls. In Claude Code, use `Agent` with `subagent_type: general-purpose` and
`run_in_background: false`; omit `model`. Agents inherit the parent's model and effort.

## Branch and commits

Create the integration branch recorded in `plan.md` from the approved HEAD and record
that starting commit there. Keep each workstream's code uncommitted through review and
remediation so the reviewer sees one coherent diff. At acceptance the lead makes one
commit containing code, its record and its plan updates. Use a subject naming the
workstream, for example `Add debug trace core (workstream 1)`. Git holds commit hashes;
do not write accepted commit hashes into these documents. Resolve unrelated dirty
worktree state before starting a lead.

## Workstream loop

The lead updates its row at each transition: `Implementing`, `Review`,
`Remediation` if needed, `Closure review`, then `Accepted` or `Blocked`.

1. Give a fresh implementation agent the packet path, the source documents and
   accepted dependency handoffs. It implements, runs the packet's targeted checks,
   removes needless state and wrappers, and fills the implementation handoff.
2. Give a different fresh reviewer the same packet, the uncommitted diff and relevant
   code. It records an independent verdict and categorized findings in the packet.
3. Triage findings. If required, order at most one remediation pass from the
   implementation agent. Ask it to revisit and simplify the affected design, rather
   than preserve a flawed first pass with aliases, flags or special cases.
4. Run focused closure in a fresh review session with the same brief. It verifies
   accepted fixes and checks for release-blocking defects in them. It does not start
   another open-ended review or promote optional suggestions.
5. Accept and commit, or block. Escalate only when disagreement persists after closure
   or a decision changes approved behavior or architecture. Workstream 2 also has an
   external Mac gate after closure and before acceptance.

Implementation prompt: `Implement <packet path> against the approved spec and accepted
handoffs. Edit only your assigned ownership, run targeted checks, simplify the diff,
and fill the implementation handoff. Leave all changes uncommitted.`

Review prompt: `Independently review <packet path> and the full uncommitted diff against
the approved spec and surrounding code. Run proportionate checks. Edit only the
Independent review section. Classify evidence as Required, Optional or Question.`

Closure prompt: `Review the accepted findings and cumulative fixes for <packet path>
in a fresh session. Verify the fixes and check them for release-blocking defects. Edit
only the Closure review section; do not restart open-ended review.`

## Interrupted work recovery

An incoming lead with a non-terminal row audits the complete diff, checks its base and
every changed file's ownership, verifies enough to establish the current state, then
continues from the earliest phase it cannot prove complete. Reuse sound work. Rerun an
undocumented conclusion or partial review. Abandon partial work only when attribution
is unsafe, the base is wrong, the packet is contradicted, unrelated changes overlap,
or repair is less safe than restart. First preserve it in a named stash or recovery
branch. Escalate unclear ownership instead of overwriting it.

## External Mac validation

Workstream 2 owns gate G1 after focused closure and before acceptance. The candidate is
the signed development build from `./scripts/run.sh --debug`. Its record must state
the branch/head being checked, the steps from the spec's Final gate, and the evidence
for each result. The agent may run what its Mac access permits. If microphone, xAI,
desktop focus or theme inspection requires Aidan, the lead records the candidate and
missing evidence, adds an escalation, sets its row to `Blocked`, and returns. The
orchestrator asks Aidan and writes his answer into that escalation. A fresh lead then
resumes the uncommitted candidate.

For a gate failure, record the failing step and diagnostic evidence, make the smallest
correction, run proportionate checks, and test another candidate. This troubleshooting
does not restart the implementation/review loop. Reopen it only if the correction
changes approved behavior, architecture, ownership, security or privilege boundaries,
persistent data, a public contract or an accepted workstream. Review meaningful
unreviewed fixes once before acceptance. The gate passes when all required Mac checks
have evidence; do not infer passage from `swift test`.

## Final whole-feature review

After both workstreams are accepted, a final-review lead owns the Final row. A fresh
reviewer audits the whole branch against the starting commit and approved spec. The
lead triages findings, gives accepted corrections to fresh implementation agents by
file owner, and runs focused closure in another fresh session. It writes
`final-review.md` and makes one commit. It uses the same return and escalation rules.

## Completion report

Report delivered behavior, verification, any pending external check, specification
drift and deferred optional observations. Do not claim the Mac gate passed without
recorded evidence.

## Lead prompts

Workstream lead:

```text
Lead workstream N of the debug window. Read docs/debug-window/implementation/README.md
and the numbered packet path supplied to you, then its source-of-truth documents. The
packet is frozen. Run the README's bounded implementation, independent review, one
remediation pass if needed, and fresh focused closure loop. Own triage and the terminal
decision. A reviewer gives evidence, not instructions. At acceptance fill your record,
set your plan row to Accepted, log drift and make one commit with code and records.
You cannot reach the user. If a decision materially changes approved behavior or
architecture, disagreement persists after closure, or G1 needs the user, write a
concise plan escalation with decision, options, recommendation, evidence and what it
unblocks. Set your row to Blocked and leave changes uncommitted. On resuming a blocked
row, record the user's lasting decision in your handoff and downstream plan log before
removing the escalation. On an interrupted row, follow the README recovery rules.
Return exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

Final-review lead:

```text
Lead the whole-feature review of the debug window. Read
docs/debug-window/implementation/README.md and final-review.md, then their
source-of-truth documents. Spawn a fresh whole-feature reviewer against the starting
commit in plan.md. Triage findings, give accepted corrections to fresh implementation
agents by file owner, and run focused closure in a fresh review session. Own the
terminal decision. At acceptance fill final-review.md, set the Final row to Accepted,
log drift and make one commit containing corrections and records. To block, write a
concise plan escalation, set the Final row to Blocked, leave changes uncommitted and
return its id. Return exactly:
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```
