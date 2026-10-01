# Provider adapters

Status: approved by Aidan, 2026-10-01. Implementation has not started. The [implementation workflow](provider-adapters-implementation/README.md) executes it.

## Goal and scope

Move everything specific to xAI behind a provider adapter, so that adding a provider means adding one folder of adapters and one registry line. xAI stays the only provider. With xAI selected, dictation, read aloud, MCP `speak`, Test and Last Dictation behave as they do on main, apart from the agreed changes below.

[Apple on-device provider](apple-on-device-provider.md) is the follow-up spec and tests this design by adding a second provider.

Outside scope: any second provider, batch transcription, choosing different providers for different services, availability checks beyond "has its credential", iOS and visual redesign of existing tabs.

## Agreed product changes

- **One provider choice.** The user picks one provider, which supplies transcription, read aloud and cleanup. Services are never split across providers.
- **Cleanup is always on.** Remove the Clean up text toggle. Dictation is cleaned up whenever the selected provider has a cleanup service. A provider without one inserts uncleaned text, the same path a failed revision already takes.
- **Features are derived from the adapters.** The Provider tab lists the selected provider's features with check marks, worked out from which services it has. No provider declares a capability flag.
- **Voice and speed are remembered per provider.** Switching to another provider and back restores the voice and speed last chosen for each one.
- **One Keychain item per provider.** The account is the provider id. Reading the key no longer accepts an item under any account name. Aidan's existing item already uses account `xai`.

## Provider description and registry

The names in this section describe responsibilities. Implementers may adjust declarations, but must keep the responsibilities and dependency direction.

```swift
public struct Provider: Identifiable, Sendable {
  public var id: ProviderID               // stored in Settings, used as the Keychain account
  public var name: String                 // used in Settings and error messages
  public var summary: String              // one line, such as "Paid. Uses your xAI API key."
  public var credential: Credential       // .none or .apiKey(placeholder:)
  public var transcription: TranscriptionService
  public var voice: VoiceService
  public var cleanup: CleanupService?
}
```

- Transcription and read aloud are required. Cleanup is optional because inserting uncleaned text is an existing, tested path. A provider without read aloud needs a spec change; do not add that path speculatively.
- The registry is a Swift file listing every provider in Settings order. The first entry is the default:

  ```swift
  public enum Providers {
    public static let all: [Provider] = [.xAI]
  }
  ```

- Providers live in `EchoTypeCore`, consistent with [0019](../decisions/0019-native-macos-app-and-core-boundary.md):

  ```
  Sources/EchoTypeCore/Providers/
    Provider.swift       // description, service types, ProviderError
    Providers.swift      // registry
    HTTP/                // helpers shared by HTTP providers
    XAI/                 // description and adapters
  ```

- Outside `Providers/<Name>/`, code names no provider. It reads the selected `Provider` and its services. Product copy in the README is exempt.

### Adding a provider

After this spec, a provider is added by:

1. Creating `Providers/<Name>/` with its description and one adapter per service.
2. Adding it to `Providers.all`.
3. Adding fixture tests for its adapters.

Settings, the Provider tab, the Read Aloud and Keyterms tabs, menu bar status, error messages and the Keychain pick it up with no further change.

## Transcription

```swift
public struct TranscriptionService: Sendable {
  public var keytermLimit: Int
  public var start: @Sendable (TranscriptionRequest) async throws -> any LiveTranscriber
}

public struct TranscriptionRequest: Sendable {
  public var language: String
  public var keyterms: [String]   // "EchoType" first, then saved terms, cut to keytermLimit
  public var credential: String?
}

public protocol LiveTranscriber: Sendable {
  var events: AsyncThrowingStream<TranscriptionEvent, any Error> { get }
  func send(audio: Data) async throws
  func finish() async throws
  func close()
  func waitForClose() async
}

public enum TranscriptionEvent: Sendable {
  case ready
  case transcript(Transcript)    // committed, utterance and provisional text
  case speech
  case finished
}
```

### What the session guarantees an adapter

`SessionMachine` takes these responsibilities from `STTClient`, so every adapter can rely on them:

- Audio is 16 kHz mono little-endian Int16 PCM, in the chunks capture produces.
- No `send` happens before `.ready`. The session holds earlier audio, up to the existing 160,000-byte limit; overflow fails the session.
- Each `send` is awaited before the next one starts. `finish()` is called at most once, after the last `send` has returned, and no `send` follows it.
- `close()` may be called at any time and more than once. `waitForClose()` joins adapter work after it.

