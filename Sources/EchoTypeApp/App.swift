import AppKit
import ServiceManagement
import SwiftUI

@main
struct EchoTypeApp: App {
  @State private var store: SettingsStore
  /// Nil for `--hud-demo`, which shows the overlay and must not start the hotkey monitor or
  /// open the microphone.
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
      SettingsButton()
      Button("Quit EchoType") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(systemName: (controller?.state ?? .idle) == .idle ? "waveform" : "waveform.circle.fill")
    }

    Settings {
      SettingsView(store: store, controller: controller)
        // Hide the Dock icon again once the window closes. See `SettingsButton`.
        .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }
  }

  private var statusLine: String {
    guard let controller else { return "Overlay demo" }
    return switch controller.state {
    case .idle: "Ready"
    case .listening: "Listening"
    case .paused: "Paused"
    case .finalizing, .inserting: "Finishing"
    case .cancelled: "Cancelled"
    }
  }
}

/// Opens the settings window in front, with keyboard focus, or in front and focused by a
/// click when macOS declines the activation. The app is `LSUIElement`, and macOS does not
/// reliably activate an accessory app, which left the window behind the frontmost app or
/// without focus. So the app becomes a regular app, with a Dock icon, while the window is
/// open, as Tailscale does. The scene's `onDisappear` switches it back.
private struct SettingsButton: View {
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Button("Settings…") {
      NSApplication.shared.setActivationPolicy(.regular)
      openSettings()
      // An activation requested while the menu is still closing can be lost, so wait for it
      // to close.
      DispatchQueue.main.async {
        NSApplication.shared.activate()
        // Activation is cooperative and macOS occasionally declines it, which left the window
        // behind the frontmost app. Raising the window regardless keeps it in front; a click
        // then focuses it. It is the app's only window that can become main: the overlay
        // panel and the menu bar's windows cannot.
        NSApplication.shared.windows.first { $0.canBecomeMain && $0.isVisible }?
          .orderFrontRegardless()
      }
    }
  }
}
