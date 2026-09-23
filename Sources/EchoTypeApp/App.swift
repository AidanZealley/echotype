import AppKit
import SwiftUI

@main
struct EchoTypeApp: App {
  @State private var controller = DictationController()

  var body: some Scene {
    MenuBarExtra {
      Text(statusLine)
      Divider()
      Button("Quit EchoType") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Image(systemName: controller.state == .idle ? "waveform" : "waveform.circle.fill")
    }
  }

  private var statusLine: String {
    switch controller.state {
    case .idle: controller.problem ?? "Ready"
    case .listening: "Listening"
    case .paused: "Paused"
    case .finalizing, .inserting: "Finishing"
    case .cancelled: "Cancelled"
    }
  }
}
