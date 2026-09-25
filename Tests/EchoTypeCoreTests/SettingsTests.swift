import EchoTypeCore
import Foundation
import Testing

@Test("Non-default settings survive a round trip")
func settingsRoundTrip() {
  let settings = Settings(
    hotkey: .controlOptionD,
    keyterms: ["shadcn", "TanStack Start"],
    language: "en-GB",
    inputDeviceID: "BuiltInMicrophoneDevice"
  )

  #expect(Settings(decoding: settings.encoded()) == settings)
}

/// The bytes this version stores. If this fails, a key name, the hotkey's shape or a modifier's
/// bit has changed and existing installs would lose that setting on upgrade. Opt+D is pinned too
/// because it is what most installs store; Ctrl+Opt+D alone would not notice control and option
/// swapping bits, and Opt+D alone would not notice a fallback to the default.
@Test("A stored value from this version decodes to the settings it was written from")
func storedValueDecodes() {
  let stored = Data(
    #"""
    {"hotkey":{"keyCode":2,"modifiers":6},"keyterms":["shadcn","TanStack Start"],"language":"en-GB","inputDeviceID":"BuiltInMicrophoneDevice"}
    """#.utf8)

  #expect(
    Settings(decoding: stored)
      == Settings(
        hotkey: .controlOptionD,
        keyterms: ["shadcn", "TanStack Start"],
        language: "en-GB",
        inputDeviceID: "BuiltInMicrophoneDevice"
      )
  )
  #expect(
    Settings(decoding: Data(#"{"hotkey":{"keyCode":2,"modifiers":4}}"#.utf8)).hotkey == .optionD)
}

@Test("A stored value missing fields keeps the ones it has and defaults the rest")
func missingFieldsDefault() {
  let stored = Data(#"{"hotkey":{"keyCode":2,"modifiers":6}}"#.utf8)

  #expect(Settings(decoding: stored) == Settings(hotkey: .controlOptionD))
}

@Test("Unreadable data decodes to the defaults")
func unreadableDataDefaults() {
  #expect(Settings(decoding: Data("not settings".utf8)) == Settings())
}
