import EchoTypeCore
import Foundation
import Observation

/// The app's settings, loaded from `UserDefaults` at launch and written back on every change.
/// The only code that touches `UserDefaults`. The API key is not here; it lives in the Keychain.
@MainActor @Observable final class SettingsStore {
  /// Renaming this key would reset every install's settings.
  private static let key = "settings"
  private static let activeKey = "hotkeysActive"

  var settings: Settings {
    didSet { UserDefaults.standard.set(settings.encoded(), forKey: Self.key) }
  }
  var hotkeysActive: Bool {
    didSet { UserDefaults.standard.set(hotkeysActive, forKey: Self.activeKey) }
  }

  init() {
    settings = Settings(decoding: UserDefaults.standard.data(forKey: Self.key))
    hotkeysActive = UserDefaults.standard.object(forKey: Self.activeKey) as? Bool ?? true
  }
}
