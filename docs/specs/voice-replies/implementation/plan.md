# Voice replies implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `voice-replies`
- Starting commit: `d451a6f`
- Review command: `claude -p "<prompt>" --permission-mode plan --model claude-opus-5-5 --effort medium`
- Specification approved at commit: `5dac92c`
- Started: `2026-09-29`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Reply request rule, keyterm and setting](01-reply-request-core.md) | Approved spec | Accepted |
| 2 | [MCP server](02-mcp-server.md) | Approved spec | Accepted |
| 3 | [Sending a reply request](03-sending.md) | 1 | Accepted |
| 4 | [Speaking in the app](04-speaking.md) | 2 | Not started |
| 5 | [MCP process and setup](05-mcp-process-and-setup.md) | 2, 4 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-5 | Not started |

## Why these boundaries

- 1 and 2 are pure `EchoTypeCore` code with `swift test` coverage, so they finish without the
  app or a Mac session. 1 holds the send rule and keyterm, and 2 holds the MCP protocol.
- 3 is the whole sending slice in the app: the controller, `Inserter`, and the two settings
  screens. It needs only 1.
- 4 and 5 split speaking at its process boundary. 4 makes the running app read text handed to
  it. 5 is the separate `--mcp` process that hands it text, plus setup docs. 4 leaves the app in
  a shippable state, since nothing posts to it yet.
- The order is 1, 2, 3, 4, 5. 3 and 4 both change `DictationController` and run one after the
  other.

## Cross-workstream contracts

- `ReplyRequest.matches(_ committed: String) -> Bool` (1, used by 3).
- `STTConnection.maximumSavedKeyterms` is 99 (1, used by 3's Keyterms tab).
- `Settings.sendReplyRequests: Bool`, default true (1, used by 3).
- `MCPServer` takes its delivery as a closure and handles newline-delimited JSON-RPC messages
  (2, used by 5). A thrown delivery error becomes a tool error result carrying its message.
- The distributed notification that carries text to the app: its name and the `text` user-info
  key live in `EchoTypeCore` (4 defines them, 5 posts them).
- Bundle identifier `com.aidanzealley.echotype` identifies the running app (5).
- A change to any of these is an escalation, not an edit by a later workstream.

## Ownership handoffs

- `Sources/EchoTypeApp/DictationController.swift`: 3 adds sending, then 4 adds `speak`.
- `Sources/EchoTypeApp/Views/SettingsView.swift`: 3 only.
- `Sources/EchoTypeApp/App.swift` and the new `main` entry: 5 only.
- `Sources/EchoTypeCore/Reviser.swift`: 1 moves the shared word and sentence helpers out of it.

## Whole-feature acceptance

- `swift test` and `swift build` pass.
- Every behaviour in the specification is present, and nothing beyond it.
- Gates A and B have passed, or the completion report lists what is still pending.

## External validation gates

| Gate | Workstream | Placement | Status |
|---|---|---|---|
| A. Sending, Return timing, keyterm | 3 | After closure, before acceptance | Passed; per-app timing, mention-without-phrase and Keyterms tab 99 unreported |
| B. MCP in each agent, agent behaviour, speaking | 5 | After closure, before acceptance | Pending |

Gate A covers the specification's Final gate items Sending, Return timing and Keyterm. Gate B
covers MCP in each agent, Agent behaviour and Speaking. The user runs both on the Mac with the
installed app. Gate B needs the app from workstream 5, so it is the first time the whole path
runs end to end.

## Escalations

Empty until a lead blocks. One entry per escalation. The lead that resolves one records its
lasting decision in the workstream handoff, and in the decision and drift log when later
workstreams depend on it, then removes the entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-29 | Notes for workstream 5, not drift: `MCPServer.handle` answers a blank line with a `-32700` error, so the stdin loop skips empty lines. Delivery errors surface through `localizedDescription`, so the delivery closure throws a `LocalizedError`. | Found in workstream 2 review | Lead 2 | 5 |
| 2026-09-29 | Gate A accepted with three checks unreported (per-app Return timing in T3 Code, Claude Code and Codex, mention-without-phrase, Keyterms tab showing 99). `returnDelay` stays 200 ms for all apps. Not drift. | User's answer covered the core checks and no app needed longer | Lead 3 | 4, 5, Final |
