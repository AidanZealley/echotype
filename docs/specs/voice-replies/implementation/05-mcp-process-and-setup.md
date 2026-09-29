# Workstream 5: MCP process and setup

Status: accepted, with parts of external validation gate B pending.

## Task packet

### Outcome

`EchoTypeApp --mcp` runs as an MCP stdio server that hands `speak` text to the running app, and
the README tells the user how to register it in each agent. The decision is recorded.

### Scope

Follow the specification's Implementation (App: entry point, delivery), Setup, and the Protocol
section's process behaviour.

- The `@main` app moves behind a small `main` that either runs the MCP stdio loop or calls
  `EchoTypeApp.main()`. The MCP process never creates an `NSApplication`, a hotkey monitor or a
  login item claim.
- The stdio loop reads newline-delimited messages, gives each to `MCPServer`, and writes any
  response line.
- Delivery finds a running app with bundle identifier `com.aidanzealley.echotype` and posts the
  text as workstream 4's distributed notification. With no app running it throws an error
  saying EchoType is not running, which `MCPServer` turns into a tool error.
- `README.md` gains the specification's Setup section, with the Claude Code and Codex
  registrations. T3 Code's line says the outcome of Gate B, or that it is unverified until then.
- A decision record `0022-voice-replies.md` and a row in `docs/decisions/README.md`, in the
  style of the existing records. Cover why EchoType sends, the agent summarises, and the server
  is hand-written and dual-era. Change the specification's Status line to describe what is
  implemented.

### Non-goals

- Changes to `MCPServer`, the notification name, `speak`, or sending. Escalate defects in them.
- New settings or launch flags beyond `--mcp`.

### Initial ownership

- `Sources/EchoTypeApp/App.swift` and a new entry file (`main.swift` or equivalent)
- A new file for the stdio loop and delivery in `Sources/EchoTypeApp`
- `README.md`, `docs/decisions/0022-voice-replies.md`, `docs/decisions/README.md`,
  `docs/specs/voice-replies.md` (Status line only)
- `Package.swift` only if the entry-point change needs it

### Required seams

Uses `MCPServer` (workstream 2) and the notification name (workstream 4).

### Acceptance criteria

- `EchoTypeApp --mcp` answers an `initialize` line and a `tools/call` line on stdin without
  opening any UI, and a normal launch is unchanged.
- The tool returns its error when the app is not running.
- The README commands use the installed app's executable path, as in the specification.
- The decision record and its index row exist, and the specification's Status line no longer
  says "Not implemented".
- `swift build` and `swift test` pass.

### Targeted verification

```sh
swift build
swift test
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}' \
  | .build/debug/EchoTypeApp --mcp
```

The last command should print an `initialize` result and exit at end of input.

### External validation gate B

Placement: after closure, before acceptance. The candidate is the branch installed with
`./scripts/install.sh`, run by the user. Checks, from the specification's Final gate:

- MCP in each agent: register the server in Claude Code and Codex, then check whether T3 Code
  picks it up for each harness it runs, and what it needs. Log the first message each client
  sends and report whether it opened with `initialize` or a modern request, and which version
  it named.
- Agent behaviour: in each agent, try "reply with EchoType", "respond with EchoType" and "read
  the whole response with EchoType, and don't summarise" on a prompt whose answer is long and
  includes code. The agent calls `speak` once, before its written reply (which is written in full). The first two speak about a
  fifth of the reply's length with no code read out. The third speaks the whole reply with
  each code block described in a sentence where it appears. Report the character count of each
  spoken text against the reply's length. If an agent misses `speak` or calls it twice in more
  than about 1 of 5 trials across the three wordings, add one line to that agent's global
  instruction file.
- Speaking: a reply is read with the `Reading` pill, Space pauses it, and the dictation hotkey
  stops it and starts a new dictation. A `speak` call during a dictation is dropped. With the
  app quit, the tool returns its error.

Evidence: a pass or fail per check, the logged first messages, and the character counts.
Record T3 Code's outcome in the README line.

## Implementation handoff

