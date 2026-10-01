# 0025 Everything specific to a provider sits behind its adapters

Status: accepted, 2026-10-01 (provider adapters, registry and credentials). Specified in
[provider adapters](../specs/provider-adapters.md).

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
  an unknown one. xAI is the only entry.
- `Settings.provider` stores the selected id. The app reads the selected provider with
  `Providers[settings.provider]` from the settings snapshot each dictation, Test or reading
  takes, and wires that provider's services. Errors are worded with the provider the
  operation ran with.
- Each provider's adapters and description live in `Providers/<Name>/`. Outside that
  folder and the registry, code names no provider. The `XAI` namespace is internal to
  `EchoTypeCore`, so the app can only reach xAI through `Provider.xAI`. Shared HTTP and
  WebSocket helpers are in `Providers/HTTP/`.
- `Credential` is `.none` or `.apiKey(placeholder:)`. A provider with `.none` always counts
  as having its credential; one with `.apiKey` needs its Keychain item, whose account is the
  provider id (see [0010](0010-settings-storage-and-api-key.md)). Dictation and reading
  fail with "Add your <name> API key in EchoType Settings" when it is missing, and the menu
  bar shows "Add your <name> API key in Settings".
- Failures reach the app as `ProviderError` and are worded with the provider's name, as
  [0006](0006-api-key-and-error-surface.md) describes.

## Adding a provider

1. Create `Providers/<Name>/` with its description and one adapter per service. Give it a
   stable id, name, summary and credential requirement. Supply transcription and read
   aloud, with a non-empty voice list whose first voice is the default and a speed range
   that includes 1. Set cleanup to `nil` if the provider has no cleanup service. Follow the
   neutral contracts in `Provider.swift` for events, cancellation and audio delivery.
2. Add it to `Providers.all`.
3. Add fixture tests for its adapters.

Settings, the Provider picker and feature list, Read Aloud voices and speed, Keyterms
limit, dictation and reading wiring, error messages, menu bar status and Keychain pick it
up with no further change. Reading choices use the provider id as their storage key.
Cleanup is always on when its service is present; no capability flags or cleanup toggle
are needed.

## Consequences

- Operation and reading tests drive fake services and a fake credential, so they cover a
  provider without a credential and a missing key without the Keychain. Error wording is
  tested with a provider defined in the test, not a second registered one.
- Reading and saving the key by account is checked on the Mac in the final gate, not
  through a protocol around the Keychain.
