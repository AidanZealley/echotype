import Foundation

/// Everything the overlay pill shows. The pill renders this value and nothing else, so the
/// `--hud-demo` loop and the dictation controller drive it the same way: build a `Pill` and
/// hand it to `OverlayPanel.show(_:on:)`.
struct Pill: Equatable {
  enum Phase: Equatable {
    /// The microphone is opening. Anything said now is lost, so the pill looks not ready.
    case starting
    case listening
    /// No speech for a while. The session is still open and waiting.
    case paused
    /// Committed; waiting for the final text.
    case transcribing
    /// Shown inline in red.
    case error(String)
  }

  var phase: Phase
  /// Rendered solid. `SessionMachine.Snapshot.settled`, which is not append-only.
  var settled = ""
  /// Rendered dimmed after `settled`. `SessionMachine.Snapshot.provisional`.
  var provisional = ""
  /// Input level from 0 to 1, already scaled for display.
  var level = 0.0
  /// The pill derives elapsed time from this.
  var startedAt: Date
}
