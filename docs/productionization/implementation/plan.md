# Local models productionization plan

Status: approved by Aidan on 2026-10-09; implementation and Final review Accepted on 2026-10-11. Public release remains held.

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
| 4 | [Pruning and combined validation](04-pruning-validation.md) | 3 and UI gate | Accepted |
| Final | [Whole-feature review](final-review.md) | 1–4 | Accepted |

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
| Signed-app functional evidence | Stream 4 lead; before acceptance | Accepted, 2026-10-11 | Reviewed unchanged R1 signed candidate; approved native UI unchanged | Physical Local capture and user shortcut commit produced actual TextEdit insertion and idle settlement. Earlier mixed-provider, offline audible speech, physical Escape, preparation and removal evidence is retained. Fresh independent evidence review and closure pass. PID 62901 preserved; paid scope exhausted |
| Public release hold | Stream 4 records; before any future publication | Pending | Parakeet provenance/notice handling and eSpeak combined-program licensing/source obligations | Explicit evidence before public release. May remain pending for a local implementation merge; no publishing is authorized |

## Escalations

None. The public release hold remains in the gate table.

## Resolved S4-FUNCTIONAL-01 history: Signed-app functional evidence

- Resolved on 2026-10-11. Aidan reported retained Ready with no error, then Recording
  during coordinated physical admission. Actual PID 62901 input start/stop logs, active
  disabled Test microphone, the user-operated commit shortcut, fresh dictated text in
  the formerly blank Untitled 2 and subsequent idle controls establish actual Local
  capture and app insertion. No agent paste or synthetic shortcut ran.
- The next Dictation shortcut commits by design. Silence renders Paused while audio
  streams; automatic insertion after silence was never an acceptance requirement.
  The new paragraph's exact fidelity remains unmeasured. The stale 19:00 trace and
  prior manual clipboard recovery are not used to prove this result.
- Earlier independently reviewed evidence closes the remaining mixed-provider, offline
  speech, visible preparation, setup cancellation/retry, captured-provider protection,
  physical Escape, lease settlement and disposable removal checks. Physical Dictation
  plus MCP speech satisfy the required entry paths; successful Local selection-reading
  hotkey playback is not claimed. Fresh evidence review and focused closure have no
  Required finding. This resolves the gate without source correction or repeated build.
- Retain the signed offline PID, user devices, production app, credentials and dictated
  target content. Paid authorization is exhausted. No merge or publication is authorized.
  The records below are historical recovery states, superseded by this resolution.


- Current resume condition, 2026-10-11: preserve offline PID 62901, parent 25015 and
  original 08:46:42 BST start. Both providers are Local, Dictation and Read Aloud Ready.
  Actual General permission API outputs report Granted. Audible offline Local completion,
  captured-provider lease retention and physical Escape with settled lease controls pass.
  Restoration/cancellation evidence closure and fresh insertion diagnosis have no findings.
- Automatic Local insertion remains blocked. Aidan reports the controlled retry stayed
  blank after recording and keeping TextEdit active for 30 seconds; AX/screenshot confirms
  the blank target. Last Dictation still contains the earlier known sentence, with verified
  JSON start/end 19:00:32–19:00:40 UTC, predating controlled retries. Recent actual-PID input
  logs establish no new capture. An unadmitted hotkey or startup before trace creation
  remains possible. Do not infer a transport bug or send another blind recording.
- The immediate missing evidence is the exact first retained waveform-menu status/error.
  The orchestrator asked for that once after reading the existing trace. Startup can
  preserve the old trace and retain an error while returning idle. Current evidence is
  `stream4-local-controlled-insertion-oct11.json`, `stream4-retained-dictation-trace-oct11.json`,
  restoration/cancellation JSON and packet 04's latest review/attribution sections.
  All paid scope is exhausted. No further capture, restart, TCC/device change or speculative
  source fix is justified by the stale trace. Earlier launch gates below are historical.
- Decision needed: report the retained waveform status/error so the lead can distinguish
  admission/startup failure before completing the automatic insertion gate. No relaunch
  or additional paid authorization is needed for that read-only diagnosis.
- Options: read the requested existing status and resume focused diagnosis, or leave the
  required functional gate blocked with current process and evidence preserved.
- Recommendation: use the existing prepared candidate. Preserve actual permission and
  device choices; do not reset TCC, change entitlements, restart or repeat paid speech.
