# 0025 Everything specific to a provider sits behind its adapters

Status: accepted, 2026-10-01 (provider adapters, registry, credentials and settings).
Extended 2026-10-03 with readiness and per-provider languages.
Updated 2026-10-12 for optional setup and independent feature selection.

## Context

EchoType used xAI for transcription, read aloud and cleanup, and xAI's protocols, URLs,
error statuses and wording ran through the session, the reader, the controller and the
Keychain wrapper. Adding a second provider, such as Apple's on-device services, would have
meant editing each of them.

## Decision

- A `Provider` describes one provider: its `id`, `name`, one-line `summary`, `credential`
  and its services. Transcription (`TranscriptionService`) and read aloud
  (`VoiceService`) are required; cleanup (`CleanupService`) is optional, and a provider
  without it inserts uncleaned text. The user independently selects Dictation and Read
  Aloud providers. Dictation keeps transcription and cleanup together. The contracts, `ProviderError` and
  the description live in `Sources/EchoTypeCore/Providers/Provider.swift`, following
  [0019](0019-native-macos-app-and-core-boundary.md).
- `Providers.all` in `Providers/Providers.swift` lists every provider in Settings order; the
  first is the default. `Providers[id]` gives the provider with that id, or the default for
  an unknown one. It lists xAI, the default, Apple and Local.
- `Settings.dictationProvider` chooses Dictation and Test; `Settings.readAloudProvider`
  chooses reading and MCP speech. The app resolves each from the operation's settings snapshot, and hands that `Provider` to the operation, which reads its credential, services
  and readiness from it. Requests are built from the settings and that provider
  (`TranscriptionRequest(settings:provider:credential:)`, `SpeechRequest`,
  `ReadinessRequest`), so nothing below the choice looks the registry up again. Errors are
  worded with the provider the operation ran with.
- Each provider's adapters and description live in `Providers/<Name>/`. Outside that
  folder and the registry, operation code consumes the captured `Provider`. Settings
  renders credentials and setup from its capabilities without naming a provider.
  Runtime namespaces stay internal to `EchoTypeCore`. Shared HTTP and WebSocket
  helpers are in `Providers/HTTP/`.
- `Credential` is `.none` or `.apiKey(placeholder:)`. A provider with `.none` always counts
  as having its credential; one with `.apiKey` needs its Keychain item, whose account is the
  provider id (see [0010](0010-settings-storage-and-api-key.md)). Dictation and reading
  fail with "Add your <name> API key in EchoType Settings" when it is missing. The menu
  identifies which selected feature is blocked; the other feature remains usable.
- Failures reach the app as `ProviderError` and are worded with the provider's name, as
  [0006](0006-api-key-and-error-surface.md) describes.
- `Provider.readiness` defaults to `Readiness.always`. A provider whose services can exist and still be
  unusable on a given Mac supplies a `Readiness`: `check(ReadinessRequest)` answers a
  `ServiceReadiness` with a `ServiceState` per service, with nil cleanup when the provider has
  none. A state is a status (`ready`, `waiting` or `unavailable`), the provider's message saying
  what is wrong and how to fix it, or a note for a ready service, and an optional link to where
  the user can fix it, such as a System Settings pane. `changes()` yields
  when an earlier answer may be out of date. A provider that leaves the default, such as xAI,
  is always usable once its credential is present. Operations gate on the credential in one
  place, throwing the app-side `MissingCredential`, before they check readiness.

- `Provider.setup: ProviderSetup?` is an optional installation and storage capability.
  `ProviderFeature`, `RuntimeLease`, `ProviderSetup`, `SetupRequirement` and
  `InstalledFile` live in `Providers/Provider.swift`. Setup describes requirements,
  installation, progress, inventory, removal and available space. `SettingsStore`
  tells each provider with setup which features it serves through `select` at launch
  and when settings change. Settings renders the same controls for any such provider.
