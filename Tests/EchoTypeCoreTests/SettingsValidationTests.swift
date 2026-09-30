import EchoTypeCore
import Foundation
import Testing

@Suite struct SettingsValidationTests {
  @Test(arguments: ["null", "\"fast\"", "0.69", "1.51", "-1", "1e999"])
  func invalidStoredSpeedPreservesOtherPreferences(speed: String) {
    let stored = Data("""
      {"hotkey":{"keyCode":2,"modifiers":6},"keyterms":["EchoType"],"language":"en-GB","inputDeviceID":"mic","cleanUp":false,"readAloudHotkey":{"keyCode":1,"modifiers":6},"voice":"altair","speechSpeed":\(speed),"sendReplyRequests":false}
      """.utf8)
    #expect(Settings(decoding: stored) == Settings(
      hotkey: .controlOptionD, keyterms: ["EchoType"], language: "en-GB",
      inputDeviceID: "mic", cleanUp: false, readAloudHotkey: .controlOptionS,
      voice: "altair", sendReplyRequests: false))
  }

  @Test(arguments: [0.7, 1.25, 1.5])
  func validSpeedSurvivesStorageAndRequest(speed: Double) throws {
    let settings = Settings(speechSpeed: speed)
    #expect(Settings(decoding: settings.encoded()) == settings)
    let request = Speech.request(text: "Hello", settings: settings, apiKey: "fake")
    let data = try #require(request.httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(body["speed"] as? Double == speed)
  }

  @Test(arguments: [Double.nan, .infinity, -.infinity, 0.69, 1.51])
  func publicInvalidSpeedEncodesSafely(speed: Double) throws {
    // Exercise both public ways to supply speed. Neither persistence nor requests may trap.
    var mutated = Settings(voice: "altair")
    mutated.speechSpeed = speed
    for settings in [Settings(voice: "altair", speechSpeed: speed), mutated] {
      let encoded = settings.encoded()
      let storage = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
      #expect(storage["speechSpeed"] as? Double == Settings().speechSpeed)
      #expect(storage["voice"] as? String == "altair")
      #expect(Settings(decoding: encoded) == Settings(voice: "altair"))
      let request = Speech.request(text: "Hello", settings: settings, apiKey: "fake")
      let data = try #require(request.httpBody)
      let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      #expect(body["speed"] as? Double == Settings().speechSpeed)
      #expect(body["voice_id"] as? String == "altair")
    }
  }
}
