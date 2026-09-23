# Workstream 3: Dictation end to end

Status: accepted.

## Task packet

### Outcome

Opt+D starts a session, speech streams to xAI, Opt+D again inserts the transcript at the
caret in whatever app has focus, and Escape discards it. The menu bar icon says whether a
session is running. Aidan can dictate a prompt into a coding agent with it.

### Scope

**The hotkey, rewritten.** `HotkeyMonitor.swift` is spike code: a file-scope mutable tap,
a hardcoded keycode, and a call to `insert` with a literal string. Replace it with a type
that takes the configured `Settings.Hotkey` and reports presses to its caller. Keep the
`tapDisabledByTimeout` and `tapDisabledByUserInput` re-enabling exactly as it is; that
part is right, and the specification names a tap that silently stops as the most likely
mystery failure in the project.

Escape is consumed only while a session is open, so it behaves normally the rest of the
time.

Put the matching rule in `EchoTypeCore`, on `Settings.Hotkey`: given a keycode and a set
of modifiers, does this chord match, with the configured modifiers held and no others.
That predicate is the only part of the tap that can be tested, and the settings milestone
will add presets that lean on it. Keep it to that; if it grows into a general event model
it has gone wrong. The `CGEventFlags` to `ModifierFlags` mapping stays in the app.

**The Keychain, read only.** `Keychain.swift` reads a `kSecClassGenericPassword` item for
service `com.aidanzealley.echotype` and returns the xAI key, or nothing. No write path
and no UI: the settings milestone owns those. Aidan seeds the item by hand once, and you
publish the exact `security add-generic-password` command with the G1 candidate.

A missing key is a normal state, not a crash. The user sees it as the menu's state line.

**The controller.** One type owning the session lifecycle: on a hotkey press with no
session, read the key, open a `URLSessionWebSocketTransport` against
`STTConnection.streamingURL(settings:)`, start a `SessionMachine`, start audio delivery,
and pump chunks into `send(audio:)`. On a press with a session running, `trigger()`. On
Escape, `cancel()`. When `run()` returns, act on the outcome:

- `insert(text)`: insert it.
- `nothing`: do nothing.
- `failed(text, error)`: insert the text if there is any, and show the error in the menu.

Recall that the socket opens on trigger, not at launch, because an idle open socket bills
streaming time. The audio device is the opposite: it stays warm, which is workstream 2's
concern.

**The menu bar.** `MenuBarExtra`'s icon reflects state, driven by `SessionMachine.states`.
The menu holds the current state, and Quit. No manual trigger item: clicking it leaves
focus wherever it was, so it cannot do the real job. The icon is `waveform` for now.

The menu's state line is also where a failure is reported, and where "no API key" is
reported. This is the only place the user can see anything in this milestone, which is
why it carries more than the specification's overlay-era description implies. Record that
as drift.

**The insertion fix.** `Inserter.insert` schedules its pasteboard restore with a bare
`asyncAfter` 800ms out. Two dictations inside that window race: the second snapshots the
first one's transcript as the contents to restore. Give the pending restore an identity so
a new insertion supersedes it. Also skip the restore write when there was nothing on the
pasteboard to begin with, rather than clearing it and writing an empty array.

Do not change the `changeCount` rule itself. Step 4 of the specification's insertion
sequence is settled and the spike confirmed it by hand.

### Non-goals

- The overlay, in any form, including a borderless window "just to see the transcript".
- Live transcript text, interim text or elapsed time crossing the `SessionMachine` seam.
- The level meter.
- The settings window, the hotkey preset dropdown, the device picker, the keyterms
  editor, launch at login and the Test button.
- `install.sh` and `--hud-demo`.
- Writing to the Keychain.
- Reconnecting or retrying a failed session.
- Changing `SessionMachine`, the transport or `Package.swift`. A defect there is an
  escalation.

### Initial ownership

- `Sources/EchoTypeApp/HotkeyMonitor.swift`
- `Sources/EchoTypeApp/Keychain.swift`
- `Sources/EchoTypeApp/DictationController.swift`
- `Sources/EchoTypeApp/Inserter.swift`
- `Sources/EchoTypeApp/App.swift`
- `Sources/EchoTypeCore/Settings.swift`, for the hotkey matching predicate only
- `Tests/EchoTypeCoreTests/`, for that predicate's tests

`Sources/EchoTypeApp/AudioCapture.swift` belongs to workstream 2. Change it only while
troubleshooting gate G1, and record each change in the handoff as a correction to
workstream 2's work.

### Required seams

- `SessionMachine` as workstream 1 left it. Consume it; do not extend it.
- The capture API recorded in workstream 2's Implementation handoff.
- `STTConnection.streamingURL(settings:)` and `STTConnection.headers(apiKey:)`.
- `Settings` as it stands, including its placeholder keyterms. There is no persistence in
  this milestone: construct the default `Settings` and use it.

### Acceptance criteria

1. Opt+D opens a session; Opt+D again inserts the transcript at the caret. Proven by gate
   G1, not by a test.
2. Escape while a session is open cancels it and inserts nothing. Escape with no session
   passes through to the focused app untouched.
3. The chord is read from `Settings.Hotkey`, not hardcoded, and matching requires the
   configured modifiers and no others, so Cmd+Opt+D and Ctrl+Opt+D pass through. Tests
   cover the predicate.
4. The tap re-enables itself on `tapDisabledByTimeout`.
5. A missing Keychain item leaves the app running and says so in the menu.
6. `Outcome.failed` inserts the accumulated text and shows the error in the menu.
   `Outcome.nothing` inserts nothing.
