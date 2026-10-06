# Workstream 4: Read aloud in the signed app

Status: accepted.

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

- Base commit: `cf2f094`
- Outcome: no source change was needed. The app already does everything the packet asks of it
  for local voices, and `build-app.sh` already stages every dependency bundle. Both release
  bundles are built, signed and verified. Criteria 1-3 are met as far as an agent can check; they
  and criterion 4 rest on the signed-app gate.
- Files changed: none outside this record. `git diff cf2f094 -- Sources Tests scripts` is empty.
  `LocalCandidates.swift` was set to `voice: "qwen3-tts"` only for the comparison build and then
  restored; `git diff` shows no change there.
- Decisions (why each scope item needed no change):
  - Fallback: `Settings.Reading.validated(for:)` maps a voice id the service does not offer to
    `voices[0]` and a speed outside `speedRange` to 1. `readingChoice(for:)`, which the Read Aloud
    tab, `ReadinessRequest(settings:provider:)` and `SpeechRequest` all use, applies it, so a
    stored `bf_emma` reads with Ryan in the comparison app and a stored `ryan` with Emma in the
    reference app, with no error. Both apps share one bundle id and so one `UserDefaults`; each
    save rewrites the stored Local choice to that app's validated one (`Settings.encode`), so
    Kokoro's stored speed resets to 1 after a save in the Qwen app. Already covered generically by
    `SettingsValidationTests` (retired voice, out-of-range speed); no new test.
  - Speed control: the Read Aloud tab's slider uses `provider.voice.speedRange` (Kokoro 0.5...2,
    step 0.1) and is hidden for an empty range (Qwen's `1...1`).
  - Progress: the Read Aloud tab follows `provider.readiness` and shows the voice's `ServiceNote`:
    "Downloading models, x of y GB", then "Loading the voice model", then nothing once ready. The
    Provider tab shows the same under "Read aloud". A reading started before ready fails with the
    same message in the pill (`Reader` checks `services.voice.requireReady()`).
  - MCP `speak`: the `--mcp` process only forwards text to the running app (`MCPProcess.deliver`),
    which reads it through `Reader` with the Local voice; it never loads a model, so MLX Audio
    Swift's stdout prints cannot corrupt the MCP stream.
  - Gate outcome (ET-R4-02, Aidan, 2026-10-06): no patch to MLX Audio Swift. Item 11's early
    ending is waived for the spike. MLX Audio Swift's per-utterance cap (6 codec steps per text
    token) and ET-R3-01's unawaitable cancellation are together fork work that blocks
    productionising Qwen. Workstream 5 marks or excludes Qwen readings that end at the cap.
  - Evaluation preset: Qwen voice `ryan` (Ryan, plain). Style verdict: the styled variant is no
    different, so the evaluation uses the plain voice. Ryan is already the first voice; the voice
    order and style prompt are unchanged.
- Verification: passed (2026-10-06, 05:53-05:57Z, one script, every step exit 0).
  - `swift build`; `swift test` (core 145, bench 23, app 76); `swift build -c release --product
    EchoTypeApp`.
  - `scripts/build-app.sh release .build/local-read-aloud/EchoType.app` (selection `kokoro`) and
    `scripts/build-app.sh release .build/voice-check/EchoType.app` (selection `qwen3-tts`, then
    restored). `codesign --verify --deep --strict` passes on both. Each `Contents/Resources` holds
    `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`,
    `swift-crypto_Crypto.bundle`, `swift-transformers_Hub.bundle`: every bundle the release build
    produces.
  - Executable SHA-256: reference
    `97c4cf1e030f0c4f62045dca7c9dee75fd1b6b6fa0fa41af0f19950480c02396`, comparison
    `ad03c428e03713c61f9276e33374b16715ff15e9119ae6be9c4431bfd3b93da4`.
