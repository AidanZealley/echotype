import EchoTypeCore
import Foundation
import Observation

/// The app's settings, loaded from `UserDefaults` at launch and written back on every change.
/// The only code that touches `UserDefaults`. The API key is not here; it lives in the Keychain.
@MainActor @Observable final class SettingsStore {
  /// Renaming this key would reset every install's settings.
  private static let key = "settings"
  private static let activeKey = "hotkeysActive"

  private let defaults: UserDefaults?
  private let providers: [Provider]

  var settings: Settings {
    didSet {
      defaults?.set(settings.encoded(), forKey: Self.key)
      updateSelection()
    }
  }
  let localInstallation = LocalInstallation()

  var hotkeysActive: Bool {
    didSet {
      defaults?.set(hotkeysActive, forKey: Self.activeKey)
    }
  }

  /// Tests pass nil defaults, which keeps settings in memory, and no providers, so they never
  /// load real models.
  init(defaults: UserDefaults? = .standard, providers: [Provider] = Providers.all) {
    self.defaults = defaults
    self.providers = providers
    settings = Settings(decoding: defaults?.data(forKey: Self.key))
    hotkeysActive = defaults?.object(forKey: Self.activeKey) as? Bool ?? true
    updateSelection()
  }

  /// Tells each provider with setup which features it serves, so it can load or release them.
  private func updateSelection() {
    for provider in providers {
      guard let setup = provider.localSetup else { continue }
      var selected: Set<ProviderFeature> = []
      if settings.dictationProvider == provider.id { selected.insert(.dictation) }
      if settings.readAloudProvider == provider.id { selected.insert(.readAloud) }
      setup.select(selected)
    }
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