- Base commit: `dd74151`
- Outcome: `EchoTypeApp --mcp` runs the stdio loop and delivers `speak` text to the running app; README Setup, decision 0022 and its index row added; spec Status updated.
- Files changed: `Sources/EchoTypeApp/App.swift` (`@main` removed), `Sources/EchoTypeApp/main.swift`, `Sources/EchoTypeApp/MCPProcess.swift`, `README.md`, `docs/decisions/0022-voice-replies.md`, `docs/decisions/README.md`, `docs/specs/voice-replies.md` (Status line).
- Decisions: Delivery checks `NSRunningApplication` for `com.aidanzealley.echotype`, throws a `LocalizedError` ("EchoType is not running. Open it and try again."), and posts with `options: [.deliverImmediately]`. The loop skips blank lines. T3 Code's README line says unverified until Gate B. Spec Status now says implemented on the branch with Gate B pending. Lasting Gate B decisions: the agent calls `speak` once first, then writes its full reply unshortened (`MCPServer.speakGuidance`, spec and README say so; the user approved the reversal from "speak after the reply"). The send rule is left as is: the user did not answer the question, so option 1 stands and a phrase like "...the summary for the speak tool, using EchoType," can still send.
- Verification: `swift build` and `swift test` pass. The `initialize` line printed a result and the process exited at end of input. A `tools/call` line returned "Speaking." because an EchoType app was running here; the not-running error path was not exercised.
- Known limitations or external checks: Gate B items still pending, listed under External validation. The not-running error is unchecked in the real app.
- Specification drift: none.

## Independent review

- Reviewer: fresh Claude Code session via the review command (Opus 5.5, medium)
- Verdict: Changes required
- Required findings: decision record 0022 had no Consequences section; the not-running check was untested and the --mcp process might match itself.
- Optional observations: T3 Code README line used a plan term ("Gate B"); bundle identifier literal repeats Info.plist (left, spec names the literal); Status line wording may go stale after merge (left).
- Questions: whether to filter the process's own pid or rely on Gate B (answered: filter, and Gate B still checks it).

## Resolution

- Finding dispositions: both Required accepted and fixed in one remediation pass (Consequences section added; own pid excluded when finding the app). Optional 2 promoted (README wording now "not yet checked"). Other optionals rejected as nonessential.
- Simplification/deletion pass: nothing further to remove; `@main` gone from App.swift, no new flags or settings.
- Final verification: `swift build` and `swift test` pass; `--mcp` answers `initialize` and exits at end of input.

## Closure review

- Verdict: Accept (fresh session via the review command)
- Remaining required findings: none
- Cumulative correction after gate B (the `speakGuidance` rewrites): one focused review through the review command. Verdict Changes required on one stale line ("after the reply") inside the E5-1 escalation, which is removed at acceptance. A search found no other "after the reply" wording in code, tests, spec or README. Otherwise wording, code, spec and README agree.

## External validation

- Gate and placement: `B`, after closure and before acceptance
- Status: `Passed`, with items pending (below)
- Candidate and instructions: the uncommitted `voice-replies` worktree on top of the workstream 4 commit. The user builds and installs it with `./scripts/install.sh`, which replaces `/Applications/EchoType.app`. Register the server per the README "Voice replies" section in Claude Code and Codex, and find out what T3 Code needs. Test agents: T3 Code, Claude Code, Codex.
- Required evidence: a pass or fail per check, the logged first message from each client, and the character counts (see the escalation in plan.md for the concrete checks).
- Attempts and lasting decisions: attempt 1 (Codex only): failed check 2, the agent looked for an EchoType desktop app and missed `speak`. Correction: one sentence added to `MCPServer.speakGuidance` (tool description and instructions) and the spec's starting text. Targeted check: `swift build`, `swift test`. Retest 1 (Codex): trigger works, but the written reply was shortened. Correction 2: `speakGuidance` and the spec's starting text now say the written reply is unchanged and only the `speak` text is shortened. Targeted check: `swift build`, `swift test`. Retest 2: found the ordering defect (the `speak` turn hid the full reply), fixed by the user-approved reversal (call `speak` first, then write the full reply; `speakGuidance`, spec, README updated), and a send-rule false positive that the spec's rule permits (escalated, not edited). Claude Code missing the server on a first thread: cause unknown. Retest 3: passed for Codex and Claude Code. The spoken summary came first, the written reply was the normal full reply, no MCP tool was missed, and Claude's logged call was `mcp__echotype__speak` with a `text` argument returning "Speaking." Return timing was fine.
- Pending, not reported or waived by the user: T3 Code (the user could not connect it and is not checking, so the README line stays "not yet checked"), character counts (waived, revisit if length becomes an issue), first-message protocol logs (only the example call above), and speaking check 3 (Reading pill, Space pause, dictation hotkey stop, drop during dictation, not-running error). Gate A's unreported checks are listed in the plan.
- Accepted on this evidence: the core path works end to end in two agents, and the pending items are not defects seen. They stay pending on Gate B in the plan.
- Send rule: the user did not answer the question, so option 1 stands. `ReplyRequest` is unchanged and no test was added.
- Deferred observation: a settings button that connects the MCP server to the agent harnesses, instead of the README commands (user's idea, out of scope). Claude Code missing the server on a first thread stays unexplained; if it recurs, note whether the thread was open before `claude mcp add`.
