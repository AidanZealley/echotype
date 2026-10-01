# Provider adapters whole-feature review

Status: Accepted. Whole-feature review, focused closure and G3 passed on 2026-10-01.

## Reviewer task packet

Review the full branch against the plan's starting commit and the [approved specification](../provider-adapters.md). Read the accepted handoffs, but review the combined diff and surrounding code independently.

Audit:

- **Completeness.** Every specification section, including the agreed product changes and documentation.
- **Contracts.** The transcription, read-aloud and cleanup contracts as implemented, against the guarantees in the specification, and whether a second provider could implement them without touching shared code.
- **Dependency direction.** Nothing outside `Providers/XAI/` reaches xAI except through the selected `Provider`. The provider-name search is clean.
- **Behaviour with xAI.** Matches the starting commit apart from the agreed changes. Fixtures stay authoritative.
- **Simplification.** Duplicated state, leftover shims, stale mocks, speculative machinery (batch mode, capability flags, availability) and tests coupled to implementation details.
- **Storage.** Compatibility and migration, including decoding settings written by the starting commit.
- **Documentation.** Decision records and the README agree with the code.

Run the complete deterministic suite and the release build once:

```sh
XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test
swift build -c release --product EchoTypeApp
```

After closure, build the G3 candidate with `./scripts/build-app.sh debug .build/EchoType-workflow.app` and run gate G3 as the README describes. Tell Aidan the candidate migrates stored settings to the new format.

## Initial whole-feature review

- Reviewer: fresh independent agent `/root/final_review/whole_feature_reviewer`. Applied the `unslop` skill to this record.
- Branch, base and reviewed head: `refactor/provider-adapters`, `f55bfad..7183e7a`. Reviewed the combined branch changes and surrounding code, the approved specification, named decision records, README and all five accepted handoffs. The lead's uncommitted plan change is outside this reviewer's ownership.
- Verification run: `git diff --check f55bfad..7183e7a` passed. `rg -ni 'xai|x\.ai' Sources --glob '!**/Providers/XAI/**' --glob '!**/Providers/Providers.swift'` printed nothing. Searches for removed types and settings found no remaining source/test callers; retired storage keys remain only in the decoder comment and compatibility tests. Compared the original transcript and PCM fixtures after namespace, wrapper and whitespace changes; their assertions and inputs are unchanged. The final lead owns the complete deterministic suite and release build, so this review did not duplicate them. No app launch, Keychain access or paid test was performed.
- Acceptance-criteria audit:
  - Completeness: the selected provider supplies every service; cleanup is always used when supplied, omitted for Test and absent-service dictation, and represented by zero requests in Last Dictation when absent. The toggle, trace field and old label are removed. Provider, Read Aloud and Keyterms controls match the specified data and order. The feature list follows the required transcription/voice services and optional cleanup service. UI appearance and real operations remain G3 checks.
  - Contracts: session holds at most 160,000 bytes before ready, enqueues sends before suspension, waits for each before finish and rejects later sends. Its single reschedule handles readiness, silence, pause, hard cap and finishing. Close releases readiness and joins sends and adapter work. The recorded finish-before-ready and final-transcript clarifications preserve the starting behaviour. Voice delivery has one rate, short chunks, pull backpressure and the narrowed cancellation promise; playback derives format and its 500 ms limit from that rate. Cleanup leaves prompt, faithfulness, final budget and fallbacks in Reviser. A second provider can implement these contracts in its own folder without shared-code changes.
  - Dependency direction: Core owns the descriptions, registry, requests and contracts. App composition snapshots the selected Provider for dictation, Test, selection reading and MCP reading; provider-named errors use the operation's snapshot. No xAI name remains outside its folder and registry in Sources. Shared HTTP helpers take status mappings from adapters. The remaining resource-copy exception is R1 below.
  - xAI behaviour: streaming URL, query values, keyterm trimming, speech rule, assembly, finalize/audio.done order, TTS JSON, voices, speed range, scalar cap, PCM conversion and bounded response queue match the starting implementation. The cleanup model, request body, resource limit and live/final timeouts are preserved. Transcript and revision fixtures retain their expected behaviour. The status changes follow the approved ProviderError mapping. Cancellation during asynchronous transcriber startup closes and joins a late result. G1 and G2 are recorded as passed; G3 still checks the integrated candidate.
  - Storage and credentials: fields decode independently; missing or unknown provider ids fall back to the registry default. Absent reading migrates the old voice/speechSpeed fields into xai with the previous speed validation. Present reading does not revive old fields; malformed entries and fields preserve unrelated values. Choices survive provider switches, retired voices and invalid speeds have independent defaults, and encoding omits voice, speechSpeed and cleanUp. Keychain read/update/add/remove all constrain the account to the provider id. Credential.none bypasses real key reads in production composition. ProviderControls identity isolates drafts and async results across providers. Upgrade persistence and real Keychain behaviour remain G3 checks.
  - Simplification: replaced STT/TTS/client/reader-request types and obsolete screenshot are deleted. No batch mode, capability flags, availability layer, compatibility aliases or extra production test machinery were added. Ordered-send state moved once into the session; PCM and provider request state moved once into adapters. Tests cover user outcomes, contracts, migration and queue limits with neutral scripted services.
  - Documentation: README and updated records describe the Provider tab, per-provider choices, always-on cleanup, errors and adding a provider. One current record still describes an intermediate state, R2 below.
