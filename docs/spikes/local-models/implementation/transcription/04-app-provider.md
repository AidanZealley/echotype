# Workstream 4: Local provider in the app

Status: accepted.

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

- Base commit: `e73a6768fed13ed49dba31fa38f9519f145ed673` on `spike/local-models`.
- Outcome: Local is third in Settings and stored Local selections survive relaunch. Fresh
  settings still select xAI. Read Aloud shows the unavailable message and hides voice and
  speed controls once readiness answers. A fixed speed never constructs a Slider, including
  before the first readiness answer. Agent-side checks and the signed-app gate passed.
- Files changed:
  - `Sources/EchoTypeCore/Providers/Providers.swift`: registers `.local` after xAI and Apple.
  - `Providers/Local/LocalCandidates.swift`: removes the outdated registry comment.
  - `Providers/Local/LocalProvider.swift`: makes the voice message explicit,
    "Local read aloud is not available yet."
  - `Sources/EchoTypeBench/RunOptions.swift`: validates every provider through the registry;
    Local still assembles only the measured services with the bench's selected candidates.
  - `Sources/EchoTypeApp/Views/SettingsView.swift`: hides unavailable voice controls and omits
    the speed Slider for a fixed rate.
  - `Tests/EchoTypeCoreTests/SettingsTests.swift`: updates the registry-order test and checks
    fresh xAI defaults and stored Apple and Local selections.
  - This handoff. The plan and packet status edits belong to the lead.
- Decisions:
  - Aidan's 2026-10-05 answer waives checklist item 4 for acceptance. Retain passes for
    items 2, 3, 5, 7, 8, 9 and 10. His retry answer also passes items 1, 6, 11 and 12.
    Earlier tests used the app installed with `scripts/install.sh`; exact correction cleanup,
    offline dictation and Whisper dictation worked. Escape error dismissal remains outside scope.
  - Whisper eventually became ready and dictated successfully without a code correction.
    Preparation can take several minutes; this gate does not measure the load duration.
  - No provider capability flag or new settings state. The existing voice readiness drives
    the unavailable UI; the service's speed range decides whether there is a speed choice.
  - No Reader change or additional request test. `Reader.read` checks voice readiness before
    `voice.speak`; the existing `ReadingOperationTests.notReadyPill` covers waiting and
    unavailable states, the displayed error and zero speech requests.
  - Constructing the registered Local provider only creates service values and `LocalModel`
    state. Downloads begin in `LocalModel.check`, reached by readiness for the selected provider.
    No unused candidate is loaded or warmed.
  - Deletion and simplification pass removed the duplicate Local entry in the bench's known
    provider list and the obsolete registry comment. No extra abstractions, flags or tests
    mirroring the view were added. Build selection remains Unified plus Qwen3-2507.
- Verification: all packet commands passed on 2026-10-04.
  - `swift build`.
  - `swift test`: 140 core, 19 bench and 76 app tests passed.
  - `swift build -c release --product EchoTypeApp`.
  - `scripts/build-app.sh release .build/local-app-check/EchoType.app`.
  - `codesign --verify --deep --strict .build/local-app-check/EchoType.app`.
  - `ls .build/local-app-check/EchoType.app/Contents/Resources`: `AppIcon.icns`,
    `FluidAudio_FluidAudio.bundle`, `mlx-swift_Cmlx.bundle`, `swift-crypto_Crypto.bundle`
    and `swift-transformers_Hub.bundle`. The staged bundle names match every `*.bundle` in
    the release bin path reported by SwiftPM. The build script needed no change.
  - `git diff --check` passed. Full command logs are in `.build/local-app-check-logs/1.log`
    through `6.log`, outside git.
- Known limitations or external checks: Aidan passed the signed-app gate on 2026-10-05,
  with checklist item 4 explicitly waived. First load after reboot, energy and Developer ID
  notarisation remain the plan's external checks. The default Unified candidate never writes FluidAudio's CTC tokenizer link;
  only the keyterms candidate does, as workstream 1 records.
- Specification drift: none. Registry ordering follows the approved plan decision. Local
  read aloud remains a later slice.

## Independent review

