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
| 3 | [Explicit local setup and native Settings](03-local-setup-settings.md) | 2 | Accepted |
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
- Feature Download/Prepare buttons give explicit consent on the current page; no repeated consent sheet. Feature setups can run concurrently, joining overlapping assets safely and cancelling independently.
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
- Stream 3 starts at `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. No existing dirty paths fall within its lifecycle or production Settings ownership. README, main demo dispatch, Parakeet timing, SettingsDemo, consolidated docs and spike deletions remain with stream 4 or their recorded owners. Stream 3 owns its packet and plan transitions before code edits. Its required Parakeet tokenizer-cache guard transfers loader ownership only for that guard; pre-existing phase timings remain stream 4 work. Additive readiness preparation/lease and speech-close contracts belong to stream 3 lifecycle integration.
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
| Native Settings judgment | Aidan; stream 3 after closure, before acceptance | Accepted, 2026-10-10 | Signed `.build/local-productionization/EchoType.app`, executable SHA-256 `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`; exact standard AppKit `.space` between split tracking separator and title | Final user conditional approval fulfilled. Actual Light/Dark spacer verified; fresh independent review and focused closure pass. Current provenance is `stream3-spacer-verification.json` |
| Signed-app functional evidence | Stream 4 lead; before acceptance | Pending | Same signed build; isolated owned test storage, installed chosen models, offline and mixed-provider checks | Record paths/configuration, outcomes, memory/load limitations and cleanup safety. Missing hardware/access evidence blocks acceptance |
| Public release hold | Stream 4 records; before any future publication | Pending | Parakeet provenance/notice handling and eSpeak combined-program licensing/source obligations | Explicit evidence before public release. May remain pending for a local implementation merge; no publishing is authorized |

## Escalations

None.

## Resolved S3-UI-01 history: Native Settings acceptance

Resolved on 2026-10-10 after the verified default spacer correction and fresh technical closure.
The following retains the earlier requests and candidate history; they are not current gates.

- Decision needed: Aidan accepts the concrete native Settings candidate or gives specific changes.
- Options: accept the implemented sidebar and Local/settings controls; request changes with page,
  theme, state and expected behavior. The chosen sidebar/model-card design remains approved.
- Recommendation: inspect the signed candidate and accept if its layout and interactions meet
  the retained reference. Agent checks passed in both themes, but cannot supply Aidan's judgment.
- Candidate: `/Users/aidanzealley/code/echotype/.build/local-productionization/EchoType.app`.
  Base `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` plus reviewed uncommitted stream 3 code and
  preserved trial sources. Corrected header executable SHA-256
  `f66bbce542535bbff668071d0417cb64277ce3691ca90de8099e60d309457450`.
  `.build/local-productionization/stream3-candidate.json` records all 95 current source/package hashes.
- Current safe inspection copies are signed `HeaderSettingsInspectionLight.app` and
  `HeaderSettingsInspectionDark.app` beside the candidate. They use unique bundle ids, disable the
  controller and contain identical normalized code/resources. They launch the real native Settings
  directly. Open Light with
  `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/HeaderSettingsInspectionLight.app`.
  Dark uses the exact sibling `HeaderSettingsInspectionDark.app` path. Close with Cmd-W and reopen
  with the same command. Inspect balanced page-header spacing, scrolled Local content under its
  material, native traffic lights, resize and the shorter pages in both themes. Do not press
  Download/Prepare or confirm removal during layout judgment. Manage files and cancellation remain safe.
- Current Light is open on scrolled Local, PID `30630`, started 08:26:22 Europe/London;
  current Dark is PID `30748`, started 08:26:42, on General. These fresh copies and windows
  are handed to Aidan. Existing user-owned PIDs `18183`, `23302`, `24222`, their prior inspection
  bundles and all live `/Applications/EchoType.app --mcp` processes were preserved. Prior
  `SettingsInspection*` and `NativeSettingsInspection*` copies are historical, not this header candidate.
- Evidence: packet 03 header correction handoff, fresh independent review and fresh focused closure
  all passed with no Required, Optional or Question findings. Header provenance is
  `.build/local-productionization/stream3-header-verification.json`; previous native-window and
  feedback provenance are historical. Fresh release packaging passed in 23.80 seconds, with three
  strict signatures, 95 matching source hashes and identical normalized code plus 22 resources.
  Earlier unchanged 26 Core and 85 App tests remain applicable. Actual Light/Dark scrolled Local,
  short General pages, native Zoom/restore and Cmd-W/reopen passed. Independent review inspected
  current Light scrolled Local and Dark General read-only. Material blur is API-supported rendered
  separation, not a pixel-level measurement; accessibility contrast/transparency preferences were
  not toggled. Saved-key navigation retains earlier fixture evidence. No setup, removal, provider,
  settings, permission or Keychain action ran. Production operation/inference evidence remains stream 4.
- What it unblocks: stream 3 acceptance and its scoped commit, then stream 4 combined validation
  and pruning. Actual signed production-app functional evidence stays a separate stream 4 gate.
- User answer: changes requested. Aidan reported the inspection copies launch uncloseable pill
  demos and do not provide a menu-bar icon from which to open Settings. Both identified inspection
  processes were stopped; the regular `/Applications/EchoType.app` process was preserved.
  Correct the inspection launch path and verify direct Settings access without HUD demos.
  Inspection-launch recovery started on 2026-10-09. A fresh implementation agent owns the minimal
  correction and a fresh reviewer will check the corrected startup and artifacts.
  Further feedback on 2026-10-10 after Aidan ran a working build:
  - Keep the sidebar layout, remove its show/hide toggle, buggy opening animation and blank
    header space above Settings pages.
  - Use one consistent set of standard macOS controls, grouped sections, row layouts and readable
    system text sizes across Dictation, Read Aloud and the rest of Settings.
  - Each feature's Download button should directly start only that feature's downloads and show
    status on the page. Remove the redundant consent dialog that repeats page information.
    Allow both feature downloads to be started, rather than disabling one for the other's setup.
  - Replace the tiny-arrow licence disclosure with small readable text/links at the bottom,
    retaining required notices. No accordion or arrow-only hit target.
  - Use the attached Raycast screenshots as consistency references for grouped rows, vocabulary
    editing, permission-granting rows and an About page containing version, updates and links.
    Prefer native controls; no Settings search is needed. Back/forward navigation and a title
    revealed on scroll are desired where supported without fragile custom machinery.
  - Reference images are `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-863f9b98-894e-4329-92eb-8bcbddc118bb.png`,
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-2817b394-a669-4f3d-9635-0bbed7284b66.png` and
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-6b1dec1d-21f4-416c-9c74-d721b1c879b4.png`.
  Further window feedback and authorization on 2026-10-10:
  - Aidan confirmed the pages are consistent and should be preserved. Correct the window/sidebar
    integration using standard AppKit or SwiftUI elements.
  - Remove the huge blank strip to the left of the sidebar. Use appropriate native system
    materials and window appearance rather than the solid white appearance in Light mode.
  - Native window chrome, sidebar, materials, controls, spacing and typography are the brief.
    Any custom integration should be minimal and justified; choosing native controls alone
    does not establish that the surrounding window is configured correctly.
  - Aidan explicitly requested these updates. The screenshot is
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-c32ae4de-dd4c-4c5f-baad-f899cdd2aba3.png`.
  Further header feedback on 2026-10-10 after reviewing the native window correction:
  - Aidan says everything else looks fine. Preserve the current consistent pages and corrected
    native window/sidebar/material configuration.
  - The page header has insufficient bottom padding. Give it balanced spacing and native blur
    material so scrolled content beneath it is separated cleanly, following the Raycast reference.
  - Remove the fixed visible `EchoType Settings` header to avoid stacked app-title/page-title bars.
    Keep ordinary native window controls and accessible window identity.
  - Current header screenshot is
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-a78d8b63-2f7b-485b-a361-9ea0fbe74cd0.png`.
    Header reference is `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-5495a124-54ee-4afb-a713-f8a97ff83644.png`;
    window reference is `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-f2280a9d-4511-4a15-8085-6231a461309e.png`.
  Additional header feedback and authorization on 2026-10-10:
  - The latest header has too much space above the page title and overly strong blur. Aidan
    requested a native toolbar/titlebar approach after a read-only source explanation showed
    the current header is custom SwiftUI Text/padding/safeAreaInset composition using regularMaterial.
  - Aidan's `Try that` authorizes replacing that assembled header with actual native toolbar/titlebar
    integration, resolving safe-area ownership and using the system bar material/treatment.
    Preserve approved pages, permanent sidebar and other lifecycle/Settings behavior.
  - Verify rendered spacing and treatment honestly, not just symmetric padding in code. Keep
    accessible identity without the duplicated visible app-title bar. No custom blur shader.
  - Current screenshot is
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-6d8ece55-f153-4197-9a81-84026b996f80.png`.
  Final header instruction and conditional UI acceptance on 2026-10-10:
  - Aidan explicitly requires AppKit/SwiftUI defaults and no invented UI standards. Fix only the
    missing default toolbar spacing by using AppKit's `NSToolbarItem.Identifier.space` between
    the split tracking separator and existing title item. Do not redesign or tune custom padding.
  - Aidan said: `Fix that one header thing and let's just mark this settings UI as approved`.
    This authorizes recording native Settings judgment as accepted once that exact spacer fix
    is verified. No further UI acceptance question is needed. Preserve all other Settings UI.
  - The current spacing screenshot is
    `/Users/aidanzealley/.t3/userdata/attachments/c4996cf4-1a46-4225-b061-11c91bca33e7-198c30f3-c30a-46fd-966b-7ed4c399ed53.png`.
  UI acceptance is authorized after the default spacer correction is verified. Meaningful requested corrections
  require focused review as the lead guide specifies. Work remains uncommitted while blocked.

