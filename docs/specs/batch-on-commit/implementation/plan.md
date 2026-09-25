# Batch pass on commit implementation plan

Status: complete; every workstream and the final review are accepted.

## Orchestration record

- Integration branch: `feat/batch-on-commit`
- Starting commit: `2acb117`
- Review command: `lead subagents`
- Specification approved at commit: `18bd0c9`
- Started: `2026-09-25`

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Batch transcriber and setting](01-batch-transcriber.md) | Approved spec | Accepted |
| 2 | [Insert the batch text on stop](02-insert-batch-text.md) | 1 | Accepted |
| Final | [Whole-feature review](final-review.md) | Workstreams 1-2 and gate G1 | Accepted |

Statuses: `Not started`, `Implementing`, `Review`, `Remediation`, `Closure review`, `Blocked`,
`Accepted`. One workstream is active at a time.

## Why these boundaries

Workstream 1 is the `EchoTypeCore` half: the WAV header, the multipart request, the timed request
and the stored setting. Every acceptance criterion there is proved by `swift test`, and the result
is safe to ship on its own, since nothing calls it yet and the stored setting only adds a key.

Workstream 2 is the app half: recording the session's audio, running the pass, the fallback, the
Settings toggle and the decision record. Its acceptance depends on a person dictating, so it
carries gate G1. Keeping the toggle with the controller wiring means the setting never appears in
the window before it does anything.

## Cross-workstream contracts

Workstream 1 provides these; workstream 2 consumes them unchanged.

- `public enum BatchTranscriber` in `Sources/EchoTypeCore/STT/BatchTranscriber.swift` with
  `static func transcribe(pcm: Data, settings: Settings, apiKey: String) async throws -> String`.
  It returns the response's `text` unchanged and throws on a timeout, a transport failure, a
  non-2xx status (as `STTError(httpStatus:)`) or an undecodable body. Deciding that empty text
  means fall back belongs to the caller.
- `pcm` is exactly the concatenated chunks `AudioChunker` yields: 16 kHz mono Int16 little-endian.
- The 5 second timeout is a constant inside `BatchTranscriber`. The caller adds no timeout.
- `Settings.batchOnCommit: Bool`, default `true`, stored under the key `batchOnCommit`, decoded on
  its own like the other stored fields.
- The keyterm caps stay in one place, `STTConnection`, and both requests use them.

## Ownership handoffs

- Workstream 1 owns `EchoTypeCore`, its tests and decision 0010. Workstream 2 edits none of them.
  A defect found there during workstream 2 is an escalation, not a silent fix.
- Workstream 2 owns `DictationController.swift`, the General tab in `SettingsView.swift`, the new
  decision record, the decisions index and the specification's status line.
- The final-review lead may change any file above for an accepted correction.

## Whole-feature acceptance

- `swift build` and `swift test` pass on the branch.
- Every behaviour in the specification's Behaviour section holds, as proved by workstream 2's
  review and G1.
- Decision 0010 lists the new stored key. A new decision record describes the batch pass and is in
  the index. The specification's status says it is implemented.
- G1 has passed.

## External validation gates

Gate status is separate from workstream status: `Pending`, `Testing`, `Troubleshooting` or
`Passed`.

| Gate | Owner | Placement | Status | Candidate | Resume condition |
|---|---|---|---|---|---|
| G1 Dictation on the Mac | Workstream 2 | After closure, before acceptance | Passed | Development app from `./scripts/run.sh`, built from the workstream 2 diff | Aidan reports pass or fail for each step in the packet's External validation section |

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
the decision and drift log when the final review depends on it, then removes the entry.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-09-25 | Live STT `endpointing` reverted from 5000 to 2000, undoing `4b7578c` in `STTConnection.swift`, its test and `docs/specs/echotype-v1.md`. Workstream 2 made this `EchoTypeCore` edit outside its ownership. | 5000 only served to stop false full stops in the inserted text, which the batch pass now fixes; 2000 suits the live pill better. G1 ran at 5000; 2000 is the value that shipped before. | Aidan (G1 escalation) | 2, Final |