- Candidate: HEAD `868f5ea3e839f3510afa68a9aef3eb7966f100b5` plus reviewed uncommitted
  stream 4 changes. Production `.build/local-productionization/EchoType.app` SHA-256
  `9f7b3e252eb37777892a59a4e3ec6196e05067dc036b650cfbab91fffabbd6ca`.
  Isolated `.build/local-productionization/Stream4ValidationR1.app` SHA-256
  `a5e98f2f68df68fa9585e1068d28a4d88e52719665be4fc2cd0c4a4384c0721b`, bundle id
  `com.aidanzealley.echotype.stream4-validation-offline`. Source/package/test provenance is
  `.build/local-productionization/stream4-candidate.json`.
- Historical launch gate: Aidan quits only the isolated Stream4ValidationR1 app, current
  PID 9478, using its own Quit command or Cmd-Q while that app is active. Preserve the live
  production app and all other windows/processes. In the same Ghostty terminal used for
  PID 2033, run `cd /Users/aidanzealley/code/echotype` then
  `./.build/local-productionization/launch-stream4-r1-network.sh`. This retains guarded
  owned preferences, models, Keychain service and every user-root denial. The isolated
  key is already provisioned. Direct Finder launch fails closed; assistant-shell launch
  reproduces the responsible-app rejection. Retain the offline script for later Local checks.
- Before any capture: inspect General for Microphone Granted, retain the new PID and
  confirm Ghostty attribution with a targeted TCC preflight query. If still Not granted,
  stop and retain evidence without altering access. In Settings > Local, explicitly Prepare
  Dictation and wait for Ready using the restored verified files. This separates preparation
  from later real input. Coordinate the spoken phrase and disposable input target before
  any physical Ctrl+Option+D. Only the one authorized 5–10-second paid Dictation plus its
  normal cleanup remains available. No further paid speech request is authorized.
- Resume procedure after authorization: retain the offline script for Local checks, prepare
  a separate bounded network-enabled launch retaining owned storage and denied user roots
  for xAI checks, copy only verified Dictation model assets back into disposable storage,
  explicitly Prepare in Settings, then test Ctrl+Opt+D/S in a disposable input target.
  Record successful xAI Dictation/Local Read Aloud and reversed Local Dictation/xAI Read
  Aloud, including MCP speech, captured-provider changes and settled playback/cancellation.
  Never treat the current network-denial sandbox as a successful paid-provider test.
- Evidence: independent review complete; S4-R1 corrected and fresh focused closure passes.
  Final tests pass 164 Core/88 App; release packaging completes in 101.72 seconds; both
  signatures and source identity checks pass. Offline setup/cancel/retry, combined
  process footprint and disposable removal evidence are retained in packet 04. R1
  actual app demonstrates visible installed-only speech preparation without stale Ready
  feedback. MCP admission alone does not prove playback completion or cancellation.
- Resume preflight on 2026-10-10: preserved user-relaunched validation PID 2033 while
  Aidan configures it. The current Apple page reports Microphone Granted and Device Control
  and Data Access Granted. Non-prompting isolated-service metadata finds an xAI item without
  returning credential data. Network launch is prepared as
  `.build/local-productionization/launch-stream4-r1-network.sh`; it preserves the owned home,
  guarded namespace and every original user-root denial. No paid call ran. Current 74
  source/package hashes match. Evidence is `stream4-functional-resume-preflight.json`.
  Pending user coordination is completion of configuration and two short spoken phrases,
  one for paid Dictation and one for Local Dictation, in a disposable input target.
  Permission/key presence alone does not close the functional gate.
- Bounded session result on 2026-10-10: owned PID 2033 restarted with the unchanged
  network script as PID 9478. CUA start/stop Ctrl+Opt+D presses eight seconds apart inserted
  two U+0004 control characters into a new disposable TextEdit target, with no capture,
  transcript or paid Dictation admission evidence. The target is cleared. General now
  reports Microphone Not granted, Device Control and Data Access Granted. No TCC change
  occurred. Physical-hotkey diagnosis is pending through the orchestrator.
