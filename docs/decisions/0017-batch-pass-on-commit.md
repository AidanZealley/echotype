# 0017 Re-transcribe the whole recording when a dictation stops

Status: accepted, 2026-09-25.

## Context

Dictation often came out as short sentences split by false full stops. The streaming
endpoint punctuates what it has heard so far and can't wait for what comes next, so it
often ends a sentence at a thinking pause. Raising `endpointing` from 2000 to 5000 made
little difference, so it went back to 2000 with this pass, which suits the live text in
the pill better.

Before building this, a 16 second clip with long pauses inside each phrase was sent by
hand to the batch endpoint, `POST https://api.x.ai/v1/stt`, with `format=true` and
`language=en`. It came back as one sentence with commas at the pauses, in well under a
second:

```json
{
  "text": "So, um, I think we should ship the settings window today, and then look at the pill tomorrow.",
  "language": "en",
  "duration": 15.851,
  "words": [{ "text": "So,", "start": 0.921, "end": 1.081, "speaker": 0 }]
}
```

Only `text` is used.

## Decision

- A General tab setting, **Re-transcribe on stop**, on by default and stored as
  `batchOnCommit` (see [0010](0010-settings-storage-and-api-key.md)). With it off,
  dictation is unchanged.
- Streaming still drives the pill. When a session's outcome is `.insert`,
  `DictationController` sends the whole recording to the batch endpoint with the same
  `language`, `filler_words=false` and keyterms as the stream, plus `format=true`, and
  inserts the batch text instead of the live text. A cancelled, empty or failed session
  skips the pass, and the Test button never runs it.
- The pass runs after the session's outcome, so the session lifecycle in
  [0004](0004-session-lifecycle.md) is unchanged. The pill stays on `Transcribing` with
  the live text during the pass and never shows the batch text. Escape, the hotkey and a
  click on the pill do nothing then, as while finalizing.
- If batch throws, times out or returns empty or whitespace-only text, the live text is
  inserted and the pill shows no error. The user still gets their words, with the streamed punctuation.
- `BatchTranscriber` limits the whole request to 5 seconds with
  `timeoutIntervalForResource`. A one-minute dictation should take a second or two, so
  the timeout only matters when something has gone wrong. `URLRequest.timeoutInterval`
  would only limit the gap between packets.
- The recording is the session's PCM chunks, collected by the pump in memory, including
  those buffered before `listening`. It is never written to disk and is released once
  the pass and the insertion are done. A minute is about 1.9 MB.
- The API key read at the start of the session is reused, so the Keychain is read once.
- Both requests take their keyterms from `STTConnection.keyterms(settings:)`, so the caps
  on count and length are defined once.
- The hard cap drops from ten minutes to five. Every capped session now ends in a batch
  request, and a ten minute recording is about 19 MB, which would most likely time out or
  be rejected and add 5 seconds before the live text went in. Five minutes (about 9.6 MB)
  is still far beyond a normal dictation. The amber elapsed time moves from eight minutes
  to four.

## Evidence

The hand-sent request above did not confirm two parameters the pass sends:

- `filler_words=false`. The request had none, and "um" came through. The stream sends
  it, and batch is assumed to honour it the same way.
- `keyterm`. It was not tried on batch. If batch rejected it with a 400, every pass
  would fall back to the live text without a visible error.

G1, dictating on the Mac with keyterms set as its steps asked: with the setting on, a dictation with long
pauses and an "um" came out as joined-up sentences with no "um", so batch accepted
`keyterm` and honoured `filler_words=false` (a rejected request would have fallen back to
the fragmented live text). With it off, the fragmented streamed text was inserted
immediately. The inserted text was not captured, and the spinner time after a one-minute
dictation was not measured.

## Consequences

- Insertion waits for the batch request after every inserted dictation. With the
  setting off, text is inserted as soon as the stream finishes.
- A failing batch request is invisible except in the punctuation, so a rejected
  parameter would look like the feature doing nothing. Reproduce the request with
  `curl` to find it.
- The menu bar shows idle during the pass while the pill still shows `Transcribing`.
- A capped session can still fall back after the full 5 second timeout.
- If the microphone fails mid-session after some text has settled, the pass runs on the
  partial recording first, so the red error appears up to 5 seconds late.
- `endpointing=2000` has not been dictated against since the revert; G1 ran at 5000.
- Re-transcribing during the session and an LLM clean-up pass are out of scope.
