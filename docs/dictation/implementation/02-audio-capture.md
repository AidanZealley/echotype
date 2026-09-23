# Workstream 2: Audio capture

Status: not started.

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

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- API for workstream 3: `TBD`
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
