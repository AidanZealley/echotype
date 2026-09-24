import AppKit
import SwiftUI

@main
struct EchoTypeApp: App {
  /// Nil for `--hud-demo`, which shows the overlay and must not start the hotkey monitor or
  /// open the microphone.
  @State private var controller: DictationController?

  init() {
    if CommandLine.arguments.contains("--hud-demo") {
      _controller = State(initialValue: nil)
      Task { await PillDemo.run() }
    } else {
      _controller = State(initialValue: DictationController())
    }
  }

  var body: some Scene {
    MenuBarExtra {
      Text(statusLine)
      Divider()
      Button("Quit EchoType") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(systemName: (controller?.state ?? .idle) == .idle ? "waveform" : "waveform.circle.fill")
    }
  }

  private var statusLine: String {
    guard let controller else { return "Overlay demo" }
    return switch controller.state {
    case .idle: controller.problem ?? "Ready"
    case .listening: "Listening"
    case .paused: "Paused"
    case .finalizing, .inserting: "Finishing"
    case .cancelled: "Cancelled"
    }
  }
}
