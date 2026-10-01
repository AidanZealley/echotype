# Apple on-device provider

Status: draft, 2026-10-01. Depends on [Provider adapters](provider-adapters.md) being merged. Implementation has not started.

## Goal and scope

Add Apple as a second provider that runs entirely on the Mac with no key or account: `SpeechTranscriber` for live transcription, `AVSpeechSynthesizer` for read aloud and Foundation Models for cleanup. Selecting Apple makes EchoType free to run and keeps audio and text on the device.

This spec is also the test of the provider design. The target is to add the provider with only `Providers/Apple/`, one registry line and the one shared capability described under [Availability](#availability). Record every other change to shared code and the reason for it.

Outside scope: batch transcription, mixing providers, other providers and iOS.

## Step 1: spikes

Answer these questions before writing production code. Run the spikes as opt-in tests under `Tests/EchoTypeCoreTests/Integration/`, next to the existing live xAI tests, so they can remain as live checks. A spike is complete when its questions are answered with measurements on Aidan's Mac and the results are recorded in this spec.

### S1 Live transcription

- With volatile results on, how do `SpeechTranscriber` results map to the transcript shape: committed, utterance and provisional?
- What marks the end of an utterance: finalized results alone, or `SpeechDetector`? What, if anything, arrives during silence? This decides how `.speech` is produced.
- Does it accept the app's 16 kHz Int16 audio, or does the adapter need to convert it?
- How long do the first word and the final result after `finish` take, on the integration recordings used for xAI?
- How accurate is it compared with xAI on the same recordings? Does a keyterm passed as a contextual string in `AnalysisContext` fix a misheard jargon word?
- How is the speech model installed through `AssetInventory`, how long does that take, and how long does the first load take compared with the 5-second readiness timeout?
- Does any permission prompt appear, such as Speech Recognition? Does `Info.plist` or the entitlements file need a change?
- Which `Settings.language` values are supported, and how does a BCP-47 tag map to a supported locale?

### S2 Voices

- Can `AVSpeechSynthesizer` use the Siri voices from a third-party app? If not, which two Premium or Enhanced voices sound best?
- What sample rate and sample format does `write(_:toBufferCallback:)` produce, and does it stream fast enough to start playback promptly?
- How does EchoType's speed multiplier map to `AVSpeechUtterance.rate`, and what range sounds usable?
- What happens when a chosen voice isn't downloaded, and how can the app detect that?

### S3 Cleanup

- Run the existing revision prompt cases through `LanguageModelSession` with the neutral prompt. How often does `Reviser`'s faithfulness validation reject the output?
- How long do live and final revisions take compared with the 3-second final budget?
- Does the largest revision window fit the model's context window?
- Which `SystemLanguageModel` availability states occur, and what should each one tell the user?

### Decision gate

Present the results to Aidan, with a recommendation for each service. Each service either ships, or the spec changes. For example, if cleanup quality is poor, Apple ships without a cleanup service and its check mark is grey.

The gate is complete when Aidan's decision is recorded here.

## Step 2: shared capability

### Availability

Spec 1 only checks credentials. Apple's services can exist and still be unusable on a given Mac, so add the smallest availability check that covers the spike results:

- Each service can report that it is ready, needs setup with a short reason (such as "Downloading speech model"), or is unavailable with a short reason (such as "Needs Apple Intelligence").
- **Provider tab.** A service that isn't ready shows a grey mark and its reason in the feature list.
- **Transcription not ready.** Dictation shows the reason in the error pill and does not start.
- **Read aloud not ready.** Reading shows the reason in the error pill.
- **Cleanup not ready.** Dictation runs without a reviser, using the path spec 1 kept for providers without cleanup.
- xAI reports ready whenever it has its key, so its behaviour doesn't change.

S1 decides how model installation starts. The preference is to start it automatically when Apple is selected and show its progress in the feature list, with no separate download setting.

This step is complete when availability is part of the provider contract and xAI's tests still pass unchanged.

## Step 3: Apple provider

Implement `Providers/Apple/` against the contract, using the spike results:

- Description: id `apple`, name `Apple`, summary "Free. Runs on this Mac.", and `Credential.none`.
- Transcription adapter: translates results into `.ready`, `.transcript`, `.speech` and `.finished`, as S1 found. `.ready` waits for the model to load. The keyterm limit comes from S1.
- Voice adapter: the voices chosen in S2, the speed mapping, and a sample rate taken from the synthesizer's buffers.
- Cleanup adapter: if the gate kept it, `LanguageModelSession` with the neutral prompt.
- Fixture tests for each adapter's translation, using recorded or constructed framework results. Live checks stay opt-in.

This step is complete when Apple appears in the Provider tab with no change to settings or UI code, beyond the availability capability.

## Verification

Run these checks on a signed build on the Mac:

- With Apple selected and the network off, dictation with cleanup, read aloud, MCP `speak` and Test all work.
- Switch xAI → Apple → xAI. Each provider keeps its voice and speed, and xAI works exactly as before.
- Apple Intelligence off, where Aidan can toggle it: Cleanup shows grey with its reason, and dictation inserts uncleaned text.
- Run the first dictation on a Mac without the speech model installed, or after removing it, to check the setup state and the readiness behaviour.
- Check the Provider tab in both themes.

## Extensibility report

Finish with a short section in the provider adapters decision record:

- List every change outside `Providers/Apple/` and `Providers.swift`, with its reason.
- Say whether each change belongs in the shared contract, and update the "Adding a provider" steps to match.

The report is complete when every shared change is accounted for.
