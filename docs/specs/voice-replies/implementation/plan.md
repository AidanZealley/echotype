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
| 4 | [Speaking in the app](04-speaking.md) | 2 | Accepted |
| 5 | [MCP process and setup](05-mcp-process-and-setup.md) | 2, 4 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-5 | Accepted |

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
  key live in `EchoTypeCore` (4 defines them, 5 posts them). The poster must post with
  `options: [.deliverImmediately]`, or the system holds the notification while the menu bar app
  is inactive.
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
| B. MCP in each agent, agent behaviour, speaking | 5 | After closure, before acceptance | Passed for Codex and Claude Code (retest 3); pending: T3 Code, first-message protocol logs, character counts, speaking check 3 (Reading pill, Space pause, hotkey stop, drop during dictation, not-running error) |

Gate A covers the specification's Final gate items Sending, Return timing and Keyterm. Gate B
covers MCP in each agent, Agent behaviour and Speaking. The user runs both on the Mac with the
installed app. Gate B needs the app from workstream 5, so it is the first time the whole path
runs end to end.

## Escalations

None open.

One entry per escalation. The lead that resolves one records its
lasting decision in the workstream handoff, and in the decision and drift log when later
workstreams depend on it, then removes the entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-29 | Notes for workstream 5, not drift: `MCPServer.handle` answers a blank line with a `-32700` error, so the stdin loop skips empty lines. Delivery errors surface through `localizedDescription`, so the delivery closure throws a `LocalizedError`. | Found in workstream 2 review | Lead 2 | 5 |
| 2026-09-29 | Gate A accepted with three checks unreported (per-app Return timing in T3 Code, Claude Code and Codex, mention-without-phrase, Keyterms tab showing 99). `returnDelay` stays 200 ms for all apps. Not drift. | User's answer covered the core checks and no app needed longer | Lead 3 | 4, 5, Final |
| 2026-09-29 | Workstream 5 must post the speak notification with `deliverImmediately` (recorded in the cross-workstream contracts; its frozen packet does not say so). The receiver cannot do this itself without a heavier selector-based observer. Not spec drift. | Found in workstream 4 review and closure | Lead 4 | 5 |
| 2026-09-29 | Tool description and server instructions (`MCPServer.speakGuidance`, workstream 2) gained one sentence saying the tool is what "EchoType" means in "reply with EchoType" and that there is no app to open; the spec's starting text updated to match. Same handling, no protocol or contract change. | Gate B: Codex did not connect the phrase to `speak` on its first trial | Lead 5 | 2, 5 |
| 2026-09-29 | `MCPServer.speakGuidance` gained wording that the written reply is unchanged and only the `speak` text is shortened; the spec's starting text and summary bullet updated to match. Same handling, no protocol or contract change. | Gate B retest 1: Codex shortened its written reply as if summarising | Lead 5 | 2, 5 |
| 2026-09-29 | Ordering reversed: the agent calls `speak` once first, with the spoken text only in its argument, then writes the full reply as the final message. Spec, `MCPServer.speakGuidance`, README and packet updated; the wording says which text goes where. Overrides the spec's "speak after the reply". | Gate B retest 2: with `speak` last, its turn became the final message and hid the full reply | User (E5-1) | 2, 5 |
| 2026-09-29 | Send rule: "...the summary for the speak tool, using EchoType," matched `ReplyRequest.matches` as the spec's rule reads (`speak` counted as a verb, `using EchoType` as the name). Not a code defect, so no edit; escalated in E5-1. | Gate B retest 2 | Lead 5 | 3 |
| 2026-09-29 | Lasting Gate B decisions: the agent calls `speak` once first, then writes its full reply (already logged above); the send rule is left as is (option 1), so "...the summary for the speak tool, using EchoType," can still send. Nothing changed in `ReplyRequest`. | User did not answer the send-rule question after retest 3, so option 1 stands | User (E5-1), Lead 5 | 3, 5, Final |
| 2026-09-29 | Gate B accepted with items pending: T3 Code (README line stays unverified), first-message protocol logs, character counts (waived), speaking check 3 (unreported). Not drift. | User could not connect T3 Code, waived counts, and reported nothing on the rest | Lead 5 | Final |
| 2026-09-29 | `MCPServer.speakGuidance` rewritten to lead with the mapping ("reply/respond/read/say ... with/using/through EchoType" means call the tool), name the wrong actions (app, desktop app, computer-use target, shell command) and say to call it directly without searching for it, once, before the final reply. Spec starting text updated to match. Same handling, no protocol or contract change. | Post-acceptance defect A: a Codex agent used computer use to look for an EchoType app | Lead Final | 2, 5 |
| 2026-09-29 | Send decision moved from the streamed text to the text actually inserted, and `Reviser` rejects a revision that drops a reply request the input had. Spec Sending and `finish` bullets updated. Overrides the spec's "streamed text is used rather than the revised text". | Post-acceptance defect B: `isFaithful` is a subsequence check, so the cleanup model could delete "reply with EchoType" while the send, decided on streamed text, still fired | Lead Final | 1, 3 |
| 2026-09-29 | Final review accepted. Fix A passed on the Mac (wording much more reliable). Fix B (phrase lost before submit) was not reported either way; it stays unverified against the real cleanup model and is reopened if the user sees it again, with the streamed committed text, each revision result, the inserted text and the Clean up setting. Not drift. | User's answer to EF-1 | User (EF-1), Lead Final | Final |
