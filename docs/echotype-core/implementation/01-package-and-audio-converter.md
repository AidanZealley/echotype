# Workstream 1: Package skeleton and audio converter

Status: accepted.

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

- Base commit: `2c57765`
- Outcome: Done, including one remediation pass covering the seven findings the lead
  accepted. All nine acceptance criteria met; the work is uncommitted on
  `feat/echotype-core`.
- Files changed: added `Package.swift`, `Sources/EchoTypeCore/Settings.swift`,
  `Sources/EchoTypeCore/AudioConverter.swift`,
  `Tests/EchoTypeCoreTests/AudioConverterTests.swift` and `.gitignore` (ignoring
  `.build/`). All five are untracked and need an explicit `git add`. `plan.md` untouched.
- Decisions:
  - `AudioConverter` is a `Sendable` struct with a `mutating convert(_:) -> Data`. Value
    semantics keep the resampler state trivially testable, and the conformance is part of
    the seam the macOS capture layer holds a converter inside an `installTap` closure.
  - The resampler is linear interpolation carrying one frame plus an output counter across
    calls. Position is derived as `producedSamples * ratio` rather than accumulated, so a
    non-integer ratio such as 44.1 kHz cannot drift over a long session.
  - Interpolating an output sample needs the input frame after it, so the stream's final
    frame is held back rather than extrapolated. A stream of `frames` mono frames yields
    `ceil((frames - 1) / ratio)` samples, which is exactly one third at 48 kHz and correct
    for upsampling ratios too. That is the rounding criterion 5 refers to, documented on
    the type.
  - Samples are clipped to full scale as they are read, before any arithmetic. That covers
    hot samples, infinities and NaN in one place: a non-finite sample can neither trap the
    Int16 conversion nor reach the interpolator, where `inf - inf` would manufacture NaN
    even at a zero fraction. NaN has no sensible amplitude, so it becomes silence.
  - The roughly 100ms chunk cadence is the macOS capture layer's obligation, not the
    converter's. The specification assigns chunking to the `AVAudioEngine` tap, and
    `installTap` treats its buffer size as a hint, so the capture layer must hold the
    cadence rather than assume it. `convert` returns everything ready for the buffer it was
    handed, so chunk size equals buffer size.
  - Multi-channel input must be interleaved and whole-framed. Both obligations sit with the
    capture layer, since `AVAudioEngine`'s input node is non-interleaved by default, and
    both are stated on `convert`: a buffer ending mid-frame drops the orphan sample and
    pairs the wrong channels for the rest of the session.
  - `Settings.Hotkey` stores a keycode plus a Foundation-only `ModifierFlags` option set, as
    the specification requires, with Opt+D (`keyCode 0x02`, `.option`) as the default. The
    macOS layer maps those flags to `CGEventFlags`; nothing here imports CoreGraphics.
  - The API key is deliberately not a `Settings` field: the specification puts it in the
    Keychain.
  - Tests use Swift Testing and the public API only. The ramp test asserts output sample `n`
    equals input frame `3n` at 48 kHz, which pins interpolation phase and fidelity rather
    than comparing the converter against itself; the clipping test asserts values rather
    than an exact output length, so it stays independent of the held-back-frame decision.
- Verification: `swift build`, `swift test --disable-xctest` (6 tests, exit 0) and
  `swift-format lint --recursive Sources Tests` (exit 0, silent) all pass on Swift 6.4 on
  the Linux machine. `EchoTypeCore` imports Foundation only, confirmed by grep over
  `Sources/`.
- Known limitations or external checks: linear interpolation has no anti-alias filter, so
  input energy above 8 kHz folds back; speech into an ASR endpoint does not need one, and a
  filter now would be unverifiable machinery. There is no flush, so the final input frame of
  a session is never emitted, which is 21 microseconds at 48 kHz. Nothing is verified
  against real `AVAudioEngine` buffers, which is a macOS milestone.
- Specification drift: none.

## Independent review