- Exactly one xAI sentence, `This is a short speech check.`, was admitted through isolated
  MCP with Local Dictation/xAI Read Aloud selected. Re-enabled Test microphone establishes
  controller idle/settlement, not audible success. Aidan's audibility outcome is pending;
  this paid attempt must not be repeated. Paid Dictation remains unused because capture
  was not established. All 36 restored disposable Dictation files and current 74 source
  hashes verify. Evidence is `stream4-functional-restored-assets.json`,
  `stream4-functional-xai-reading.json` and `stream4-functional-bounded-attempt.json`.
  No source/UI change or extra paid request ran. Current PID 9478, blank target and
  Local Dictation/xAI Read Aloud selection are preserved pending user outcomes. Further
  capture/provider changes must wait; final free Local checks use the offline launch.
- User outcomes for that bounded session: Aidan's physical Ctrl+Option+D reached a
  `Starting` state, remained there, and Escape was pressed. Subsequent presses eventually
  showed a Microphone access not granted error. No inserted Dictation result is confirmed.
  Aidan heard no xAI sentence, with earbuds connected to two devices, so audibility is
  unverified rather than a confirmed provider failure. Do not repeat the paid speech attempt.
  Diagnose the isolated launch/permission attribution and starting/cancellation state using
  existing evidence and non-capturing checks before further live capture. Preserve devices,
  TCC, credentials and the approved UI; do not infer a functional pass.
- Latest physical outcome, 2026-10-10: Aidan reports `Ok I manually did a ctrl+opt+D
  dictation into an active text edit and it worked`. Read-only inspection preserves
  Ghostty PID 19185 and confirms xAI Dictation/Local Read Aloud, active hotkeys,
  xAI Ready and enabled Test microphone. Its existing disabling rule proves idle
  settlement. Successful physical insertion is user evidence; no per-operation provider
  trace, exact transcript or cleanup quality was inspected. The existing network log
  is empty. Evidence is `stream4-physical-dictation-result.json`.
- Both bounded paid allowances are now consumed. Do not repeat paid Dictation or
  speech under the earlier authorization. Earlier claims that paid Dictation was unused
  describe incomplete historical evidence and are superseded by this result.
- Remaining functional gates are successful Local Read Aloud through hotkey/MCP,
  reverse Local Dictation/xAI Read Aloud with audible completion, installed offline
  operation, captured-provider switching and settled playback/cancellation with lease
  release. The prior paid reading was unheard; a user decision is required before
  repeating it. Preserve the current Ghostty launch and user apps pending coordination.
  No capture, inference, paid request, focus, source/settings change or restart ran
  during this diagnosis. Stream 4 remains Blocked; functional acceptance is not claimed.
- Unblocks: stream 4 functional acceptance and its scoped commit, then whole-feature review.
  Native Settings approval is already Accepted. Public-release licence/provenance and
  signing/notarization holds remain separate and do not authorize publication.
- Latest continuation decision: after clarification of workflow status and unnecessary
  manual terminal coordination, Aidan says `Ok let's continue`. Use computer use to
  operate a fresh Ghostty shell tab, verify the isolated process and perform the offline
  launch/setup. User input is needed only for coordinated spoken Dictation and audible
  outcome confirmation. No additional paid call is authorized.
- Oct11 continuation: after the absent isolated process was established, Aidan
  reports `done` for running the offline launcher at a Ghostty shell prompt.
  Verify the new isolated process and permission state, then resume free Local checks.
- Oct11 physical Local Dictation outcome: Aidan says `I missed it happening but no
  text is showing in untitled 2`. No successful insertion is established. Inspect
  current app/target read-only before any repeat recording, without inferring
  capture or failure from an empty document alone.
- Last Dictation diagnostic coordination: after initially selecting the wrong menu,
  Aidan confirms `Clicked wrong thing. It's open now`. Inspect the open isolated
  Last Dictation window read-only before any recording retry.
- Coordinated physical Local retry outcome: after explicit NOW instructions using
  `This is a short local dictation test.`, Aidan confirms `Recording started, I
  spoke and stopped it`. Inspect output/trace and settlement before marking success.
- Trace correlation answer: Aidan confirms `Yes, roughly right; TextEdit was active`
  for the rendered transcript `Hello, Tailwind to my computer again, isn't this fun?`
  and clicking Untitled 2 before the shortcut. Transcription matches actual speech;
  blank target despite attempted paste needs diagnosis rather than a focus assumption.