- A readiness check may start setup managed by the system, such as Apple's speech
  assets. It never starts a provider's own model download. Local installs only from
  Settings. `Readiness.prepare` prepares an installed feature and returns a
  `RuntimeLease` that keeps it alive through operation teardown. Local's loading and
  installation policy belongs to [0026](0026-local-model-stack.md).

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
  `.unavailable` in the red error pill, each showing the provider's message as is. The
  feature page follows readiness on a change of provider, language or voice and on
  each `changes()` yield. Each service row shows its status and the provider's message,
  with a link when available. Apple's updates cover installed voices and Apple
  Intelligence availability. Readiness watchers restart only when those request inputs
  change, so editing unrelated settings does not restart setup checks.
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
   `check` returns each service's state without waiting for setup, tolerates concurrent
   calls and reports an unsupported language. Any system-managed setup runs in a task
   the adapter owns so it survives a provider switch. Provider-owned downloads require
   explicit Settings setup. Its `changes` returns a fresh stream per call and yields
   whenever setup starts, finishes or fails, or the system's state changes. The provider
   writes every reason the app shows. Leave the default, `Readiness.always`, when the
   services are always usable once the credential is present.
4. Supply `setup` if the provider owns installable files. Supply `readiness.prepare`
   if an operation needs an installed runtime and a lease.
5. Add it to `Providers.all`.
6. Add fixture tests for its adapters, and keep checks that call real services opt-in.

Settings setup and storage controls, the Provider picker and service status rows,
the Language picker, Read Aloud voices, speed and voice status, Keyterms limit,
dictation and reading wiring, the waiting and
error pills, error messages, menu bar status and Keychain pick it up with no further change.
Reading choices use the provider id as their storage key. Cleanup is always on when its
service is present and ready; no capability flags or cleanup toggle are needed.

## Apple

Apple runs every service on the Mac with no key or account: `SpeechTranscriber` for live
transcription, `AVSpeechSynthesizer` for read aloud and Foundation Models for cleanup. It is
a free fallback; lower quality than xAI is acceptable, and xAI stays the default.

- **Language.** Apple lists English only. Bare `en` resolves to `en-GB` in every service,
  since the frameworks' own bare-tag matching varies between processes.
- **Readiness.** Transcription needs the speech model for the locale, which the adapter
  downloads through one installation at a time, started by any check. The voice needs a
  voice for the language. Cleanup needs Apple Intelligence on and supporting the language;
  the system loads its model. Messages say what is wrong and how to fix it, linking Apple
  Intelligence & Siri or Accessibility > Read & Speak.
- **Transcription.** Final segments append to committed text and volatile results replace
  provisional text. Recognised text is the speech evidence, since `SpeechDetector` reported
  nothing. Finishing a session that recognised nothing makes the framework reject the
  recognition, which is an empty finish. Keyterms go through `AnalysisContext`, with a
  provisional cap of 100 saved terms.
- **Voice.** System voice, the default, reads with the system's default voice for the
  language and works on any Mac. Zoe and Jamie are optional premium downloads. A saved voice
  that is missing or does not speak the language falls back to the system voice, with a
  note, and is kept so it returns once installed. Speed maps through rates measured by ear
  for Zoe and Jamie over `0.8...1.3`; other voices use Zoe's. Text goes to the synthesiser
  one utterance of at most 250 scalars at a time, so a paused reading stops synthesis.
- **Cleanup.** Each request gets a fresh `LanguageModelSession` with greedy sampling. Context
  overflow and other failures throw, and `Reviser` keeps the dictated text.
- **Permissions.** No bundle permission changed. `SpeechTranscriber` transcribed under
  `swift test` with Speech authorisation never requested; the existing microphone permission
  covers capture. First-use prompts on a signed install are an open check in
  [0007](0007-known-gaps.md).

## Consequences

- Operation and reading tests drive a fake provider with fake services and a fake credential, so they cover a
  provider without a credential and a missing key without the Keychain. Error wording is
  tested with a provider defined in the test, not a second registered one.
- Keychain behaviour is checked on the Mac rather than through a protocol around the
  Keychain. The signed build's Mac validation confirmed retained key, voice and speed,
  dictation with cleanup, read aloud, MCP speech, Test transcription, wrong-key rejection
  and recovery, and the provider settings in both themes on 2026-10-01.
