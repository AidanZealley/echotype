# Workstream 2: Cleanup adapter and always-on cleanup

Status: not started.

## Task packet

### Outcome

Dictation is cleaned up through a neutral `CleanupService`, with the xAI request in `Providers/XAI/`. The Clean up text toggle is gone: cleanup runs whenever a cleanup service is supplied, and with none the operation inserts unrevised text.

### Scope

- Add `CleanupService` and its request, as in the specification's [Cleanup](../provider-adapters.md#cleanup) section.
- Move the prompt next to `Reviser` as neutral product behaviour. Move the xAI chat request (model, temperature, reasoning effort, request limits) into an xAI cleanup adapter, exposed as a value the app wires directly, such as `XAI.cleanup`. Remove `RevisionRequest.swift`.
- `DictationOperation` creates a reviser only when it has a cleanup service, replacing the `settings.cleanUp` check. Test still never revises.
- Remove `Settings.cleanUp`. A stored `cleanUp` is ignored on decode and no longer encoded.
- Remove the General tab toggle, `DictationTrace.cleanUp` and Last Dictation's "cleanup off" label. A dictation without cleanup shows zero requests.
- Update [0021](../../decisions/0021-revise-committed-dictation.md) (cleanup always on), [0010](../../decisions/0010-settings-storage-and-api-key.md) (the ignored `cleanUp` key) and [0023](../../decisions/0023-last-dictation-window.md) if it mentions the label.

### Non-goals

- No change to revision windows, faithfulness validation, reply-request protection, budgets or fallbacks.
- No read-aloud, registry, Keychain or provider-selection changes.

### Initial ownership

- `Sources/EchoTypeCore/Reviser.swift`, `RevisionRequest.swift` (removed), `DictationTrace.swift`, `Settings.swift` (`cleanUp` only), new cleanup files under `Providers/` and `Providers/XAI/`.
- `Sources/EchoTypeApp/DictationOperation.swift` (revision dependency), `DictationController.swift` (cleanup wiring), `Views/SettingsView.swift` (General tab toggle only), `Views/LastDictationWindow.swift`.
- Tests: `ReviserTests`, `SettingsTests`, `SettingsValidationTests`, `DictationTraceTests`, `Integration/RevisionPromptTests.swift`, `Tests/EchoTypeAppTests/DictationOperationTests.swift`, `SpeechAdmissionTests.swift`.
- Decision records 0021, 0010, 0023, this record and row 2.

### Required seams

- Consume workstream 1's `ProviderError` and xAI status mapping.
- The handoff records the final `CleanupService` declaration and the xAI cleanup service value for workstream 4.

### Acceptance criteria

- An operation without a cleanup service inserts the committed text unrevised and records no revisions. This replaces the `cleanUp: false` cases.
- An operation with a cleanup service keeps today's live and final revision behaviour. The existing reviser fixtures pass unchanged in meaning.
- Decoding stored settings that contain `cleanUp` keeps every other field. Encoding no longer writes `cleanUp`.
- Nothing references `cleanUp`, `RevisionRequest` or the toggle. The prompt is not in `Providers/XAI/`.

### Targeted verification

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Reviser|Settings|DictationTrace|DictationOperation|SpeechAdmission'
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
- Known limitations or external checks: covered by gate G3
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
