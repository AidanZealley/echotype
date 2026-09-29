# Workstream 2: MCP server

Status: not started.

## Task packet

### Outcome

`EchoTypeCore` has an `MCPServer` that speaks the specification's dual-era MCP protocol and
exposes the `speak` tool. It is tested without a process, a pipe or the app.

### Scope

Follow the specification's Protocol section and Tool description section.

- `MCPServer` handles one newline-delimited JSON-RPC message and returns the response line, if
  any. Suggestion: `init(deliver: @escaping (String) throws -> Void)` and
  `handle(_ line: String) -> String?`. The delivery is a closure so the server does not depend
  on the app.
- Modern: `server/discover`, `_meta` protocol version on every request, and
  `UnsupportedProtocolVersionError` (`-32022`) listing the supported versions.
- Legacy: `initialize` selects legacy semantics for the rest of the process, then
  `notifications/initialized` and `ping`.
- Both: `tools/list` returns `speak` with the specification's description and a schema
  requiring a string `text`. `tools/call` delivers the text and returns a short text result.
  A thrown delivery error becomes a tool error result carrying its message. Unknown methods get
  method-not-found. Every result carries `resultType: "complete"`.
- The description text and the `instructions` text are the specification's, from its Tool
  description section, kept as one constant.
- Hand-written, no dependency (the specification says why).

### Non-goals

- Reading stdin, the `--mcp` entry point, the notification or finding the running app.
  Workstream 5 owns them.
- Any file under `Sources/EchoTypeApp`.

### Initial ownership

- `Sources/EchoTypeCore/MCPServer.swift` (new, may split into a second new file)
- `Tests/EchoTypeCoreTests/MCPServerTests.swift` (new)

### Required seams

Provides `MCPServer` with a delivery closure. Workstream 5 constructs it with a closure that
posts to the app and throws when the app is not running.

### Acceptance criteria

- The specification's MCPServer tests exist and pass: a legacy exchange (`initialize`, then
  `tools/call`) and a modern one (`tools/call` with `_meta`) each deliver the text, and a
  modern request naming an unsupported version gets `-32022` with the supported list.
- A delivery that throws returns a tool error result with the thrown message.
- `server/discover` and `initialize` both return the instructions, and `tools/list` order is
  fixed.
- Nothing in the file imports AppKit or Foundation types beyond JSON handling.

### Targeted verification

```sh
swift test --filter MCPServerTests
swift build
```

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