## Conventions learned

- Kokoro loads its public FluidAudio model store directly; do not call manager.initialize,
  which fetches unused English G2P. Check the internal repository link resolves to the
  verified installation before loading. Generated English data belongs in the app bundle.
- A signed validation host can establish isolated resource packaging; keep actual
  production-app functional evidence as the required stream 4 gate.

- Stream 3 operation/bench callers must acquire `Readiness.prepare(feature)` and keep its
  runtime lease through teardown. `Readiness.check` only reports. Local speech close must join
  synthesis before lease release. Explicit preselection setup retains Ready; a provider switch
  away during setup releases that feature after setup and operation leases settle.
- Shared provider panes need provider-specific SwiftUI identity so credentials reload when
  navigating between Apple and xAI. Temporary read/write-denied credential fixtures are UI
  evidence only and do not replace actual production-app checks.

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
| 2026-10-10 | Refine established sidebar and consistent native grouped rows; use page-button consent and concurrent feature setup | Explicit UI feedback after working build; duplicate consent sheet removed | Aidan | 3 / 4 / Final |
| 2026-10-09 | Use a separate signed host for stream 1 isolated packaging validation; retain actual signed-app functional checks in stream 4 | The current app has no isolated-store launch path and MCP reaches the live GUI; independent review and closure accepted the bounded packaging check | Stream 1 lead | 1 / 4 / Final |

