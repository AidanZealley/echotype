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

### S2 Voices

- Can `AVSpeechSynthesizer` use Siri voices through buffer synthesis from a third-party app? Prefer them if they satisfy the stream contract; otherwise choose the best available installed voices. Premium or Enhanced voices sounding worse than xAI is acceptable and does not block the provider.
- What sample rate and sample format does `write(_:toBufferCallback:)` produce, and does it stream fast enough to start playback promptly?
- How does EchoType's speed multiplier map to `AVSpeechUtterance.rate`, and what range sounds usable?
- What happens when a chosen voice isn't downloaded, and how can the app detect that?
- Can synthesis stay bounded when the reader stops pulling during a long paused reading? Verify pause/resume or another bounded approach, delivery in chunks of at most 100 ms, and cancellation that interrupts a pending `next()` and releases synthesis work.
- How do the selected voices interact with `Settings.language`? The default policy is to fall back to an installed voice for that language when a curated voice is missing or incompatible, without overwriting the saved choice. Report unavailable if no suitable voice exists. Confirm this policy is feasible and record the adapter's text limit.

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
