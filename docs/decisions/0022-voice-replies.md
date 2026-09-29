# 0022 Voice replies

Status: accepted, 2026-09-29.

## Context

The goal is to dictate a prompt to a coding agent, ask for a spoken reply, and hear it
without touching another key. The specification is
[voice-replies.md](../specs/voice-replies.md).

## Decision

- **EchoType sends.** When a dictation ends with a reply request, EchoType inserts the text
  and presses Return itself. The agent never has to know a dictation happened, and no
  agent-side hook or wrapper is needed.
- **The agent summarises.** The agent calls a `speak` tool with a spoken version of its
  reply. It has the reply and its code blocks in context, so it can shorten the answer and
  describe code in a sentence. EchoType doesn't summarise, and needs no second model call.
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

## Consequences

- A dictation can still end with a reply request by accident and send itself. The send
  setting is the escape hatch.
- Nothing enforces summary length beyond `Speech.capped`. A long summary is cut, not
  refused.
- Any local process can make EchoType speak.
- The legacy MCP path stays until clients have moved to the modern revision.
- What T3 Code needs is still open until it is checked on the Mac.
