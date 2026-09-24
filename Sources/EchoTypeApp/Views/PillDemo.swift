import AppKit

/// `--hud-demo`: plays the pill through every state with made-up transcripts, on a loop, so
/// the overlay can be reviewed in one launch. It drives `OverlayPanel` exactly as the dictation
/// controller does, and never touches the hotkey or the microphone.
@MainActor enum PillDemo {
  static func run() async {
    // Clicks do nothing here: committing a session is the controller's job.
    let panel = OverlayPanel(onClick: {})
    while !Task.isCancelled {
      await play(on: panel)
    }
  }

  private static let sentence =
    "Rename the session snapshot and update every call site, then run the tests again."
  private static let jargon = """
    so the AVAudioEngine tap resamples to 16 kHz linear PCM, the WebSocket to api.x.ai \
    streams it with interim_results on, the CGEventTap swallows Opt+D and Escape, and \
    NSPanel stays nonactivating at the screenSaver level while SwiftUI renders glassEffect
    """

  /// One pass through every state, about three seconds each.
  private static func play(on panel: OverlayPanel) async {
    func show(_ pill: Pill) {
      if let screen = NSScreen.main { panel.show(pill, on: screen) }
    }
    var pill = Pill(phase: .starting, startedAt: .now)
    show(pill)
    await pause(3)

    // Words arrive dimmed and turn solid every few words.
    pill.phase = .listening
    for (index, word) in sentence.split(separator: " ").enumerated() {
      pill.provisional += (pill.provisional.isEmpty ? "" : " ") + word
      if index % 4 == 3 {
        pill.settled += (pill.settled.isEmpty ? "" : " ") + pill.provisional
        pill.provisional = ""
      }
      pill.level = .random(in: 0.3...0.9)
      show(pill)
      await pause(0.2)
    }

    // Too long for two lines, so it loses its beginning.
    pill.settled += " " + pill.provisional + " " + jargon
    pill.provisional = "and the pill truncates from the left"
    await speak(&pill, for: 3, show: show)

    pill.phase = .paused
    pill.level = 0
    show(pill)
    await pause(3)

    // Past eight minutes the elapsed time turns amber.
    pill.phase = .listening
    pill.startedAt = .now - 8 * 60 - 5
    await speak(&pill, for: 3, show: show)

    pill.phase = .transcribing
    pill.level = 0
    show(pill)
    await pause(3)

    pill.phase = .error("xAI is unavailable")
    show(pill)
    await pause(3)
    panel.hide()
    await pause(1.5)

    // Nothing heard: the pill fades away silently.
    show(Pill(phase: .listening, startedAt: .now))
    await pause(3)
    panel.hide()
    await pause(2)
  }

  /// Moves the level as if someone were talking.
  private static func speak(
    _ pill: inout Pill, for seconds: Double, show: (Pill) -> Void
  ) async {
    for _ in 0..<Int(seconds * 10) {
      pill.level = .random(in: 0.2...0.9)
      show(pill)
      await pause(0.1)
    }
  }

  private static func pause(_ seconds: Double) async {
    try? await Task.sleep(for: .seconds(seconds))
  }
}
