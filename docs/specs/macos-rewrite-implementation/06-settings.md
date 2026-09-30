# Workstream 6: Validate settings compatibly

Status: not started.

## Task packet

### Outcome

Stored and programmatically constructed settings cannot crash speech/request encoding, and valid existing preferences survive the rewrite.

### Scope and non-goals

Validate finite speech speed in the supported 0.7 through 1.5 range at the persistence and request boundaries. Invalid values fall back to `Settings`' default. Preserve valid fractional values, current storage keys, modifier raw values and per-field fallback. Ensure settings encoding cannot trap on a publicly constructible invalid speed. Keep API key outside settings.

Adjust only the settings store/view/request call sites necessary for a coherent validation policy. Preserve live hotkey matching and per-operation setting snapshots. Verify microphone Test cannot insert or replace Last Dictation through the accepted coordinator.

Do not add settings schema versions, generic validation frameworks, migrations for unchanged keys, configurable timing knobs, new settings or redesign the UI. Other fields retain their existing product constraints unless the spec already requires a boundary correction.

### Initial ownership

- `Sources/EchoTypeCore/Settings.swift`, `TTS/Speech.swift`, `Tests/EchoTypeCoreTests/SettingsTests.swift`, `SpeechTests.swift`.
- `Sources/EchoTypeApp/SettingsStore.swift`, `Views/SettingsView.swift`, `Reader.swift` or accepted reading request call site only if its signature changes.
- New `Tests/EchoTypeCoreTests/SettingsValidationTests.swift`; app settings/coordinator tests if meaningful compatibility coverage is missing.
- Decision 0010 and affected 0018/index, this record, row 6 and escalations.

### Required seams

One validation policy supplies finite/ranged speed to storage and requests. Avoid duplicating range/default constants in multiple layers. Preserve existing valid request fields and persistence fixtures. If a throwing signature is necessary, update all callers in this slice; do not preserve a trapping alias.

### Acceptance criteria

- Spec case 12 passes. Malformed speed does not discard valid preferences; invalid finite values and nonfinite programmatic values cannot trap.
- Round-trip/settings compatibility fixtures retain valid values and unchanged keys.
- Speech requests only encode valid speed; UI slider behavior remains unchanged.
- Test operations retain non-insertion/no-trace behavior; command arbitration and snapshots do not regress.
- No duplicated validation or unused compatibility facade is left behind.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'SettingsValidationTests|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|malformedSendReplyRequests|payloadBeforeReadAloudDecodes|unreadableDataDefaults|speechRequestFields|speechCap|CoordinatorTests'
swift build --product EchoTypeApp
git diff --check
```

Create the named validation suite; verify nonzero selection with `swift test list`. Test invalid speed at the actual public construction/encoding/request boundaries rather than mirroring the implementation's helper. No new hardware gate is needed; the assembled settings UI is checked at Final.

## Implementation handoff

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Decisions: TBD
- Verification: TBD
- Known limitations or external checks: TBD
- Specification drift: TBD

## Independent review

- Reviewer: TBD, lead subagent
- Verdict: TBD
- Required findings: TBD
- Optional observations: TBD
- Questions: TBD

## Resolution

- Finding dispositions: TBD
- Simplification/deletion pass: TBD
- Final verification: TBD

## Closure review

- Verdict: TBD
- Remaining required findings: TBD
