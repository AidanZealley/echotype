# Local models productionization plan

Status: approved by Aidan on 2026-10-09; execution in progress.

## Orchestration record

- Integration branch: `feat/local-models-productionization`, reuse existing branch.
- Starting commit: `077a1ec3973cd9629c527e7f9c419c6e4263ee93`.
- Main comparison base: `4669f80f43a9be81008f8e01a4bb854f914b1b68`, recorded from `git merge-base HEAD origin/main` at execution start.
- Historical spike recovery: `2f231b9` on `spike/local-models`; old workflow docs stay in git,
  with useful findings consolidated into docs/decisions/0026-local-model-stack.md and docs/local-models.md.
- Review configuration: lead subagents, inherited model and effort.
- Specification decisions approved: Aidan confirmed model set and explicit download/preparation in this conversation, 2026-10-09.
- Workflow approved: Aidan, 2026-10-09, in this conversation.
- Execution started: 2026-10-09 on verified branch `feat/local-models-productionization`.
- Initial dirty-work rule: first relevant lead adopts and reviews its listed trial changes; no blanket baseline commit.

## Workstream order

| # | Workstream | Depends on | Status |
| ---: | --- | --- | --- |
| 1 | [Production speech packaging](01-speech-packaging.md) | Approved workflow | Accepted |
| 2 | [Feature provider selection](02-feature-providers.md) | 1 | Accepted |
| 3 | [Explicit local setup and native Settings](03-local-setup-settings.md) | 2 | Not started |
| 4 | [Pruning and combined validation](04-pruning-validation.md) | 3 and UI gate | Not started |
| Final | [Whole-feature review](final-review.md) | 1–4 | Not started |

## Why these boundaries

Speech packaging has its own native C/resource toolchain and can be verified independently.
Provider migration and operation snapshots are one behavior change across persistence and
composition. Local installation, preparation, cancellation, removal and their Settings UI
stay together to avoid temporary interfaces or unusable installation APIs. The last stream
uses the bench for remaining measurements, records evidence, then retires the bench and
remaining candidates. It owns documentation and combined signed-app evidence. Work is sequential because composition and local adapters transfer ownership.

## Cross-workstream contracts

- One stable `local` provider; chosen transcription/cleanup pair and Kokoro voices remain pinned.
- Distinct Dictation/Read Aloud settings; Dictation includes cleanup. Operations capture the provider
  at admission. Keys remain provider-scoped, not feature-scoped.
- Readiness reports only; explicit setup installs/verifies then prepares. Runtime preparation
  uses installed files only, is feature-specific and shared by concurrent callers.
- Ready means prepared, not merely downloaded. Cancelling prevents stale completion/publication;
  retained verified files stay visible and removable. Removal and active work cannot race.
- Model manifests drive names, requirements, byte totals and ownership. Shared assets count once.
  External real cache directories and unrelated files are preserved.
- Standard native navigation/controls implement the chosen sidebar and Local cards/storage sheet.
  Demo data, sizes, navigation styling and flags are references, not production contracts.
- Bench stays usable only until stream 4 records required installed-model validation. Then remove
  its executable, dedicated tests, corpus tooling and unused support. Retain helpers/fixtures
  consumed by app/core tests and preserve user recordings/results. New testing tooling is separate.

## Ownership handoffs and current dirty work

- 1 adopts Kokoro frontend/text/model trial edits, their tests and build-app/package eSpeak changes.
  Also adopt the existing MLX restoration, CleanupModel API changes and Qwen speech retirement
  together with dependent candidate/bench edits so accepted commits compile independently.
- Stream 2 recovery on 2026-10-09 retains base `367a7ce165d9a8ac6610462877fdd9ef583dab42`.
  The recovery lead adopts the dirty feature-choice, operation, credential and provider-binding
  changes and their tests as implementation, including the new `FeatureProviderTests.swift`.
  Minimal Settings constructor adaptations in bench Transcribe and Apple live tests belong
  to 2. Demo dispatch/source, Parakeet timing, documentation and spike deletions remain
  with their existing owners. Fresh Core/App/release checks, independent review and
  focused closure passed before acceptance.
- 2 owns Settings.swift and app operation composition. SettingsView receives only necessary bindings
  for distinct provider choices; reuse those controls in 3 rather than adding temporary facades.
- 3 receives composition files for readiness/lifecycle integration and owns ModelStore/LocalModel,
  production SettingsView and feature installation/storage APIs. It also receives LocalCandidates
  for confirmed default selection and chosen manifest definitions, including cleanup definitions.
  Review existing dirty edits to those definitions when adopting them. Use SettingsDemo.swift read-only.
- 4 owns remaining candidate/dependency pruning, bench validation then retirement, and
  Parakeet timing logs. It also removes
  demo source/main dispatch after the UI gate. Qwen speech retirement is already accepted in 1.
