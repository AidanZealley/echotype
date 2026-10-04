# Workstream 4: Local provider in the app

Status: not started.

## Task packet

### Outcome

Settings lists the experimental local provider after xAI and Apple. Selecting it downloads and
loads the build's transcription and cleanup models with progress shown, and the installed,
signed release app dictates and cleans up with them, including after an offline relaunch. Aidan
has confirmed this through the signed-app checklist below. xAI stays the default.

### Scope

- Add `.local` to `Providers.all` after `.xAI` and `.apple`, per the plan's decision log.
- Remove what being outside the list made necessary: the "not in `Providers.all`" comments in
  `LocalCandidates.swift` and `LocalProvider.swift`, and the bench's special case in
  `RunOptions.provider()` where the list now covers it. The bench keeps building the local
  provider from its selection for `--candidate`.
- Make whatever small change the app needs for a provider whose voice is `.unavailable` and
  whose voice list is a placeholder, so Settings and read aloud behave sensibly: a clear
  unavailable state, no crash, no request. Keep it inside existing patterns; a new Settings
  design is out of scope.
- Fix tests the new entry breaks, and add a test only where the change adds behaviour worth
  guarding.
- Run the agent-side checks below, then open the signed-app gate.

### Non-goals

- Model selection settings, a setup UI, or changing the default provider.
- Local read aloud. The app driver, scenarios or `bench session`.
- Changing an adapter, cleanup or the bench's measurements, except as a gate correction under
  the README's gate rules.

### Initial ownership

- `Sources/EchoTypeCore/Providers/Providers.swift`, `Sources/EchoTypeCore/Providers/Local/`
  (comments and provider description only), `Sources/EchoTypeBench/RunOptions.swift`.
- `Sources/EchoTypeApp/` and `Sources/EchoTypeCore/Settings.swift`, only for the unavailable
  voice handling above.
- Affected tests under `Tests/`.

### Required seams

- Consumes the build's selection, readiness and transcriber behaviour as workstreams 1 and 2
  built them. The app's own `DictationOperation` drives the services; nothing here depends on
  workstream 3.

### Acceptance criteria

1. Settings lists Local third; a fresh settings file still defaults to xAI, and no download
   starts unless Local is selected.
2. With Local selected and read aloud requested, the app reports read aloud as unavailable
   without crashing or sending a request.
3. `swift test` and the release build pass, and the release bundle from `build-app.sh` holds
   every dependency resource bundle and passes `codesign --verify`.
4. The signed-app gate has passed: every checklist item has Aidan's pass.

### Targeted verification

```bash
swift build
swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-app-check/EchoType.app
codesign --verify --deep --strict .build/local-app-check/EchoType.app
ls .build/local-app-check/EchoType.app/Contents/Resources
```

Do not run `scripts/install.sh` or launch the app yourself; Aidan does both in the gate.

### Signed-app gate

Open it after closure review. Before opening it:

1. Move the build's transcription model directory (`parakeet-unified`'s, the smallest download)
   aside under the README's download rule, so the app shows a real download. Leave the cleanup
   model installed.
2. Build the Whisper check app: set `LocalSelection.build`'s transcription to `whisper-turbo`,
   run `scripts/build-app.sh release .build/whisper-check/EchoType.app`, then restore the
   selection to `parakeet-unified` and confirm `git diff` no longer shows that change.
3. Write the candidate (base commit plus uncommitted workstream changes) and the checklist into
   the External validation section, then block as the README describes.

The checklist, written for Aidan. Ask for a pass or fail and a short note on each.

1. Run `scripts/install.sh` from the repository. It replaces `/Applications/EchoType.app` with
   this build and launches it, and may ask for your password. Afterwards, switch back to xAI in
   Settings whenever you like.
2. In Settings, choose Local. Does the provider list and the Local entry read well? Note anything
   about the wording or layout you would change.
3. Settings shows transcription downloading with progress, then loading, then ready, and cleanup
   loading then ready. Read aloud shows as unavailable with a clear message.
4. While transcription is still downloading, switch to Apple and back to Local. The download
   carries on and finishes.
5. Dictate a short sentence into TextEdit. The text is right and is inserted.
6. Dictate "Let's meet on Tuesday, no, Wednesday at ten." Cleanup removes the correction.
7. Dictate continuously for about a minute. Text keeps up while you talk, and the insert after you
   stop takes no more than a few seconds.
8. Start dictation and stop it at once. The pill closes and nothing hangs.
9. Stop mid-sentence. The last words you said are inserted.
10. Ask EchoType to read some selected text aloud. It says read aloud is unavailable and nothing
    hangs.
11. Quit EchoType, turn Wi-Fi off, relaunch it and dictate a sentence. It works offline. Turn
    Wi-Fi back on.
12. Quit EchoType and open `.build/whisper-check/EchoType.app` from the repository. Allow any
    permission it asks for, choose Local if needed, wait for transcription to be ready, and
    dictate a sentence. It works. Quit it and reopen `/Applications/EchoType.app`.

If anything fails, also send the output of
`log show --last 15m --predicate 'process == "EchoTypeApp"' > ~/Desktop/echotype-log.txt` (it
writes the app's recent log to your Desktop; say where it is rather than pasting it).

After the gate passes, remove the set-aside model copy once the app's fresh download has
verified, and delete `.build/whisper-check/`.

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

- Gate and placement: signed-app check, after closure review and before acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: a pass or fail with a note for each of the 12 checklist items, and the log
  file for any failure.
- Attempts and lasting decisions: `TBD`
- Resume condition: every checklist item has passed, the last attempt listing only items that
  needed repeating.
