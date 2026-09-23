# 0002 Detect speech from what the endpoint actually sends

Status: accepted, 2026-09-22 (EchoTypeCore workstreams 3 and 4).

## Context

The original specification treated "no new partials" as silence. A live session
against `wss://api.x.ai/v1/stt` showed otherwise:

- Partials keep arriving at about 1 Hz with `"text":""` during silence.
- Nothing arrives at all during the 2 to 3 seconds the endpoint spends deciding where
  an utterance ends.

So the documented detector reads silence as activity and speech as silence.

## Decision

Speech is a partial with non-empty text, or a `speech_final`. `SessionMachine` ignores
`start` and `duration` when moving between `listening` and `paused`.

Other live observations the code relies on:

- `endpointing=2000` is a floor. The boundary lands 2.73 to 2.80s after the last
  reported word, with the frame in hand at about 3.0s. Budget 3s.
- `transcript.done` has empty text. `finalize` resolves the tail into one more
  `speech_final` partial that arrives before `done`.
- A word in `words` is `{"text", "start", "end"}`. The key is `text`, not `word`, and
  `confidence` was never sent.

## Consequences

- Entering `paused` lags the end of speech by about 3s and leaving it lags by 0.7 to
  2.3s. Both are well inside the ten second threshold.
- The timings come from a public-corpus fixture with inserted digital silence, which is
  the easiest case for voice activity detection. A real room may be slower.
- The `text`/`word` mismatch threw on every frame carrying words and reached a paid
  session before it was caught. A test now decodes `Word` in the live shape.
