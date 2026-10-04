import Foundation

/// One decoded stretch of speech.
struct WhisperSegment: Equatable {
  var text: String
  /// Seconds from the start of the audio that was decoded.
  var end: Double
}

/// What a Whisper session has settled and what it still shows provisionally.
///
/// Whisper decodes a window of audio at once, so each decode of the unsettled audio replaces the
/// last. A segment is committed only once it is settled, so committed text only grows. The audio
/// behind committed segments is then dropped by the caller, so a decode never covers more than
/// the unsettled part.
struct WhisperTranscript {
  /// How much of a decode to commit.
  enum Settle {
    /// The leading segments the previous decode also produced, with the same text. The last is
    /// never one of them, because it is the one still growing.
    case agreed
    /// Everything: a pause follows, the window bound is reached, or the dictation is over.
    case all
  }

  private(set) var committed = ""
  /// The segments of the latest decode that are not committed.
  private var pending: [WhisperSegment] = []

  var transcript: Transcript {
    Transcript(committed: committed, provisional: Self.text(of: pending))
  }

  /// Replaces the pending segments with `decoded`, committing those `settle` allows. Returns how
  /// many seconds of the decoded audio the committed segments cover, or nil when none were
  /// committed, so the caller can drop that audio.
  mutating func update(with decoded: [WhisperSegment], settle: Settle) -> Double? {
    let count =
      switch settle {
      case .agreed:
        min(zip(pending, decoded).prefix { $0.text == $1.text }.count, max(decoded.count - 1, 0))
      case .all: decoded.count
      }
    let settled = decoded.prefix(count)
    let text = Self.text(of: settled)
    if committed.isEmpty { committed = text } else if !text.isEmpty { committed += " " + text }
    pending = Array(decoded.dropFirst(count))
    return settled.last?.end
  }

  private static func text(of segments: some Sequence<WhisperSegment>) -> String {
    segments.map(\.text).joined(separator: " ")
  }
}
