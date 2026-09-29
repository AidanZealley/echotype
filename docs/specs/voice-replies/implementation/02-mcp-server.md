# Workstream 2: MCP server

Status: accepted.

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

- Base commit: `6e33111`
- Outcome: `MCPServer` in `EchoTypeCore` speaks both protocol eras and exposes `speak`. Tested without a process, pipe or app.
- Files changed: `Sources/EchoTypeCore/MCPServer.swift` (new), `Tests/EchoTypeCoreTests/MCPServerTests.swift` (new). Status line at the top not edited.
- Decisions: `MCPServer` is a final class with `init(deliver:)` and `handle(_:) -> String?`; it is hand-written over `JSONSerialization` (Foundation JSON only). The description and `instructions` are one constant, `MCPServer.speakGuidance`. `initialize` sets legacy mode, which skips version checks afterwards; otherwise a request naming an unsupported `_meta` version gets `-32022` with `data.supported` and `data.requested`. A request with no `_meta` version and no prior `initialize` is served rather than rejected. Messages without an `id` get no response. `tools/call` with a bad name or missing `text` returns a tool error result. `ttlMs` is 3,600,000 and `cacheScope` is `public` (the spec allows only `public` or `private`), defined once as `MCPServer.cacheHints` and merged into the discover and tools/list results. The `-32022` error data shape and the ttl values are my choices, not the spec's.
- Verification: `swift test --filter MCPServerTests` (4 tests pass); `swift build` succeeds.
- Known limitations or external checks: Real clients' first message and version are unchecked until the final gate.
- Specification drift: None.

## Independent review

- Reviewer: fresh `claude -p` session, Opus 5.5, medium reasoning, read-only
- Verdict: Changes required
- Required findings: (1) `cacheScope: "shared"` is not a valid MCP value (only `public` or `private`), in the discover and `tools/list` results.
- Optional observations: (2) non-`LocalizedError` delivery errors give a generic message, so workstream 5's closure should throw a `LocalizedError`; (3) a wrong tool name gets the `text` message rather than `-32602`; (4) the test `Delivered` helper class is unneeded; (5) version constants could be `private`; (6) blank lines get a `-32700` error, so workstream 5 should skip empty lines.
- Questions: (7) requests with no `_meta` version and no prior `initialize` are served.

## Resolution

- Finding dispositions: 1 accepted and fixed by a fresh remediation pass (`public`, with `ttlMs` and `cacheScope` defined once as `cacheHints`, plus a test assertion). 2 and 6 are carried to workstream 5 as notes: its delivery closure throws a `LocalizedError`, and its stdin loop skips blank lines. 3, 4 and 5 rejected as optional and nonessential with one tool and no external callers. 7 accepted: serving a versionless request costs nothing, covers a legacy client that pings before `initialize`, and the specification is silent.
- Simplification/deletion pass: one guidance constant, one state flag (`isLegacy`), no dependency, no dead code. The duplicated cache hints were merged in remediation.
- Final verification: `swift test --filter MCPServerTests` (4 tests) and `swift build` pass.

## Closure review

- Verdict: Accept (fresh session, Opus 5.5, medium reasoning)
- Remaining required findings: none
