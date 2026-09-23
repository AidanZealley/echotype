# Workstream 2: Audio capture

Status: accepted.

## Task packet

### Outcome

A type in `EchoTypeApp` that opens the microphone, converts what it hears into the
format the xAI endpoint expects, and delivers it in chunks a session can stream. It has
no caller yet; workstream 3 wires it up.

### Scope

**Capture.** An `AVAudioEngine` input tap. Follow the system default input device, which
is what you get by not setting one, so connecting AirPods does the obvious thing. The
device picker is a later milestone.

**Conversion.** Device-rate Float32 to 16 kHz mono little-endian Int16, using
`AVAudioConverter`. Note that the simple `convert(to:from:)` form does not resample; rate
conversion needs the `convert(to:error:withInputFrom:)` form with an input block. The
platform owns resampling, including the anti-alias filtering a hand-written interpolator
would skip, which is why this is not reimplemented. `Tests/EchoTypeCoreTests/Integration/AudioConverter.swift`
is a fixture helper for the live protocol test and is not a model to follow.

**Cadence.** Roughly 100ms per chunk, which is about 3200 bytes at 16 kHz mono Int16.
The tap's buffer size is a hint the engine may ignore, so the chunking is yours to get
right: no dropped samples and no repeated samples at a buffer boundary.

**Device lifetime, separate from delivery.** Opening the input device takes 100 to 300ms,
enough to clip the first word. Acquire the stream on first use and hold it through a few
minutes of idle before releasing it, so the second dictation in a row does not pay that
cost. Starting and stopping delivery is a different thing from acquiring and releasing
the device, and the API must make that difference visible to its caller.

**Permission.** Add `NSMicrophoneUsageDescription` to `Resources/Info.plist`. Without it
the process is killed the first time it touches the microphone, with nothing that says
why. Request microphone access and surface the result to the caller rather than failing
silently.

### Non-goals

- The RMS level meter. It belongs to the overlay milestone and nothing renders it yet.
- The input device picker, and any `Settings` field for it.
- Opus, or any encoding other than raw PCM. At 32 KB/s the API's Opus option buys
  nothing and would cost an encoder.
- A protocol wrapper around `AVAudioEngine` so it can be faked. Tests of the fake are
  not worth the seam.
- Wiring to `SessionMachine`, the hotkey or the overlay.

### Initial ownership

- `Sources/EchoTypeApp/AudioCapture.swift`
- `Resources/Info.plist`

Do not change `Package.swift` or anything in `EchoTypeCore`.

### Required seams

Workstream 3 is the only consumer. It needs to:

- Acquire the device ahead of, or at, the first session and keep it warm afterwards.
- Start delivery when a session opens and stop it when the session ends.
- Receive `Data` chunks of 16 kHz mono little-endian Int16, roughly 100ms each, in
  capture order, and hand each to `SessionMachine.send(audio:)`.
- Learn that microphone permission was refused, and that the engine failed to start.

Choose the API that makes that read well. Record its exact shape in the Implementation
handoff, including how a caller learns about failure, because workstream 3 reads that
handoff rather than the code.

### Acceptance criteria

1. `Resources/Info.plist` carries `NSMicrophoneUsageDescription` with text that says why
   the app wants the microphone.
2. The capture type compiles, requests microphone access, and starts an `AVAudioEngine`
   input tap on the system default device.
3. Conversion produces 16 kHz mono little-endian Int16 at the device's real rate,
   whatever that is. 44.1 kHz must work as well as 48 kHz.
4. Chunks are roughly 100ms and no sample is dropped or duplicated across a buffer
   boundary.
5. Device acquisition and release are separate from starting and stopping delivery, and
   the device survives a few minutes of idle between sessions.
6. A refused permission and a failed engine start both reach the caller as something it
   can act on. Neither is swallowed.
7. The handoff records the API workstream 3 will call.

### Targeted verification

```bash
swift build
swift test
```

Then, because compiling is a weak signal for this workstream, launch it once to prove the
plist and the permission path:

```bash
./scripts/run.sh
```

The app has no way to trigger capture yet, so what this proves is that the bundle builds,
signs and launches with the new plist key rather than dying on it. Record what happened.

```bash
swift-format lint --recursive Sources Tests Package.swift
```

Skip the lint if swift-format is not installed and say so in the handoff.

There is no unit test for this workstream and one should not be invented. Its real
verification is gate G1 in workstream 3. Say so plainly in the handoff rather than
padding the suite.