- Local reading outcome: Aidan says `I think it worked but I was changing audio
  device part way. Please try again`. Repeat the same short free Local sentence,
  preserving user-chosen device settings. Audible completion is not yet confirmed.
- Repeat Local reading result: Aidan confirms `Yes, heard the full sentence` for
  `This is a short offline speech check.` Audible offline Local completion is confirmed.
- Escape scenario user outcome: Aidan missed the cancellation prompt, then selected
  text and invoked Read Aloud himself. Screenshot shows NSPOSIXErrorDomain Code 1,
  `Operation not permitted` from a URLSession task. The prior lead retained xAI
  as next Read Aloud after provider-switch testing in the network-denied app.
  This new user request cannot demonstrate Local failure or successful cancellation.
  Restore Local Read Aloud, verify settlement and retain the unverified Escape gate.
- Subsequent coordinated Local cancellation: after `Ready now` and a fresh local
  reading notice, Aidan confirms `Yes, stopped when I pressed Escape`. Verify current
  controller idle and freshly opened storage controls to close cancellation/lease evidence.
- Controlled insertion follow-up: Aidan says `Try again and I'll make sure I stay
  in it`. Re-establish the disposable target and coordinate another physical Local
  check, keeping TextEdit active through processing. Prior controlled attempt is unconfirmed.
- Controlled retry result: Aidan reports `Still blank after 30 seconds` after the
  physical recording instructions and keeping TextEdit active through processing.
  Diagnose this attempt and validation-specific automatic-paste permissions/transport;
  no successful automatic insertion is established and no further blind retry is needed.
- Retained waveform status answer: Aidan reports exact first line `Ready`.
  No retained startup error is observed. Verify live recording admission separately
  from stop/insertion on the next coordinated check, rather than another blind full retry.
- Confirmed live recording outcome: Aidan reported `Recording`, then after the stop
  instructions said `I saw the text appear in the dictaiton box but I had to use the
  shortcut to commit it myself`. The lead observes actual dictated text in Untitled 2
  and controller idle, with no agent paste. Check intended review/commit shortcut
  semantics; do not impose automatic insertion after pause if commit is designed separately.
- Latest manual launch result after computer-use refusal: Aidan reports
  `kill: kill 19185 failed: no such process` and EchoType Settings opened just after.
  The old PID was already absent; verify the new offline process and attribution
  before continuing Local setup and coordinated physical input.
- Native automation blocker, 2026-10-10: fresh shell inspection at 19:32:45 BST
  confirms network PID 19185, parent 19159, unchanged start 18:38:25 and foreground
  process group 19185 on Ghostty `ttys004`. CUA lists running Ghostty, but
  `cua.getApp('com.mitchellh.ghostty')` rejects access with `Computer Use is not
  allowed to use the app 'com.mitchellh.ghostty' for safety reasons.` No native
  terminal action, termination or offline launch occurred. The authorized computer-use
  recovery cannot proceed through this tool. Resolve Ghostty tool access or provide an
  authorized launch route that retains its working responsible-app attribution. The
  recommendation is to resolve the tool restriction. Do not retry user terminal loops,
  launch through T3 Code, bypass the restriction or infer offline operation. Evidence
  is `.build/local-productionization/stream4-native-ghostty-blocker.json`. This blocks
  offline functional validation, stream 4 acceptance and Final; earlier reviews remain
  valid. User answer for this new tool-access blocker is pending.
- Latest user authorization: after being told the unheard xAI reading requires approval
  to repeat, Aidan answered `Ok repeat`. Authorize exactly one additional reading of
  `This is a short speech check.` No additional paid Dictation, long reading or bulk
  comparison is authorized. Continue remaining free Local validation afterward.
- User result for the authorized repeat: Aidan answered `Yes, heard the full sentence`
  when asked whether he heard `This is a short speech check.` Audible xAI playback
  is confirmed. The additional single-sentence allowance is now consumed.
- Offline relaunch coordination: Aidan answered `Yes, I think` when asked whether
  the isolated app was relaunched with the offline script in Ghostty. Lead must
  verify the current process, offline profile and microphone access before capture.
- Aidan subsequently confirms `Yes, it reopened` after the exact Ghostty commands
  stopping isolated PID 19185 and running the offline launcher. Verify the new
  process and permission state, then continue free Local validation.
