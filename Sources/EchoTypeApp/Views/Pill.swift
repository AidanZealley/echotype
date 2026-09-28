import Foundation

/// Everything the overlay pill shows. The pill renders this value and nothing else, so the
/// `--hud-demo` loop and the dictation controller, for dictation and reading alike, drive it the
/// same way: build a `Pill` and hand it to `OverlayPanel.show(_:on:)`.
struct Pill: Equatable {
  enum Phase: Equatable {
    /// The microphone is opening. Anything said now is lost, so the pill looks not ready.
    case starting
    case listening
    /// No speech for a while. The session is still open and waiting.
    case paused
    /// Committed; waiting for the final text.
    case transcribing
    /// Reading the selection aloud. The level is the audio's as it plays.
    case reading
    /// Reading is paused by the user, with its place in the audio retained.
    case readingPaused
    /// Shown inline in red.
    case error(String)
  }

  var phase: Phase
  /// Keeps the reading layout when a reading ends with an error.
  var isReading = false
  /// The microphone that actually opened for this dictation.
  var inputDevice: InputDevice?
  /// Rendered solid. Committed text, revised when cleanup is on, followed by settled utterance runs.
  var settled = ""
  /// Rendered dimmed after `settled`. `SessionMachine.Snapshot.provisional`.
  var provisional = ""
  /// The microphone's level, or while reading the playback's, from 0 to 1, already scaled
  /// for display.
  var level = 0.0
  /// The pill derives elapsed time from this.
  var startedAt: Date
  /// Holds the displayed time still while reading is paused.
  var pausedAt: Date?
  var pausedDuration: TimeInterval = 0
}