## Implementation handoff

- Base commit: `3a0da2a`
- Outcome: Done, to the compile-and-review bar. `AudioCapture` opens the default input
  device, converts to 16 kHz mono little-endian Int16 with `AVAudioConverter`, and delivers
  3200-byte chunks. It has no caller. Whether it captures anything is for gate G1 to show.
- Files changed:
  - `Sources/EchoTypeApp/AudioCapture.swift`: new. `AudioCapture`, plus a private
    `Chunker` that owns conversion and chunking under a lock.
  - `Resources/Info.plist`: `NSMicrophoneUsageDescription`, "EchoType listens while you
    dictate and sends your speech to xAI to turn it into text."
- API for workstream 3: one `@MainActor final class AudioCapture`, created once and kept
  for the life of the app.
  - `func acquire() async throws(AudioCapture.Failure)`: asks for microphone access the
    first time, then opens the default input device and keeps it warm. Does nothing if the
    device is already held. Optional to call; use it to warm the device ahead of a session.
  - `func start() async throws(AudioCapture.Failure) -> AsyncThrowingStream<Data, any Error>`:
    acquires if needed, then starts delivery. Iterate the stream and pass each chunk to
    `SessionMachine.send(audio:)`. Chunks arrive in capture order, 3200 bytes each (100ms)
    except the last. Calling `start()` again finishes the previous stream.
  - `func stop()`: ends delivery. Yields the remaining partial chunk, then finishes the
    stream normally. The device stays open for 3 minutes and closes itself if no `start()`
    follows. There is no public `release()`, because nothing needs one.
  - Failures:
    - `start()` or `acquire()` throws `.microphoneDenied` if access is refused, now or
      earlier. Only System Settings can undo it.
    - They throw `.noInputDevice` if there is no input device to open.
    - They throw `.engineFailed(underlying)` if `AVAudioEngine.start()` fails.
    - During a session the stream itself throws `.engineFailed` if conversion fails, or if
      the device changes and cannot be reopened. Workstream 3 should treat a thrown stream
      as a failed session. A stream that finishes without throwing only ever means
      `stop()` was called.
  - Calling contract: every stream `start()` returns must be ended by `stop()`, which is
    what arms the idle release. If the session ends while `start()` is still awaiting, for
    example during the first-use permission prompt, call `stop()` once `start()` returns.
    Cancelling the iterating task does not end delivery.
- Decisions:
  - **Warm device means a running engine with the tap installed.** A running engine with no
    tap may not pull from the input, which would defeat the point. `Chunker` drops buffers
    while nothing is delivering and converts only while something is.
  - **One lock, not a queue.** The tap runs on an audio thread and `start`/`stop` on the main
    actor. A `Mutex` around the continuation, converter and pending bytes orders the two
    edges: nothing captured before `begin` or after `end` is delivered. Conversion happens
    under the lock. It is short work, and the main actor holds the lock only for a moment.
  - **A fresh converter per session**, made from the first tap buffer's actual format and
    remade whenever that format changes. That is how 44.1 kHz, 48 kHz and a Bluetooth
    headset's rate all get handled without asking the device. `downmix = true`, so stereo
    inputs are mixed rather than truncated to the first channel.
  - **No dropped or repeated samples.** Each tap buffer goes to `convert(to:error:withInputFrom:)`,
    whose input block returns `.noDataNow` after supplying it once. The resampler keeps its
    own history across calls. If the output buffer fills first (`.haveData`), the loop
    converts again. Chunks are cut from a running byte buffer, so where the engine's buffer
    boundaries fall has no effect on chunk boundaries. After cutting, the buffer is replaced
    with a fresh copy of the unsent tail, because `Data.removeFirst` keeps consumed bytes
    allocated and the buffer would grow for the length of the session.
  - **Flush on stop, not on failure.** `stop()` yields the last partial chunk so the tail of
    the final word is not lost. The few milliseconds held inside the resampler are not
    drained, because that needs an end-of-stream and a converter reset for no audible gain.
  - **Default device changes.** The engine stops itself on `AVAudioEngineConfigurationChange`.
    The observer closes the device, and reopens it on the new default only if a session is
    delivering, so that session carries on across an AirPods connect. When idle it stays
    closed until the next `start()`. That way an idle warm mic never grabs newly connected
    AirPods and holds them in headset mode, and unrelated device changes don't restart the
    idle timer. Reopening mid-session re-arms the idle timer, but release is skipped while
    delivering.
  - **3 minutes idle.** "A few minutes" in the specification. A private constant, not a
    `Settings` field, since nothing needs to change it.
  - **The tap block is formed in `Chunker.install(on:format:)`**, a nonisolated method. A
    closure formed on the main actor would be main-actor isolated under Swift 6 and trap
    when the engine calls it from its audio thread.
