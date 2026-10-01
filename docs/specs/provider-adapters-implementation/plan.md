# Provider adapters implementation plan

Status: in progress. Workflow approval: approved by Aidan on 2026-10-01.

## Orchestration record

- Integration branch: `refactor/provider-adapters`
- Starting commit: `f55bfad`
- Review command: `lead subagents`, inherited model and effort
- Specification approved: by Aidan on 2026-10-01; its committed version is the starting commit
- Started: 2026-10-01

This file is the resume record. Only one lead is active at a time. The execution procedure, recovery rules and lead prompts are in the [README](README.md).

Workstream states: Not started, Implementing, Review, Remediation, Closure review, Blocked, Accepted.

## Workstream order

| # | Workstream | Depends on | Status |
|---:|---|---|---|
| 1 | [Transcription adapter](01-transcription.md) | Workflow approval | Accepted |
| 2 | [Cleanup adapter and always-on cleanup](02-cleanup.md) | 1 | Accepted |
| 3 | [Read-aloud adapter](03-read-aloud.md) | 2 | Accepted |
| 4 | [Provider registry and credentials](04-registry-credentials.md) | 3 | Not started |
| 5 | [Provider settings and window](05-settings-window.md) | 4 | Not started |
| Final | [Whole-feature review](final-review.md) | 1 to 5 | Not started |

## Why these boundaries

- **1 Transcription.** Session and adapter must change together: the session takes over holding audio and ordering sends at the same time as the xAI protocol moves out. It also introduces `ProviderError`, because the adapter is the first thing to throw it.
- **2 Cleanup.** Changes the dictation operation's revision seam once. The cleanup adapter and removing the toggle go together, because "no cleanup service" replaces `cleanUp: false` as the path without revision.
- **3 Read aloud.** Reading, playback and MCP `speak` form a separate path with its own Mac gate.
- **4 Registry and credentials.** Composes the three services into `Provider` once they all exist, so no service contract is declared before it is implemented. It switches wiring, credentials and error wording to the selected provider.
- **5 Settings and window.** Holds the user-visible settings: per-provider reading storage and its migration, and the Provider, Read Aloud and Keyterms tabs.

Every intermediate state is a working xAI-only app. Workstreams 1 to 3 wire their xAI service directly at the app's composition points; 4 replaces only that wiring with registry lookup. Order is sequential, because 1, 2 and 4 all change the dictation composition in `DictationController.swift` and 2, 4 and 5 all change `Settings.swift` and `SettingsView.swift`.

## Cross-workstream contracts

These are frozen. A defect in one is raised as an escalation naming the owning workstream, not worked around downstream.

- **Specification shapes.** `TranscriptionService`, `LiveTranscriber`, `TranscriptionEvent`, `VoiceService`, `SpeechStream`, `SpeechAudio`, `CleanupService`, `ProviderError` and `Provider` keep the responsibilities and guarantees given in the specification. Declaration details may differ. Each owner records its final declarations in its handoff.
- **Dependency direction.** Code outside `Sources/EchoTypeCore/Providers/XAI/` reaches xAI only through a service value. From workstream 4, that service value comes only from the selected `Provider`. `Providers/XAI/` depends on the neutral contracts, never the reverse.
- **Errors.** Every xAI endpoint maps HTTP statuses through one xAI mapping that builds on the shared default and adds 400 as `rejectedCredential`. `STTError` is not visible outside `Providers/XAI/` after workstream 1.
- **Behaviour.** With xAI, dictation, read aloud, MCP `speak`, Test and Last Dictation behave as on the starting commit, apart from the specification's agreed changes. Existing protocol, transcript and revision fixtures stay authoritative; they move with their code rather than being rewritten.
- **Storage.** The stored keys `provider` and `reading`, the migration of `voice` and `speechSpeed`, and ignoring `cleanUp` follow the specification exactly. Each field keeps decoding independently with its own fallback.

## Ownership handoffs

