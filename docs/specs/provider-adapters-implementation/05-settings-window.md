# Workstream 5: Provider settings and window

Status: not started.

## Task packet

### Outcome

The Settings window has a Provider tab with the provider picker, summary, derived feature list, key row and Test. Read Aloud remembers voice and speed per provider. Keyterms shows the provider's limit. Existing installs keep their voice and speed.

### Scope

- Add `Settings.reading`, the per-provider voice and speed stored as a JSON object keyed by provider id, with the fallbacks in the specification's [Settings and storage](../provider-adapters.md#settings-and-storage) section.
- Migrate a stored `voice` and `speechSpeed` into the `xai` entry when `reading` is absent, using today's speed validation. Stop encoding `voice` and `speechSpeed`. Remove `Settings.voice`, `speechSpeed`, `speechSpeedRange`, `defaultSpeechSpeed` and `validatedSpeechSpeed` once nothing needs them; validation comes from the provider's `speedRange`.
- `Reader` and MCP `speak` use the selected provider's reading choice.
- Rename the API Key tab to Provider and lay it out as the specification's [Settings window](../provider-adapters.md#settings-window) section describes. Use SF Symbols and theme-aware colours, with no cards, pills or em dashes in the copy. Keep today's masked key, Save, Replace, Remove and Test behaviour.
- Read Aloud tab: voices by display name and a speed slider over the provider's range in 0.1 steps, both editing that provider's `reading` entry. Keyterms tab: the count uses the selected provider's limit.
- Run the specification's provider-name search and fix any match outside `Providers/XAI/` and the registry.
- Complete the provider adapters decision record's "Adding a provider" section. Update [0010](../../decisions/0010-settings-storage-and-api-key.md) for `reading` and its migration, [0015](../../decisions/0015-settings-window-layout.md) for the Provider tab, and the README's features and install steps.

### Non-goals

- No second provider, no availability states beyond present or absent services, and no grey check marks for runtime conditions.
- No visual redesign of the General, Agents or Updates tabs.

### Initial ownership

- `Sources/EchoTypeCore/Settings.swift`, `Sources/EchoTypeApp/Views/SettingsView.swift`, `Reader.swift` and `DictationController.swift` (reading choice only), `README.md`.
- Tests: `SettingsTests`, `SettingsValidationTests`, `Tests/EchoTypeAppTests/ReadingOperationTests.swift` where reading choice is used, and new focused tests.
- The provider adapters decision record, 0010, 0015, this record and row 5.

### Required seams

- Consume workstream 4's `Provider`, registry and selected-provider access.

### Acceptance criteria

- Settings tests cover migrating `voice` and `speechSpeed` into `xai`, an invalid stored speed falling back as today, a provider's choice surviving a switch to another provider and back, a voice the provider no longer offers falling back to its first voice, and per-field independence.
- The feature list is computed from the provider's services: "Live transcription", "Read aloud" and "Cleanup", with cleanup grey when the provider has no cleanup service.
- The provider-name search finds `xai`, `xAI` and `x.ai` only in `Providers/XAI/` and the registry.
- The README and decision records describe the Provider tab, always-on cleanup and the steps to add a provider.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Settings|ReadingOperation'
swift build --product EchoTypeApp
grep -rniE 'xai|x\.ai' Sources --include=*.swift | grep -v '^Sources/EchoTypeCore/Providers/XAI/' | grep -v '^Sources/EchoTypeCore/Providers/Providers.swift'
git diff --check
```

The search must print nothing. Adjust the test filter to the identifiers `swift test list` shows, and record the exact command and test count. Layout and both themes are checked in gate G3.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: Provider tab appearance and upgrade are checked in G3
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
