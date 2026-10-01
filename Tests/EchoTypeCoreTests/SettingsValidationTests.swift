import EchoTypeCore
import Foundation
import Testing

@Suite struct SettingsValidationTests {
  @Test(arguments: ["null", "\"fast\"", "0.69", "1.51", "-1", "1e999"])
  func invalidStoredSpeedPreservesOtherPreferences(speed: String) {
    let stored = Data("""
      {"hotkey":{"keyCode":2,"modifiers":6},"keyterms":["EchoType"],"language":"en-GB","inputDeviceID":"mic","readAloudHotkey":{"keyCode":1,"modifiers":6},"voice":"altair","speechSpeed":\(speed),"sendReplyRequests":false}
      """.utf8)
    #expect(Settings(decoding: stored) == Settings(
      hotkey: .controlOptionD, keyterms: ["EchoType"], language: "en-GB",
      inputDeviceID: "mic", readAloudHotkey: .controlOptionS,
      reading: ["xai": .init(voice: "altair")], sendReplyRequests: false))
  }

  @Test(arguments: [0.7, 1.25, 1.5])
  func validSpeedSurvivesStorageAndRequest(speed: Double) {
    let settings = Settings(reading: ["xai": .init(voice: "ara", speed: speed)])
    #expect(Settings(decoding: settings.encoded()) == settings)
    #expect(SpeechRequest(text: "Hello", settings: settings, voice: Providers.all[0].voice, credential: nil).speed == speed)
  }

  @Test(arguments: [Double.nan, .infinity, -.infinity, 0.69, 1.51])
  func publicInvalidSpeedEncodesSafely(speed: Double) throws {
    // Exercise both public ways to supply speed. Neither persistence nor requests may trap.
    var mutated = Settings(reading: ["xai": .init(voice: "altair")])
    mutated.reading["xai"]?.speed = speed
    for settings in [Settings(reading: ["xai": .init(voice: "altair", speed: speed)]), mutated] {
      let encoded = settings.encoded()
      let storage = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
      let reading = try #require(storage["reading"] as? [String: [String: Any]])
      #expect(reading["xai"]?["speed"] as? Double == 1)
      #expect(reading["xai"]?["voice"] as? String == "altair")
      #expect(Settings(decoding: encoded) == Settings(reading: ["xai": .init(voice: "altair")]))
      let request = SpeechRequest(text: "Hello", settings: settings, voice: Providers.all[0].voice, credential: nil)
      #expect(request.speed == 1)
      #expect(request.voice == "altair")
    }
  }
}

extension SettingsValidationTests {
  @Test func readingMigrationWritesOnlyTheNewFormat() throws {
    let settings = Settings(decoding: Data(#"{"voice":"altair","speechSpeed":1.25}"#.utf8))
    #expect(settings.reading["xai"] == .init(voice: "altair", speed: 1.25))
    let stored = try #require(JSONSerialization.jsonObject(with: settings.encoded()) as? [String: Any])
    #expect(stored["reading"] != nil)
    #expect(stored["voice"] == nil && stored["speechSpeed"] == nil)
    #expect(Settings(decoding: settings.encoded()) == settings)
  }

  @Test func providerChoicesSurviveSwitchingAndStorage() {
    var first = Providers.all[0]
    first.id = "first"
    var second = first
    second.id = "second"
    second.voice.voices = [Voice(id: "second-voice", name: "Second voice")]
    second.voice.speedRange = 0.5...2
    var settings = Settings(provider: first.id, reading: [
      "first": .init(voice: "altair", speed: 1.25),
      "second": .init(voice: "second-voice", speed: 1.8),
    ])
    #expect(settings.readingChoice(for: first.voice) == .init(voice: "altair", speed: 1.25))
    settings.provider = second.id
    #expect(settings.readingChoice(for: second.voice) == .init(voice: "second-voice", speed: 1.8))
    settings.provider = first.id
    #expect(settings.readingChoice(for: first.voice) == .init(voice: "altair", speed: 1.25))
    #expect(Settings(decoding: settings.encoded()).reading == settings.reading)
  }

  @Test func readingFieldsAndEntriesDecodeIndependently() {
    let stored = Data(#"{"language":"en-GB","voice":"altair","speechSpeed":1.5,"reading":{"xai":{"voice":42,"speed":1.25},"other":{"voice":"remembered","speed":"bad"},"broken":false}}"#.utf8)
    let settings = Settings(decoding: stored)
    #expect(settings.language == "en-GB")
    #expect(settings.readingChoice(for: Providers.all[0].voice) == .init(voice: "ara", speed: 1.25))
    #expect(settings.reading["other"] == .init(voice: "remembered", speed: 1))
    #expect(settings.reading["broken"] == nil)
    let retiredVoice = Settings(reading: ["xai": .init(voice: "retired", speed: 1.2)])
    #expect(retiredVoice.readingChoice(for: Providers.all[0].voice) == .init(voice: "ara", speed: 1.2))
    let badSpeed = Settings(reading: ["xai": .init(voice: "altair", speed: 2)])
    #expect(badSpeed.readingChoice(for: Providers.all[0].voice) == .init(voice: "altair", speed: 1))
    let malformed = Settings(decoding: Data(#"{"reading":false,"voice":"altair","speechSpeed":1.5,"language":"fr"}"#.utf8))
    #expect(malformed.reading.isEmpty && malformed.language == "fr")
  }
}
