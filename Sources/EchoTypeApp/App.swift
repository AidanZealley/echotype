import AppKit
import EchoTypeCore
import ServiceManagement
import SwiftUI

struct EchoTypeApp: App {
  @State private var store: SettingsStore
  /// Nil for `--hud-demo`, which shows the overlay and must not start the hotkey monitor or
  /// open the microphone. It records no dictation, so it has no Last Dictation window.
  @State private var controller: DictationController?

  init() {
    let store = SettingsStore()
    _store = State(initialValue: store)
    if CommandLine.arguments.contains("--hud-demo") {
      _controller = State(initialValue: nil)
      Task { await PillDemo.run() }
    } else {
      _controller = State(initialValue: DictationController(store: store))
    }
    Self.claimLoginItem()
  }

  /// `SMAppService.mainApp` answers `status` by bundle identifier, but the login item launches
  /// the copy that last registered it or read its status. An item enabled before install, or
  /// after opening Settings in the development bundle, points at `.build/EchoType.app`. The
  /// installed copy registers again at launch while the item is enabled, which points it back
  /// here. A disabled item stays disabled. The development bundle never claims it at launch.
  private static func claimLoginItem() {
    guard Bundle.main.bundlePath == "/Applications/EchoType.app" else { return }
    Task.detached {
      let service = SMAppService.mainApp
      guard service.status == .enabled else { return }
      try? service.register()
    }
  }

  var body: some Scene {
    MenuBarExtra {
      Text(statusLine)
      Divider()
      if controller != nil {
        Toggle("Enable hotkeys", isOn: $store.hotkeysActive)
          .disabled(!(controller?.isIdle ?? false))
        Divider()
      }
      WindowButtons(hasLastDictation: controller != nil)
      Button("Quit EchoType") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(nsImage: statusImage)
        .accessibilityLabel(statusLine)
    }

    Settings {
      SettingsView(store: store, controller: controller)
        .onDisappear(perform: windowClosed)
    }

    Window("Last Dictation", id: LastDictationWindow.id) {
      if let controller {
        LastDictationWindow(controller: controller)
          .onDisappear(perform: windowClosed)
      }
    }
    .defaultSize(width: 560, height: 640)
    // It opens only from the menu, so the app launches as an accessory app with no window.
    .defaultLaunchBehavior(.suppressed)
    // A window left open when the app quit must not come back at the next launch.
    .restorationBehavior(.disabled)
    // Keeps the window out of the Window menu, which the app shows while any window is open.
    .commandsRemoved()
  }

  private var statusLine: String {
    guard let controller else { return "Overlay demo" }
    if !store.hotkeysActive { return "Inactive" }
    if controller.hasCredential == false {
      return "Add your \(Providers[store.settings.provider].name) API key in Settings"
    }
    if let error = controller.lastError { return error }
    if controller.hasCredential == nil { return "Starting" }
    return switch controller.state {
    case .idle: "Ready"
    case .starting: "Starting"
    case .listening: "Listening"
    case .reading: "Reading"
    case .paused: "Paused"
    case .finishing, .inserting: "Finishing"
    case .cancelled: "Cancelled"
    }
  }

  /// Draw the opacity into the image so the menu bar gets one template icon.
  private var statusImage: NSImage {
    let dimmed = !store.hotkeysActive || controller?.hasCredential == false
      || controller?.lastError != nil
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
      guard let waveform = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
      else { return false }
      waveform.draw(
        in: NSRect(x: 0, y: 2, width: 18, height: 14), from: .zero,
        operation: .sourceOver, fraction: dimmed ? 0.5 : 1)
      return true
    }
    image.isTemplate = true
    return image
  }
}

/// The menu's window items: Settings, and Last Dictation when a controller records dictations.
private struct WindowButtons: View {
  let hasLastDictation: Bool
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Settings…") { presentWindow { openSettings() } }
    if hasLastDictation {
      Button("Last Dictation…") { presentWindow { openWindow(id: LastDictationWindow.id) } }
    }
  }
}

/// Opens a window in front, with keyboard focus, or in front and focused by a click when macOS
/// declines the activation. The app is `LSUIElement`, and macOS does not reliably activate an
/// accessory app, which left the window behind the frontmost app or without focus. So the app
/// becomes a regular app, with a Dock icon, while any of its windows is open, as Tailscale does.
/// `windowClosed` switches it back. See decision 0011.
@MainActor private func presentWindow(_ open: () -> Void) {
  NSApplication.shared.setActivationPolicy(.regular)
  open()
  // An activation requested while the menu is still closing can be lost, so wait for it to
  // close.
  DispatchQueue.main.async {
    NSApplication.shared.activate()
    // Activation is cooperative and macOS occasionally declines it, which left the window
    // behind the frontmost app. Raising the window regardless keeps it in front; a click then
    // focuses it. The window just opened is the app's frontmost window that can become main:
    // the overlay panel and the menu bar's windows cannot.
    NSApplication.shared.orderedWindows.first { $0.canBecomeMain && $0.isVisible }?
      .orderFrontRegardless()
  }
}

/// Hides the Dock icon again once the last window closes, so closing one window leaves it while
/// the other is open or minimised. Checked on the next turn, when the closing window is no
/// longer visible.
@MainActor private func windowClosed() {
  DispatchQueue.main.async {
    let open = NSApplication.shared.windows.contains {
      $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized)
    }
    guard !open else { return }
    NSApplication.shared.setActivationPolicy(.accessory)
  }
}
