import Foundation
import EchoTypeCore

/// Everything the overlay pill shows. The pill renders this value and nothing else, so the
/// `--hud-demo` loop and the dictation controller, for dictation and reading alike, drive it the
/// same way: build a `Pill` and hand it to `OverlayPanel.show(_:on:)`.
struct Pill: Equatable {
  enum Phase: Equatable {
    /// The microphone is opening. Anything said now is lost, so the pill looks not ready.
    case starting
    /// Recording continues while no conservative focused text-field identity is available.
    case selectInput
    case listening
    /// No speech for a while. The session is still open and waiting.
    case paused
    /// Committed; waiting for the final text.
    case transcribing
    /// Clipboard transaction owns completion; Escape no longer cancels.
    case inserting
    /// Reading the selection aloud. The level is the audio's as it plays.
    case readingStarting
    case reading
    /// Reading is paused by the user, with its place in the audio retained.
    case readingPaused
    /// A service the session needs is not ready yet, so it did not start. Shown inline beside
    /// an amber mark, with the provider's reason.
    case waiting(String)
    /// Shown inline in red.
    case error(String)
  }

  var phase: Phase
  /// Keeps the reading layout when a reading ends with an error.
  var isReading = false
  /// The microphone that actually opened for this dictation.
  var inputDevice: InputDevice?
  /// The provider's cleanup was not ready, so this dictation inserts unrevised text.
  var cleanupSkipped = false
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
  var canCommit = true
  var dictationHotkey: Settings.Hotkey = .optionD
}