- Verification:
  - `swift build`: clean, no warnings.
  - `swift test`: 33 tests passing, exit 0. None of them touch this code.
  - `./scripts/run.sh`: built, signed as `com.aidanzealley.echotype` and launched. The
    process stayed running and the bundled `Info.plist` carries
    `NSMicrophoneUsageDescription`. Nothing calls `AudioCapture` yet, so the permission
    prompt was not exercised.
  - `swift-format` is not installed, so the lint step was skipped.
  - No unit test was written, per the packet. Everything here is `AVAudioEngine` and
    `AVAudioConverter` behaviour. The real verification is gate G1 in workstream 3.
- Known limitations or external checks:
  - Untested against a real microphone: permission prompt, first-word clipping, chunk
    cadence, conversion quality at 44.1 kHz, and reopening on a device change all wait
    for G1.
  - The orange microphone indicator stays lit for the 3 minutes the device is held warm.
    That follows from the specification's choice to keep the device warm.
  - A device change while idle closes the device, so the next session pays the 100 to
    300ms open cost again.
  - Denied access is reported but the system does not re-prompt. Workstream 3 should
    point the user at System Settings.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent review agent, against the uncommitted diff on `3a0da2a`.
- Verdict: Changes required. The design meets criteria 1 to 7 on reading, and one
  memory defect in the chunking has to be fixed. `swift build` is clean. `swift test`
  passes 33 tests with exit 0. `swift-format` is not installed, so lint was skipped. No
  test was added, which is correct for this packet: there is nothing here to test without
  faking `AVAudioEngine`.
- Required findings:
  - **R1. `pending.removeFirst(_:)` keeps every byte of the session in memory.**
    `Chunker.receive` cuts chunks with `state.pending.removeFirst(Self.chunkBytes)`. On
    `Data` that re-slices rather than compacting: `startIndex` advances and the backing
    storage keeps everything already sent. So `pending`, which should never hold more
    than one chunk, grows with the whole session: 32 KB/s, about 19 MB of live bytes at
    the ten-minute cap, plus growth slack. `end()` and `begin()` reset `State`, so
    nothing survives the session. Evidence: a standalone `swiftc -O` program running
    this exact loop (append 1365-byte buffers, yield and `removeFirst(3200)`) over 546 MB
    of input ended with `pending.startIndex == 546000000`, `count == 0` and 528 MB max
    RSS. Swapping in
    `pending.removeSubrange(pending.startIndex..<pending.startIndex + chunkBytes)`, or
    `pending = Data(pending.dropFirst(chunkBytes))`, gave `startIndex == 0` and 5 to
    6 MB RSS. Chunk contents and order are correct either way, because
    `Data(pending.prefix(_:))` copies into a zero-based `Data`.
- Optional observations:
  - **O1. The stream has no `onTermination`.** If the consumer's iteration is cancelled
    or dropped without calling `stop()`, the continuation stays in `Chunker`.
    `isDelivering` then stays true, so the idle release never closes the device. The
    microphone indicator stays lit, and the tap keeps converting into a stream nobody
    reads. Either set `continuation.onTermination` to end delivery, or state in the
    handoff that every `start()` must be matched by `stop()` even when the pump task is
    cancelled. The second option is enough if workstream 3 is careful.
  - **O2. Two lines are 101 columns** (the `convert(_:with:)` signature and the
    `AVAudioPCMBuffer(pcmFormat:frameCapacity:)` guard). swift-format's default limit is
    100 and the repository has no `.swift-format` override. Lint was skipped, so this was
    not caught.
  - Read and found sound, so no action is needed: the converter usage (block form, one
    supply per tap buffer, then `.noDataNow` rather than `.endOfStream`, and a loop on
    `.haveData`); converter rebuilt when `buffer.format` changes; `downmix = true`;
    `int16ChannelData![0]` on an interleaved mono Int16 buffer; the tap block formed in a
    nonisolated method; the notification observer on `.main` with
    `MainActor.assumeIsolated`; the re-check of `engine == nil` after the permission
    `await`; one fresh `AVAudioEngine` per acquisition, so the tap format and the hardware
    format are queried together; and the `Info.plist` key and wording.
