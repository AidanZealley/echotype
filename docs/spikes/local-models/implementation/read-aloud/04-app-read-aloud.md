# Workstream 4: Read aloud in the signed app

Status: not started.

## Task packet

### Outcome

The installed, signed reference app (Unified, Qwen3, Kokoro) reads aloud with Local selected. It
downloads and loads the voice with progress shown, pauses, resumes, stops and changes speed, and
works offline and through EchoType's MCP `speak`. Dictation still works with all three models
loaded. A voice comparison app with Qwen3-TTS does the same. Aidan has confirmed both through
the checklist below and has chosen the Qwen preset and style verdict the evaluation uses.

### Scope

- Build and verify the release bundles:
  - the reference app from `LocalSelection.build`;
  - the voice comparison app, with the selection's voice temporarily set to `qwen3-tts`, then
    restored, confirming `git diff` no longer shows the change.

  Both must hold every dependency resource bundle and pass `codesign --verify --deep --strict`.
  Fix `build-app.sh` only if staging misses something.
- Make whatever small app change local voices need, inside existing patterns:
  - a stored voice the build does not offer falls back to the first voice (check that
    `Settings.readingChoice` already does this when switching between the two apps);
  - the speed control follows the service's range;
  - Read Aloud shows the voice's download and loading progress.

  A new Settings design is out of scope.
- Fix tests the change breaks, and add a test only where the change adds behaviour worth
  guarding.
- Run the agent-side checks below, then open the gate.

### Non-goals

- Changing a voice adapter, cleanup, transcription or the bench, except as a gate correction
  under the README's gate rules.
- Model or voice selection settings, a style prompt editor, or changing the default provider.
- The app driver, scenarios or `bench session`.

### Initial ownership

- `Sources/EchoTypeApp/`, `Sources/EchoTypeCore/Settings.swift`, `scripts/build-app.sh`.
- `Sources/EchoTypeCore/Providers/Local/LocalCandidates.swift`, for the temporary selection
  change only (it must end restored), and, after the gate, the Qwen voice order or style prompt
  if Aidan asks for a change.
- Affected tests under `Tests/`.

### Required seams

- Consumes the voice candidates, voice ids and readiness as workstreams 2 and 3 built them
  ([02-kokoro.md](02-kokoro.md), [03-qwen3-tts.md](03-qwen3-tts.md) handoffs). The app's own
  `Reader` and `SpeechPlayer` drive the services; nothing here depends on the bench.
- Produces Aidan's chosen Qwen voice id and style verdict for workstream 5. At acceptance, record
  them in the plan's decision and drift log.

### Acceptance criteria

1. With Local selected, the Read Aloud tab offers Emma and Heart in the reference app and the
   Qwen voices in the comparison app, with a working speed control, and shows voice progress.
2. Switching between the two apps with a stored voice the other does not offer reads with that
   app's first voice, without an error.
3. `swift test` and the release build pass. Both bundles from `build-app.sh` hold every
   dependency resource bundle and pass `codesign --verify`.
4. The signed-app gate has passed: every checklist item has Aidan's pass or waiver, and Aidan has
   named the Qwen voice for the evaluation.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-read-aloud/EchoType.app
codesign --verify --deep --strict .build/local-read-aloud/EchoType.app
ls .build/local-read-aloud/EchoType.app/Contents/Resources
```

Build the comparison app the same way into `.build/voice-check/EchoType.app` and verify it too.
Do not run `scripts/install.sh` or launch either app yourself; Aidan does both in the gate.

### Signed-app gate

Open it after closure review. Before opening it:

1. Move the Kokoro model directories aside under the README's download rule, so the app shows a
   real download. Leave transcription, cleanup and Qwen3-TTS installed. The app Aidan is running
   has no voice candidate, so it never touches Kokoro's files; confirm that from its selection
   before moving them, and escalate instead if it does.
2. Build both apps as above.
3. Write the candidate (base commit plus uncommitted workstream changes, with a fingerprint of the
   source diff) and the checklist into the External validation section, then block as the README
   describes.

The checklist, written for Aidan. Ask for a pass or fail and a short note on each. Items 13-15
ask for choices, not passes.

1. Run `scripts/install.sh` from the repository. It replaces `/Applications/EchoType.app` with the
   reference build (Unified, Qwen3, Kokoro) and launches it, and may ask for your password.
2. In Settings, keep Local selected and open Read Aloud. Read aloud shows downloading with
   progress, then loading, then ready. Emma and Heart are offered and the speed control works.
3. Select a paragraph anywhere and read it aloud with Emma, then with Heart. Speech starts
   quickly, sounds right, and plays without gaps. Note how quickly it starts compared with xAI.
4. Read a long selection. Pause it partway, wait ten seconds, resume. It carries on from where it
   paused, with no skipped or repeated words.
5. Stop a reading partway. It stops at once and the pill closes.
6. Change the speed to each end and read a sentence. It is clearly slower, then faster, and
   still clear.
7. In a new agent session, ask the agent to reply using EchoType. The reply is read aloud with
   your Local voice. (Existing sessions keep their old MCP connection until restarted.)
8. Straight after a reading, dictate a sentence into TextEdit. The text is right, is cleaned up
   and is inserted. All three models are loaded at this point.
9. Quit EchoType, turn Wi-Fi off, relaunch it, and read a sentence aloud. It works offline. Turn
   Wi-Fi back on.
10. Quit EchoType and open `.build/voice-check/EchoType.app` from the repository. Allow any
    permission it asks for, choose Local if needed, and wait for read aloud to be ready. This
    can take minutes the first time.
11. In the comparison app, read a paragraph and a long selection with the first Qwen voice.
    Pause and resume, then stop. All behave as in items 3-5. Note how quickly speech starts.
12. Dictate a sentence in the comparison app. It still works with Qwen3-TTS loaded.
13. **Choose a preset.** Read this passage with each Qwen voice you want to try:
    "Try the same paragraph in each, including a few technical terms you commonly read. These
    demos help judge voice quality; their response times won't represent performance inside
    EchoType on your Mac." Name the preset you prefer. Note whether it says "read" as "reed" and
    "demos" as "deh-mohs".
14. **Style prompt.** Read the same passage with your preset's styled variant. Say whether the
    style prompt is better, worse or no different, and suggest different wording if you want
    one tried.
15. **Utterance length,** if the lead lists two sample files: play both and say whether the
    shorter one loses anything in pronunciation or intonation.
16. Quit the comparison app and reopen `/Applications/EchoType.app`.

If anything fails, also send the output of
`/usr/bin/log show --last 15m --predicate 'process == "EchoTypeApp"' > ~/Desktop/echotype-log.txt`
(it writes the app's recent log to your Desktop; say where it is rather than pasting it).

If Aidan suggests different style prompt wording, change the prompt as a gate correction and ask
them to repeat item 14 with a new comparison build. After the gate passes, remove the set-aside
Kokoro copy once the app's fresh download has verified, and delete `.build/voice-check/`.

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

- Gate and placement: signed-app check and Qwen preset audition, after closure review and before
  acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: a pass, fail or waiver with a note for items 1-12 and 16. The chosen preset,
  the style verdict and, if offered, the utterance-length verdict for items 13-15. The log file
  for any failure.
- Attempts and lasting decisions: `TBD`
- Resume condition: every pass/fail item has passed or been waived, and Aidan has named the
  preset. The last attempt lists only items that needed repeating.
