import EchoTypeCore
import Foundation
import Testing

@Test("Non-default settings survive a round trip")
func settingsRoundTrip() {
  let settings = Settings(
    hotkey: .controlOptionD,
    dictationProvider: "xai",
    keyterms: ["shadcn", "TanStack Start"],
    inputDeviceID: "BuiltInMicrophoneDevice",
    readAloudHotkey: .controlOptionS,
    reading: ["xai": .init(voice: "altair", speed: 1.25)],
    sendReplyRequests: false
  )

  #expect(Settings(decoding: settings.encoded()) == settings)
  #expect(String(decoding: settings.encoded(), as: UTF8.self).contains(#""dictationProvider":"xai""#))
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
        dictationProvider: "xai",
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
  #expect(Settings(decoding: stored).dictationProvider == Providers.all[0].id)
  #expect(Settings(decoding: stored).readAloudHotkey == .optionS)
  #expect(Settings(decoding: stored).readingChoice(for: Providers.all[0]).voice == "ara")
  #expect(Settings(decoding: stored).readingChoice(for: Providers.all[0]).speed == 1.0)
  #expect(Settings(decoding: stored).sendReplyRequests)
}

@Test("An unknown provider falls back to the default without discarding other settings")
func unknownProvider() {
  let stored = Data(#"{"hotkey":{"keyCode":2,"modifiers":6},"provider":"retired"}"#.utf8)

  #expect(Settings(decoding: stored) == Settings(hotkey: .controlOptionD))
  #expect(Settings(decoding: stored).dictationProvider == Providers.all[0].id)
}

@Test("xAI stays the default, and registered provider selections load")
func registeredProviders() {
  #expect(Providers.all.map(\.id) == ["xai", "local"])
  #expect(Settings(decoding: nil).dictationProvider == Provider.xAI.id)
  for provider in Providers.all {
    let settings = Settings(dictationProvider: provider.id)
    #expect(Settings(decoding: settings.encoded()).dictationProvider == provider.id)
  }
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

@Test("Each missing feature migrates from legacy selection; explicit choices win")
func featureProviderMigration() throws {
  let cases: [(String, ProviderID, ProviderID)] = [
    (#"{"provider":"local"}"#, "local", "local"),
    (#"{"provider":"xai","dictationProvider":"local"}"#, "local", "xai"),
    (#"{"provider":"local","readAloudProvider":"xai"}"#, "local", "xai"),
    (#"{"provider":"local","dictationProvider":"retired","readAloudProvider":"local"}"#, "xai", "local"),
    (#"{"provider":"local","dictationProvider":false}"#, "xai", "local"),
    (#"{"provider":"local","readAloudProvider":null}"#, "local", "xai"),
    (#"{"provider":false,"dictationProvider":"local","readAloudProvider":"xai"}"#, "local", "xai"),
  ]
  for (json, dictation, reading) in cases {
    let settings = Settings(decoding: Data(json.utf8))
    #expect(settings.dictationProvider == dictation)
    #expect(settings.readAloudProvider == reading)
    let encoded = try #require(JSONSerialization.jsonObject(with: settings.encoded()) as? [String: Any])
    #expect(encoded["provider"] == nil)
    #expect(encoded["dictationProvider"] as? String == dictation.rawValue)
    #expect(encoded["readAloudProvider"] as? String == reading.rawValue)
  }
}

@Test("Independent provider choices retain unrelated settings and reading preferences")
func independentProviderStorage() {
  var settings = Settings(
    hotkey: .controlOptionD, dictationProvider: "xai", readAloudProvider: "local",
    keyterms: ["TanStack"], language: "en-GB", inputDeviceID: "mic",
    readAloudHotkey: .controlOptionS,
    reading: ["xai": .init(voice: "altair", speed: 1.25)], sendReplyRequests: false)
  #expect(Settings(decoding: settings.encoded()) == settings)
  settings.dictationProvider = "local"
  #expect(Settings(decoding: settings.encoded()).readAloudProvider == "local")
  settings.readAloudProvider = "xai"
  #expect(Settings(decoding: settings.encoded()).dictationProvider == "local")
  #expect(Settings(decoding: settings.encoded()).reading == settings.reading)
}

@Test("Removed Apple selections fall back independently and retired reading preferences are discarded")
func retiredProviderMigration() throws {
  let cases: [(String, ProviderID, ProviderID)] = [
    (#"{"provider":"apple"}"#, "xai", "xai"),
    (#"{"provider":"apple","dictationProvider":"local"}"#, "local", "xai"),
    (#"{"dictationProvider":"apple","readAloudProvider":"local"}"#, "xai", "local"),
    (#"{"dictationProvider":"local","readAloudProvider":"apple"}"#, "local", "xai"),
  ]
  for (json, dictation, readAloud) in cases {
    var stored = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    stored["keyterms"] = ["Vite"]
    stored["reading"] = [
      "apple": ["voice": "retired-voice", "speed": 1.5],
      "retired": ["voice": "another-retired-voice", "speed": 1.5],
      "xai": ["voice": "altair", "speed": 1.25],
    ]
    let settings = Settings(decoding: try JSONSerialization.data(withJSONObject: stored))
    #expect(settings.dictationProvider == dictation)
    #expect(settings.readAloudProvider == readAloud)
    #expect(settings.keyterms == ["Vite"])
    #expect(settings.reading == ["xai": .init(voice: "altair", speed: 1.25)])
    #expect(Settings(decoding: settings.encoded()) == settings)
  }
}

@Test("Encoding reading preferences excludes unregistered providers")
func retiredReadingPreferencesAreNotStored() throws {
  let settings = Settings(reading: [
    "retired": .init(voice: "old-voice", speed: 1.5),
    "xai": .init(voice: "altair", speed: 1.25),
  ])
  let stored = try #require(JSONSerialization.jsonObject(with: settings.encoded()) as? [String: Any])
  let reading = try #require(stored["reading"] as? [String: Any])
  #expect(Set(reading.keys) == ["xai"])
}
