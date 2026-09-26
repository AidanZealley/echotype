# Workstream 1: Speech request, PCM decoding and settings

Status: not started.

## Task packet

### Outcome

Decision 0018 records the spike. `EchoTypeCore` can build the TTS request in the form 0018
chooses, cap the text at 60,000 characters, decode streamed PCM into Float32 samples, and store
the three read-aloud settings. `swift test` proves each of these. Nothing in the app calls them
yet.

### Scope

- Gate G1 comes first; see the README. Once it has passed, write
  `docs/decisions/0018-read-aloud-audio-fetch.md` from Aidan's answer, in the format of the other
  records: whether REST streams, with the timestamps; the time to first audio at each
  `optimize_streaming_latency` setting; the setting reading uses; whether `text_normalization`
  is on; and so whether reading uses REST or the WebSocket. Add it to the index in
  `docs/decisions/README.md`.
- In `Settings.swift`, the three settings and the hotkey presets in the plan's cross-workstream
  contracts, following [0010](../../../decisions/0010-settings-storage-and-api-key.md). Update
  0010's list of stored keys.
- `Sources/EchoTypeCore/TTS/Speech.swift`: the voices, the sample rate, the cap, and the request
  for the branch 0018 chose, as the contracts describe. Only that branch; write nothing for the
  other.
- `Sources/EchoTypeCore/TTS/PCMDecoder.swift`: the conversion with the carried byte.
- Tests, per the specification's Tests section:
  - The request, or the socket URL and messages, carry the voice, speed, language, codec, sample
    rate and the spike's chosen settings.
  - If the socket is used, decoding `audio.delta` (base64 in `delta`), `audio.done` and `error`
    (with `message`) frames.
  - A chunk split mid-sample, including splits at every offset of a short buffer, yields the same
    samples as the whole buffer.
  - `SettingsTests`: extend the round trip and the pinned stored payload with the three new keys,
    and check that a payload without them decodes to the defaults.

### Non-goals

- Anything in `EchoTypeApp`: fetching, playback, the pasteboard, hotkeys, the pill or Settings UI.
- A network client or `async` fetch function in `EchoTypeCore`. The app streams the bytes.
- The branch of the specification the spike rejected.
- Voice previews, timestamps or text clean-up beyond the spike's `text_normalization` choice.
- A live integration test against xAI.

### Initial ownership

- `Sources/EchoTypeCore/Settings.swift` and the new `Sources/EchoTypeCore/TTS/` directory.
- `Tests/EchoTypeCoreTests/SettingsTests.swift` and new test files for `Speech` and
  `PCMDecoder`.
- `docs/decisions/0018-read-aloud-audio-fetch.md` (new), `docs/decisions/0010-settings-storage-and-api-key.md`
  and `docs/decisions/README.md`.
- This packet's record sections, and the workstream 1 row, G1 row, escalation and drift entries in
  `plan.md`.

### Required seams

Provide the plan's "Cross-workstream contracts" exactly. Reuse `STTConnection.headers(apiKey:)`
for auth rather than a second copy of the header.

### Acceptance criteria

1. G1 has passed, and decision 0018 records all four spike facts and the chosen branch, and is in
   the index.
2. `Speech` builds the request for the chosen branch with the text, voice, speed, language, PCM
   codec at 24 kHz, and the chosen `optimize_streaming_latency` and `text_normalization`, and the
   tests prove each field.
3. If the socket is chosen, `Speech.Event` decodes the three server frames, and `messages(text:)`
   sends the text as one `text.delta` then `text.done`.
4. The cap returns text of at most 60,000 characters and reports whether it cut.
5. `PCMDecoder` gives identical samples however the bytes are split into chunks, and an empty
   chunk yields no samples.
6. The three settings have the specified defaults, round-trip, decode on their own, and are in the
   pinned stored payload. Existing stored payloads decode unchanged. Decision 0010 lists the keys.
7. `swift build` and `swift test` pass.

### Targeted verification

```bash
swift build
swift test
```

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

## External validation

- Gate and placement: G1, before implementation.
- Status: `Pending`
- Candidate and instructions: the specification's Spike section, run by Aidan on the Mac.
- Required evidence: the four facts listed in the README's G1 section.
- Attempts and lasting decisions: `TBD`
- Resume condition: Aidan's answer in the plan's escalation entry covers all four facts.