| File or area | Order and notes |
|---|---|
| `DictationController.swift` | 1 → 2 → 3 → 4 → 5. Each workstream changes only its own wiring, plus `describe(_:)` in 1 and 4. |
| `DictationOperation.swift` | 1 changes the transcriber dependency; 2 changes the revision dependency; 4 changes key lookup. |
| `Settings.swift` | 2 removes `cleanUp`; 4 adds `provider`; 5 adds `reading`, migrates and removes `voice`, `speechSpeed` and the speed range. |
| `SettingsView.swift` | 1 changes the Keyterms count source; 2 removes the Clean up text toggle; 3 changes the voice list source; 4 changes Keychain calls and the key placeholder; 5 owns the Provider, Read Aloud and Keyterms tab layout. |
| Shared network helpers in `Sources/EchoTypeCore/Providers/HTTP/` | 1 creates them (status mapping, WebSocket transport); 3 adds the streamed HTTP body. |
| Error mapping lines in `RevisionRequest.swift` and `ReadingRequest.swift` | 1 may edit them to use the xAI status mapping; their files then belong to 2 and 3. |
| Decision records | Each packet names its own. Workstream 4 creates the provider adapters record, and 5 completes its "Adding a provider" section. |

## External validation gates

| Gate | Owner and placement | Status | Candidate | Required evidence and resume condition |
|---|---|---|---|---|
| G1 Dictation | 1, after closure before acceptance | Passed | `.build/EchoType-workflow.app` from workstream 1's uncommitted state on `f55bfad` | Aidan reports that a signed candidate with xAI passes: normal dictation, stopping mid-sentence keeps the final words, Escape during Transcribing inserts nothing, and the Settings Test button shows what it heard |
| G2 Read aloud | 3, after closure before acceptance | Passed | `.build/EchoType-workflow.app` from workstream 3's uncommitted state on `a889284` | Aidan reports that a signed candidate passes: reading a selection with each voice, Space to pause and resume, stopping with the hotkey, and an agent's MCP `speak` call |
| G3 Whole feature | Final, after focused closure before acceptance | Pending | TBD | Aidan reports that a signed candidate passes the specification's Mac checks: the upgrade keeps the existing key, voice and speed; dictation shows cleanup requests in Last Dictation; read aloud, MCP `speak` and Test work; a wrong key shows "xAI rejected the API key", with the real key restored afterwards; the Provider tab is checked in both themes |

Gate states are Pending, Testing, Troubleshooting or Passed, separate from workstream states.

## Whole-feature acceptance

- Rows 1 to 5 are Accepted.
- The final review runs the complete deterministic suite and the release build once.
- The specification's provider-name search is clean.
- Gate G3 has passed.

CI is not run by this workflow because nothing is pushed; the completion report says so.

## Escalations

None open.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected workstreams |
|---|---|---|---|---|
| 2026-10-01 | `LiveTranscriber` contract clarified: `finish()` may come before `.ready` when no audio was sent, and an adapter may yield a final `.transcript` just before `.finished`. `STTError` is deleted rather than made private, and xAI `error` events throw `ProviderError.failed(message)` | Keeps the starting commit's xAI behaviour and makes the guarantees explicit for later adapters | Workstream 1 lead, within the specification's "declaration details may differ" | 1, 4, Apple follow-up |
| 2026-10-01 | Cleanup dependency: `DictationOperation.Dependencies` takes `cleanup: CleanupService?` and its own `revisionClock` for the final budget; `Reviser` takes the service and credential and owns `Reviser.prompt`. No specification drift. `docs/images/settings-general.png` still shows the removed toggle and has no owner; the final review's documentation check should replace or drop it | Declaration details the specification leaves open; recorded for workstream 4's wiring and the final review | Workstream 2 lead | 4, Final |
| 2026-10-01 | Read-aloud contract: `VoiceService` holds voices (first is the default), `speedRange`, `maximumCharacters` and `speak`, with `capped(_:)`; `SpeechRequest(text:settings:credential:)` builds requests; `SpeechStream` promises one sample rate and chunks of at most 100 ms, and `cancel()` only guarantees that a pending `next()` throws. The app wires `XAI.voice` in the reader factory and the Read Aloud tab, and `Settings.speechSpeedRange` duplicates `XAI.voice.speedRange` until workstream 5. No specification drift | Declaration details the specification leaves open; recorded for workstream 4's wiring and 5's settings | Workstream 3 lead | 4, 5 |

## Completion summary

Written by the final-review lead.
