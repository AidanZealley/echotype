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
/// Features install one at a time, in the order they were requested.
@MainActor @Observable final class LocalInstallation {
  var readiness: ServiceReadiness?
  var files: [LocalFile] = []
  /// Features waiting to install. The first is installing.
  private(set) var queue: [ProviderFeature] = []
  var message: String?
  var messages: [ProviderFeature: String] = [:]
  /// Installs the queue, then ends. Tests await it.
  @ObservationIgnored private(set) var worker: Task<Void, Never>?
  @ObservationIgnored private var current: Task<Void, any Error>?
  private let controls: LocalSetup

  init(controls: LocalSetup = Provider.local.localSetup!) { self.controls = controls }

  func follow() async {
    await refreshFiles()
    await Provider.local.readiness.follow(.init(language: "en", voice: "bf_emma")) {
      self.readiness = $0
    }
  }

  func start(_ feature: ProviderFeature) {
    guard !queue.contains(feature) else { return }
    messages[feature] = nil
    queue.append(feature)
    if worker == nil { worker = Task { await work(); worker = nil } }
  }

  func cancel(_ feature: ProviderFeature) {
    if queue.first == feature, let current { current.cancel() } else { queue.removeAll { $0 == feature } }
  }

  private func work() async {
    while let feature = queue.first {
      let controls = controls
      let task = Task { try await controls.install(feature) }
      current = task
      do { try await task.value } catch is CancellationError {
        messages[feature] = "Cancelled."
      } catch {
        messages[feature] = task.isCancelled ? "Cancelled." : error.localizedDescription
      }
      current = nil
      queue.removeFirst()
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