- Reviewer: independent review agent, fresh session.
- Verdict: one required finding. Everything else is optional or a question for the lead.
- Checks run: `swift test --disable-xctest` (5 tests, exit 0) and
  `swift-format lint --recursive Sources Tests` (exit 0, silent). `grep -rn "import"` over
  `Sources/` shows Foundation only, so criterion 4 holds. Criteria 1, 2, 3, 6, 7 and 9 are
  met as written, and criterion 5 is met at 48 kHz (48000 frames in, exactly 16000 samples
  out). Resampler fidelity was checked outside the repository by running a linear ramp at
  48 kHz through a copy of the converter: output sample `n` equals input frame `3n` exactly,
  so the interpolation is correctly phased and is a real interpolation rather than sample
  dropping. Chunked-versus-whole equality also holds at 8 kHz, 16 kHz and 96 kHz, not just
  the 44.1 kHz the test covers.

### Required findings

1. A non-finite input sample aborts the process instead of clipping
   (`Sources/EchoTypeCore/AudioConverter.swift:87`). Criterion 8 asks for samples beyond
   Int16's range to be clipped rather than wrapped, and `min(max(sample, -1), 1)` does not
   handle infinity or NaN: `Int16(_: Float)` traps on both. Evidence, running the shipped
   `convert` over `[.infinity, .infinity, -.infinity, -.infinity]` at 16 kHz:
   `Swift/IntegerTypes.swift:2989: Fatal error: Float value cannot be converted to Int16
   because it is either infinite or NaN`, from `AudioConverter.convert(_:)`. Note the
   interpolator reaches NaN on its own from finite-looking input too: `earlier + (later -
   earlier) * fraction` with both frames at `+inf` computes `inf - inf`, which is NaN even
   at `fraction == 0`. A trap here kills the whole dictation app mid-session with nothing
   recoverable, and the guard that exists to prevent exactly this class of bad sample is one
   `isFinite` check away from covering it. The lead may reasonably downgrade this if it
   judges that `AVAudioEngine` can never hand over a non-finite float, but that judgement is
   not currently written down anywhere and the cost of covering it is a single expression.

### Optional observations

1. The documented output-length formula is off by one when the input rate is below 16 kHz
   (`Sources/EchoTypeCore/AudioConverter.swift:12`, repeated in the handoff). The type states
   `floor((frames - 2) / ratio) + 1`. The loop's actual stopping condition gives
   `ceil((frames - 1) / ratio)`. The two agree for every downsampling ratio, and disagree
   when `ratio < 1`: 4000 frames at 8 kHz produce 7998 samples, while the documented formula
   predicts 7997. This matters a little more than a stray comment because criterion 5 is
   defined in terms of what the implementation documents, and because the specification
   makes an 8 kHz path plausible, since it calls out AirPods as the device the picker must
   follow and Bluetooth HFP inputs run at 8 or 16 kHz.
2. `AudioConverter` does not conform to `Sendable`, while `Settings` does. A public struct
   gets no implicit conformance outside its module, so under the Swift 6 language mode this
   manifest selects, the macOS capture layer cannot hold a `var converter` inside an
   `installTap` closure without working around it. Verified by building a separate module
   against this package: `error: type 'AudioConverter' does not conform to the 'Sendable'
   protocol`, while the same check on `Settings()` compiles. No acceptance criterion covers
   this, and the fix is one word, but the packet freezes the package layout as a seam for
   later workstreams and this is part of that seam.
3. Multi-channel input silently loses frame alignment if a buffer ever ends mid-frame
   (`Sources/EchoTypeCore/AudioConverter.swift:74`). The comment says a trailing partial
   frame is ignored, which understates it: the orphan sample is dropped permanently, so every
   later frame pairs the wrong two channels and the stream is one sample short for the rest
   of the session. Evidence at 16 kHz stereo over a ramp, whole call versus split at 5
   samples: `[164, 819, 1475, 2130, 2785, 3441, 4096, 4751, 5407]` against
   `[164, 819, 1802, 2458, 3113, 3768, 4424, 5079]`. Frame-aligned chunks are exact, which is
   what `AVAudioEngine` delivers in practice, so this is a documentation gap rather than a
   live bug. Either carry the partial frame or state the frame-aligned precondition on
   `convert`.