| 2026-10-10 | Omit Settings back/forward history and scroll-revealed title | Native grouped forms and permanent sidebar satisfy the selected design; custom effects would add fragile machinery. Aidan requested these only where supported simply | Stream 3 lead, Aidan UI accepted 2026-10-10 | 3 |

## Stream 3 feedback recovery, 2026-10-10

- Recovery lead verified integration HEAD `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d` and inventoried all dirty/untracked paths. The reviewed stream 3 implementation remains adopted. README, main demo dispatch, SettingsDemo, Parakeet timing, consolidated notes and spike deletions remain preserved for stream 4.
- Recovery established a signed candidate with 94 matching source hashes and verified direct native Settings launch in both themes. The fresh independent feedback review found S3-FR1 and S3-FR2 below. Both are accepted for the single remediation pass, followed by fresh focused closure. No UI acceptance is inferred from Aidan running the build.
- The explicit 2026-10-10 feedback authorizes direct feature-specific Download/Prepare consent on the page and independent concurrent feature setup. It supersedes the old duplicate consent-sheet design. Cancellation, verified shared assets, readiness, leases, safe removal and the public release hold remain required.
- Stream 3 owns corrections in App.swift, SettingsStore.swift, SettingsView.swift, LocalSettingsPane.swift, LocalSetup.swift, LocalModel.swift, ModelStore.swift and focused lifecycle/store/app tests, with small native Settings helpers if needed. Other stream 3 paths are read-only unless a necessary seam is reported. The lead owns plan transitions; implementation owns an appended correction handoff in packet 03. No concurrent shared edits, builds or inference.
- The implementation reported and lead approved the small LocalModel preparation-admission seam on 2026-10-10. Admission occurs synchronously under lifecycle protection before awaiting the shared loader, closing a cancellation race without changing operation preparation semantics. The interrupted conditional SceneBuilder launch correction did not compile; declarative native scenes will replace it before a fresh candidate is prepared.

