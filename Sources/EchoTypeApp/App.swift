import AppKit
import SwiftUI

@main
struct EchoTypeApp: App {
    init() {
        startHotkey()
    }

    var body: some Scene {
        MenuBarExtra("EchoType", systemImage: "waveform") {
            Button("Quit EchoType") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