4. `init` asserts `inputSampleRate > 0` but not `channelCount > 0`
   (`Sources/EchoTypeCore/AudioConverter.swift:38`). `channelCount: 0` falls through the
   `guard channelCount > 1` fast path and is silently treated as mono. Cheap to make
   consistent with the rate check.
5. No test asserts that output values track the input waveform. The suite pins counts,
   endianness, clipping, downmix and chunk-boundary self-consistency, all of which would still
   pass if the resampler picked the nearest sample, interpolated the wrong pair or sat one
   frame out of phase, because the streaming test compares the converter against itself. I
   confirmed by hand that none of those defects is present, so this is a coverage gap rather
   than a bug. A ramp at 48 kHz asserting `out[n] == in[3n]` is three lines and closes the
   class. This is the one place the packet's "asserted against known waveforms" wording is
   only half honoured: the tests use a sine, then assert only its length.
6. `overloadedSamplesClip` expects exactly three samples from four input frames, which ties a
   clipping test to the held-back-final-frame decision. If that decision ever changes, the
   test fails for a reason unrelated to what it is named for. Asserting on the values present
   rather than the exact array would keep it about clipping. Otherwise the tests use the
   public API and observable output throughout, and none of them reaches into buffering
   internals.

### Questions

1. Scope asks for the converter to emit "chunks of roughly 100ms", and the implementation
   delegates cadence to the caller's buffer size instead. The reasoning in the handoff is
   sound, and no acceptance criterion tests cadence, so I am not raising it as unmet. The
   question for the lead is whether the 100ms obligation is now explicitly the macOS capture
   layer's, because `AVAudioEngine` treats the `installTap` buffer size as a hint and
   commonly returns larger buffers than requested. If nobody owns it, chunk size drifts to
   whatever the audio hardware happens to do, which changes how quickly partials reach the
   overlay.
2. `convert` takes interleaved samples, but the input node's default format in
   `AVAudioEngine` is non-interleaved. The contract is documented on `downmixToMono`, so this
   is only a note that workstream 5 must interleave, or request a mono format, rather than
   hand over a channel pointer. Worth confirming the lead wants that obligation left on the
   macOS side rather than the converter taking a channel-major buffer.
3. `Package.swift`, `Sources/`, `Tests/` and `.gitignore` are all untracked rather than
   staged. The lead's single workstream commit needs to `git add` them explicitly.

## Resolution

- Finding dispositions:
  - Required 1 (non-finite sample traps): accepted and fixed. A trap kills the app
    mid-dictation, and criterion 8 exists to stop bad samples doing damage. Clipping now
    happens before any arithmetic, so infinities clamp to full scale, NaN becomes silence
    and the interpolator can no longer manufacture NaN from `inf - inf`.
  - Optional 1 (documented output-length formula wrong below 16 kHz): promoted and fixed.
    Criterion 5 is defined in terms of the rounding the implementation documents, so a
    formula that disagrees with the loop at HFP rates is a real defect. The documentation
    now states `ceil((frames - 1) / ratio)`; the loop is unchanged.
  - Optional 2 (`Sendable`): promoted and fixed. The package layout is a seam this
    workstream freezes, and the macOS capture layer will hold a converter inside a tap
    closure. One word.
  - Optional 3 (multi-channel frame alignment): promoted as documentation only. The
    interleaved, whole-framed contract is now stated on `convert` where a caller reads it.
    Carrying a partial frame was rejected: `AVAudioEngine` delivers frame-aligned buffers,
    so it is machinery for a case that does not arise.
  - Optional 4 (`channelCount` precondition): promoted and fixed, for consistency with the
    rate check.
  - Optional 5 (no waveform-fidelity test): promoted and fixed. The reviewer is right that
    every prior test would pass with a resampler that dropped samples or sat a frame out of
    phase, because the streaming test compares the converter against itself. One ramp test
    asserting `out[n] == in[3n]` at 48 kHz closes the class, and honours the packet's
    "asserted against known waveforms".
  - Optional 6 (clipping test asserted an exact length): promoted and fixed. The test now
    asserts the clipped values rather than coupling to the held-back-final-frame decision.
  - Question 1 (100ms cadence): answered by the lead. The cadence is the macOS capture
    layer's obligation, not the converter's. The specification assigns chunking to the
    `AVAudioEngine` tap; the converter returns everything ready for the buffer it is handed.
    Recorded on the type and in the plan's decision log.
  - Question 2 (interleaved input): answered by the lead. Interleaving stays the capture
    layer's obligation, now documented on `convert`.
  - Question 3 (untracked files): handled by the lead when staging the workstream commit.
  - Nothing was rejected outright and no finding was deferred.
