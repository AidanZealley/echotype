# Local models whole-feature review

Status: Accepted on 2026-10-11. Complete net merge review, bounded F-R1/F-R2 remediation and fresh focused closure pass. Public release remains held; no merge or publication occurred.

## Reviewer task packet

The lead supplies code-review, applicable instructions, specification, plan contracts,
accepted handoffs and exact diff bases. Independently audit every spec acceptance item,
including the adopted trial work and the complete net merge diff against main. Check provider
migration/snapshots, feature-specific availability, explicit setup and late cancellation,
no download side effects, owned removal/unloading, native UI, reproducible speech resources,
chosen runtime/dependency pruning, recorded pre-retirement measurements and complete
bench retirement. Read the consolidated model
decision and setup/storage notes as context. Verify old spike workflow docs stay absent,
links resolve and archive recovery remains usable; historical evidence is not a reason
to keep experimental runtime infrastructure.

Check that mock source/dispatch are gone after UI acceptance and that docs do not imply
measured hotkey latency or guaranteed subsecond preparation. Public-release holds must remain
honest. Functional gaps cannot be relabelled release-only. Review the complete remaining diff
for machinery without a product requirement and update acceptance evidence after corrections.
Verify Package.swift, source/tests, scripts and CI have no bench target or active bench command.
Retained shared audio helpers must have real core/app test consumers. Historical evidence and
archive commands may mention the bench; they must not present it as an available final tool.
The final app evidence and deterministic tests must cover the exact post-retirement revision.

Use stream 4's reliable checks for the exact reviewed head. Rerun relevant checks after changes
and missing full CI-equivalent commands, rather than repeating expensive successful inference
without a reason. Required normal checks are deterministic tests with live variables removed,
the release build of EchoTypeApp, strict signed-bundle verification and `git diff --check`. Never run paid calls,
real-file deletion or simultaneous inference merely to broaden coverage.

```sh
env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test
swift build -c release --product EchoTypeApp
scripts/build-app.sh release .build/local-productionization/EchoType.app
codesign --verify --deep --strict .build/local-productionization/EchoType.app
git diff --check
```

## Initial whole-feature review

- Reviewer / configuration: independent whole-feature review subagent, inherited model and
  effort, Codex harness. Applied code-review, its coding practices and unslop. Read the
  specification, plan contracts/conventions, accepted stream handoffs and their reviews,
  consolidated decision and setup/storage notes. Reviewed production behavior and retained
  spike changes, not just stream 4's pruning.
- Branch, starting base, main comparison base and reviewed head:
  `feat/local-models-productionization`; execution start
  `077a1ec3973cd9629c527e7f9c419c6e4263ee93`; net merge comparison
  `4669f80f43a9be81008f8e01a4bb854f914b1b68`; reviewed HEAD
  `1d4deecbb217dd1e8fd71d99ddffeb18a1937c76`. Existing uncommitted workflow/spec
  scaffolds retain their recorded ownership. This reviewer changes only this section.
- Verification and supplied evidence:
  - Independently matched all 74 source/package hashes and both remediation-test hashes
    in `stream4-candidate.json` against current files. Its source inventory covers every
    surviving Swift source. Production and R1 executable hashes match the recorded
    `9f7b3e252eb37777892a59a4e3ec6196e05067dc036b650cfbab91fffabbd6ca` and
    `a5e98f2f68df68fa9585e1068d28a4d88e52719665be4fc2cd0c4a4384c0721b`.
  - Independently reran strict deep codesign verification on both signed bundles and
    `git diff --check`; all pass. Inspected and reused `stream4-r1-full-tests.log`,
    164 Core tests and 88 App tests, and `stream4-r1-packaging.log`, release EchoTypeApp
    build and signed packaging in 101.72 seconds. These cover the exact surviving
    implementation after bench retirement and S4-R1. No required normal command lacks
    reliable current evidence, so no build or deterministic test was repeated.
  - Inspected active package/source/tests/scripts/CI for bench commands or targets.
    None remains. `WAVRecording` and `AudioConverter` have real Core integration-test
    consumers, including chunking, timing and recording summaries. Rejected model
    implementations, manifests, dependencies, dedicated tests, corpus and Settings mock
    dispatch/source are absent. Historical spike records resolve at `2f231b9`.
  - Signed-app results are supplied lead/user evidence, not fresh GUI observations by
    this reviewer. Physical Local capture plus the next Dictation shortcut produced a
    paragraph in the previously blank TextEdit target and settled idle. Silence only
    renders Paused. Paragraph fidelity is unmeasured. Earlier evidence establishes xAI
    physical Dictation with Local Read Aloud selected, audible xAI MCP speech with Local
    Dictation selected, offline Local audible MCP completion, captured-provider/lease
    protection, physical Escape and settled controls. Successful Local selection-reading
    hotkey playback is not claimed. No paid request, inference, deletion, GUI/process
    action, model/preference/credential change or restart ran during this review.
