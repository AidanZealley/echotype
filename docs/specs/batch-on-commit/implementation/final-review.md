# Batch pass on commit whole-feature review

Status: accepted, 2026-09-25.

## Reviewer task packet

Review the full branch against the starting commit in `plan.md` and the approved
[specification](../../batch-on-commit.md). Read the accepted handoffs in
[01-batch-transcriber.md](01-batch-transcriber.md) and [02-insert-batch-text.md](02-insert-batch-text.md),
then review the combined diff and surrounding code independently.

Check:

- Every item in the specification's Behaviour, Implementation and Tests sections is delivered, or
  its drift is in the plan's decision and drift log.
- The seam between the two workstreams: the PCM format, the timeout living only in
  `BatchTranscriber`, empty text treated as a fallback by the caller, and the keyterm caps defined
  once.
- Session lifecycle: the recording is collected for every session and released when it ends, the
  Keychain is read once, `test()` is unchanged, and `.nothing` and `.failed` outcomes skip the pass.
- Settings storage: the stored key name, independent decoding, and decision 0010.
- Machinery the specification does not ask for: retries, logging, network mocks, extra state or
  options.
- Test quality: the tests protect the WAV format, the request body and the stored setting, not
  implementation details.
- Documentation agreement: decision 0017, the index, decision 0010, doc comments in
  `DictationController`, and the specification's status.

Run `swift build` and `swift test`. Do not launch the app or change settings; G1 covered it.
Classify evidence as Required, Optional or Question, and name the owning file for each Required
finding.

## Initial whole-feature review

- Reviewer: fresh general-purpose agent
- Branch, base, and reviewed head: `feat/batch-on-commit`, base `2acb117`, head `377519d`
- Verification run: `swift build` "Build complete!". `swift test` "Test run with 47 tests in 1
  suite passed", including `wavReadsBack` and `batchRequestFields`; `LiveProtocolTests` skipped
  without `XAI_API_KEY`. App not launched.
- Acceptance-criteria audit:
  - Behaviour: the toggle and caption sit after `LanguageRow` (`SettingsView.swift:42-47`).
    `batchPass` returns the outcome untouched when the setting is off or the outcome is not
    `.insert`, and keeps `live` on a throw or empty text (`DictationController.swift:150-158`).
    `test()` discards the key and the recording (`:175`, `:183`). Nothing touches the pill
    between `run` and `finish`, and `Pill.apply` ignores the final `idle` (`:379-380`).
  - Escape, hotkey and click during the pass: `phase` stays `.running` until `dictate()`
    returns. The hotkey and a click call `commit()`, whose `audio.stop()` returns at
    `guard let session` (`AudioCapture.swift:64-66`). Escape is consumed and calls
    `session.cancel()`, which returns at `guard isActive` (`SessionMachine.swift:141-142`). That
    matches finalizing, as the spec asks. `isIdle` is false, so Test stays disabled.
  - Memory: the recording is a local in `pump`, then `run`, then `dictate()` (`:141`). It is
    released when `dictate()` returns, after `finish`, as 0017 says. Nothing writes it to disk.
  - Seam: `pcm` is the pump's chunks unchanged; the 5 s `timeoutIntervalForResource` lives only
    in `BatchTranscriber` and the caller adds none; empty text falls back in the caller; the
    caps live once in `STTConnection.keyterms(settings:)`, used by both requests. The Keychain
    is read once, in `start` (`:216`), and the key travels in `.started`.
  - Settings: `batchOnCommit` is stored under that key and decoded on its own with a `true`
    default (`Settings.swift:136-137`). The pinned payload and `missingFieldsDefault` cover it.
    0010 lists the key.
  - No retries, logging, network mocks or extra state. Tests cover the WAV format, the request
    body and the stored setting.
  - Docs: 0017 matches the code and G1 and is in the index. The `DictationController` doc
    comments describe the pass and the recording. The spec's status says implemented. The
    endpointing revert is in the drift log.
- Required findings by owner: none.
- Optional observations:
  1. A session that reaches the 10 minute hard cap ends as `.insert` and runs the pass on
     about 19 MB. It will most likely hit the 5 s timeout or a 413 and fall back, so the user
     waits 5 s longer for the live text. The spec expects dictations under a minute, so this
     doesn't block.
  2. Whitespace-only batch text still replaces `live` (`DictationController.swift:156`,
     `!batch.isEmpty`). Workstream 2 declined this and left it for this review. It's
     improbable and matches the spec's "empty" literally. Trimming before the check would
     cost nothing.
  3. When the microphone fails mid-session with text settled, the pass runs on the partial
     recording before the red error shows, so the error appears up to 5 s later. Harmless.
- Questions: none.
- Verdict: accept. No Required findings.

## Lead triage

- Accepted findings and owners: Optional 2 promoted to Required, owner
  `DictationController.swift`. Whitespace-only batch text would become an `.insert` whose
  `SessionMachine.Outcome` contract says "Never empty", and would replace the user's words.
  `batchPass` now falls back when the batch text is all whitespace, which includes empty.
- Rejected findings and reasons: none.
- Deferred optional observations: Optional 1 (a hard-cap session sends about 19 MB and most
  likely falls back after the 5 s timeout) and Optional 3 (a microphone failure's error shows
  after the pass). The spec expects dictations under a minute, and both still end with the
  user's text or error.
- Drift requiring user decision: none. The endpointing revert is already approved in the
  decision and drift log.

## Focused closure

- Reviewed head: `377519d` with the uncommitted correction, base `2acb117`. `swift build`
  "Build complete!". `swift test` "Test run with 47 tests in 1 suite passed". App not launched.
- Finding outcomes: promoted Optional 2 is fixed. `batchPass` now guards with
  `!batch.allSatisfy(\.isWhitespace)` (`DictationController.swift:156`), which is true for an
  empty string, so empty and whitespace-only batch text both keep `live`. The `.insert`
  outcome can no longer be blank. The doc comment above it says "returns only whitespace". The
  change is one line, adds no state or branch, and touches nothing else. No new test, which
  suits a one-line guard in the app target that has no test seam. 0017 and the spec still say
  "empty text"; whitespace-only is a superset of that, so the docs remain true.
- Final simplification assessment: the branch is about as small as the spec allows.
  `BatchTranscriber` is one stateless enum with three functions that the tests exercise
  directly. The recording rides out through the existing `pump` and `run` returns rather than
  new controller state. The API key travels in `.started` instead of a second Keychain read.
  The keyterm caps moved into one shared `STTConnection.keyterms(settings:)`. The setting is one
  field with independent decoding. No retries, logging, protocols or mocks. Nothing left to
  delete.
- Remaining blockers: none.
- Verdict: accept. The accepted finding is fixed and the correction introduces no defect.

## Completion record

- Final verification: `swift build` passes; `swift test` passes 47 tests, with
  `LiveProtocolTests` skipped without `XAI_API_KEY`.
- External validation pending: none. G1 passed in workstream 2.
- Specification drift: the live `endpointing` revert from 5000 to 2000, approved by Aidan and
  recorded in the plan's decision and drift log. Nothing new.
