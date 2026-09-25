# Batch pass on commit

A second transcription of the whole recording, run when the user stops, whose text is
inserted instead of the streamed text.

Status: drafted and implemented 2026-09-25.

## Problem

Dictation often comes out as short sentences split by false full stops. The streaming
endpoint punctuates what it has heard so far and can't wait to hear what comes next, so
it often ends a sentence at a thinking pause. Raising `endpointing` from 2000 to 5000
made little difference.

The batch endpoint hears the whole recording in one pass, and punctuates across pauses
much better. EchoType keeps streaming for the pill and inserts the batch text.

## Confirmed by hand

A 16 second clip with long pauses inside each phrase, sent with `format=true` and
`language=en`, came back as one sentence with commas at the pauses. The response took
well under a second. Dictations are expected to stay under a minute.

The response:

```json
{
  "text": "So, um, I think we should ship the settings window today, and then look at the pill tomorrow.",
  "language": "en",
  "duration": 15.851,
  "words": [{ "text": "So,", "start": 0.921, "end": 1.081, "speaker": 0 }]
}
```

Only `text` is used.

Not confirmed:

- The request had no `filler_words` parameter, and "um" came through. The streaming
  URL sends `filler_words=false`; the batch request sends it too, and it is assumed to
  work the same way.
- `keyterm` was not tried on batch. The batch request sends the keyterms the stream
  sends. If batch rejects the parameter with a 400, every pass falls back silently, so
  checking this is part of the manual checks below.

## Behaviour

- A setting in the General tab, on by default: **Re-transcribe on stop**, with the
  caption "Better punctuation, slower insertion".
- With it off, nothing changes from today.
- With it on, dictation looks the same until the user stops. The pill stays on
  `Transcribing` with the live text visible while the batch request runs. The pill does
  not show the batch text. When the batch text arrives, EchoType inserts it and the pill
  closes.
- If batch fails, times out or returns empty text, EchoType inserts the live text. The
  pill shows no error, because the user still gets their text, just with the old
  punctuation.
- The pass runs only when the session's outcome is `.insert`. A cancelled, empty or
  failed session behaves as it does today.
- The Test button in Settings is unchanged. It still checks only the streaming path.
- Escape and the hotkey do nothing during the pass, as during `finalizing` today. The
  timeout limits the wait.

## Implementation

### Core

`Sources/EchoTypeCore/STT/BatchTranscriber.swift`:

- `static func wav(pcm: Data) -> Data` puts a 44-byte RIFF header on 16 kHz mono Int16
  PCM, the format `AudioChunker` already produces.
- `static func request(wav: Data, settings: Settings, apiKey: String) -> URLRequest`
  builds the `POST https://api.x.ai/v1/stt` multipart request. It sends `format=true`,
  `filler_words=false`, `language` and the keyterms, capped as in `STTConnection`, then
  `file` last, because the endpoint requires `file` to be the last field.
- `static func transcribe(pcm: Data, settings: Settings, apiKey: String) async throws ->
  String` sends the request on a `URLSession` whose `timeoutIntervalForResource` is the
  timeout, and decodes `text`. It throws on any non-2xx status, using
  `STTError(httpStatus:)`.

The timeout is a constant in `BatchTranscriber`, 5 seconds. A one-minute dictation
should take a second or two, so the timeout only comes into play when something has gone
wrong. `timeoutIntervalForResource` limits the whole request.
`URLRequest.timeoutInterval` only limits the time between packets.

`Settings` gets `batchOnCommit: Bool = true`, persisted under the key `batchOnCommit`
and decoded independently like the other fields, as set out in
[0010](../decisions/0010-settings-storage-and-api-key.md).

### App

In `DictationController`:

1. `pump` also appends each chunk to a local `Data` and returns it with the audio
   failure. It sees every chunk the session sent, including those buffered before
   `listening`. The recording is held in memory only, for the length of the session. A
   minute is about 1.9 MB.
2. `Start.started` also carries the API key that `start` already reads, so the pass
   doesn't read the Keychain a second time.
3. In `dictate()`, between `run` and `finish`: if `settings.batchOnCommit` is on and
   the outcome is `.insert(live)`, call `BatchTranscriber.transcribe`. On success with
   non-empty text, replace the outcome with `.insert(batch)`. On anything else, keep
   `live`.

The pill needs no changes. When `run` returns, the last snapshot has already put it in
`transcribing`, and `Pill.apply` ignores the `idle` state that follows. The menu bar
shows `idle` during the pass, which lasts about a second.

`SessionMachine` doesn't change. The pass comes after the session's outcome, so the
session lifecycle in [0004](../decisions/0004-session-lifecycle.md) stays as it is.

### Settings window

Add a `Toggle` bound to `store.settings.batchOnCommit` in `GeneralTab`, after
`LanguageRow`, with the caption in secondary text like the Login Items hint.

## Tests

- `BatchTranscriber.wav` output read back by the existing `WAVRecording` test helper has
  a 16 kHz rate, one channel, and the same samples.
- The multipart body built by `request` has the parameters above and puts `file` last.
- `SettingsTests`: extend the pinned stored payload with `batchOnCommit`, and check that
  a payload without the key decodes to `true`.

No test for the fallback wiring in the controller. It is a few lines in the app target,
which has no tests, and it's quick to check by hand.

## Checking it on the Mac

1. `swift test`.
2. With some keyterms set, dictate speech with long pauses. The inserted text should be
   one joined-up sentence with no "um". If it still looks fragmented, batch is failing
   and the live text is being used. The likely cause is a parameter batch rejects, so
   try it with curl.
3. Watch the spinner after a one-minute dictation.

The fallback to the live text isn't checked by hand. Making batch fail while streaming
still works would need a switch added only for the check, and the fallback is a few
lines that review can confirm by reading.

## When done

Write a decision record for the batch pass and add it to the index in
`docs/decisions/README.md`. Re-transcribing during the session and an LLM pass are out
of scope.
