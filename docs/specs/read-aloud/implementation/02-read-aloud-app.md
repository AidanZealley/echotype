# Workstream 2: Read aloud in the app

Status: accepted, 2026-09-26.

## Task packet

### Outcome

Selecting text in any app and pressing the read-aloud hotkey reads it aloud in the chosen voice
and speed, with a `Reading` pill that the hotkey, Escape or a click stops. The Read Aloud tab sets
the hotkey, voice and speed. Dictation behaves as before, except that starting one stops a
reading.

### Scope

Everything in the specification's Behaviour, "Copying the selection", "Fetching and playing
audio" and Implementation > App sections, for the branch decision 0018 chose:

- `Pasteboard.swift` (new): `Inserter`'s save and restore, extracted so both use it, plus the copy:
  post Cmd+C with explicit flags, poll `changeCount` every 10ms for up to 300ms, read the string
  and restore what was there before. `Inserter` keeps its supersede logic and uses the helper.
- `HotkeyMonitor` matches both `settings.hotkey` and `settings.readAloudHotkey` and reports which
  was pressed. Escape passes through unless a dictation or a reading takes it.
- `SpeechPlayer.swift` (new): wraps `AVAudioEngine` and `AVAudioPlayerNode` at `Speech.sampleRate`,
  schedules Float32 buffers from a `PCMDecoder`, stops immediately, and reports when the last
  scheduled buffer has finished.
- `Reader.swift` (new): runs one reading. Copy, read the Keychain once, cap the text, fetch, play,
  stop. For REST, `URLSession.bytes(for:)` with bytes gathered into roughly 100ms buffers; for the
  socket, `URLSessionWebSocketTransport` with `Speech.messages(text:)` and `Speech.Event`.
  Stopping cancels the fetch and stops the player.
- `DictationController` owns the `Reader`: it routes the read-aloud hotkey to it, sends Escape and
  pill clicks to it while reading, stops it before a dictation starts, and ignores the read-aloud
  hotkey while a dictation or test is starting or running. The Test button stays unavailable
  while reading. Map reading errors to the pill in red, worded as `describe(_:)` words dictation
  errors; a missing key uses the dictation wording.
- `Pill.Phase.reading`: the strip says `Reading`, the foot shows a stop hint, and the level glow
  stays at zero. "Nothing selected" is an error pill. "Reading the first 60,000 characters" shows
  in the text area when the text was cut. When the audio ends, the pill fades. Update `PillView`
  and `PillDemo` for the new phase.
- `SettingsView`: a `ReadAloudTab` with the `speaker.wave.2` icon after Keyterms, holding the
  hotkey picker (`Hotkey.readAloudPresets`), the voice picker (`Speech.voices`, capitalised) and
  a speed slider from 0.7 to 1.5. Each reading reads settings once when it starts.
- Update doc comments on `DictationController`, `HotkeyMonitor` and `Inserter` so they describe
  reading.
- After G2, add a short G2 paragraph to decision 0018 with the observed time to first audio, and
  set the specification's status line to implemented, with the date.

### Non-goals

- Anything in the specification's Out of scope section: word highlighting, voice previews,
  pausing, LLM clean-up, custom voices.
- Changes to `EchoTypeCore` or its tests. Raise an escalation for a defect there.
- The rejected fetch branch.
- Retries, logging, caching audio, or reading the pasteboard's non-string types.
- App-target tests. The target has none; review and G2 cover the wiring.

### Initial ownership

- `Sources/EchoTypeApp/`: `Pasteboard.swift`, `SpeechPlayer.swift` and `Reader.swift` (new),
  `Inserter.swift`, `HotkeyMonitor.swift`, `DictationController.swift`, `Views/Pill.swift`,
  `Views/PillView.swift`, `Views/PillDemo.swift` and `Views/SettingsView.swift`.
- `docs/decisions/0018-read-aloud-audio-fetch.md`, the G2 paragraph only.
- `docs/decisions/0009-overlay-behaviour.md`, only if something it states is no longer true.
- `docs/specs/read-aloud.md`, status line only.
- This packet's record sections, and the workstream 2 row, G2 row, escalation and drift entries in
  `plan.md`.

### Required seams

Consume the plan's "Cross-workstream contracts" as workstream 1 delivered them, and read decision
0018 for the branch. Use one `PCMDecoder` per reading.

### Acceptance criteria

