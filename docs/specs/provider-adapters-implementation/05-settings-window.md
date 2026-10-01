# Workstream 5: Provider settings and window

Status: accepted.

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

- Base commit: `57d4ee0`, accepted workstream 4. All implementation changes are uncommitted. Review with `git diff HEAD`; `plan.md` belongs to the lead.
- Outcome: complete within scope. `Settings.reading` stores each provider's voice and speed in a JSON object keyed by its id. Legacy voice and speed migrate only when `reading` is absent. Voice and speed fallbacks are independent, and malformed entries do not discard other providers or settings. Reader uses the selected provider's choice for both selection reading and MCP `speak`. Provider replaces API Key, with the registry picker, summary, service-derived feature list, conditional key editor and Test. Read Aloud edits the selected provider's entry and uses its voices and speed range. Keyterms already consumed the selected provider's limit in workstream 4 and remains correct.
- Files changed:
  - Core: `Settings.swift`, `Providers/Provider.swift`, `Providers/Providers.swift`.
  - App: `Reader.swift`, `Views/SettingsView.swift`. `DictationController.swift` needs no change because its existing Reader factory passes the selected service and settings snapshot.
  - Tests: `SettingsTests.swift`, `SettingsValidationTests.swift`, `ReadingOperationTests.swift`.
  - Docs: README, decision records 0010, 0015 and 0025, this handoff. The README drops the General screenshot that still showed the removed cleanup toggle; the lead also deletes that unused image after review.
- Decisions:
  - `Settings.Reading` is a small Codable value with `voice` and `speed`. `Settings.reading` is `[String: Reading]`, so JSON encodes an object rather than an array of custom dictionary keys. `Reading.validated(for: VoiceService)` supplies independent field fallbacks; `Settings.readingChoice(for: VoiceService)` resolves the selected provider's entry. Encoding validates registered providers' choices and preserves other entries, sanitising non-finite speeds.
  - `SpeechRequest.init(text:settings:voice:credential:)` now receives the active `VoiceService`. Reader passes its injected service, so the same service determines the default voice, speed range, cap and request. These changes to `Provider.swift` were approved by the lead as required ownership expansion.
  - The internal `Providers.migratedReading(voice:speed:)` keeps the legacy provider reference in the registry and uses its unchanged voice speed range. The lead approved this registry ownership expansion. No provider names leak into Settings.
  - ProviderControls takes an immutable provider and is identified by its id. Switching providers discards its draft, reveal state and messages. A cancelled initial load cannot publish its key. In-flight writes keep their original provider id, and a provider with no credential never reads Keychain.
  - Transcription and voice services are required by the Provider type, so their feature checks are green. Cleanup is computed from `provider.cleanup != nil`, with a grey absent mark. No capability flags or runtime availability states were added.
- Verification:
  - `swift test list` confirmed the identifiers. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SettingsValidationTests|ReadingOperationTests|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|unknownProvider|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults'` passed all 29 tests, 13 core and 16 app. This covers migration, previous invalid-speed behaviour, independent fields and entries, retired voice fallback, provider switching and requests using the selected reading entry.
  - `swift build --product EchoTypeApp` passed.
  - `grep -rniE 'xai|x\.ai' Sources --include='*.swift' | grep -v '^Sources/EchoTypeCore/Providers/XAI/' | grep -v '^Sources/EchoTypeCore/Providers/Providers.swift'` printed nothing. The include glob is quoted for zsh; grep's no-match exit is expected.
  - `git diff --check` passed. The deletion and simplification pass confirmed the global reading fields, speed constants, validation accessor and APIKeyTab name are gone. No compatibility aliases or generic provider infrastructure remain.
- Known limitations or external checks: Provider tab appearance in both themes, upgrade persistence, Keychain behaviour and live operation checks remain in G3. No app was launched, real key read or paid request made.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent agent `/root/workstream5/review`, reviewing the complete uncommitted `git diff HEAD` on `57d4ee0` and surrounding code against the approved specification, named decisions, workflow and earlier handoffs.
- Verdict: passes this workstream's deterministic review. G3 still owns visual inspection, upgrade persistence and real Keychain/live-operation checks.
- Required findings: none. Migration is limited to an absent `reading` field; malformed fields and entries retain unrelated choices. Requests and the Read Aloud bindings resolve the selected provider's entry against its voice service. The Provider feature list follows the required-service contract and optional cleanup service. Key editor identity resets drafts, revealed keys and results on provider changes, initial loads respect cancellation, and writes capture the original provider id. Providers without credentials skip Keychain loading. Reader's selection and supplied-text paths share the request construction used by MCP `speak`. The removed global fields and old tab name have no remaining source/test references; the approved ownership expansions introduce no extra service or compatibility layer.
- Optional observations:
  - O1: README removes its obsolete General screenshot, but `docs/images/settings-general.png` remains. A repository reference search finds only historical workstream records. Deleting this unused image would complete the documentation cleanup; it is outside the packet's initial ownership and does not affect current instructions or acceptance.
- Questions: none.
- Verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SettingsValidationTests|ReadingOperationTests|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|unknownProvider|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults'` passed 13 core and 16 app tests. `swift build --product EchoTypeApp` and `git diff --check` passed. The packet's quoted-glob provider-name search printed nothing outside `Providers/XAI/` and `Providers.swift`. No app was launched, key read or paid request made.

## Resolution

- Finding dispositions: no Required findings or Questions. O1 accepted as a small documentation cleanup: the obsolete General screenshot has no active references, so the lead removed it. No remediation pass was needed.
- Simplification/deletion pass: the global voice/speed settings, old speed validation constants and APIKeyTab are removed. No compatibility aliases, capability flags or extra provider configuration remain. The unused `docs/images/settings-general.png` is deleted along with its README reference.
- Final verification: implementation and independent review both passed all 29 targeted tests, the app build, provider-name search and diff checks. Fresh closure accepted the final candidate and verified the removed image has no active references; all remaining README images exist. G3 owns appearance, upgrade persistence and real Keychain/live checks.

## Closure review

- Verdict: closed. Fresh closure review on `57d4ee0` checked the accepted findings and resolutions against the final uncommitted candidate. There were no Required findings or remediation. O1 is resolved: `docs/images/settings-general.png` is deleted, its README reference is absent, and remaining mentions are historical workflow records. Removing this unused documentation image introduces no release-blocking defect.
- Verification: the deleted image is absent; repository reference search found no active use; all four remaining README image paths exist; `git diff HEAD --check` passed. Source and tests were unchanged after independent review, so its 29 passing targeted tests and app build remain applicable. G3 still owns appearance in both themes, upgrade persistence and real Keychain/live checks. No app was launched, key read or paid request made.
- Remaining required findings: none.
