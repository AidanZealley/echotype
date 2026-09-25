# Workstream 1: Batch transcriber and setting

Status: accepted.

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

- Base commit: `2acb117`
- Outcome: `BatchTranscriber` (`wav`, `request`, `transcribe`) and `Settings.batchOnCommit` exist
  as the plan's cross-workstream contracts describe. Nothing in `EchoTypeApp` calls them yet.
- Files changed: `Sources/EchoTypeCore/STT/BatchTranscriber.swift` (new),
  `Sources/EchoTypeCore/STT/STTConnection.swift`, `Sources/EchoTypeCore/Settings.swift`,
  `Tests/EchoTypeCoreTests/BatchTranscriberTests.swift` (new),
  `Tests/EchoTypeCoreTests/SettingsTests.swift`,
  `docs/decisions/0010-settings-storage-and-api-key.md`.
- Decisions:
  - The caps are shared through a new `public static func STTConnection.keyterms(settings:)
    -> [String]`, which `streamingURL` now uses too. `maximumKeytermLength` stays `private`.
  - `BatchTranscriber.timeout` is `internal` (5 s). `transcribe` makes an ephemeral
    `URLSession` per call and invalidates it with `finishTasksAndInvalidate()`.
  - A response that is not an `HTTPURLResponse` throws `STTError.unexpectedStatus(0)`.
  - The multipart boundary is `echotype-<UUID>`; the file part is named `audio.wav` with
    `Content-Type: audio/wav`.
  - The pinned payload in `SettingsTests` stores `"batchOnCommit":false`, so it also proves a
    non-default value decodes. `missingFieldsDefault` checks the absent key decodes to `true`.
- Verification: `swift build` clean; `swift test` 47 tests passed, `LiveProtocolTests` skipped
  without `XAI_API_KEY`. Changed Swift files run through `swift format -i`.
- Known limitations or external checks: `transcribe` has no automated test by design; G1 in
  workstream 2 proves the live request, including whether batch accepts `keyterm` and
  `filler_words`.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent review agent (Claude Opus 5.5), against base `2acb117`.
- Verdict: accept. No Required findings.
- Evidence:
  - `swift build`: build complete. `swift test`: "Test run with 47 tests in 1 suite passed",
    including `wavReadsBack` and `batchRequestFields`; the existing `STTConnection` streaming
    URL tests still pass after the keyterm refactor.
  - `swift format lint` on the five changed Swift files: no diagnostics.
  - AC1: `BatchTranscriber.swift:12-31` writes RIFF/`WAVEfmt `/`data` with 16000 Hz, 1 channel,
    16 bits, then `header + pcm`. `BatchTranscriberTests.swift:10-19` checks 44 + count, the
    unchanged suffix, and `WAVRecording` sample rate, channels and samples, including
    `.max`/`.min`.
  - AC2: `BatchTranscriber.swift:37-60` builds `POST https://api.x.ai/v1/stt`, headers from
    `STTConnection.headers(apiKey:)`, one boundary shared by header and body, fields in order
    `format`, `filler_words`, `language`, `keyterm`..., then `file`. The test parses the body
    with the header's boundary and checks field order and values, the 100-term and 50-character
    caps (`t97` last, `x` * 50), and that `file` is last with the WAV unchanged.
  - AC3: `BatchTranscriber.swift:71-82` uses an ephemeral session with
    `timeoutIntervalForResource = timeout` (5), maps any non-2xx (and a non-HTTP response, as 0)
    to `STTError(httpStatus:)`, and decodes `text`. It matches the plan's contract signature,
    `public` on a `public enum`.
  - AC4: `Settings.swift:88-109,123,136-137,146` adds the field with default `true`, the
    coding key, an independent `try? decodeIfPresent ?? defaults` decode and an unconditional
    encode. `SettingsTests.swift` pins `"batchOnCommit":false`, round-trips `false`, and
    `missingFieldsDefault` asserts the absent key gives `true`.
  - AC5: decision 0010 lines 15-18 list `batchOnCommit` among the stored keys.
  - Boundaries: nothing in `Sources/EchoTypeApp` changed; `streamingURL` emits the same query
    items in the same order (the keyterm mapping only moved into `keyterms(settings:)`); no
    network stub or live test was added.
- Required findings: none.
- Optional observations:
  - O1. `STTConnection.keyterms(settings:)` is a new `public` function where the packet
    suggested widening `maximumKeytermLength` (`01-batch-transcriber.md`, Scope: "Widen
    `maximumKeytermLength` from `private` if needed rather than copying the number"). It keeps
    the caps in one place as the plan's contract requires and removes the duplicate mapping,
    so it satisfies the intent; recorded only so the lead can note it is not drift.
  - O2. `Settings.swift:114` says "Only the fields the settings window edits are persisted".
    `batchOnCommit` has no control until workstream 2 adds the toggle, so the comment is briefly
    ahead of the code. No change needed if workstream 2 lands as planned.
- Questions: none.

## Resolution

- Finding dispositions:
  - O1 rejected as a change, accepted as the design. `STTConnection.keyterms(settings:)` keeps
    both caps in `STTConnection` and gives both requests one mapping, which meets the plan's
    contract better than exposing the length constant. Not drift.
  - O2 no change. The toggle lands in workstream 2, which makes the comment true again.
  - No Required findings, so the remediation pass was skipped.
- Simplification/deletion pass: the lead read the whole diff. The old keyterm mapping in
  `streamingURL` was replaced rather than duplicated; nothing else is left over.
- Final verification: `swift build` clean; `swift test` 47 tests passed, `LiveProtocolTests`
  skipped without `XAI_API_KEY`.

## Closure review

- Reviewer: fresh closure review agent (Claude Opus 5.5), against base `2acb117`.
- Verdict: accept. No finding was accepted for remediation, so there were no fixes to check. The
  uncommitted diff is the one the independent review saw and still meets acceptance criteria
  1 to 6.
- Evidence: `swift build` complete; `swift test` "Test run with 47 tests in 1 suite passed",
  including `wavReadsBack` and `batchRequestFields`. The `transcribe` signature, its throwing
  behaviour, the internal 5 second constant, `Settings.batchOnCommit` and the shared
  `STTConnection.keyterms(settings:)` match the plan's cross-workstream contracts. Nothing in
  `Sources/EchoTypeApp` changed.
- Remaining required findings: none.
