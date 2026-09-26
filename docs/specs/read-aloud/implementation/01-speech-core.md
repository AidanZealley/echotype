# Workstream 1: Speech request, PCM decoding and settings

Status: accepted.

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

- Base commit: `8a47832`, uncommitted.
- Outcome: the REST branch only. `Speech.request(text:settings:apiKey:)` builds `POST
  https://api.x.ai/v1/tts` with a JSON body of exactly `text`, `voice_id`, `language`,
  `speed`, `output_format: {codec: "pcm", sample_rate: 24000}`,
  `optimize_streaming_latency: 0` and `text_normalization: false`, auth from
  `STTConnection.headers(apiKey:)`. `Speech.voices = ["ara", "altair"]`,
  `Speech.sampleRate = 24_000`, `Speech.maximumCharacters = 60_000` and
  `Speech.capped(_:) -> (text: String, wasCut: Bool)`. `PCMDecoder` (`Sendable`) matches the
  contract. `Settings` gains the three fields, `Hotkey.optionS`, `controlOptionS` and
  `readAloudPresets` exactly as the plan's contracts say.
- Files changed: `Sources/EchoTypeCore/Settings.swift`, `Sources/EchoTypeCore/TTS/Speech.swift`
  (new), `Sources/EchoTypeCore/TTS/PCMDecoder.swift` (new),
  `Tests/EchoTypeCoreTests/SettingsTests.swift`, `Tests/EchoTypeCoreTests/SpeechTests.swift`
  (new), `Tests/EchoTypeCoreTests/PCMDecoderTests.swift` (new),
  `docs/decisions/0018-read-aloud-audio-fetch.md` (new), `docs/decisions/0010-...md` (stored
  keys and read-aloud presets), `docs/decisions/README.md` (index row).
- Decisions: from E1 (G1, answered by Aidan 2026-09-26): REST streams (first audio +0.59s,
  last +20.80s on about 1,900 characters), `optimize_streaming_latency` off (no measurable
  gain, prose sounded better without it) and `text_normalization` off. Reading uses REST and
  sends both settings explicitly as 0 and false. Decision 0018 holds the full record. The
  cap counts Unicode scalars, not `Character`s, so the result is at most 60,000 characters
  by either count; a cut may split a grapheme cluster, which is harmless for speech. The body
  is an `Encodable` struct with `.convertToSnakeCase`.
- Verification: `swift build` passes; `swift test` passes, 52 tests (47 before: +2 speech,
  +2 PCM decoder, +1 settings for a pre-read-aloud payload; the existing round trip, pinned
  payload and missing-fields tests now cover the three keys).
- Known limitations or external checks: the voice id `altair` is taken from the spec's
  "Ara or Altair" and was not sent to the endpoint; the spike only used `ara`. G2's voice
  step checks it. The pinned payload test checks decoding only, as before; it does not pin
  the encoder's key order.
- Specification drift: none.

## Independent review

- Reviewer: fresh independent review agent, 2026-09-26, over the uncommitted diff on `8a47832`
  including the untracked `Sources/EchoTypeCore/TTS/`, `SpeechTests.swift`,
  `PCMDecoderTests.swift` and decision 0018.
- Verdict: acceptable as it stands. Every acceptance criterion holds; no Required findings.
  - AC1: 0018 records streaming with timestamps (07:54:18.627 / 07:54:19.213 / 07:54:39.429;
    headers noted as not captured separately, as in E1), first audio +0.59s / +0.58s, the
    setting, `text_normalization` off, and REST. Index row added (`docs/decisions/README.md:31`).
    4,934,304 bytes / 48,000 B/s = 102.8s, matching "about 103 seconds".
  - AC2: `Speech.swift:28-52` builds the body; `SpeechTests.swift:17-27` checks all seven
    fields and `body.count == 7`, so nothing extra is sent. Auth reuses
    `STTConnection.headers(apiKey:)` (`Speech.swift:34`). No WebSocket code (AC3 n/a).
  - AC4: `Speech.capped` counts scalars, so the result is at most 60,000 `Character`s too;
    `SpeechTests.swift:30-36`.
  - AC5: `PCMDecoderTests.swift:9-25` covers every split offset, including a non-zero
    `startIndex` slice from `dropFirst`, single-byte and empty chunks, and `Int16.min/max`.
  - AC6: defaults, round trip, per-field decoding, pinned payload and a pre-read-aloud payload
    are covered in `SettingsTests.swift`; 0010 lists the keys and the presets. Contracts in
    `plan.md` match names, types, key code `0x01` and init parameter order.
  - AC7: `swift build` → "Build complete!"; `swift test` → "Test run with 52 tests in 1 suite
    passed".
  - The handoff's open check on `altair`: the xAI REST reference
    (docs.x.ai/developers/rest-api-reference/inference/voice) lists `altair` and `ara` among
    the built-in voice ids, so the id is right; G2 still confirms it by ear.
- Required findings: none.
- Optional observations:
  - O1 Test redundancy. `missingFieldsDefault` already asserts
    `Settings(decoding: stored) == Settings(hotkey: .controlOptionD)`, which covers the three
    new defaults, so the added lines `SettingsTests.swift:56-58` repeat it. The new
    `payloadBeforeReadAloudDecodes` (`SettingsTests.swift:62`) proves the same property with a
    fuller payload. Keeping the new test and dropping the three lines would be enough.
  - O2 Stored values are not range-checked. `voice` and `speechSpeed` decode any string or
    double (`Settings.swift` decoder), so a value outside `Speech.voices` or 0.7-1.5 goes
    straight into the request and would come back as a 400. A non-finite `speechSpeed` set in
    code would trap in `encoded()`'s `try!`. Only the app writes these, through a picker and a
    bounded slider in workstream 2, so this is acceptable. It is noted in case the lead wants
    to clamp them in the decoder.
