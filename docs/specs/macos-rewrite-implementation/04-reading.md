# Workstream 4: Own reading lifetime

Status: not started.

## Task packet

### Outcome

Reading owns text acquisition, speech request, decoding, queued playback and cleanup. Pause has a bounded buffer policy; stop/replacement cannot leave old playback, levels or clipboard work affecting another operation.

### Scope

Replace `Reader`'s constructor-started unstructured lifetime with an explicit operation owned by the accepted coordinator. Use the clipboard API from 2, joining any necessary Copy/restoration cleanup before replacement or dictation takeover. Stop playback promptly while required clipboard cleanup finishes.

Use typed startup/playing/paused/failure presentation derived from the operation. Show startup immediately, including while selection or the request is pending. Space during startup remembers pause, and autorepeats do not toggle repeatedly. Preserve Escape/read-aloud stop and dictation takeover.

Decode PCM away from the main actor. Bound player scheduling by queued duration; start with a small named limit, record it and test that pause does not increase it without limit. Network ingestion must backpressure or stop accumulating rather than hide an unlimited byte queue elsewhere. Preserve sample-rate/chunk-boundary correctness and text capping.

Own request cancellation, player stop, all scheduled buffers and completion. Stopping a paused player or cancelling during a playback-completion await must resolve the operation without a hanging continuation. Old callbacks must not alter another reading's UI. Failures reach the existing overlay/menu path.

Keep the current notification entry point functioning with existing admission behavior until 5 changes its public reply contract. Do not create a temporary acknowledged transport or stub just for the next packet.

### Non-goals

No new voices, provider/model changes, audio cache, UI redesign, MCP request/reply work or changes to accepted clipboard/dictation contracts. Avoid a generic media pipeline or class hierarchy.

### Initial ownership

- `Sources/EchoTypeApp/Reader.swift`, `SpeechPlayer.swift`, focused new reading types and accepted coordinator reading integration.
- `Views/Pill.swift`, `PillView.swift`, `PillDemo.swift`, `App.swift` only for reading presentation/state consumers.
- `Sources/EchoTypeCore/TTS/PCMDecoder.swift` only if meaningful decoding changes are necessary; preserve its fixtures.
- `Tests/EchoTypeAppTests/ReadingOperationTests.swift`, `SpeechPlayerTests.swift`, relevant core PCM tests.
- Decision record 0018 and affected 0009/index, this record, row 4/G5 and escalations.
- Consume accepted clipboard and coordinator contracts from 2/3. Do not redesign them silently.

### Required seams

The handoff publishes reading creation/run/stop/pause/completion behavior, presentation and how the coordinator reserves a replacement for immediate startup after cleanup. MCP in 5 calls that coordinator admission boundary. Keep text sources typed, with selection acquisition separate from supplied text. Tests substitute request data and player completion without opening audio hardware or reaching xAI.

### Acceptance criteria

- Spec case 10 passes at startup, selection Copy, request, playing, paused and completion boundaries.
- Stop cancels the request and clears playback; repeated stop is harmless. Replacement never inherits old levels, pause or completion.
- Space repeat and dictation takeover obey the command table. Selection failure and non-2xx/network errors remain visible.
- Queued duration stays within the documented limit while paused and while the response arrives faster than playback.
- Existing PCM and speech-cap behavior is preserved. Reading/Test do not replace Last Dictation.
- G5 passes on the signed candidate. Duplicate reading presentation state and old fire-and-forget lifetimes are removed.

### Targeted verification

```sh
XAI_API_KEY= swift test --filter 'ReadingOperationTests|SpeechPlayerTests|pcmSplitAnywhere|pcmByteByByte|speechCap'
swift build --product EchoTypeApp
./scripts/build-app.sh debug .build/EchoType-workflow.app
git diff --check
```

Create the named app suites; confirm selected tests with `swift test list`. Supply deterministic PCM and controllable playback completions. Test timeout/stop without a real audio device. For G5 record selection, pause, replacement and dictation takeover on the signed build; ask before billed playback if it requires a live xAI request.

## Implementation handoff

- Base commit: TBD
- Outcome: TBD
- Files changed: TBD
- Reading/coordinator declarations used by MCP: TBD
- Playback limit and enforcement: TBD
- Decisions: TBD
- Verification: TBD
- Known limitations or external checks: TBD
- Specification drift: TBD

## Independent review

- Reviewer: TBD, lead subagent
- Verdict: TBD
- Required findings: TBD
- Optional observations: TBD
- Questions: TBD

## Resolution

- Finding dispositions: TBD
- Simplification/deletion pass: TBD
- Final verification: TBD

## Closure review

- Verdict: TBD
- Remaining required findings: TBD

## External validation

- Gate and placement: G5, after closure before acceptance
- Status: Pending
- Candidate and instructions: Record signed selection/empty-selection behavior, pause during startup, paused Stop, back-to-back replacements, dictation takeover during Copy and cleanup, and playback-level ownership
- Required evidence: No stale playback/callbacks, prompt Stop, correct command handling and bounded pause queue
- Attempts and lasting decisions: TBD
- Resume condition: Signed behavior passes; required user interaction or live API authorisation supplied
