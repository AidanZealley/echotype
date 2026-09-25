# Workstream 2: Input device, key test and system status

Status: accepted.

## Task packet

### Outcome

The settings window also picks the input device, tests the whole dictation path with one
click, shows whether each permission is granted with a button to fix it, and turns
launch at login on and off. Dictation uses the chosen device when it is connected and
the system default otherwise.

### Scope

**Listing inputs.** List the connected input devices through Core Audio, each with its
UID and name. The UID is what `Settings.inputDeviceID` stores; `nil` means follow the
system default. Refresh the list when the window appears. Nothing here runs in the event
tap's path.

**Using the chosen device.** `AudioCapture.start` takes the device UID for the session.
It opens that device when it is connected and the system default otherwise. The reopen
after a configuration change resolves the UID again. Setting the device on the input
node's audio unit before the engine starts (`auAudioUnit.setDeviceID`) is a suggestion.
Update `AudioCapture`'s comments, which say it follows the default by never choosing a
device. The controller passes the UID from the settings it read at the session's start.

**The picker.** An input row with System default followed by each connected input. A
stored device that is not connected stays selected and shows as not connected, so
unplugging it never silently resets the choice.

**The Test button.** Beside the API key. It saves the key in the field first, so it
tests the key the user sees. Then it runs a real streaming session through
`DictationController`, with the settings and the device a dictation would use, for five
seconds, then commits it the way Opt+D does. The outcome shows inline under the button:

- the transcript, for `insert`
- that nothing was heard, for `nothing`
- the error, worded by the controller's existing `describe(_:)`, for `failed` and for a
  start failure

A test never inserts and never shows the pill. The button shows that a test is running
and is disabled while one runs or while a dictation runs. Opt+D does nothing while a test
runs. The test and a dictation share one start sequence (microphone, key, socket) in the
controller rather than two copies of it.

