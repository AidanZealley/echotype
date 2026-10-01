# 0018 Read aloud fetches audio over REST

Status: accepted, 2026-09-26 (read aloud gate G1).

## Context

Read aloud needs audio to start playing soon after the hotkey, even for a long selection.
`POST https://api.x.ai/v1/tts` returns raw audio bytes, but the docs don't say whether it
sends them while it is still generating. If it doesn't, reading has to use the WebSocket,
`wss://api.x.ai/v1/tts`. Two request settings were also open: `optimize_streaming_latency`,
which the docs say changes the first chunk's size, and `text_normalization`.

Aidan ran the specification's spike on the Mac on 2026-09-26, with voice `ara`, 16-bit PCM
at 24 kHz and `curl --trace-time`. Times are from the request being sent.

## Evidence

- **REST streams.** Long prose, about 1,900 characters: request sent 07:54:18.627, first
  audio bytes 07:54:19.213 (+0.59s), last 07:54:39.429 (+20.80s), 4,934,304 bytes, about
  103 seconds of audio. A Markdown sample of about 600 characters: first bytes +0.35s,
  last +11.92s. The headers were not captured separately; the first data arrived with them.
- **`optimize_streaming_latency`.** On the long prose, first audio at +0.59s without it and
  +0.58s with `"optimize_streaming_latency": 1` (last bytes +20.26s). No measurable gain,
  and the prose sounded better without it.
- **`text_normalization`.** On a selection of Markdown, code and a URL there was little
  difference. Without it the voice read the `ts` hint on a code fence aloud. With it the
  voice read the bold "**Note:**" as "negative note", and first audio came about 0.35s
  later.

## Decision

- Reading fetches audio with one `POST /v1/tts` and plays the bytes as they arrive. The
  WebSocket is not used.
- The request sends `"optimize_streaming_latency": 0` and `"text_normalization": false`
  explicitly, rather than omitting them, so a change to the endpoint's defaults can't
  change reading, and the tests can pin both.
- The xAI voice adapter, `XAI.voice` in `Providers/XAI/`, builds the request, streams the
  response and maps a non-2xx status with `XAI.error(httpStatus:)`. Speed uses the shared
  Settings validation policy before it reaches the request. Nonfinite or out-of-range values
  fall back to 1.0; valid fractional values survive unchanged.
  See [0010](0010-settings-storage-and-api-key.md).
- Read Aloud has its own Opt+S or Ctrl+Opt+S hotkey, Ara or Altair voice, and speed
  from 0.7 to 1.5. It uses the General tab's language. The reading hotkey or
  Escape stops playback. Space pauses or resumes it. The dictation hotkey stops playback and
  starts dictation. A reading press during dictation or a settings test is ignored.
- Copy the focused selection through the pasteboard as [0020](0020-pasteboard-insertion-and-selection-copy.md)
  describes. An empty copy shows "Nothing selected". Audio plays as 24 kHz mono
  PCM in roughly 100 ms buffers. The pill's meter and glow follow playback on
  dictation's level scale.

## Consequences

- Time to first audio from the endpoint was about half a second in the spike, before the
  app's playback buffering.
- Markdown and code are read as written, fence hints included. Cleaning them up is out of
  scope.
- A reading is capped at the REST limit of 60,000 characters. The pill no longer names
  the cut (removed 2026-09-28, see decision 0008). The cap was not exercised with a real
  selection at G2.

## G2 on the Mac

Aidan checked the finished app on 2026-09-26. Reading passed every check, including a
reading with the `en-GB` language tag, which the endpoint accepted. Time to first audio
from the hotkey was under half a second and felt instant. The 60,000-character cap was not
exercised with a real selection.


## Accepted lifecycle rewrite, 2026-09-30

`Reader` is now created without starting work. The coordinator reserves it synchronously,
retains its `run()` task and joins that task before a replacement or dictation acquires
resources. Each replacement starts with its own pause, levels, request, decoder and player.
Stopping releases playback and the request immediately, while the accepted Clipboard
service finishes any posted Copy response window and restoration. Rapid replacements
retain the whole predecessor join chain.

The operation publishes starting, playing, paused, failed or stopped presentation.
Starting appears while selection and request work are pending. Space remembers pause
before the first audio arrives; repeat events are consumed without toggling. The menu and
pill derive reading state from the operation. Identity checks reject old level and
presentation callbacks. Reading does not replace Last Dictation.

