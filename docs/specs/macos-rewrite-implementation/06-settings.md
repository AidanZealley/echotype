# Workstream 6: Validate settings compatibly

Status: Accepted.

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

- Base commit: `7198c32612b45aaf9d1090e6833174c70e134e65` on `refactor/macos-lifecycle`. The only pre-existing change was the lead's row-6 Implementation transition. Read the approved spec, workflow, plan, README, global instructions, relevant decisions and accepted dependency records. Applied `unslop` and `writing-for-agents` to this handoff.
- Outcome: One Settings policy supplies finite speech speed within 0.7 through 1.5, with default 1.0, to field-by-field decoding, settings encoding and speech request encoding. Invalid speed does not discard valid preferences. Public construction and mutation with NaN, either infinity or out-of-range finite speed encode safely. Valid fractional values survive unchanged. The slider shares the range and retains its existing 0.1 step.
- Files changed: `Sources/EchoTypeCore/Settings.swift`, `Sources/EchoTypeCore/TTS/Speech.swift`, `Sources/EchoTypeApp/Views/SettingsView.swift`, new `Tests/EchoTypeCoreTests/SettingsValidationTests.swift`, `Tests/EchoTypeAppTests/SpeechAdmissionTests.swift`, decisions 0010/0018 and their index, and this Implementation handoff. The lead owns plan/status/review records. SettingsStore, Reader, coordinator production code, existing persistence fixtures, API-key storage and request signatures are unchanged.
- Decisions: Retained the nonthrowing request and persistence APIs. Their only encoded double now passes the shared policy, so the existing force-try encoders cannot trap on invalid speed. No throwing alias, migration, schema version or generic validator was needed. `Settings.speechSpeed` remains publicly mutable; validation occurs at the persistence/request boundaries. Storage keys, modifier raw values, defaults and per-field fallback are preserved. Code audit confirms HotkeyMonitor reads both chords live and the accepted coordinator captures Settings when reserving reading or constructing dictation/Test.
- Compatibility evidence: The new CoordinatorTests declaration first completes a real fake-backed dictation, then holds Test capture at an explicit acknowledgement. It verifies ignored dictation/read-aloud hotkeys, Escape and Space passing through, busy supplied speech and another Test being declined. A fake capture failure finishes Test with no extra insertion and preserves the nonempty prior Last Dictation exactly. Existing successful Test coverage separately proves five-second completion without insertion, destination capture, overlay or trace. Existing reading and speech-admission suites verify arbitration and operation isolation without changing the accepted coordinator.
- Verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` selected three `SettingsValidationTests` declarations and one `CoordinatorTests` declaration, recorded in `.build/settings-test-list.txt`. The exact packet filter passed 11 core declarations and one app declaration, 12 total. The three validation declarations cover six malformed/stored cases, three valid boundary/fractional cases and five public invalid cases through construction and mutation. Log `.build/settings-tests.log`. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'microphoneTest|SpeechAdmissionTests|ReadingOperationTests|HotkeyAdapterTests'` passed 24 declarations, log `.build/settings-compatibility-tests.log`. `swift build --product EchoTypeApp` and `git diff --check` passed, build log `.build/settings-build.log`.
- Simplification/deletion: Replaced the duplicated UI range literal with the Settings range and retained one computed boundary value. Reused the existing fake coordinator fixture with held Test capture rather than adding another production seam or test driver. No obsolete facade, unused validator, duplicate mutable state, new timing knob, retry or lifecycle machinery remains.
- Known limitations or external checks: Assembled settings UI is reserved for Final, as required by the packet. Existing approved manual deferrals and live-test allowances are unchanged. This slice ran deterministic tests and an unsigned build only. No live TTS/STT/cleanup, microphone Test, key inspection/export, GUI focus/restart, permission grant, install, production replacement or publication occurred.
- Specification drift: none. Work remains uncommitted for independent review.

## Independent review