- Acceptance audit:
  1. Settings migration preserves unrelated fields, initializes only absent feature
     choices from legacy `provider`, validates choices independently and writes only new
     choices. Keys remain provider-scoped. Literal migration/persistence tests cover this.
  2. Dictation/Test and selection/MCP reading resolve their own captured provider.
     Mixed/reversed fake-operation tests and supplied physical Dictation/MCP speech
     evidence establish independent wiring. No provider router or composite was added.
  3. Selection, initialization and readiness report without fetching. Only explicit setup
     reaches `ModelStore.start`; operation preparation rejects missing assets. Read Aloud
     setup/preparation does not touch Dictation. Dependency loaders use installed paths;
     Kokoro's conflict guard prevents fallback paths and chosen voices are preinstalled.
  4. Manifests drive requirements and pinned checksums. Setup separates download,
     verification and preparation. Generations, writer draining and feature ownership
     prevent late cancelled publication and duplicate shared downloads. Retained/corrupt
     installations recover and retry; meaningful temporary-store tests cover these paths.
  5. Installed features work offline under supplied signed-app evidence. Credential and
     service availability are feature-specific, with recovery copy/actions. Cleanup load
     failure preserves the existing unrevised-transcription policy. Queries do not retry
     loading or downloads.
  6. Operations keep provider/settings snapshots and runtime leases through teardown.
     Readings join cancelled synthesis; Dictation leases survive revision/insertion.
     Switching away releases unused runtimes after setup/operations settle and retains
     files. First specialization can recur; docs make no hotkey latency/subsecond guarantee.
  7. Managed inventory/removal includes current, retained, generated, obsolete and trial
     pronunciation files, excludes unrelated real caches and reports deletion failures.
     Setup/leases protect active files and cancelled writers drain before removal.
     However preparation can replace an unowned cache symlink, reported in F-R1 below.
  8. Frozen accepted native Settings uses feature pages, shared provider credentials,
     model cards and storage management. Standard AppKit split/toolbar controls and
     system colours implement the accepted Light/Dark design; keyterm editor has a
     boundary and focus state. No new design judgment is needed.
  9. Only the chosen Parakeet/Qwen/Kokoro adapters remain. Pinned eSpeak source inputs
     compile English resources at build time, with process-global conversion serialized
     by one actor and no runtime compiler/cache dependency. Shared audio test helpers
     remain justified. Pre-retirement combined quality/resource evidence is retained;
     exact post-retirement tests/signing and actual-app evidence match. Documentation
     retirement/completion gaps remain in F-R2. Public release licensing/provenance,
     Developer ID/notarization and hosted CI execution remain separate honest holds.
- Required findings by owner:
  - F-R1, stream 3 lifecycle/cache ownership. `LocalModel.swift:144–150` removes any
    existing symlink whose literal target differs from the requested directory. There
    is no ownership check. `ParakeetModel.swift:51` uses this on FluidAudio's fixed
    external tokenizer cache before its conflict guard. A valid link into another
    tool's store is therefore deleted/replaced, then the guard accepts the new target.
    The same helper is used by `KokoroModel.swift:27`. This violates the explicit rule
    to replace/remove only EchoType-owned links and can break another tool's cache.
    Preserve unowned links, resolve relative targets for comparison and fail with the
    existing useful conflict message. Replace a different target only when ownership
    is established. Add a focused temporary-fixture check covering preserved unrelated
    symlinks and permitted owned revision replacement. Existing real-folder tests do
    not cover this case. The static call path demonstrates the defect; no user-cache
    experiment is needed.
  - F-R2, stream 4 documentation. `docs/specs/test-harness.md:57` says the removed
    `Corpus/manifest.json` is committed and links to it; lines 41 and 90 describe the
    retired bench as an executable target. The historical intro does not identify
    these paths and instructions as unavailable archived behavior. `README.md:89`
    directs users to Settings > Updates, now inside About. The status introductions in
    workflow README, `0026-local-model-stack.md` and `local-models.md` still describe
    pre-S4 implementation/functional gates as pending after their acceptance. This
    leaves live setup/review guidance inconsistent and breaks the required retirement
    documentation/link audit. Make the historical harness explicitly archived with
    usable git recovery instead of a dead live corpus link; update current navigation
    and stream status while keeping whole-feature acceptance pending and public release
    held. Do not restore retired machinery or claim a wider functional test than ran.
