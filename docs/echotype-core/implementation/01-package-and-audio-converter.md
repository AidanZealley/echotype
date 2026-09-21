# Workstream 1: Package skeleton and audio converter

Status: not started.

## Task packet

### Outcome

`swift build`, `swift test --disable-xctest` and `swift-format lint` all pass on a
package containing the `Settings` value type and an audio converter that turns
device-rate Float32 samples into 16 kHz mono little-endian Int16 suitable for the xAI
streaming endpoint.

### Scope

- `Package.swift` at swift-tools-version 6.2 declaring the `EchoTypeCore` library and
  the `EchoTypeCoreTests` test target. No external dependencies. No macOS app target;
  see the plan's decision log for why.
- `Settings`, a value type holding every tunable the specification names: the hotkey as
  a keycode plus modifier flags, the keyterm list, language, the silence timeout in
  seconds (default 10), the hard session cap in seconds (default 600), and the selected
  input device as an optional identifier where absent means follow the system default.
- `AudioConverter`, converting Float32 input at an arbitrary device sample rate to
  16 kHz mono Int16, little-endian, emitting chunks of roughly 100ms. It must be
  usable as a stream: successive calls continue from where the previous one ended
  without dropping or duplicating samples at the boundary.

### Non-goals

- Capturing audio. `AVAudioEngine` is macOS-only and belongs to a later milestone.
  The converter takes `[Float]` and returns `Data`.
- Opus encoding. The specification rejects it, since PCM at 16 kHz is 32 KB/s.
- Persisting settings. `UserDefaults` is macOS-side; this is the value type only.
- Any networking. That is workstream 2.
- A general-purpose DSP abstraction. One converter, one job.

### Initial ownership

Creates and owns `Package.swift`, `Sources/EchoTypeCore/Settings.swift`,
`Sources/EchoTypeCore/AudioConverter.swift` and `Tests/EchoTypeCoreTests/`.

### Required seams

Freezes for later workstreams: the package layout, the Foundation-only import rule,
and `Settings` as the single source of tunables.

### Acceptance criteria

1. `swift build` succeeds.
2. `swift test --disable-xctest` exits 0 with all tests passing.
3. `swift-format lint --recursive Sources Tests` exits 0.
4. `EchoTypeCore` imports nothing from Apple except Foundation.
5. Converting 48 kHz input produces exactly one third as many output samples, within
   the rounding the implementation documents.
6. Feeding a continuous signal through several successive calls produces the same
   output as feeding it in one call, proving no samples are lost or repeated at chunk
   boundaries.
7. Stereo input is downmixed to mono.
8. Samples beyond the range Int16 can represent are clipped rather than wrapping.
9. Output byte order is little-endian.

### Targeted verification

```bash
swift build
swift test --disable-xctest
swift-format lint --recursive Sources Tests
```

New focused tests covering criteria 5 to 9, asserted against known waveforms rather
than golden files. Test the converter's observable behaviour, not its internal
buffering strategy.

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