1. The read-aloud hotkey with text selected copies it with Cmd+C carrying explicit flags, restores
   the previous pasteboard contents, and starts reading with the pill in its `Reading` phase.
2. With nothing selected the pill shows "Nothing selected" in red and nothing is fetched.
3. The read-aloud hotkey, Escape or a click on the pill stops reading at once: the player stops
   and the request or socket is cancelled. Escape is consumed only while reading or dictating.
4. When the audio ends the pill fades. Stopping early also fades it, with no error.
5. A selection over 60,000 characters reads its first 60,000 and the pill says "Reading the first
   60,000 characters".
6. The dictation hotkey during a reading stops the reading and starts a dictation. The read-aloud
   hotkey during a dictation or a test does nothing and is consumed.
7. A missing key and API errors show in the pill in red, worded as for dictation.
8. The request uses the voice, speed and language from settings read when the reading starts.
9. PCM chunks are decoded by one `PCMDecoder` per reading and scheduled as they arrive, not
   after the whole response.
10. The Read Aloud tab appears after Keyterms with the three settings, and they persist through
    `SettingsStore`. Changing the hotkey applies without relaunching.
11. Dictation, insertion and the Test button behave as before when no reading is involved.
12. `swift build` and `swift test` pass, and `./scripts/run.sh` builds and launches the app.
13. Gate G2 has passed.

### Targeted verification

```bash
swift build
swift test
./scripts/run.sh
```

`./scripts/run.sh` stops any running EchoType, including the installed one, and launches the
development bundle. `./scripts/run.sh --hud-demo` shows the pill demo, which is a quick way to
see the `Reading` phase. Check the tab in Settings if you can drive the UI; otherwise G2 covers
it.

## Implementation handoff

- Base commit: `6875601`
- Outcome: REST branch built as scoped. Reading covers copy, one Keychain read, cap, a streamed
  `POST /v1/tts` through one `PCMDecoder` into roughly 100ms (4,800-byte) buffers, and playback.
  The read-aloud hotkey, Escape or a click stops a reading, and the dictation hotkey stops it
  and starts a dictation. There is a `Reading` pill phase and a Read Aloud tab. `EchoTypeCore`
  and its tests are untouched.
- Files changed:
  - New in `Sources/EchoTypeApp/`: `Pasteboard.swift` (`saved()`, `restore(_:)`,
    `copySelection()`), `SpeechPlayer.swift` and `Reader.swift`.
  - Changed in `Sources/EchoTypeApp/`: `Inserter.swift`, `HotkeyMonitor.swift`,
    `DictationController.swift`, `Views/Pill.swift`, `Views/PillView.swift`,
    `Views/PillDemo.swift` and `Views/SettingsView.swift`.
  - `docs/decisions/0009-overlay-behaviour.md`: the click bullet now says a click stops a
    reading.
- Decisions:
  - `Reader` is created per reading and starts its own task in `init`, so `stop()` always has
    a task to cancel. `stop()` cancels the task, which cancels the `URLSession` request, and
    calls `SpeechPlayer.stop()`. `finished()` returns quietly when the task was cancelled, so
    stopping early never shows an error.
  - `SpeechPlayer.finished()` queues one silent frame and awaits its `.dataPlayedBack`
    completion. `node.stop()` completes it at once. A scratch check on this Mac confirmed
    both: about 1.0s for 1s of queued audio, and immediate return on stop and on a player
    that was never started.
  - Controller phase `.reading(Reader)`. The dictation hotkey during a reading sets `.starting`
    and runs `reader.stop()` and then `dictate()`. The reading's own cleanup sees that it is no
    longer the current reader and leaves the phase and the pill alone. `isIdle` is false
    while reading, so the Test button is disabled.
  - The pill is set up when the press arrives but shown only when `Reader` calls `onStart`,
    after the copy and the key. "Nothing selected" therefore shows straight away in red with
    no `Reading` flash first. The cut notice goes in `Pill.settled`.
  - Pill foot while reading: `esc stop`. This is right whichever read-aloud hotkey is set. The
    dictation foot hard-codes `⌥D` and is unchanged. The meter shows a `speaker.wave.2.fill`
    icon, and the glow's opacity is 0.
  - `describe(_:)` gains `Reader.Failure` (`nothingSelected`, `noAPIKey` sharing the dictation
    string, `playback`), bare `STTError` cases with the same wording as the wrapped
    `SessionError.stt` ones, a catch-all `xAI error: …` for other statuses, and `URLError` as
    `Connection failed: …`.
  - The tab's speed slider steps by 0.1 and shows the value to one decimal place.
  - G2 (Aidan, E2 and E3): steps 1 to 7 passed, time to first audio under half a second.
    Lasting decision: while reading, the pill's waveform glow and meter bars move with the
    audio as it is heard, on dictation's scale. Aidan asked for this in E2 and passed its look
    in E3. It replaces the packet's "the level glow stays at zero"; the drift log carries it
    for the final review, which owns the specification's line.
