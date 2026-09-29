# Workstream 5: MCP process and setup

Status: not started.

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
  includes code. The agent calls `speak` once, after its reply. The first two speak about a
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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`

## External validation

- Gate and placement: `B`, after closure and before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: `TBD`
- Attempts and lasting decisions: `TBD`
- Resume condition: the user reports every check passing