- Optional observations: `Prose.swift:4,7` still exports `Prose` and `words` publicly
  from the retained spike diff. All surviving consumers are within EchoTypeCore; the
  bench's external scoring consumer is gone. Restore internal visibility during the
  deletion pass if desired. This does not block acceptance.
- Questions: none.
- Verdict: changes required. F-R1 is a storage-ownership defect and F-R2 leaves required
  production/retirement guidance inaccurate. Other audited acceptance behavior has
  sufficient code/test/signed-app evidence within the stated limits. Recheck the narrow
  corrections and refresh exact-revision deterministic/build/signature evidence after
  source changes; do not repeat paid calls or successful inference without a reason.

## Lead triage

- Accepted findings / owners: F-R1 and F-R2 accepted for one bounded Final remediation pass. Fresh implementation owns LocalModel.swift, its necessary Parakeet/Kokoro call-site adaptation, focused temporary-fixture tests, README.md, docs/specs/test-harness.md, docs/productionization/implementation/README.md, docs/decisions/0026-local-model-stack.md and docs/local-models.md. Preserve unrelated links/files and the existing accepted contracts.
- Rejected findings / reasons: none.
- Deferred optional observations: Prose public visibility is nonblocking and remains outside remediation.
- Drift requiring decision: none. The corrections enforce accepted ownership and documentation contracts. Root confirmed this bounded correction needs no further user approval.

## Resolution

- Implementation handoff: F-R1 and F-R2 implemented on 2026-10-11, on
  `feat/local-models-productionization` at unchanged HEAD
  `1d4deecbb217dd1e8fd71d99ddffeb18a1937c76`. Changes remain uncommitted for
  independent focused closure. Applied unslop and writing-for-agents to the documents.
- F-R1: `linkFolder` compares resolved, standardized destinations, including relative
  targets. Real folders and foreign links remain intact. Replacement requires the old
  target to be a direct child of EchoType's managed root, named for the requested
  manifest's model with a 40-hex revision, matching the existing inventory convention.
  Parakeet and Kokoro pass their manifest names; their useful conflict guards remain.
  Removal errors propagate. No new ownership registry, dependency or loader is added.
- Focused fixtures: `LocalModelLinkTests` uses an injected temporary managed root to
  verify owned revision replacement, unchanged equivalent relative links, real-folder
  sentinels, valid/dangling foreign relative links, nearby-root names and unknown model
  names. The Kokoro conflict test now checks real folders and valid/dangling foreign
  relative links, asserting the exact conflict error before voice conversion or
  FluidAudio. All fixtures are temporary; no real model/cache path was exercised.
- F-R2: README now directs users to Settings > About > Updates. The historical test
  harness is explicitly archived, with working `git show`/`git ls-tree` recovery and
  no dead live Corpus link. Workflow, model-decision and setup/storage introductions
  record Accepted streams 1–4 while Final correction closure remains pending. Licensing,
  provenance and Developer ID/notarization holds remain. Corrected file links resolve;
  both archived specification and corpus recovery commands succeed at `2f231b9`.
- Changed files: LocalModel.swift, ParakeetModel.swift, KokoroModel.swift,
  LocalModelLinkTests.swift, KokoroEnglishFrontendTests.swift, README.md,
  docs/specs/test-harness.md, docs/productionization/implementation/README.md,
  docs/decisions/0026-local-model-stack.md, docs/local-models.md and this Resolution.
  Existing plan edits and unrelated untracked files retain their ownership. Optional
  Prose visibility remains deferred. No product/UI, model choice or architecture changes.