### What an adapter guarantees the session

- `.ready` arrives once, before any transcript.
- Each `.transcript` carries the complete current transcript, not a change. `committed` only grows at its end, `utterance` may be replaced, and `provisional` is shown dimmed and never inserted. This is the shape `TranscriptAssembler` produces today.
- `.speech` arrives whenever the provider shows evidence that someone is talking. It drives the silence and pause rules.
- `.finished` arrives after `finish()` once the tail is resolved, and then the stream ends.
- Failures throw `ProviderError`. Any other thrown error is treated as a connection failure.

### What stays in the session

The readiness timeout, silence, pause, hard cap and finishing deadline, the outcomes, and the rule that `.finished` or the stream ending before closing began is a failure. All of these are expressed only in terms of the four events above. Keep [0024](../decisions/0024-dictation-operation-lifetime.md)'s single `reschedule()` and its deadlines.

### The xAI adapter

`STTClient`, the event decoding, `TranscriptAssembler`, the streaming URL and the speech rule from [0002](../decisions/0002-speech-signal-from-observed-protocol.md) move into `Providers/XAI/`. The adapter translates:

| xAI | Event |
|---|---|
| `transcript.created` | `.ready` |
| `transcript.partial` | `.transcript` from the assembler, plus `.speech` when the current `isSpeech` rule holds |
| `transcript.done` | `.finished` |
| `finish()` | sends `finalize` then `audio.done` |

The 50-character keyterm cap is the xAI adapter's own rule. Building the shared keyterm list (`EchoType` first, a saved `EchoType` dropped, cut to the limit) stays neutral.

## Read aloud

```swift
public struct VoiceService: Sendable {
  public var voices: [Voice]                  // a short list chosen by hand; the first is the default
  public var speedRange: ClosedRange<Double>  // a multiplier where 1 is normal
  public var maximumCharacters: Int           // counted in Unicode scalars
  public var speak: @Sendable (SpeechRequest) -> any SpeechStream
}

public protocol SpeechStream: Sendable {
  func next() async throws -> SpeechAudio?    // nil at the end
  func cancel()
}

public struct SpeechAudio: Sendable {
  public var sampleRate: Int
  public var samples: [Float]
}
```

- `SpeechRequest` carries text, voice id, speed, language and credential.
- `Reader` caps text with the provider's `maximumCharacters`, pulls from the stream and no longer builds requests or decodes PCM.
- `SpeechPlayer` takes its format and its 500 ms queue limit from the stream's sample rate, not a constant.
- Pull-based delivery keeps the current backpressure: an adapter must not read ahead without bound while playback is paused. The streaming HTTP body with its bounded queue moves to `Providers/HTTP/`. The PCM decoding moves into the xAI adapter.
- xAI keeps its voices `ara` and `altair`, its 0.7 to 1.5 range and its 60,000-character limit.

## Cleanup

```swift
public struct CleanupService: Sendable {
  public var revise: @Sendable (CleanupRequest) async throws -> String
}
// CleanupRequest: prompt, text, final, credential
```

- The prompt and faithfulness validation stay neutral, next to `Reviser`. The model, temperature, reasoning effort and request limits are adapter details.
- The operation's injected final-revision budget, live versus final behaviour and fallbacks are unchanged ([0021](../decisions/0021-revise-committed-dictation.md), [0024](../decisions/0024-dictation-operation-lifetime.md)).

## Errors

```swift
public enum ProviderError: Error, Equatable, Sendable {
  case rejectedCredential
  case rateLimited
  case unavailable
  case failed(String)
}
```

- `STTError` becomes private to the xAI adapter. `SessionError.stt` becomes `.provider(ProviderError)`.
- `Providers/HTTP/` maps statuses by default: 401 and 403 to `rejectedCredential`, 429 to `rateLimited`, 5xx to `unavailable`, and anything else to `failed`. xAI also maps 400 to `rejectedCredential`, as it does today.
- The controller words errors with the selected provider's name, producing today's text for xAI: "xAI rejected the API key", "xAI rate limit reached", "xAI is unavailable" and "xAI error: …". Connection, microphone and selection messages are unchanged.

## Settings and storage

Extend [0010](../decisions/0010-settings-storage-and-api-key.md). Each field still decodes on its own and falls back to its default.