- Reviewer: fresh Codex independent reviewer, 2026-10-04. Applied the `unslop` skill to this record.
- Verdict: agent-side review passed. No Required findings. The signed-app gate remains pending.
- Acceptance criteria:
  1. Passed by code inspection and tests. `Providers.all` lists xAI, Apple, Local. The
     `registeredProviders` test checks the order, fresh xAI defaults and stored selections.
     Constructing `Provider.local` creates service values and model state only. Download and
     load begin in `LocalModel.check`, reached through the selected provider's readiness.
     Settings follows that provider; registration does not check every provider.
  2. Passed by code inspection and existing operation tests. Local returns the explicit read-aloud
     unavailable message. Settings hides its voice and speed controls after readiness answers,
     and the strict speed-bound check prevents a `1...1` Slider before that answer. `Reader.read`
     calls `services.voice.requireReady()` before constructing a speech request. The existing
     `notReadyPill` test checks unavailable and waiting pills, error messages and zero requests.
  3. Passed independently. All six targeted commands exited zero: `swift build`, `swift test`,
     `swift build -c release --product EchoTypeApp`, `scripts/build-app.sh release
     .build/local-app-check/EchoType.app`, `codesign --verify --deep --strict
     .build/local-app-check/EchoType.app`, and the resource listing. Tests passed with 140 core,
     19 bench and 76 app tests. The four staged dependency bundles exactly match the release
     bin directory: FluidAudio, MLX Cmlx, swift-crypto Crypto and swift-transformers Hub.
     `AppIcon.icns` is present too. Logs are `.build/local-app-review-logs/1.log` through `6.log`.
  4. Pending as required by the workflow. Aidan must validate the signed app after closure.
     This review made no app launch, install, model move or Whisper comparison build.
- Boundaries, lifecycle and simplicity: the complete diff and status contain only the owned
  source and tests, this packet and the lead's plan status. No untracked files were present.
  The bench validates providers through the registry and still builds Local from the measured
  service's selection. No model selection or adapter behaviour changed. Existing readiness
  followers ignore answers after cancellation; store downloads and model loading remain owned
  independently of Settings, so switching providers does not cancel preparation. The change
  removes the duplicate bench registry entry and obsolete comment without adding flags,
  wrappers or duplicated state. `git diff --check` passed.
- Required findings: none.
- Optional observations: none.
- Questions: none.

## Resolution

- Finding dispositions: independent review found no Required findings, Optional observations or Questions. No remediation needed.
- Simplification/deletion pass: accepted the implementation pass. Registry membership replaces the duplicate bench entry; unavailable voice handling uses existing readiness and speed range.
- Final verification: all six packet commands passed in implementation and independent review. Focused closure reran all six successfully; both gate bundles also pass signature and resource checks.

## Closure review

- Reviewer: fresh Codex closure reviewer, 2026-10-04. Applied the `unslop` skill to this record.
- Verdict: agent-side closure passed. No release-blocking defect found in the finished candidate.
- Remaining required findings: none. Independent review accepted no findings, so no remediation
  needed verification. Focused inspection confirms registry order and xAI defaults, selected-only
  model preparation, unavailable voice handling and the existing readiness guard before speech.
- Verification: reran all six packet commands. `swift build`, `swift test`,
  `swift build -c release --product EchoTypeApp`, `scripts/build-app.sh release
  .build/local-app-check/EchoType.app`, `codesign --verify --deep --strict
  .build/local-app-check/EchoType.app`, and the resource listing all exited zero.
  The release app contains `AppIcon.icns` and all four dependency resource bundles, matching
  every `*.bundle` in SwiftPM's release bin directory. `git diff --check` passed.
  Command logs are `.build/local-app-closure-logs/1.log` through `6.log`, outside git.
- Signed-app validation remains pending. The lead owns preparing and opening that gate.
  This review did not install or launch the app, move models or build the Whisper check app.

## External validation

- Gate and placement: signed-app check, after closure review and before acceptance.
- Status: passed on 2026-10-05. Aidan passed all required items across the two attempts;
  item 4 remains explicitly deferred and waived for acceptance.
- Candidate: base `e73a6768fed13ed49dba31fa38f9519f145ed673` plus the uncommitted workstream 4 source and test changes. Source/test diff SHA-256 is `842b618db275be97ab9918c04d16a5126a04a4ae4e6c766ceaf7cd36e8b35b4d`.
- Gate builds, before acceptance cleanup: `.build/local-app-check/EchoType.app` uses `parakeet-unified` and `qwen3-4b-2507`, built in focused closure. `.build/whisper-check/EchoType.app` uses `whisper-turbo` and the same cleanup candidate. Both release bundles pass `codesign --verify --deep --strict` and contain all four dependency resource bundles.
- Download preparation: moved only the Unified transcription model to `/Users/aidanzealley/Library/Application Support/EchoType/SignedAppCheck-20261004/parakeet-unified-en-0.6b-640ms-int8-d32e972dd4315f1dc3f6be28fb2aab0ab3e80358`. Cleanup and Silero remain installed. No installed model was deleted. The default Unified build does not write FluidAudio's CTC tokenizer link.
- Comparison preparation: temporarily changed `LocalSelection.build` to Whisper, built the check app, then restored Unified. The selection has no git diff. Build log is `.build/local-app-check-logs/whisper-gate-build.log`.
- Required evidence: a pass or fail with a short note for each checklist item, plus the log file for any failure.
- Attempts and lasting decisions: attempt 1 opened after independent review and closure passed with no findings. No app was installed or launched by agents. Aidan's final answer passed the remaining checks on the unchanged candidate.
- Resume condition: satisfied. Earlier passes and Aidan's item 4 waiver remain valid.

