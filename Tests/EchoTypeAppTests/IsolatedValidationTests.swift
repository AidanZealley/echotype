import Darwin
import EchoTypeCore
import Foundation
import Testing

@testable import EchoTypeApp

@Suite struct IsolatedValidationTests {
  @Test("Validation metadata cannot redirect normal app credentials or suppress its permission prompt")
  func guardedIdentity() throws {
    for id in ["com.aidanzealley.echotype", "com.other.app", "com.aidanzealley.echotype.stream4-validation-test"] {
      for enabled in [false, true] {
        let root = FileManager.default.temporaryDirectory.appending(path: "ValidationIdentity-\(UUID()).app")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: "Contents"), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
          fromPropertyList: ["CFBundleIdentifier": id, "EchoTypeIsolatedValidation": enabled], format: .xml, options: 0)
        try data.write(to: root.appending(path: "Contents/Info.plist"))
        let bundle = try #require(Bundle(url: root))
        let expected = enabled && id.hasPrefix("com.aidanzealley.echotype.stream4-validation-")
        #expect(bundle.isIsolatedValidation == expected)
        #expect(Keychain.service(for: bundle) == (expected ? id : "com.aidanzealley.echotype"))
      }
    }
  }
  @Test @MainActor func ownedPreferencesReadAndWriteAllFields() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "ValidationPreferences-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appending(path: "owned.plist")
    var settings = EchoTypeCore.Settings(dictationProvider: "xai", readAloudProvider: "local")
    let seed = try PropertyListSerialization.data(
      fromPropertyList: ["settings": settings.encoded(), "hotkeysActive": false], format: .xml, options: 0)
    try seed.write(to: path)
    let store = SettingsStore(validationPreferences: path)
    #expect(store.settings == settings)
    #expect(!store.hotkeysActive)
    settings.readAloudProvider = "apple"
    store.settings = settings
    store.hotkeysActive = true
    let reloaded = SettingsStore(validationPreferences: path)
    #expect(reloaded.settings == settings)
    #expect(reloaded.hotkeysActive)
    #expect(throws: (any Error).self) { try SettingsStore.validationPreferencePath(environment: [:]) }
    let realHome = URL(fileURLWithPath: String(cString: getpwuid(getuid())!.pointee.pw_dir))
    #expect(throws: (any Error).self) {
      try SettingsStore.validationPreferencePath(environment: ["CFFIXED_USER_HOME": realHome.path], redirectedHome: realHome)
    }
    #expect(throws: (any Error).self) {
      try SettingsStore.validationPreferencePath(environment: ["CFFIXED_USER_HOME": root.path], redirectedHome: realHome)
    }
  }

}