- Completion recovery adopted the existing feedback corrections without source edits. Dark native inspection and candidate/copy provenance passed. Fresh independent review accepted two required findings for remediation: S3-FR1 must retain intact installed files when a sibling is missing or truncated; S3-FR2 must drain a cancelled shared-manifest writer before admitting a newly requested feature to a fresh generation. The current pre-remediation candidate remains layout evidence only. No builds or inference were repeated during recovery review.

- Completion recovery closed S3-FR1 and S3-FR2 after the single bounded remediation and fresh
  independent focused closure. Final evidence is 26 Core / 85 App tests, successful release
  packaging, three strict signatures and 94 matching source hashes. Stream 3 is technically
  closed and remains Blocked only on explicit native UI acceptance, S3-UI-01. No commit,
  merge, publication or stream 4 work started. User processes and unrelated work were preserved.

- Final corrected Light inspection is open for Aidan. PID `18183`, started 2026-10-10
  07:58:49 Europe/London, exact command
  `/Users/aidanzealley/code/echotype/.build/local-productionization/SettingsInspectionLight.app/Contents/MacOS/EchoTypeApp`.
  Native window `EchoType Settings`, id `settings-inspection`, opens on Dictation.
  This process is intentionally left open and its ownership transferred to Aidan.
  Preserve it as a user process. Final launch provenance is
  `.build/local-productionization/stream3-final-inspection-launch.json`.

## Stream 3 native window recovery, 2026-10-10

- Recovering the explicit window correction at unchanged HEAD `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. Adopt existing dirty App.swift and SettingsView.swift container work as implementation, preserve approved pages and lifecycle/store fixes. All unrelated dirty paths retain their recorded owners.
- Fresh implementation, independent review and focused closure will cover the narrow native window/container correction. UI acceptance remains pending. User-owned Light PID 18183 and all other user app processes are preserved.

- Native window independent review passed with no Required, Optional or Question findings. The lead accepts that disposition; no remediation is needed. Fresh focused closure verifies this narrow correction and refreshed candidate provenance.

- Fresh native window focused closure passed with no Required, Optional or Question findings. Source changes are limited to scene default sizes, the root view frame/material and a 35-line native split-controller bridge. No lifecycle/store/page-control behavior changed. Earlier 26 Core/85 App results remain valid; affected release build, 95 source hashes, normalized identical code/resources and three strict signatures passed.
- Current candidate executable SHA-256 is `da8c78d971733c2996a1475f3baa54dbc36d982e1124f462c96e1b9f6e51b528`. Provenance is `.build/local-productionization/stream3-native-window-verification.json`; previous feedback provenance remains historical.
- Original 900-point window centered a fixed 790-point root, producing a 55-point leading gutter. A native NSSplitViewController with a non-collapsible sidebar item now fills the window. System material backs the detail. The purple control in the original screenshot was macOS Window sharing, not an app sidebar toggle; no system sharing/recording chrome was removed.
- Actual Light/Dark rendered checks establish sidebar x=0, native traffic lights/titlebar, system materials, native Zoom resize and close/reopen. Independent review inspected both current windows read-only. OS accessibility contrast/transparency preferences were not toggled; native material adaptation is retained. Production operation/inference validation remains stream 4.
- New corrected safe windows remain open, Light PID `23302` and Dark PID `24222`. Dark was preserved after CUA reported user activity. Original user-owned Light PID `18183`, its bundle and all /Applications MCP processes were preserved. No live setup/removal/download/Keychain action occurred. Open the corrected Light with `open -a /Users/aidanzealley/code/echotype/.build/local-productionization/NativeSettingsInspectionLight.app`; use the sibling NativeSettingsInspectionDark.app for Dark. Close with Cmd-W and reopen normally. Inspect both themes and pages; do not invoke setup or confirm removal for layout judgment.
- Stream 3 remains Blocked on `S3-UI-01` until Aidan explicitly accepts the full native window. Page consistency acceptance does not imply full UI acceptance. No commit, merge or publication occurred. No specification drift.

## Stream 3 header recovery, 2026-10-10

- Recovering only the newly authorized page-header spacing/material and redundant visible window-title correction at unchanged HEAD `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. Prior native/sidebar, grouped-page and lifecycle/store corrections remain adopted and preserved. Unrelated dirty files retain their owners.
- Fresh implementation owns narrow changes in App.swift, SettingsView.swift and SettingsSplitView.swift, plus a small native header helper only if needed, and an appended packet handoff. The lead owns plan transitions. Sequential implementation, independent review and focused closure will refresh signed candidate provenance before blocking on explicit UI acceptance.
- User-owned inspection PIDs 18183, 23302 and 24222, their bundles and all live /Applications processes are preserved. New verification uses uniquely named copies and ids. No real setup, removal, cache or Keychain action is authorized for layout checks.

