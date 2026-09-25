# Local install implementation workflow

Status: draft orchestration instructions. The developer must approve this workflow before execution.

This directory is the complete handoff for a fresh Codex orchestration agent. The final step of [EchoType v1](../../echotype-v1.md) is a release `install.sh` that installs the signed app in `/Applications`.

## Source of truth

Read this README and [plan.md](plan.md) to orchestrate. The workstream lead reads the [specification](../../echotype-v1.md), the [build-path decision](../../../decisions/0001-build-and-sign-on-the-mac.md), the [current signing decision](../../../decisions/0014-sign-with-apple-development.md), the [login item decision](../../../decisions/0013-test-button-and-system-rows.md), the [known gaps](../../../decisions/0007-known-gaps.md), repository instructions, and its [packet](01-local-install.md). Product documents override this workflow if they conflict.

## Roles and loop

- The orchestrator owns the integration branch, its base, workstream order, escalations and completion report. It reads only this README, `plan.md` and the leads' three-field returns. It does not read the specification, packets, diffs or findings.
- A workstream lead owns one packet through implementation, review, correction, acceptance and one commit. It ends at acceptance or blockage.
- An implementation agent makes the smallest complete change, runs the packet's targeted checks, simplifies the result, and writes the implementation handoff.
- A fresh independent reviewer inspects the diff and surrounding code. It edits only the review section of the packet. Findings are evidence: Required blocks acceptance; Optional does not; Question needs lead judgment.

The orchestrator reads `plan.md`, spawns a lead for the next row using only the packet path, waits once for its return, and continues or stops based on that return. After workstream 1 is accepted, it spawns the [final-review lead](final-review.md). Report to the developer at workstream acceptance, on an escalation and at completion. Do not narrate progress between those points.

## Lead return contract

The lead writes status in the plan table, drift in the decision and drift log, and escalation in the escalations section before committing or returning. The orchestrator does not copy the return into the plan. It writes only the branch and starting commit at the start, and the developer's answer in an escalation entry. Those writes join the next lead's commit.

```text
status: Accepted | Blocked
drift: <one line, or none>
escalation: <plan.md escalation id, or none>
```

## Agent spawning

This workflow explicitly requires Codex subagents. Spawn each with `fork_turns: "none"`; omit model and reasoning effort overrides. Wait for each in one long `wait_agent` call measured in minutes. Never busy-poll. Agents share a worktree, so only one implementation or review agent works at a time. The lead may spawn its reviewer only after implementation stops.

## Branch and commits

Create `codex/install-echotype-v1` from the approved current HEAD. Record the branch and starting commit in `plan.md`. Respect unrelated dirty changes; resolve overlapping state before starting. Keep implementation changes uncommitted through review and correction. At acceptance, the lead commits code, its packet record and plan changes once, with a subject naming the workstream. The final-review lead makes one separate commit. Documents do not record accepted commit hashes.

## Workstream lead procedure

1. Set the row to Implementing. Spawn a fresh implementation agent with the packet and source documents. Have it write the handoff and stop.
2. Set the row to Review. Spawn a different fresh agent to review the complete uncommitted diff. Have it write Required, Optional and Question findings in the packet.
3. Triage findings. If a required fix exists, set Remediation and send the implementation agent through one correction pass. It must revisit and simplify the affected design, rather than pile on wrappers or special cases.
4. Set Closure review. Spawn a fresh reviewer with the same brief to verify accepted fixes and check them for release-blocking defects. This is a focused check, not another open-ended review.
5. Run the [external validation gate](#external-validation-gate) after closure. Accept only when it passes. If unresolved required findings or a material scope decision remain, block with an escalation. There is no automatic third correction loop.
6. Write the resolution and closure sections, set Accepted, update the drift log, and make the single workstream commit.

Implementation prompt: "Read this README, the packet and its source documents. Implement the packet, run its targeted checks, simplify, and write only the implementation handoff. Leave changes uncommitted."

Review prompt: "Read this README, the packet and its source documents. Inspect the complete workstream diff and surrounding code. Run proportionate checks. Write the independent review with Required, Optional and Question findings backed by evidence. Do not edit implementation files."

Closure prompt: "Use the same review brief. Check accepted findings and their fixes for release-blocking defects. Write only the closure verdict. Do not restart open-ended review."

## Interrupted work recovery

A non-terminal row with no live lead is interrupted. Start a fresh lead for that row. It audits the full diff, confirms the base and ownership of every change, runs enough verification to establish current state, and resumes at the earliest phase it cannot prove complete. Reuse sound work; repeat undocumented conclusions or incomplete reviews. Abandon partial work only when its ownership or base is unclear, it contradicts the packet, it overlaps unrelated changes, or repair is less safe than restarting. Preserve it first in a named stash or recovery branch. Escalate unclear ownership rather than overwrite it.

## External validation gate

Gate G1 belongs to workstream 1 after closure and before acceptance. The candidate is the installed `/Applications/EchoType.app` built by `install.sh`. The lead can verify the release build, bundle signature, path, normal launch and settings behavior on the development Mac. A real login after sign-out or restart needs the developer to act. The lead records the candidate, instructions and local evidence in its packet, adds an escalation to `plan.md`, marks G1 Testing and its row Blocked, and returns the escalation id. The orchestrator asks the developer to confirm that enabling Launch at login from the installed app starts that installed app at the next login, and that disabling it stops doing so. The answer is recorded in the escalation entry before a fresh lead resumes.

If external testing finds a defect, the lead records the failure, makes the smallest correction, reruns agent-accessible checks and offers a new candidate. It does not restart the implementation and review loop for ordinary diagnostics. Reopen focused review when a correction changes approved behavior, architecture, ownership, security or privilege boundaries, persisted data, a public contract, or accepted work elsewhere. Once G1 passes, review meaningful unreviewed changes once and record the final evidence. A gate needing the developer's action returns Blocked; elapsed time never counts as approval.

## Final whole-feature review

After workstream acceptance, the orchestrator spawns a final-review lead. It gets a fresh reviewer for the full branch against the starting commit, triages findings, assigns accepted corrections to fresh implementation agents by file ownership, and runs focused closure in a fresh review session. It owns the Final row and follows the same three-field return and escalation rules.

## Completion report

Report the installed behavior, checks run, G1 result, specification drift and deferred Optional findings.
