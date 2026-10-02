# Workstream 2: Choose the language from a fixed list

Status: not started.

## Task packet

### Outcome

The Settings Language field is a picker over a fixed, provider-neutral list that holds only English (`en`). A saved tag outside the list maps to the entry with the same language subtag, or to English. `Settings.language` still stores the BCP-47 tag, so request types and xAI behaviour are unchanged.

Specification: [Language picker](../../specs/apple-on-device-provider.md#language-picker).

### Scope

- Define the list once in `EchoTypeCore`. Each entry has a display name and a bare tag. Suggestion: alongside `Settings` in `Settings.swift`.
- Map saved tags when settings load, following the existing decoding and validation style.
- Replace `LanguageRow`'s text field with a picker.
- Update any documentation that describes the language as free text, such as `README.md` or a decision record.

### Non-goals

- Languages other than English, per-provider language lists, and region choices.
- Any change to `Providers/`.

### Initial ownership

- `Sources/EchoTypeCore/Settings.swift`, or one new file beside it for the list
- `LanguageRow` in `Sources/EchoTypeApp/Views/SettingsView.swift`
- `Tests/EchoTypeCoreTests/SettingsTests.swift`, `SettingsValidationTests.swift`
- Documentation lines that describe the language field

### Required seams

- Workstreams 3–5 resolve tags from this list. Record the list's type and location in the handoff.

### Acceptance criteria

- Settings shows a Language picker with English selected.
- Saved `en`, `en-US` and `fr` all load as `en`, and the stored value is a tag from the list.
- Existing settings, transcription request and xAI tests pass.

### Targeted verification

```bash
swift build
swift test --disable-xctest --filter 'SettingsTests|SettingsValidationTests|TranscriptionRequestTests'
git diff --check
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
