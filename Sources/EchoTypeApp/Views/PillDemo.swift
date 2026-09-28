import AppKit

/// `--hud-demo` drives the same panel as dictation, including preview overflow and compact states.
@MainActor enum PillDemo {
  private static let lines = [
    "The transcript starts on one line.",
    "Each sentence adds another readable line.",
    "The pill grows around the transcript.",
    "New words keep arriving in the preview.",
    "The text approaches the pixel height limit.",
    "The preview reaches its height cap.",
    "This line makes the transcript overflow.",
    "The newest words remain in view.",
    "Older words fade and clip at the top.",
    "The newest words stay at the bottom.",
    "No wheel or trackpad input is required.",
    "The final line remains visible at the bottom.",
  ]

  static func run() async {
    let panel = OverlayPanel()
    while !Task.isCancelled {
      var pill = Pill(
        phase: .listening, settled: lines[0], startedAt: .now)
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(3)

      // Words arrive dimmed, then the settled run takes their place every few words.
      for (index, word) in lines.dropFirst().joined(separator: " ").split(separator: " ").enumerated() {
        pill.provisional += (pill.provisional.isEmpty ? "" : " ") + word
        if index % 6 == 5 {
          pill.settled += " " + pill.provisional
          pill.provisional = ""
        }
        pill.level = .random(in: 0.2...0.9)
        if let screen = NSScreen.main { panel.show(pill, on: screen) }
        await pause(0.24)
      }

      // An earlier correction can leave the preview while the newest text stays visible.
      if !pill.provisional.isEmpty {
        pill.settled += " " + pill.provisional
        pill.provisional = ""
      }
      pill.settled = pill.settled.replacingOccurrences(of: "The pill grows", with: "The preview grows")
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(3)

      pill.phase = .transcribing
      pill.level = 0
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(2)

      pill = Pill(
        phase: .reading, isReading: true, settled: "Reading the first 60,000 characters",
        startedAt: .now)
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(3)

      pill.phase = .readingPaused
      pill.pausedAt = .now
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(2)

      pill = Pill(phase: .error("Nothing selected"), isReading: true, startedAt: .now)
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
      await pause(3)
      panel.hide()
      await pause(1.5)
    }
  }

  private static func pause(_ seconds: Double) async {
    try? await Task.sleep(for: .seconds(seconds))
  }
}