**Permission rows.** One row each for Microphone and for Device Control and Data Access,
showing granted or not. Read the first with `AVCaptureDevice.authorizationStatus(for:)`
and the second with `AXIsProcessTrusted()`, which is still the check on macOS 27.2 (see
[0001](../../decisions/0001-build-and-sign-on-the-mac.md)). Refresh when the window
appears and when the app becomes active, so returning from System Settings updates them.
Each row's button opens its pane:
`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone` and
`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. Whether
the second lands on the Device Control and Data Access pane is checked at G2.

**Launch at login.** A toggle over `SMAppService.mainApp`. It reads the service's status
when the window appears rather than storing anything. Turning it on registers, and
turning it off unregisters. A failure shows inline. When the status is
`requiresApproval`, say so and offer `SMAppService.openSystemSettingsLoginItems()`.

**The specification's error list.** In `docs/specs/echotype-v1.md`, change the errors
line's "401 bad key" to say that a wrong key is a 400 and a 401 means no credentials were
sent, as recorded in [0006](../../decisions/0006-api-key-and-error-surface.md). Change
nothing else in the specification.

**The gap list.** In `docs/decisions/0007-known-gaps.md`, rewrite the Bluetooth item to
say the input picker now lets the user choose another microphone, and that there is no
warning. Add an item for `install.sh` (build-order step 6): a login item registered from
`.build/EchoType.app` points at that path, so the installed app has to be registered
again from `/Applications`.

**Gate G2.** After focused closure, the lead fills in this record's External validation
section with the candidate and the exact steps from G2 in `plan.md`, adds escalation
entry E2 to `plan.md`, sets the row to `Blocked` and G2 to `Testing`, and returns.
Failures Aidan reports go through the troubleshooting loop in the README.

### Non-goals

- A warning about Bluetooth input.
- A level meter or live transcript in the settings window.
- The batch endpoint.
- Watching for devices connecting while the window is open, beyond refreshing when it
  appears.
- Requesting permissions from the rows. The first dictation or test raises the
  Microphone prompt, and launch raises the other.
- Changes to the overlay, `SessionMachine`, the settings encoding or the store's shape.
  A defect in a frozen contract is an escalation.
- `install.sh`.

### Initial ownership

- `Sources/EchoTypeApp/AudioCapture.swift`
- A new input device listing file in `Sources/EchoTypeApp/`
- `Sources/EchoTypeApp/DictationController.swift`, for the device and the Test run
- The settings views in `Sources/EchoTypeApp/Views/`, adding sections and rows only
- `docs/specs/echotype-v1.md`, the errors line only
- `docs/decisions/0007-known-gaps.md`
- Workstream 1's files, only for defects G2 finds, as the README allows

### Required seams

- Workstream 1's handoff: the settings store and its API, the `Keychain` API, and where
  the form's sections live.
- `AudioCapture.start()` and `stop()`, and the commit order in
  [0005](../../decisions/0005-microphone-per-session.md): stop capture first so the pump
  drains the tail before `trigger()`.
- `SessionMachine.Outcome` and the controller's `describe(_:)`.

### Acceptance criteria

1. Sessions and tests open the chosen input when it is connected and the system default
   otherwise, including after a device change mid-session.
2. The picker lists System default and the connected inputs, and keeps a disconnected
   choice visible as not connected.
3. Test saves the key, runs one five second streaming session and shows its outcome
   inline. It never inserts or shows the pill, and it cannot overlap a dictation in
   either direction.
4. The start sequence exists once in the controller.
5. Both permission rows show current status, refresh on return to the app, and open
   their panes.
6. The launch at login toggle reflects and changes `SMAppService.mainApp`, and shows
   failures and the approval state.
7. The specification's error line and the 0007 items are updated as above.
8. Gate G2 passed, with Aidan's evidence recorded below.

### Targeted verification

```bash
swift build
timeout 120 swift test --disable-xctest
xcrun swift-format lint --recursive Sources Tests Package.swift
```

This workstream adds no `EchoTypeCore` logic, so it adds no tests. It is verified by
reading and at G2.

## Implementation handoff

- Base commit: `fb37b13`
- Outcome: implemented, uncommitted. Criteria 1 to 7 are met by reading and wait on G2.
  Criterion 8 is G2 itself.
- Files changed:
  - `Sources/EchoTypeApp/InputDevice.swift` (new): `InputDevice.all()` lists devices with an
    input stream, each with its UID and name, for the picker. `InputDevice.connectedID(uid:)`
    resolves one UID to a connected input's Core Audio ID.
  - `Sources/EchoTypeApp/AudioCapture.swift`: `start(deviceUID:)`; comments rewritten.
  - `Sources/EchoTypeApp/DictationController.swift`: one private `start(_:)` shared by
    `dictate()` and the new `test()`, a `.testing` phase, `isIdle` and `TestOutcome`.
  - `Sources/EchoTypeApp/Views/SettingsView.swift`: Test button in the API key row, an Input
    row in the hotkey section, a Launch at login section and a permissions section.
  - `Sources/EchoTypeApp/App.swift`: passes the controller to `SettingsView`. The
    activation-policy pair is untouched.
  - `docs/specs/echotype-v1.md` (errors line), `docs/decisions/0007-known-gaps.md`.
- Decisions:
  - `AudioCapture` keeps the session's UID and, on every open including the reopen after
    a configuration change, resolves it with `InputDevice.connectedID(uid:)`
    (`kAudioHardwarePropertyTranslateUIDToDevice`, then an input-stream check) and calls
    `inputNode.auAudioUnit.setDeviceID` before reading the input format. A UID that is not
    connected keeps the default. A `setDeviceID` failure is `engineFailed`, not a silent
    fallback. The lookup is two Core Audio calls on the main actor, in the start path that
    already builds the engine there; the picker lists devices in a detached task.
  - `start(_:)` returns `.started(session, chunks)`, `.abandoned` or `.failed(message)`.
    `dictate()` puts that in the pill; `test()` returns it. Escape only abandons a
    `.starting` phase, so a test never sees `.abandoned`.
  - `test()` sets `.testing`, which the hotkey, Escape and pill clicks ignore (the hotkey
    is still consumed). It never calls `showStarting()`, so the pill stays nil and every
    pill update is a no-op, and it never calls `finish`, so nothing is inserted. After five
    seconds it calls `commit()` (stop capture, the pump then triggers). The timer is
    cancelled when the session ends, so it cannot commit a later dictation. The menu bar
    icon and status line do show the test as listening.
  - A microphone failure takes precedence over the outcome, as in `finish`; `.failed`
    shows its error, not its partial text.
  - The Test button saves the field, waits for the chained Keychain write, and skips the
    test if the save failed. It is disabled while its own test runs or while
    `controller.isIdle` is false. `test()` also returns nil if a dictation started in
    between.
  - A disconnected stored device shows as `<UID> (not connected)`: only the UID is stored.
  - Launch at login reads and writes `SMAppService.mainApp` in detached tasks. It rereads
    the status on appear and on `didBecomeActiveNotification`, so approving in Login Items
    shows on return. The toggle is disabled while a register or unregister is in flight. It
    is on for `.enabled` and `.requiresApproval`; the latter adds a line and an Open Login
    Items button.
  - Permission rows read `AVCaptureDevice.authorizationStatus(for: .audio)` and
    `AXIsProcessTrusted()` on appear and on `didBecomeActiveNotification`, once per trigger
    for the whole section; each has an Open button for its pane. In the overlay demo
    (`--hud-demo`), with no controller, there is no Test button.
- Verification: `swift build` clean, no warnings; `timeout 120 swift test
  --disable-xctest` 45 passing; `xcrun swift-format lint --recursive Sources Tests
  Package.swift` clean. No tests added, as the packet says.
- Known limitations or external checks:
  - Unverified until G2: that `setDeviceID` before start selects the input on macOS 27.2,
    that the input format read after it matches what the tap delivers, and that it does not
    cause a configuration-change loop; whether a change of system default while a chosen
    device is in use triggers a harmless reopen; the Accessibility URL landing on Device
    Control and Data Access.
  - The device list refreshes only when the window appears, and a stored device can show as
    not connected for a frame until the detached listing returns.
- Specification drift: none in the first implementation; the spec's errors line now
  matches 0006. The G2 corrections added the capture drift approved in E6, logged in
  [plan.md](plan.md).
- G2 correction 1 (AVCaptureSession):
  - Files changed: `Sources/EchoTypeApp/AudioCapture.swift` (capture rewritten on
    `AVCaptureSession`), `Sources/EchoTypeApp/InputDevice.swift` (Core Audio code replaced by
    an `AVCaptureDevice.DiscoverySession` listing), `Sources/EchoTypeApp/DictationController.swift`
    (one stale comment about tap buffers). `start(deviceUID:)`, `stop()`, `onLevel`,
    `Failure` and the chunk stream are unchanged, so nothing else changed. `SettingsView`'s
    picker is untouched: `InputDevice` keeps `uid` and `name` and `all()`.
  - Decisions:
    - Approved by Aidan at G2 (E6, 2026-09-25, by running G2 on this candidate): microphone
      capture is an input-only `AVCaptureSession`, not `AVAudioEngine`; the picker lists
      `AVCaptureDevice`s and `Settings.inputDeviceID` stores their unique ID; a session keeps
      the input it opened when the system default changes and reopens at most once if that
      input goes away; the meter measures the converted 16 kHz mono audio. Logged as drift in
      [plan.md](plan.md).
    - `AudioCapture` keeps the chunk contract and the stop-first commit order (0005).
      `stop()` ends delivery under the chunker's lock and then closes the device off the
      main actor, so the microphone is released moments after the call returns rather than
      inside it.
    - Each open is a `Microphone` actor owning one input-only `AVCaptureSession`. Its
      executor is its own `DispatchSerialQueue`, so `startRunning()` and `stopRunning()`,
      which block, never run on the main actor or in the shared pool, and the session (not
      `Sendable`) needs no `@unchecked`. The device is `AVCaptureDevice(uniqueID:)` when it
      exists and `isConnected`, else `AVCaptureDevice.default(for: .audio)`, else
      `noInputDevice`. An input init failure, a `canAddInput`/`canAddOutput` refusal, or a
      session not running after `startRunning()` is `engineFailed`, so no call in the open path
      can raise.
    - `AVCaptureAudioDataOutput` with no `audioSettings` (the device's native format) and the
      chunker as sample buffer delegate on its own serial queue. Each `CMSampleBuffer` is
      copied into an `AVAudioPCMBuffer` in the format it arrived in (from its stream
      description, plus its channel layout above two channels) and goes through the existing
      converter, which is remade when the format changes. A buffer that is not linear PCM or
      cannot be copied ends the stream with `engineFailed`, as a conversion failure did.
    - The level meter now measures the converted 16 kHz mono audio (what is sent), so it
      works for any device format. It reports on the first buffer of a delivery, which still
      marks audio flowing, and then once per 3,200-byte chunk, keeping the roughly 100ms
      cadence the pill's glow averages over. This departs from 0009's "loudest channel's RMS
      before conversion"; a mono downmix reads up to 6 dB lower than the loudest channel when
      only one of two channels carries the voice.
    - Mid-session loss: the actor observes `AVCaptureDevice.wasDisconnectedNotification` for
      the device and `AVCaptureSession.runtimeErrorNotification` for the session, because
      which one a disconnect posts on macOS is undocumented. The first report closes the
      device and, for a session in progress, reopens it, resolving the stored ID again;
      reports from a closed or replaced open are ignored. A failed reopen ends the stream with
      its error. A loss before any audio arrived since the last open ends the stream with
      `engineFailed` instead of reopening, so a failure that recurs on every open cannot
      loop. A change of system default is not followed.
    - The picker lists `AVCaptureDevice.DiscoverySession` with device types `.microphone` and
      `.external`, media type audio, storing `uniqueID` and showing `localizedName`, in a
      detached task when the window appears as before. `Settings.inputDeviceID`, its
      encoding and the store are unchanged.
    - Removed: the configuration-change observer, `setDeviceID`, the Core Audio UID lookup
      and listing, `import CoreAudio` and `import Accelerate`.
  - Relied on and unverified until G2: that `AVCaptureSession` capture on the Bluetooth
    earbuds keeps delivering across the headset profile switch (in the new format) without a
    runtime error; that a disconnect posts at least one of the two observed notifications;
    that `startRunning()` leaves `isRunning` false when it fails; that the capture's native
    format is linear PCM that `CMSampleBufferCopyPCMDataIntoAudioBufferList` copies; that
    `.microphone` and `.external` list every input the user expects, including Bluetooth;
    and that `AVCaptureDevice.uniqueID` equals the Core Audio UID, so a device stored by the
    previous candidate still resolves (if not, it shows as not connected until chosen again).
  - Verification: `swift build` clean, no warnings (full rebuild of the app target);
    `timeout 120 swift test --disable-xctest` 45 passing; `xcrun swift-format lint
    --recursive Sources Tests Package.swift` clean. Nothing run that opens the microphone.
  - Limitations: sample buffer size is the capture's choice, so the first level may arrive
    slightly later or earlier than a tap buffer did. The overlay demo's sample transcript in
    `Views/PillDemo.swift` still mentions "the AVAudioEngine tap"; it is demo copy in the
    overlay, which this correction does not touch. The specification's Audio section and
    architecture line still name `AVAudioEngine`, and 0009 pre-conversion metering; that
    drift is the lead's to record.

- G2 attempt 3 correction and E7:
  - Files changed: `Sources/EchoTypeApp/App.swift` (`SettingsButton` only),
    `docs/decisions/0007-known-gaps.md`.
  - Decisions:
    - After the deferred `activate()`, `SettingsButton` raises the settings window with
      `orderFrontRegardless()`, found as the app's only visible window that can become
      main, so a declined activation still leaves the window in front and a click focuses
      it. G2 attempt 3 passed with it; Aidan has not seen the window open behind since.
    - Approved by Aidan (E7, 2026-09-25, option A): keep the Dock icon and Cmd+Tab entry
      while the settings window is open, as E3 approved. While the window is open, the menu
      bar menu does not open from a fullscreen app, a known macOS limitation for status
      items of regular apps. Recorded in 0007 as a known gap, not fixed. Showing the Dock
      icon only while EchoType is frontmost (option B) was declined because it drops the
      Cmd+Tab entry. Aidan asked to draw a line under the window behaviour and raise it
      again only if it becomes a problem.

## Independent review

- Reviewer: fresh independent review agent, against `fb37b13` plus the uncommitted diff.
- Verdict: accept for closure and G2. No required findings. Checks rerun: `swift build`
  clean, `timeout 120 swift test --disable-xctest` 45 passing, `swift-format lint` clean.
  Criteria 1 to 7 hold by reading. Specific checks:
  - Hotkey after upgrade: the diff does not touch `Settings`, its coding or the store.
  - Main actor: Keychain reads and writes, `SMAppService` calls and the picker's listing
    run detached. The one Core Audio listing on the main actor is in `openDevice`, next to
    `engine.start()`, which already ran there (see O1).
  - Test versus dictation: `.testing` is set synchronously before the first await, and the
    hotkey is consumed and ignored, Escape passes through and pill clicks are ignored
    while it is set. The Test button is disabled on `!isIdle` (an observed `phase`), and
    `test()` rechecks. The five second timer only ever calls `audio.stop()`, is cancelled
    before `phase` returns to idle, and every hop is on the main actor, so it cannot
    commit a later dictation. The test never creates a pill, so `levelChanged` and
    `updatePill` do nothing, and it never calls `finish`, so it cannot insert. A settings
    change mid-session cannot reach it: the controller copies `settings` and
    `AudioCapture` keeps `deviceUID` from the session's start, including for the reopen.
  - `dictate()` behaves as before the refactor, including Escape while starting (both
    `end()` calls are guarded by `pill`) and `state = .idle` before the insert, which
    now happens in `run`.
  - `InputDevice`: `takeRetainedValue` is correct for the UID and name properties, which
    Core Audio returns retained. The input-stream check is the standard one.
  - No tests were added, as the packet says. None is missing, since nothing here is
    `EchoTypeCore` logic.
- Required findings: none.
- Optional observations:
  - O1. `openDevice` enumerates every device (streams, UID and name per device) on the
    main actor to resolve one UID, on each start and reopen with a chosen device.
    `kAudioHardwarePropertyTranslateUIDToDevice` resolves it in one call. The cost is small
    next to `engine.start()`, so this does not block acceptance.
  - O2. `LaunchAtLoginRow` reads its status only when it appears. After Open Login Items
    and approving there, the row still says "Allow EchoType in Login Items" until the
    window is reopened, although the permission rows next to it refresh on
    `didBecomeActiveNotification`. Refreshing it on that notification too would fix
    this. Separately, a second click while a register or unregister is in flight starts a
    second detached call, and the calls race. Disabling the toggle while one is pending
    would prevent that. This meets the packet as written, and G2 item 7 checks only after
    reopening.
  - O3. The permission rows' `onAppear` and `onReceive` sit on a `Group`, so each runs
    once per row (the handoff notes this). Moving them to the enclosing `Section` in
    `SettingsView` removes the duplicate and that caveat.
- Questions:
  - Q1. The handoff lists as unverified whether `setDeviceID` posts an
    `AVAudioEngineConfigurationChange` that arrives after the observer is registered. If
    it did, every reopen would set the device again and loop, with audio dropping out.
    G2 item 1 only catches this if the dictation with a non-default input lasts more than
    a few seconds. The lead could say so in the G2 instructions.
- G2 correction 1 review:
  - Reviewer: fresh independent review agent, against `fb37b13` plus the uncommitted diff,
    concentrating on `AudioCapture.swift`, `InputDevice.swift` and their callers.
  - Verdict: not ready for G2. R1 means no session would ever deliver audio. Checks rerun:
    `swift build` clean, `timeout 120 swift test --disable-xctest` 45 passing,
    `swift-format lint` clean. Nothing run that opens the microphone. Two throwaway
    programs in `/tmp` built synthetic `CMSampleBuffer`s and ran the handoff's copy and
    convert code on them.
  - Checked and sound:
    - Objective-C exceptions: none left in the open or delivery path by reading.
      `addInput` and `addOutput` are guarded by `canAdd…`, the delegate queue is serial, no
      `audioSettings` is set, there is no `beginConfiguration`, and the converter's input
      buffer always has the converter's input format, because the converter is remade on
      any format change. `AVAudioFormat(streamDescription:channelLayout:)` returns nil
      rather than raising for a missing or mismatched layout (tested).
    - Main actor: `startRunning` and `stopRunning` run on the `Microphone` actor's own
      queue, and the listing runs detached. Conversion under the chunker's lock is the same
      contention as before.
    - 0005: `stop()` still ends delivery under the lock and flushes the tail before the
      pump triggers. The chunk format and cadence are unchanged. On every path traced
      (normal stop, Escape while the open is in flight, a failed open, a start failure,
      stop during a reopen) the `Microphone` is closed. `close()` is queued behind `open()`
      on the same serial executor, so it can never run first and leave a session running.
    - Stored ID: the picker stores `AVCaptureDevice.uniqueID` and the open resolves
      `AVCaptureDevice(uniqueID:)`, so the two agree by construction.
    - Conversion: once R1 is fixed, Float32 non-interleaved 48 kHz stereo, Float32
      interleaved 44.1 kHz stereo, Int16 interleaved 48 kHz stereo and Int16 16 kHz mono all
      copy and convert. 24,000 input frames at 48 kHz gave 7,994 at 16 kHz, 16 kHz mono
      passed through exactly, and the converter was made once per format.
  - Required findings:
    - R1. Every sample buffer fails to copy, so every session ends at its first buffer
      with "Microphone failed: could not read audio (-12731)". A fresh `AVAudioPCMBuffer`
      has `frameLength` 0, and its `mutableAudioBufferList` reports `mDataByteSize` 0 even
      though the header says capacity. `CMSampleBufferCopyPCMDataIntoAudioBufferList` then
      returns `kCMSampleBufferError_RequiredParameterMissing` (-12731). This happened in the
      throwaway program for all four formats above, and every copy succeeded once
      `frameLength` was set to the frame count before the copy. Fix: in `pcmBuffer(from:)`,
      set `buffer.frameLength = AVAudioFrameCount(frames)` before
      `CMSampleBufferCopyPCMDataIntoAudioBufferList`, not after it.
    - R2. A reopen is not tied to the session it serves. `deviceLost`'s task decides with
      the global `chunker.isDelivering`, and its `openDevice()` always replaces
      `self.microphone`. Suppose a session ends while its reopen is in flight and the next
      dictation or Test starts before that reopen returns. If the new start has assigned
      its own `Microphone` but not yet called `chunker.begin`, the stale task's
      `if !chunker.isDelivering { closeDevice() }` closes the new session's microphone, and
      the new session runs silent. If the stale reopen fails after the new session began,
      `chunker.end(throwing:)` ends the new session's stream with the stale error. The old
      engine code had no await between the access check and assigning `engine`, so this
      window was only `requestAccess`. The actor hop makes it the whole device open, which on
      a Bluetooth headset includes the profile switch. The microphone is still released, so
      this is a wrong session outcome, not a leak. Fix: have the reopen act only if the
      delivery and the open it made are still current. For example, keep a delivery
      counter that `start` and `stop` increment, and compare `microphone === opened`
      before closing or ending.
  - Optional observations:
    - O1. The loop guard only covers a loss before any audio. A loss that recurs after the
      first buffers of every open would reopen about once per open for the rest of the
      session, which is the attempt 1 pattern again. At most one reopen per session bounds
      that for certain and still meets criterion 1 (fall back once to the default). It would
      also replace `heard`, which depends on a level hop to the main actor and, after a
      reopen, is only set once a whole chunk has accumulated. That is fewer concepts.
    - O2. The chunker is shared by every `Microphone` and closing is asynchronous. A previous
      open still stopping on its own queue can feed buffers into the next delivery, so two
      sources would interleave into one stream, if Opt+D or Test starts again before
      `stopRunning` returns. That is unlikely, because the next `startRunning` usually takes
      longer. It becomes impossible if R2's fix also has `openDevice` await the previous
      close (keep the close task) or gates `captureOutput` on the current output.
    - O3. An input with more than two channels fails every session with "unsupported
      audio" when its format description carries no channel layout. With a discrete layout
      the converter's downmix keeps only channel 0 (tested: a signal on channel 2 of 4 came
      out silent). This is rare for this app's users. Record it in 0007 rather than add
      handling.
    - O4. Leftovers: `Failure.engineFailed` now names a framework that is gone (it is in the
      user-facing path only through `describe`, whose wording is unchanged); the demo copy in
      `Views/PillDemo.swift`; the specification's lines 46, 317 and 375 naming
      `AVAudioEngine`; and 0005's "The app follows the system default input". Renaming the
      case is in scope. The documents are the lead's drift to record.
    - O5. A possible bold simplification that only G2 can confirm: set the output's
      `audioSettings` to 16 kHz mono Int16 interleaved linear PCM (a macOS-only property)
      and copy the block buffer's bytes straight into chunks. That would delete
      `pcmBuffer`, `channelLayout`, the converter and its remake-on-format-change, and O3
      with them, leaving the capture stack to resample across the profile switch. The risk:
      the header says settings the output cannot honour raise, so it has to be proven on the
      earbuds and the built-in microphone before it replaces working conversion code.
  - Questions:
    - Q1. Criterion 1 says "including after a device change mid-session", and 0005 says the
      app follows the system default. With System default chosen, a mid-session change of
      default (such as AirPods connecting) is no longer followed; the engine followed it.
      The handoff states this. The lead should decide whether it is accepted drift or a
      miss.
    - Q2. The meter now reads RMS after conversion to 16 kHz mono, not 0009's loudest
      channel before conversion. The reason holds: one measurement for every device format.
      It departs from an accepted decision, so it needs recording, and G2 should glance at
      the meter on a stereo input.
  - Behaviour the design depends on that only G2 can confirm: that capture on the earbuds
    keeps delivering across the HFP switch without a runtime error (if an error comes
    before any audio, the session ends with "Microphone failed", and if it comes after,
    see O1); which notification a disconnect posts, and that `object: device` matches the
    posting instance; that `startRunning` leaves `isRunning` false on failure; that the
    native format is linear PCM (after R1); that `.microphone` and `.external` list the
    earbuds and every other expected input, once each; that a Bluetooth `uniqueID` is
    stable across reconnects; and that stopping one session while another starts on the
    same device (back to back, or a reopen) is harmless.
  - Simplest design: yes in shape. An input-only capture session owned by an actor on its
    own queue is the direct replacement, and removing the configuration observer,
    `setDeviceID` and the Core Audio lookup is a real reduction. It becomes simpler still
    with O1, and possibly O5.

- G2 attempt 3 correction review:
  - Reviewer: fresh independent review agent, on the unreviewed attempt 3 change to
    `SettingsButton` in `App.swift`, after G2 passed.
  - Verdict: no required findings. Checks rerun: `swift build` clean,
    `timeout 120 swift test --disable-xctest` 45 passing, `swift-format lint` clean.
  - Checked and sound: the lookup cannot match a wrong window. The overlay `Panel`
    returns false from `canBecomeMain`, the menu-style `MenuBarExtra` and the status
    item's borderless window cannot become main, and the settings view opens no sheet,
    alert or popover. `orderFrontRegardless()` changes only window order, never key status
    or activation, and runs only from the user's Settings… click, so the overlay's
    never-take-focus rule holds. The activation-policy pair is unchanged.
  - Optional: `SettingsButton`'s doc comment still promised keyboard focus in every case,
    while a declined activation now leaves the window in front and focused by a click.
  - Question: whether the window is always visible one main-queue turn after
    `openSettings()`. If not, the lookup returns nil and nothing happens, which is the
    attempt 2 behaviour, so the only cost is W1 returning in that case.

## Resolution

- Finding dispositions (lead):
  - O1 promoted: resolve the UID with `kAudioHardwarePropertyTranslateUIDToDevice`, so
    the microphone-open path on the main actor makes one Core Audio call, not a listing.
  - O2 promoted: the launch at login row also rereads its status when the app becomes
    active, so approving in Login Items updates it, and the toggle is disabled while a
    register or unregister is in flight.
  - O3 promoted: refresh the permission rows once per trigger.
  - Q1 kept for G2: step 1's instructions ask for a dictation of at least fifteen seconds
    on a non-default input and for any audio dropouts.
  - L1 (lead, from reading) withdrawn: the lead read `SettingsView.controller` as
    always passed, but `App.controller` is nil under `--hud-demo`, whose menu can still
    open the window. The remediation agent showed this; the optional and its comment
    stay.
- Simplification/deletion pass: `InputDevice` dropped its Core Audio `id` and
  `Identifiable`, since only the open path needs an ID and now gets it from
  `connectedID(uid:)`; the picker keys on `uid`. `PermissionRows` became
  `PermissionsSection`, owning its `Section` and the refresh modifiers, so `SettingsView` has
  no wrapper for it. L1 not applied: its premise is wrong. `App.controller` is nil under
  `--hud-demo`, whose menu still opens the settings window, so `SettingsView.controller`
  stays optional and its comment is accurate. Making it non-optional fails to compile at
  `App.swift`'s call.
- Final verification: `swift build` clean, no warnings; `timeout 120 swift test
  --disable-xctest` 45 passing; `xcrun swift-format lint --recursive Sources Tests
  Package.swift` clean.
- G2 correction 1 dispositions (lead):
  - R1 and R2 accepted. O2 accepted with R2, since one fix closes both. O1 promoted: one
    reopen per session is simpler than the `heard` guard and bounds every loop. O4
    promoted for the code rename only.
  - O3 not fixed: an input with more than two channels is rare for this app. Recorded in
    0007.
  - O5 rejected: asking the capture output for 16 kHz Int16 would delete the conversion
    code, but unsupported `audioSettings` raise, and it cannot be proven without the
    earbuds. Worth revisiting only after G2 passes on the converter path.
  - Q1 kept as behaviour: with System default chosen, a session keeps the device it opened
    when the default changes mid-session. Criterion 1's "device change mid-session" is met
    by the reopen when the device in use goes away. Following a new default mid-session
    would switch a Bluetooth headset's profile mid-dictation, the failure this correction
    removes. Recorded as drift for Aidan's approval with the capture change.
  - Q2 kept: the meter measures the audio that is sent, after the mix to 16 kHz mono, not
    0009's loudest channel before conversion, because the native format may not be float.
    Recorded as drift.
  - Remediation note, not acted on: the converter holds back roughly 20 to 30ms at the end
    of a session, which `stop()` does not flush. The conversion code predates this
    workstream and G1 of the dictation milestone showed no clipped last words, so it is
    left for the final review to weigh.
  - Closure note, not acted on: a stop during an open relies on the queued close running
    after the open on the microphone actor. Its executor is a serial dispatch queue, which
    runs jobs in order, so this holds.
- G2 correction 1 remediation:
  - R1: `pcmBuffer(from:)` sets `frameLength` to the sample count before
    `CMSampleBufferCopyPCMDataIntoAudioBufferList`, with a comment saying why. A throwaway
    program in `/tmp` (deleted) ran the file's `pcmBuffer`, `makeConverter` and `convert` on
    synthetic `CMSampleBuffer`s: the old order failed with -12731 for every format, and the
    new order copied and converted Float32 non-interleaved 48 kHz stereo, Float32 interleaved
    44.1 kHz stereo, Int16 interleaved and non-interleaved 48 kHz stereo, and Int16 16 kHz
    mono, one converter per format.
  - R2 and O2: per-session state moved off `AudioCapture` into a private `Session` object
    (device UID, its own `Chunker`, its `Microphone`, `reopened`). `AudioCapture` keeps only
    `session`, the one in progress. An open or reopen acts only on the `Session` it was
    given: after the access prompt it opens only if that session is still current, a loss is
    handled only if it comes from the current session's current microphone, and ending
    checks identity, so a late reopen can neither close nor fail a newer session. Each
    session's microphone delivers to that session's own chunker, created with the stream's
    continuation and dropping everything once ended, so a device still closing cannot feed
    the next session's stream. The level hop checks the reporting chunker is still
    delivering, so a stale level cannot reach the next session's pill. This removes
    `Chunker.begin`, the shared lazy chunker, `levelArrived` and the stale-reopen
    `if !chunker.isDelivering { closeDevice() }`.
  - O1: at most one reopen per session (`Session.reopened`). A second loss in the same
    session ends the stream with `captureFailed`. `heard` is removed; nothing else used it.
  - O4: `Failure.engineFailed` renamed `captureFailed`, including `describe(_:)` in
    `DictationController`. The user-facing wording ("Microphone failed: ...") is unchanged.
  - Simplification/deletion pass: `start` now calls `stop()` to finish any previous session
    rather than `Chunker.begin` finishing its continuation, and a failed start ends its own
    session through the same `end(_:throwing:)` as `stop()` and a failed reopen, so the
    open path has no catch of its own. `Chunker.isDelivering` is private. Nothing else
    found to remove.
  - Verification: `swift build` clean with no warnings (also a fresh build into a separate
    build path); `timeout 120 swift test --disable-xctest` 45 passing; `xcrun swift-format
    lint --recursive Sources Tests Package.swift` clean. Nothing run that opens the
    microphone.

- G2 attempt 3 dispositions (lead):
  - Optional accepted and applied by the lead: the doc comment now says the window opens
    with keyboard focus, or in front and focused by a click when macOS declines the
    activation. A comment-only change, so no further review; `swift build` clean, 45
    tests passing, lint clean.
  - Question accepted as a residual risk, no change: G2 passed on this candidate. If the
    window is seen behind again, retry the lookup a turn later rather than return to
    SwiftUI's window identifier.
  - W2 closed as E7 option A: recorded in 0007.
- Acceptance: criteria 1 to 7 met by reading and at G2, criterion 8 met by G2 passing
  across attempts 2 and 3. The spec's remaining `AVAudioEngine` wording, 0005's "follows
  the system default input" and 0009's pre-conversion metering are superseded by the
  approved E6 drift in [plan.md](plan.md) and are left for the decision records when the
  workflow is retired.

## Closure review

- Reviewer: fresh closure agent, against `fb37b13` plus the uncommitted diff.
- Verdict: Accepted
- Remaining required findings: none.
- Verified:
  - O1: `InputDevice.connectedID(uid:)` makes one
    `kAudioHardwarePropertyTranslateUIDToDevice` call, passing a pointer to the `CFString`
    as the qualifier with `MemoryLayout<CFString>.size`, then the input-stream check. It
    returns nil for `kAudioObjectUnknown`. `openDevice` uses it on every open, including the
    reopen, before reading the input format, so no listing runs on the main actor.
  - O2: `LaunchAtLoginRow` rereads its status on `.task` and on
    `didBecomeActiveNotification`. `pending` is set synchronously at the start of `set(_:)`
    on the main actor and disables the toggle until the detached register or unregister
    returns. Every `SMAppService` call except `openSystemSettingsLoginItems()` runs in a
    detached task.
  - O3: `PermissionsSection` owns its `Section`, and `onAppear` and `onReceive` sit on it,
    so each trigger refreshes once.
  - Deletion pass: `InputDevice` has no `id` or `Identifiable`, and the picker keys on
    `uid`. `SettingsView.controller` stays optional, which is correct because
    `App.controller` is nil under `--hud-demo`.
  - The test and dictation paths are unchanged apart from these fixes. `test()` still
    commits through `commit()`, which only calls `audio.stop()`, and never calls `finish`.
  - Checks rerun: `swift build` clean; `timeout 120 swift test --disable-xctest` 45
    passing; `xcrun swift-format lint --recursive Sources Tests Package.swift` clean.
- G2 correction 1 closure:
  - Reviewer: fresh closure agent, against `fb37b13` plus the uncommitted diff, on
    `AudioCapture.swift` and `DictationController.swift`.
  - Verdict: Accepted
  - Remaining required findings: none.
  - Verified:
    - R1: `pcmBuffer(from:)` sets `frameLength` to the sample count (equal to the capacity)
      before `CMSampleBufferCopyPCMDataIntoAudioBufferList`, with a comment saying why.
    - R2: per-session state lives on a private `Session`. `open` checks the session is still
      current after the access prompt and creates no `Microphone` otherwise. `deviceLost`
      acts only when both the session and the reporting microphone are current, and
      `end(_:throwing:)` is identity-guarded, so a late reopen can neither close nor fail a
      newer session. `start` calls `stop()` first, which ends the previous session and closes
      its microphone, including one a reopen has just assigned.
    - O2: each `Session` owns its `Chunker`, made with its own continuation, and `end` resets
      the chunker's state, so buffers from a device still closing are dropped and cannot
      reach the next stream. The level hop checks the reporting chunker, not a shared one.
      `Chunker.begin`, the shared chunker and `levelArrived` are gone.
    - O1: `Session.reopened` allows one reopen; a second loss ends the stream with
      `captureFailed`. `heard` is gone.
    - O4: `Failure.engineFailed` is `captureFailed` everywhere, including `describe(_:)`; the
      wording is unchanged. No `engineFailed` remains in `Sources` or `Tests`.
    - Microphone released: every end (stop, a failed start, a failed or second-loss reopen, a
      new start) goes through `end`, which closes the session's current microphone. A
      replaced microphone is closed in `deviceLost`. The `Microphone` is assigned before its
      open is awaited, so an end during the open queues `close()` behind it on the actor's
      serial executor; `open` also closes itself when the session is not running after
      `startRunning()`. Closing twice is harmless.
    - Objective-C exceptions: `addInput` and `addOutput` stay behind `canAdd…`, no
      `audioSettings`, a serial delegate queue, `frameLength` never above capacity, and the
      converter is remade whenever the buffer's format differs from its input format.
    - Main actor: `startRunning`, `stopRunning` and the device lookup run on the
      `Microphone` actor's queue; the main actor only awaits them or queues a close.
    - 0005: `commit()` still only calls `audio.stop()`, whose `end` flushes the partial chunk
      and finishes the stream under the chunker's lock before the pump triggers. Chunks are
      3,200 bytes of 16 kHz mono little-endian Int16.
    - Note, not blocking: the "close queues behind open" ordering relies on the opening task
      and the closing task having the same priority, since actor jobs are ordered by
      priority. Both start from main-thread UI or event tap handlers, so they do.
    - Checks rerun: `swift build` clean with no warnings (after touching both files);
      `timeout 120 swift test --disable-xctest` 45 passing; `xcrun swift-format lint
      --recursive Sources Tests Package.swift` clean. Nothing run that opens the microphone.

## External validation

- Gate and placement: G2, after focused closure, before acceptance
- Status: `Passed`
- Candidate and instructions (attempt 2): the uncommitted workstream 2 state on
  `feat/settings` (base `fb37b13`), after G2 correction 1 and its closure. Capture now uses
  `AVCaptureSession` instead of `AVAudioEngine`. Launch it with `./scripts/run.sh` only.
  Open Settings… from the menu bar. Have the Between 3ANC earbuds connected. Then:
  1. The Input picker should list System default, MacBook Pro Microphone and the earbuds,
     each once, by name. If the picker shows an earlier choice as "(not connected)",
     choose it again: device IDs are now the ones AVFoundation reports.
     - Choose the earbuds. Dictate with Opt+D for at least fifteen seconds. Report
       whether the pill reaches listening, whether the transcript covers the whole
       fifteen seconds without gaps, and whether the app stays up. The first second or so
       may be lost to the earbuds' profile switch (0005).
     - Choose MacBook Pro Microphone. Dictate for at least fifteen seconds and check the
       macOS microphone indicator (Control Centre shows which input is in use) names the
       built-in microphone. Run Test and check the same.
     - Choose System default (the earbuds, while they are the default input) and dictate
       again.
     - Relaunch and check the last choice is still selected.
  2. Choose the earbuds, then disconnect them (put them in the case). Reopen the window:
     the picker should still show the earbuds as their ID followed by "(not connected)".
     Dictate: it should use the built-in microphone. Optionally, disconnect the earbuds in
     the middle of a dictation on them: the dictation should carry on from the built-in
     microphone, or end with a "Microphone failed" error, and the app should stay up.
  3. With a good key, click Test and speak for the five seconds. What you said should
     appear under the key field. Nothing should be pasted into any app and no pill
     should appear.
  4. Change the key to a wrong one and click Test: a key error ("xAI rejected the API
     key") should appear under the field. Put the good key back, click Test and stay
     silent: "Nothing was heard" should appear.
  5. While a test runs, press Opt+D: nothing should happen. While a dictation runs, the
     Test button should be disabled.
  6. The Permissions section should show Microphone and Device Control and Data Access as
     Granted. Click each Open button and report which pane of System Settings it opens,
     in particular whether the second lands on Device Control and Data Access on macOS
     27.2.
  7. Turn on Launch at login. EchoType should appear under System Settings > General >
     Login Items. Turn it off; it should disappear. Change it in System Settings, return
     to the window and check the toggle matches. Optionally, log out and back in with it
     on and check EchoType starts. Note: the item registered here points at
     `.build/EchoType.app`, so turn it off afterwards (see 0007).
  If anything fails or crashes, say which step, what you saw, and attach any crash
  report. The lead reads the app's unified log for the time of the run.
- Required evidence: the G2 list in [plan.md](plan.md)
- Attempts and lasting decisions:
  - Attempt 1, published 2026-09-25 as escalation E5 in [plan.md](plan.md). E1 to E4
    were used by workstream 1, so this gate uses E5 rather than the packet's E2 to keep
    ids unique.
  - Attempt 1 result (Aidan, 2026-09-25, E5 answer): step 1 fails. Dictation would not
    take audio from his Bluetooth earbuds, and the app crashed. Steps 2 to 7 not reported.
    Earbuds: Status Audio Between 3ANC (non-Apple, HFP and A2DP), which macOS lists as
    both an input (16 kHz while in use) and an output (44.1 kHz), and which were the
    system default input and output.
  - Evidence: the crash report (EXC_BAD_ACCESS on the main thread in
    `MainActor.assumeIsolated`, from SwiftUI hover handling) and the app's unified log for
    the run (08:29 to 08:37).
  - Diagnosis:
    - Reopen loop. Every `AVAudioEngine` start on the earbuds switched them from A2DP to
      the headset profile, which changed the device format, so the engine posted a
      configuration change within half a second and stopped. `deviceChanged()` closed
      the engine and opened a new one, whose start switched the profile again: 45 starts
      in the run, roughly one a second, while a dictation was open. With the system
      default (no stored device) the engine opens an aggregate of the default output and
      input, both the earbuds, and loops the same way, so this is not only the new
      `setDeviceID` path. With the earbuds chosen explicitly, `setDeviceID` also failed to
      set the Bluetooth format (`SetBluetoothAudioFormat ... err='who?'`) and the engine
      fell back to its default aggregate by itself. This is the dropout loop review Q1
      anticipated.
    - Crash. In one reopen the input node's `outputFormat(forBus: 0)` still said 44.1
      kHz while the hardware had moved to 16 kHz. `installTap` with that format raised an
      Objective-C exception ("Format mismatch: input hw 16000 Hz, client format 44100
      Hz"). AppKit caught and logged it, but it had unwound through the Swift task
      running `deviceChanged()`, leaving the concurrency runtime's executor state on the
      main thread pointing at a dead frame. The next `MainActor.assumeIsolated`, four
      seconds later on a mouse move, crashed on it.
  - Correction (lead): revisit the capture design rather than patch the engine. The loop
    comes from `AVAudioEngine` on macOS tying input to an output-side IO unit and
    stopping itself on any device format change, which a Bluetooth headset causes on
    every open. `AudioCapture` moves to `AVCaptureSession` (input only, device chosen
    by unique ID, format changes absorbed by the capture stack), and the picker lists
    `AVCaptureDevice`s so the stored ID and the open path agree by construction. This
    changes the capture framework the specification names, so the full loop is
    reopened and the change goes to Aidan for approval with the next candidate.
  - Correction 1 went through implementation, independent review (two required
    findings), one remediation pass and focused closure (Accepted), recorded in the
    sections above.
  - Attempt 2, published 2026-09-25 as escalation E6 in [plan.md](plan.md), which also
    asks Aidan to approve the move to `AVCaptureSession`. E5's answer is recorded above and
    the entry removed.
  - Attempt 2 result (Aidan, 2026-09-25, E6 answer and follow-up), taken as approving
    option A (`AVCaptureSession`). Step 1 passes: dictation and Test use each input. Step 2
    passes. Step 4: a wrong key shows the key error inline. Step 5: Opt+D does nothing
    during a test. Step 6 passes: both rows show granted and each button opens the right
    pane, including Device Control and Data Access on macOS 27.2. Not reported: step 3, the
    silent half of step 4, the Test-disabled-during-dictation half of step 5, and step 7.
    He asked whether Test stopping after about five seconds while dictation keeps
    listening is expected: it is, by the plan's decision log, and he was told so. Two
    window observations, both in workstream 1's activation code in `App.swift`:
    - W1. The settings window occasionally still opens below the frontmost window, from the
      main desktop. Infrequent, and he cannot force it.
    - W2. With the settings window open, after switching to a fullscreen app, clicking the
      menu bar icon does not show the menu. He is unsure whether that is normal.
  - Diagnosis (lead, by reading and from reports; agents cannot open the window, and the
    unified log does not record whether an activation was granted):
    - W1. `SettingsButton` switches to a regular app and activates one main-queue turn
      later. Activation on macOS 14 and later is cooperative and can be declined, and
      activating shortly after an accessory-to-regular switch is known to be unreliable
      without a delay. When it is not granted, the window opens in an inactive app, behind
      the frontmost app. Attempt 4 of G1 removed the `orderFrontRegardless()` fallback
      because it found the window by SwiftUI's undocumented identifier.
    - W2. A known macOS limitation, not a defect in the code: a status item of an app with
      the regular activation policy does not open its menu or popover while another app is
      fullscreen, and an accessory app's does (Apple Developer Forums thread 85994, where
      toggling the policy toggles the behaviour). It follows from the Dock icon decision
      approved at G1 (E3). Fixing it means leaving the regular policy while EchoType is not
      frontmost, which drops the Cmd+Tab entry E3 approved, so it goes to Aidan.
  - Correction for attempt 3 (`App.swift`, `SettingsButton` only): after the deferred
    `activate()`, raise the settings window with `orderFrontRegardless()`, so a declined
    activation still leaves it in front and a click focuses it. The window is found as the
    app's only visible window that can become main (the overlay panel and the menu bar's
    windows cannot), not by identifier. Troubleshooting correction, not yet reviewed; it
    gets one review after the gate passes. `swift build` clean with no warnings (also a
    fresh build path), 45 tests passing, swift-format lint clean.
  - Attempt 3, published 2026-09-25 as escalation E7 in [plan.md](plan.md), with these
    steps, launching with `./scripts/run.sh` only:
    - W1. Use Settings… from the menu bar as usual for a while, with another app's window
      frontmost each time and the window closed between tries. Report whether the window
      ever opens behind another window. If it does and a click brings it forward, say so.
    - W2. Decide option A or B in E7.
    - Step 3. With a good key, click Test and speak for the five seconds. What you said
      appears under the key field; nothing is pasted anywhere and no pill appears.
    - Step 4, silent half. With the good key, click Test and stay silent: "Nothing was
      heard" appears.
    - Step 5, second half. Start a dictation with Opt+D, open the window: Test is disabled
      until the dictation ends.
    - Step 7. Turn on Launch at login: EchoType appears under System Settings > General >
      Login Items. Turn it off: it disappears. Change it in System Settings, return to the
      window and check the toggle matches. Optionally, log out and in with it on and check
      EchoType starts. Turn it off afterwards: the item points at `.build/EchoType.app`
      (see 0007).
  - Attempt 3 result (Aidan, 2026-09-25, E7 answer): every remaining G2 step passes on
    the attempt 3 candidate: step 3 (Test shows the transcript inline, nothing pasted, no
    pill), the silent half of step 4 ("Nothing was heard"), the second half of step 5
    (Test disabled during a dictation) and step 7 (launch at login on and off, and the
    toggle following System Settings). W1: he has not seen the settings window open below
    the current window again. W2: option A, recorded in 0007. With attempt 2's results
    (steps 1, 2 and 6, the wrong-key half of step 4 and the first half of step 5), every G2
    observation has passed. E7's lasting decision is in the Implementation handoff above
    and the entry is removed from [plan.md](plan.md).
- Resume condition: every G2 observation reported as passing. Met.
