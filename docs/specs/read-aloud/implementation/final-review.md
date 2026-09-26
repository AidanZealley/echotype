# Read aloud whole-feature review

Status: accepted, 2026-09-26.

## Reviewer task packet

Review the full branch against the starting commit in `plan.md` and the approved
[specification](../../read-aloud.md). Read the accepted handoffs in
[01-speech-core.md](01-speech-core.md) and [02-read-aloud-app.md](02-read-aloud-app.md) and
decision 0018, then review the combined diff and surrounding code independently.

Check:

- Every item in the specification's Behaviour, Implementation and Tests sections is delivered for
  the branch 0018 chose, or its drift is in the plan's decision and drift log.
- The seam between the workstreams: the PCM format and sample rate defined once in `Speech`, one
  `PCMDecoder` per reading, the auth header reused from `STTConnection`, and the cap applied
  before the request.
- Lifecycle: stopping by hotkey, Escape, click and a dictation start all cancel the fetch and stop
  the player; a reading that ends on its own fades the pill; the Keychain is read once per
  reading; the pasteboard is restored after the copy; `Inserter`'s supersede logic still holds.
- Hotkey routing: both hotkeys and Escape reach the right owner in every controller phase,
  including a test.
- Settings storage: the stored key names, independent decoding, and decision 0010.
- Machinery the specification does not ask for: retries, logging, network mocks, unused
  branches of the rejected fetch path, extra state or options.
- Test quality: the tests protect the request fields, the frames if used, split-sample decoding
  and the stored settings, not implementation details.
- Documentation agreement: decisions 0018 and 0010, the index, decision 0009 if the pill's
  behaviour changed, doc comments in the app target, and the specification's status.

Run `swift build` and `swift test`. Do not launch the app or change settings; G2 covered it.
Classify evidence as Required, Optional or Question, and name the owning file for each Required
finding.

## Initial whole-feature review

- Reviewer: fresh whole-feature review agent, 2026-09-26.
- Branch, base, and reviewed head: `feat/read-aloud`, base `8a47832`, head `cdcabce`
  (`git diff 8a47832..HEAD`, 24 files). The uncommitted edits to `plan.md` and this file are
  workflow records, not reviewed code.
- Verification run: `swift build` completes. `swift test`: 52 tests pass. The app was not
  launched and no settings were changed.
- Acceptance-criteria audit:
  - Behaviour: the Read Aloud tab has the hotkey (⌥S, ⌃⌥S), voice (Ara, Altair) and speed
    (0.7 to 1.5, step 0.1) settings (`SettingsView.swift:61-89`). The hotkey copies the
    selection and reads it under a `Reading` pill with a stop hint (`DictationController.swift:113-132`,
    `PillView.swift:19`). The hotkey, Escape and a click stop it (`:127-128`, `:140-142`,
    `:161`). Audio ending fades the pill (`read(_:)`, `:356-363`, calls `end()` with no error).
    "Nothing selected" is an error pill. The 60,000 cap and its notice are at `Reader.swift:54-55`
    and `DictationController.swift:365-369`. The dictation hotkey stops a reading and starts
    dictating (`:102-108`). The read-aloud hotkey is ignored during a dictation or a test
    (`:129-130`). Errors reuse dictation's wording (`:418-451`). Reading uses the General tab's
    `language` (`Speech.swift:49`).
  - Branch 0018 (REST): one `POST /v1/tts` with `optimize_streaming_latency: 0` and
    `text_normalization: false` (`Speech.swift:32-56`). `URLSession.bytes(for:)` is gathered
    into 100ms buffers (`Reader.swift:16,66-75`). No socket code was added.
  - Seam: `Speech.sampleRate` is the only rate. `SpeechPlayer` and `Reader.bufferBytes` both
    use it, and `"pcm"` appears only in `Speech`. There is one `PCMDecoder` per reading
    (`Reader.swift:66`). Auth comes from `STTConnection.headers(apiKey:)` (`Speech.swift:38`).
    The cap is applied before the request (`Reader.swift:54-57`).
  - Lifecycle: `Reader.stop()` cancels the task, which ends `bytes`, and stops the player at
    once. The Keychain is read once per reading (`Reader.swift:51`). The pasteboard is restored
    inside the uncancellable copy (`Pasteboard.swift:39-64`). `Inserter` keeps its
    `pending.before + 1` supersede check and uses only the extracted save and restore.
  - Hotkey routing: I traced all six controller phases for both hotkeys, Escape and click,
    including `.testing`. Each reaches the owner the specification names. `test()` refuses
    while reading through `isIdle`.
  - Settings: the keys `readAloudHotkey`, `voice` and `speechSpeed` each decode on their own
    (`Settings.swift:163-168`), are pinned in `SettingsTests.storedValueDecodes`, and default
    when missing. Decision 0010 lists them.
  - Machinery: none beyond the specification. There are no retries, logging, network mocks
    or leftover socket paths.
  - Tests: the request fields (including a 7-key body check), split-sample decoding at every
    offset, and the stored settings are all protected. The tests check behaviour, not internals.
  - Documentation: decision 0018, the index entry, the 0010 keys and the 0009 click, meter and
    tap-callback notes all match the code. The specification's status says implemented.
    One contradiction remains (R1).
