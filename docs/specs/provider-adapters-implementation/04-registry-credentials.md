# Workstream 4: Provider registry and credentials

Status: accepted.

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

- Base commit: `6723fab` (workstream 3 accepted). All work is uncommitted; source, test and decision-record changes are staged. Review with `git diff --cached HEAD` (plan.md is the lead's).
- Outcome: complete within scope. `Provider`, `ProviderID` and `Credential` are in `Providers/Provider.swift`; `Providers.all = [.xAI]` with a `Providers[id]` lookup that falls back to the first entry is in `Providers/Providers.swift`; `Provider.xAI` (id `xai`, name `xAI`, summary "Paid. Uses your xAI API key.", `.apiKey(placeholder: "xai-…")`, composing `XAI.transcription`, `XAI.voice`, `XAI.cleanup`) is in `Providers/XAI/XAI.swift`. The `XAI` namespace is now internal, so the app can reach xAI only through `Provider.xAI`. `Settings.provider` is stored under `provider`; a missing or unknown id decodes to `Providers.all[0].id`. The controller's dictation and reader factories take services and the credential from `Providers[settings.provider]`. The Keychain wrapper reads, saves and removes by account (the provider id); the any-account read and the delete-every-item clear are gone. `hasAPIKey` is `provider.credential.isSatisfied(by: storedKey)`, refreshed at launch and whenever `store.settings.provider` changes. Errors, the pill's missing-key text and the menu bar text use the provider's name and produce today's xAI text. The API Key tab reads and writes the selected provider's item and uses its name and placeholder.
- Files changed:
  - Core: `Providers/Provider.swift` (description, id, credential), new `Providers/Providers.swift`, `Providers/XAI/XAI.swift` (`Provider.xAI`; `XAI` internal), `Settings.swift` (`provider` only).
  - App: `Keychain.swift`, `DictationController.swift` (wiring, key status, `describe`), `DictationOperation.swift` and `Reader.swift` (credential check only), `App.swift` (menu bar text), `Views/SettingsView.swift`.
  - Tests: `SettingsTests` (round trip writes `provider`, pinned payload includes it, missing and unknown `provider`), `DictationOperationTests` (`noCredentialNeeded`, `missingKey`), `ReadingOperationTests` (`noCredentialNeeded`, `missingKey`), new `ProviderWordingTests.swift` (`providerWording`), `SpeechAdmissionTests` (dependency shape only).
  - Docs: new decision record `0025-provider-adapters.md`; 0006 (errors) and 0010 (`provider` key, Keychain per provider).
  - Outside the listed ownership, forced by the acceptance criterion or by `XAI` becoming internal: `SettingsView`'s Read Aloud voice list and Keyterms count now read `Providers[store.settings.provider]` instead of `XAI.voice` and `XAI.transcription` (workstream 3's handoff assigned the voice list here; the layout stays workstream 5's), one comment in the API Key tab no longer names `xai-`, and `Integration/RevisionPromptTests.swift` uses `@testable import` to reach `XAI.cleanup`.
- Contract declarations for later workstreams:

  ```swift
  // Providers/Provider.swift
  public struct Provider: Identifiable, Sendable {
    public var id: ProviderID          // Settings.provider and the Keychain account
    public var name: String            // Settings and error wording
    public var summary: String
    public var credential: Credential
    public var transcription: TranscriptionService
    public var voice: VoiceService
    public var cleanup: CleanupService?
    public init(id:name:summary:credential:transcription:voice:cleanup:)
  }
  public struct ProviderID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String        // encodes as a bare string
  }
  public enum Credential: Equatable, Sendable {
    case none
    case apiKey(placeholder: String)
    public func isSatisfied(by key: String?) -> Bool   // .none always true
  }

  // Providers/Providers.swift
  public enum Providers {
    public static let all: [Provider]                       // [.xAI]; first is the default
    public static subscript(id: ProviderID) -> Provider     // unknown id gives all[0]
  }

  // Providers/XAI/XAI.swift
  extension Provider { public static let xAI: Provider }    // `enum XAI` is internal

  // Settings
  public var provider: ProviderID      // init parameter after `hotkey`, default Providers.all[0].id

  // App
  Keychain.key(for: ProviderID) -> String?
  Keychain.save(_ key: String, for: ProviderID) -> Bool
  Keychain.remove(for: ProviderID) -> Bool
  DictationOperation.Dependencies / Reader.Dependencies: var credential: Credential; var key: () async -> String?
  static func DictationController.describe(_ error: any Error, provider: Provider) -> String
  ```

  How the app reads the selected provider: `Providers[settings.provider]`, from the settings snapshot each dictation, Test or reading takes (`store.settings` in views and the menu bar). Workstream 5 builds the picker by writing `store.settings.provider`; the controller's key status and the API Key tab's saved key follow that change on their own.
- Decisions:
  - `Settings.provider` stores a `ProviderID`, not a `Provider`, because `Settings` is `Equatable` and the description holds closures. Decoding normalises through `Providers[id].id`, so storage and lookup share one fallback rule.
  - The operation and reader take the provider's `Credential` alongside the stored-key closure and fail with `noAPIKey` only when `credential.isSatisfied(by: key)` is false. A `.none` provider proceeds with a nil credential. The controller's key closure reads nothing from the Keychain for a `.none` provider.
  - `describe(_:provider:)` is a static, internal function so tests can word errors with a provider defined in the test. Dictation, Test and reading word failures with the provider from the settings snapshot they ran with, not whatever is selected when they end.
  - The provider-change refresh uses `Observations { store.settings.provider }` (macOS 26) and skips repeats, since any settings edit re-emits. Its first value replaces the old launch-time refresh.
  - `Keychain.save` keeps update-then-add for the provider's item, so a changed key keeps its access rule. The API Key tab reloads its saved key per provider with `.task(id:)`; the rest of its layout is workstream 5's.
  - The decision index (`docs/decisions/README.md`) no longer lists records (removed in `374ca0a`), so there was no entry to add.
  - The new record's "Adding a provider" section lists the three steps and what picks a provider up today; workstream 5 adds the Provider, Read Aloud and Keyterms tabs to it.
- Verification:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Settings|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|unknownProvider|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults|DictationOperation|ReadingOperation|SpeechAdmission|providerWording'`: passed, 10 core tests in 1 suite and 44 app tests in 4 suites. Top-level settings tests and `providerWording` need their own names, as `swift test list` shows.
  - Full deterministic suite `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test` ran once: 90 core and 66 app tests passed.
  - `swift build --product EchoTypeApp`: passed with no warnings. `git diff --check` and `git diff --cached --check`: clean.
  - `grep -rnE 'XAI\.|xai|xAI|x\.ai' Sources | grep -v '^Sources/EchoTypeCore/Providers/XAI/' | grep -v '^Sources/EchoTypeCore/Providers/Providers.swift'` prints nothing.
- Known limitations or external checks: Keychain by account is checked in G3 (reading the existing `xai` item after upgrade, save, remove and a wrong key). The live xAI tests were not run. A provider switch cannot happen in the app until workstream 5 adds the picker, so the refresh-on-change path is exercised only by code review until then.
- Specification drift: none. `Credential.isSatisfied(by:)`, `Providers[id]` and the `credential` dependency are declaration details.

## Independent review

- Reviewer: independent review agent, fresh session. Reviewed the staged diff `git diff --cached HEAD` on base `6723fab` (plan.md excluded).
- Verdict: accept. No Required findings. Every acceptance criterion is met:
  - `git grep` finds no xAI service value or `XAI.` reference in `Sources/` outside `Providers/XAI/`, apart from `Providers.all = [.xAI]` in the registry. `XAI` is internal, so the compiler enforces this for the app target. The controller's dictation, Test and reader factories read `Providers[settings.provider]` from the snapshot each one takes.
  - `SettingsTests` cover a missing `provider` (`missingFieldsDefault`), an unknown one (`unknownProvider`, which also keeps the other fields) and a round trip that checks `"provider":"xai"` is written. The pinned payload in `storedValueDecodes` includes the key.
  - `providerWording` words every `ProviderError` and both `noAPIKey` errors with a provider defined in the test, and pins today's xAI text. `noCredentialNeeded` in `DictationOperationTests` and `ReadingOperationTests` shows a `.none` provider proceeds with a nil key and sends a nil credential. `missingKey` shows an `.apiKey` provider with no key fails before any service starts, and that dictation still releases capture.
  - `Keychain` reads, saves (update, then add) and removes by `kSecAttrAccount` = provider id. The any-account read and the delete-every-item `clear` are gone, with no remaining callers. Checking this on the Mac is left to G3, as 0019 requires.
  - Lifecycle is unchanged. `DictationOperation` still runs `checkStartup()` after the key read and before throwing `noAPIKey`. `Reader` still checks `checkStopped()` before its credential guard. The launch refresh now runs in the `Observations` loop. That loop is only in the convenience init, so test controllers never read the Keychain. The generation counter still drops stale results.
  - Dependency direction holds. `Provider`, `Credential` and `Providers` are in `EchoTypeCore`. `Settings` depends only on the registry for its fallback. The app imports Core and never the reverse.
  - Decision records: 0025 is new. 0006 now describes `ProviderError` wording and drops `STTError`, which closes workstream 3's leftover. 0010 now covers the `provider` key and one Keychain item per account. All three match the code.
  - Checks run with `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV=`:
    - The handoff's targeted filter passed 10 core tests in 1 suite and 44 app tests in 4 suites.
    - `--filter 'unknownProvider|providerWording|noCredentialNeeded|missingKey'` passed 5 tests.
    - `swift build --product EchoTypeApp` passed with no warnings.
    - `git diff --cached --check` was clean.
- Required findings: none.
- Optional observations:
  1. Switching provider in the API Key tab (`Views/SettingsView.swift`, `APIKeyTab`) needs workstream 5 to handle the transient state. `.task(id: provider.id)` reloads `savedKey`, but `loaded` stays true, so the previous provider's masked key shows under the new name until the read returns. `replacing`, `draft`, `revealed`, `testOutcome` and any error also carry over. If the provider changes during a save, `savedKey = key` shows the old provider's key on the new provider's tab. The picker can't be reached until workstream 5, and that workstream restructures the tab, so it should reset this state per provider. This is not a defect here.
  2. After a provider switch, `hasAPIKey` keeps the old provider's value until `refreshAPIKeyStatus` finishes, while `statusLine` (`App.swift`) already shows the new provider's name. The mismatch is brief and can't be reached until workstream 5. Setting `hasAPIKey = nil` at the start of a provider-change refresh would show "Checking API key…" instead. This is optional.
  3. `Resources/Info.plist` `NSMicrophoneUsageDescription` still says the app "sends your speech to xAI". This is product copy outside the README exemption and outside this packet's scope. The final review or the Apple provider work should decide on it.
- Questions: none.

## Resolution

- Recovery audit: the complete staged and unstaged diff is based on the previous accepted workstream 3 commit `6723fab`. Every changed file belongs to this workstream, including the handoff's explained service-reference replacements and integration-test import. Implementation and independent review are complete in the record; no implementation changes followed that review. Resume at focused closure. Remediation passes used: zero.
- Finding dispositions: no Required findings or Questions. Optional observation 1 is deferred to workstream 5's Provider tab, where provider changes become reachable; reset and isolate key-editor state there. Observation 2 is deferred as optional, since xAI is the only registered provider and the picker is not present. Observation 3 is deferred to final review's provider-name and documentation check, which includes `Resources/Info.plist`.
- Simplification/deletion pass: the old any-account Keychain read, service-wide remove and direct xAI wiring are gone. The registry lookup is one fallback rule, and `.none` avoids Keychain reads without an availability flag or additional credential machinery. No further deletion is needed within this packet.
- Final verification: recovery reran `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Settings|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|unknownProvider|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults|DictationOperation|ReadingOperation|SpeechAdmission|providerWording'`, passing 10 core tests in 1 suite and 44 app tests in 4 suites. `swift build --product EchoTypeApp` and diff whitespace checks pass. Keychain checks remain in G3; no real key or live paid service was accessed.

## Closure review

- Verdict: accept. Fresh closure session inspected the complete staged and unstaged diff against `HEAD` at `6723fab`, the recorded independent review and its dispositions. There were no Required findings, no remediation and no implementation changes after independent review. No release-blocking defect was found. The optional key-editor state observation belongs to workstream 5, the brief credential-status mismatch stays optional, and the microphone copy is deferred to final review as recorded.
- Verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'settingsRoundTrip|storedValueDecodes|missingFieldsDefault|unknownProvider|providerWording|noCredentialNeeded|missingKey'` passed 4 core tests and 5 app tests in 2 suites. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift build --product EchoTypeApp` passed with no warnings. `git diff HEAD --check` and `git diff --cached --check` were clean. The provider-name search in `Sources/` matched only `Providers/XAI/` and the registry. Keychain queries constrain every operation to the provider account by inspection; their Mac verification remains in G3. No real Keychain item, running app or paid service was accessed.
- Remaining required findings: none.