- User answer: Aidan now reports Microphone Granted after launching the network script
  from Ghostty. Preserve that launch attribution; do not restart from T3 Code.
  Aidan now confirms `Yes, finish setup now` after automation paused for human activity.
  The lead may finish provider selection and focus the disposable TextEdit target while
  preserving the current Ghostty-launched process. Coordinate physical capture afterward.
  Aidan reports microphone permission is probably granted; verify it in the
  isolated app without altering TCC. Aidan authorizes short paid functional checks, not long
  voice-quality comparison readings or spending toward a US$1 target. Bound this session to
  one 5–10-second xAI Dictation and one single-sentence xAI Read Aloud, with required normal
  cleanup requests for that dictation. No long readings, bulk comparisons or repeated paid
  trials. Keep xAI credentials isolated and require user provisioning if absent. Run remaining
  local checks without paid calls. Record results; unresolved access remains a gate.
  Aidan subsequently confirms: `Yes, key entered and app ready`. Configuration is complete
  and the isolated app may be controlled/restarted for the authorized bounded checks.
  Coordinate microphone capture with Aidan before each short dictation so actual spoken input
  is available. Do not ask for the already-provided key or repeat spending approval.


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

- Live Dictation evidence must distinguish admission, physical commit and observed target
  delivery. Silence only pauses presentation; it does not commit. A stale trace cannot
  attribute a retry, and paste attempted is weaker than fresh target delivery. Coordinate
  start and commit separately when admission is uncertain; never infer a transport fix
  from a blank target without an admitted operation.

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

## Stream 4 start and ownership, 2026-10-10

- Base is `868f5ea3e839f3510afa68a9aef3eb7966f100b5`. Accepted streams and final native toolbar contract remain frozen.
- Adopt remaining Parakeet timing, README/main demo dispatch, SettingsDemo removal and authorized 29 spike-document deletions. Own candidate/dependency pruning and assigned productionization/spec documentation. Preserve app-testing.md, qwen-tts-follow-up.md and unrelated test-harness trial text unless explicitly needed by the packet.
- Begin with installed-model/corpus and isolation inventory. Keep the bench until required evidence is recorded. No silent download, production application access, user credentials/cache/preference mutation or user-process termination is authorized.
- Sequential fresh implementation and independent review follow the guide. Signed production-app functional evidence is required before acceptance; a packaging validation host cannot substitute.

- Stream 4 implementation and pre-retirement measurements are complete. Post-retirement 164 Core/87 App tests and signed release pass. Source is frozen for independent review; isolated real-controller UI/MCP validation has established cancellation/retry and live speech removal protection, while required microphone/paid-provider evidence remains pending.

- Stream 4 recovery on 2026-10-10 found a complete durable independent review. S4-R1 is accepted for one bounded correction at the earlier-owner Settings status seam. PID 95594 is absent, so no process was terminated; interrupted long-reading completion remains unproven. The signed functional gate remains required.

- Stream 4 recovery closure passed with no findings after the authorized earlier-owner status
  correction. Ready now derives only from readiness; success messages are not duplicated.
  Final R1 signed actual app confirms Ready to Installed after provider unload without stale
  success text. A fresh MCP replacement settles and releases file-removal protection, but
  Escape/real hotkey and paid mixed-provider completion remain unproven. Owned PID 95327 is
  idle on Local. General shows Microphone Not granted, Device Control/Data Access Granted.
  Stream 4 is Blocked on S4-FUNCTIONAL-01, with no acceptance commit or downstream Final start.


## Stream 4 bounded functional session, 2026-10-10

- Aidan confirmed the isolated key and readiness. The orchestrator coordinated speech
  before the single synthetic capture attempt. No capture was established; the two hotkey
  presses reached TextEdit as control characters. Permission labeling changed after the
  owned network-script restart, without permission mutation. Physical-hotkey diagnosis
  remains pending. The signed candidate and 74 source/package hashes are unchanged.
- One single-sentence xAI MCP reading was admitted and settled. Audible success remains
  pending user evidence and no repeat paid call is allowed. Verified disposable Dictation
  files were restored from read-only originals, without setup or inference overlap.
- Packet 04 records exact limitations and safe current state. Stream 4 remains Blocked on
  S4-FUNCTIONAL-01. Earlier technical review/closure and tests remain valid. No acceptance
  commit or Final review is claimed, and no production/user-root/TCC mutation ran.

