# Productionize the local model provider

Status: product choices confirmed, updated 2026-10-09. Productionization is on a branch
from the completed local-model spike. Both model sets and the Settings direction are
confirmed. Aidan approved the implementation workflow on 2026-10-09. Streams 1–4 are accepted; whole-feature review remains before final acceptance.

## Goal

Make Local a supported provider with explicit installation and removal, and let users
choose providers independently for Dictation and Read Aloud. Transcription and cleanup
stay together under the Dictation provider.

A supported example is xAI for Dictation and Local for Read Aloud. That setup installs
and loads only Local's speech models. Users can see what EchoType has downloaded and
reclaim its space through Settings.

The [model decision record](../decisions/0026-local-model-stack.md) preserves measured
tradeoffs, chosen revisions and known limitations. This spec replaces the spike's
automatic-download and single-provider
behaviour for the production implementation. Full spike records remain recoverable
at commit `2f231b9`; completed workflow documents are not part of the production tree.

## Scope

- Separate Dictation and Read Aloud provider choices, including migration.
- Explicit installation, cancellation, retry and removal of EchoType's local models.
- Feature-specific preparation, credentials, availability and errors.
- Production model selection and removal of rejected candidates and obsolete spike code.
- Targeted automated tests and signed-app validation of these changes.

Use the bench for the remaining model-stack measurements during this pass, then retire
it before merging. Record useful evidence first; remove the executable, dedicated tests,
corpus tooling and unused support while retaining helpers/fixtures consumed by core/app
tests. Preserve user recordings/results and archived code. The separate
[app testing follow-up](app-testing.md) adds three testing tiers independently of the bench.
New automation commands, baseline comparisons, quality thresholds and general workflow
machinery are outside this pass.

Arbitrary model repositories, a model picker, separate cleanup providers, a cleanup
toggle, automatic model updates and new languages or hardware tiers are outside scope.
The deferred [Qwen3-TTS voice investigation](qwen-tts-follow-up.md) preserves the spike's
findings and future voice-control ideas without keeping its implementation in this pass.

## Model decisions

Aidan confirmed the Dictation stack after the [loading investigation](../productionization/parakeet.md).
The first observed boosted preparation took 46.9 seconds; subsequent fresh processes
prepared in 0.75–0.80 seconds. These are bench preparation measurements, not hotkey
response times. A long initial preparation is acceptable when presented during explicit setup.

| Feature | Confirmed choice | Remaining validation |
| --- | --- | --- |
| Dictation transcription | Parakeet Unified EN 0.6B, 640 ms INT8, with CTC keyterm boosting | Combined-set and signed-app loading; retain visible first-use preparation |
| Dictation cleanup | Qwen3-4B-Instruct-2507, four-bit, at the measured pinned revision | Quality and cancellation after dependency restoration |
| Read Aloud | Kokoro v1.0 Core ML with eSpeak NG English phonemization | Production packaging and lifecycle; retain Heart and Emma voice ids |

Ship one supported model set per feature. Preserve the provider id `local` and stable
voice ids for retained voices. Keep the spike's measured limitations visible in the
production decision, including English support and resource costs.

### Confirmed speech pipeline

On 2026-10-09, Aidan accepted the eSpeak comparison build's audio and chose this
pipeline for productionization. See the [comparison notes](../productionization/kokoro-espeak-comparison.md)
for pinned revisions, implementation details and measurements. The accepted path is
written-form normalization, phrase-aware eSpeak NG, conversion to Kokoro v1.0's
phoneme alphabet, then the existing Core ML synthesis chain. Retain the explicit
clock a.m./p.m. preparation and the phoneme-length protection.

Replace the trial's packaging with a reproducible build of the required English
pronunciation data from pinned sources. Bundle that compiled data and read it without
runtime compilation, downloads or copying it into users' model storage. Production
builds must not depend on a developer's model cache, tests having run first, or the
comparison-only build environment variable. Keep eSpeak's process-global state
serialized across readings and accent changes.

Remove the previous article override and FluidAudio's unused English G2P models,
lexicons and cache links from the speech installation and preparation path. Preserve
FluidAudio's Core ML backend and any assets it actually requires. Verify this with
an offline signed-app run containing only the declared production speech assets.
Inventory older frontend assets and the trial's generated pronunciation directory
so users can remove them through the same storage management as obsolete models.

