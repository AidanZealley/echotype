# 0025 Everything specific to a provider sits behind its adapters

Status: accepted, 2026-10-01 (provider adapters, registry, credentials and settings).

## Context

EchoType used xAI for transcription, read aloud and cleanup, and xAI's protocols, URLs,
error statuses and wording ran through the session, the reader, the controller and the
Keychain wrapper. Adding a second provider, such as Apple's on-device services, would have
meant editing each of them.

## Decision

- A `Provider` describes one provider: its `id`, `name`, one-line `summary`, `credential`
  and its services. Transcription (`TranscriptionService`) and read aloud
  (`VoiceService`) are required; cleanup (`CleanupService`) is optional, and a provider
  without it inserts uncleaned text. The user picks one provider and it supplies every
  service; services are never split across providers. The contracts, `ProviderError` and
  the description live in `Sources/EchoTypeCore/Providers/Provider.swift`, following
  [0019](0019-native-macos-app-and-core-boundary.md).
- `Providers.all` in `Providers/Providers.swift` lists every provider in Settings order; the
  first is the default. `Providers[id]` gives the provider with that id, or the default for
  an unknown one. It lists xAI, the default, then Apple.
- `Settings.provider` only chooses a provider. The app reads the selected provider with
  `Providers[settings.provider]` from the settings snapshot each dictation, Test or reading
  takes, and hands that `Provider` to the operation, which reads its credential, services
  and readiness from it. Requests are built from the settings and that provider
  (`TranscriptionRequest(settings:provider:credential:)`, `SpeechRequest`,
  `ReadinessRequest`), so nothing below the choice looks the registry up again. Errors are
  worded with the provider the operation ran with.
- Each provider's adapters and description live in `Providers/<Name>/`. Outside that
  folder and the registry, code names no provider. The `XAI` and `Apple` namespaces are
  internal to `EchoTypeCore`, so the app can only reach them through `Provider.xAI` and
  `Provider.apple`. Shared HTTP and WebSocket helpers are in `Providers/HTTP/`.
- `Credential` is `.none` or `.apiKey(placeholder:)`. A provider with `.none` always counts
  as having its credential; one with `.apiKey` needs its Keychain item, whose account is the
  provider id (see [0010](0010-settings-storage-and-api-key.md)). Dictation and reading
  fail with "Add your <name> API key in EchoType Settings" when it is missing, and the menu
  bar shows "Add your <name> API key in Settings".
- Failures reach the app as `ProviderError` and are worded with the provider's name, as
  [0006](0006-api-key-and-error-surface.md) describes.
- `Provider.readiness` defaults to `Readiness.always`. A provider whose services can exist and still be
  unusable on a given Mac supplies a `Readiness`: `check(ReadinessRequest)` answers a
  `ServiceReadiness` with a `ServiceState` per service (`ready`, `waiting(reason)` or
  `unavailable(reason)`, with nil cleanup when the provider has none), and `changes()` yields
  when an earlier answer may be out of date. A provider that leaves the default, such as xAI,
  is always usable once its credential is present. Operations gate on the credential in one
  place, throwing the app-side `MissingCredential`, before they check readiness.

## Service responsibilities

- `SessionMachine` holds audio until the transcriber is ready and awaits each send before
  starting the next. It calls `finish()` at most once after the last send. Finishing before
  readiness is valid when no audio was sent, preserving a quick stop during startup.
  An adapter may emit a final transcript immediately before its finished event so the
  session keeps the resolved tail. Adapters report `ProviderError`; the old `STTError`
  type is removed.
- `Reader` pulls audio from `SpeechStream`, so pausing playback stops consumption and
  bounds adapter read-ahead. Every chunk uses the same sample rate and holds at most
  100 ms of audio. Cancellation interrupts a pending pull; the caller stops pulling
  afterwards and does not rely on later results. See [0018](0018-read-aloud-audio-fetch.md).
- `Reviser` owns the cleanup prompt and faithfulness validation. The operation owns the
  final revision budget, while `CleanupService` makes the provider request. This keeps
  product rules independent of the provider's model and request parameters. See
  [0021](0021-revise-committed-dictation.md) and
  [0024](0024-dictation-operation-lifetime.md).
- An operation starts only when the service it needs is `.ready`: dictation and Test need
  transcription, and reading and MCP speech need the voice. Dictation uses cleanup only when
  it is `.ready` at start; otherwise the dictation inserts unrevised text and the pill says
  "No cleanup". `DictationOperation` checks before opening capture, and `Reader` after the credential
  and before requesting speech. `.waiting` ends the pill in its amber waiting phase and
  `.unavailable` in the red error pill, each showing the provider's reason as is. The
  Provider tab follows the selected provider's readiness while it is open: it checks on a
  change of provider, language or voice and on each `changes` yield, and shows a not-ready
  service's reason beside its mark. Apple's `changes` stream covers System Settings changes,
  because it observes installed voices and Apple Intelligence availability. The app makes one
  check at launch to start setup, and operations check at start.
- The key editor's SwiftUI identity uses the provider id, keeping unsaved key text and
  credential status separate when the selection changes. Storage and validation are
  described in [0010](0010-settings-storage-and-api-key.md).

## Adding a provider

1. Create `Providers/<Name>/` with its description and one adapter per service. Give it a
   stable id, name, summary and credential requirement. Supply transcription and read
   aloud, with a non-empty voice list whose first voice is the default and a speed range
   that includes 1. Set cleanup to `nil` if the provider has no cleanup service. Follow the
   neutral contracts in `Provider.swift` for events, cancellation and audio delivery.
