# Read aloud implementation plan

Status: draft; implementation has not started.

## Orchestration record

- Integration branch: `feat/read-aloud`
- Starting commit: `8a47832`
- Review command: `lead subagents`
- Specification approved at commit: `8a474b1`
- Started: `2026-09-26`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Speech request, PCM decoding and settings](01-speech-core.md) | Approved spec and gate G1 | Accepted |
| 2 | [Read aloud in the app](02-read-aloud-app.md) | 1 | Not started |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-2 and gate G2 | Not started |

Statuses: `Not started`, `Implementing`, `Review`, `Remediation`, `Closure review`, `Blocked`,
`Accepted`. One workstream is active at a time.

## Why these boundaries

Workstream 1 is the `EchoTypeCore` half: the spike's decision record, the three stored settings
and hotkey presets, the TTS request (REST or socket, as the spike decides) and the PCM decoder.
Every acceptance criterion there is proved by `swift test`, and the result is safe to ship on its
own: nothing calls it yet, and the stored settings only add keys. The spike belongs here because
its result decides what `Speech` contains.

Workstream 2 is the app half: copying the selection, the hotkey routing, playback, the reader,
the pill phase and the Read Aloud tab. These change together to produce one user-visible feature,
and its acceptance depends on a person listening, so it carries gate G2. Keeping the tab with the
reader means the settings never appear in the window before they do anything.

## Cross-workstream contracts

Workstream 1 provides these; workstream 2 consumes them unchanged.

- `Settings` gains `readAloudHotkey: Hotkey = .optionS`, `voice: String = "ara"` and
  `speechSpeed: Double = 1.0`, stored under the keys `readAloudHotkey`, `voice` and
  `speechSpeed`, each decoded on its own like the other stored fields. The memberwise `init`
  takes them as defaulted parameters after `batchOnCommit`.
- `Settings.Hotkey.optionS` (keycode `0x01`, `kVK_ANSI_S`) and `controlOptionS`, and
  `Hotkey.readAloudPresets = [optionS, controlOptionS]`. `Hotkey.presets` stays the dictation
  list.
- `public enum Speech` in `Sources/EchoTypeCore/TTS/Speech.swift` holds:
  - `voices: [String]`, the voice ids as the endpoint names them (Ara first). The tab shows each
    capitalised.
  - `sampleRate`, 24,000, the PCM rate every request asks for.
  - The 60,000-character cap: a function returning the text cut to its first 60,000 characters
    and whether it was cut.
  - The request, in whichever form decision 0018 chooses. Both carry the text, `voice`,
    `language`, `speed`, 16-bit PCM at `sampleRate`, and the spike's chosen settings, and use
    `STTConnection.headers(apiKey:)` for auth.
    - **REST:** `request(text:settings:apiKey:) -> URLRequest` for `POST /v1/tts`. The app maps a
      non-2xx status with `STTError(httpStatus:)`.
    - **WebSocket:** `streamingURL(settings:) -> URL`, `messages(text:) -> [String]` (one
      `text.delta`, then `text.done`), and `Speech.Event` with cases `audio(Data)`, `done` and
      `error(String)`, decoded from one server text frame by a throwing initialiser. The app
      opens it with `URLSessionWebSocketTransport(url:apiKey:)`, as dictation does.
- `public struct PCMDecoder` in `Sources/EchoTypeCore/TTS/PCMDecoder.swift`, with `init()` and
  `mutating func samples(from chunk: Data) -> [Float]`. It converts 16-bit little-endian PCM to
  Float32 by dividing by 32,768 and carries an odd trailing byte into the next call. Use one
  decoder per reading.

## Ownership handoffs

- Workstream 1 owns `EchoTypeCore`, its tests, decision 0010, the new decision 0018 and the
  decisions index. Workstream 2 edits none of them, except that it adds its G2 findings to 0018.
  A defect found in workstream 1's code during workstream 2 is an escalation, not a silent fix.
- Workstream 2 owns the `EchoTypeApp` target and the specification's status line.
- The final-review lead may change any file above for an accepted correction.

## Whole-feature acceptance

- `swift build` and `swift test` pass on the branch.
- Every behaviour in the specification's Behaviour section holds, as proved by workstream 2's
  review and G2.
- Decision 0018 records the spike and G2's time to first audio and is in the index. Decision 0010
  lists the new stored keys. The specification's status says it is implemented.
- G1 and G2 have passed.

## External validation gates

Gate status is separate from workstream status: `Pending`, `Testing`, `Troubleshooting` or
`Passed`.

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1 The spike | Workstream 1 | Before implementation | Passed | The curl commands in the specification's Spike section | Aidan reports all four facts listed in the README's G1 section |
| G2 Reading on the Mac | Workstream 2 | After closure, before acceptance | Pending | Development app from `./scripts/run.sh`, built from the workstream 2 diff | Aidan reports pass or fail for each step in the packet's External validation section |

## Escalations

Empty until a lead blocks. One entry per escalation, in this shape:

```markdown
### E1 <short title> (workstream N)

- Decision needed:
- Options:
- Lead's recommendation:
- Evidence:
- Unblocks:
- Aidan's answer:
```

The lead that resolves an entry records its lasting decision in the workstream handoff, and in
the decision and drift log when a later workstream or the final review depends on it, then
removes the entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-26 | Reading fetches audio over REST (`POST /v1/tts`), sending `optimize_streaming_latency: 0` and `text_normalization: false`. Not drift: the specification left this to the spike. | G1: REST streams, first audio +0.59s; latency setting gave no gain; normalisation misread Markdown. Decision 0018. | Aidan (G1, E1) | 2, Final |
| 2026-09-26 | Reading passes the General tab's `language` unchanged, as specified. xAI's TTS docs list a fixed set of tags (`en`, `pt-BR`, ...) without `en-GB`, so a regional tag may get a 400. Unverified; G2 should read once with a regional tag. Mapping tags would be a specification change for Aidan. | Workstream 1 review Q1 | Workstream 1 lead | 2, Final |