Keep the pronunciation checks for consonant and vowel sounds, "hour", "university",
literal "thee", both accents and long sequences. Validate numbers, clocks, punctuation,
speed, cancellation and a long reading through the signed app after cleanup.

The eSpeak dependency is GPLv3. Before a public release, provide GPL-compatible
licensing for the combined program, corresponding source and build instructions,
and the required notices. Personal and commercial use are permitted by GPL;
do not impose a personal-use-only restriction. This choice does not require changing
the repository's overall licence during the local evaluation.

## Provider selection and stored settings

Settings stores two explicit choices: the Dictation provider and the Read Aloud provider.
The Dictation provider supplies both transcription and its optional cleanup service.
Reading a selection and speech supplied through MCP both use the Read Aloud provider.
The existing microphone Test uses the Dictation provider.

For existing installations, initialise each missing new choice from the legacy
`provider` value. An explicitly stored new choice takes precedence. Validate each choice
independently using the registry's existing unknown-provider fallback. New installations
retain the current default provider for both features.

Keep legacy decoding as a migration boundary, but write only the new choices. Preserve
hotkeys, language, keyterms, input device, reply settings, API keys and per-provider voice
and speed preferences. Language resolution and keyterm limits follow the Dictation
provider; voice and speed resolution follow the Read Aloud provider.

Each operation snapshots its provider and settings when admitted. A provider change
applies to the next operation. It does not redirect or restart an active dictation or
reading. Existing admission, cancellation and interruption rules remain in force.

## Settings experience

Show the provider choice alongside the settings for each feature. Show the selected
feature's availability and a useful next action, such as adding a key, downloading models
or retrying a failed load.

Manage credentials and local storage in a shared Providers area. A provider's API key
appears once even when both features use it. Credentials remain keyed by provider id.
Removing a key explains which selected features it affects. Switching providers retains
stored keys and reading preferences.

Aidan selected the sidebar structure from variant C on 2026-10-09, refined to separate
Dictation and Read Aloud destinations instead of a combined Overview. Each feature page
owns its provider choice, feature settings and availability. Shared provider setup and
storage remain separate destinations, alongside General, Keyterms, Agents and Updates.
Keep each page focused on its concern rather than combining feature and provider settings
on one long page. See the [layout study](../productionization/settings-variants.md).
The Local page presents separate Dictation and Read Aloud model cards with model names,
size, installation status and actions. A compact storage summary opens a Manage files
sheet for removal, retained downloads and obsolete assets. Provider assignment stays
on the feature pages. Sources and licences appear as a secondary link.
The focused mock is the implementation reference for layout and state presentation.
Retain it through the Settings workstream, then remove its source and demo entry point
after the production UI is accepted. Use standard macOS SwiftUI sidebar navigation,
forms, editors and controls, with system colours and readable system typography.
Use consistent grouped rows across feature, vocabulary, permissions and provider pages.
Keep the sidebar visible without a show/hide toggle or a blank header area. Use the native
AppKit unified compact toolbar with a split tracking separator, standard fixed-space item
and page-title item. AppKit supplies spacing and material; the page title uses ordinary
NSTextField content in its toolbar item. About includes
version, updates and links. No Settings search is required. Native navigation history and
scrolling titles are optional where supported simply; avoid custom toolbar effects.
Sources and licences use readable secondary text/links at the bottom, without a disclosure
accordion. These refinements were explicitly requested by Aidan on 2026-10-10.
Custom arrangement of the model cards
is appropriate; copying the mock's hand-built navigation is unnecessary. The Keyterms
editor needs a visible boundary and focus indication in both themes, especially dark mode.

## Explicit local installation

Selecting Local saves the provider choice and shows setup information. It starts no
downloads. App launch, opening Settings, status checks, hotkeys, microphone Test and MCP
speech also start no local downloads.

Settings offers installation by feature: Dictation and Read Aloud. Dictation's installation
includes transcription, cleanup and their supporting assets as one supported set. Users
can install either feature or both, including before selecting Local for that feature.

Before the user starts installation, show:

- Each required model's name and purpose, grouped by feature.
- Download size for missing files, distinguishing already installed assets.
- The total download required for the selected features.
- A short explanation that the models run on this Mac and work offline after installation.
- Available disk space and any known temporary storage requirement.
- A route to model source and licence information.

