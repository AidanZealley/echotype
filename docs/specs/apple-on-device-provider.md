# Apple on-device provider

Status: ready for spikes, 2026-10-01. The [provider adapter implementation](../decisions/0025-provider-adapters.md) is merged. Apple implementation has not started; production work waits for the decision gate below.

## Goal and scope

Add Apple as a second provider that runs entirely on the Mac with no key or account: `SpeechTranscriber` for live transcription, `AVSpeechSynthesizer` for read aloud and Foundation Models for cleanup. Selecting Apple makes EchoType free to run and keeps audio and text on the device.

Apple is a feature-complete fallback. Lower transcription, voice and cleanup quality than xAI is acceptable; feature completeness and adapter containment are the shipping gate. xAI remains the default. On a supported Mac with the required assets and Apple Intelligence enabled, Apple must supply all three services and preserve the existing dictation, Test, read aloud, MCP speech, voice/speed selection and keyterm behavior. When system configuration makes a service unavailable, use the availability behavior below.

This spec is also the test of the provider design. Apple must fit the existing operation contracts, plus the small shared capability described under [Availability](#availability). Production changes should be confined to `Providers/Apple/`, one registry line and the shared wiring for availability.

Apple's adapters own model installation and loading, locale matching, audio conversion, transcript assembly, voice fallback, rate mapping, bounded buffering, framework cancellation, cleanup sessions and context limits. Shared code consumes provider-neutral states, events and errors. Do not add Apple-specific branches to `SessionMachine`, `Reader`, `Reviser`, settings or UI code.

Any further shared change needs a concrete justification at the decision gate before implementation. If Apple cannot supply all three services and meet the operation contracts without disproportionate complexity or missing behavior, return the concrete limitation to Aidan rather than silently dropping a feature. Being free does not justify making the rest of the app harder to maintain. Tests, required bundle permissions and documentation changes are expected outside the adapter folder and must be recorded in the extensibility report.

Outside scope: batch transcription, mixing providers, other providers and iOS.

## Step 1: spikes

Execution packets are in the [spike workflow](apple-on-device-provider/spike/README.md). That workflow covers only this step and its decision gate; production implementation requires a separate workflow after the findings are recorded.

Answer these questions before writing production code. Run the spikes as opt-in tests under `Tests/EchoTypeCoreTests/Integration/`, next to the existing live xAI tests, so they can remain as live checks. A spike is complete when its questions are answered with measurements on Aidan's Mac and the results are recorded in this spec.

The implementation defaults below are provisional. Revisit them at the decision gate using the spike results, rather than building shared machinery to accommodate unproven requirements.

### S1 Live transcription

- With volatile results on, how do `SpeechTranscriber` results map to the transcript shape: committed, utterance and provisional?
- What marks the end of an utterance: finalized results alone, or `SpeechDetector`? What, if anything, arrives during silence? This decides how `.speech` is produced.
- Does it accept the app's 16 kHz Int16 audio, or does the adapter need to convert it?
- How long do the first word and the final result after `finish` take, on the integration recordings used for xAI?
- How accurate is it compared with xAI on the same recordings? Does a keyterm passed as a contextual string in `AnalysisContext` fix a misheard jargon word? Verify that built-in and saved terms can reach the framework and determine its usable limit; perfect recognition of every term is not required.
- How is the speech model installed through `AssetInventory`, how long does that take, and how long does the first load take compared with the 5-second readiness timeout?
- Separate asset download from cold loading of an installed model. Can the adapter return from `start()` promptly and load before `.ready`, within the existing readiness timeout? Loading must not escape that timeout by blocking inside `start()`.
- Does cancellation during loading promptly release adapter work? Check immediate stop before readiness, silence-only input, repeated close and preservation of the final tail after `finish()`.
- Does any permission prompt appear, such as Speech Recognition? Does `Info.plist` or the entitlements file need a change?
- Which `Settings.language` values are supported, and how does a BCP-47 tag map to a supported locale?
- How does the adapter distinguish unsupported hardware, unsupported language and missing assets? For the default `en`, record which regional locale is selected. The default policy is an equivalent supported locale where possible, otherwise a clear unavailable reason.

### S1 results

Measured on 2026-10-01 with the accepted [S1 experiment](apple-on-device-provider/spike/01-transcription.md#implementation-handoff). S1 accepted after independent review and fresh closure, under the named limitations accepted by Aidan. MacBookPro18,3, Apple M1 Pro, 16 GB RAM, arm64, macOS 27.2 build 26B5091g, Swift 6.4 and macOS SDK 27.0. The model reports Apple Intelligence available. Initial synthetic evidence used 16.568 seconds of `say` speech with two added three-second pauses. Recovery used Aidan's supplied 27.993-second human PCM16 WAV at 44.1 kHz stereo, converted with the existing helper, plus a fresh 34.993-second pause variant and five-second prefix. All recordings streamed as 100 ms chunks in real time. Audio and logs remain outside the repo; provenance is in the handoff. No xAI credential is available.

| Question | Observed evidence and proposed choice |
|---|---|
| Transcript mapping | Volatile results rewrite the current segment and sometimes contain partial words. Final results append segments, including their leading whitespace. The test adapter maps final segments to committed, keeps utterance empty and maps volatile text to provisional. SessionMachine's committed-prefix checks passed. Final segment ranges differ from preceding volatile ranges; treating every result as a new segment would duplicate text. |
| Utterances and speech | Finalization occurred at sentence boundaries while more audio was coming. It does not alone establish an utterance boundary. The final spoken sentence remained provisional through three seconds of trailing silence and resolved only after finish. Paired SpeechDetector emitted no results in these runs. Recognition text supplies speech evidence and avoids the observed ten-second no-speech cancellation. With a two-second test silence timeout, SessionMachine paused and resumed across the recorded gap. Human pause checks also produced two paused snapshots per run and returned to listening. True acoustic onset and room silence remain unmeasured. |
| Input | The advertised formats were 8 kHz and 16 kHz mono Int16. The app's 16 kHz Int16 was accepted directly in AVAudioPCMBuffer, with explicit buffer timestamps. No Apple resampler was needed on this SDK. Other OS/SDK behavior is unmeasured. |
| Latency and tail | First word arrived about 1.06 s after adapter launch. On the final synthetic run, final tail arrived 65 to 71 ms after finish and stop-to-outcome took 109 to 117 ms. SessionMachine inserted the complete tail in both context variants. Human original first word was 1.960 to 1.987 s, final tail 60 to 73 ms and stop-to-outcome 144 to 151 ms. With fresh pauses, first word was 1.974 to 1.997 s, tail 73 to 75 ms and stop-to-outcome 152 to 154 ms. These are Apple-only checks; the earlier xAI fixture was not recovered. |
| Accuracy and keyterms | Plain words and the final sentence survived. Both context variants rendered EchoType as two words, Zustand as "zust and", and TanStack as two words. The terms did not fix those synthetic pronunciations. TranscriptionRequest supplied built-in EchoType followed by saved terms to AnalysisContext, and framework readback confirmed them. Lists of 1, 100 and 1000 strings were accepted and read back; this does not establish their recognition effect or the usable maximum. The four full human runs returned identical normalized 43-word content, with punctuation differences; context did not change words. The supplied sample has no saved jargon and no independent reference transcript, so it establishes neither jargon improvement nor a word-error rate. Keep a provisional cap of 100 until human jargon evidence supports another choice. |
| Assets and setup | Initially English locales were installed. `status` reported supported even when the English installation request was nil; query results changed to installed after setup queries. A missing fr-FR request existed. Its download completed in 8.995 s despite task cancellation at 100 ms, with 8.891 s cancellation-to-join. A later request was nil. Querying requests also left en_GB/fr_FR reserved; French regional locales remain installed. Check availability without repeatedly requesting setup. No failed download or retry was observed. |
| Installed-model readiness | Start returned in 0.09 to 2.18 ms while a worker prepared the analyzer before ready. Preparation took 82 to 125 ms on the first load in a fresh test process and 37 to 51 ms subsequently, within the five-second readiness timeout. System caches may already be warm; genuinely cold loading is unproven. The nine-second download must happen in setup before starting capture. |
| Lifecycle | Immediate finish requested around 13 ms before readiness resolved to empty completion. Loading cancellation requested after 10 ms joined by 38 to 39 ms from launch. Repeated close joined normally. Five-second human prefixes preserved final text, with tail 90 to 92 ms and stop-to-outcome 97 to 99 ms. Active cancellation after five seconds joined in 1.77 ms with no insertion. Three seconds of zero PCM produced no text and Speech error Code 1 RecogRejected at finish. The candidate exposes that failure; a future empty-silence policy must validate real-room silence rather than broadly swallowing Code 1. |
| Permissions | File input completed without a prompt or authorization request; Speech authorization remained notDetermined. SwiftPM needed no signed host. The production bundle currently has microphone usage text and audio-input entitlement, with no speech usage text. These experiments do not establish microphone or signed-app permissions, so no bundle change is proposed yet. |
| Language and availability | 45 regional locales were advertised. Exact en-GB/en-US matched their regions; de matched de_DE, ja matched ja_JP, zh-Hant matched zh_TW and xx-ZZ was unsupported. Bare en varied between en_GB, en_SG and en_US across processes; bare fr varied between fr_CA/fr_CH. Settings accepts arbitrary BCP-47 strings, so expose equivalent supported matching and an unsupported-language reason, with a deliberate stable regional policy for bare tags. Unsupported hardware was not present; isAvailable was true. Installed lists, status and request existence differ, so status alone cannot decide whether setup is needed. |

The real SessionMachine required no shared change for the measured path. DictationOperation starts capture before opening the adapter, so start must return promptly and emit ready after preparation. Its Test path commits after five seconds and bypasses insertion and cleanup; the human five-second prefix now resolves final text through this contract, while signed Test wiring remains for production verification. The provisional background setup policy fits the observed non-cancelling download. Retry after a failed download, genuine cold loading, real-room silence, human keyterm accuracy, the recognition limit and unavailable-hardware behavior remain unproven. Aidan accepted the named environment limitations on 2026-10-01 provided later validation accounts for them, without waiving human evidence. The handoff records concrete follow-up for every limitation, including signed microphone/Test, room tone and human jargon/reference checks. Missing same-recording xAI comparison and unobserved states remain explicit; none is presented as measured feature-complete support.

### S2 Voices

- Can `AVSpeechSynthesizer` use Siri voices through buffer synthesis from a third-party app? Prefer them if they satisfy the stream contract; otherwise choose the best available installed voices. Premium or Enhanced voices sounding worse than xAI is acceptable and does not block the provider.
- What sample rate and sample format does `write(_:toBufferCallback:)` produce, and does it stream fast enough to start playback promptly?
- How does EchoType's speed multiplier map to `AVSpeechUtterance.rate`, and what range sounds usable?
- What happens when a chosen voice isn't downloaded, and how can the app detect that?
- Can synthesis stay bounded when the reader stops pulling during a long paused reading? Verify pause/resume or another bounded approach, delivery in chunks of at most 100 ms, and cancellation that interrupts a pending `next()` and releases synthesis work.
- How do the selected voices interact with `Settings.language`? The default policy is to fall back to an installed voice for that language when a curated voice is missing or incompatible, without overwriting the saved choice. Report unavailable if no suitable voice exists. Confirm this policy is feasible and record the adapter's text limit.

### S2 results

Measured silently on 2026-10-02 with the [S2 experiment](apple-on-device-provider/spike/02-voice.md#implementation-handoff). MacBookPro18,3, Apple M1 Pro, 16 GB RAM, arm64, macOS 27.2 build 26B5091g, Swift 6.4, SDK 27.0. Apple Intelligence reports available. Six live checks passed in 41.378 s; all six ordinary checks skip before service initialization. No production code, host, permission prompt, agent playback, network change or asset/settings change was used. Raw logs and synthetic WAVs remain outside the repo. The Mac gate, independent review and fresh closure passed. S2 is accepted after one documentation remediation. Latest recovery reran all six live checks in 40.850 s and all six ordinary checks skipped before service initialization.

| Question | Observed evidence and proposed choice |
|---|---|
| Siri and alternatives | Inventory has 182 voices after Aidan installed Zoe Premium, up from 181. Siri remains absent and its historical identifier returns nil. [Apple's WWDC20 explanation](https://developer.apple.com/videos/play/wwdc2020/10022/) states Siri voices are unavailable through this API. Installed candidates are Daniel Enhanced, `com.apple.voice.enhanced.en-GB.Daniel`; Samantha Compact, `com.apple.voice.compact.en-US.Samantha`; and Zoe Premium, `com.apple.voice.premium.en-US.Zoe`. All synthesize. Aidan prefers continuous speech, found the earlier 1x sample better and judges xAI far superior, while valuing a free local option. Aidan chose Zoe as the provisional Apple default. Lower quality does not block feasibility. |
| Format and latency | All three candidates emit mono noninterleaved Float32 at 22,050 Hz, with callbacks at most 256 frames, about 11.6 ms. The test helper copies Float32, averages channels, checks a constant sample rate and delivers at most 100 ms per pull. Every delivered sample was finite and within -1...1. Paragraph first-buffer continuous/sentence-aware times were Daniel 247/275 ms, Samantha 548/530 ms and Zoe 717/731 ms. Earlier French/Traditional Chinese checks used the same format. Other PCM formats and actual stereo conversion remain unobserved. The observed format fits Reader without a shared change; Aidan asked the agent to choose a compatible format. |
| Speed slider | Exploratory duration mapping over 0.7...1.5 uses fixed voice-specific rate anchors, recorded in the handoff. At requested .7/.85/.925/1/1.1/1.25/1.4/1.5, measured short-sentence speeds stay within about 2.2% of target. Daniel's actual endpoints were .703/1.493, Samantha's .715/1.503 and Zoe's .702/1.490. A separate paragraph gives .700/1.503, .715/1.505 and .700/1.498. Samantha's slow-rate plateaus prevent exact continuous duration matching. No runtime calibration system is proposed. Silent duration evidence demonstrates rate control, not a usable 0.7...1.5 range. Aidan rejected the offered 0.7x and 1.5x samples and accepted 1x for the spike. He will tune the future slider during implementation; no 1.1x sample is required. |
| Missing voices and setup | Before Aidan's download Zoe lookup returned nil; afterwards it resolves and synthesizes. Invalid ids still return nil. Enumeration/lookup therefore support unavailable-id detection and installed same-language fallback without replacing saved ids. Public SDK declarations provide lookup, inventory and voices-change notification, without a system-voice download/progress API. Future setup is user-managed [Read & Speak settings](https://support.apple.com/guide/mac-help/change-the-voice-your-mac-uses-to-speak-text-mchlp2290/mac), guidance and inventory refresh. Download failure, interrupted downloads and removal during synthesis were not induced. Aidan's earlier five-test pass in response to the network-disconnected command is reported offline evidence, not agent-observed networking. |
| Bounded synthesis and lifecycle | One utterance of at most 250 Unicode scalars is submitted; another starts only after delegate completion and PCM consumption. Sentence endings are preferred. The 1,260-scalar reading paused after its first pull submitted only 210 scalars. At two/four seconds it stayed at 1,103 callbacks and 282,060 frames. Peak unread payload was 1,127,424 bytes; peak retained PCM payload 1,128,240 bytes. Resume delivered all 1,692,360 generated frames across six utterances, with every scalar submitted. A confirmed pending pull threw on repeated cancellation in .116 ms; synthesis stopped, no accepted callbacks followed over 200 ms, and another reading completed. Process RSS was 75,392 KiB before pulling, 75,440/75,456 KiB at two/four seconds paused and 75,488 KiB after drain. This short warmed-process observation excludes separate synthesis services and does not establish isolated framework-service memory. |
| Language and text limit | Saved Daniel remains for compatible en/en-US. French and zh-Hant fallbacks synthesize with Thomas and Meijia without changing saved Daniel. Missing-id fallback now chooses Zoe for bare en/en-US; xx-ZZ is unavailable. Propose a 60,000-scalar service cap, with bounded internal utterances. Its first pull works; full drain is unmeasured and Aidan explicitly deferred it. Wider locale calibration is also deferred. Sentences longer than 250 scalars still require a word/hard split, whose prosody is unmeasured. |

Aidan identified missing latter-half content in older continuous exports. The original helper treated an intermediate empty PCM callback as EOF, and cancellation discarded the tail. Delegate `didFinish` now marks completion after queued PCM callbacks. Generated and pulled counts match, all scalars are submitted and comparison EOF has no late tail. Empty callbacks remain diagnostic only. The writer correctly wrote all delivered PCM.

Aidan then rejected the former mid-sentence break after "We are comparing the". Sentence-aware segmentation now splits the same 448-scalar paragraph into 224 + 224 after "the next words should still make sense." The rejected break is gone. All three continuous/sentence-aware WAV pairs are byte-identical, independently checked with `cmp` and PCM hashes. Daniel's pair has 566,698 frames, 25.701 s; Samantha's 544,745, 24.705 s; Zoe's 529,736, 24.024 s. This is identical audio for that paragraph, not a guarantee of other text or a word transcript. Slow/fast paragraph exports are continuous to isolate the speed judgment.

Reader accepts the measured rate and chunk shape, and SpeechPlayer queues at most half a second. MCP enters SpeechAdmission, DictationController and the same Reader. Eight existing delivery/admission checks passed in 0.012 s using fake dependencies, including replacement during startup/pause. They are compatibility evidence, not Apple MCP integration. Actual Apple wiring would require production changes and was skipped under Aidan's instruction to attempt it only if easy. Aidan does not require signed Reader evidence or formal xAI comparison, and will explore full reading lengths in later use. No shared/bundle change emerged from SwiftPM; actual production wiring remains unimplemented.

The [S2 Mac gate](apple-on-device-provider/spike/02-voice.md#external-validation) passed on measured missing-id/post-install inventory, language fallback, bounded paused PCM, complete drain, pending cancellation/restart and byte-identical continuous/sentence-aware paragraph audio, together with Aidan's Zoe/1x choice and reported offline execution. These satisfy the spike criteria; they do not establish general prosody or signed-app integration. Oversized-sentence split prosody, failed/interrupted voice downloads, removal during synthesis and isolated synthesis-service memory remain explicit evidence bounds, without a waiver or claim of support. Before production claims, listen to oversized-sentence splits, verify inventory refresh/fallback and recovery around failed/interrupted downloads and voice removal in an authorized setup, and observe synthesis-service memory during a longer paused/drained/cancelled reading. Independent review and fresh closure accepted this distinction.

### S3 Cleanup

- Run the existing revision prompt cases through `LanguageModelSession` with the neutral prompt. Measure intended corrections, unwanted deletions, unchanged output and faithfulness rejections. The current validator permits deletions, so passing validation alone does not establish quality.
- How long do live and final revisions take compared with the 3-second final budget?
- How promptly does cancellation end a live or final request? `Reviser.finish()` cancels and awaits live work before starting its final budget, so check total stop-to-insertion latency too.
- Test long passages without sentence punctuation and accumulated input after slow revisions. Revision windows have no fixed upper bound today. Account for instructions, input and output in the model's context budget. The default is a fresh `LanguageModelSession` per revision; if input does not fit or generation fails, let the existing reviser preserve the original text. Do not truncate dictated text or add shared chunking machinery.
- Which `SystemLanguageModel` availability states occur, and what should each one tell the user?

### Decision gate

Present the results to Aidan with a feasibility recommendation for each service. Report quality measurements as tradeoffs, not a requirement to match xAI. Cleanup must perform real revision when available; an adapter that always returns unchanged text does not establish feature completeness. Individual failed, oversized or unfaithful revisions may preserve the original text through the existing reviser.

Record a feature-feasibility matrix covering all three services, built-in and saved keyterms, language/voice resolution, speed selection, streaming pause/resume, startup/finish/cancellation and availability/setup. Map each to measured evidence and the existing contract; distinguish measured compatibility from app wiring that awaits production implementation. Dictation, Test and MCP use the same service contracts, so investigate any caller-specific assumptions without adding production wiring during the spike.

If a required feature is impossible or needs a shared change beyond availability, present the limitation and options to Aidan. Do not weaken the contracts or make cleanup optional for quality reasons. Confirm the provisional setup, locale and voice policies here before production work, and record whether all three services are feasible within the containment boundary.

The gate is complete when Aidan's decision is recorded here.

## Step 2: shared capability

### Availability

The current provider contract only checks credentials. Apple's services can exist and still be unusable on a given Mac, so add the smallest availability check that covers the spike results:

- Each service can report that it is ready, needs setup with a short reason (such as "Downloading speech model"), or is unavailable with a short reason (such as "Needs Apple Intelligence").
- **Provider tab.** Feature marks continue to indicate which services the provider supports. Readiness is separate: show a short reason beside a supported service that needs setup or is unavailable. Missing cleanup keeps its grey mark.
- **Transcription not ready.** Dictation shows the reason in the error pill and does not start.
- **Read aloud not ready.** Reading shows the reason in the error pill.
- **Cleanup not ready.** Dictation runs without a reviser, using the existing path for providers without cleanup.
- Credentials remain a separate prerequisite. xAI needs no additional setup check; its feature marks and existing missing-key behavior stay unchanged.

S1 decides how model installation starts. The preference is to start it automatically when Apple is selected, including launch with Apple already selected. A short "Downloading speech model" state is sufficient; numeric progress and a shared download manager are unnecessary.

Check availability for the selected language and voice on selection, app launch, relevant settings changes and operation start. Refresh the feature list when setup completes or fails and when the app becomes active after system settings change. The Apple adapter owns setup and reports state through the shared contract; checks themselves should not repeatedly initiate downloads.

Provisional setup policy: one installation runs at a time, may complete after switching providers and reports a short failure reason if it fails. Retry on reselecting Apple or on the next operation attempt; that attempt reports setup status without starting capture. Confirm installation cancellation and retry behavior in S1. Recheck availability at operation start; if cleanup becomes unavailable during a dictation, failed requests preserve the original text through the existing reviser.

This step is complete when availability is part of the provider contract, focused tests cover blocked transcription and reading, cleanup fallback and setup-state refresh, and xAI's existing tests pass unchanged. Use fake services for shared behavior tests.

## Step 3: Apple provider

Implement `Providers/Apple/` against the contract, using the spike results:

- Description: id `apple`, name `Apple`, summary "Free. Runs on this Mac.", and `Credential.none`.
- Transcription adapter: translates results into `.ready`, `.transcript`, `.speech` and `.finished`, as S1 found. `.ready` waits for the model to load. The keyterm limit comes from S1.
- Voice adapter: the voices chosen in S2, the speed mapping, and a sample rate taken from the synthesizer's buffers.
- Cleanup adapter: `LanguageModelSession` with the neutral prompt and the existing faithfulness validation.
- Fixture tests for each adapter's translation, using recorded or constructed framework results. Live checks stay opt-in.

This step is complete when Apple appears in the Provider tab with no change to settings or UI code, beyond the availability capability.

## Verification

Run these checks on a signed build on the Mac:

- After required assets are installed and Apple Intelligence is available, with Apple selected and the network off, dictation with cleanup, read aloud, MCP `speak` and Test all work.
- Switch xAI → Apple → xAI. Each provider keeps its voice and speed, and xAI works exactly as before.
- With Apple Intelligence off where Aidan can toggle it: Cleanup retains its support mark, shows its unavailable reason, and dictation inserts uncleaned text.
- Run the first dictation on a Mac without the speech model installed, or after removing it, to check the setup state and the readiness behaviour.
- Check that setup completion and failure update Settings, launch with Apple selected starts required setup, and a language change rechecks the required assets.
- Pause a long reading and resume it without missing audio or unbounded read-ahead. Cancel while synthesis or model loading is pending and check that the next operation works.
- Check the Provider tab in both themes.

## Extensibility report

Finish with a short section in the provider adapters decision record:

- List every change outside `Providers/Apple/` and `Providers.swift`, with its reason.
- Say whether each change belongs in the shared contract, and update the "Adding a provider" steps to match.

The report is complete when every shared change is accounted for.
