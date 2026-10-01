# 0024 One operation owns dictation through insertion

Status: accepted, 2026-09-30. Finishing ownership simplified and signed dictation smoke checks passed on 2026-10-01.

## Context

The old controller, session, client and relay split one lifetime across independent tasks. The session decoded each frame twice, the capture pump discarded send errors, hard-cap closure could overtake the final chunk, and Escape stopped working during finalisation. Waiting for a send before arming the timeout could hang indefinitely.

## Decision

- The main-actor coordinator reserves a `DictationOperation` synchronously and retains its top-level task. Each operation snapshots settings and owns its capture instance, transcription, revision, destination, insertion eligibility and trace. The coordinator also owns reading admission and replacement, as [0018](0018-read-aloud-audio-fetch.md) describes.
- `SessionMachine` keeps platform-neutral transcript assembly and timing. One `reschedule()` computes its single pending deadline from state: readiness before `transcript.created`, the sooner of silence and the hard cap while listening, the hard cap while paused, and the finishing deadline while finalising. `STTClient.run(observe:)` is the sole receive/JSON decode loop and passes typed events to that owner. The relay is deleted. Every ordered send awaits the preceding send's success; a failed audio frame prevents later closing frames from claiming completion.
- Calls only go down: the session decides when finishing begins, and the operation does how. `SessionMachine` never calls into its owner. The operation's one `finish()` routine, started at most once by the stop hotkey, reply-request detection or the hard cap's `finalizing` snapshot, runs in order: `beginFinishing()` arms the eight-second monotonic budget; the operation captures the destination and publishes finishing; it stops capture and joins the audio pump, draining the partial final chunk; then, unless cancelled during drain, `sendClosing()` sends `finalize` and `audio.done`. Once `sendClosing()` has begun, `transcript.done` completes the protocol, because the endpoint sends it only after `audio.done`; a `done` before then, or socket closure alone, is failure, and a closing-send failure before `done` fails the session. When `run()` returns for any reason, the operation stops capture, cancels the pump and finish routine, and joins both, so a stalled drain or send is released by the session ending.
- Readiness has five seconds after microphone/key setup and socket opening. System prompts have no network deadline. Audio queued before `transcript.created` is retained ahead of closing frames. Its finite limit is 160,000 bytes, five seconds of 16 kHz mono Int16 audio. Capture buffers twenty 100 ms chunks, two seconds. Overflow fails the session, which closes the socket and releases a suspended send rather than waiting for the pump to discover its stream error; capture then stops as the session ends.
- Escape sets the operation's cancellation presentation synchronously, stops capture and cancels its child work. It remains effective through drain and final revision, including queued success before the clipboard boundary. The clipboard service rechecks that signal and owns restoration after `onBegin`; the operation then advertises no Escape command.
- Live and final revision reuse one ephemeral network session with a five-second resource limit. Requests retain separate five-second and three-second request limits. A separate injected monotonic three-second final budget cancels the final task. Stop joins revision work while retaining the existing faithfulness, reply protection and fallback rules.
- The operation's observable presentation is the source for menu/pill state, including microphone readiness. Configured stop hints appear only when commit is available. The core no longer publishes an insertion state because it does not own the clipboard boundary.
- Destination readiness is advisory. The operation samples the existing conservative `DestinationFocus.capture()` before capture starts and discards the token to a Boolean. Identity-checked audio-level callbacks refresh that Boolean at most every 0.5 monotonic seconds, including silence. No observer, independent polling task or additional clock is needed. Starting takes precedence until microphone audio flows; then unavailable focus shows "Select an input" instead of Listening or Paused. Capture and network work continue normally. Entry to finishing still captures a fresh destination token, and Clipboard still owns insertion/Return revalidation. Readiness never authorises insertion. Dictation error text uses a 1.5 line-height multiple. Select an input and dictation's final minute show a fixed orange dot beside plain text, with the level glow turned orange; coloured text alone was illegible on light glass over dark windows.
- Test uses the same capture/transcription lifetime and its five-second clock, while ignoring dictation/read-aloud hotkeys and Escape. It creates no pill, destination-readiness probe, insertion or trace. A dictation records final text and the actual clipboard insertion/sending result separately.

## Consequences

Operation tests assert outcomes such as inserted text, sent frames, traces and released
resources. They hold a suspension only where needed to test a real drain, send or
revision stall. Protocol and transcript fixtures remain authoritative; tests tied only
to removed callback ordering were deleted. The finishing task is cancelled and joined
on teardown without a test solely pinning that internal structure.

The final deterministic suite passed 79 core and 61 app tests, and the release build
passed. Signed smoke checks passed normal dictation, stopping mid-sentence without
losing final words, Escape during Transcribing, and reply-request paste plus Return.
T3 Code's Accessibility compatibility requirement is recorded in
[0020](0020-pasteboard-insertion-and-selection-copy.md).

Earlier approved manual deferrals remain unverified: external-input fallback and
microphone disconnect, Bluetooth conversion, detailed Test controls and trace retention,
permission edges, fine-grained hints and alternate-theme error layout. These are
validation limits, not additional architectural requirements. CI has not run; see
[0019](0019-native-macos-app-and-core-boundary.md).

This record replaces lifetime/timing/presentation portions of [0004](0004-session-lifecycle.md), [0005](0005-microphone-per-session.md), [0009](0009-overlay-behaviour.md), [0012](0012-capture-with-avcapturesession.md) and [0021](0021-revise-committed-dictation.md). Their observations, chosen-device fallback, conversion and text rules remain in force.
