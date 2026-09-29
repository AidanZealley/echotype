# Workstream 1: Reply request rule, keyterm and setting

Status: accepted.

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

- Base commit: `d451a6f` (working tree, uncommitted)
- Outcome: `ReplyRequest.matches`, the built-in first `EchoType` keyterm with
  `STTConnection.maximumSavedKeyterms` (99), and `Settings.sendReplyRequests` (default on,
  decoded independently) are in `EchoTypeCore`. The app does not use them yet.
- Files changed: `Sources/EchoTypeCore/Prose.swift` (new), `ReplyRequest.swift` (new),
  `Reviser.swift`, `STT/STTConnection.swift`, `Settings.swift`; tests: `ReplyRequestTests.swift`
  (new), `STTConnectionTests`, `SettingsTests`.
- Decisions: `Prose` (internal) holds `words` and `sentenceStarts`, which `Reviser.split`,
  `Reviser.isFaithful` and `ReplyRequest` use; the old copies and `isPunctuation` are gone. The
  name may follow the preposition only directly (`with EchoType`, `with echo type`). The
  verb may be anywhere in the last sentence. `keyterms(settings:)` also applies the 50
  character cap to `EchoType`, which is a no-op.
- Verification: `swift test --filter` for ReplyRequestTests, STTConnectionTests,
  SettingsTests and ReviserTests all pass; `swift build` succeeds. The existing URL test
  now expects a trailing `keyterm=EchoType` item, and the cap test was rewritten for 99.
- Known limitations or external checks: `SettingsView` still shows
  `STTConnection.maximumKeyterms` (100) until workstream 3.
- Specification drift: none.

## Independent review

- Reviewer: `claude -p` on claude-opus-5-5, medium effort, read-only (review command, no substitution)
- Verdict: `Accept`
- Required findings: none
- Optional observations: the `else { return false }` in `ReplyRequest.matches` cannot run because `Prose.sentenceStarts` always returns at least one start; the test function `keytermsAreCapped` has a name narrower than its new title
- Questions: none

## Resolution

- Finding dispositions: no Required findings, so no remediation pass. Both optional observations left unpromoted: the guard is harmless and the rename is cosmetic.
- Simplification/deletion pass: done by the implementation agent (old `Reviser` word and sentence copies and `isPunctuation` removed). The reviewer found no dead code or duplicated state.
- Final verification: lead reran `ReplyRequestTests`, `STTConnectionTests`, `SettingsTests` and `ReviserTests` (20 tests, all pass) and `swift build`.

## Closure review

- Verdict: `Accept` (fresh session, same review command)
- Remaining required findings: none
