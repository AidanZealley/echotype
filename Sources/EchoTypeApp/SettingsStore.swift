import EchoTypeCore
import Foundation
import Observation

/// The app's settings, loaded from `UserDefaults` at launch and written back on every change.
/// The only code that touches `UserDefaults`. The API key is not here; it lives in the Keychain.
@MainActor @Observable final class SettingsStore {
  /// The one `UserDefaults` key. Renaming it would reset every install's settings.
  private static let key = "settings"

  var settings: Settings {
    didSet { UserDefaults.standard.set(settings.encoded(), forKey: Self.key) }
  }

  init() {
    settings = Settings(decoding: UserDefaults.standard.data(forKey: Self.key))
  }
}
