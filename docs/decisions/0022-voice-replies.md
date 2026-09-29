# 0022 Voice replies

Status: accepted, 2026-09-29.

## Context

The goal is to dictate a prompt to a coding agent, ask for a spoken reply, and hear it
without touching another key. It has to work in Claude Code, Codex and T3 Code without
per-agent logic in EchoType. Reading a selected reply verbatim is hard to follow by ear,
because of code blocks, paths and markdown, and speech is billed per character.

## Decision

- **EchoType sends.** When a dictation ends with a reply request, EchoType inserts the text
  and presses Return itself. The agent never has to know a dictation happened, and no
  agent-side hook or wrapper is needed.
- **A reply request is a name after a preposition plus a speaking verb.** The last
  sentence of the dictation needs `EchoType` directly after `with`, `through`, `via` or
  `using`, and one of `read`, `reply`, `respond`, `speak`, `say`, `answer` or `tell`
  anywhere in that sentence. Talking about EchoType doesn't qualify. The rule is loose on
  purpose: a phrase like "the summary for the speak tool, using EchoType," still sends.
  Tightening it would break natural requests such as "read the whole response with
  EchoType, minus any code blocks", so the Send reply requests setting is the escape
  hatch.
- **The send is decided on the inserted text.** Cleanup may delete words, so a send
  decided on the streamed text could fire after the cleanup model dropped the request.
  The decision uses the text actually inserted, and `Reviser` rejects a revision that
  drops a reply request the input had.
- **The agent summarises.** The agent calls a `speak` tool with a spoken version of its
  reply. It has the reply and its code blocks in context, so it can shorten the answer and
  describe code in a sentence. EchoType doesn't summarise, and needs no second model call.
- **The agent speaks first, then writes its full reply.** With `speak` last, its turn
  became the final message and hid the full written reply in the agent UI. Called first,
  the spoken text goes only in the tool argument and the written reply stays complete
  and normal. The tool description and server instructions state the mapping from
  "reply with EchoType" to the tool first, name the wrong actions (an app, computer use,
  a shell command) and say where each text goes. Agents misread earlier wordings, so the
  description is treated as the fix, not the agent.
- **The server is hand-written and dual-era.** `EchoTypeApp --mcp` speaks MCP over stdio,
  serving `2026-07-28` and `2025-11-25`. Claude Code, Codex and T3 Code's harnesses will
  move to the modern revision at different times, and a modern-only server fails every
  legacy client at startup. The official Swift SDK implements only `2025-11-25`, and one
  tool doesn't justify the dependency. The dual-era support is a compatibility boundary
  that stays until legacy clients are gone.
- **Delivery is a distributed notification.** The `--mcp` process finds the running app by
  bundle identifier and posts the text with `deliverImmediately`. It never starts a second
  app. With no app running, the tool returns an error. Any local process could post the
  notification, but all it can do is have EchoType read text aloud, so it has no
  authentication.

- **Setup is commands to paste.** Settings has an Agents tab with the registration
  command for Claude Code and Codex. EchoType doesn't edit another tool's config, run
  its CLI or report whether an agent is connected. T3 Code needs no step of its own,
  since it runs those harnesses.

## Consequences

- A dictation can still end with a reply request by accident and send itself. The send
  setting is the escape hatch.
- Nothing enforces summary length beyond `Speech.capped`. A long summary is cut, not
  refused.
- Any local process can make EchoType speak.
- The legacy MCP path stays until clients have moved to the modern revision.
- Nothing tells the user whether an agent is connected. Claude Code once missed the
  server on its first thread and the cause is unknown.
- Agent behaviour depends on the tool description. Reword it there, not in per-agent
  instruction files.
