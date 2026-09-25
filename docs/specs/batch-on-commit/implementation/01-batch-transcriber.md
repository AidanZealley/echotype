# Workstream 1: Batch transcriber and setting

Status: not started.

## Task packet

### Outcome

`EchoTypeCore` can turn a session's PCM into a WAV, build the batch `POST /v1/stt` request, and
transcribe a recording within a 5 second limit. `Settings` carries `batchOnCommit`, on by default
and persisted. The app behaves exactly as before, because nothing calls the transcriber yet.

### Scope

- Add `Sources/EchoTypeCore/STT/BatchTranscriber.swift` with `wav(pcm:)`, `request(wav:settings:apiKey:)`
  and `transcribe(pcm:settings:apiKey:)` as the specification's Core section describes.
- Reuse `STTConnection` for what both requests share: the keyterm caps and
  `STTConnection.headers(apiKey:)` for authentication. Widen `maximumKeytermLength` from `private`
  if needed rather than copying the number.
- `transcribe` uses its own `URLSession` with `timeoutIntervalForResource` set to the 5 second
  constant, since `URLRequest.timeoutInterval` only limits the gap between packets.
- Add `batchOnCommit: Bool = true` to `Settings`, its initialiser, `CodingKeys`, `init(from:)` and
  `encode(to:)`, decoded on its own with a fallback to the default like the other fields.
- Add `Tests/EchoTypeCoreTests/BatchTranscriberTests.swift` and extend `SettingsTests.swift` with
  the tests in the specification's Tests section.
- Add `batchOnCommit` to the list of stored keys in decision 0010.

### Non-goals

- Anything in `EchoTypeApp`: the controller, the recording, the toggle.
- Retries, logging, progress, or use of the response's `words`, `language` or `duration`.
- A `URLProtocol` stub or other network mocking to test `transcribe`. G1 in workstream 2 proves the
  live request.
- A live-endpoint test.
- Changes to `STTConnection.streamingURL` or its behaviour.

### Initial ownership

- `Sources/EchoTypeCore/STT/BatchTranscriber.swift` (new).
- `Sources/EchoTypeCore/STT/STTConnection.swift`, only to share the keyterm caps.
- `Sources/EchoTypeCore/Settings.swift`.
- `Tests/EchoTypeCoreTests/BatchTranscriberTests.swift` (new) and
  `Tests/EchoTypeCoreTests/SettingsTests.swift`.
- `docs/decisions/0010-settings-storage-and-api-key.md`.
- This packet's record sections and the workstream 1 row and drift entries in `plan.md`.

### Required seams

Provide the contracts in the plan's "Cross-workstream contracts" section exactly. Workstream 2
depends on the `transcribe` signature, its throwing behaviour and `Settings.batchOnCommit`.

### Acceptance criteria

1. `wav(pcm:)` returns a 44-byte RIFF header followed by the PCM unchanged. Written to a temporary
   file and read with the test helper `WAVRecording`, it reports 16 kHz, one channel and the
   original samples.
2. `request` builds `POST https://api.x.ai/v1/stt` with bearer authentication from
   `STTConnection.headers(apiKey:)` and a `multipart/form-data` body whose boundary matches the
   `Content-Type` header. The body has `format=true`, `filler_words=false`, `language` from the
   settings, and one `keyterm` field per keyterm under the same caps as the streaming URL, then the
   WAV as the `file` field, last. A test checks the fields, the caps and that `file` is last.
3. `transcribe` sends that request on a session limited by `timeoutIntervalForResource` of 5
   seconds, throws `STTError(httpStatus:)` on any non-2xx response, and returns the decoded
   `text`.
4. `Settings().batchOnCommit` is `true`. The pinned stored payload in `SettingsTests` includes
   `"batchOnCommit"`, and a stored payload without the key decodes with `batchOnCommit == true`.
   A round trip with it `false` survives.
5. Decision 0010 lists `batchOnCommit` among the stored keys.
6. `swift test` passes.

### Targeted verification

```bash
swift build
swift test
```

The whole suite runs in seconds, so run it rather than filtering. `LiveProtocolTests` stays skipped
without `XAI_API_KEY`; do not set it.

## Implementation handoff

- Base commit: `TBD`
- Outcome: `TBD`
- Files changed: `TBD`
- Decisions: `TBD`
- Verification: `TBD`
- Known limitations or external checks: `TBD`
- Specification drift: `TBD`

## Independent review

- Reviewer: `TBD`
- Verdict: `TBD`
- Required findings: `TBD`
- Optional observations: `TBD`
- Questions: `TBD`

## Resolution

- Finding dispositions: `TBD`
- Simplification/deletion pass: `TBD`
- Final verification: `TBD`

## Closure review

- Verdict: `TBD`
- Remaining required findings: `TBD`