Each feature page and Local card shows these requirements before its Download button.
Pressing Download is explicit consent and starts only that feature, then prepares it
after verification. Show progress on the page before reporting Ready. Already installed
features offer Prepare or Retry directly. Do not repeat the page information in a consent
sheet. Users can start Dictation and Read Aloud setup independently and concurrently.
Count shared assets once, reuse overlapping verified downloads and preparation safely,
and cancelling one feature must not cancel assets still needed by the other.
This interaction was explicitly requested by Aidan on 2026-10-10.

Show progress, the feature being installed and failures with Cancel or Retry as appropriate.
Cancellation stops network work and prevents later publication or loading from that
cancelled attempt. Already verified files may remain for retry; show their retained disk
usage and offer removal. Retry reuses verified files and fetches missing or invalid files.
Recovery works after relaunch without treating an incomplete set as installed.

Keep pinned revisions, file sizes, checksum verification and publication only after all
required files verify. Runtime libraries load from the verified store and do not fetch
their own fallback assets. A known insufficient-space condition prevents installation
with an actionable message; a disk-full failure leaves recoverable or removable data.

## Readiness and loading

Separate reporting status, installing assets and preparing a runtime. A local readiness
check reports current state without starting downloads or loading models. Status can
distinguish models needing installation from installed models awaiting preparation.

Explicit setup includes preparation so the user sees the expensive initial loading
in Settings before attempting dictation or reading. Already installed features offer
Prepare or Retry preparation without downloading again. Installed and Ready are distinct.
Cancelling setup during preparation prevents a late Ready result from that cancelled
attempt; verified files remain installed and can be prepared or removed later.

After restart or unloading, an operation can prepare its installed models again, with
visible loading status. Do not imply a universal subsecond load: Core ML may repeat
specialization after system or cache changes. Readiness queries still only report state.
Preparation runs off the main actor and reuses loaded weights for later operations.
Preparing Read Aloud does not load transcription or cleanup. Preparing Dictation does
not load speech. Concurrent callers share preparation rather than starting duplicate work.

Selecting another provider stops initiating work for the old selection. Switching away
from Local retains downloaded files but releases unused local runtimes once no operation
uses them. Keep models needed by the other Local feature. A feature-specific memory
policy is sufficient; idle timers and general cache eviction are outside scope.

Missing transcription assets block Local dictation with a route to Settings. Missing speech
assets block Local reading in the same way. Preserve the existing dictation policy that
cleanup unavailable at startup allows unrevised transcription with the No cleanup hint.
Installation still offers the complete Dictation set, rather than a separate cleanup choice.

Failures offer an explicit retry where recovery is possible. Repeated status checks do
not retry failed downloads or model loads indefinitely. Fully installed features work
offline without contacting model hosts.

## Credentials and feature availability

Check credentials for the provider used by the attempted operation. A missing xAI
Dictation key does not prevent Local Read Aloud, and a missing local voice model does not
prevent xAI Dictation. Errors name the provider captured by that operation.

Settings and menu-bar status represent partial availability clearly. A single global
credential flag must not imply that both features are unusable when only one is blocked.
Keep the current error presentation and operation lifecycle where they already fit.

## Model removal and storage ownership

Settings shows actual on-disk usage for installed assets, incomplete downloads and generated
runtime files. Offer Remove Dictation models, Remove Read Aloud models and Remove all
local models. Also make obsolete installed revisions visible and removable after upgrades.
Shared assets are removed only when no retained feature needs them.

Removal confirms the affected features and estimated space reclaimed. It deletes downloaded
payloads, partial files and generated files owned by that model set, and removes only
EchoType-owned runtime cache links. It preserves settings, API keys, other applications'
files and unrelated runtime caches. Account for existing spike installations in the inventory.

Disable removal of a feature while its operation, preparation or download is active,
with a reason and the relevant Stop or Cancel action. Once that work has ended, release
loaded references before deleting files. Removal cannot race with a task publishing or
recreating the same model directory. Other features remain usable.

After removal, retain the provider choice and show that installation is required. No
status check or subsequent operation silently redownloads the removed files. Report
partial deletion failures honestly and allow retry; do not claim space was reclaimed
when deletion failed.

