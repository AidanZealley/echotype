# Apple on-device provider

Status: approved for implementation, 2026-10-02. Aidan amended external-check placement on the same date; remaining checks follow whole-feature review. Builds on the [provider adapters](../decisions/0025-provider-adapters.md). The [feasibility research](../research/apple-on-device-provider.md) holds the spike's measurements and reasoning; this spec owns the requirements.

## Goal and scope

Add Apple as a second provider that runs entirely on the Mac with no key or account: `SpeechTranscriber` for live transcription, `AVSpeechSynthesizer` for read aloud and Foundation Models for cleanup. Selecting Apple makes EchoType free to run and keeps audio and text on the device.

Apple is a feature-complete fallback. Lower transcription, voice and cleanup quality than xAI is acceptable; feature completeness and adapter containment are the shipping gate. xAI remains the default. On a supported Mac with the required assets and Apple Intelligence enabled, Apple supplies all three services and preserves the existing dictation, Test, read aloud, MCP speech, voice/speed selection and keyterm behaviour. When system configuration makes a service unusable, the [readiness](#readiness) behaviour applies.

This spec is also a test of the provider design. Shared changes are limited to:

- the [readiness](#readiness) capability and its wiring,
- the [language picker](#language-picker),
- one registry line in `Providers.swift`,
- tests, any required bundle permission and documentation.

Apple's adapters own model installation and loading, language resolution, audio conversion, transcript assembly, voice fallback, rate mapping, bounded buffering, framework cancellation, cleanup sessions and context limits. Shared code consumes provider-neutral states, events, errors and reason strings. Do not add Apple-specific branches or wording to `SessionMachine`, `Reader`, `Reviser`, `DictationOperation`, settings or UI code.

Any further shared change needs a concrete justification and Aidan's decision before implementation. If Apple cannot supply a service within the contracts without disproportionate complexity or missing behaviour, return the concrete limitation to Aidan rather than silently dropping a feature. Being free does not justify making the rest of the app harder to maintain.

Outside scope: batch transcription, mixing providers, other providers and iOS.

## Readiness

The provider contract only checks credentials. Apple's services can exist and still be unusable on a given Mac, so `Provider` gains one optional member. Approximate shape for `Provider.swift`:

```swift
public struct Provider {
  …
  /// Nil when the services are always usable once the credential is present.
  public var readiness: Readiness?
}

/// Whether this Mac can use the provider's services now, for these settings.
public struct Readiness: Sendable {
  /// What each service can do now. Starts any setup it needs; the provider runs at most one
  /// setup at a time, so calling again is cheap.
  public var check: @Sendable (ReadinessRequest) async -> ServiceReadiness
  /// Yields when an earlier answer may be out of date, such as setup finishing or failing.
  public var changes: @Sendable () -> AsyncStream<Void>
}

public struct ReadinessRequest: Equatable, Sendable {
  /// The app's BCP-47 tag; the provider resolves its own form.
  public var language: String
  public var voice: String
}

public struct ServiceReadiness: Equatable, Sendable {
  public var transcription: ServiceState
  public var voice: ServiceState
  /// Nil when the provider has no cleanup.
  public var cleanup: ServiceState?
}

public enum ServiceState: Equatable, Sendable {
  case ready
  /// Setup or loading is under way, such as "Downloading speech model".
  case waiting(String)
  /// The Mac or its settings rule the service out, such as "Needs Apple Intelligence".
  case unavailable(String)
}
```

The provider writes every reason string. xAI's `readiness` is nil, so its behaviour, feature marks and missing-key handling are unchanged.

Behaviour:

- **Operation start.** Dictation and Test check readiness after the credential and before opening capture. Reading checks it before requesting speech. An operation starts only when the service it needs is `.ready`. Dictation and Test need transcription, and reading and MCP speech need voice. Dictation needs transcription; cleanup is used only when ready at start, otherwise the dictation inserts unrevised text and the pill says "No cleanup".
- **Pill.** `.unavailable` uses the existing red error pill, as "No microphone found" does. `.waiting` uses a new amber or neutral pill phase that shows the reason and fades the same way. A waiting operation does not start. A dictation whose cleanup is not ready does start: its hint row shows "No cleanup" beside the input device, and the reason stays in the Provider tab.
- **Provider tab.** Feature marks still show which services a provider supports, and missing cleanup keeps its grey mark. A supported service that is not ready shows its reason beside the mark.
- **Refresh.** The Provider tab follows readiness while it is open: it checks, and so starts any required setup, on a change of provider, language or voice and on each `changes` yield. Apple's `changes` stream covers System Settings changes, because it observes installed voices and Apple Intelligence availability. The app makes one check at launch to start setup early, including launch with Apple already selected, and keeps no answer from it. Each operation checks at start.
- **Setup.** One installation runs at a time and may complete after switching providers. A failure reports a short reason and the next check retries it, so reselecting Apple or trying again retries. A short waiting reason is enough; numeric progress and a shared download manager are unnecessary.
- **Mid-dictation loss.** If cleanup becomes unusable during a dictation, failed requests preserve the original text through the existing `Reviser`. No other fallback machinery.

This step is complete when readiness is part of the provider contract and these are covered with fake services: blocked dictation, Test and reading for waiting and unavailable states, and Settings refreshing on `changes`. xAI's existing tests must pass unchanged.

## Language picker

Replace the free-text Language field with a picker over the selected provider's languages. Each provider lists its own `Language` values, a display name and a bare BCP-47 tag such as `en` or `fr`, and the first is its default. Both list only English (`en`) for now. A language is added to a provider's list once someone can test it with that provider.

`Settings.language` stays one stored tag, the user's preference. `Settings.language(for:)` resolves it per provider to the entry with the same language subtag, or to the provider's default if there is none. Loading never rewrites the stored tag, so a saved `fr` comes back if a provider later lists French. Requests carry the resolved tag.

Each adapter resolves the tag to its own form. xAI passes it through. Apple resolves it to a supported regional locale per service and reports an unsupported language through readiness.

## Apple provider

Implement `Providers/Apple/` against the contracts:

- **Description.** Id `apple`, name `Apple`, summary "Free. Runs on this Mac." and `Credential.none`.
- **Readiness.** As above. Transcription needs its speech assets installed for the resolved locale. Voice needs a usable voice for the language. Cleanup needs `SystemLanguageModel` to be available and to support the language:
  - unsupported hardware, Apple Intelligence turned off and an unsupported language are `.unavailable`,
  - a model that is still downloading or loading is `.waiting`.

  Querying installation requests has side effects, because it reserves locales. Keep those queries inside `check`'s single-setup path.
- **Language.** A bare tag maps to a deliberate, stable, supported region. Bare `en` maps to `en-GB`, since the framework's own bare-tag matching is unstable. Explicit supported regional tags are preserved.
- **Transcription.**
  - Final segments append to committed text, volatile results replace provisional text, and utterance stays empty. Committed text only grows, and the resolved tail arrives before `.finished`.
  - Nonempty recognised text emits `.speech`. `SpeechDetector` produced nothing in the spike, so don't rely on it. Silence handling stays in `SessionMachine`: a dictation with no speech cancels quietly, and silence after speech pauses and keeps listening, as with xAI.
  - Stopping a session that recognised nothing makes the framework throw `RecogRejected` (Speech error code 1) at finish. Treat that as an empty finish, not an error.
  - `start()` returns promptly. `.ready` waits for the analyser to prepare, within the existing five-second readiness timeout.
  - Feed the app's 16 kHz mono Int16 audio directly; the adapter owns any conversion another SDK requires.
  - Preserve Test's five-second finalisation, quick stop before readiness and joined cancellation.
  - Pass the built-in `EchoType` term and saved keyterms through `AnalysisContext`, with a provisional `keytermLimit` of 100.
- **Voice.**
  - Voices are Zoe Premium (`com.apple.voice.premium.en-US.Zoe`, the default) and Jamie Premium (`com.apple.voice.premium.en-GB.Malcolm`, shown as "Jamie"). Siri voices are not available through this API.
  - If the saved voice is missing or does not suit the language, fall back to an installed voice for the language without overwriting the saved choice. If none exists, report `.unavailable` with guidance to download one in System Settings > Accessibility > Read & Speak. Refresh on the voices-changed notification.
  - Map speed through fixed per-voice rate anchors. The spike measured Zoe's; Jamie needs his own. Confirm the range by ear, keeping 1x. Aidan accepted the implemented `0.8...1.3` range on 2026-10-02; his preferred speed of 1.1x does not change the defaults.
  - The text limit is 60,000 Unicode scalars. Submit one utterance of at most 250 scalars at a time, preferring the last complete sentence within the bound, and start the next only after the previous is consumed.
  - Take the sample rate from the synthesiser's buffers, deliver at most 100 ms per chunk and cancel pending pulls promptly.
- **Cleanup.**
  - Use a fresh `LanguageModelSession` per request with the exact `Reviser` prompt, greedy generation and unchanged framework protections.
  - `Reviser` still owns windows, faithfulness validation and the three-second final budget.
  - Context overflow fails the request, and `Reviser` preserves the text. No truncation or shared chunking.
- **Tests.** Fixture tests for each adapter's translation, using recorded or constructed framework results. Live checks stay opt-in.
- **Permissions.** Determine on the signed build whether Speech needs authorisation or a usage description. If it does, follow the existing microphone pattern: request at operation start, word the denial in the pill and show it in the Settings system rows.

Cleanup quality is tuned through real dictation after implementation rather than specified here. A change to the shared `Reviser` prompt or validation also affects xAI, so it needs Aidan's decision.

This step is complete when Apple appears in the Provider tab and works with no settings or UI change beyond readiness and the language picker.

## Spike code

The spike experiments formerly lived in `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/`. Workstream 6 deleted them after the production adapters and tests covered what was useful. The research document describes their removal, with git history as their source.

## Verification

Aidan runs the required checks on a signed build. The [G2 end checklist](../apple-on-device-provider/implementation/plan.md#g2-end-checklist) owns the stable item numbers, required evidence and current results, including first-use permission behavior.

On 2026-10-02 he reported items 1, 2, 10, 11 and 12 passing and instructed, "Let's move anything unverified right to the end". Remaining items 3, 4, 5, 6, 7, 8, 9 and 13 follow whole-feature review and do not block workstream 6 or review acceptance. This amends the original gate placement. Full external verification remains pending until those checks pass. Automated and unsigned live evidence remains separate from signed-app validation. Any final-review correction affecting a passed item requires a re-check in the end checklist.

## Extensibility report

Finish with a short section in the provider adapters decision record:

- List every change outside `Providers/Apple/` and `Providers.swift`, with its reason.
- Say whether each change belongs in the shared contract, and update the "Adding a provider" steps to match, including readiness and language resolution.

The report is complete when every shared change is accounted for.
