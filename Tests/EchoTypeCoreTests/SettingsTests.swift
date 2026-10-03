import EchoTypeCore
import Foundation
import Testing

@Test("Non-default settings survive a round trip")
func settingsRoundTrip() {
  let settings = Settings(
    hotkey: .controlOptionD,
    provider: "xai",
    keyterms: ["shadcn", "TanStack Start"],
    inputDeviceID: "BuiltInMicrophoneDevice",
    readAloudHotkey: .controlOptionS,
    reading: ["xai": .init(voice: "altair", speed: 1.25)],
    sendReplyRequests: false
  )

  #expect(Settings(decoding: settings.encoded()) == settings)
  #expect(String(decoding: settings.encoded(), as: UTF8.self).contains(#""provider":"xai""#))
}

/// The bytes this version stores. If this fails, a key name, the hotkey's shape or a modifier's
/// bit has changed, which would reset the stored setting. Opt+D is pinned too
/// because it is what most installs store; Ctrl+Opt+D alone would not notice control and option
/// swapping bits, and Opt+D alone would not notice a fallback to the default. Ctrl+Opt+S pins
/// the read-aloud hotkey's key code.
@Test("A stored value from this version decodes to the settings it was written from")
func storedValueDecodes() {
  let stored = Data(
    #"""
    {"hotkey":{"keyCode":2,"modifiers":6},"provider":"xai","keyterms":["shadcn","TanStack Start"],"language":"en","inputDeviceID":"BuiltInMicrophoneDevice","readAloudHotkey":{"keyCode":1,"modifiers":6},"reading":{"xai":{"voice":"altair","speed":1.25}}}
    """#.utf8)

  #expect(
    Settings(decoding: stored)
      == Settings(
        hotkey: .controlOptionD,
        provider: "xai",
        keyterms: ["shadcn", "TanStack Start"],
        inputDeviceID: "BuiltInMicrophoneDevice",
        readAloudHotkey: .controlOptionS,
        reading: ["xai": .init(voice: "altair", speed: 1.25)]
      )
  )
  #expect(
    Settings(decoding: Data(#"{"hotkey":{"keyCode":2,"modifiers":4}}"#.utf8)).hotkey == .optionD)
}

@Test("A stored value missing fields keeps the ones it has and defaults the rest")
func missingFieldsDefault() {
  let stored = Data(#"{"hotkey":{"keyCode":2,"modifiers":6}}"#.utf8)

  #expect(Settings(decoding: stored) == Settings(hotkey: .controlOptionD))
  #expect(Settings(decoding: stored).provider == Providers.all[0].id)
  #expect(Settings(decoding: stored).readAloudHotkey == .optionS)
  #expect(Settings(decoding: stored).readingChoice(for: Providers.all[0]).voice == "ara")
  #expect(Settings(decoding: stored).readingChoice(for: Providers.all[0]).speed == 1.0)
  #expect(Settings(decoding: stored).sendReplyRequests)
}

@Test("An unknown provider falls back to the default without discarding other settings")
func unknownProvider() {
  let stored = Data(#"{"hotkey":{"keyCode":2,"modifiers":6},"provider":"retired"}"#.utf8)

  #expect(Settings(decoding: stored) == Settings(hotkey: .controlOptionD))
  #expect(Settings(decoding: stored).provider == Providers.all[0].id)
}

@Test("xAI stays the default, and a stored Apple selection loads as Apple")
func registeredProviders() {
  let stored = Data(#"{"provider":"apple"}"#.utf8)

  #expect(Providers.all.map(\.id) == ["xai", "apple"])
  #expect(Settings(decoding: stored).provider == Provider.apple.id)
}

@Test("A malformed sendReplyRequests falls back to on without discarding other settings")
func malformedSendReplyRequests() {
  let stored = Data(#"{"hotkey":{"keyCode":2,"modifiers":6},"sendReplyRequests":"no"}"#.utf8)

  #expect(Settings(decoding: stored) == Settings(hotkey: .controlOptionD))
}

@Test("A saved language the provider does not list is kept, and resolves to its default")
func savedLanguageOutsideProviderList() {
  let settings = Settings(language: "fr")

  #expect(Settings(decoding: settings.encoded()).language == "fr")
  #expect(settings.language(for: .xAI) == "en")
}

@Test("Unreadable data decodes to the defaults")
func unreadableDataDefaults() {
  #expect(Settings(decoding: Data("not settings".utf8)) == Settings())
}
