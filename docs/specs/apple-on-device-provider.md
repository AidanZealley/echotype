# Apple on-device provider

Status: measured-feasibility spike accepted, 2026-10-02. Aidan approved completing the investigation and its recorded policies, with further cleanup tuning deferred to feature implementation. The [provider adapter implementation](../decisions/0025-provider-adapters.md) is merged. Apple production implementation and its workflow are not authorized by this decision.

## Goal and scope

Add Apple as a second provider that runs entirely on the Mac with no key or account: `SpeechTranscriber` for live transcription, `AVSpeechSynthesizer` for read aloud and Foundation Models for cleanup. Selecting Apple makes EchoType free to run and keeps audio and text on the device.

Apple is a feature-complete fallback. Lower transcription, voice and cleanup quality than xAI is acceptable; feature completeness and adapter containment are the shipping gate. xAI remains the default. On a supported Mac with the required assets and Apple Intelligence enabled, Apple must supply all three services and preserve the existing dictation, Test, read aloud, MCP speech, voice/speed selection and keyterm behavior. When system configuration makes a service unavailable, use the availability behavior below.

This spec is also the test of the provider design. Apple must fit the existing operation contracts, plus the small shared capability described under [Availability](#availability). Production changes should be confined to `Providers/Apple/`, one registry line and the shared wiring for availability.

Apple's adapters own model installation and loading, locale matching, audio conversion, transcript assembly, voice fallback, rate mapping, bounded buffering, framework cancellation, cleanup sessions and context limits. Shared code consumes provider-neutral states, events and errors. Do not add Apple-specific branches to `SessionMachine`, `Reader`, `Reviser`, settings or UI code.

Any further shared change needs a concrete justification and Aidan's decision before implementation. If Apple cannot supply all three services and meet the operation contracts without disproportionate complexity or missing behavior, return the concrete limitation to Aidan rather than silently dropping a feature. Being free does not justify making the rest of the app harder to maintain. Tests, required bundle permissions and documentation changes are expected outside the adapter folder and must be recorded in the extensibility report.

Outside scope: batch transcription, mixing providers, other providers and iOS.

## Accepted investigation and implementation policies

The measured-feasibility investigation completed on 2026-10-02. All three services fit the existing operation contracts on the supported, configured Mac. Measurements, experiment code, rationale, verification provenance and remaining evidence bounds are in [Apple provider research](../research/apple-on-device-provider.md). This specification owns product requirements; the research document supports them.

Aidan approved completing the spike with these policies and deferred further cleanup investigation and tuning to feature implementation. No production implementation or workflow generation is authorized by that decision. The separate wrong-recipient and meaningful-content deletion failures remain quality risks. Passing faithfulness validation does not establish semantic safety. Excessive-repetition reduction is ambiguous stress evidence, not proof of an ordinary long-dictation failure.

- Transcription appends final segments to committed text, replaces volatile provisional text and leaves utterance empty. Nonempty recognition supplies speech evidence. Preserve monotonic committed prefixes and the final tail. Return promptly from `start()` and prepare before `.ready` within the existing five-second readiness timeout.
- Use the app's 16 kHz mono Int16 input where supported; the Apple adapter owns any required conversion on other supported SDKs. Preserve Test's five-second finalization contract, quick stop and joined cancellation.
- Pass built-in EchoType and saved keyterms to AnalysisContext. Keep a provisional cap of 100 including EchoType pending human jargon and recognition-limit verification.
- Resolve bare language tags to a deliberate stable supported region; bare `en` maps to `en-GB`. Preserve explicit supported regional tags, use equivalent supported matching where possible and reject unsupported required-service language combinations with a clear reason.
- Zoe Premium is the provisional Apple default at 1x. Daniel Enhanced and Samantha Compact are alternatives. Siri is unavailable through this API. Fall back to an installed compatible-language voice without overwriting the saved choice; report unavailable when none exists. Guide users to system Read & Speak settings for downloads and refresh inventory after changes.
- Provide a practical speed slider. The measured .7...1.5 duration mapping is exploration; only 1x received listening acceptance. Tune the slider during implementation. Use the provisional 60,000-Unicode-scalar text limit. Keep synthesis bounded during paused pulls, deliver at most 100 ms per chunk and cancel pending pulls promptly. Prefer complete sentence boundaries within the bounded utterance size, with oversized-sentence prosody checked during implementation.
- Required assets must be installed before capture. Follow the [availability and setup requirements](#availability) for hard gates, pill messaging, installation and retry.
- Cleanup must perform real revision when available. Use a fresh LanguageModelSession per request, the exact neutral Reviser prompt, greedy generation and unchanged framework protections. Reviser owns windows, faithfulness validation and its existing three-second final cancellation budget. Individual failed, oversized or unfaithful requests preserve text through Reviser. Context overflow must fail safely without truncating dictation or adding shared chunking.

Before shipping, account for the research document's [feature feasibility and remaining verification](../research/apple-on-device-provider.md#feature-feasibility-and-remaining-verification), including signed dictation/Test/Reader/MCP, integrated offline behavior, permissions, cold readiness, model/voice setup failure and refresh, room silence, human keyterm accuracy, multilingual and representative long-dictation cleanup quality. The accepted investigation does not claim those unobserved states were verified.

## Shared capability

### Availability

The current provider contract only checks credentials. Apple's services can exist and still be unusable on a given Mac, so add the smallest availability check that covers the spike results:

- Each service can report that it is ready, needs setup with a short reason such as "Downloading speech model", or is unavailable with a short reason such as "Needs Apple Intelligence".
- Feature marks in the Provider tab continue to indicate which services the provider supports. Readiness is separate: show a short reason beside a supported service that needs setup or is unavailable. Missing cleanup keeps its grey mark.
- When transcription is not ready, dictation shows the reason in the error pill and does not start.
- When read aloud is not ready, reading shows the reason in the error pill.
- When cleanup is not ready, unsupported hardware, disabled Apple Intelligence and missing required models block Apple dictation with a short reason. Loading/downloading/not-ready states use pill messaging. Do not add unavailable-state fallback machinery. Individual request failures still preserve text through the existing Reviser.
- Credentials remain a separate prerequisite. xAI needs no additional setup check; its feature marks and existing missing-key behavior stay unchanged.

Start required model installation automatically when Apple is selected, including launch with Apple already selected. A short "Downloading speech model" state is sufficient; numeric progress and a shared download manager are unnecessary.

Check availability for the selected language and voice on selection, app launch, relevant settings changes and operation start. Refresh the feature list when setup completes or fails and when the app becomes active after system settings change. The Apple adapter owns setup and reports state through the shared contract; checks themselves should not repeatedly initiate downloads.

Setup policy: one installation runs at a time, may complete after switching providers and reports a short failure reason if it fails. Retry on reselecting Apple or on the next operation attempt; that attempt reports setup status without starting capture. Verify failed-install retry during implementation; successful installation does not establish it. Recheck availability at operation start; if cleanup becomes unavailable during a dictation, failed requests preserve the original text through the existing reviser.

This step is complete when availability is part of the provider contract, focused tests cover blocked transcription, reading and cleanup prerequisites plus setup-state refresh, and xAI's existing tests pass unchanged. Use fake services for shared behavior tests.

## Apple provider

Implement `Providers/Apple/` against the contract, using the accepted policies and [supporting research](../research/apple-on-device-provider.md):

- Description: id `apple`, name `Apple`, summary "Free. Runs on this Mac.", and `Credential.none`.
- Transcription adapter: translates results into `.ready`, `.transcript`, `.speech` and `.finished`, according to the accepted transcript mapping. `.ready` waits for the model to load. Use the provisional 100-term cap.
- Voice adapter: the approved voice choices and tuned speed mapping, and a sample rate taken from the synthesizer's buffers.
- Cleanup adapter: `LanguageModelSession` with the neutral prompt and the existing faithfulness validation.
- Fixture tests for each adapter's translation, using recorded or constructed framework results. Live checks stay opt-in.

This step is complete when Apple appears in the Provider tab with no change to settings or UI code, beyond the availability capability.

## Verification

Run these checks on a signed build on the Mac:

- After required assets are installed and Apple Intelligence is available, with Apple selected and the network off, dictation with cleanup, read aloud, MCP `speak` and Test all work.
- Switch xAI → Apple → xAI. Each provider keeps its voice and speed, and xAI works exactly as before.
- With Apple Intelligence off where Aidan can toggle it: Cleanup retains its support mark, shows its unavailable reason, and Apple dictation is blocked. Re-enable it before verifying successful cleanup. Individual failed revisions still preserve original text.
- Run the first dictation on a Mac without the speech model installed, or after removing it, to check the setup state and the readiness behaviour.
- Check that setup completion and failure update Settings, launch with Apple selected starts required setup, and a language change rechecks the required assets.
- Pause a long reading and resume it without missing audio or unbounded read-ahead. Cancel while synthesis or model loading is pending and check that the next operation works.
- Check the Provider tab in both themes.

## Extensibility report

Finish with a short section in the provider adapters decision record:

- List every change outside `Providers/Apple/` and `Providers.swift`, with its reason.
- Say whether each change belongs in the shared contract, and update the "Adding a provider" steps to match.

The report is complete when every shared change is accounted for.
