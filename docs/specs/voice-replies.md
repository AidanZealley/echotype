# Voice replies

The user dictates a prompt to a coding agent, ends it by asking for a spoken reply, and
the message sends itself. The agent speaks a version of its reply through EchoType,
then writes its reply as usual. One press of the dictation hotkey starts the exchange, and nothing else
needs a key.

Status: draft, 2026-09-29. Implemented on the `voice-replies` branch; Gate B is pending.

## Problem

Using an agent by voice today takes three hands-on steps: dictate, press Return, then
select the reply and press the read-aloud hotkey. The selected reply is read verbatim,
including code blocks, paths and markdown, which is hard to follow by ear.

The user works in Claude Code, Codex and T3 Code, which switches between models and
harnesses. The integration has to work in all of them without per-agent logic in
EchoType.

## Approach

EchoType does the listening and the speaking, and the agent decides what to say:

- **EchoType sends.** When the last sentence of a dictation asks for a reply through
  EchoType, EchoType inserts the text and presses Return. The request stays in the
  message.
- **The agent reads the request.** "Reply with EchoType", "read the whole response with
  EchoType, minus any code blocks" or "tell me what failed with EchoType" are ordinary
  instructions to the agent. EchoType does not interpret them.
- **The agent summarises by default.** Speech is billed per character and is the largest
  cost EchoType has, and the full reply is usually on screen. Unless the request asks for
  more, the agent speaks a summary that scales with its reply, about a fifth of the length
  for a long one. The agent calls `speak` first, then writes its full reply as the final message. The
  written reply is unchanged: only the `speak` text is shortened.
  Nothing in the app enforces the length beyond the existing
  `Speech.capped`.
- **The agent speaks through MCP.** EchoType ships an MCP server with one `speak` tool.
  Its description tells the agent when to call it and how to write for listening. Claude
  Code and Codex both load MCP servers, so the same server works in each without
  instruction files.

## Behaviour

### Sending

- A General tab setting, **Send reply requests**, on by default, with the caption "Ending
  with a request like “reply with EchoType” sends the message".
