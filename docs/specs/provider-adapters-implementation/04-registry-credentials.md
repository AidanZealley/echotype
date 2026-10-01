# Workstream 4: Provider registry and credentials

Status: not started.

## Task packet

### Outcome

The app gets every service from the selected `Provider` in a Swift registry. Keys are stored per provider, and credential status and error messages use the selected provider's name. xAI is the only registered provider and the default.

### Scope

- Add `Provider`, `ProviderID` and `Credential` as in the specification's [Provider description and registry](../provider-adapters.md#provider-description-and-registry) section, and the `Providers` registry with `.xAI` as its only entry.
- Add the xAI description in `Providers/XAI/`: id `xai`, name `xAI`, summary "Paid. Uses your xAI API key.", and the `xai-…` key placeholder, composing the three service values from workstreams 1 to 3.
- Add `Settings.provider`. A missing or unknown stored id falls back to `Providers.all[0]`.
- Replace direct xAI wiring in `DictationController` and the reader factory with the selected provider's services. The operation and reader read the selected provider's credential.
- The Keychain wrapper reads, saves and removes the item whose account is the provider id. Remove deletes only that item. The "any account name" read is gone.
- `hasAPIKey` becomes whether the selected provider has its credential; `Credential.none` always does. The menu bar text becomes "Add your <name> API key in Settings". Changing the provider setting refreshes it.
- `describe(_:)` and the "no key" messages use the selected provider's name, producing today's exact text for xAI.
- The API Key tab reads and writes the selected provider's key and uses its placeholder. Workstream 5 restructures the tab.
- Create the provider adapters decision record (next free number in `docs/decisions/`) covering the contract and registry, and update the index. Update [0006](../../decisions/0006-api-key-and-error-surface.md) and [0010](../../decisions/0010-settings-storage-and-api-key.md) for errors, the `provider` key and the Keychain.

### Non-goals

- No Provider tab, feature list, per-provider voice storage or Keyterms tab change.
- No availability concept beyond having the credential.
- No migration for keys stored under another account name.

### Initial ownership

- New `Providers/Provider.swift`, `Providers/Providers.swift` and `Providers/XAI/XAI.swift` (or equivalent).
- `Sources/EchoTypeCore/Settings.swift` (`provider` only), `Sources/EchoTypeApp/Keychain.swift`, `DictationController.swift`, `DictationOperation.swift` (key lookup only), `Reader.swift` (credential only), `App.swift`, `Views/SettingsView.swift` (API Key tab Keychain calls and placeholder only).
- Tests: `SettingsTests`, `Tests/EchoTypeAppTests/DictationOperationTests.swift`, `ReadingOperationTests.swift` and `SpeechAdmissionTests.swift` where wiring changes, plus new focused tests.
- The new decision record and the index, 0006, 0010, this record and row 4.

### Required seams

- Consume the service values recorded in workstreams 1 to 3's handoffs.
- The handoff records the final `Provider` declaration and how the app reads the selected provider, for workstream 5.

### Acceptance criteria

- No code outside `Providers/` refers to an xAI service value directly; the composition reads `Providers` and `Settings.provider`.
- Settings tests cover a missing `provider`, an unknown `provider` and a round trip.
- Tests show that errors are worded with the provider's name and that `Credential.none` counts as having a credential, using a provider defined in the test rather than a second registered provider.
- Keychain reads, saves and removes by account. Following [0019](../../decisions/0019-native-macos-app-and-core-boundary.md), this is checked on the Mac in gate G3, not through a protocol around the Keychain.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Settings|DictationOperation|ReadingOperation|SpeechAdmission'
swift build --product EchoTypeApp
git diff --check
```

Adjust the filter to the identifiers `swift test list` shows, and record the exact command and test count.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Contract declarations for later workstreams: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: Keychain by account is checked in G3
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