### Diagnostic retry 2, 2026-10-05

- Recovery: HEAD is the recorded base, and all eight dirty files belong to workstream 4.
  The source/test diff fingerprint still matches attempt 1. Independent review and closure
  remain valid. Both existing gate bundles pass strict signature verification and contain
  the same four dependency resource bundles; `git diff --check` passed. No source, test,
  build selection, installed app or model was changed in this retry.
- Preserved evidence: Aidan passed items 2, 3, 5, 7, 8, 9 and 10. Item 4 is explicitly
  deferred and no longer required for acceptance. Items 6 and 11 were unanswered.
  Installation was implicit in using the app; the retry asks only for confirmation.
  Escape dismissing errors is outside this workstream and remains unchanged.
- Runtime evidence: the existing Whisper comparison process, PID 97625, launched at
  06:49:26 BST. Its log contains ANE activity at 06:49:28 and 06:52:57, then Metal shader
  compilation at 06:52:58. A five-second sample at 06:54:28 found no active model-load
  stack. Read-only inspection of that running app's Settings showed ready checkmarks for
  Live transcription and Cleanup. The Loading state resolved during this attempt.
  This establishes eventual readiness, not a measured load duration or a passed dictation.
- Diagnosis: a persistent hang is not reproduced. Runtime preparation is consistent with
  the delay; workstream 2 also observed runtime specialization and a 129-second fresh
  load/warm. The log does not isolate the slow stage. ANE kernel-shape errors appear
  before Metal compilation, but preparation still reached ready, so those messages alone
  do not justify changing compute units or the adapter. No speculative correction was made.
- Diagnostic files, outside git: `.build/local-app-retry-logs/runtime.log` and
  `.build/local-app-retry-logs/whisper-app.sample.txt`. Sampling the ANE service itself
  was denied by macOS privileges; no elevated access was requested.
- Failure-log correction: in this Mac's zsh, `log` is a shell builtin before `/usr/bin/log`.
  Use `/usr/bin/log` to obtain the system log. This explains why the original
  command could produce no app logs; the absolute command captured this process's records.
- Candidate: unchanged from attempt 1. No rebuild or fresh review is needed because no code
  changed. Keep both finished bundles and the set-aside Unified model until acceptance.

### Acceptance, 2026-10-05

- Recovery: HEAD remains the recorded base. The complete diff contains only the eight owned
  files, with no untracked files. The source/test SHA-256 still matches the reviewed candidate.
  Both gate bundles pass strict signature verification; `git diff --check` passes. The prior
  independent and closure reviews remain valid. No code correction, rebuild or new review was needed.
- Aidan's final results:
  - Item 1: pass. Previous checks used EchoType installed with `scripts/install.sh`.
  - Items 2 and 3: pass. Settings reads well, download progress appeared, transcription and
    cleanup reached ready, and read aloud remained unavailable.
  - Item 4: explicitly deferred and waived for acceptance. Switching away during download
    remains untested in the signed app; Aidan accepts addressing it later if it becomes an issue.
  - Item 5: pass. Simple dictation worked and inserted text.
  - Item 6: pass. The exact correction sentence worked; cleanup kept the corrected content
    and removed the unwanted text.
  - Item 7: pass. Long dictation kept up and worked fine.
  - Item 8: pass. Immediate start and stop closed the pill.
  - Item 9: pass. Stopping mid-sentence inserted the final words.
  - Item 10: pass. Read aloud reported unavailable. Escape dismissal remains outside scope.
  - Item 11: pass. Aidan's confirming dictation ran with Wi-Fi off.
  - Item 12: pass. Whisper dictated successfully after preparation finished. Aidan believes
    the earlier Loading report came from not waiting long enough.
- Fresh download verification: independently checked all 13 Unified manifest file sizes and
  SHA-256 digests in the fresh installed model. Every file matches the pinned manifest.
- Acceptance cleanup: removed only the set-aside Unified model copy and the temporary
  `.build/whisper-check/` comparison bundle after the gate and fresh-model verification passed.
  No other installed model or run directory was deleted. No agent installed or launched an app.
- Decision: accepted. User authorization waives item 4's original pass requirement. No
  specification drift or unresolved escalation remains.
