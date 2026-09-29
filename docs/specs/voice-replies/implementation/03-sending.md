# Workstream 3: Sending a reply request

Status: accepted; gate A passed with three checks unreported.

## Task packet

### Outcome

With **Send reply requests** on, a dictation whose last streamed sentence is a reply request
ends itself, inserts, and presses Return. The setting and the new keyterm limit appear in
Settings.

### Scope

Follow the specification's Behaviour (Sending, Built-in keyterm) and the App section for
`DictationController`, `Inserter` and `SettingsView`.

- `DictationController.run` calls `commit()` when `snapshot.committed` grows and
  `ReplyRequest.matches` holds, if sending is on and the session is a dictation.
- `finish` sends when the outcome is `.insert` and the final streamed committed text matches.
  Only `.insert` sends. The Test button, failed, cancelled and empty sessions never do.
- Sending inserts, waits a named constant (start at 200 ms), then calls `Inserter.pressReturn()`.
- `Inserter.pressReturn()` posts Return with empty flags, for the reason given for Cmd+V.
- `SettingsView`: the toggle and caption in the General tab, and "N of 99 keyterms used" in
  the Keyterms tab, using `STTConnection.maximumSavedKeyterms`.
- With the setting off, nothing changes and a request is inserted as ordinary text.

### Non-goals

- `speak`, `Reader`, notifications, the `--mcp` entry point (workstreams 4 and 5).
- Changes to `ReplyRequest`, keyterms or `Settings` from workstream 1. Escalate defects in them.
- A setting for the Return delay.

### Initial ownership

- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/Inserter.swift`
- `Sources/EchoTypeApp/Views/SettingsView.swift`

### Required seams

Uses `ReplyRequest.matches(_:)`, `Settings.sendReplyRequests` and
`STTConnection.maximumSavedKeyterms` from workstream 1. Leaves `DictationController` for
workstream 4, so keep the sending code in clearly named private methods.

### Acceptance criteria

- The two send paths (a commit that makes a match, and a hotkey stop whose final text matches)
  both reach one place that inserts, waits and presses Return.
- No path other than `.insert` on a real dictation reaches Return.
- The toggle persists through `Settings`, and the caption reads "Ending with a request like
  “reply with EchoType” sends the message".
- The Keyterms tab shows 99 as the limit and the tab's saving keeps at most 99.
- `swift build` and `swift test` pass.

### Targeted verification

```sh
swift build
swift test
```

The controller is not unit-tested; review reads the code paths against the acceptance
criteria.

### External validation

- Gate and placement: `A`, after closure and before acceptance
- Status: `Passed`, with unreported checks pending
- Candidate and instructions: the working tree on branch `voice-replies` (base `8d62d49`), built with `./scripts/install.sh`.
- Required evidence: a pass or fail per check (Sending, Return timing, Keyterm), and the app for any timing failure.
- Attempts and lasting decisions: one run. The user reported a pass: reply sends after a pause and after the hotkey, Return follows the paste and the message went through, "EchoType" is spelled correctly, and with the setting off neither path sends. No app needed a longer delay, so `returnDelay` stays 200 ms.
- Pending, not reported: which apps were tried (T3 Code, Claude Code, Codex), the mention-without-phrase case, and the Keyterms tab showing 99. Listed in the completion report.
- Resume condition: met
