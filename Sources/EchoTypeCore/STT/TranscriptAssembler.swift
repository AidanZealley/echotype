import Foundation

/// Turns an ordered stream of server events into the text that will be inserted.
///
/// The final text is every `speech_final` segment in order, plus whatever trailing partial the
/// `finalize` resolves into, whether that arrives as one more `speech_final` segment or is
/// still interim when `transcript.done` closes the session. Interim text can be rewritten by a
/// later partial, so it is held separately and contributes to `text` only at `done`.
public struct TranscriptAssembler: Equatable, Sendable {
  public init() {}

  /// The committed transcript: the only text that may be inserted.
  public private(set) var text: String = ""

  /// The trailing partial, provisional until a `speech_final` supersedes it. For display only,
  /// which is what the overlay renders dimmed.
  public private(set) var interim: String = ""

  public mutating func apply(_ event: STTEvent) {
    switch event {
    case .partial(let partial):
      applyPartial(partial)
    case .done:
      // `finalize` may resolve the tail with `is_final` alone rather than a further
      // `speech_final`. Committing here recovers that last sentence, and is a no-op when a
      // `speech_final` already cleared the interim.
      commit(interim)
    case .created, .error:
      break
    }
  }

  private mutating func applyPartial(_ partial: STTEvent.Partial) {
    let segment = partial.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard partial.speechFinal else {
      interim = segment
      return
    }
    commit(segment)
  }

  private mutating func commit(_ segment: String) {
    interim = ""
    guard !segment.isEmpty else { return }
    // Segments are separate utterances, so they are joined with a single space rather than run
    // together. Nothing is added at either end of the result.
    text = text.isEmpty ? segment : text + " " + segment
  }
}