- Read-only access diagnosis establishes why permission changed across launches. TCC
  attributed user PID 2033 to Ghostty with microphone authValue 2. It attributes assistant
  PID 9478 to T3 Code Nightly and explicitly rejects that responsible app's missing
  audio-input entitlement, returning authValue 0/authReason 5. Validation app entitlement
  is present. Network/offline profile difference is only network denial, and neither
  executable nor redirected home changed. This is an access gate, not a proven app defect.
- Physical hotkey reaches actual Starting. Source displays Starting before credential,
  preparation and permission stages; Escape cancels presentation immediately while startup
  ownership settles after awaited work. No captured audio or insertion is inferred. No
  paid speech retry is allowed. The existing network log contains no playback evidence.
- User-terminal NETWORK launch steps and non-capturing preflight/explicit Prepare are
  recorded in S4-FUNCTIONAL-01. Preserve current PID 9478 for Aidan to quit. No source fix,
  app control, microphone prompt/capture, paid call, TCC or audio-device change occurred.
  Earlier signed-candidate tests/review remain valid; no unchanged build was repeated.
- Fresh independent diagnosis review verified TCC, entitlements, isolation profile and
  source cancellation sequencing with no Required finding. Durable evidence is
  `.build/local-productionization/stream4-access-diagnosis.json`. This does not clear
  required real-app output or the consumed, unheard paid reading. Stream 4 stays Blocked.
- Fresh focused closure passes after narrowing packet 04's log wording to the retained
  result at 18:29:51. No source finding remains and no unchanged build was required.
  The user-terminal access gate and functional evidence remain required.


## Stream 4 Ghostty launch recovery, 2026-10-10

- Exact user-launched validation PID 19185, parent zsh PID 19159, is preserved. Read-only
  General shows both microphone and Device Control/Data Access Granted. The attribution
  gate is resolved for this process; actual capture and insertion remain required.
- Explicit installed-only Local Dictation Prepare settled to Ready. All 74 source hashes
  match, isolated key metadata is present and native Ctrl+Option+D is confirmed.
- CUA reported human activity during provider selection, so the lead stopped UI actions.
  Owned preferences still show Local Dictation/xAI Read Aloud. No capture or paid request
  ran. Orchestrator coordination is required before target/provider setup resumes.
- Stream 4 remains Blocked on S4-FUNCTIONAL-01. The paid reading remains consumed,
  unheard and unverified. No repeat or functional waiver is inferred.


## Stream 4 physical input handoff, 2026-10-10

- Latest user outcome: Aidan reports the open TextEdit window is empty and did not
  observe the pill closely enough to identify recording, processing or an error.
  This is no successful insertion evidence. The orchestrator explained the expected
  click/start/wait/speak/stop sequence and asked him to hold off on another attempt
  pending read-only diagnosis. No additional paid request is authorized by this report.
- Subsequent user outcome: `Ok I manually did a ctrl+opt+D dictation into an active
  text edit and it worked`. This supplies successful physical Dictation/insertion
  evidence. Lead checks current provider attribution and settlement read-only;
  no repeat paid Dictation is needed or requested.

- Aidan authorized completing setup with `Yes, finish setup now`. Ghostty PID 19185,
  parent zsh PID 19159, start 18:38:25 remains preserved. Owned preferences are now
  xAI Dictation and Local Read Aloud. Installed-only speech Prepare settled Ready
  with Zero KB download. xAI Dictation shows Ready; enabled Test microphone proves
  controller idle without invoking it. No new capture or paid request was initiated.
- TextEdit `Untitled`, blank `First Text View`, is focused for physical Ctrl+Option+D.
  The phrase is `EchoType turns this short sentence into text. I am testing the
  microphone once.` The orchestrator supplied 5–10-second start/speak/stop instructions.
- No user outcome has arrived. Read-only observations show no inserted output. This
  does not prove an attempt occurred or consume the paid Dictation allowance. Preserve
  the ready target and process until Aidan reports the result.
- Stream 4 remains Blocked on S4-FUNCTIONAL-01. Actual input/insertion/settlement,
  the remaining free Local checks and the consumed unheard paid reading remain
  concrete functional gates. No acceptance commit or downstream Final review starts.


## Stream 4 acceptance and Final handoff, 2026-10-11