- `provider`: the selected provider id. A missing or unknown id gives `Providers.all[0]`.
- `reading`: the voice and speed last chosen for each provider, stored as a JSON object keyed by provider id. Reading a provider's choice falls back to its first voice at speed 1, and to that default for a voice it no longer offers or a speed outside its range.
- Migration: when `reading` is absent, a stored `voice` and `speechSpeed` become the entry for `xai`, using today's speed validation. Encoding writes `reading` and stops writing `voice` and `speechSpeed`.
- `cleanUp` is ignored on decode and no longer written, like `batchOnCommit`.
- `DictationTrace.cleanUp` and Last Dictation's "cleanup off" label are removed. A dictation that wasn't cleaned up shows zero requests.

## Credentials

- The Keychain wrapper reads, saves and removes the item whose account is the provider id. Remove deletes only that item.
- A provider with `Credential.none` always counts as having its credential.
- `hasAPIKey` becomes whether the selected provider has its credential. Menu bar copy becomes "Add your <name> API key in Settings". Changing provider refreshes it.

## Settings window

- Rename the API Key tab to **Provider**. From top to bottom it has:
  - **Provider picker.** Lists `Providers.all`.
  - **Summary.** The provider's one-line summary.
  - **Feature list.** One row per service, "Live transcription", "Read aloud" and "Cleanup", with a green check mark when the provider has the service and a grey mark when it doesn't. Use SF Symbols and theme-aware colours, without cards or pills.
  - **Key row.** Only for a provider that needs a key. Keep today's masked key, Save, Replace, Remove and Test behaviour, with the provider's placeholder.
  - **Test.** Available for every provider. It uses the selected provider.
- General tab: remove the Clean up text toggle.
- Read Aloud tab: the voice picker lists the selected provider's voices with their display names. The speed slider uses its range with a 0.1 step. Both edit that provider's `reading` entry.
- Keyterms tab: the count reads "n of (keytermLimit − 1)", using the selected provider's limit.

## Verification

Keep tests focused on behaviour that would break for a user.

- **Session.** Session tests drive a scripted `LiveTranscriber` that emits neutral events, in place of xAI JSON over a scripted socket. They keep today's coverage of readiness, silence, pause, hard cap, finishing, cancellation and failure outcomes.
- **xAI adapter.** The existing protocol and assembler fixtures become xAI adapter tests, together with the translation table above.
- **Settings.** Tests cover migration of `voice` and `speechSpeed`, an ignored `cleanUp`, an unknown provider id, a remembered choice surviving a provider switch, and the fallback for a missing voice.
- **Operation.** Operation tests cover a provider without cleanup inserting unrevised text, replacing the `cleanUp: false` cases.
- **Reading.** Reading tests cover the player taking its format from the stream.
- **Live tests.** Opt-in tests under `Tests/EchoTypeCoreTests/Integration/` exercise the xAI adapter and stay disabled in CI.
- **Mac checks.** A signed build is checked on the Mac for:
  - an upgrade from the current install, keeping the key, voice and speed
  - dictation, with cleanup visible in Last Dictation
  - read aloud, MCP `speak` and Test
  - a wrong key, which shows the existing message
  - the Provider tab in both themes
- **No provider names leak.** Searching `Sources/` for `xai`, `xAI` and `x.ai` matches only `Providers/XAI/` and the registry.

## Documentation

- Add a decision record for provider adapters covering this contract and the "Adding a provider" steps.
- Update [0002](../decisions/0002-speech-signal-from-observed-protocol.md) and [0003](../decisions/0003-transcript-assembly.md) to say they describe the xAI adapter.
- Update [0006](../decisions/0006-api-key-and-error-surface.md) for errors, [0010](../decisions/0010-settings-storage-and-api-key.md) for storage and Keychain, [0018](../decisions/0018-read-aloud-audio-fetch.md) for the speech stream, and [0021](../decisions/0021-revise-committed-dictation.md) for cleanup that is always on.
- Update the README's features and install steps for the Provider tab and the removed toggle.

## Suggested slices

Each slice leaves a usable app and removes the code it replaces:

1. Transcription contract, session changes and xAI transcription adapter.
2. Read-aloud contract and xAI voice adapter.
3. Cleanup contract, `ProviderError` and provider-named messages.
4. Registry, settings storage and migration, Keychain per provider, Provider tab, and removal of the cleanup toggle.