- Package.swift/Package.resolved transfer 1 → 4; Kokoro loaders/manifests 1 → 3 → 4;
  controller and SettingsView 2 → 3. Earlier semantic contracts remain frozen.
- LocalCandidates transfers 1 → 3 → 4: stream 1 adopts only existing Qwen speech retirement,
  stream 3 makes the confirmed set usable for setup and UI;
  stream 4 removes remaining experimental selection/loser plumbing without changing that set.
- New files stay within the current stream's responsibility. Tests follow their behavior owner.
- Preserve app-testing.md, qwen-tts-follow-up.md, consolidated decision/setup notes and unrelated
  dirty work. The 29 spike-document deletions are authorized documentation cleanup; retain them,
  and include them with the scoped documentation changes in stream 4.
  Assigned productionization/spec documentation changes may be committed with 4.

## Whole-feature acceptance

All four rows and the UI gate pass. Every numbered packet has independently reviewed handoffs
and passing checks. Final covers every spec acceptance item and the complete net merge diff,
including retained spike changes predating execution. No losing runtime, settings demo
or bench target remains in the merged codebase. Completed spike workflow docs stay absent;
consolidated evidence and its archive recovery instructions remain.
No unapproved download occurs. Signed-app offline, mixed-provider, preparation, cancellation,
removal and combined-memory checks have recorded evidence, not just bench inference results.

## External validation gates

| Gate | Owner / placement | Status | Candidate and instructions | Evidence / resume condition |
| --- | --- | --- | --- | --- |
| Native Settings judgment | Aidan; stream 3 after closure, before acceptance | Pending | Signed `.build/local-productionization/EchoType.app`; inspect sidebar, feature settings, Local download/preparation and Manage files in both themes, including Keyterms contrast | Record candidate path/revision and Aidan's acceptance or concrete feedback. Resume only on acceptance |
| Signed-app functional evidence | Stream 4 lead; before acceptance | Pending | Same signed build; isolated owned test storage, installed chosen models, offline and mixed-provider checks | Record paths/configuration, outcomes, memory/load limitations and cleanup safety. Missing hardware/access evidence blocks acceptance |
| Public release hold | Stream 4 records; before any future publication | Pending | Parakeet provenance/notice handling and eSpeak combined-program licensing/source obligations | Explicit evidence before public release. May remain pending for a local implementation merge; no publishing is authorized |

## Escalations

None. A blocking lead adds a named entry containing decision needed, options, recommendation,
evidence, what it unblocks and user answer. Do not erase unresolved entries.

## Conventions learned

- Kokoro loads its public FluidAudio model store directly; do not call manager.initialize,
  which fetches unused English G2P. Check the internal repository link resolves to the
  verified installation before loading. Generated English data belongs in the app bundle.
- A signed validation host can establish isolated resource packaging; keep actual
  production-app functional evidence as the required stream 4 gate.

- Each feature has its own page; provider setup stays separate. Avoid horizontal tabs and accordions.
- Local needs clear model-card hierarchy and compact storage, with removal in Manage files.
- Native system controls support both themes; the Keyterms editor needs a visible boundary and focus.
- The 46.9-second bench preparation was first observed loading; subsequent boosted processes took
  0.75–0.80 seconds. Do not describe this as measured hotkey latency or a universal load guarantee.

- Stream 2 freezes `dictationProvider` and `readAloudProvider`. Only absent fields
  inherit legacy `provider`; present malformed or unknown fields fall back independently.
  Operations receive captured providers directly. Credential checks start no runtime work.
  Legacy local readiness side effects are documented seams for stream 3, not completed
  lifecycle work or signed production-app evidence.

## Decision and drift log

| Date | Decision or drift | Reason | Approved by | Affected streams |
| --- | --- | --- | --- | --- |
| 2026-10-09 | Confirm boosted Parakeet, Qwen3-4B and Kokoro/eSpeak; explicit setup includes preparation | Measured loading and accepted voice audition; user accepts visible initial wait | Aidan | 1–4 |
| 2026-10-09 | Retire the bench in stream 4 after validation, before merge | No expected ongoing use; future testing can recover evidence/code from git | Aidan | 4 / Final |
| 2026-10-09 | Consolidate spike evidence and remove completed spike docs from the merge | Preserve useful findings without 9,513 lines of task/review history | Aidan | 4 / Final |
| 2026-10-09 | Preserve Settings mock through UI acceptance, then remove shipped demo machinery | Concrete layout reference without permanent prototype code | Aidan | 3–4 |
| 2026-10-09 | Use a separate signed host for stream 1 isolated packaging validation; retain actual signed-app functional checks in stream 4 | The current app has no isolated-store launch path and MCP reaches the live GUI; independent review and closure accepted the bounded packaging check | Stream 1 lead | 1 / 4 / Final |
