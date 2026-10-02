# Workstream 2: Choose the language from a fixed list

Status: accepted.

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

- Base commit: `b3728905aa1207baf2abd1627bafe149377c745e`
- Outcome: The General tab's Language row is a picker over `Settings.Language.all`, which holds only English (`en`). Loading settings maps any stored tag to the entry with its language subtag, or to English, so stored `en`, `en-US` and `fr` all load as `en`. `Settings.language` is still a `String` tag; request types, `ReadinessRequest` and xAI are unchanged.
- Files changed:
  - `Sources/EchoTypeCore/Settings.swift`: new nested `Settings.Language`; `language` default is `Language.english.tag`; `init(from:)` maps the stored tag through `Language.matching`.
  - `Sources/EchoTypeApp/Views/SettingsView.swift`: `LanguageRow` (text field) deleted; an inline `Picker("Language", ...)` in `GeneralTab`, matching the Hotkey picker.
  - `Tests/EchoTypeCoreTests/SettingsTests.swift`: fixtures that stored or expected `en-GB` now use `en` (or the default); new parameterised `storedLanguageMapsToPickerEntry` (`en`, `en-US`, `EN-gb`, `fr`, `english`, empty).
  - `Tests/EchoTypeCoreTests/SettingsValidationTests.swift`: expectations no longer expect `en-GB` to survive loading; two language assertions that can no longer distinguish anything from the default were removed.
  - `docs/decisions/0007-known-gaps.md`: the "every 400 is worded as a key problem" gap no longer says the language is free text.