- Verification: `swift build` and `swift test` pass (52 tests). `./scripts/run.sh` built,
  signed and launched the development app. `./scripts/run.sh --hud-demo` showed the `Reading`
  pill with the cut notice, and the red "Nothing selected" pill (checked from screenshots).
  The Settings tab was not checked by driving the UI. The dev app was quit and the installed
  `/Applications/EchoType.app`, which `run.sh` had stopped, was relaunched.
- Known limitations or external checks:
  - Error pills, reading errors included, still show the dictation foot `⌥D stop · esc
    cancel`. This predates this workstream.
  - A 400 from TTS reads "xAI rejected the API key", as for dictation. A regional language tag
    such as `en-GB` may also cause a 400 (see the drift log), and G2 should try one.
  - If a reading starts within 0.8s of an insertion, the copy saves and restores the
    transcript, and `Inserter`'s pending restore then finds the pasteboard changed and leaves
    it alone. The user's earlier pasteboard contents are lost in that case.
  - `AVAudioEngine.connect` and `AVAudioPlayerNode.play` are deprecated in the macOS 27 SDK.
    They don't warn at the package's macOS 26 target.
- Specification drift: the reading glow above (drift log). The specification's
  `read-aloud.md:134` still says the glow stays at zero.
- Remediation (R1 and O4):
  - R1: `Pasteboard.copySelection()` now runs its copy and poll in an unstructured task, which
    does not inherit the caller's cancellation, so the 300ms wait and the restore always run.
    `Reader` checks for cancellation right after the copy, before "Nothing selected", so a
    stop during the copy ends quietly. A scratch check of the same pattern in a cancelled task
    waited 361ms instead of returning at once.
  - O4: `readAloudPressed()` now cancels the error fade and sets `screen` and the hidden
    `Reading` pill synchronously, before it creates the `Reader`. `read(_:)` only awaits the
    reading and cleans up. The comment says the pill shows only once the reader has the text.
  - Verification: `swift build` (no warnings after touching every app source) and
    `swift test` (52 tests) pass. `./scripts/run.sh` was not run, per the lead.