- Required findings by owner:
  - R1 (`docs/specs/read-aloud.md`). Line 133 says "The level glow stays at zero while
    reading." That contradicts the approved drift (plan.md drift log; E2 and E3) and the code:
    `PillView.swift:165,183` animate the glow for `.reading` at opacity 0.4, and
    `DictationController.swift:124` feeds it playback levels. Fix: say the glow and meter
    follow the audio as it plays, on dictation's scale. `02-read-aloud-app.md:36` still has the
    old packet wording, but that packet is frozen and its handoff records the drift, so leave it.
- Optional observations:
  - O1. `readAloudPressed()` builds the `Reader` inside the event tap callback. That builds a
    `SpeechPlayer`: `AVAudioEngine()`, `mainMixerNode`, `connect` and `installTap`
    (`SpeechPlayer.swift:15-26`). This is Core Audio setup on the tap's thread, on top of the
    Accessibility lookup that 0009 records. Decision 0009 says the callback only changes the
    phase, and it notes only the screen lookup. G2 showed no lag. A cheap fix is to create the
    player in `Reader.read` just before `start()`.
  - O2. Unmapped statuses read badly in the pill. `"xAI error: \(error)"`
    (`DictationController.swift:446`) renders a 500 as `xAI error: unexpectedStatus(500)`,
    and a 413 or 502 as the raw case name.
  - O3. There is no backpressure (carried over from workstream 2's Q1). The response arrives
    about 5x faster than real time (0018: 103s of audio in 20s), and every chunk is scheduled
    on arrival. A full 60,000-character reading is roughly 50 minutes of audio, so up to
    about 300 MB of Float32 buffers could be queued. That is acceptable for a rare maximum
    and matches the specification's "scheduled as it arrives". Worth knowing, not fixing now.
  - O4. The doc comment at `Pill.swift:3-5` breaks mid-sentence after "build a `Pill` and".
    Rewrap it.
  - O5. If ⌥S is pressed within 0.8s of an insertion, the reading's copy bumps `changeCount`,
    so `Inserter`'s pending restore skips (`Inserter.swift:29,46`). The reader then restores
    the transcript, not the user's earlier pasteboard. It is a narrow window and the
    specification does not cover it.
- Questions: none.
- Verdict: one Required documentation fix (R1). The code meets the specification for the REST
  branch and has no correctness defects. Accept once R1 is corrected.

## Lead triage

- Accepted findings and owners:
  - R1 (`docs/specs/read-aloud.md`): bring the `.reading` line in line with the approved glow
    drift. Leave the frozen packet's wording; its handoff records the drift.
  - O4, promoted (`Sources/EchoTypeApp/Views/Pill.swift`): rewrap the broken doc comment. The
    brief asks for doc comments that read correctly, and the fix is one line.
- Rejected findings and reasons: none.
- Deferred optional observations:
  - O1: building the player in the tap callback is setup only, the engine starts later, and G2
    showed no lag. Moving it is a refactor without a user-visible defect.
  - O2: reading's wording for an unmapped status matches dictation's, which the specification
    asks for ("worded as for dictation"). Better copy for both is separate work.
  - O3: no backpressure matches the specification's "scheduled as it arrives". Revisit only if
    long readings show memory pressure.
  - O5: a reading started within 0.8s of an insertion restores the transcript. The window is
    narrow and the specification does not cover it.
- Drift requiring user decision: none. The glow drift was approved by Aidan at G2 (E2, E3).

## Focused closure

- Reviewed head: `cdcabce` plus the uncommitted edits to `docs/specs/read-aloud.md` and
  `Sources/EchoTypeApp/Views/Pill.swift` (`git diff -- docs/specs/read-aloud.md Sources/`).
  Fresh closure reviewer, 2026-09-26. `swift build` completes. `swift test`: 52 tests pass. The
  app was not launched.
- Finding outcomes:
  - R1: fixed. `read-aloud.md:133-134` now says "The level glow and meter follow the audio as
    it plays, on dictation's scale." That matches the code: `PillView.swift:165,183` animate the
    glow for `.reading`, the meter rises for `.reading` (`PillView.swift:51,68`),
    `DictationController.swift:124` feeds playback levels to the pill, and `SpeechPlayer`
    scales them with dictation's `Overlay.level(rms:)` (`SpeechPlayer.swift:62`). It also
    matches the approved drift in the plan's log (E2, E3). No other line in the specification
    still says the glow stays at zero.
  - O4 (promoted): fixed. The `Pill` doc comment (`Pill.swift:3-5`) now reads as one sentence.
    The change is comment-only.
- Final simplification assessment: the corrections are one specification line and one comment
  rewrap. They add no code, state or machinery. Nothing further to remove.
- Remaining blockers: none.
- Verdict: closed. Both accepted findings are fixed, the wording matches the code, and nothing
  new blocks release.

## Completion record

- Final verification: `swift build` succeeds and `swift test` passes 52 tests with the
  corrections applied.
- External validation pending: none. G1 and G2 passed; the corrections change only a
  specification line and a doc comment.
- Specification drift: the pill's glow and meter follow the audio while reading (approved at
  G2, E2 and E3). The specification's `.reading` line now says so.