- Simplification/deletion pass: the remediation replaced the clamp inside
  `littleEndianInt16` with a single `clipped` helper applied at the point samples enter the
  arithmetic, rather than adding a non-finite special case beside the existing clamp. No
  wrappers, flags or compatibility paths were added. `.gitignore` is kept: `.build/` would
  otherwise be untracked noise in every later workstream's diff.
- Final verification: `swift build` (Build complete), `swift test --disable-xctest`
  (6 tests, exit 0) and `swift-format lint --recursive Sources Tests` (exit 0, silent), all
  rerun by the lead after remediation. `grep "^import" Sources/` shows Foundation only.

## Closure review

- Verdict: closed. All seven accepted findings are fixed in the working tree and no
  release-blocking defect was found in the fixes.
- Remaining required findings: none.
- Checks rerun by the closure reviewer: `swift test --disable-xctest` (6 tests, exit 0) and
  `swift-format lint --recursive Sources Tests` (exit 0, silent), both on the current
  working tree. `grep` over `Sources/` shows `import Foundation` only, so criterion 4 still
  holds.
- Fix verification, one line per accepted finding:
  - Required 1 (non-finite trap): fixed. `clipped` (`AudioConverter.swift:97`) maps
    infinities to full scale and NaN to zero before interpolation, and is applied to both
    interpolation operands, so nothing non-finite can reach `Int16(_: Float)`. The
    interpolated value is provably within full scale, since both operands are in [-1, 1] and
    `fraction` is in [0, 1), so the conversion cannot overflow either.
  - Optional 1 (output-length formula): fixed and independently checked. The documented
    `ceil((frames - 1) / ratio)` now matches the loop. Verified by running the built library
    from outside the package: 4000 frames at 8 kHz produce 7998 samples, and 4410 frames at
    44.1 kHz produce 1600, both exactly as the formula predicts.
  - Optional 2 (`Sendable`): fixed. `public struct AudioConverter: Sendable`.
  - Optional 3 (frame alignment): fixed as documentation. The interleaved, whole-framed
    contract is stated on `convert` and its consequence is named, not softened.
  - Optional 4 (`channelCount` precondition): fixed.
  - Optional 5 (waveform fidelity): fixed. `resampledValuesFollowTheInput` asserts
    `out[n] == in[3n]` over a 300-frame ramp, which fails on nearest-sample picking, the
    wrong operand pair or a one-frame phase error.
  - Optional 6 (clipping test coupled to length): fixed. `overloadedSamplesClip` now asserts
    values, and the non-finite case it gained asserts the three samples the contract requires
    rather than an incidental length.
- Defects introduced by the fixes: none found. Interpolation still cannot index outside its
  window, because only one frame is ever needed behind the current position and that frame is
  the carried one; an empty downmix returns early and leaves `carriedFrame` intact.
- Still open for the lead, unchanged from the review and not a blocker: `Package.swift`,
  `Sources/`, `Tests/` and `.gitignore` remain untracked and need an explicit `git add` in
  the workstream commit.
