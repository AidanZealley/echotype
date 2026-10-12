# Local models follow-up

A brief for one agent working on Aidan's Mac, on branch `feat/local-models-productionization`.
It applies a review of the Local provider and Settings work. The review was read-only, so treat
each finding as a claim to confirm in the code before changing it.

## How to work

- Read `README.md` (Development) and [0025](decisions/0025-provider-adapters.md) first. Read
  [0026](decisions/0026-local-model-stack.md) and [local-models.md](local-models.md) before
  workstreams 2 and 4.
- Do the workstreams in order. Commit once per workstream, following the repository's commit
  style (plain sentence subjects).
- After each workstream, run the `code-review` skill as a single subagent scoped to that
  workstream's diff. Fix Required findings. Then stop and summarise for Aidan before starting
  the next workstream.
- Workstream 5 is interactive: show Aidan screenshots after each Settings page.
- Leave `docs/productionization/` and `docs/specs/`. Aidan is deleting them. Nothing
  below needs them.
- Prefer deleting code to adding it. The current Local code is overbuilt; do not add
  generation tracking, retry machinery or interleaving tests to cover hypothetical races.

Verification for every workstream:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
swift build -c release --product EchoTypeApp
```

Use `./scripts/run.sh` when a step needs the signed app.

## 1. Remove spike and validation scaffolding

The settings-inspection and isolated-validation hooks from the agent workflow still ship. No
script builds those bundles.

- `Sources/EchoTypeApp/App.swift`: `inspectingSettings`, its launch branch, the
  `settings-inspection` `Window` scene and `MenuBarExtra(isInserted:)`. Restore unconditional
  `claimLoginItem()`.
- `Sources/EchoTypeApp/SettingsStore.swift`: `validationPreferencePath`,
  `isolatedPreferences`, `saveValidationPreferences`, the `validationPreferences` branches and
  `import Darwin`. Settings and `hotkeysActive` go straight to `UserDefaults` again.
- `Sources/EchoTypeApp/Keychain.swift`: `isIsolatedValidation` and the service override.
- `Sources/EchoTypeApp/HotkeyMonitor.swift:46`: always prompt.
- `Sources/EchoTypeApp/MCPProcess.swift`: revert the bundle identifier change if it only served
  validation bundles.
- `Tests/EchoTypeAppTests/IsolatedValidationTests.swift`: delete.
- `ModelStore.inventory` (`ModelStore.swift` around 300-366): drop the historical experiment
  names (whisper, smollm, qwen3-tts, the espeak trial, obsolete G2P files) and the
  `~/.cache/fluidaudio/Models/kokoro` link. Owned files are the supported manifests' directories;
  the only external link left is the CTC tokenizer cache. Drop matching fixtures in
  `LocalLifecycleTests.inventory`.
- `Sources/EchoTypeTestSupport`: move `AudioConverter` and `WAVRecording` back into
  `Tests/EchoTypeCoreTests/Integration/`, drop `public`, and delete the target from
  `Package.swift`.
- Comments that point at deleted material: `KokoroSpeech.swift:13` ("workstream 2 handoff"),
  `Package.swift` (Qwen speech experiment, research notes), `ModelStore.swift` ("experimental
  runtimes"). Check the `espeak-ng_data.bundle` comment in `scripts/build-app.sh` is still true.
- Delete the unused `StatusMark` view in `SettingsView.swift`.

Done when `grep -rn 'isIsolatedValidation\|inspection\|EchoTypeTestSupport\|workstream' Sources Tests Package.swift`
finds nothing and both verification commands pass.

## 2. Startup responsiveness and loading bugs

Measured on Aidan's M1 Pro (0026): Parakeet loads in 0.3 s unboosted or 0.8 s boosted on a
normal relaunch, Kokoro in 2.5 to 6 s, Qwen cleanup in about 8.6 s. Today a dictation waits for
Parakeet and then Qwen before the microphone opens, about 12 s.

1. **Open the microphone without waiting for cleanup.** `LocalLifecycle.prepare(.dictation)`
   (`LocalSetup.swift`) awaits transcription, then cleanup. Await transcription only, and start
   the cleanup load without awaiting it. A dictation whose cleanup is not ready at start keeps
   the existing "No cleanup" behaviour.
2. **Escape cancels during loading.** `LocalModel.waitForPreparation` waits on a detached task
   and ignores cancellation, and `DictationOperation.cancel()` / `Reader.stop()` do not cancel
   the startup wait. Make the wait return on cancellation (the load may keep running) and have
   cancel/stop end it. The controller must return to idle at once.
3. **Cancelling a load clears it.** `LocalModel.cancel()` leaves `state.task` set, so the next
   preparation joins the cancelled task and fails with the loading message. Clear the task in
   `cancel()`; the detached task only clears state for its own generation.
4. **Remember a failed load** until setup is retried from Settings, instead of reloading (and
   re-hashing) on every dictation.
5. **Stop hashing on every load.** `LocalModel.swift` calls `verifyInstalled` (SHA-256 over
   about 3 GB) before each load. Installation already verifies. Check sizes at load time.
6. **Load selected, installed features at launch.** `select` only releases. Have it begin
   preparation for selected features whose files are installed. This loads; it never
   downloads.
7. **Unload Qwen under memory pressure.** Keep Parakeet and Kokoro resident while selected.
   Release the cleanup model on `DispatchSource.makeMemoryPressureSource(eventMask: .warning)`;
   the next dictation reloads it in the background (item 1). No timer or setting.
8. **Readiness churn.** `DictationController.followAvailability()` restarts both readiness
   watchers and sets them to nil on every settings change, including each keyterm keystroke.
   Restart only when either provider id, the language or the read-aloud voice changes.
9. **Download cancellation race.** `ModelDownloadSource.swift:31-38` can create a task on an
   invalidated session if cancellation lands between `checkCancellation()` and
   `downloadTask(with:)`. Make creation and cancellation exclusive.

Done when, in the signed app with Local selected for both features: dictation after relaunch
starts capturing within about a second; Escape during a cold load returns to idle at once and
the next hotkey works; read aloud after launch starts without visible preparation. Report the
timings you observe to Aidan.

## 3. One install at a time, as a queue

Aidan chose serial installs. The current per-feature concurrency (`setupGenerations`,
`releaseAfterSetup`, shared-download retention in `cancel`, `removing`/`removingFeatures`)
exists only so Dictation and Read Aloud setup can overlap. Replace it with a queue:

- Pressing Install while another feature installs enqueues it. Its row shows "Waiting for
  Dictation setup" (or Read Aloud). The button is never disabled because another install is
  running.
- One worker installs queued features in order. Cancel removes a queued feature, or cancels
  the running one.
- Removal is synchronous file work; do it under the lock and drop the removal flags.
- `LocalModel.release()` is an alias for `cancel()`; delete it.
- `recoverInstalled` salvages intact files from a corrupt install. Replace it with "delete the
  install and download again".

Prune tests in the same commit:

- Delete tests of removed concurrency: `concurrentIndependentSetup`,
  `cancelledSharedWriterAdmission`, interleaving variants of `selectionDuringSetup`, and the
  three `ModelStoreTests` recovery tests (keep one "corrupt install re-downloads").
- Replace `Task.yield()` spin loops (`LocalInstallationTests`, `LocalLifecycleTests`) with
  awaiting returned tasks or existing gates. Give `KokoroSpeechTests`' read-ahead test a gate on
  the second synthesis instead of 1000 yields.
- `FeatureProviderTests`: merge the overlapping "each feature uses its own provider" tests and
  stop writing real `UserDefaults` and calling the real `Provider.local`.
- Keep: install, checksum mismatch, interruption, reporting without side effects, download
  and setup cancellation, a lease protecting its feature's files from removal, feature
  isolation, Kokoro close and cancel, transcript and text tests, settings captured at
  operation start.

Simplify symlink handling while here: only the CTC tokenizer cache can collide with another
FluidAudio install. "If something not ours is there, throw; otherwise create the link" replaces
`linkFolder`'s revision parsing and Kokoro's conflict guards. Keep one "foreign CTC cache is
preserved" test and delete the other permutations in `LocalModelLinkTests` and
`KokoroEnglishFrontendTests.conflictingRepository`.

Done when the queue behaves as described in the app and `LocalLifecycle` has no per-feature
generations.

## 4. Keyterm boosting

Boosting is always on because `TranscriptionRequest.init(settings:provider:credential:)`
(`Provider.swift`) prepends a built-in "EchoType" keyterm for every provider. Boosting costs
about 5x Parakeet's stop-to-final time and causes false substitutions. The keyterm exists for
the reply trigger, which already accepts "echo type" as two words
(`ReplyRequest.swift`).

1. Remove the built-in keyterm and its doc comment. Boosting is then on only when the user
   has saved keyterms.
2. Load and warm the CTC boosting model only when keyterms are present; drop the hardcoded
   "EchoType" warm-up vocabulary in `ParakeetModel.swift`.
3. Ask Aidan to dictate "reply with EchoType" about five times each on Local and xAI in the
   signed app. If a provider consistently hears another spelling (for example "eco type"), add
   it to `ReplyRequest`'s name match with a test. Keep the name in the trigger; a generic phrase
   would send messages by accident.

Done when the reply trigger works on both providers without the keyterm and Settings copy
no longer implies a built-in term.

## 5. Settings rebuild and the provider boundary

Do this interactively. The goal is stock SwiftUI with no custom chrome. Aidan chose a sidebar
layout.

### Boundary

Settings names Local directly, which [0025](decisions/0025-provider-adapters.md) forbids.

- Move `ProviderFeature` and `RuntimeLease` from `Providers/Local/LocalSetup.swift` into
  `Provider.swift`.
- Rename `Provider.localSetup: LocalSetup?` to `Provider.setup: ProviderSetup?`, with
  `SetupRequirement` and `InstalledFile` for its value types.
- `SettingsStore.swift`: replace the `== "local"` checks with a loop over `Providers.all`
  calling `setup?.select`. Build the readiness request from settings instead of the
  hardcoded `bf_emma` voice.
- Views render setup for any provider with `if let setup = provider.setup`. No
  `provider.id == "local"` and no `Provider.local` in `Sources/EchoTypeApp`.
- Pick one rule for `Readiness.check` downloading: Apple's `check` still starts its speech
  asset install (`AppleSpeechAssets.swift`), while the docstring says check never downloads.
  Ask Aidan which.

### Layout

- Replace `SettingsSplitView.swift` with `NavigationSplitView`: `List(selection:)` sidebar
  with `.toolbar(removing: .sidebarToggle)`, and `.navigationTitle` on each page. Drive pages
  from a `Pane` enum carrying title and SF Symbol.
- Sidebar groups: Dictation, Read Aloud | xAI, Local | General, Keyterms, Agents, About.
- Every page is `Form { Section … }.formStyle(.grouped)`. Remove
  `.scrollContentBackground(.hidden)`, `.background(.regularMaterial)`, `.ignoresSafeArea()`,
  fixed frames and `.font(.body)`.
- Feature pages: a Provider `Picker` with the provider summary as footer; a Status section
  with a `LabeledContent` row per service; then the feature's own options. If the provider
  needs setup, a "Set Up…" button that opens its page.
- Local page: one section per feature with a `LabeledContent` row per model (name and purpose
  as a two-line label, size as value), a status row, `ProgressView(value:)` while installing
  and one Download / Cancel / Remove… button. Then a Storage section with the on-disk total,
  Manage Files… and licences. Install details appear only here.
- Manage Files: `Table(files, selection:)` in a sheet with toolbar confirmation actions, not
  a hand-laid frame.
- General > Permissions only. Remove the Permissions section from provider pages.

### Components

- Help text goes in `Section` footers, or as a second `Text` in a `Toggle` label. No
  `.caption` captions.
- Errors: `Label(message, systemImage: "exclamationmark.triangle.fill")` or the footer, not
  red body text.
- Replace hand-drawn boxes (commands, instructions, keyterms) with `LabeledContent` plus a
  Copy button, a Copy button with footer, and a plain `TextEditor` section.
- Speed: `Slider` with minimum and maximum value labels.
- API key: `LabeledContent("API key", value: masked)` plus plain Replace and Remove buttons.
- Permissions rows show their status once. Today `SettingsView.swift` around 799-817 shows
  "Granted" as both the value and a caption:

  ```swift
  LabeledContent(title) {
    if granted { Label("Granted", systemImage: "checkmark.circle.fill") }
    else { Button("Open System Settings…") { open(pane) } }
  }
  ```

### Copy

One sentence per message. No em dashes and no ` · ` separators. Cut the multi-sentence
strings in `LocalSettingsPane.swift` and `SettingsView.swift`; "Prepare / Retry" becomes
"Retry".

Done when no file in `Sources/EchoTypeApp/Views` sets a background, material, fixed font or
hand-drawn border; no Local names appear in `Sources/EchoTypeApp`; Aidan has approved
screenshots of every page in light and dark mode.

## 6. Documentation

- [0025](decisions/0025-provider-adapters.md): describe `Provider.setup` as an optional
  capability that Settings renders generically, remove the Local exceptions, and make "Settings
  … pick it up with no further change" true again.
- [0026](decisions/0026-local-model-stack.md) and [local-models.md](local-models.md): loading
  at launch, memory-pressure unloading, the install queue, boosting only with user keyterms.
- [0015](decisions/0015-settings-window-layout.md): replace the tab layout with the sidebar.
- `README.md`: anything the above changes.

Done when every changed behaviour is described once, in the record that owns it.

## Deferred

Do not start these. They are quality improvements for later briefs.

- Kokoro text normalisation for URLs, file names, versions, abbreviations and markdown.
- Prompt-lookup speculative decoding for cleanup.
- Resumable downloads with HTTP `Range`.
- Committing boosted transcripts at each utterance end so cleanup can run during speech.
