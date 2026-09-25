# Workstream 2: Insert the batch text on stop

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
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

## External validation

- Gate and placement: G1, after closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`. The lead records the base, confirms the app running from
  `./scripts/run.sh` was built from the current diff, and gives Aidan these steps:
  1. In Settings > General, confirm **Re-transcribe on stop** is on, with its caption. Set a few
     keyterms if none are set.
  2. Dictate a sentence or two with long thinking pauses and at least one "um", then stop. The
     inserted text should read as joined-up sentences with no "um".
  3. Dictate for about a minute and note how long the spinner stays after stopping.
  4. Turn the setting off and dictate with pauses. The text should match today's fragmented
     output, inserted immediately.
  Opening Settings in the development build moves the login item to it. The installed app takes
  it back the next time it launches.
- Required evidence: pass or fail for each step, the inserted text from steps 2 and 4, and the
  spinner time from step 3. The fallback is not tested by hand; review proves criterion 2 from
  the code.
- Troubleshooting: if step 2 still looks fragmented, batch is failing and the live text is being
  used. Give Aidan a `curl` command to run with their own key that reproduces the
  request against a short WAV, once with and once without `keyterm` and `filler_words`, to find a
  rejected parameter.
  Dropping a parameter changes approved behaviour and needs Aidan's answer.
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan's results are recorded in the plan escalation. A fresh lead audits the
  candidate, resolves any failure, and marks G1 `Passed` before accepting.
