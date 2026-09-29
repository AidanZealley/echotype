# Workstream 1: Reply request rule, keyterm and setting

Status: not started.

## Task packet

### Outcome

`EchoTypeCore` can decide whether a dictation's committed text is a reply request, always
sends `EchoType` as the first keyterm, and stores the `sendReplyRequests` setting. The app
does not use any of it yet.

### Scope

Follow the specification's Behaviour (Sending, Built-in keyterm) and Implementation (Core).

- `ReplyRequest.matches(_ committed: String) -> Bool`: the last sentence has the name
  (`echotype`, or `echo` then `type`) directly after `with`, `through`, `via` or `using`, and
  one of `read`, `reply`, `respond`, `speak`, `say`, `answer`, `tell`.
- The word normalisation and sentence splitting it shares with `Reviser` move to one place,
  used by both. Do not copy `Reviser.split` or `Reviser.isFaithful`'s word logic.
- `STTConnection.keyterms(settings:)` puts `EchoType` first, drops a saved duplicate in any
  case, and takes at most `maximumKeyterms - 1` saved terms. Add a public
  `maximumSavedKeyterms` (99) for the Keyterms tab.
- `Settings.sendReplyRequests: Bool = true`, decoded independently as in
  [0010](../../../decisions/0010-settings-storage-and-api-key.md).

### Non-goals

- Any file under `Sources/EchoTypeApp`, including `SettingsView`. Workstream 3 uses these.
- The MCP server, the `speak` path, or a model-based send decision.

### Initial ownership

- `Sources/EchoTypeCore/ReplyRequest.swift` (new)
- `Sources/EchoTypeCore/Reviser.swift`, and a new shared file for the extracted helpers
- `Sources/EchoTypeCore/STT/STTConnection.swift`
- `Sources/EchoTypeCore/Settings.swift`
- `Tests/EchoTypeCoreTests`: new `ReplyRequestTests.swift`, and edits to `STTConnectionTests`,
  `SettingsTests` and `ReviserTests` as needed

### Required seams

Provides, unchanged for later workstreams: `ReplyRequest.matches(_:)`,
`STTConnection.maximumSavedKeyterms`, `Settings.sendReplyRequests`. `Reviser` behaviour does
not change.

### Acceptance criteria

- The tests in the specification's Tests section for `ReplyRequest.matches` and
  `STTConnection.keyterms` exist and pass, including "tell me what failed with EchoType" and
  "make EchoType read faster" (no match).
- A settings file without `sendReplyRequests` decodes with it on, and a malformed value falls
  back to on without discarding other settings.
- Existing `Reviser` tests pass unchanged.
- One implementation of the word and sentence rules serves `Reviser` and `ReplyRequest`.

### Targeted verification

```sh
swift test --filter ReplyRequestTests
swift test --filter STTConnectionTests
swift test --filter SettingsTests
swift test --filter ReviserTests
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