- Questions:
  - Q1 Language tags the TTS endpoint rejects. The General tab's language is a free-text
    BCP-47 field (`Sources/EchoTypeApp/Views/SettingsView.swift:252-257`) and STT accepts
    regional tags. `Speech.request` passes it through unchanged (`Speech.swift:45`). The xAI
    REST reference lists the TTS `language` values as `auto`, `en`, `ar-EG`, `ar-SA`, `ar-AE`,
    `bn`, `zh`, `fr`, `de`, `hi`, `id`, `it`, `ja`, `ko`, `pt-BR`, `pt-PT`, `ru`, `es-MX`,
    `es-ES`, `tr` and `vi`. `en-GB` is not among them, yet the test uses it
    (`SpeechTests.swift:7`). A user with `en-GB` stored would likely get a 400 on every reading.
    The specification says "Reading uses the General tab's `language`", so the code follows the
    spec. The lead should decide whether this is accepted as is and left to G2, or whether
    `Speech.request` should map unsupported tags, for example to the primary subtag or `auto`,
    which would be specification drift. This is unverified against the live endpoint.

## Resolution

- Finding dispositions:
  - No Required findings, so no remediation pass.
  - O1 declined. The three extra default checks are redundant but harmless and name the new
    defaults at the point a reader looks for them; not worth a remediation pass.
  - O2 declined. Only workstream 2's picker and bounded slider write `voice` and
    `speechSpeed`; clamping in the decoder would guard a hypothetical writer.
  - Q1 judged: keep the specification. "Reading uses the General tab's `language`" is approved
    behaviour, the default `en` is on the endpoint's list, and the rejection of regional tags
    such as `en-GB` is unverified. Mapping tags would change approved behaviour on unverified
    evidence. Recorded in the plan's decision and drift log so workstream 2 and G2 check it:
    if G2 shows a 400 for a regional tag, that is a specification change for Aidan.
- Simplification/deletion pass: the lead read `Speech.swift` and `PCMDecoder.swift`; both are
  the contract and nothing more, with no socket branch, client or wrapper.
- Final verification: the reviewer's `swift build` and `swift test` (52 tests) on the final
  diff, confirmed by the closure reviewer; no code changed after review. Closure's record gap
  is closed: the Q1 entry is in the plan's decision and drift log.

## Closure review

- Reviewer: fresh closure agent, 2026-09-26, over the uncommitted diff on `8a47832`, untracked
  files included.
- Diff unchanged since review: every line the review cites still matches (`Speech.swift:28-52`,
  `:34`, `:45`; `SpeechTests.swift:7`, `:17-27`, `:30-36`; `PCMDecoderTests.swift:9-25`;
  `SettingsTests.swift:56-58`, `:62`; `docs/decisions/README.md:31`). No source, test or
  decision file was modified after 08:06:12; only this packet and `plan.md` changed later
  (08:08:52, the Resolution). `git status` shows the same ten paths the handoff lists, plus
  this packet and `plan.md`.
- Accepted findings: none, so there is nothing to check as fixed. O1 and O2 stay Optional.
  Q1's ruling keeps the specification's behaviour and changes no code.
- Checks: `swift build` → "Build complete!"; `swift test` → "Test run with 52 tests in 1 suite
  passed". `STTConnection.headers(apiKey:)` and `STTError(httpStatus:)`, which `Speech.swift`
  and 0018 rely on, exist (`STTConnection.swift:44`, `STTEvent.swift:126`).
- Record gap for the lead, not a code defect: the Resolution says Q1 is "Recorded in the plan's
  decision and drift log", but that table in `plan.md` still reads `None`. Add the Q1 entry
  (regional language tags such as `en-GB` may get a 400 from TTS; G2 checks; a mapping would be
  a specification change for Aidan) before committing, since workstream 2 and G2 depend on it.
- Verdict: acceptable. No release-blocking defect.
- Remaining required findings: none.

## External validation

- Gate and placement: G1, before implementation.
- Status: `Passed`
- Candidate and instructions: the specification's Spike section, run by Aidan on the Mac.
- Required evidence: the four facts listed in the README's G1 section.
- Attempts and lasting decisions: Aidan ran the spike on 2026-09-26; decision 0018 holds the
  full answer. REST streams: long prose (about 1,900
  characters) sent 07:54:18.627, first audio bytes 07:54:19.213 (+0.59s), last 07:54:39.429
  (+20.80s), 4,934,304 bytes; Markdown sample (about 600 characters) first +0.35s, last +11.92s.
  Headers were not captured separately; the first data arrived with them. Time to first audio
  +0.59s without `optimize_streaming_latency`, +0.58s with it at 1: no measurable gain, and the
  prose sounded better without it. `text_normalization` off: with it the voice misread bold
  "**Note:**" as "negative note" and first audio took about 0.35s longer; without it the voice
  read the `ts` fence hint aloud. Lead's ruling: reading uses REST, and the request sends
  `"optimize_streaming_latency": 0` and `"text_normalization": false` explicitly, so the choice
  is pinned against default changes and the tests can prove each field.
- Resume condition: Aidan's answer in the plan's escalation entry covers all four facts.
