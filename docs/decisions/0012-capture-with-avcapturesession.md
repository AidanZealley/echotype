# 0012 Capture the microphone with AVCaptureSession on the chosen input

Status: accepted, 2026-09-25 (settings gate G2). Replaces the specification's
`AVAudioEngine` tap, the "follows the system default" line in
[0005](0005-microphone-per-session.md) and the pre-conversion meter in
[0009](0009-overlay-behaviour.md).

## Context

The settings milestone added an input picker. With `AVAudioEngine` on Bluetooth earbuds
(Between 3ANC), every engine start switched the headset profile, the format change
stopped the engine, and the restart switched it again, about once a second. One restart
installed a tap on the stale format, which raised an Objective-C exception and crashed
the app.

## Decision

- Capture is an input-only `AVCaptureSession` with an `AVCaptureAudioDataOutput` in the
  device's native format. Each sample buffer is copied into an `AVAudioPCMBuffer` and goes
  through `AudioConverter`, which is remade when the format changes. The chunk contract
  and the stop-first commit order from 0005 are unchanged.
- Each open is a `Microphone` actor whose executor is its own serial queue, so the
  blocking `startRunning()` and `stopRunning()` never run on the main actor, where the
  event tap runs.
- The picker lists `AVCaptureDevice.DiscoverySession` devices (`.microphone` and
  `.external`), and `Settings.inputDeviceID` stores their `uniqueID`. A stored device that
  is not connected shows as not connected, and the session uses the system default input.
- A session keeps the input it opened when the system default changes. Following a new
  default mid-session would switch a Bluetooth headset's profile mid-dictation. If the
  input goes away, the session reopens once, resolving the stored ID again. A loss before
  any audio arrived ends the session instead, so a failure on every open cannot loop.
- The meter measures the converted 16 kHz mono audio, which is what is sent, so it reads
  the same for every device format. It reports on the first buffer, which still marks
  audio flowing, then once per 100ms chunk.

## Consequences

- Bluetooth earbuds work as a chosen input and as the system default.
- A mono mix reads up to 6 dB lower than the loudest channel when only one of two channels
  carries the voice.
- The specification's Architecture and Audio sections still name `AVAudioEngine`. This
  record wins.
