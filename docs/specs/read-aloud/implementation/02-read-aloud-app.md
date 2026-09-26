# Workstream 2: Read aloud in the app

Status: not started.

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

- Gate and placement: G2, after closure and before acceptance.
- Status: `Pending`
- Candidate and instructions: `TBD`
- Required evidence: pass or fail for steps 2 to 7 of the specification's "Checking it on the
  Mac" and the Read Aloud tab, plus the time to first audio.
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan's answer in the plan's escalation entry covers every step.