- Stream 4 is Accepted. Pruning and bench retirement, recorded combined-set evidence,
  unchanged signed candidate checks, S4-R1 remediation, independent technical closure
  and the final signed-app functional evidence are complete. Fresh live-evidence review
  and focused closure have no Required findings. S4-FUNCTIONAL-01 is resolved above.
- Read-only final provenance matches all 74 source/package hashes, two remediation test
  hashes and both signed executable hashes. Existing 164 Core/88 App test and release
  verification remain valid; no source change required another build or inference run.
- Drift: bounded signed validation identity/home isolation was adopted and independently
  reviewed to preserve real credentials/preferences/models. Product architecture, native
  UI and model pins did not change. Public-release obligations remain a separate hold.
- Final may now begin its required whole-feature review against the recorded starting
  commit and main comparison base. Preserve unrelated dirty work, the user's dictated
  TextEdit content and the offline R1 PID. No merging or publication is authorized.


## Final review start, 2026-10-11

- Streams 1–4 are Accepted at HEAD `1d4deecbb217dd1e8fd71d99ddffeb18a1937c76`. Fresh whole-feature review covers execution base `077a1ec3973cd9629c527e7f9c419c6e4263ee93` and the complete net merge diff from `4669f80f43a9be81008f8e01a4bb854f914b1b68`, including retained spike work.
- Final owns final-review.md and its plan transitions. Existing implementation-brief.md, lead-guide.md and starter-prompt.md remain untracked workflow references; app-testing.md and qwen-tts-follow-up.md retain unrelated ownership. No blanket adoption or commit is authorized.
- Native Settings and resolved physical Dictation/MCP functional evidence remain accepted. Preserve offline PID 62901, TextEdit content, other apps and every user storage/permission/device choice. Paid scope is exhausted. Public release holds remain separate.

- Fresh whole-feature review found F-R1, preparation replacing foreign cache symlinks, and F-R2, inaccurate retirement/completion/navigation docs. Both are accepted for one narrow remediation pass. Optional Prose visibility stays deferred. Independent focused closure follows current-revision deterministic tests, release build and signing. Fixtures and a separate Final candidate preserve all real cache/model paths and existing app bundles/processes.

- F-R1/F-R2 remediation passed 8 focused tests, 166 Core/88 App deterministic tests, release build and separate FinalReviewCandidate strict signing. Existing production/R1 candidates remain unchanged. Final source/resource/test hashes and logs are in `.build/local-productionization/final-review-candidate.json`. Fresh focused closure now verifies the accepted fixes, their boundary effects and supplied functional evidence applicability. No app launch or inference was repeated.


## Final acceptance, 2026-10-11

- Fresh whole-feature review audited the complete execution-start diff and net merge diff from recorded main comparison base, including retained spike work. F-R1 foreign-cache link protection and F-R2 retirement/status/navigation documentation were accepted, corrected once and independently closed with no Required findings. Optional Prose visibility remains deferred.
- Final is Accepted. Current correction passed 166 Core/88 App deterministic tests, 8 focused fixture/frontend tests, release build, separate candidate packaging, strict signing and diff checks. Closure independently matched source/resource/test/log inventories and candidate identities. Evidence is `final-review-candidate.json`; final-review.md records applicability of the earlier exact signed-app functional evidence. No new inference or paid call was needed for this preservation-only cache fix.
- Completion status was finalized after closure without code/resource changes. No Final specification drift or unresolved escalation remains. Public-release licensing/provenance and Developer ID/notarization holds remain. No merge, PR or publication ran.
- Final commits only its cache-link source/tests, accepted documentation corrections and Final/plan completion records. Pre-existing untracked lead-guide, implementation-brief, starter-prompt, app-testing and qwen follow-up remain owned by their prior authors. Every existing app/process, user TextEdit paragraph and real storage/preference/permission/device choice remains preserved.

## Post-acceptance documentation resolution

- Aidan subsequently requested `Ok resolve those docs`. This authorizes adding the three
  referenced workflow documents and the two linked follow-up specs in a scoped documentation
  commit. The workflow instructions are archived with completion dates and links to this plan.
  App testing remains a deferred, unapproved draft; Qwen3-TTS remains deferred research.
  Their inclusion does not authorize implementation or reopen accepted productionization work.
- The earlier untracked-file records describe their state at each acceptance handoff.
  This documentation cleanup changes no product code or release holds and authorizes no merge
  or publication.
