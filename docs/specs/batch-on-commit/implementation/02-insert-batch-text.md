# Workstream 2: Insert the batch text on stop

Status: Accepted.

## Task packet

### Outcome

With **Re-transcribe on stop** on, a committed dictation inserts the batch transcription of the
whole recording, and falls back to the live text without an error when batch fails, times out or
returns empty text. With it off, dictation behaves as it did before this feature. The toggle is in
the General tab, and a decision record explains the pass.

### Scope

- In `DictationController`, the three changes in the specification's App section:
  - `pump` also collects every chunk into a local `Data` and returns it with the audio failure.
  - `Start.started` also carries the API key `start` already reads.
  - `dictate()` runs the pass between `run` and `finish` when `settings.batchOnCommit` is on and
    the outcome is `.insert`, replacing the text only with non-empty batch text.
- Update the doc comments on `DictationController`, `pump` and `run` so they describe the pass and
  the recording.
- In `GeneralTab`, a `Toggle("Re-transcribe on stop", isOn: $store.settings.batchOnCommit)` after
  `LanguageRow`, with the caption "Better punctuation, slower insertion" in secondary text, styled
  like the Login Items hint.
- A new decision record, `docs/decisions/0017-batch-pass-on-commit.md`, in the format of the other
  records: the false full stops, the observed batch response, the fallback, the timeout, the
  recording held in memory only, and the two unconfirmed parameters with what G1 found. Add it to
  the index in `docs/decisions/README.md`.
- Set the specification's status line to implemented, with the date.

### Non-goals

- `SessionMachine`, `Pill`, `PillView` and `OverlayPanel`. The pill already stays on
  `Transcribing` when `run` returns.
- The Test button path. `test()` never runs the pass and ignores the recording.
- Letting Escape or the hotkey cancel the pass, a batch error in the pill, retries or logging.
- Writing the recording to disk.
- Controller tests. The app target has no tests; G1 covers the wiring.
- Any file owned by workstream 1. Raise an escalation for a defect there.

### Initial ownership

- `Sources/EchoTypeApp/DictationController.swift`.
- `Sources/EchoTypeApp/Views/SettingsView.swift`, `GeneralTab` only.
- `docs/decisions/0017-batch-pass-on-commit.md` (new) and `docs/decisions/README.md`.
- `docs/specs/batch-on-commit.md`, status line only.
- This packet's record sections, and the workstream 2 row, G1 row, escalation and drift entries in
  `plan.md`.

### Required seams

Consume the plan's "Cross-workstream contracts" as workstream 1 delivered them. Pass the
collected recording as `pcm` unchanged and treat empty text from `transcribe` as a fallback.

### Acceptance criteria

1. With the setting on and outcome `.insert(live)`, `BatchTranscriber.transcribe` receives every
   chunk the session sent, including those buffered before `listening`, and the API key read once
   by `start`. Non-empty batch text is inserted instead of `live`.
2. When `transcribe` throws or returns empty text, `live` is inserted and the pill closes as after
   a normal session, with no error shown.
3. With the setting off, or with outcome `.nothing` or `.failed`, `dictate()` behaves as before.
   `test()` behaves as before.
4. The Keychain is read once per session.
5. During the pass the pill stays on `Transcribing` with the live text and never shows the batch
   text. The hotkey, Escape and a click on the pill neither start a session nor change what is
   inserted.
6. The recording lives only in memory for the session and is released when `dictate()` returns.
7. The toggle appears in the General tab after the language row with the specified label and
   caption, and its value persists through `SettingsStore`.
8. Decision 0017 exists, matches the implementation and G1's findings, and is in the index.
9. `swift build` and `swift test` pass, and `./scripts/run.sh` builds and launches the app.
10. Gate G1 has passed.

### Targeted verification

```bash
swift build
swift test
./scripts/run.sh
```

`./scripts/run.sh` stops any running EchoType, including the installed one, and launches the
development bundle. Check the toggle in Settings if you can drive the UI; otherwise G1 covers it.

## Implementation handoff

- Base commit: `095449f`
- Outcome: implemented. `pump` appends every chunk it drains to a local `Data` and returns
  `(recording, failure)`; `run` returns `(outcome, audioFailure, recording)`.
  `Start.started` carries `apiKey:`. `dictate()` calls a new private `batchPass`, which returns
  the outcome unchanged unless `settings.batchOnCommit` is on and it is `.insert`, and replaces
  it with `.insert(batch)` only when `BatchTranscriber.transcribe` returns non-empty text
  (`try?`, so any throw keeps `live`). `test()` discards the key and the recording. `phase` stays
  `.running(session)` during the pass, so the hotkey and a click call `commit()` (a repeat
  `audio.stop()`, a no-op) and Escape calls `session.cancel()`, which returns early once the
  session has ended. The recording is a local of `dictate()` and is freed when it returns.
- Files changed: `Sources/EchoTypeApp/DictationController.swift`,
  `Sources/EchoTypeApp/Views/SettingsView.swift` (`GeneralTab`: a `VStack` with the toggle and a
  caption styled like the Login Items hint, after `LanguageRow`),
  `docs/decisions/0017-batch-pass-on-commit.md` (new), `docs/decisions/README.md` (index row),
  `docs/specs/batch-on-commit.md` (status line).
