# SessionMachine finishing redesign

Status: proposed, 2026-10-01. Not started. This is the last part of the macOS lifecycle rewrite. It lands on `refactor/macos-lifecycle`, which then merges to `main` as one complete rewrite.

## Problem

The lifecycle rewrite fixed real ordering bugs. When a dictation ends, captured audio is drained before the closing frames, a stalled drain or send is bounded by the finishing deadline, and every failure reaches its owner. The cost is that ending a session is now the hardest code in the app to read.

Two objects share the ending:

- `SessionMachine`, an actor in `EchoTypeCore`, owns the socket, transcript, timers and outcome.
- `DictationOperation`, on the main actor in `EchoTypeApp`, owns capture, the audio pump, revision, destination and insertion.

A session can end from three places: the user's stop (in the operation), the hard cap (a session timer) and failures (either side). Drain belongs to the operation but has to happen before the closing frames, which belong to the session. So the session calls back up into the operation through `onFinishing` and `onAbort`, and the operation calls down into the session. To keep those calls once-only and joinable, the session holds four task handles (`finishingEffect`, `abortTask`, `finishingTask` and `closingSend`) plus `hasRun` and an early-ending path in `run()`. `conclude` awaits five of them in a specific order.

Separately, the readiness timeout, the silence and hard-cap deadline and the finishing deadline share one replace-on-schedule `SessionClock` slot. Each one is scheduled from a different method and silently replaces the last, so you can only see which deadline is live by tracing every call site.

The tests mirror this. The `DictationOperationTests` harness has 11 gates and about 20 counters, and many tests hand-drive exact interleavings. Any change to the order breaks them, even when behavior is unchanged.

## Goal

One place sequences finishing, and calls only go down. Behavior stays identical to the accepted rewrite.

## Design

### The session decides when; the operation does how

`SessionMachine` stops calling into its owner. Remove `onFinishing`, `onAbort` and the four task handles.

The public surface becomes:

- `run() -> Outcome`: the single receive loop, as now.
- `send(audio:)`: as now. It fails the session on a send error.
- `beginFinishing()`: synchronous within the actor. It moves to `finalizing` and arms the finishing deadline, and is idempotent.
- `sendClosing()`: waits for readiness if audio is held, then sends `finalize` and `audio.done` in order behind the queued audio.
- `cancel()` and `fail(_:)`: as now.
- `snapshots`: as now. When the hard cap fires, the session calls `beginFinishing()` itself, and the resulting `finalizing` snapshot is the operation's cue.

`DictationOperation` owns one `finish()` routine, started at most once from any of three places: the stop hotkey, reply-request detection or a `finalizing` snapshot it didn't request. In order:

1. `await session.beginFinishing()`. The deadline covers everything after this point, which preserves decision 0024.
2. Capture the destination, then publish `.finishing`.
3. Stop capture and await the pump draining its remaining chunks.
4. `await session.sendClosing()`.

`transcribe` awaits `session.run()`. When `run()` returns, for any reason (finalised, deadline, failure or cancel), the operation stops capture, cancels the pump and the finish routine, and joins both. This replaces `onAbort`: a stalled drain or send is released because the session ended, not because the session reached back into the operation.

### `transcript.done` without the closing-send task

Today, `done` during finalisation waits on `closingSend` so a failed closing send can't be reported as finalised. The endpoint sends `transcript.done` only after it has received `audio.done`, so once `done` arrives the protocol has completed, whatever the local send call later reports. The rule becomes one `closingStarted` flag, set when `sendClosing()` begins:

- `done` while `closingStarted` is set counts as `finalised`.
- `done` at any other time is `closed`.
- A closing-send failure before `done` fails the session, as it does today.

### One deadline function

Replace the scattered `clock.schedule` calls with `reschedule()`, which computes the single next deadline from state:

- Starting, not yet ready: the readiness deadline.
- Listening: the earlier of the silence timeout and the hard cap.
- Paused: the hard cap.
- Finalizing: the finishing deadline recorded at `beginFinishing()`.

Every state change calls it. `SessionClock` keeps its one-slot contract.

### Tests

- Rewrite the operation harness around outcomes: the inserted text, the order of sent frames, the trace, and which resources were released. Use a fake transport, a manual clock and a capture stream the test controls. Only add a gate where a test has to hold a specific suspension, such as a stalled drain or send.
- Keep `SessionMachineTests` and `STTClientTests` where they assert observable protocol and transcript behavior, and delete tests that only pin internal task ordering.

## Behavior to preserve

Each item needs a deterministic test after the redesign:

- Explicit stop, reply-request stop and hard cap all drain captured audio, including the final partial chunk, before `finalize` and `audio.done`.
- The finishing deadline (`Settings.finalizeTimeout`) starts when finishing begins. It covers drain, closing sends and `transcript.done`. When it expires, the session fails with its committed text preserved.
- A stalled binary send, closing send or capture drain ends within the finishing deadline and releases capture.
- Readiness: no `transcript.created` within five seconds fails the session. Audio held before the handshake is bounded at five seconds and sent in order once ready.
- Capture overflow and send failures fail the session with committed text preserved, and never send Return automatically.
- Escape cancels through drain and final revision. After the clipboard boundary, insertion owns completion.
- The destination is captured fresh when finishing begins, never from the advisory readiness probe.
- An unrequested `transcript.done` or socket close while listening is `closed`, with the committed text in the failure.
- Test mode keeps its five-second timer and has no overlay, insertion or trace.

## Scope

In scope: `SessionMachine.swift`, `STTClient.swift` where `sendClosing` needs it, `DictationOperation.swift`, and their tests.

Out of scope: clipboard, destination, reading, MCP, `TranscriptAssembler`, `Reviser`, settings and presentation. Any change to the presentation enums is limited to what `finish()` publishes.

## Acceptance

- `onFinishing`, `onAbort`, `finishingEffect`, `abortTask`, `finishingTask` and `closingSend` are gone. `conclude` joins nothing owned by the operation.
- Every item under "Behavior to preserve" has a passing deterministic test, and the full suite and release build pass.
- The operation test harness is clearly smaller, with fewer gates and counters than today's 11 and about 20.
- Signed smoke check on the Mac: a normal dictation, stop mid-sentence (no lost final words), Escape while Transcribing, and one reply request.

## Process

Implemented through the workflow in [session-machine-redesign-implementation](session-machine-redesign-implementation/README.md): outcome tests first, then the ownership change, then one whole-feature review and a Mac smoke check.
