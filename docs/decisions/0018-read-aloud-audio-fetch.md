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
- `Speech.request(text:settings:apiKey:)` in `EchoTypeCore` builds the request. The app
  streams the response and maps a non-2xx status with `STTError(httpStatus:)`.

## Consequences

- Time to first audio from the endpoint was about half a second in the spike, before the
  app's playback buffering.
- Markdown and code are read as written, fence hints included. Cleaning them up is out of
  scope.
- A reading is capped at the REST limit of 60,000 characters.
