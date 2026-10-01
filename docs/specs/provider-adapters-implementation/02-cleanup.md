# Workstream 2: Cleanup adapter and always-on cleanup

Status: accepted.

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

- Base commit: `3b961c9` (workstream 1 accepted). All work is uncommitted; source, test and decision-record changes are staged so the rename shows. Review with `git diff HEAD` (plan.md is the lead's).
- Outcome: complete within scope. `Reviser` sends every request through a neutral `CleanupService`, carrying `Reviser.prompt`, the window, whether it is final and the credential. The xAI chat request (endpoint, `grok-4.3`, temperature 0, reasoning effort `none`, 5 s live and 3 s final timeouts, 5 s resource limit) is `XAI.Cleanup` in `Providers/XAI/XAICleanup.swift`, exposed as `XAI.cleanup`. `RevisionRequest.swift` is gone (renamed into `XAICleanup.swift`). `DictationOperation.Dependencies` replaces the `revise` factory with `cleanup: CleanupService?` and `revisionClock`; the operation builds a `Reviser` only outside Test and only when `cleanup` is non-nil. The controller wires `XAI.cleanup`. `Settings.cleanUp`, the General tab toggle, `DictationTrace.cleanUp` and Last Dictation's "cleanup off" label are removed; the summary always shows the request count, so a dictation without cleanup reads "0 requests".
- Files changed:
  - Core: `Providers/Provider.swift` (cleanup contract), `Providers/XAI/XAI.swift` (`cleanup`), `Providers/XAI/XAICleanup.swift` (was `RevisionRequest.swift`), `Reviser.swift`, `DictationTrace.swift`, `Settings.swift`.
  - App: `DictationOperation.swift`, `DictationController.swift`, `Views/SettingsView.swift` (toggle only), `Views/LastDictationWindow.swift`.
  - Tests: `ReviserTests`, `SettingsTests`, `SettingsValidationTests`, `DictationTraceTests`, `Integration/RevisionPromptTests.swift`, `DictationOperationTests`, `SpeechAdmissionTests`.
  - Docs: decision records 0021 and 0010. 0023 doesn't mention the label, so it is unchanged.
- Contract declarations for later workstreams:

  ```swift
  // Providers/Provider.swift
  public struct CleanupService: Sendable {
    public var revise: @Sendable (CleanupRequest) async throws -> String
    public init(revise: @escaping @Sendable (CleanupRequest) async throws -> String)
  }
  public struct CleanupRequest: Equatable, Sendable {
    public var prompt: String      // Reviser.prompt
    public var text: String        // the window
    public var final: Bool         // the user is waiting; give up sooner
    public var credential: String?
    public init(prompt: String, text: String, final: Bool, credential: String?)
  }

  // Providers/XAI/XAI.swift
  public static let cleanup: CleanupService   // XAI.cleanup; XAI.Cleanup is internal

  // Reviser
  public static let prompt: String
  public init(cleanup: CleanupService, credential: String?, finalClock: any SessionClock = SystemClock())

  // DictationOperation.Dependencies (app)
  var cleanup: CleanupService?           // nil: insert the committed text unrevised
  var revisionClock: any SessionClock    // the final revision budget
  ```

  Workstream 4 replaces the controller's `cleanup: XAI.cleanup` with the selected provider's optional service.
- Decisions:
  - The credential is passed to `Reviser` once and copied into each `CleanupRequest`, matching the spec's request shape. `XAI.Cleanup` sends no `Authorization` header when it is nil, as `XAI.transcription` does.
  - The final-revision clock became its own dependency (`revisionClock`) because the operation now builds the `Reviser` itself and `SessionClock` holds one schedule per instance, so it can't share `clock`. The controller passes `SystemClock()`.
  - Removing `cleanUp` from `CodingKeys` is enough to ignore it, as with `batchOnCommit`. The storage comment names both retired keys. `storedValueDecodes` now pins this version's bytes without `cleanUp`, and `retiredKeysIgnored` (was `payloadBeforeReadAloudDecodes`) decodes a payload holding both retired keys plus a non-default field, then checks that re-encoding has no `cleanUp`.
  - One new parameterised operation test, `cleanupService(cleanup:)`, covers both paths: without a service the committed text is inserted with no revisions and no final call; with one, revisions are recorded and the final call runs once. The other harness tests keep `cleanup: false` as their default, which now means a nil service.
  - `ReviserTests.revisionRequests` checks each request carries `Reviser.prompt`, the credential and the right `final` flag. The other reviser fixtures are unchanged in meaning; a private helper adapts their text closures to a `CleanupService`.
- Verification:
  - `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Reviser|Settings|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults|dictationTrace|liveRevisionPromptCases|DictationOperation|SpeechAdmission'`: passed, 23 core tests (the live prompt test skipped without a key) and 25 app tests (the filter also matches `CoordinatorTests/microphoneTestRetainsLastDictationAndIgnoresCommands`). Top-level settings and trace tests need their own names in the filter, as `swift test list` shows.
  - `swift build --product EchoTypeApp`: passed.
  - `git diff --check`: clean.
  - `grep -rn "cleanUp\|RevisionRequest\|Clean up text" Sources Tests` finds only the retired-key comment in `Settings.swift` and the retired-key test. The prompt appears only in `Reviser.swift`.
- Known limitations or external checks:
  - Covered by gate G3. The live prompt test was not run.
  - Outside this packet: `docs/images/settings-general.png` still shows the Clean up text toggle, and README's "Clean up text" feature bullet still reads correctly but uses the old toggle's name.
- Specification drift: none. `revisionClock` is a declaration detail of the operation's injected final-revision budget.

## Independent review

- Reviewer: independent review agent (Claude Code, fresh session), against base `3b961c9` and the uncommitted diff.
- Verdict: accept. No required findings.
- Evidence checked:
  - Contract matches the specification's Cleanup section: `CleanupService.revise(CleanupRequest)` with `prompt`, `text`, `final`, `credential`, in `Providers/Provider.swift`. `XAI.cleanup` is the only public xAI cleanup symbol; `XAI.Cleanup` is internal.
  - The xAI request is byte-for-byte today's (endpoint, `grok-4.3`, `reasoning_effort` `none`, temperature 0, 3 s final / 5 s live timeouts, 5 s resource limit, `XAI.error(httpStatus:)`). The only change is that a nil credential omits `Authorization`, which the operation never passes (the key is non-optional there).
  - `Reviser.prompt` is the moved prompt text, unchanged; `Providers/XAI/` contains no prompt. `Reviser` names no provider. Windows, faithfulness, reply-request protection, final budget and fallbacks are untouched; only the request call site changed.
  - `DictationOperation` builds a `Reviser` only when `!isTest` and `cleanup != nil`, and the trace is created for every non-test dictation as before. The separate `revisionClock` is justified: the operation now constructs the `Reviser`, and the harness needs a manual final-budget clock distinct from `clock` and `testClock` (`finalRevisionDeadline` advances it).
  - `Settings.cleanUp`, its coding key, the General tab toggle, `DictationTrace.cleanUp` and the "cleanup off" label are gone; the summary always shows `requestCounts`, so a dictation without cleanup reads "0 requests". `DictationTrace` is in-memory only, so dropping its field has no persistence impact.
  - `retiredKeysIgnored` decodes a payload with both retired keys plus a non-default `sendReplyRequests` and checks re-encoding omits `cleanUp`, covering the acceptance criterion. `cleanupService(cleanup:)` covers both operation paths with meaningful assertions (no revisions and no final call without a service).
  - Grep of `Sources`, `Tests` and decision records for `cleanUp|RevisionRequest|Clean up text|cleanup off|finalRequest` finds only the retired-key comment, the retired-key test and 0010/0021's history notes. Decision records 0010 and 0021 are accurate; 0023 does not mention the label.
  - Reran `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Reviser|Settings|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults|dictationTrace|liveRevisionPromptCases|DictationOperation|SpeechAdmission'`: 23 core and 25 app tests passed. `swift build --product EchoTypeApp` passed; `git diff HEAD --check` clean.
- Required findings: none.
- Optional observations:
  - O1. `README.md` line 25 still headlines the feature as "**Clean up text.**" and `docs/images/settings-general.png` still shows the toggle. The specification's Documentation section asks for the README to reflect the removed toggle, but this packet doesn't own README or images. Leave for workstream 4 (which owns the Settings window) or the final review; worth recording in the plan so it isn't lost.
  - O2. `XAI.Cleanup` has no deterministic test of its request shape (headers, body keys, timeouts); only the opt-in live prompt test exercises it. This matches the pre-change coverage of `RevisionRequest`, so it is not a regression.
  - O3. In `ReviserTests`, `let reviser = reviser({ ... })` shadows the file-private helper with a local of the same name. It compiles and reads acceptably; renaming the helper (for example `textReviser`) would be marginally clearer. Not worth a remediation pass on its own.
- Questions: none.

## Resolution

- Recovery: the first lead and implementation agent stopped mid-implementation (row Implementing, record empty). The new lead confirmed the uncommitted work sat on `3b961c9` and touched only this packet's files, kept the core contract, adapter and `Reviser` changes, and had a fresh implementation agent finish the work. No remediation pass was used before or after.
- Finding dispositions: no required findings, so no remediation pass.
  - O1 deferred. `README.md` belongs to workstream 5, whose packet already requires the README to describe always-on cleanup. `docs/images/settings-general.png` (still shows the toggle) has no owner; the final review's documentation check should pick it up.
  - O2 rejected: same coverage as `RevisionRequest` had, and the request is unchanged.
  - O3 rejected: cosmetic.
- Simplification/deletion pass: done by the implementation agent. `RevisionRequest.swift`, the `revise` factory, `finalRequest`, `Settings.cleanUp`, `DictationTrace.cleanUp`, the toggle and the "cleanup off" label are deleted with no aliases or compatibility paths.
- Final verification: the reviewer's rerun of the handoff's filter (23 core, 25 app tests passed), `swift build --product EchoTypeApp` and `git diff HEAD --check` are on the reviewed state, which is unchanged since.

## Closure review

- Reviewer: closure review agent (Claude Code, fresh session), against base `3b961c9` and the uncommitted diff.
- Verdict: accept. The reviewed state holds: no required findings were raised and no remediation pass ran, and the diff still meets every acceptance criterion (nil `cleanup` inserts unrevised with no revisions, `Reviser` is built only outside Test with a service, retired `cleanUp` is ignored on decode and not encoded, no stray `cleanUp`/`RevisionRequest`/toggle references, prompt only in `Reviser.swift`).
- Verification rerun: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test --filter 'Reviser|Settings|settingsRoundTrip|storedValueDecodes|missingFieldsDefault|malformedSendReplyRequests|retiredKeysIgnored|unreadableDataDefaults|dictationTrace|liveRevisionPromptCases|DictationOperation|SpeechAdmission'`: 23 core tests (live prompt test skipped without a key) and 25 app tests passed. `swift build --product EchoTypeApp` passed. `git diff HEAD --check` clean.
- Remaining required findings: none. O1 (README and settings screenshot) stays deferred as recorded in Resolution.