Keep model payloads under EchoType's managed storage. Inventory unavoidable external
links and derived files, and give them an explicit ownership rule. Never overwrite or
delete another tool's real cache directory to force it into EchoType's store.

Document how to remove downloaded models before uninstalling, and the locations to clean
if the app has already been removed. Dragging the app to Trash does not execute cleanup.
A full account/settings reset or an uninstall helper is outside this pass.

When a later app version requires new model revisions, show the changed download
requirements and require an explicit download. Old revisions remain identifiable and
removable. Automatic replacement and deletion are outside scope.

## Implementation boundaries and deletion pass

Keep provider-specific inference behind the existing service contracts. Resolve the two
provider choices at operation creation and pass the selected provider directly. Two
feature choices do not require a generic router or a composite provider.

Retain the verified model store and the preparation code needed by the chosen models.
Add lifecycle control where installation, cancellation, unloading and removal require it.
Use manifests as the source for download requirements rather than duplicating model lists
and sizes in the UI.

Remove losing runtimes, manifests, dependencies, candidate selection code, comparison-only
build options and dedicated tests made obsolete by the chosen set. After required
measurements are recorded, remove EchoTypeBench, its test target, corpus tooling, commands
and unused support. Keep shared helpers only where remaining tests actually consume them.
Rerun deterministic tests and signed-app verification after retirement. Historical experiments remain in git; useful findings remain
in the consolidated decision record and follow-up documents.

Before finishing, review the diff for duplicated state, obsolete facades and machinery
that serves no requirement in this spec. Update the README, uninstall guidance and affected
decision records, including [provider selection](../decisions/0025-provider-adapters.md),
[settings storage](../decisions/0010-settings-storage-and-api-key.md) and settings layout.
Retain the consolidated [decision evidence](../decisions/0026-local-model-stack.md),
[setup/storage/release notes](../local-models.md) and Qwen follow-up. Completed spike
workflow documents, research survey and result diary have been removed from this branch;
the full archive remains at `2f231b9`. Do not restore them as production documentation.

## Acceptance

Use targeted tests for meaningful behaviour, with fake providers and temporary model
stores where appropriate. Run the repository's required checks and validate a signed
release build on the Mac. Record the chosen models and remaining measured limitations.

The pass is complete when:

1. Existing settings migrate without losing unrelated preferences or credentials, and the
   two provider choices persist independently.
2. xAI Dictation with Local Read Aloud works through hotkeys and MCP speech. Reverse the
   arrangement to check that operation wiring is independent of provider identity.
3. Selection, launch, Settings, Test and operations trigger no unapproved local download.
   Installing only Read Aloud downloads and prepares no Dictation models.
4. Explicit setup shows download requirements, verifies assets, then visibly prepares
   the selected features before reporting Ready. Cancellation, retry and interrupted
   installation recovery never publish incomplete models or late cancelled results.
5. Installed features run offline. Missing credentials, missing models and load failures
   affect only the relevant feature and offer a useful recovery action.
6. Provider changes during an operation preserve its captured provider. Switching away
   releases unused local runtimes after work settles while retaining downloaded files.
7. Removal reclaims owned installed, incomplete and generated data without touching other
   tools' files. Active-work protection, shared assets and deletion failures behave as above.
   A removed feature stays uninstalled until the user explicitly downloads it again.
8. Settings uses the selected design in both themes, shows per-feature availability and
   presents each provider's credentials once.
9. The chosen model implementations are the only shipped local candidates. Required bench
   evidence is recorded before its executable and obsolete machinery are removed. Final
   app checks pass after removal; no new automation suite is introduced.

## Confirmed decisions and remaining checks

- Boosted Parakeet, Qwen3-4B cleanup and Kokoro/eSpeak are confirmed. Keep the current
  Parakeet loading implementation; repeated measurements indicate no runtime fix.
- Explicit setup downloads and prepares the requested features. Keep verified files
  after cancellation, unload unused runtimes after provider switches, and protect
  removal during active operations, preparation and downloads.
- The sidebar structure and simplified Local page are chosen. Validate the native
  production UI with Aidan before accepting the Settings workstream.
- Combined-model, offline and signed-app validation remain implementation acceptance
  checks. Existing licence provenance and public-release obligations remain recorded
  in the productionization notes; do not claim they were resolved by the load test.

See the [approved implementation workflow](../productionization/implementation/README.md).