- Sequential verification: focused fixture/frontend checks passed, 8 tests in 2 suites,
  including 5 foreign-path cases and 3 Kokoro conflict cases. The full deterministic
  `env -u XAI_API_KEY -u ECHOTYPE_FIXTURE_WAV -u ECHOTYPE_APPLE_LIVE swift test`
  passed 166 Core tests in 22 suites and 88 App tests in 13 suites. Live/installed-model
  opt-in tests remained skipped. Release EchoTypeApp build passed in 117.52 seconds;
  separate candidate packaging passed, followed by strict deep codesign verification
  and `git diff --check`. Logs and complete source/test identities are recorded in
  `.build/local-productionization/final-review-candidate.json`. The signed candidate
  executable SHA-256 is `3aecb8ececd0ac9fffcd57f645786e070b30eb3c50595dd269feaf4bb5e12977`.
- Evidence effects and boundaries: retained functional evidence predates this correction.
  The new candidate was built and signed only; it was not launched or used for inference.
  Provider routing, leases, insertion and UI are unchanged. Physical Local capture plus
  the next user Dictation shortcut produced TextEdit insertion and idle settlement;
  paragraph fidelity remains unmeasured. Silence only rendered Paused, not an automatic
  commit. Retained mixed-provider and audible MCP/offline completion evidence stands;
  successful Local selection-reading hotkey playback is not claimed. No broader speech
  quality or hotkey-latency conclusion follows from these tests.
- Contract conflicts or drift: none. Foreign-cache preservation enforces the accepted
  ownership rule, and documentation separates stream acceptance from Final closure.
  Existing EchoType.app/R1 bundles and their executable hashes are preserved. No paid
  request, app control/restart, preference, credential, permission or user-file change
  ran. User-owned PID 62901, TextEdit and all other apps remain untouched. Final acceptance
  and publication are not authorized by this implementation handoff.

## Focused closure

- Reviewer: fresh independent focused closure subagent, inherited model and effort,
  Codex harness. Applied code-review, coding practices and unslop. Read the original
  F-R1/F-R2 findings, lead dispositions, Resolution, specification, plan contracts and
  Conventions learned, and stream 4's accepted evidence/review/closure. The initial
  whole-feature audit remains the complete net-diff review; this pass checks its bounded
  corrections and affected boundaries without reopening the deferred Prose observation.
- Reviewed head: `1d4deecbb217dd1e8fd71d99ddffeb18a1937c76` plus the uncommitted
  F-R1/F-R2 corrections. Execution start remains
  `077a1ec3973cd9629c527e7f9c419c6e4263ee93`; net merge comparison remains
  `4669f80f43a9be81008f8e01a4bb854f914b1b68`.
- Finding outcomes:
  - F-R1 closed. `linkFolder` resolves relative destinations before comparison, preserves
    real folders and foreign valid/dangling links, and replaces only a link targeting a
    direct managed-root child with the requested manifest name and a 40-hex revision.
    Removal errors propagate. The temporary fixtures cover foreign-path sentinels,
    nearby-root/unknown-model rejection, owned revision replacement without deleting
    the old directory, and unchanged equivalent relative links. Both loader guards still
    reject conflicts. Kokoro rejects before voice conversion or its download-capable
    dependency; Parakeet rejects before CTC loading, and its preceding Unified/VAD loads
    use installed paths without downloads. No real user cache was exercised.
  - F-R2 closed. Current Updates navigation matches About. The harness clearly marks
    retired targets, corpus paths and commands as archived and unavailable, removes the
    dead live Corpus link and supplies working git recovery. The workflow/model/setup
    introductions distinguish Accepted streams and functional/UI gates from pending
    Final acceptance. I independently checked their local links and the archived
    specification/corpus recovery commands. Public-release holds remain explicit.