- Required findings by owner:
  - R1, workstream 4, provider isolation and credentials: `Resources/Info.plist:20` still says "sends your speech to xAI" in NSMicrophoneUsageDescription. This is the provider-specific permission copy deferred expressly to final review by workstream 4. It sits outside the adapter and the README copy exemption, so adding a provider still requires an app-resource change to keep that prompt accurate. Use provider-neutral microphone copy. The Sources search already passes; this is the remaining resource boundary correction.
  - R2, workstream 3, read-aloud documentation: `docs/decisions/0018-read-aloud-audio-fetch.md:152` says Settings.speechSpeedRange duplicates the xAI range "until reading choices are stored per provider". Workstream 5 completed those choices and deleted that property. The current Provider adapters section therefore contradicts the final code. Describe validation against the selected VoiceService.speedRange and per-provider reading choice, or remove the obsolete transitional sentence. This is required by the final packet's documentation criterion.
- Optional observations:
  - O1, workstream 4: on a future provider change, refreshAPIKeyStatus retains the previous hasAPIKey until the key read returns. App.statusLine already uses the new provider name, so it can briefly show that name with the previous credential state. The generation check prevents late results from replacing newer ones. xAI is the only registered provider, making this unreachable today; resetting the status while refreshing can wait for the second-provider work.
- Questions: none.
- Verdict: changes required for R1 and R2. No runtime correctness defect or additional specification drift found. Full deterministic verification, release build and G3 remain the final lead's acceptance steps.

## Lead triage

- Accepted findings and owners: R1, workstream 4, Resources/Info.plist. The microphone copy must remain accurate for any registered provider. R2, workstream 3, decision 0018. The final record must describe selected-service validation rather than a deleted intermediate property. Each correction has a separate implementation owner.
- Rejected findings and reasons: none.
- Deferred optional observations: O1, transient credential-status refresh during a future provider switch. xAI is the only registered provider, so this has no current user impact; leave it to second-provider work.
- Drift requiring user decision: none. Both accepted corrections complete existing requirements.

## Focused closure

