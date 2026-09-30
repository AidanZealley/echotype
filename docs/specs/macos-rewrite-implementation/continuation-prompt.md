# Resume the EchoType macOS lifecycle rewrite

Resume the approved workflow paused at Aidan's request after workstream 3 acceptance.
This instruction resumes execution; do not request workflow approval again.

1. Read `docs/specs/macos-rewrite-implementation/README.md` and `plan.md`.
   As orchestrator, read only those files and lead returns, plus a named plan escalation
   when a lead blocks. Do not read the specification, packets, diffs or findings.
2. Confirm the recorded branch `refactor/macos-lifecycle` and inspect worktree status.
   Preserve unrelated work. Keep the recorded starting commit and existing accepted work.
   Read `git show HEAD:docs/specs/macos-rewrite-implementation/plan.md` to confirm durable
   acceptance. At this handoff, workstreams 1 through 3 are committed Accepted;
   workstream 4 is next and Not started. No implementation lead remains active.
3. Use the README's workstream lead prompt and pass only the next dependency-ready
   packet path. Start with `docs/specs/macos-rewrite-implementation/04-reading.md`
   if the plan still records this handoff state. Assign exclusive file/state ownership.
   Every Codex agent spawn must use `fork_turns: "none"`, with no model or
   reasoning-effort override. Wait in a blocking call measured in minutes.
4. Continue the README's sequential loop through workstreams 4, 5 and 6, then its
   final-review lead. Leads own records, triage, gates and acceptance commits.
   Recover interrupted non-terminal rows and uncommitted acceptance before advancing.
   Verify each Accepted row in HEAD's committed plan without inspecting diffs.
5. On Blocked, read only the named escalation, surface the concrete decision or Mac
   action, record Aidan's answer there and spawn a fresh lead for that row. Honour
   approvals and deferrals already recorded in the plan, keeping unverified evidence
   explicit. The Test allowance is consumed; other live authority is bounded and
   cumulative. Further live tests require appropriate recorded authority. Coordinate
   desktop focus changes and candidate restarts during idle time so they do not
   interfere with Aidan's dictation.
6. Aidan requested concise written and EchoType-spoken summaries of meaningful plan
   changes. Summarise changed phases, acceptance and escalations; avoid repeated
   unchanged-status messages or routine queries to running agents. Call EchoType's
   MCP `speak` tool once per summary before the written update. Follow higher-priority
   harness requirements for updates and waits.

Complete only after Final is durably Accepted. Report behavior, verification, approved
pending external evidence, drift and deferred observations from the plan's Completion
summary. Do not claim deferred checks passed.