- Decisions:
  - Seam for workstreams 3-5: the list is `Settings.Language` in `Sources/EchoTypeCore/Settings.swift`, public:
    ```swift
    public struct Settings.Language: Hashable, Sendable {
      public var name: String   // display name, "English"
      public var tag: String    // bare BCP-47 tag, "en"
      public static let english: Language
      public static let all: [Language]                    // [english]
      public static func matching(_ tag: String) -> Language  // language subtag before "-", case-insensitive; else english
    }
    ```
    `Settings.language` holds `Language.all`'s `tag` after loading. Adapters receive the bare tag (via `TranscriptionRequest.language`, `SpeechRequest.language`, `ReadinessRequest.language`) and resolve it themselves.
  - Mapping happens only when decoding stored settings, as the specification says. `Settings(language:)` in memory is not normalised, so existing tests and fixtures that build requests from `Settings(language: "en-GB")` (TranscriptionRequest, reading, xAI) are unchanged and still pass `en-GB` through.
  - Only `-` separates subtags; `en_US` maps to English through the fallback, which is the same result while English is the only entry.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'SettingsTests|SettingsValidationTests|TranscriptionRequestTests'`: 15 tests in 2 suites. This filter does not match the free-function tests in `SettingsTests.swift` (they have no `SettingsTests` suite), so they were also run by name: 8 tests, including the new language test's 6 cases.
  - `swift test --disable-xctest`: 108 core tests and 71 app tests.
  - `git diff --check`
- Known limitations or external checks: the picker's appearance in the Settings window was not checked by eye; it is a standard `Picker` in a `.columns` form like the Hotkey row, with one entry.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5.5).
- Verdict: Accept. Every acceptance criterion is met within the packet's ownership, with no Required findings.
  - Picker: `Sources/EchoTypeApp/Views/SettingsView.swift:152-156` binds `store.settings.language` to `Settings.Language.all` tags. It matches the Hotkey picker above it, and `LanguageRow` is fully deleted.
  - Mapping: `Sources/EchoTypeCore/Settings.swift:79-81` (`matching`) and `:218-221` (decode). The list is defined once at `:63-81`. Stored `en`, `en-US`, `EN-gb`, `fr`, `english` and `""` all load as `en` (`Tests/EchoTypeCoreTests/SettingsTests.swift:90-96`). An empty string splits to no subtag and falls back to English correctly.
  - Containment: no change to `Providers/`, `Provider.swift` or request types. Every adapter path still reads `settings.language` through `ReadinessRequest(settings:)`, `TranscriptionRequest(settings:)` and `SpeechRequest(settings:)` (`Provider.swift:115`, `:178`, `:300`).
  - Lifecycle: the readiness follow in `DictationController.swift:142-151` already observes language through `ReadinessRequest`. A one-entry picker cannot change it today, and no new tasks or observers were added.
  - Documentation: `README.md` and the decision records had no other free-text description. The `0007-known-gaps.md` edit is accurate. The "Settings accepts arbitrary BCP-47 strings" line in `docs/research/apple-on-device-provider.md:30` is historical research owned by workstream 6, so it was correctly left alone.
  - Verification run by the reviewer, all passing: `swift build`; the packet's filtered `swift test` (15 tests in 2 suites); the free-function settings tests by name (4 tests, including the 6 language cases); full `swift test --disable-xctest` (108 core and 71 app tests); and `git diff --check`.
- Required findings: none.
- Optional observations:
  - O1 (verification gap, plan convention candidate): the packet's filter `SettingsTests|SettingsValidationTests|TranscriptionRequestTests` does not match the free-function tests in `Tests/EchoTypeCoreTests/SettingsTests.swift` (for example `:92`), because they sit in no `SettingsTests` suite. As written, it would not run the new mapping test. The implementer caught this and ran them by name. Later packets should filter by test name or run the target, and the lead may want to record this under conventions learned.
  - O2 (behaviour note, spec-mandated): users who saved `en-GB` or `en-US` now send `en` to xAI for transcription and speech. The value passes through at `XAITranscriber.swift:113` and `XAIVoice.swift:31`. The specification requires this mapping (spec line 88), and xAI accepts `en` (`docs/decisions/0017-batch-pass-on-commit.md:18`), so this is not drift. It is a user-visible change in which English variant xAI receives, and it may be worth a line in release notes.
  - O3 (nit): `Language.name` and `.tag` are `public var` (`Settings.swift:66`, `:68`). That matches `Hotkey`'s style (`:15-16`), but immutable `let` would better express a fixed list entry. Leave as is unless the lead prefers otherwise.
- Questions:
  - Q1: the mapping happens only in memory when settings load. `SettingsStore.swift:20` does not write back, so `UserDefaults` keeps a legacy tag such as `en-GB` until the next settings change. All readers go through `Settings`, so nothing observes the old value. I read the criterion "the stored value is a tag from the list" as satisfied by `Settings.language`. Please confirm that reading. Writing back on load would add behaviour to `SettingsStore`, which is outside the packet's ownership, and I do not recommend it.

## Resolution

- Finding dispositions: no Required findings, so no remediation pass. O1 accepted as a plan convention: the packet filter misses the free-function settings tests, which were run by name. O2 not drift: the specification requires the mapping and xAI accepts `en`; noted for release notes. O3 declined: `var` matches `Hotkey` and `Reading`. Q1 confirmed: "the stored value" means `Settings.language`; `UserDefaults` keeps a legacy tag until the next settings save, which nothing reads, and write-back would change `SettingsStore` outside this packet.
- Simplification/deletion pass: `LanguageRow` and its local text state deleted; the picker is inline in `GeneralTab` like the Hotkey picker. Two language assertions that could no longer distinguish anything from the default removed.
- Final verification: lead reran `swift build`, the packet's filtered `swift test` (15 tests), the four free-function settings tests by name (including six language cases) and `git diff --check`; all pass. Reviewers also ran the full `swift test --disable-xctest` (108 core, 71 app), passing.

## Closure review

- Reviewer: fresh closure review agent (Claude Opus 5.5).
- Verdict: Accept. The independent review raised no Required findings, so no remediation ran. The tree the review accepted is unchanged since that review: it has the same diff against `b3728905` in `Settings.swift`, `SettingsView.swift`, the two settings test files and `0007-known-gaps.md`. It has no release-blocking defect.
  - `Settings.Language` is defined once. Decoding maps every stored tag through `Language.matching`, and nothing else writes `settings.language` except the picker binding and the memberwise init. `LanguageRow` has no remaining references.
  - `Providers/` and the request types are untouched.
- Verification (all pass):
  - `swift build`
  - `swift test --disable-xctest --filter 'SettingsTests|SettingsValidationTests|TranscriptionRequestTests'`: 15 tests in 2 suites.
  - The free-function settings tests by name (`storedLanguageMapsToPickerEntry|settingsRoundTrip|storedValueDecodes|retiredKeysIgnored`): 4 tests, including the 6 language cases. The packet's filter misses these tests, as O1 noted.
  - Full `swift test --disable-xctest`: 108 core and 71 app tests.
  - `git diff --check`
- Remaining required findings: none. O1-O3 and Q1 remain optional items for the lead to triage in Resolution. They were not promoted.
