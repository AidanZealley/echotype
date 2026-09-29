# Workstream 3: Sending a reply request

Status: not started.

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

### External validation gate A

Placement: after closure, before acceptance. The candidate is the branch built with
`./scripts/install.sh`, run by the user. Checks, from the specification's Final gate:

- Sending: dictate a prompt ending "reply with EchoType" with a pause at the end. The session
  ends by itself and the text, request included, is inserted and sent. Repeat with the hotkey
  stopping instead of the pause. A dictation that mentions EchoType without the phrase inserts
  without sending. Turning the setting off stops sends.
- Return timing: send in T3 Code, Claude Code in the terminal and Codex in the terminal. The
  message arrives whole and sends once. Report any app that needed a longer delay.
- Keyterm: "EchoType" is spelled that way in the stream and the Keyterms tab shows 99 as the
  limit.

Evidence: a pass or fail per check, and the app for any timing failure. If an app needs longer,
raise the one constant for all apps (say 400 ms) and ask for a retest.

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

- Gate and placement: `A`, after closure and before acceptance
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: `TBD`
- Attempts and lasting decisions: `TBD`
- Resume condition: the user reports every check passing