- Header implementation completed and source is frozen. The title now uses a top safe-area inset with symmetric 16-point spacing and standard regularMaterial; a private native split-controller subclass hides visible NSWindow title text while preserving its title string and native controls. No other source paths changed. Fresh release, 95 source hashes, three signatures and identical normalized code/resources passed. Independent review now covers this narrow correction.

- Fresh header independent review passed with no Required, Optional or Question findings. The lead accepts that disposition without remediation. Actual new Light scrolled Local and Dark General were inspected read-only, and source/artifact/signature identity was independently checked. Fresh focused closure now verifies the narrow correction and evidence, without restarting whole-stream review.

- Fresh header focused closure passed with no Required, Optional or Question findings. The title
  inset and native title visibility correction are technically closed. Current candidate SHA-256
  is `f66bbce542535bbff668071d0417cb64277ce3691ca90de8099e60d309457450`, with header provenance
  `.build/local-productionization/stream3-header-verification.json`. Fresh safe Light PID30630
  remains open on scrolled Local; Dark PID30748 remains on General. Only SettingsView and
  SettingsSplitView source changed. UI acceptance is still pending S3-UI-01; no commit, merge,
  publication or stream 4 work began. No specification drift.

## Stream 3 native toolbar recovery, 2026-10-10

- Recovering the authorized replacement of the custom padded safe-area header with native toolbar/titlebar integration at unchanged HEAD `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. The earlier assembled header is retained as historical evidence only. Approved pages, permanent sidebar and lifecycle/store behavior remain adopted.
- Fresh implementation owns SettingsView.swift, SettingsSplitView.swift and App.swift only where necessary for native window integration, plus its appended packet handoff. No unrelated dirty work is discarded or committed. Implementation, independent review and focused closure run sequentially.
- Preserve all user inspection processes, including PIDs 30630 and 30748, and every live /Applications MCP process. New checks use unique signed inspection copies. No setup, settings edit, removal, download or Keychain action is authorized. UI acceptance remains pending S3-UI-01.
- Phase: implementation complete; fresh independent review in progress. Native NSToolbar uses unifiedCompact treatment, a tracking separator and standard NSTextField title content. The system owns the 40-point bar and measured 12/16/12 title metrics. Custom padded inset removed; accessible window identity preserved. Fresh signed candidate SHA-256 `837378c7ca439cf93b0f3e8b6f4adab2d2c52935755c48009dcdc5b755071bfd`, with 95 source hashes, three signatures and identical normalized code/resources. Final Light PID40641 and Dark PID40642 remain open, transferred to user ownership. Diagnostic PIDs39620 and40217 and all previous user processes remain preserved.

- Native toolbar independent review passed for source behavior with no Required or Question findings. Optional S3-TO1 identifies stale nested release/provenance pointers in candidate metadata. The lead promotes this narrow evidence bookkeeping correction so the concrete candidate consistently references current toolbar verification. Source remains frozen; no rebuild is required. Fresh closure follows.


## Stream 3 final default spacer recovery, 2026-10-10

- Recovered native toolbar independent review and S3-TO1 metadata resolution at unchanged HEAD `e6edc9cf03ef32f20d09164d17ca6dd8dac8387d`. Prior fresh toolbar closure was interrupted and is not assumed complete.
- The final user instruction authorizes only AppKit's standard `.space` between the existing tracking separator and title item. A fresh implementation agent owns that one-line source correction and current signed candidate evidence. No custom padding or other UI change is allowed.
- Aidan's conditional UI approval will close S3-UI-01 once the exact spacer is verified and fresh independent review and focused closure pass. No further approval question is required. Earlier lifecycle/page review and 26 Core/85 App checks remain applicable.
- All user-owned inspection processes and unrelated dirty work remain preserved. Stream 3 acceptance includes a scoped commit. Stream 4 retains production functional evidence, trial timing, demo retirement and remaining documentation ownership.

- Exact standard spacer implementation passed fresh release packaging in 22.98 seconds, 95 source identities, three strict signatures and normalized identical code/resources. Current production executable SHA-256 is `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`. Current evidence is `.build/local-productionization/stream3-spacer-verification.json`; historical toolbar/header artifacts remain historical.
- Fresh safe Light PID 75712 and Dark PID 75743 show the default gap in actual native Settings. Existing user bundles/processes remain untouched. Source is frozen for fresh independent review, followed by focused closure.

- Fresh default spacer independent review passed with no Required, Optional or Question findings. The lead accepts that disposition without remediation. Reviewer independently verified the complete recovered native toolbar change, current source/artifact/signature identities and metadata, and read-only Light Local/Dark General show the standard gap. Fresh focused closure now verifies the interrupted toolbar scope and S3-TO1 resolution as well as the exact final spacer.


## Stream 3 acceptance and stream 4 handoff, 2026-10-10

- Fresh default spacer focused closure passed with no Required, Optional or Question findings. It closes the previously interrupted native toolbar correction and S3-TO1 bookkeeping resolution. All required stream 3 reviews and meaningful checks are complete.
- Aidan's final answer was `Fix that one header thing and let's just mark this settings UI as approved`. The exact authorized fix inserts AppKit's standard `.space` between the existing split tracking separator and title item. Actual Light/Dark windows and independent verification establish that correction. Native Settings judgment is Accepted and S3-UI-01 is closed; no further UI approval is required.
- Frozen UI contract uses a native `NSToolbar`, `.unifiedCompact` system treatment, split tracking separator and default fixed-space item. Its title is ordinary `NSTextField` content inside a toolbar item. AppKit owns header sizing/material/spacing. There is no custom padded header, titlebar lookup or custom blur. Approved pages, permanent sidebar and lifecycle contracts are preserved.
- Current candidate SHA-256 is `35414727620eb844958740124043b90acde3604e3910857ee400183074c52e40`. Fresh release packaging passed in 22.98 seconds, all 95 source identities match, all three strict signatures pass and normalized code/resources match. Unchanged 26 Core/85 App checks remain applicable. Current evidence is `.build/local-productionization/stream3-spacer-verification.json`; older artifacts remain historical.
- Stream 3 accepts its lifecycle/setup/storage, production Settings source/tests and packet/plan records in one scoped commit. Only Parakeet's tokenizer-cache conflict guard is staged; its original timing instrumentation stays dirty for stream 4. README, main demo dispatch, SettingsDemo, test-harness follow-up, consolidated docs/specification and spike deletions retain stream 4 or recorded ownership. Final specification toolbar text is handed to stream 4 with that document.
- Current signed safe inspection bundles are `SpacerSettingsInspectionLight.app` and `SpacerSettingsInspectionDark.app`. User-owned PIDs 75712/75743 remain open; earlier bundles and observed user processes are untouched. No real setup, download, removal, provider/settings edit, Keychain action, merge or publication occurred during final UI verification.
- Stream 4 may now begin pruning/demo retirement and required signed production-app offline, mixed-provider, loading, cancellation, removal and combined-memory validation. Controller-disabled Settings copies do not establish that functional gate. Public-release obligations remain the existing explicit hold. No specification drift.