- With it on, a dictation is a **reply request** when the last sentence of its streamed
  committed text contains both:
  - **The name as an object.** The word `echotype`, or `echo` followed by `type`,
    directly after `with`, `through`, `via` or `using`. Talking about EchoType ("make
    EchoType read faster", "the reply bug in EchoType") does not qualify.
  - **A speaking verb.** One of `read`, `reply`, `respond`, `speak`, `say`, `answer`,
    `tell`.

  Words are compared as in `Reviser.isFaithful`: lowercased, with punctuation stripped at
  word edges. Sentences end at `.`, `!` or `?` followed by whitespace, as in
  `Reviser.split`. The send decision is made on the text that is inserted, and `Reviser`
  rejects a revision that would drop a reply request, keeping the streamed words.
- When a newly committed segment makes the dictation a reply request, the session ends
  as if the hotkey had been pressed: capture stops, the session finalises, cleanup runs
  its final revision, and the pill shows `Transcribing` meanwhile. Commits only happen
  after a pause of about 1.2 seconds (`endpointing=1200`), so this is when the session
  ends.
- A session ended by the hotkey whose inserted text is a reply request also
  sends. The phrase decides whether to send; how the session ended does not.
- Sending inserts the final text, including the request, as today. After a short delay,
  EchoType then posts Return with no modifiers. Start at 200 ms and adjust from the final
  gate.
- Only an `.insert` outcome sends. A failed, cancelled or empty session never presses
  Return, and neither does the Test button.
- With the setting off, dictation is unchanged, and a request is inserted as ordinary
  text.

A pause of more than 1.2 seconds inside the request commits the words said so far. For
example, "read the reply with EchoType … minus the code" sends before "minus the code".
Put qualifiers before the request and end on it: "without code blocks, read the response
with EchoType". Some sentences can still match by accident, such as "the reply is wrong
with EchoType" followed by a pause. The setting is the escape hatch.

### Built-in keyterm

`EchoType` is always sent as the first keyterm, so the stream spells the name
consistently. It is not stored in settings and does not appear in the Keyterms tab. The
user can save up to 99 keyterms, and the tab shows "N of 99 keyterms used". A saved
`EchoType` in any case is dropped rather than sent twice. This applies whether or not
**Send reply requests** is on, because the name is also worth hearing correctly in
ordinary dictation.

### Speaking

- The MCP `speak` tool takes `text` and hands it to the running app. The app reads it
  aloud as a reading does today: the `Reading` pill, the configured voice and speed,
  `Speech.capped`, Space to pause, Escape or the read-aloud hotkey to stop, and the
  dictation hotkey to stop it and start dictating a follow-up.
- A `speak` call while a reading is under way stops that reading and starts the new one.
  A call while a dictation or test is starting or running is dropped, so the agent never
  talks over the user.
- The tool returns as soon as the app has the text, so the agent's turn does not stay
  open for the length of the reading. If the app isn't running, the tool returns an
  error saying so.
- A `speak` reading does not copy the selection or wait for the paste restore. It has
  its text already.

### Tool description

The description does the work an instruction file would otherwise do, and it goes into
every agent that loads the server. Starting text:

> Speaks text aloud through EchoType. When the user asks you to reply, respond, read, say or
> give something with, using or through EchoType, call this tool. EchoType is not an app, desktop
> app, computer-use target or shell command: do not open it or look for an app. Call this
> directly, without searching for it, once you are ready to write your final reply and before
> you write it. The text argument is the only place the spoken version goes: a summary written for listening, or
> all of your reply if the user asks for the whole response, in full, or not to summarise. After
> the call, write your reply as the final message, complete and exactly as you would if EchoType
> were never mentioned. Do not shorten it and do not call this again. Unless the user asks for
> more, the summary scales with your reply: a few sentences for a short one, and about a fifth of
> the length for a long, detailed one. Cover what you did or found, each main point, anything
> that went wrong, and anything you need from the user. Either way, leave out code blocks, file
> paths, tables and URLs unless asked. Where a code block matters, say in a sentence what it does,
> at the point it appears, instead of reading it. Write plain sentences without markdown. It
> returns once EchoType has the text, so don't wait.

Send the same text as the server's `instructions`, in the `initialize` result for legacy
clients and the `server/discover` result for modern ones (see the protocol section). Not
every client reads server instructions, so the tool description must work on its own.

## Setup

`README.md` gains a section with the registration for each agent, using the installed
app's executable:

- Claude Code:
  `claude mcp add --scope user echotype -- /Applications/EchoType.app/Contents/MacOS/EchoTypeApp --mcp`
- Codex, in `~/.codex/config.toml`:

  ```toml
  [mcp_servers.echotype]
  command = "/Applications/EchoType.app/Contents/MacOS/EchoTypeApp"
  args = ["--mcp"]
  ```

- T3 Code: whatever the final gate finds. If it passes the harness's own MCP
  configuration through, no separate step is needed.

## Implementation

### Core

- `ReplyRequest.matches(_ committed: String) -> Bool`, the rule above. The word
  normalisation and sentence splitting it shares with `Reviser` move to one place instead
  of being copied.
- `STTConnection.keyterms(settings:)` puts `EchoType` first, drops a saved duplicate, and
  takes at most `maximumKeyterms - 1` saved terms. A `maximumSavedKeyterms` constant gives
  the Keyterms tab its 99.
- `Settings` gains `sendReplyRequests: Bool = true`, decoded independently as in
  [0010](../decisions/0010-settings-storage-and-api-key.md).
- `MCPServer`, the JSON-RPC handling for newline-delimited messages on stdio. It takes
  the delivery as a closure, so it doesn't depend on the app. Protocol details are
  below.

### Protocol

The server is dual-era, in the terms of MCP's
[versioning page](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning):
it serves modern clients on `2026-07-28` and legacy clients on `2025-11-25`. Claude Code,
Codex and the harnesses T3 Code runs will move to the modern revision at different
times, and a modern-only server fails every legacy client at startup. This is a real
compatibility boundary, so it stays until the legacy clients are gone.

- **Modern.** Every request carries `io.modelcontextprotocol/protocolVersion` in
  `params._meta`, and there is no handshake. The server implements `server/discover`,
  whose result has `supportedVersions: ["2026-07-28", "2025-11-25"]`, a `tools`
  capability, `io.modelcontextprotocol/serverInfo` in `_meta`, the instructions, and
  `ttlMs` and `cacheScope`. A request naming any other version gets
  `UnsupportedProtocolVersionError` (code `-32022`) listing the supported versions.
- **Legacy.** An `initialize` request selects legacy semantics for the rest of the
  process. The server answers with `2025-11-25`, a `tools` capability, server info and
  the instructions, then accepts `notifications/initialized` and `ping`.
- **Both.** `tools/list` returns `speak` with its description and an input schema
  requiring a string `text`, in a fixed order, with `ttlMs` and `cacheScope`.
  `tools/call` for `speak` delivers the text and returns a short text result. Every
  result carries `resultType: "complete"`; legacy clients ignore the extra fields.
  Unknown methods get a method-not-found error.

The official [Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) implements
only `2025-11-25` as of writing, and one tool doesn't justify the dependency, so the
server is written by hand.

### App

- **Entry point.** `--mcp` has to take effect before SwiftUI starts, so the `@main` app
  moves behind a small `main` that either runs the MCP stdio loop or calls
  `EchoTypeApp.main()`. The MCP process never creates an `NSApplication`, a hotkey
  monitor or a login item claim.
- **Delivery.** The MCP process checks for a running app with bundle identifier
  `com.aidanzealley.echotype` and posts the text as a distributed notification. The app
  observes it and passes it to `DictationController`. Any local process could post it,
  but all it can do is have EchoType read text aloud, so it has no authentication.
- **`DictationController`.**
  - `run` checks `ReplyRequest.matches` whenever `snapshot.committed` grows, when
    sending is on and the session is a dictation. On a match it calls `commit()`.
  - `finish` sends when the outcome is `.insert` and the inserted text (after any
    revision) matches. It inserts, waits, and posts Return.
  - `speak(_ text:)` follows `readAloudPressed`'s phase rules, with the text given:
    starts a reading from idle, replaces a reading, and does nothing in the other
    phases.
- **`Reader`** takes its text source: the selection, as now, or given text.
- **`Inserter`** gains `pressReturn()`, posting Return with empty flags. The explicit
  flags matter for the same reason as Cmd+V.
- **`SettingsView`**: the toggle and caption in the General tab, and the 99 in the
  Keyterms tab.

## Tests

- `ReplyRequest.matches`: each of "reply with EchoType", "respond with echo type" and
  "read the response with EchoType, minus any code blocks" and "tell me what failed with
  EchoType" matches as the last sentence. The name without a verb doesn't, the name in an
  earlier sentence doesn't, a verb without the name doesn't, and the name without a
  preposition ("make EchoType read faster") doesn't.
- `STTConnection.keyterms`: `EchoType` comes first, a saved duplicate is dropped, and 100
  saved terms send 99 of them.
- `MCPServer`: a legacy exchange (`initialize`, then `tools/call`) and a modern one
  (`tools/call` with `_meta`) each deliver the text, and a modern request naming an
  unsupported version gets `-32022` with the supported list. These pin the
  compatibility boundary; the other methods need no tests of their own.

## Deferred

- **Model-based send decision.** If the rule still misfires in real use, ask Grok whether
  the last sentence requests a spoken reply, only when it contains the name. That adds a
  network call to the send path, so it waits for evidence.

## Final gate

After implementation, run `swift test`, then check on the Mac with the installed app:

- **Sending.** Dictate a prompt ending "reply with EchoType" with a pause at the end. The
  session ends by itself, the text including the request is inserted, and it is sent.
  Repeat with the hotkey stopping instead of the pause. A dictation that mentions
  EchoType without a verb inserts without sending. Turning the setting off stops sends.
- **Return timing.** Send in T3 Code, Claude Code in the terminal and Codex in the
  terminal. The message arrives whole and sends once. The 200 ms delay is a guess, and
  chat inputs on web views may handle a paste asynchronously. If an app needs longer,
  raise the one constant for all apps (say 400 ms) rather than adding a setting.
- **MCP in each agent.** Register the server in Claude Code and Codex, then check whether
  T3 Code picks it up for each harness it runs. Record what T3 Code needs. Log the first
  message each client sends and record whether it opened with `initialize` or a modern
  request, and which version it named.
- **Agent behaviour.** In each agent, try "reply with EchoType", "respond with EchoType"
  and "read the whole response with EchoType, and don't summarise" on a prompt whose
  answer is long and includes code. The agent calls `speak` once, before its written reply, and the reply is written in full. The
  first two speak a summary of roughly a fifth of the reply's length, with no code read
  out. The third speaks the whole reply, describing each code block in a sentence where it
  appears. Record the character count of each spoken text against the reply's length, to
  judge whether the summary proportion needs adjusting. If an agent misses `speak` or calls it twice in more
  than about 1 of 5 trials across the three wordings, add one line to that agent's global
  instruction file. No EchoType code changes.
- **Speaking.** A reply is read with the `Reading` pill. Space pauses it, and the
  dictation hotkey stops it and starts a new dictation. A `speak` call during a dictation
  is dropped. With the app quit, the tool returns its error.
- **Keyterm.** "EchoType" is spelled that way in the stream without being saved as a
  keyterm, and the Keyterms tab shows 99 as the limit.