2. List the provider's languages in `languages`, with its default first, and resolve them in
   the adapter. Requests carry the tag `Settings.language(for:)` resolves from the stored
   preference, a bare tag such as `en`; map it to the provider's own form. xAI passes it
   through, and Apple maps a bare tag to a fixed region. Adding a language means adding it to
   that provider's list and checking its adapter resolves it.
3. If the Mac, its settings or a download can rule a service out, supply `readiness`. Its
   `check` returns each service's state without waiting for setup, starts any setup in a
   task the adapter owns so it survives a provider switch, tolerates concurrent calls and
   reports an unsupported language. Its `changes` returns a fresh stream per call and yields
   whenever setup starts, finishes or fails, or the system's state changes. The provider
   writes every reason the app shows. Leave the default, `Readiness.always`, when the
   services are always usable once the credential is present.
4. Add it to `Providers.all`.
5. Add fixture tests for its adapters, and keep checks that call real services opt-in.

Settings, the Provider picker and feature list with readiness reasons, Read Aloud voices
and speed, Keyterms limit, dictation and reading wiring, the waiting and error pills,
error messages, menu bar status and Keychain pick it up with no further change. Reading
choices use the provider id as their storage key. Cleanup is always on when its service is present; no capability flags or cleanup toggle
are needed.

## Consequences

- Operation and reading tests drive a fake provider with fake services and a fake credential, so they cover a
  provider without a credential and a missing key without the Keychain. Error wording is
  tested with a provider defined in the test, not a second registered one.
- Keychain behaviour is checked on the Mac rather than through a protocol around the
  Keychain. The signed build's Mac validation confirmed retained key, voice and speed,
  dictation with cleanup, read aloud, MCP speech, Test transcription, wrong-key rejection
  and recovery, and the Provider tab in both themes on 2026-10-01.

## Extensibility report

Adding Apple, the second provider, tested this design. Its adapters, description and language
regions sit in `Providers/Apple/`, and the registry gained one entry. Everything else the
branch changed is below. Each shared change is provider-neutral and part of the contract
above; none names Apple.

| Change | Reason | Shared contract |
|---|---|---|
| `Provider.swift`: `Provider.readiness`, `Readiness`, `ReadinessRequest`, `ServiceReadiness`, `ServiceState` | Apple's services can exist and still be unusable on a Mac. The credential was the only usability check. | Yes. Defaults to `Readiness.always`, so xAI is unchanged. |
| `DictationOperation.swift` and `Reader.swift`: check readiness before capture or speech, and the app-internal `NotReady` error | An operation must not start with a service that is not ready. Dictation checks before the credential, which is read after capture opens, so xAI startup is unchanged. | Yes, the operation side of readiness. |
| `DictationController.swift`: wires each operation's check and makes one check at launch to start setup, ends a blocked operation in the waiting or error pill, words `NotReady` as the provider's reason | Settings shows setup progress while the Provider tab is open, on a change of provider, language or voice and on each `changes` yield. One check at launch starts setup. | Yes. A reader's raw failure is no longer shown before the worded one, which also applies to xAI. |
| `Pill.swift`, `PillView.swift`, `PillDemo.swift`: `Pill.Phase.waiting` and its demo steps | A service still setting up is not an error, so it gets an amber pill. | Yes, generic UI for `.waiting`. |
| `SettingsView.swift`: readiness reasons beside the Provider tab's marks | Shows why a supported service cannot be used yet. | Yes. |
| `Settings.swift` and `SettingsView.swift`: `Provider.languages`, replacing the free-text Language field | Free text cannot be resolved reliably by every provider; each provider lists its languages and its adapter resolves a known bare tag. | Yes. The stored tag is kept and resolved per provider. |
| Tests: readiness in `DictationOperationTests`, `ReadingOperationTests`, `ProviderWordingTests`, `ProviderReadinessTests`; the language list in `SettingsTests` and `SettingsValidationTests`; Apple fixture tests in `Apple*Tests.swift` and opt-in live checks in `Integration/Apple*LiveTests.swift` | Cover the shared changes with fake services, and Apple's adapters with fixtures. Live checks run only with `ECHOTYPE_APPLE_LIVE=1`. | Shared tests cover the contract; Apple tests are the provider's own. |
| `Tests/EchoTypeCoreTests/Integration/AppleProviderSpike/` deleted | The production adapters and their tests replaced the experiments; git history keeps them. | No. |
| `README.md`, this record, [0007](0007-known-gaps.md), the [specification](../specs/apple-on-device-provider.md) and the [research](../research/apple-on-device-provider.md) | Document Apple, readiness and the language list, mark the experiments removed, and record the user-approved external-check placement. | No. |
| `docs/apple-on-device-provider/implementation/01-provider-readiness.md` through `06-register-apple.md`, `plan.md`, `README.md` and `final-review.md` | Record implementation handoffs, reviews, verification and workflow status. | No. Workflow documentation. |

No bundle permission changed. The SDK documents Speech authorisation and its usage
description only for `SFSpeechRecognizer`, and the adapters transcribed under `swift test`
with Speech authorisation `notDetermined` throughout. The existing microphone permission
covers capture. Aidan reported signed-build offline dictation and cleanup passing at G2 item 1.
First-use permission prompt behavior remains pending at item 13 in the
[G2 end checklist](../apple-on-device-provider/implementation/plan.md#g2-end-checklist), after
whole-feature review by his decision. Successful signing and unsigned tests do not establish
that behavior.