- Decisions: whitespace-only batch text counts as non-empty, following the specification
  literally. Decision 0017's status reads "accepted, 2026-09-25, pending batch-on-commit gate
  G1", and its Evidence section has a `G1: pending` paragraph for the lead to replace with the
  findings for `filler_words` and `keyterm`, the inserted text and the spinner time. Update the
  status line when G1 passes.
- Decisions after G1: G1 passed on Aidan's answer (steps 1, 2 and 4; step 3 not run and
  waived). Aidan also approved reverting live `endpointing` from 5000 to 2000 (undoing
  `4b7578c`), made by this workstream in `EchoTypeCore` with his authorisation and recorded in
  the plan's decision and drift log. Decision 0017 records the revert and G1's findings.
- Verification: `swift build` clean, with no warnings. `swift test` passed, 47 tests.
  `./scripts/run.sh` built, signed and launched `.build/EchoType.app` from this diff; it is
  still running. The toggle was not checked in the UI.
- Known limitations or external checks: G1 covers the wiring, the toggle's appearance and the
  two unconfirmed parameters. The Test path also collects its five-second recording, then
  drops it.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent review agent, against base `095449f` plus the uncommitted diff.
- Verdict: no Required findings. Criteria 1 to 8 hold by reading; 9 holds for `swift build` and
  `swift test` (not relaunched; the handoff records `./scripts/run.sh`); 10 is G1, still pending.
  Checks run: `swift build` ("Build complete!"), `swift test` ("Test run with 47 tests in 1
  suite passed").
  - Criterion 1: `AudioCapture.start` builds the stream with `AsyncThrowingStream.makeStream(of:)`
    and the default unbounded buffer (`AudioCapture.swift:49`), so chunks buffered before
    `listening` are drained by `pump`, which appends each one before sending
    (`DictationController.swift:276`). The key read in `start` travels in `.started`
    (`:227`) to `batchPass` (`:142`, `:155`).
  - Criterion 2: `try?` plus `guard let batch, !batch.isEmpty else { return outcome }` (`:156`)
    keeps `.insert(live)`, and `finish` then runs the unchanged path with no error.
  - Criterion 3: `batchPass` returns the outcome untouched unless the setting is on and it is
    `.insert` (`:153`); `test()` discards the key and the recording.
  - Criterion 4: `Keychain.apiKey()` is called only in `start`; no second read was added.
  - Criterion 5: the last snapshots are `inserting` then `idle` (`SessionMachine.settle`), and
    `Pill.apply` maps `inserting` to `transcribing` and ignores `idle` (`:379`-`:380`); nothing
    updates the pill between `run` and `finish`. `phase` stays `.running`, so a press or click
    calls `commit()`, whose `audio.stop()` returns at `guard let session` because `end` cleared
    it (`AudioCapture.swift:65`, `:108`), and Escape's `session.cancel()` returns at
    `guard isActive` (`SessionMachine.swift:141`-`142`). `isIdle` is false, so Test stays
    disabled.
  - Criterion 6: the recording is a local in `pump`, `run` and `dictate()`, with no file I/O.
  - Criterion 7: the toggle binds `$store.settings.batchOnCommit` after `LanguageRow`, with the
    caption in `.caption`/`.secondary` like the Login Items hint (`SettingsView.swift:42`-`47`,
    `:346`-`348`). Persistence is workstream 1's `Settings` coding (`Settings.swift:136`, `:146`).
  - Criterion 8: 0017 matches the code and is indexed; the G1 paragraph is pending by design.
- Required findings: none.
- Optional observations:
  1. Whitespace-only batch text replaces the live text. `!batch.isEmpty`
     (`DictationController.swift:156`) lets `" "` or `"\n"` through, so the user would get
     whitespace instead of their words, and the resulting `.insert` breaks the "Text to insert.
     Never empty." contract (`SessionMachine.swift:47`). The handoff reads "non-empty" literally.
     Checking `batch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` instead would
     match the specification's intent ("If batch ... returns empty text, EchoType inserts the
     live text") at no cost. The response is unlikely to be whitespace-only, so this is not
     blocking.
  2. Decision 0017 says the recording "is released when the session ends"
     (`0017-batch-pass-on-commit.md:49`). It is released when `dictate()` returns, after the
     pass and the insertion, as acceptance criterion 6 says. A one-word change would make it
     exact.
- Questions: none.

## Resolution

- Finding dispositions: no Required findings, so no remediation pass.
  - Optional 1 (whitespace-only batch text): declined. The specification and the seam say
    "empty", a whitespace-only response is improbable, and inserting it is harmless. Left for
    the final review to weigh.
  - Optional 2 (0017 release wording): accepted as a documentation fix. The lead changed the
    sentence to say the recording is released once the pass and the insertion are done.
- Simplification/deletion pass: the diff adds one helper (`batchPass`), one tuple element on
  `run` and `pump`, and one associated value on `Start.started`. Nothing to remove.
- Final verification: `swift build` clean and `swift test` 47 passed, run by the implementation
  agent and the reviewer on this diff.
- Post-G1 review: Required 1 (drift log row missing) accepted and fixed by the lead in
  `plan.md`; it was a record gap, not code. Optional 1 (2000 not dictated since the revert)
  declined: it restores the value that shipped before `4b7578c`, and the batch pass does not
  depend on it. Final checks on the committed diff: `swift build` clean, `swift test` 47
  passed, `./scripts/run.sh` built and launched the app.

## Closure review

- Reviewer: fresh closure agent, against base `095449f` plus the uncommitted diff.
- Verdict: closed. The one accepted finding, Optional 2, is fixed. Decision 0017 now reads "is
  released once the pass and the insertion are done" (`0017-batch-pass-on-commit.md:49`-`50`).
  That matches the code: `recording` is a local of `dictate()` that stays alive through
  `batchPass` and `finish` (`DictationController.swift:141`-`143`), which is what criterion 6
  says. The fix touches only that sentence, so it adds no release-blocking defect. The source
  diff has not changed since the independent review, and `swift build` reports "Build
  complete!". The declined Optional 1 and the pending G1 paragraph are outside this closure.
- Remaining required findings: none.

### Post-G1 review

- Reviewer: fresh review agent, limited to the post-G1 correction (endpointing revert and
  decision 0017) against base `095449f` plus the uncommitted diff.
- Verdict: the revert is exact and complete, and 0017 matches the code and G1. One Required
  record gap in `plan.md`.
  - Revert: `git diff` on `STTConnection.swift`, `STTConnectionTests.swift` and
    `docs/specs/echotype-v1.md` is the line-for-line inverse of `git show 4b7578c` on the same
    three files (value `5000` to `2000` in code, test and spec URL; the two added comment lines
    and the three added spec lines removed). The test and the spec are byte-identical to
    `4b7578c^`. `STTConnection.swift` differs from `4b7578c^` only by workstream 1's committed
    `keyterms(settings:)` refactor.
  - No stale claims: `grep -rnE "5000|endpointing"` over `*.md` and `*.swift` finds `5000` for
    live endpointing only in the batch-on-commit spec's Problem section (intentional), 0017's
    Context (historical, and says it went back to 2000), and the E1 entry and this packet.
    `OverlayTests.swift:26` is a screen coordinate. Decision 0002 and `echotype-v1.md` still
    describe `endpointing=2000`, now correct again.
  - 0017: status "accepted, 2026-09-25" matches the index row. The Context note on returning to
    2000 matches the code. The G1 paragraph matches E1: steps 1, 2 and 4 passed, and it says the
    inserted text was not captured and the one-minute spinner time was not measured. Its
    `keyterm` and `filler_words=false` conclusion is an inference from joined-up text with no
    "um", and the paragraph states it as that, with the reasoning.
  - Checks: `swift build` ("Build complete!"), `swift test` ("Test run with 47 tests in 1 suite
    passed").
- Required findings:
  1. The decision and drift log in `plan.md` still reads "None", though E1 says "record it in
     the decision and drift log" and this packet's External validation section says "The
     endpointing revert is in the plan's decision and drift log". Add the row (revert of
     `4b7578c`, reason, approved by Aidan in E1, workstream 2 touching `EchoTypeCore`) before
     accepting and removing E1. Record only; no code change.
- Optional observations:
  1. G1 ran on the candidate with `endpointing=5000`, so the restored 2000 has not been dictated
     against since the revert. It restores a value that shipped before `4b7578c`, and the batch
     pass does not depend on it, so this does not block.

## External validation

- Gate and placement: G1, after closure and before acceptance.
- Status: `Passed`
- Candidate: base `095449f` plus the uncommitted workstream 2 diff, launched with
  `./scripts/run.sh` after closure and put to Aidan through plan escalation E1.
- Results (Aidan, 2026-09-25): step 1 (toggle and caption in General) passed. Step 2 passed:
  a dictation with long pauses and an "um" came out as joined-up sentences with no "um", so
  batch accepted `keyterm` and `filler_words=false` rather than falling back. Step 4 passed:
  with the setting off, the fragmented streamed text was inserted immediately. Step 3, the
  spinner time after a one-minute dictation, was not run; Aidan accepted G1 without it. No
  inserted text or `curl` output was captured. Criterion 2's fallback is proved from the code
  by review.
- Post-G1 correction: Aidan approved, in E1, reverting live `endpointing` from 5000 to 2000,
  undoing commit `4b7578c` in `STTConnection.swift`, its test and `docs/specs/echotype-v1.md`.
  Applied as `git revert --no-commit 4b7578c`, which applied cleanly. Decision 0017 now records
  the revert, its G1 paragraph and an accepted status. `swift build` clean, `swift test` 47
  passed, and `./scripts/run.sh` rebuilt and relaunched `.build/EchoType.app` from this diff.
  The revert touches an `EchoTypeCore` file, so it had one focused review; see Closure review.
- Attempts and lasting decisions: one candidate, passed. The endpointing revert is in the plan's
  decision and drift log.