- Questions:
  - **Q1. `stop()` does not cancel a `start()` that is still in flight.** `start()`
    awaits `acquire()`, which on first use awaits the system permission prompt. That can
    take many seconds. If the caller calls `stop()` meanwhile (Escape, or a second Opt+D),
    `stop()` finds no continuation and does nothing. `start()` then resumes and calls
    `begin`, which leaves delivery running with no session behind it and blocks idle
    release. The handoff does not mention this. Should `AudioCapture` make `stop()`
    supersede a pending `start()`, for example with a generation check before `begin`?
    Or should the handoff say that workstream 3 must not call `stop()` before `start()`
    returns, and must call it afterwards if the session has already ended? Either is
    small. The lead should choose one so workstream 3 is not left to find out.
  - **Q2. A warm Bluetooth microphone, and reopening while idle.** Holding the default
    input open for 3 minutes after a session is the specification's choice. With AirPods
    as the default input, though, an open microphone keeps them on the headset profile,
    so any audio playing sounds worse for those 3 minutes. `deviceChanged()` also reopens
    when no session is running, which re-arms the full 3 minutes on any configuration
    change. `AVAudioEngineConfigurationChange` fires for output changes too. This is not a
    defect against the packet. It is worth adding to G1's observations, or recording as a
    known consequence. Reopening only while delivering, and simply closing otherwise,
    would be a simpler rule if the lead prefers it.

## Resolution

- Finding dispositions:
  - **R1 accepted, fixed.** `receive` cuts whole chunks by offset, then replaces
    `pending` with a fresh copy of the unsent tail, so it never holds more than one chunk.
  - **Q2 promoted and fixed.** On a configuration change the device is closed and only
    reopened while a session is delivering. An idle warm microphone no longer grabs newly
    connected AirPods into headset mode, and unrelated device changes no longer restart
    the idle timer. The cost is that the next session after an idle device change pays
    the open time again, which is recorded in the handoff's limitations.
  - **O2 accepted, fixed.** Both lines wrapped.
  - **O1 rejected as code, resolved as contract.** An `onTermination` handler would run
    from inside `finish()`, which `Chunker` calls under its lock, so it would re-enter the
    `Mutex`. Workstream 3 owns exactly one stream at a time, so a stated rule is simpler:
    every stream `start()` returns is ended by `stop()`. Recorded in the handoff's API.
  - **Q1 answered as contract.** If the session ends while `start()` is still awaiting
    (the first-use permission prompt), the caller calls `stop()` once `start()` returns.
    A generation counter in `AudioCapture` would guard a window that exists only on the
    very first use. Recorded in the handoff's API.
- Simplification/deletion pass: the Q2 change removed the idle reopen path rather than
  adding one. Nothing else in the file is unneeded by an acceptance criterion.
- Final verification: `swift build` clean, `swift test` 33 passing, exit 0, after
  remediation. `./scripts/run.sh` was run once before remediation and launched with the
  new plist key; the plist did not change afterwards. `swift-format` is not installed, so
  lint was skipped. The real verification is gate G1 in workstream 3.

## Closure review

- Reviewer: focused closure review agent, against the uncommitted diff on `3a0da2a`.
- Verdict: Approved.
- Remaining required findings: none.
- Checks:
  - **R1 fixed.** `receive` cuts chunks by offset from a zero-based `pending` and replaces
    it with `Data(state.pending[sent...])`, so it never holds more than one chunk's worth of
    bytes plus one tap buffer. `pending` is only ever assigned a fresh `Data`, so the
    offset indexing is valid. Chunks are copied out, so order and contents are unchanged.
  - **Q2 fix sound.** `deviceChanged()` closes the device and reopens it only while
    delivering. A failed reopen ends the stream with the thrown `Failure`. A `stop()`
    during the reopen still leaves the device released after the idle timeout, because the
    reopen's `acquire()` schedules the release and it is not skipped once delivery has
    ended.
  - **O2 fixed.** No line in `AudioCapture.swift` exceeds 100 columns.
  - **O1 and Q1** are recorded as calling contract in the handoff's API, as the
    Resolution says.
  - `Resources/Info.plist` carries `NSMicrophoneUsageDescription` with the stated wording.
  - `swift build` clean after touching the file, no warnings. `swift test` 33 passing.
- Note for the lead: the `Status:` line at the top still reads "not started".