7. Two dictations inside the 800ms restore window do not corrupt each other's pasteboard
   restore.
8. The menu bar icon differs between idle and a running session.
9. No overlay, settings window or level meter appears in the diff.
10. Gate G1 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
swift test
./scripts/run.sh
```

Add the hotkey predicate's tests to `Tests/EchoTypeCoreTests/`.

```bash
swift-format lint --recursive Sources Tests Package.swift
```

Skip the lint if swift-format is not installed and say so in the handoff.

Everything else is gate G1. Do not manufacture a test for the tap, the pasteboard or the
Keychain by wrapping them in a protocol and faking them.

## External validation

- Gate and placement: G1, after focused closure and before acceptance
- Status: `Passed`, on candidate 4, 2026-09-24
- Candidate and instructions: candidate 4, published 2026-09-24. It is candidate 3 with
  correction T4 (the microphone is released when each session ends) and with the T3
  diagnostic removed, built and relaunched with `./scripts/run.sh` and running now. The key
  is already seeded, so the seeding step is done; the command stays in the Decisions of the
  handoff below. Use the MacBook Pro Microphone (System Settings > Sound > Input). T4 can
  affect only three things, so only these need rechecking, in TextEdit:
  1. Cold-start first word. Wait a few seconds after any earlier dictation, press Opt+D and
     start speaking straight away, then press Opt+D. Is the first word there?
  2. Back to back. Dictate one sentence, and within a second or two of it landing dictate
     another. Do both land, with their first words?
  3. The indicator. Does the orange macOS microphone indicator clear when a session ends,
     both after Opt+D commits and after Escape cancels?
  If a grant misbehaves, `tccutil reset All com.aidanzealley.echotype` and relaunch.
- Required evidence: the seven G1 observations in [plan.md](plan.md), in Aidan's words,
  plus one added by the lead: 8. whether the last word was clipped, because remediation R1
  changed how the commit press ends capture and only real audio can confirm it. If no key is
  seeded, the menu's state line should read "No xAI API key in the Keychain" after Opt+D.
  All eight passed on candidate 3; candidate 4 needs only its three checks above.
- Attempts and lasting decisions:
  - Attempt 1, candidate 1 (the tree after closure). Failing action: after a
    `tccutil reset` and `./scripts/run.sh`, only Device Control and Data Access was
    prompted, never Microphone; after granting it, Opt+D changed nothing, with no icon
    change, prompt or text. Evidence: the unified log shows WindowServer checking the
    event-tap grant once it was given, then two `SecItemCopyMatching` calls from the app
    (pid 80059) at 20:02:15 and 20:02:17, one per Opt+D. So the tap was installed and
    matched the chord. `security find-generic-password -s com.aidanzealley.echotype` finds
    no item: the key had not been seeded, so `dictate()` returned with "No xAI API key in
    the Keychain" before `AudioCapture.start()`, which is what requests Microphone access
    and what puts the icon into the running state. The problem only showed inside the
    menu. No Microphone check appears in the TCC log. Diagnosis: working as built, but the
    candidate's order (key before microphone) and the instructions (seed after the first
    launch, Microphone expected at launch) made a missing key look like a dead app.
  - T1, the correction: `dictate()` opens the microphone before reading the key, and calls
    `audio.stop()` if the key is missing. The first Opt+D now raises the Microphone prompt
    whether or not a key is seeded, and the Keychain read leaves the first word's path,
    which is review O1's suggestion. Microphone before socket and workstream 2's
    `start()`/`stop()` pairing both still hold. The instructions now seed the key before the
    first Opt+D, say Microphone is prompted on first use, and point at the menu's state
    line when nothing seems to happen. `swift build` clean; `timeout 180 swift test
    --disable-xctest` 35 passing, no helper left running. No change to `AudioCapture`.
  - Attempt 2, candidate 2. What worked: Opt+D raised the Microphone prompt, and the menu bar
    icon and the macOS microphone indicator both changed while a session ran. Failing
    actions: after seeding, the menu still reported no key until a relaunch; after the
    relaunch every dictation failed with "xAI rejected the API key" and nothing was inserted.
    Evidence, from the unified log and the Keychain item's attributes (the secret was
    inspected only for shape, never printed or recorded):
    - The item was created at 20:05:40. The app running then (pid 85306) last read the
      Keychain at 20:05:15, from presses made before the item existed, and made no read
      after it; its menu was opened afterwards. So the app never missed a fresh item: the
      menu was still showing the result of the earlier presses, since the state line holds
      the last attempt's problem until the next Opt+D. The relaunch only coincided with the
      next press. Each Opt+D in the relaunched app (pid 90203) read the Keychain afresh.
    - Every press after the relaunch read the item and opened the socket, and `api.x.ai`
      answered each upgrade with HTTP 400, which the app reports as a rejected key.
    - The stored secret is not an xAI key: it does not start with `xai-` and is a small
      fraction of an xAI key's length. A 400 is exactly what the endpoint returns for it.
      The most likely cause is typing a Mac password at `security`'s "password data for new
      item" prompt rather than pasting the key.
    Diagnosis: the key in the Keychain is wrong; the app reads and sends it correctly. No
    live request was made, since sending the stored value to xAI would only disclose it
    again and could not show more than the 400 already logged. No code change.
  - T2, the correction: the seeding step now says what the prompt wants, adds a check that
    the stored value looks like an xAI key without printing it, and explains that the menu
    line describes the last Opt+D so a fresh key needs a fresh press, not a relaunch.
  - Candidate 2 republished 2026-09-23 with T2; awaiting Aidan.
  - Attempt 3, candidate 2 after re-seeding. What worked: the key was accepted, sessions
    opened and text was inserted. Failing action: most transcripts were wrong. Often the
    inserted text was the seeded keyterms themselves ("Supabase , AppKit, SwiftUI, Tailwind,
    Vite, TypeScript, Zod, xAI"), once a sentence never said ("Three , how to make an account
    in Justs."), and only occasionally what was said, in a room Aidan describes as silent.
    Evidence, gathered on this Mac without speaking into it:
    - The default input device throughout attempts 2 and 3 was the Bluetooth earbuds
      "Between 3ANC". The unified log shows the input stream starting at 44.1 kHz and
      switching to 16 kHz once capture starts, which is a Bluetooth headset moving into
      its headset (HFP) profile. It is not the MacBook Pro Microphone.
    - Conversion is correct. The `Chunker` conversion, run offline on a 440 Hz tone in tap
      sized buffers at 44.1, 48 and 16 kHz, produces 16 kHz Int16 at the right length and
      pitch with no discontinuity at buffer boundaries.
    - Capture from the real device is correct in form. `AudioCapture.swift` itself, compiled
      into a probe signed as the app so it shares the Microphone grant, delivered 16 kHz
      audio in real time from the earbuds (5.12s of audio in 5.26s, no gaps, no device
      changes while warm). Its level was low: the loudest 100ms chunk was about -29 dBFS.
    - The rest of the path is correct. Clean synthesised speech sent through `SessionMachine`,
      `STTClient` and the real transport, paced and committed as `DictationController`
      does, with the seeded keyterms, came back word for word. Five seconds of digital
      silence came back empty, not as keyterms.
    - The endpoint guesses on faint audio. The probe's captures from the earbuds held
      distant speech from the room. The same capture sent twice came back as two different
      short phrases, the behaviour Aidan reports.
    - The first session after launch, or after three idle minutes, restarts the engine
      several times over its first few seconds on these earbuds. Each profile switch posts
      `AVAudioEngineConfigurationChange`, and `AudioCapture` reopens the device each time.
      That loses audio at the start of that session, but most failing sessions were warm
      ones with no restart, so it does not explain the pattern.
    Diagnosis, not yet confirmed: the app sends what the input device hears, correctly
    formatted, and what the Bluetooth earbuds hear of Aidan is too faint or poor for the
    endpoint, which then returns the keyterm prompt or a guess. Only Aidan's own audio can
    confirm it. The alternative, a capture defect that only shows with his voice, is what
    the playback rules in or out.
  - T3, the correction: a temporary diagnostic, `Sources/EchoTypeApp/Diagnostic.swift`, with
    hooks in `DictationController.swift` and in `AudioCapture.swift`. The `AudioCapture`
    hooks are a correction to workstream 2's work, as the plan allows during G1: they only
    record the tap format when the device opens or delivery starts, and each configuration
    change. No behaviour changes. Each session overwrites
    `/tmp/echotype-last-session.wav` with the bytes sent to xAI and
    `/tmp/echotype-last-session.txt` with the input device name, formats, device changes and
    audio seconds. The instructions add an A/B run against the MacBook Pro Microphone. T3
    must be deleted before acceptance: the file and every line marked `TEMPORARY, G1
    troubleshooting T3`. `swift build` clean; `timeout 180 swift test --disable-xctest` 35
    passing, no test process left running. The probe and every recording the lead made were
    deleted.
  - Candidate 3 published 2026-09-23; awaiting Aidan.
  - Aidan's answer on candidate 3: G1 passed every observation on the MacBook Pro
    Microphone. The Bluetooth earbuds were the cause of the wrong transcripts, as diagnosed;
    no capture defect. Product decision, approved drift from the specification's "hold it
    through a few minutes of idle" and workstream 2's 3-minute idle release: the microphone
    is released as soon as a session ends, so the orange macOS indicator clears with it.
  - T4, the correction: a correction to workstream 2's `AudioCapture`, as the plan allows
    during G1. `stop()` ends delivery and closes the device; the idle release
    (`idleRelease`, `releaseTask`, `scheduleRelease()`) is deleted, and `acquire()` is now
    the private `openDevice()`, called only by `start()` and the mid-session reopen. No
    delay before closing: `stop()` already ends the `Chunker` under its lock before
    anything else, so the flushed tail is all that would have been sent either way, and a
    delay would only keep a quick second dictation warm. The mid-session reopen now closes
    the device again if the session ended while it was reopening, which the idle release
    used to cover. Every session pays the 100 to 300ms device open. T3 removed: the
    diagnostic file and every hook. `swift build` clean, no warnings; `timeout 120 swift
    test --disable-xctest` 35 passing, no test process left running.
  - T4 review, run because T4 changes approved behaviour on the audio path: a fresh
    independent review (the G1 correction T4 subsections of the Independent review,
    Resolution and Closure review below). No code defect; the no-delay reasoning held. Three
    documentation findings were fixed and closed. Candidate 4 published 2026-09-24.
  - Aidan's answer on candidate 4 (2026-09-24): no clipping, on a cold start or back to
    back; the orange microphone indicator clears when a session ends, after both Opt+D and
    Escape. G1 passes; accept workstream 3. With candidate 3's answer, all eight
    observations have passed, on the MacBook Pro Microphone. No release delay is needed.
  - Specification change, approved by Aidan with this answer: the Audio section of
    `docs/specs/echotype-v1.md` now releases the microphone when each session ends,
    matching T4, and the Overlay section gains a starting state, shown between Opt+D and
    audio flowing. The starting state belongs to the overlay milestone; workstream 3 does
    not implement it.
- Resume condition: met. Candidate 4 passed all three checks.

The candidate is the uncommitted branch state. The instructions Aidan receives must
include the exact `security add-generic-password` command to seed the API key, the
`./scripts/run.sh` invocation, and the seven observations listed under G1 in
[plan.md](plan.md). If a grant misbehaves, `tccutil reset All com.aidanzealley.echotype`
is the verified escape hatch.

## Implementation handoff

- Base commit: `8a820c3`
- Outcome: Done, to the compile-and-review bar. Opt+D opens a session, Opt+D again commits
  it, Escape cancels it, and the outcome is inserted or reported in the menu. Whether any of
  it works on a real voice is gate G1.
- Files changed:
  - `Sources/EchoTypeCore/Settings.swift`: `Settings.Hotkey.matches(keyCode:modifiers:)`,
    true only for the same key with exactly the configured modifiers.
  - `Tests/EchoTypeCoreTests/HotkeyTests.swift`: new. The predicate matches its own chord
    (Opt+D, and Ctrl+Opt+D as a configured preset) and rejects Cmd+Opt+D, Ctrl+Opt+D,
    Shift+Opt+D, bare D and Opt+E against Opt+D.
  - `Sources/EchoTypeApp/HotkeyMonitor.swift`: rewritten as `@MainActor final class
    HotkeyMonitor`, taking a `Settings.Hotkey`, an `onHotkey` closure and an `onEscape`
    closure that returns whether a session took the press. The tap reaches the instance
    through `userInfo`, so there is no file-scope state. The `CGEventFlags` to
    `ModifierFlags` mapping lives here. The `tapDisabledByTimeout` and
    `tapDisabledByUserInput` re-enable, the Accessibility prompt and the one-second install
    retry are unchanged.
  - `Sources/EchoTypeApp/Keychain.swift`: new. `Keychain.apiKey()` reads the
    `kSecClassGenericPassword` item for service `com.aidanzealley.echotype`, any account,
    and returns `nil` if there is none. No write path.
  - `Sources/EchoTypeApp/DictationController.swift`: new. The session lifecycle, the
    outcome handling and the wording of every error the menu shows.
  - `Sources/EchoTypeApp/Inserter.swift`: now a class holding the pending restore. The
    insertion sequence and the `changeCount == before + 1` rule are unchanged.
  - `Sources/EchoTypeApp/App.swift`: `MenuBarExtra` with a state-dependent icon, a state
    line and Quit.
- Decisions:
  - **Keychain account.** The reader matches on service alone, so the account name does not
    matter. The command below uses `xai`; the settings milestone should write the same.
  - **Seed command.** Run `./scripts/run.sh` once first so the bundle exists, then from the
    repository root:

    ```bash
    security add-generic-password -U -s com.aidanzealley.echotype -a xai \
      -T "$PWD/.build/EchoType.app" -w
    ```

    `-w` last makes `security` prompt for the key, so it stays out of shell history. `-T`
    adds the app to the item's access list. The bundle's designated requirement is
    `identifier "com.aidanzealley.echotype" and certificate leaf = H"38709d06..."`, with no
    hash of the binary, so the entry should survive rebuilds. If macOS still asks whether
    EchoType may use the item, choose Always Allow. The key is read on each Opt+D, so
    seeding it needs no relaunch.
  - **The key is read off the main actor.** A Keychain access prompt blocks the calling
    thread, and blocking the main thread would stall the tap until the system disabled it.
  - **Microphone before socket.** The controller calls `AudioCapture.start()`, then reads
    the key (calling `stop()` if there is none), then opens the transport and starts the
    `SessionMachine`. The key read came first until G1 troubleshooting correction T1. The
    packet lists the socket first. Reversing it means a denied or missing microphone never
    opens a billed socket, and the workstream 2 contract (every stream `start()` returns is
    ended by `stop()`, including a session that ended while `start()` was awaiting) cannot
    be broken, because no session exists until `start()` has returned. The cost: while
    `start()` is awaiting (at most 300ms, or the first-use permission prompt), further Opt+D
    presses are ignored and Escape passes through.
  - **Audio is pumped only once the session is listening.** `send(audio:)` drops audio
    before `run()` has begun, so the pump starts on the first state from `states`, which is
    always `listening`. Chunks captured before that wait in the stream. `STTClient` already
    holds audio until `transcript.created`.
  - **Opt+D commits by ending capture, not by calling `trigger()`.** The press calls
    `audio.stop()`. The pump sends every chunk still in the stream, including the partial
    last chunk `stop()` flushes, and then calls `trigger()` itself, so the last word goes out
    before `audio.done`. The pump ignores a failed `send` and keeps draining, because the
    session reports the socket failure itself. So the pump only ends when the stream does,
    and always triggers. There is no direct `trigger()` path for a pump that has already
    exited, because that case no longer exists. A send hung on a dead socket would also hold
    up a direct `trigger()`, since `STTClient.finish()` queues behind it. `run()` still calls
    `stop()` when the session ends, which covers cancel, silence, the hard cap and failures.
    After a commit press that is a second `stop()`, which does nothing.
  - **A thrown audio stream is treated as a failed session** without changing
    `SessionMachine`: the pump calls `trigger()`, whatever was transcribed is inserted, and
    the menu shows the microphone error.
  - **Escape matches on keycode 53 alone**, with any modifiers, and is consumed only while a
    session is running.
  - **The restore's identity is the `changeCount` from before its write.** A new insertion
    that finds the previous transcript still on the pasteboard (`changeCount == before + 1`
    of the pending restore) inherits that restore's saved contents instead of snapshotting
    the transcript, and the old restore sees it has been superseded and does nothing. If
    something else wrote in between, the new insertion snapshots that as usual. An empty
    saved pasteboard is carried forward the same way and never written back, so the last
    transcript stays on the pasteboard.
  - **The microphone is released when each session ends** (G1 correction T4, Aidan at gate
    G1). `AudioCapture.stop()` ends delivery and closes the device, with no release delay;
    the idle release is gone. G1 showed no first-word clipping on a cold start or back to
    back, and the orange indicator clears after both Opt+D and Escape. The specification's
    Audio section now says the same, and its Overlay section gains a starting state for the
    overlay milestone to show between Opt+D and audio flowing.
  - **Bluetooth earbud input is a known limitation, not a defect.** G1 traced the wrong
    transcripts to faint headset-profile audio; the app keeps following the system default
    input. Device choice or a warning belongs with the settings milestone.
  - **Menu state line.** `Listening`, `Paused`, `Finishing` or `Cancelled` while a session
    runs; otherwise the last problem, or `Ready`. The problem clears when the next session
    starts. `STTError.badRequest` and `.unauthorized` both read "xAI rejected the API key",
    per workstream 1's finding. Icon: `waveform` idle, `waveform.circle.fill` while a
    session runs.
- Verification:
  - `swift build`: clean, no warnings.
  - `timeout 180 swift test --disable-xctest`: 35 tests passing (33 before, plus the two
    predicate tests), exit 0. No test process left running.
  - `./scripts/run.sh` was not run: it launches the app, which triggers the Accessibility
    prompt, and G1 is the lead's gate. The same bundle steps were run into a temporary
    directory instead (copy binary and plist, `codesign --sign "EchoType Dev"`), which
    signed cleanly with the designated requirement quoted above. Nothing was launched.
  - `swift-format` is not installed, so lint was skipped. No line in the changed files
    exceeds 100 columns.
  - No test for the tap, the pasteboard or the Keychain, per the packet.
- Known limitations or external checks:
  - Everything except the predicate rests on G1, which passed on candidates 3 and 4: the
    tap consuming Opt+D and Escape, the Keychain read, the menu updating, insertion, the
    pasteboard restore across two quick dictations, and first- and last-word clipping.
  - Every session pays the 100 to 300ms device open before audio flows, since the device is
    released when each session ends (G1 correction T4). G1 on candidate 4 showed no
    first-word clipping on a cold start or back to back on the MacBook Pro Microphone; a
    slower device could still clip, which the overlay's starting state is meant to make
    visible.
  - On Bluetooth earbuds every session, not just the first after launch, now opens the
    device, so the engine may restart several times during the profile switch and the
    session loses its opening seconds. Bluetooth input is already a known limitation for
    this milestone.
  - A missing key is reported when Opt+D is pressed, not at launch.
  - If a send hangs on a dead socket that the message loop has not yet noticed, Opt+D does
    not commit until the send is released. The session then ends when the loop notices, or
    by the silence rules or the hard cap.
- Specification drift: the menu's state line carries session failures and "no API key",
  which the specification gives to the overlay and the settings window. It is the only
  place the user can see anything in this milestone. The error wording treats a 400 as a
  key problem, following workstream 1's recorded drift. Releasing the microphone when each
  session ends departed from the specification's warm idle hold; Aidan approved it at G1
  and the specification now says it, with an overlay starting state to cover the open.

## Independent review

- Reviewer: independent review agent, against the uncommitted diff on `8a820c3`.
- Verdict: Changes requested. One required finding. It is small, and the rest of the
  workstream is sound.
- Checks run: `swift build` after touching every changed file: clean, no warnings.
  `timeout 180 swift test --disable-xctest`: 35 tests passing. No test process was left
  running afterwards. `swift-format` is not installed, so lint was skipped; no changed line
  exceeds 100 columns. The app was not launched.
- Required findings:
  - **R1. Opt+D throws away the end of the dictation, including the tail that
    `AudioCapture.stop()` exists to flush.** On a press with a session running,
    `hotkeyPressed` calls `session.trigger()` directly
    (`Sources/EchoTypeApp/DictationController.swift:47-48`). `trigger()` moves the session
    to `finalizing` before it awaits anything
    (`Sources/EchoTypeCore/SessionMachine.swift`, `beginFinalizing`), and from then on
    `send(audio:)` returns without sending because `isActive` is false. Three kinds of audio
    get dropped. The first is chunks already yielded but not yet pulled by the pump, which
    can back up behind a slow socket send (`STTClient.sendInOrder`). The second is the
    partial chunk, up to 100ms, still in `Chunker.pending`. The third is anything the tap
    delivers before the session ends. `audio.stop()` does not run until the session has
    concluded (`DictationController.swift:101-103`), so its flush, which workstream 2's
    handoff describes as "so the tail of the final word is not lost", always lands on a
    session that no longer accepts audio. The user presses Opt+D as they finish speaking,
    so this cuts the last word on the normal path. Gate G1 asks about first-word clipping,
    not the last word, so the gate is unlikely to catch it. A fix that stays inside this
    workstream: on the commit press, call `audio.stop()`. The pump then drains what is
    buffered and what `stop()` flushed into the still-listening session, and calls
    `trigger()` itself when the stream finishes normally. `run()` can then drop its own
    `stop()` or keep it, since a second `stop()` is harmless. There is a catch. If the pump
    has already returned on a failed send (line 113), a press must still end the session, so
    keep a direct `trigger()` for that case, or have the pump keep draining instead of
    returning.
- Optional observations:
  - **O1. Reading the Keychain before starting delivery puts it in the first-word path.**
    `dictate()` awaits `Keychain.apiKey()` on a detached task (line 64) before
    `audio.start()` (line 72). With a warm device, nothing is delivered until the key read
    and two executor hops finish, and `Chunker` discards what it hears before `begin`.
    `SecItemCopyMatching` against the file keychain is an IPC to `securityd`, usually a few
    to tens of milliseconds. That is probably too small to hear, but first-word clipping is
    one of the things G1 has to report. If G1 shows clipping, start audio first and read the
    key after it, calling `stop()` if the key is missing. That keeps both the
    microphone-before-socket order and workstream 2's `start()`/`stop()` contract.
  - **O2. A denied or failed Keychain read shows as "No xAI API key in the Keychain".**
    `Keychain.apiKey()` returns `nil` for any status other than `errSecSuccess`
    (`Sources/EchoTypeApp/Keychain.swift:19`). That includes `errSecAuthFailed` or
    `errSecUserCanceled` when Aidan clicks Deny on the access prompt, so the menu would
    tell him to seed a key he has already seeded. Mapping `errSecItemNotFound` to "no key"
    and everything else to "Keychain access failed" would fix it, if the lead thinks G1 can
    reach that path.
  - **O3. Escape is consumed, and does nothing, in two gaps where `phase` is `.running` but
    the session is not cancellable.** The first gap is before `run()` has entered
    `listening`, from `DictationController.swift:81` until the `run()` task has started. The
    second is during `finalizing`, which lasts up to the 8 second `finalizeTimeout`. In both,
    `cancel()` is a guarded no-op (`SessionMachine.isActive`). The first gap is
    microseconds. The second matches the specification's state diagram, where Escape leaves
    only `listening` and `paused`, and a session in `finalizing` is still open, so this is
    consistent with "consumed only while a session is open". Noted for completeness; no
    change recommended.
- Questions:
  - **Q1. Does the published seed command really survive rebuilds without a prompt?** The
    command in the handoff is correct as a command. `-U` updates in place. `-w` last makes
    `security` prompt for the secret. `-T` adds the bundle at the path `scripts/run.sh`
    rebuilds (`app=.build/EchoType.app`). The query in `Keychain.swift` does not set
    `kSecUseDataProtectionKeychain`, so it searches the same file-based login keychain
    `security` writes to. The claim that it "should survive rebuilds" rests only on the
    legacy ACL's designated requirement, which has no cdhash. Since macOS 10.12, the
    keychain also checks the item's partition list. An item created by `security` carries
    Apple's tool partitions, and an app signed by a self-signed identity with no Team ID
    may not match them. So the first read after each `./scripts/run.sh` may still prompt,
    possibly for the login keychain password. I could not verify this without writing to
    Aidan's keychain, which I did not do. Recommendation: in the G1 instructions, word
    "survives rebuilds" as something to observe rather than a promise. Tell Aidan that
    Always Allow is the expected answer to a prompt. If it re-prompts on every rebuild, the
    fix to try is `security set-generic-password-partition-list`, and the settings
    milestone needs to know about it either way.
  - **Q2. Is "says so in the menu" at launch required by criterion 5?** A missing key is
    only reported after an Opt+D press (line 65). Until then the menu reads "Ready". The
    handoff records this as a limitation. Reading the Keychain at launch would report it
    earlier, but it could raise the access prompt at launch too. The press-time behaviour
    looks right to me, and I read it as meeting the criterion, but the lead should decide.
- Points the lead asked about, judged sound:
  - **Microphone before socket, with Opt+D ignored and Escape passed through while
    `.starting`.** Agreed. It keeps a denied or pending microphone prompt from opening a
    billed socket. It also makes workstream 2's "stop after a late start" case impossible:
    nothing can end a session before `start()` returns, and there is no suspension point
    between a successful `start()` (line 72) and `phase = .running` (line 81). The cost
    is a swallowed second press or a passed-through Escape during a cold open of 100 to
    300ms, or while the first-use prompt is up. That is acceptable, and the silence rule
    cancels a session nobody wanted after ten seconds.
  - **`start()`/`stop()` pairing.** Every successful `start()` reaches `audio.stop()` at
    line 103. `run()` always returns once `states` finishes, and `conclude` always finishes
    it. A `start()` that throws has not called `Chunker.begin`, so it has nothing to end.
    The pump ends when `stop()` finishes the stream, and a send suspended on a dead
    socket is released by `conclude` closing the transport before `await pump?.value`.
  - **Inserter supersede and the empty pasteboard.** Traced through. A second insertion
    that finds the first transcript still on the pasteboard (`changeCount ==
    pending.before + 1`) inherits the first insertion's saved items. The first restore then
    sees `pending.before != before` and returns (`Inserter.swift:35,41`). If something else
    wrote in between, the second insertion snapshots that as the user's contents, which
    matches the specification's rule. Saved items are copies, and each is written at most
    once, which respects `NSPasteboardItem`'s single-write constraint. An empty saved
    array is carried forward and never written (line 47), as the packet asks. The
    `changeCount` rule itself is unchanged.
  - **Isolation.** The tap's run-loop source is on the main run loop, so
    `MainActor.assumeIsolated` in the callback (`HotkeyMonitor.swift:54`) holds.
    `handle` does only a comparison and schedules a `Task`, so it stays well inside the
    tap timeout. The unretained `userInfo` pointer is safe because the controller, and so
    the monitor, lives for the whole process. `Keychain` is nonisolated (the package sets
    no default isolation), so the detached read really does run off the main actor.
    Blocking one cooperative-pool thread while an access prompt is up is acceptable for
    one call. The `tapDisabledByTimeout`/`tapDisabledByUserInput` re-enable is kept exactly.
  - **Tests.** `HotkeyTests.swift` tests only the pure `Settings.Hotkey.matches` decision
    in `EchoTypeCore`, including the Cmd+Opt+D and Ctrl+Opt+D cases criterion 3 names. It
    uses no fake and asserts no implementation detail, so it is the right size. No test
    doubles for the tap, the pasteboard or the Keychain were added.
  - **Scope.** No overlay, settings window, level meter, Keychain write, or change to
    `SessionMachine`, the transport or `Package.swift`. `AudioCapture.swift` is untouched.

### G1 correction T4 review

- Reviewer: fresh independent review agent, against `git diff
  Sources/EchoTypeApp/AudioCapture.swift` on `8a820c3` and its caller
  `DictationController.swift`. Aidan's release-on-end decision is treated as approved.
- Verdict: Accepted, with one documentation finding for the lead before the commit. The code
  is correct; the no-delay choice holds.
- Checks run: `swift build` after touching both files: clean, no warnings. `timeout 120
  swift test --disable-xctest`: 35 passing. `pgrep -fl swiftpm-testing-helper` empty
  afterwards. No line in `AudioCapture.swift` exceeds 100 columns. `swift-format` is not
  installed. The app was not launched.
- Required:
  - **T4-R1. The release-on-end drift is not in the plan's decision and drift log.** E1's
    decision says "record it as drift approved by Aidan", and the README gives drift one
    home, that log. It is recorded only in this file's attempt list. The log's workstream 2
    row still describes a warm idle device held under "the spec's hold through a few
    minutes of idle", which is now false. Add a row (Aidan, 2026-09-23, affects 2 and 3)
    and mark the workstream 2 row superseded. Docs only.
- Optional:
  - **T4-O1. Bluetooth earbuds now lose the start of every session, not just the first.**
    Attempt 3 found that opening "Between 3ANC" restarts the engine several times over the
    first few seconds (the HFP switch), which is why the first session after launch or idle
    lost its opening. With the device opened per session, every session is that session.
    Bluetooth input is already a recorded known limitation, so this is not a defect, but
    the handoff's limitations line should name it so no one rediagnoses it.
  - **T4-O2. `stop()`'s comment slightly overclaims.** "closing the device cannot cut off
    the tail" is true of closing, but whatever the tap has not yet been handed when
    `Chunker.end()` runs (up to one tap buffer, about 100ms) is dropped by `end()`. That was
    equally true of the warm design, and G1 heard no last-word clipping, so it is wording,
    not behaviour.
- Question: none.
- Points checked and judged sound:
  - **No delay is right.** Tail loss is decided by when `Chunker.end()` runs, which is the
    first thing `stop()` does in both designs. Closing the device afterwards cannot drop
    anything that would have been sent, so a delay before `closeDevice()` would not prevent
    last-word clipping; it would only keep a quick second session warm, which is what
    Aidan asked to lose. If G1 reports tail clipping, the fix is delaying `end()`, not the
    close.
  - **Start/stop pairing.** Denied access and `noInputDevice` throw before `begin` and
    before an engine is stored; `engine.start()` failure removes its tap. The missing-key
    path calls `stop()`, which ends an empty session and closes the device. Every session
    reaches `run()`'s `audio.stop()`. A commit press followed by that call, or extra presses
    during `finalizing`, are no-ops: `end()` finds no continuation and `closeDevice()` finds
    no engine. A mid-session conversion failure leaves the engine open with no delivery
    until `run()`'s `stop()` closes it.
  - **Mid-session reopen against `stop()` and a following `start()`.** The only suspension
    in `openDevice()` is `requestAccess`; everything after the second `engine == nil` guard,
    and from `openDevice()` returning to `chunker.begin`, is synchronous on the main actor.
    Reopen resumes after `stop()`: it opens, sees no delivery and closes. Reopen and a new
    `start()` both waiting: whichever resumes first opens; if it is the reopen, it closes
    again and `start()`'s second guard reopens; if it is `start()`, the reopen's guard
    returns and delivery is live, so it leaves the device open. A reopen failure after
    `stop()` ends an empty `Chunker`, so no stale error reaches the next session.
  - **Back-to-back sessions.** A second Opt+D is only acted on once `phase` is `.idle`, after
    the first session's outcome and `stop()`. It then pays a cold open while `.starting`
    ignores presses. Correct; whether the open clips the first word needs Aidan's recheck,
    as the handoff says.
  - **T3 is gone.** No `Diagnostic.swift`, no `TEMPORARY` marker, no
    `echotype-last-session` path in Sources, Tests or scripts. No trace of `idleRelease`,
    `releaseTask`, `scheduleRelease` or `acquire` remains in Sources. The class and method
    comments and `run()`'s "releases the microphone" match the new behaviour.

## Resolution

- Finding dispositions:
  - R1 accepted. Confirmed by reading: `trigger()` sends `finalize` and `audio.done`, so any
    chunk after it is dropped or arrives too late. Fixed in the remediation pass; the
    lead's suggested direct `trigger()` fallback was rightly dropped because the pump now
    has a single exit that always triggers.
  - O1 rejected at first, then applied as G1 troubleshooting correction T1, for a different
    reason: with the key read first, a missing key stopped the first Opt+D before the
    Microphone prompt, which is how G1 attempt 1 failed.
  - O2 rejected. Distinguishing a denied Keychain prompt from a missing item belongs with
    the settings milestone's key editor; "Always Allow" is in the G1 instructions.
  - O3 rejected, as the reviewer recommended: it follows the specification's state diagram.
  - Q1 accepted as an instruction change, not a code change. The G1 instructions tell Aidan
    to expect a possible Keychain prompt after a rebuild, to choose Always Allow, and give
    the partition-list fallback.
  - Q2 answered: reporting a missing key on the first Opt+D press meets criterion 5. The app
    stays running and the menu says so at the moment it matters.
- Simplification/deletion pass: R1 was fixed by changing what the commit press does, not by
  adding a path next to it. The press now calls `audio.stop()` in place of `trigger()`. The
  pump's early return on a failed send and its separate trigger for a microphone failure
  are gone; the pump now has one exit, which always triggers. That made the lead's
  suggested direct `trigger()`, for a pump that had already exited, unnecessary, so it was
  not added. No flag, wrapper or new state was added. `SessionMachine`, the transport,
  `AudioCapture` and `Package.swift` are unchanged. A second `stop()` is safe: once the
  stream has ended, `Chunker.end()` finds no continuation and nothing pending, and
  `scheduleRelease()` only re-arms the idle timer.
- Final verification: `swift build`: clean, no warnings. `timeout 180 swift test
  --disable-xctest`: 35 tests passing, exit 0. No test process was left running,
  `swiftpm-testing-helper` included. No changed line exceeds 100 columns. `swift-format` is
  not installed. The app was not launched. The last-word fix depends on real audio, so it
  still has to be confirmed at G1.

### G1 correction T4 resolution

- Why a review: T4 changes approved behaviour on the audio path, so the lead ran a fresh
  independent review, one remediation pass and a fresh closure rather than folding it into
  the troubleshooting loop. The code change itself was recovered from the interrupted lead
  intact: the diff matched its T4 record, built clean and passed 35 tests.
- T4-R1 accepted and fixed by the lead: the release-on-end drift and the Bluetooth known
  limitation are in the plan's decision and drift log as approved by Aidan, and the
  workstream 2 idle-release row is marked superseded.
- T4-O1 accepted: the handoff's limitations say every Bluetooth session now loses its
  opening seconds to the profile switch.
- T4-O2 accepted: the comment in `stop()` no longer claims nothing is lost at the tail.
- No delay before closing, confirmed: the tail ends at `Chunker.end()` in both designs, so
  a delay would only keep a quick second session warm. G1 on candidate 4 confirmed it: no
  clipping back to back, so the one-second release Aidan allowed was not needed.
- Terminal decision: Accepted. G1 passed on candidate 4, T4 is closed, and Aidan's
  specification change is in this commit. `swift build` clean; `timeout 120 swift test
  --disable-xctest` 35 passing, no test process left running.

## Closure review

- Verdict: Accepted for gate G1. R1 is fixed, and the fix introduces no release-blocking
  defect.
- Remaining required findings: none.
- Evidence:
  - **R1 fixed.** The commit press now calls only `audio.stop()`
    (`DictationController.swift:47-51`), and the only `trigger()` in the app is the pump's
    single exit (line 131). `Chunker.end()` yields the partial chunk and then finishes the
    stream under the same lock the tap uses, so every chunk captured before the press is
    buffered in the stream ahead of its end. The pump sends each chunk in order while the
    session is still `listening`, then triggers, so `finalize` and `audio.done` go out
    after the last audio. A press that lands before the pump exists (between `phase =
    .running` and the first `listening` state) is safe too: the finished stream keeps its
    buffered chunks, and the pump drains them once it starts.
  - **`start()`/`stop()` pairing holds.** Nothing between a successful `start()` (line 75)
    and `run()` can return early, and `run()` always calls `audio.stop()` at line 108 once
    `states` finishes, which `conclude` guarantees. A commit press followed by that call
    is a second `end()` on an empty `Chunker`, which does nothing. A microphone failure
    finishes the stream by throwing; the pump records it and triggers, and the later
    `stop()` does nothing.
  - **No new hang.** After a commit press on a dead socket, a pump suspended in `send` is
    released when the message loop notices and `conclude` closes the transport. The rest
    of the sends return at once on `isActive`, and `trigger()` does nothing. Escape while
    the pump drains still cancels normally.
  - `SessionMachine`, `AudioCapture` and `Package.swift` are unchanged from `8a820c3`.
  - `swift build`: clean. `timeout 180 swift test --disable-xctest`: 35 tests passing. No
    test process was left running, `swiftpm-testing-helper` included.
  - Whether the last word actually arrives needs real audio. G1 should check it alongside
    first-word clipping.

### G1 correction T4 closure

- Verdict: Accepted. T4-R1, T4-O1 and T4-O2 are fixed, and the fixes introduce no
  release-blocking defect.
- Remaining required findings: none.
- Evidence:
  - **T4-R1 fixed.** `plan.md`'s decision and drift log has a release-on-end row approved by
    Aidan at gate G1, affecting workstream 3 and the later overlay and settings milestones,
    and a Bluetooth known-limitation row. The workstream 2 idle row now opens with
    "Superseded by the release-on-end row below." The row is dated 2026-09-24 while E1
    records the decision on 2026-09-23; this does not affect any decision.
  - **T4-O1 fixed.** The handoff's Known limitations names that on Bluetooth earbuds every
    session opens the device and loses its opening seconds.
  - **T4-O2 fixed.** `AudioCapture.stop()`'s comment now says closing loses nothing that
    would have been sent, and that audio the tap has not yet received when delivery ends
    (up to one tap buffer, about 100ms) is not sent. The code is unchanged: `chunker.end()`,
    then `closeDevice()`.
  - `swift build`: clean. `timeout 120 swift test --disable-xctest`: 35 tests passing, exit
    0. `pgrep -fl swiftpm-testing-helper` empty afterwards. The app was not launched.