- Known limitations or external checks:
  - `.build/release/EchoTypeApp` holds the reference build: the Resolution rebuilt the comparison
    app first and the reference app last. The executable hashes above are superseded by the
    Resolution's Final verification. Rebuild the comparison app after any source change, as the
    gate rules require.
  - Kokoro's download shows coarsely: `LocalModel.downloading` formats gigabytes to one decimal,
    so its 97 MB reads "0.0 of 0.1 GB" until about half done, then "0.1 of 0.1 GB". It is progress,
    but thin for item 2 of the checklist. `LocalModel.swift` is outside this packet's ownership; if
    the gate finds it inadequate, the fix is a finer format there (a gate correction).
  - Qwen's unawaitable cancellation (ET-R3-01) is unchanged: the app has no settle wait, so
    stop-then-read and stop-then-quit may overlap MLX work or crash at exit. The gate must exercise
    both and check the log and `~/Library/Logs/DiagnosticReports` (plan, conventions learned);
    checklist item 11 does not yet say so explicitly, so the lead should add it to the
    instructions it writes into External validation.
  - Everything else in criteria 1-2 and the whole of criterion 4 is the signed-app gate's.
- Specification drift: Qwen readings may end early at MLX Audio Swift's per-utterance cap,
  waived for the spike (ET-R4-02; plan's decision and drift log).

## Independent review

- Reviewer: fresh independent review agent (Claude Code), 2026-10-06.
- Verdict: changes required. One Required finding: Kokoro's download progress is not usable.
  "No source change" is right for the rest of the scope (fallback, speed range, bundles, MCP).
- Checks run (all exit 0): `swift build`; `swift test` (core 145, bench 23, app 76);
  `swift build -c release --product EchoTypeApp` (recompiled from the restored reference source,
  so `.build/release` now holds the reference build); `scripts/build-app.sh release
  .build/local-read-aloud/EchoType.app`; `codesign --verify --deep --strict` on both bundles. The
  comparison bundle was not rebuilt; its executable still hashes `ad03c428…`, as the handoff
  says. The rebuilt reference executable hashes
  `52597d5c35160f9b7a6b811150df793c5f2da611bdaac322571b176427397c73`. Both `Contents/Resources`
  hold the four bundles `.build/release` produces, and MLX Audio Swift ships resources for its
  tests only. `git diff cf2f094 -- Sources Tests scripts` is empty, and `build` is `kokoro`.
- Criteria:
  1. Partly met. The Read Aloud tab offers `provider.voice.voices` (Emma, Heart; nine Qwen presets,
     each plain and styled). The slider uses `speedRange`, 0.5...2 for Kokoro, and is hidden for
     Qwen's `1...1`. The tab follows `readiness.voice`. Kokoro's download progress fails it in
     substance (R1).
  2. Met. `Reading.validated(for:)` maps an unoffered id to `voices[0]` and an out-of-range speed
     to 1, and the picker, `ReadinessRequest` and `SpeechRequest` all go through
     `readingChoice(for:)`. `SettingsValidationTests` covers a retired voice. Side effect: saving
     in the Qwen app rewrites the stored Local speed to 1, so Kokoro's speed resets after a
     round trip. That is acceptable under the criterion, which asks only for no error.
  3. Met (above).
  4. The gate's, not yet open.
- Required findings:
  - **R1. Kokoro's download shows no usable progress.** `LocalModel.downloading`
    (`Sources/EchoTypeCore/Providers/Local/LocalModel.swift:83-88`) formats gigabytes to one
    decimal. Kokoro's manifest totals 97,489,362 bytes, so the tab reads "Downloading models, 0.0
    of 0.1 GB" until about 50 MB and then "0.1 of 0.1 GB". The store's roughly 1% updates all render as one
    of those two strings. The packet's scope names this item ("Read Aloud shows the voice's
    download and loading progress"). Checklist item 2 asks Aidan to confirm it, and the
    handoff already expects it may fail there. That costs a full gate round for a one-line
    fix. Fix: format sizes under 1 GB in MB, or with a byte-count formatter, keeping today's
    GB form above 1 GB. `LocalModelTests` (2.3 GB) and the bench's phase grouping
    (`Measurements.phases`, which splits on the first digit) are unaffected. `LocalModel.swift`
    is outside the packet's listed ownership. Fixing it now is the lead's call; otherwise it is a
    gate correction.
- Optional observations:
  - **O1. Gate wording: the download may finish before Aidan looks.** `DictationController`
    runs one readiness check at launch (`DictationController.swift:134-138`). That check starts
    every missing download, so Kokoro's 97 MB may be installed before item 2's Read Aloud tab is
    open. Also, nothing starts loading after a download ends until the next check (opening
    Settings or a reading), so a first reading may fail with "Loading the voice model". That is
    by design, as for transcription in slice 2. The lead should tell Aidan to open Settings,
    Read Aloud straight after `install.sh` launches the app. A download that has already finished
    should not count as a failure of item 2, and a first reading that fails with a loading
    message should count only if it persists.
  - **O2. The handoff is stale after this review's rebuild.** `.build/release` now holds the
    reference build, not the comparison one. The reference bundle's executable hash changed to
    the one above. Update the handoff's known limitation and use the current hashes in the
    gate candidate.
  - **O3. Qwen cancellation checks belong in the gate text.** The handoff is right: under the
    conventions learned (ET-R3-01), items 11 and 16 must ask for several stop-then-read cycles,
    then stop-then-quit at once. They must also ask for the app log and
    `~/Library/Logs/DiagnosticReports`. Add this to the External validation instructions.
- Questions: none.

## Resolution

- Finding dispositions:
  - R1, fixed. `LocalModel.downloading` (`Sources/EchoTypeCore/Providers/Local/LocalModel.swift`,
    ownership extended by the lead for this fix) now picks the unit from the total: under 1 GB both
    figures are whole MB ("Downloading models, 12 of 97 MB" for Kokoro, so each roughly 1% store
    update shows), otherwise today's one-decimal GB ("0.0 of 2.3 GB"). The message keeps its
    "Downloading models, <done> of <total> <unit>" shape. It was made internal (from private) so
    `LocalModelTests.downloadProgressAndFailure` can add one expectation for the MB form beside the
    existing GB one. Checked, not assumed: `Measurements.phases` names a phase by the text before
    the first digit, trimmed of punctuation and whitespace, so the MB form still groups as
    "Downloading models"; `MeasurementsTests` passes unchanged. This also retires the handoff's
    known limitation about Kokoro's coarse download progress.
  - O1-O3 were not accepted for this workstream's resolution; they are the lead's gate
    instructions (O2's stale limitation is corrected in the handoff above).
- Simplification/deletion pass: the formatter stays one function with one branch on the total;
  no formatter type, byte-count formatter or new test was added. Nothing else changed in
  `Sources`, `Tests` or `scripts`; `LocalCandidates.swift` ends restored to `voice: "kokoro"`.
- Final verification: passed (2026-10-06, 06:08-06:12Z, one script, every step exit 0).
  - `swift build`; `swift test` (core 145, bench 23, app 76); `swift build -c release --product
    EchoTypeApp`.
  - `scripts/build-app.sh release .build/voice-check/EchoType.app` with the selection's voice set
    to `qwen3-tts`, then `LocalCandidates.swift` restored (`git diff` shows no change there), then
    `scripts/build-app.sh release .build/local-read-aloud/EchoType.app` last, so `.build/release`
    holds the reference build.
  - `codesign --verify --deep --strict` passes on both. Each `Contents/Resources` holds
    `AppIcon.icns`, `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`,
    `swift-crypto_Crypto.bundle`, `swift-transformers_Hub.bundle`: every bundle in `.build/release`.
  - Executable SHA-256 (`Contents/MacOS/EchoTypeApp`): reference
    `b5e531fceac19f9357bb20fc552191fc53d8c2735426ef8e18c8915b3a02ad9f`, comparison
    `cd666a92befe4d5298816af4c796ce051e0cb7f59fa4feb2442dd4a179d1f506`.

## Closure review

- Reviewer: fresh closure agent (Claude Code), 2026-10-06.
- Verdict: closed. R1 is fixed and the fix introduces no release-blocking defect.
- Remaining required findings: none.
- R1: `LocalModel.downloading` now formats both figures in the total's unit, whole MB under 1 GB
  and one-decimal GB otherwise, so Kokoro's 97 MB download reads "Downloading models, 12 of 97 MB"
  and moves with each store update. Its only caller is `LocalModel.check()`. The GB form is
  unchanged for the larger models. MB values under 1 GB stay below 1,000, so no grouping
  separator appears. `Measurements.phases` still groups the MB text as "Downloading models".
  The only other change is one test expectation. Widening `private` to internal is test-only
  visibility inside the module.
- Verification: passed (2026-10-06, about 06:13-06:17Z, one script, every step exit 0).
  - `swift build`; `swift test` (exit 0; app suite 76 tests).
  - Comparison app first: `LocalCandidates.swift` set to `voice: "qwen3-tts"`, `swift build -c
    release --product EchoTypeApp`, `scripts/build-app.sh release .build/voice-check/EchoType.app`.
    The file was then restored, and `git diff --exit-code` on it is clean.
  - Reference app last: `swift build -c release --product EchoTypeApp`, `scripts/build-app.sh
    release .build/local-read-aloud/EchoType.app`, so `.build/release` holds the reference build.
  - `codesign --verify --deep --strict` passes on both. Each `Contents/Resources` holds
    `AppIcon.icns` and the four bundles `.build/release` produces (FluidAudio, mlx-swift Cmlx,
    swift-crypto Crypto, swift-transformers Hub).
  - Executable SHA-256 (`Contents/MacOS/EchoTypeApp`), superseding the Resolution's: reference
    `c1299914b465f0fb094e8ddc80a5c2db4951c72746b69a1e19422001adfbff21`, comparison
    `d4d92d61c640b1fe894c97e246ed736191c1f4160b66fa2388fc9f929ff607f9`.
  - `git diff -- Sources Tests scripts` shows only `LocalModel.swift` and `LocalModelTests.swift`.

## External validation

- Gate and placement: signed-app check and Qwen preset audition, after closure review and before
  acceptance.
- Status: `Passed with waiver` (item 11's early ending waived by Aidan, ET-R4-02; item 16
  settled by the lead from machine evidence, below).
- Candidate and instructions (attempt 1, 2026-10-06):
  - Candidate: base `cf2f094` plus the uncommitted change to `LocalModel.swift` and
    `LocalModelTests.swift` (R1). Fingerprint: `git diff cf2f094 -- Sources Tests scripts | shasum
    -a 256` is `1a0f90f6…1d84`. Bundles built by closure from that source, both passing
    `codesign --verify --deep --strict`: reference `.build/local-read-aloud/EchoType.app`
    (executable `c1299914…ff21`, what `scripts/install.sh` rebuilds and installs) and comparison
    `.build/voice-check/EchoType.app` (`qwen3-tts`, executable `d4d92d61…07f9`).
  - Preparation: the installed app (built 4 Oct) has no voice candidate (no `bf_emma`, `qwen3-tts`
    or "Loading the voice model" in its binary), so it never touches Kokoro. The Kokoro model
    directory was moved aside to
    `~/Library/Application Support/EchoType/SetAside-20261006/` so the app shows a real download.
    Transcription, cleanup and both Qwen3-TTS models stay installed. Item 15 is not offered (no
    sample files).
  - Instructions for Aidan: the packet's checklist, items 1-14 and 16, with these additions.
    - Item 2: open Settings, Read Aloud straight after `install.sh` launches the app; Kokoro is
      97 MB and the download starts at launch, so it shows "Downloading models, x of 97 MB" only
      briefly. A download already finished when you look is not a failure. A first reading that
      fails with "Loading the voice model" fails only if it persists.
    - Item 11, ET-R3-01: in the comparison app, stop a Qwen reading and immediately start another,
      several times. Then start one, stop it and quit at once (Cmd-Q). Reopen it and say whether
      anything misbehaved.
    - Item 16, before reopening the installed app: run
      `/usr/bin/log show --last 30m --predicate 'process == "EchoTypeApp"' > ~/Desktop/echotype-log.txt`
      and `ls -lt ~/Library/Logs/DiagnosticReports | head`, and say whether an `EchoTypeApp` crash
      report from today is listed. Do this whether or not anything failed.
- Required evidence: a pass, fail or waiver with a note for items 1-12 and 16. The chosen preset,
  the style verdict and, if offered, the utterance-length verdict for items 13-15. The log file
  for any failure.
- Attempts and lasting decisions:
  - Attempt 1 (Aidan, 2026-10-06, ET-R4-01): items 1-10 and 12 pass. Item 11 fails: Qwen
    readings end early, notably with slower voices (Sohee stopped about halfway); first audio is
    "well within my tolerance"; rapid stop-then-start "didn't seem to misbehave". Item 13: no
    preset named; every preset is "super impressive" but "very non-deterministic" (Uncle Fu's
    accent changes between readings), while Kokoro is the same every time. Item 14: no different;
    styled variants vary as much as the plain ones. Item 16 not reported. Feedback: wants a voice
    prompt field in Read Aloud settings, and ideally "a couple of nice predictable voices" plus an
    open custom-voice prompt.
  - Item 11 diagnosis (lead, 2026-10-06): MLX Audio Swift caps each generation at
    `min(maxTokens, max(75, textTokens * 6))` codec steps
    (`Qwen3TTS.swift:379-380` at the pinned `bf14ae0c`, unchanged on upstream `main`), that is
    0.48 s of speech per text token, and stops silently at the cap with no EOS. A voice slower than
    that loses the end of every utterance (250 characters each), which on a paragraph reads as
    stopping early. Evidence: fast run `20261006T132708Z-local` (Sohee) ends exactly at the cap on
    three single-utterance passages: `reading-demo-pronunciation` 37 tokens, 222 steps, 17.8 s
    (Ryan 12.9 s in `20261005T212611Z-local`); `reading-technical-terms` 44 tokens, 21.1 s;
    `reading-numbers-abbreviations` 57 tokens, 27.4 s. Ryan's `reading-past-tense-read` (14 tokens,
    84 steps, 6.7 s) also ends at the cap. The cap is internal to the runtime; no public parameter
    or adapter-side change avoids it without changing the spoken text, so the fix needs a patched
    MLX Audio Swift (escalation ET-R4-02).
  - Item 16, checked by the lead from the machine (read-only): no `EchoTypeApp` report in
    `~/Library/Logs/DiagnosticReports` (or `Retired`), and no Fault entries from `EchoTypeApp`
    in the last 10 hours of the unified log. The comparison app (pid 69077) was still running at
    14:27, so stop-then-quit and the reopen step are still Aidan's.
  - Feedback triage: the prompt field is the packet's non-goal ("a style prompt editor", "model
    or voice selection settings"), and predictable curated voices plus a custom prompt is a
    product design for productionising. Neither is built here; both are carried to the spike's
    recommendation. Qwen's variability is sampling at the model's recommended temperature 0.9; it
    is a finding for workstream 5 rather than a defect.
  - ET-R4-02 answer (Aidan, 2026-10-06): option C, no patch. Item 11's early ending is waived for
    the spike; the rest of item 11 (pause, resume, stop, rapid stop-then-start, first audio)
    passed. The truncation cap is recorded with ET-R3-01 as fork work that blocks productionising
    Qwen. Item 13 preset: Ryan (`ryan`). With item 14's "no different", the evaluation uses plain
    `ryan`. No gate correction, so no rebuild or re-review: the candidate is unchanged
    (`1a0f90f6…1d84`).
  - Item 16, settled by the resuming lead (2026-10-06, 14:53 BST), no further gate attempt. The
    comparison app (pid 69077, started 13:44) was still in use. Its unified log since 13:40 has no
    fault entries and no MLX entries; its errors are only CoreAudio, CMIO and AppKit window
    warnings. `~/Library/Logs/DiagnosticReports` (and `Retired`) holds no `EchoTypeApp` report.
    That covers the reading, dictation and rapid stop-then-start cycles of the whole gate.
    Stop-then-quit cannot be observed until Aidan quits the comparison app, and agents never quit
    EchoType. Its only possible failure is ET-R3-01's teardown crash, whose fix Aidan has already
    ruled fork work before productionising, so a further round trip could not change a decision.
    It is carried to the plan's whole-feature pending list, with deleting `.build/voice-check/`,
    which is still running.
  - Clean-up: the fresh Kokoro download matched the set-aside copy file for file (`diff -rq`,
    excluding its self-symlink), and the set-aside copy was removed.
  - Acceptance verification (lead, 2026-10-06, on the unchanged candidate): `swift build`, `swift
    test` (core 145, bench 23, app 76), `swift build -c release --product EchoTypeApp`,
    `scripts/build-app.sh release .build/local-read-aloud/EchoType.app` and `codesign --verify
    --deep --strict` on both bundles all pass; `LocalCandidates.swift` is unchanged. The running
    comparison bundle was not rebuilt.