- Reviewed head: `7183e7a` plus the uncommitted R1 and R2 corrections. Fresh reviewer `/root/final_review/closure_reviewer` read the packet, initial review, triage, approved specification, workflow and named source documents. Applied the `unslop` skill. Review stayed focused on the accepted corrections and defects they might introduce.
- Finding outcomes: R1 closed. `NSMicrophoneUsageDescription` now says "EchoType uses the microphone to turn your speech into text." It names no provider and accurately describes dictation. `plutil -lint Resources/Info.plist` passed. R2 closed. Decision 0018 now describes per-provider `Settings.reading`, `Settings.readingChoice(for:)` and validation against the selected `VoiceService.speedRange`. Checked both changed passages against `Settings.Reading.validated(for:)` and the `SpeechRequest` initializer; the documented voice and speed fallbacks match the implementation. The obsolete `Settings.speechSpeedRange` reference is gone.
- Final simplification assessment: Both corrections replace obsolete text directly. They add no production code, aliases, state, abstractions or test machinery. `git diff --check` passed. The provider-name search outside `Providers/XAI/` and the registry returned no source matches; the plist also contains no provider name. No release-blocking defect was introduced. The lead's complete deterministic suite and release build passed; this copy and documentation review did not repeat them. O1 remains deferred.
- Remaining blockers: none. G3 passed after this fresh focused closure, as recorded below.
- Verdict: Focused closure passed. R1 and R2 are resolved with no additional drift. G3 subsequently passed; whole-feature acceptance is complete.

## External validation

- Gate and placement: G3, after focused closure before acceptance
- Status: `Passed`, confirmed by Aidan on 2026-10-01
- Candidate and instructions: `.build/EchoType-workflow.app`, signed debug build on `refactor/provider-adapters`, HEAD `7183e7a` plus R1 microphone copy and R2 decision-record correction. Built with `./scripts/build-app.sh debug .build/EchoType-workflow.app`; strict code-signature verification passed. Executable SHA-256: `cb18c8d9fb1fad1d399e6f6269fe9edd72397eb5c0ab052850daef48db635206`. Agents performed no install or launch. Aidan ran the integrated Mac checks; the lasting evidence from E-G3-1 is recorded below. The candidate shares the installed app's settings and Keychain account and rewrites stored settings in the new per-provider reading format.
- Required evidence and result: Aidan confirms the existing key, voice and speed carried over. Dictation inserts successfully, and Last Dictation shows replacements and cleanup. Selected-text reading works, the MCP spoken update was heard, and Provider Test shows what he said. A wrong key produced exactly "xAI rejected the API key"; restoring the real key recovered operation. The Provider tab looks good in light and dark themes. An additional MCP `speak` call was admitted successfully. No key was recorded or accessed by agents.
- Attempts and lasting decisions: the first integrated G3 candidate passed all checks. E-G3-1 is resolved and removed from the plan; its evidence is preserved here. No correction or additional remediation was needed after the gate.
- Recovery verification: the resuming final lead checked the complete four-file diff against the previous accepted head `7183e7a`. Every changed file belongs to final review. The recorded whole-feature review and fresh focused closure are complete, and the candidate executable still matches the SHA-256 above. No source changed after the passing deterministic suite and release build; only the reviewed plist copy and documentation changed. Repeating those checks would add no acceptance evidence.
- Resume condition: satisfied. Every G3 check passed.

## Completion record

- Final verification: `XAI_API_KEY= ECHOTYPE_FIXTURE_WAV= swift test` passed, reporting 93 core tests and 66 app tests, with both opt-in live tests skipped. `swift build -c release --product EchoTypeApp` passed. These complete checks ran once on `7183e7a`; subsequent changes were plist copy and documentation only. Focused closure checked the corrections, plist lint and provider-name searches. Signed debug candidate build and `codesign --verify --deep --strict --verbose=2 .build/EchoType-workflow.app` passed. CI did not run because the branch was not pushed.
- External validation pending: none. G1 dictation, G2 read aloud and G3 whole feature passed. All workstreams and the complete feature are Accepted.
- Specification drift: none. Earlier declaration clarifications remain in the decision log; final corrections complete the existing requirements.