- G2 correction: reading glow (approved by Aidan in E2; replaces "the level glow stays at
  zero"):
  - `SpeechPlayer` installs a tap on the player node's output in `init`, about 100ms per
    buffer. The tap computes the buffer's RMS, scales it with `Overlay.level(rms:)` as
    dictation does, and hands it to the main actor, which drops it unless the node is still
    playing. `Reader` gains an `onLevel` parameter that it passes to the player, and
    `DictationController` feeds it to `updatePill { $0.level = level }`. Because the player
    has stopped by the time the reading's cleanup runs, a dictation's or a later reading's pill
    never gets a stale level.
  - Why a tap: the node renders in real time, so the tap follows what is heard with no
    bookkeeping. Per-buffer levels at schedule time would need completion callbacks to line
    them up with playback. `engine.stop()`, called on stop and at the end, stops the tap.
  - Look: while reading, the glow matches listening: blue, rippling, opacity 0.4. The
    `LevelMeter` shows the moving bars in place of the speaker icon, since the strip already
    says `Reading`. `PillDemo` runs the reading pill through `speak(_:for:show:)`. Doc
    comments on `SpeechPlayer`, `Reader.init`, `Pill.Phase.reading`, `Pill.level`, `LevelMeter`
    and `LevelGlow` are updated.
  - Not changed: `docs/specs/read-aloud.md:134` still says the glow stays at zero. That is
    outside this packet's ownership, and the drift log records the change.
  - Verification: `swift build` (no warnings after touching every app source) and
    `swift test` (52 tests) pass. A scratch `AVAudioEngine` check with the same tap delivered
    2,400-frame buffers every ~100ms across 1s of scheduled audio, which is real time, and
    nothing after `stop()`. `./scripts/run.sh --hud-demo` screenshots show the `Reading` pill
    with the blue top glow and bars at different heights from frame to frame. The demo was
    quit and `/Applications/EchoType.app` relaunched. Audio-driven glow in a real reading
    still needs Aidan's look.

## Independent review

- Reviewer: fresh independent review agent, 2026-09-26, against `6875601` plus the uncommitted
  diff.
- Verdict: changes required. One Required finding, in the pasteboard restore when a reading is
  stopped during the copy. Everything else meets criteria 1 to 12 on reading. Criterion 13 is
  G2 and was not assessed.
- Checks run:
  - `swift build` after touching every `EchoTypeApp` source: builds with no warnings or errors.
  - `swift test`: 52 tests pass.
  - `git diff HEAD --stat -- Sources/EchoTypeCore Tests`: empty, so `EchoTypeCore` and its
    tests are untouched.
  - A scratch script ran the copy's poll loop (`for _ in 0..<30 { try? await Task.sleep(for:
    .milliseconds(10)) }`) in a cancelled task. It finished in 0.25ms, not 300ms.
  - `./scripts/run.sh` was not run, per the lead's instruction.
- Required findings:
  - **R1. Stopping a reading during the copy loses the user's pasteboard.**
    `Pasteboard.copySelection()` (`Pasteboard.swift:32-47`) posts Cmd+C, then polls with
    `try? await Task.sleep`. `Reader.stop()` cancels the reading's task (`Reader.swift:38-41`),
    and a cancelled `Task.sleep` throws at once. The `try?` swallows that, so all 30
    iterations finish in about 0.25ms (scratch check above) and the function returns nil
    before the focused app has handled the Cmd+C. The copy then lands on the pasteboard and
    nothing restores it. This happens when Escape, a second read-aloud press
    (`DictationController.swift:121-122`, `134-136`) or the dictation hotkey
    (`DictationController.swift:102-108`) arrives before the copy registers. That window is
    typically tens of milliseconds, longer in slow or Electron apps. In the dictation case,
    `Inserter` may then save the selection as "the user's" contents. This breaks the
    specification's "put back what the pasteboard held before" and criterion 1's restore.
    Suggested fix, simplest first: finish the bounded 300ms copy whether or not the task is
    cancelled, for example with a sleep that ignores cancellation, and check cancellation
    after `copySelection()` returns, as `Reader.swift:47` already does after the key.
- Optional observations:
  - **O1. The reading's catch-all errors show Swift case names.** `DictationController.swift:443-444`
    words any other `STTError` as `"xAI error: \(error)"`. A 500 therefore shows
    `xAI error: unexpectedStatus(500)`, and a 413 shows `xAI error: payloadTooLarge`. Plain
    wording such as "xAI error: HTTP 500" would read better. Dictation's own fallback,
    `Dictation failed: …`, is no better, so this does not break "worded as for dictation".
  - **O2. A 400 reads as a key problem.** `DictationController.swift:432-434` maps `STTError.badRequest`
    to "xAI rejected the API key". For TTS, a 400 is as likely to be a rejected `language` or
    `voice`. This is already in the handoff and the drift log, and G2 should read once with a
    regional language tag.
  - **O3. Bytes are read one at a time on the main actor.** `Reader` is `@MainActor`, and
    `Reader.swift:62-67` appends one byte per `AsyncBytes` iteration on the thread that also
    serves the event tap. At the spike's rate, about 240 KB/s (4.9 MB in 20s), this is cheap
    enough. If G2 shows hotkey lag during a long reading, gather bytes off the main actor.
  - **O4. Pill set-up depends on task order.** `read(_:)` sets `pill` and `screen`
    (`DictationController.swift:352-354`) in a task queued after the one `Reader.init`
    starts (`Reader.swift:24`). It relies on the reader suspending in `copySelection()`
    before `onStart` calls `updatePill`. That suspension always happens, so it works today.
    Setting `pill` and `screen` in `readAloudPressed()` would remove the dependency.
  - **O5. Reading error pills show the dictation foot.** `PillView.swift:19` shows
    `⌥D stop · esc cancel` on a reading's error pill. The handoff already notes this, and
    error pills showed it before this workstream.
  - **O6. A doc comment reflow is cosmetic.** In `Views/Pill.swift:3-6`, the reflow leaves a
    short line ("build a `Pill` and").
- Questions:
  - **Q1. Should the scheduled audio be bounded?** `Reader.swift:62-68` schedules every buffer
    as it arrives, as the specification says. The response arrives about 5x faster than
    real time, so almost the whole reading ends up queued in the player node as Float32. By
    the spike's ratio (4,934,304 bytes for about 1,900 characters), a 60,000-character
    reading is about 54 minutes of audio, and about 310 MB of scheduled buffers. That is
    within the specification's letter. The lead should judge whether a cap belongs in this
    workstream or should be left alone. A cap here would wait for playback once more than a
    few seconds are queued, which holds the HTTP stream open longer.
- Concurrency and cancellation, verified with no finding:
  - `stop()` is synchronous on the main actor. It cancels the task, which cancels
    `URLSession.bytes(for:)`, and calls `node.stop()`, which completes the `finished()`
    silence buffer at once.
  - `Reader.swift:47` and `:56` stop a late key or response from starting the player after a
    stop. `onStart` cannot run after a stop, because the cancellation check precedes it.
  - `finished()` swallows the cancelled task's error (`Reader.swift:33`), so an early stop
    fades the pill with no error.
  - `read(_:)` compares reader identity (`DictationController.swift:358`, `369-371`) before
    touching the phase or the pill. A dictation that took over, or a later reading, is never
    disturbed by a stale cleanup.
  - A reading that ends naturally while a new press arrives leaves the phase `.reading` until
    cleanup. A read-aloud press in that window only stops the finished reader, and a
    dictation press takes over normally.
  - Escape is consumed only in `.reading`, `.starting`, `.abandoned` and `.running`
    (`DictationController.swift:130-147`). The read-aloud hotkey is consumed in every phase
    (`HotkeyMonitor.swift:94-98`) and ignored outside `.idle` and `.reading`
    (`DictationController.swift:123-124`).
  - Settings are snapshotted once, at the press (`DictationController.swift:116`), into
    `Speech.request`, which carries voice, speed and language.
  - `isIdle` is false while reading, so the Test button (`SettingsView.swift:175`) is
    disabled.

## Resolution

- Finding dispositions:
  - R1 accepted. The copy must finish its bounded 300ms wait even when the reading is stopped,
    then honour the cancellation, so the pasteboard is always restored.
  - O4 accepted as a small fix: set `screen` and the `Reading` pill synchronously when the
    press creates the reader, not in a later task, and keep the comments accurate about when
    the pill appears.
  - O1 declined: dictation's catch-all wording is no plainer, and error wording is shared.
  - O2 declined: the specification asks for dictation's wording; the drift log already asks G2
    to try a regional language tag.
  - O3 declined: cheap at the observed rate; revisit only if G2 shows hotkey lag.
  - O5 declined: older than this workstream; the foot does not know the configured hotkey.
  - O6 declined: cosmetic.
  - Q1 declined for this workstream: the specification says each chunk is scheduled as it
    arrives, and a backpressure cap adds machinery and a server-timeout risk for the rare
    60,000-character reading. Left for the final review to weigh.
- Simplification/deletion pass: the implementation agent's pass stands; the remediation
  replaced the copy's cancellable sleep loop with one uncancellable task rather than adding a
  flag. Closure's note on the Accessibility lookup now running in the tap callback is accepted:
  it is bounded, and dictation's lookup blocks the same main thread.
- G2 correction review dispositions:
  - No Required findings.
  - O1 declined: one 102-column line, cosmetic.
  - O2 declined: `installTap` joins the other macOS 27 deprecations, which do not warn at the
    macOS 26 target.
  - Q1 deferred to Aidan's look at the new candidate: if the glow sits near full while reading,
    playback gets its own scale as a further G2 correction.
  - No remediation or closure pass: nothing was accepted to fix.
- Acceptance (resumed lead, after E3 passed): no code changed since the G2 correction review,
  so no further review was needed. The lead added the G2 paragraph to decision 0018, set the
  specification's status to implemented, and brought decision 0009 up to date: the meter also
  reads playback, and a reading press finds the pill's screen in the event tap callback
  (closure's note on O4).
- Final verification: lead reran `swift build` and `swift test` (52 tests pass) on the
  remediated diff, and `./scripts/run.sh` built and launched the candidate. At acceptance,
  `swift build` and `swift test` (52 tests) passed again on the final diff.

## Closure review

- Reviewer: fresh closure agent, 2026-09-26, against `6875601` plus the uncommitted diff.
- Verdict: closed. R1 and O4 are fixed, and neither fix introduces a release-blocking defect.
- Checks run: `swift build` completes, and `swift test` passes 52 tests. `./scripts/run.sh` was
  not run, per the lead.
- R1: `Pasteboard.copySelection()` (`Pasteboard.swift:31-34`) awaits an unstructured `Task`.
  It inherits the main actor but not the reader's cancellation, and a non-throwing task's
  `.value` waits even when the caller is cancelled. So the 300ms poll and the restore always
  run. `Reader.swift:45` checks cancellation before "Nothing selected", so a stop during the
  copy still ends quietly through `finished()`. The phase stays `.reading` until then. Escape
  and the read-aloud hotkey stay consumed, and the dictation hotkey takes over as before.
  Dictation does not touch the pasteboard until insertion, so the copy's restore cannot race it.
- O4: `readAloudPressed()` (`DictationController.swift:113-122`) cancels the fade and sets
  `screen` and the hidden `Reading` pill before it creates the `Reader`. `onStart` therefore
  always finds them. The comments at `:118-119` and `:353-354` match.
- Note, not a finding: O4 moves `NSScreen.forFocusedWindow()`, an Accessibility lookup, into
  the event tap callback. Dictation does that lookup in a task. It is bounded at 0.25s per read,
  and the main thread would block the next tap event either way. It departs a little from
  decision 0009's "the callback only changes the phase", but it follows the lead's disposition.
- Remaining required findings: none.

## External validation

- Gate and placement: G2, after closure and before acceptance.
- Status: `Passed`
- Candidate and instructions: base `6875601` plus the uncommitted workstream 2 diff, launched
  by the lead with `./scripts/run.sh` as `.build/EchoType.app` after the remediation, so the
  running app is the current diff. Aidan checks steps 2 to 7 of the specification's "Checking
  it on the Mac", the Read Aloud tab's hotkey, voice and speed, one reading with a regional
  language tag such as `en-GB` (drift log), and the 60,000-character message if he has a long
  enough selection. He reports pass or fail for each and the time to first audio.
- Required evidence: pass or fail for steps 2 to 7 of the specification's "Checking it on the
  Mac" and the Read Aloud tab, plus the time to first audio.
- Attempts and lasting decisions:
  - Attempt 1 (E2): steps 1 to 7 passed, including a reading with `en-GB`. Step 8, the
    60,000-character message, was not run. Time to first audio: under half a second, felt
    instant.
  - G2 correction, approved by Aidan in E2 as drift: while reading, the pill's waveform glow
    shows as it does during dictation, driven by the audio as it plays rather than as it
    arrives. This replaces the packet's "the level glow stays at zero". It gets a focused
    review, then a new candidate for Aidan to see the glow.
  - Attempt 2 (E3): the corrected diff, launched by the lead with `./scripts/run.sh` as
    `.build/EchoType.app` after `swift build` and `swift test` (52) passed. Aidan: pass. The
    glow and meter move with the voice, ⌥S stops a reading, and a dictation started during a
    reading takes over the glow cleanly. This settles the correction review's Q1: the glow
    does not sit pinned, so playback keeps dictation's scale.
- Result: passed. Decision 0018 records G2 and the time to first audio.

## G2 correction review

- Reviewer: fresh focused review agent, 2026-09-26, against `6875601` plus the uncommitted
  diff. Only the "G2 correction: reading glow" change was in scope.
- Verdict: closed. The glow follows playback, nothing keeps delivering levels after a stop, the
  end of the audio, a dictation taking over or a following reading, and dictation is unchanged.
  No Required findings.
- Checks run:
  - `touch` on every `EchoTypeApp` source, then `swift build`: builds with no warnings or
    errors. `swift build -v` confirmed `SpeechPlayer.swift` was recompiled.
  - `swift test`: 52 tests pass.
  - A scratch program copying `SpeechPlayer`'s tap (a `nonisolated static` factory, the
    `isPlaying` guard on the main actor), built with `swiftc -swift-version 6`, scheduled 2s
    of audio and stopped after 1s. It delivered 10 levels about 100ms apart, starting at
    0.23s. A `precondition(!Thread.isMainThread)` in the tap held, there was no isolation
    trap, and 0 levels arrived after `stop()`.
  - `./scripts/run.sh` was not run, per the brief.
- Follows playback: the tap is on the player node's output (`SpeechPlayer.swift:20-25`), so it
  fires as the engine renders, not as `Reader` schedules. The response arrives about 5x faster
  than real time (`Reader.swift:68-73`), and the scratch check shows levels arriving in real
  time.
- No stale tap or level:
  - Stop: `Reader.stop()` (`Reader.swift:42-45`) calls `SpeechPlayer.stop()`, which stops the
    node and the engine (`SpeechPlayer.swift:48-51`). The engine no longer renders, so the tap
    stops firing. Any level already queued on the main actor finds `node.isPlaying` false and
    is dropped (`:24`).
  - End of audio or a failure mid-stream: `defer { player.stop() }` (`Reader.swift:65`) runs
    before the task completes. `read(_:)` then clears the pill (`DictationController.swift:356-363`),
    so the reading's cleanup never sees a playing node.
  - Dictation takes over: `hotkeyPressed()` runs `reader.stop()` and then `dictate()`, in that
    order and in one main-actor task (`DictationController.swift:102-108`). So the node stops
    before `showStarting()` builds the dictation's pill, and no reading level can reach it.
  - Following reading: a new press builds a new `Reader`, which builds a new `SpeechPlayer`
    (`Reader.swift:27`). The old player's queued levels test the old node, which has stopped.
    A new reading also needs the phase back at `.idle`, and only the old reading's cleanup sets
    that.
  - Before the audio starts, and when a reading fails before `player.start()`, the engine never
    runs, so the tap never fires.
  - Lifetime: the tap block holds `self` weakly, so the engine, node and tap go when the
    `Reader` is released. Not removing the tap explicitly is fine.
- Threading and concurrency: the tap closure is built in a `nonisolated static` function
  (`SpeechPlayer.swift:54-65`), so Swift 6 infers no main-actor isolation for it and inserts no
  runtime check on the audio thread. The block does only an RMS, `Overlay.level(rms:)` and a
  `Task { @MainActor in … }`. `node.isPlaying` and `updatePill` are read on the main actor only.
  The tap thread is AVAudioEngine's own, not the real-time render thread, so allocating a
  `Task` there is acceptable. Dictation's `AudioChunker` uses the same hand-off pattern
  (`AudioChunker.swift:55`).
- Dictation unchanged: `levelChanged(_:)` and `AudioCapture.onLevel` are untouched.
  `LevelGlow`'s `.listening` opacity (0.4) and its animation are as before; `.reading` joins
  those cases (`PillView.swift:165`, `:183`). `LevelMeter`'s `.starting`, `.listening` and
  `.paused` rendering is unchanged; `.reading` joins that branch (`PillView.swift:68`). The old
  speaker-icon case is gone, not left as dead code.
- Simplicity: the handoff gives its reason for using a tap rather than levels at schedule time:
  those would need completion callbacks to line up with playback. The one addition to
  `Reader` and `DictationController` is an `onLevel` parameter, fed into the existing
  `updatePill`. There are no flags, no extra state and no new types. This is adequate and
  minimal.
- Required findings: none.
- Optional observations:
  - **O1. One line is over 100 columns.** `PillView.swift:165` is 102 characters. Every other
    line the workstream touched stays within 100. (`SettingsView.swift:235` is longer, but that
    line was already there at `6875601`.)
  - **O2. `installTap` is also deprecated in the macOS 27 SDK.** The scratch build warned
    "'installTap(onBus:bufferSize:format:block:)' was deprecated in macOS 27.0". The package's
    macOS 26 target gives no warning, as the handoff already notes for `connect` and `play`.
    The handoff's known-limitations note could name `installTap` too.
- Questions:
  - **Q1. Will the reading glow sit near full?** Playback uses `Overlay.level(rms:)`, which maps
    -50 to -20 dBFS linearly (decision 0009). Dictation's microphone speech "sits around two
    thirds" on that scale. TTS output is usually normalised louder, around -20 to -16 dBFS, so
    the reading glow may stay near full depth and move less than dictation's. No real reading
    could be measured here. Aidan's look at the new candidate should settle it. If it looks
    pinned, adjust the scale for playback only.
