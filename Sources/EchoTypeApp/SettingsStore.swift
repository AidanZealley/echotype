import Darwin
import EchoTypeCore
import Foundation
import Observation

/// The app's settings, loaded from `UserDefaults` at launch and written back on every change.
/// The only code that touches `UserDefaults`. The API key is not here; it lives in the Keychain.
@MainActor @Observable final class SettingsStore {
  /// Renaming this key would reset every install's settings.
  private static let key = "settings"
  private static let activeKey = "hotkeysActive"
  private let validationPreferences: URL?

  /// The CFPreferences daemon does not honor the validation process's redirected home.
  /// Only the signed validation identity writes this owned plist directly.
  static func validationPreferencePath(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    redirectedHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> URL {
    guard let configured = environment["CFFIXED_USER_HOME"], configured.hasPrefix("/"),
      let account = getpwuid(getuid()), let realPath = account.pointee.pw_dir
    else { throw ProviderError.failed("Isolated validation requires an explicit owned home.") }
    let root = URL(fileURLWithPath: configured).standardizedFileURL
    let realHome = URL(fileURLWithPath: String(cString: realPath)).standardizedFileURL
    guard root == redirectedHome.standardizedFileURL, root != realHome,
      root.resolvingSymlinksInPath() != realHome.resolvingSymlinksInPath()
    else { throw ProviderError.failed("The validation home must redirect away from the user's real home.") }
    return root.appending(path: "Library/Preferences/\(Bundle.main.bundleIdentifier!).plist")
  }

  private static var isolatedPreferences: URL? {
    guard Bundle.main.isIsolatedValidation else { return nil }
    // Fail closed before any defaults read or write if the validation launch is not isolated.
    return try! validationPreferencePath()
  }

  private func saveValidationPreferences() {
    guard let validationPreferences else { return }
    let data = try! PropertyListSerialization.data(
      fromPropertyList: [Self.key: settings.encoded(), Self.activeKey: hotkeysActive], format: .xml, options: 0)
    try! data.write(to: validationPreferences, options: .atomic)
  }

  var settings: Settings {
    didSet {
      if validationPreferences != nil { saveValidationPreferences() }
      else { UserDefaults.standard.set(settings.encoded(), forKey: Self.key) }
      updateLocalSelection()
    }
  }
  let localInstallation = LocalInstallation()

  var hotkeysActive: Bool {
    didSet {
      if validationPreferences != nil { saveValidationPreferences() }
      else { UserDefaults.standard.set(hotkeysActive, forKey: Self.activeKey) }
    }
  }

  init(validationPreferences: URL? = SettingsStore.isolatedPreferences) {
    self.validationPreferences = validationPreferences
    if let validationPreferences {
      let data = try? Data(contentsOf: validationPreferences)
      let values = data.flatMap {
        try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? [String: Any]
      }
      settings = Settings(decoding: values?[Self.key] as? Data)
      hotkeysActive = values?[Self.activeKey] as? Bool ?? true
    } else {
      settings = Settings(decoding: UserDefaults.standard.data(forKey: Self.key))
      hotkeysActive = UserDefaults.standard.object(forKey: Self.activeKey) as? Bool ?? true
    }
    updateLocalSelection()
  }
  private func updateLocalSelection() {
    var selected: Set<ProviderFeature> = []
    if settings.dictationProvider == "local" { selected.insert(.dictation) }
    if settings.readAloudProvider == "local" { selected.insert(.readAloud) }
    Provider.local.localSetup?.select(selected)
  }
}

/// Setup survives navigation between Settings pages. No work starts in its initializer.
@MainActor @Observable final class LocalInstallation {
  var readiness: ServiceReadiness?
  var files: [LocalFile] = []
  var requested: Set<ProviderFeature> = []
  var running: Bool { !requested.isEmpty }
  var message: String?
  var messages: [ProviderFeature: String] = [:]
  @ObservationIgnored private var tasks: [ProviderFeature: Task<Void, Never>] = [:]
  @ObservationIgnored private var generations: [ProviderFeature: UUID] = [:]
  private let controls: LocalSetup

  init(controls: LocalSetup = Provider.local.localSetup!) { self.controls = controls }

  func follow() async {
    await refreshFiles()
    await Provider.local.readiness.follow(.init(language: "en", voice: "bf_emma")) {
      self.readiness = $0
    }
  }

  func start(_ features: Set<ProviderFeature>) {
    for feature in features where !requested.contains(feature) {
      let id = UUID()
      generations[feature] = id
      requested.insert(feature)
      messages[feature] = nil
      let controls = controls
      tasks[feature] = Task {
        do {
          try await controls.install([feature])
        } catch {
          if generations[feature] == id { messages[feature] = error.localizedDescription }
        }
        guard generations[feature] == id else { return }
        requested.remove(feature)
        tasks[feature] = nil
        await refreshFiles()
      }
    }
  }

  func cancel(_ feature: ProviderFeature) {
    guard requested.contains(feature) else { return }
    let id = UUID()
    generations[feature] = id
    let task = tasks[feature]
    task?.cancel()
    controls.cancel([feature])
    messages[feature] = "Cancelling. Verified downloads will be retained for retry."
    Task {
      await task?.value
      guard generations[feature] == id else { return }
      requested.remove(feature)
      tasks[feature] = nil
      messages[feature] = "Cancelled. Retained files can be reused or removed."
      await refreshFiles()
    }
  }

  func refreshFiles() async {
    let controls = controls
    do { files = try await Task.detached { try controls.inventory() }.value } catch {
      message = error.localizedDescription
    }
  }

  func remove(_ files: [LocalFile]) async {
    let controls = controls
    do {
      try await Task.detached { try controls.remove(files) }.value
      message = "Files removed. Downloaded models can be installed again."
    } catch { message = error.localizedDescription }
    await refreshFiles()
  }
}