- Reviewer: fresh independent lead subagent, reviewed against base `7198c32612b45aaf9d1090e6833174c70e134e65`.
- Verdict: no Required defect found. Inspected the complete tracked diff, untracked validation suite, approved specification, dependency handoffs and surrounding settings/coordinator/reading code. One Settings policy validates decoding, settings encoding and speech requests. Invalid stored speed retains valid fields; public construction and mutation cannot send a nonfinite or out-of-range speed into either JSON encoder. Valid boundary and fractional speeds, storage keys, modifier bits and request fields remain compatible. The slider retains its 0.1 step. API-key storage, live hotkey matching and per-operation snapshots are unchanged.
- Required findings: none. The new coordinator test preserves a nonempty prior Last Dictation and insertion count while Test rejects dictation/read-aloud commands, Escape, Space, supplied speech and another Test. Its acknowledged capture failure complements the existing successful five-second Test fixture, which verifies no insertion, destination capture, overlay or trace. No production lifecycle change, duplicated validator, unused facade, migration or generic machinery was introduced.
- Optional observations: none added by this review.
- Questions: none.
- Independent verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test list` confirmed all three validation declarations and the coordinator declaration. The packet's exact filter passed 11 core declarations and one app declaration, 12 total. `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'microphoneTest|SpeechAdmissionTests|ReadingOperationTests|HotkeyAdapterTests'` passed 24 declarations. `swift build --product EchoTypeApp` and `git diff --check` passed. Logs are `.build/settings-review-test-list.txt`, `.build/settings-review-tests.log`, `.build/settings-review-compatibility-tests.log` and `.build/settings-review-build.log`.
- Limits: assembled settings UI remains for Final. Existing manual deferrals remain unchanged. Review used deterministic tests and an unsigned build only, with no live calls, GUI interaction/restart, microphone Test, key inspection/export, permission grants, installation, production replacement, publication or commit.

## Resolution

- Finding dispositions: Independent review found no Required, Optional or Question findings. Lead audit accepts the evidence and unchanged compatibility boundaries; no remediation pass is needed.
- Simplification/deletion pass: One computed Settings value supplies validation to both encoders and decoding; the slider reuses its range. No duplicate default/range, schema migration, throwing compatibility facade or production test seam remains. Coordinator production code and settings storage are unchanged.
- Final verification: Independent review reran the packet filter, 12 declarations, and compatibility filter, 24 declarations, plus app build and diff whitespace checks. Fresh focused closure passed all four focused declarations with no remaining Required finding. No hardware gate is assigned to this packet; assembled settings UI remains for Final.

## Closure review

- Reviewer: fresh focused closure subagent, checked against base `7198c32612b45aaf9d1090e6833174c70e134e65`. Applied `unslop` and `writing-for-agents` to this record.
- Verdict: closure passes. Independent review recorded no Required, Optional or Question findings, and the lead accepted that result without remediation. Verified that the recorded closure basis matches the implementation and tests; no release-blocking defect found. The shared Settings policy still supplies finite, ranged speed at decoding and both encoding boundaries, preserves valid fractional values and leaves storage keys, live hotkeys and operation snapshots unchanged. Coordinator production code remains unchanged.
- Remaining required findings: none. No optional work promoted and no further review loop needed.
- Verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'SettingsValidationTests|CoordinatorTests'` passed all four declarations, including the stored malformed cases, valid boundary/fractional cases, public invalid construction/mutation cases and prior Last Dictation retention during Test. Log `.build/settings-closure-tests.log`. Checked the independent review's recorded packet/compatibility test and build logs; their passing results support the lead's resolution. `git diff --check` passed before and after this record edit.
- Limits: assembled settings UI remains for Final. Accepted manual deferrals and live-test limits are unchanged. Closure used deterministic tests only and edited this section only. No live calls, GUI/focus/restart, microphone Test, key inspection/export, grants, installation, production replacement, publication or commit occurred.

## Acceptance audit

- Lead confirmed base `7198c32612b45aaf9d1090e6833174c70e134e65`, integration branch and durable Accepted rows 1 through 5. All changed paths belong to packet 6, including the added validation suite and narrow coordinator compatibility fixture. The frozen Task packet is unchanged.
- Independent review and fresh focused closure pass without findings; no remediation was used. Lead inspected the complete diff, shared validation, unchanged persistence/request signatures and explicit Test acknowledgement. Targeted checks establish spec case 12 without new production machinery.
- No external gate belongs to packet 6. Final owns assembled settings UI and G7. Existing G1/G2/G4/G5/G6 deferrals, Foundation buffering limitation and Optional packet-4 fixture observation persist. G5/G6 live allowances remain exhausted; no live or GUI action occurred.
- Drift: none. SettingsStore, coordinator and Reader production code, Keychain identity and operation handoffs remain unchanged. Code and completed records are ready for the single acceptance commit.