- Verification: independently matched all 81 build-source/resource hashes, all 49 test
  hashes and all five corrected-document hashes in `final-review-candidate.json`.
  Source, plugin, resource and test inventories have no missing inputs. All six recorded
  log hashes match. Inspected and reused the successful focused checks, 8 tests in two
  suites including five foreign-path and three Kokoro conflict cases, and full
  deterministic checks, 166 Core tests and 88 App tests with live opt-ins skipped.
  Release EchoTypeApp build passed in 117.52 seconds and separate candidate packaging
  passed. Independently reran strict deep codesign verification on FinalReviewCandidate.app
  and `git diff --check`; both pass. Its executable matches
  `3aecb8ececd0ac9fffcd57f645786e070b30eb3c50595dd269feaf4bb5e12977`.
  Preserved production/R1 executable hashes also match their recorded identities.
  Reliable exact-input logs cover the required build/test commands, so none was repeated.
- Boundary assessment: new links, links already resolving to the installed model and
  owned revision replacement retain their successful behavior. Foreign conflicts now
  stop preparation instead of overwriting another installation. The change leaves
  provider routing, operation snapshots, leases, capture, insertion, speech and accepted
  native UI unchanged. Current temporary-fixture evidence and signed packaging cover
  the correction; earlier signed-app functional evidence covers the unchanged pipeline.
  The new candidate was not launched or used for inference. No functional acceptance
  item is waived or reclassified as release-only.
- Retained functional limits: physical Local capture plus the next user Dictation
  shortcut produced a paragraph in the previously blank TextEdit target and idle
  settlement. Silence only rendered Paused; exact paragraph fidelity remains unmeasured.
  Prior accepted mixed-provider, audible xAI MCP, offline audible Local MCP, preparation,
  cancellation/retry, captured-provider/lease, physical Escape and owned removal evidence
  remains supplied lead/user evidence from the earlier candidate. Successful Local
  selection-reading hotkey playback is not claimed. Paid scope is exhausted.
- Final simplification assessment: the ownership check uses the existing managed-root,
  manifest-name and revision convention with one fixture injection. It adds no registry,
  loader, dependency, product setting or generic machinery. Focused tests protect actual
  ownership and pre-download boundaries. No new unjustified complexity or obsolete
  machinery appeared in the correction. Optional Prose visibility remains deferred.
- Remaining blockers: none for local implementation acceptance. Required findings none;
  new Optional findings none; Questions none. Public-release licensing/provenance,
  corresponding-source/notices, Developer ID/notarization and hosted CI execution remain
  explicit external holds. This review authorizes no merge or publication.
- Verdict: the accepted F-R1/F-R2 corrections pass focused closure and the whole-feature
  review can be accepted by the lead. Verification used file/log reads, signature and
  diff checks only. No UI/process control, restart, capture, inference, paid request,
  real-file deletion or user storage/preferences/permissions/devices/Keychain mutation
  ran. All apps, offline PID 62901 and the user's TextEdit content remain untouched.

## Completion record

- Final verification: Final is Accepted after complete execution-start and net merge audits, one bounded correction pass and independent focused closure. Current corrected implementation passed 166 Core/88 App deterministic tests, 8 focused fixture/frontend tests, release build, separate signed packaging and strict signature verification. Closure independently matched 81 source/resource inputs, 49 test files, five reviewed docs and six logs. Candidate evidence is `.build/local-productionization/final-review-candidate.json`; executable SHA-256 `3aecb8ececd0ac9fffcd57f645786e070b30eb3c50595dd269feaf4bb5e12977`. Completion-status text was finalized after closure; no source, test or build-resource input changed. Prior signed-app functional evidence remains attributed to its exact earlier candidate and applies to the unchanged successful installed-model and operation paths. The correction only preserves conflicting foreign paths, covered by current temporary-fixture tests. The Final candidate was not launched.
- External checks / public-release holds: Native Settings and required signed-app functional gates are Accepted. Licensing/provenance, corresponding-source/notices and Developer ID/notarization remain required before public release. Hosted CI was not run by this local workflow. Exact paragraph fidelity, first load after reboot/system update, energy, output-device latency and broad speech quality remain unmeasured. No successful Local selection-reading hotkey or automatic silence insertion is claimed. Paid authorization is exhausted. No merge or publication occurred; user-owned PID 62901, apps, TextEdit and real storage/preferences/permissions/devices remain preserved.
- Specification drift: none in Final. The previously reviewed bounded validation identity/home isolation remains recorded stream 4 drift. Optional Prose public visibility is deferred. Commit ownership includes only Final corrections and completion records; guide/brief/starter and unrelated app-testing/qwen follow-up remain untracked.