Playback schedules at most 12,000 frames, 500 ms of 24 kHz mono audio including the
playing buffer. A producer waits for played-buffer completion before scheduling more.
Pause leaves that limit in place. Stop and task cancellation resolve both capacity and
playback-completion waits, including while paused. PCM decoding runs on a separate actor,
using the existing decoder and sample-boundary fixtures. Decode chunks remain 100 ms.

The REST adapter uses a dedicated serial URLSession delegate queue. Each delivered
callback is split into at most 65,536-byte pieces. Four capacity slots limit queued
application copies to 262,144 bytes, with one consumer-held piece adding at most
65,536 bytes. These copied response buffers together use at most 327,680 bytes,
plus the 500 ms playback queue and the 100 ms decode working set. The callback
waits for capacity before copying another piece. Pause therefore backpressures
intake; Stop cancels the session, discards queued copies and wakes the callback.

Foundation owns the original callback data and its internal networking buffers.
Their size is outside the copied-buffer bound; this is not a total-process memory
guarantee. Independent localhost testing with no consumer kept URLSession's
received-byte count flat for six seconds while a 64 MiB producer stalled, then
cancellation released it. This establishes backpressure on the tested Mac.

This policy replaces the first candidate's task-suspension and callback-overflow
policy. Aidan observed a real overflow on that signed candidate. A local response
sent in 32 KiB pieces reproduced a 440,964-byte URLSession callback after
suspension. The previous adapter confused callback size with queue size and
failed valid speech. The corrected adapter accepts larger callbacks through its
bounded pieces rather than raising that failure threshold. Independent focused
review and targeted tests pass; Aidan subsequently confirmed signed selected-text playback of the correction.

Focused tests use fake playback completions and a socket-free URLProtocol. They cover
replacement across Copy, request, playback, pause and completion; Space repeats; cancelled
dictation takeover; rapid replacements; finite response buffering; HTTP, network and
inactivity-timeout errors; and task cancellation. HTTP timeout errors propagate from
URLSession's existing request policy. No new whole-reading duration limit is added.
The REST settings, text cap, voices, speed, language and PCM format remain unchanged.
Incoming speech uses the acknowledged admission policy in
[0022](0022-voice-replies.md).

Signed checks passed selection playback and clipboard restoration, empty-selection
feedback, playing pause/resume, paused Escape, remembered startup pause and held-Space
repeat handling. A rapid replacement check established newest-only audible startup
supersession. Reviewed deterministic tests cover cleanup and isolation at the other
replacement boundaries.

Signed replacement during pending Copy and paused-reading dictation takeover were
explicitly deferred. Audible-first interruption and replacement pause/level checks
remain unverified. The saturated-queue cancellation fixture acknowledges producer entry
rather than the actual capacity wait; an independent stalled-consumer localhost probe
established that cancellation releases the blocked callback. No production observation
hook was added solely for that fixture.

## Provider adapters, 2026-10-01

Reading now goes through the neutral `VoiceService` in `Providers/Provider.swift`. `Reader`
caps the text with the service's `maximumCharacters`, builds a `SpeechRequest` (text,
voice id, validated speed, language and credential) and pulls `SpeechAudio` from the
`SpeechStream` that `speak` returns. It no longer builds requests or decodes PCM.
`SpeechPlayer` takes its format, its 100 ms level tap and its 500 ms queue limit from the
first chunk's sample rate instead of a constant.

The xAI adapter keeps everything above unchanged: one `POST /v1/tts` with the same body,
the voices Ara and Altair, the 0.7 to 1.5 range, the 60,000-character cap and 24 kHz
16-bit PCM. The bounded streaming body is `StreamingResponse` in `Providers/HTTP/`, with
the same 64 KiB pieces and four capacity slots, and maps a failed status through the
provider's mapping. The xAI stream is an actor, so decoding stays off the UI actor. It
takes the next body piece only after yielding the last 100 ms chunk of the previous one, so
the copied-buffer bound and backpressure described above are unchanged: while playback is
paused the reader stops pulling, the stream stops taking pieces and the body's callback
waits for capacity. A stream promises chunks of at most 100 ms with one sample rate.
`Settings.speechSpeedRange` duplicates the xAI range until reading choices are stored per
provider.
