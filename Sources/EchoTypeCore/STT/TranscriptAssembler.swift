import Foundation

/// Turns an ordered stream of server events into the text that will be inserted, and the text
/// an overlay shows while the session runs.
///
/// Within one utterance the endpoint reports text in runs. A partial carries only the run since
/// the last `is_final` boundary; an `is_final` partial settles that run, rewritten into its final
/// form; and the `speech_final` partial that closes the utterance resends the whole utterance.
/// So settled runs are held only until `speech_final` replaces them, and joining them with the
/// `speech_final` text would duplicate every word.
public struct TranscriptAssembler: Equatable, Sendable {
  public init() {}

  /// The committed transcript: every `speech_final` segment in order, plus whatever tail
  /// `transcript.done` finds uncommitted. The only text that may be inserted.
  public private(set) var text: String = ""

  /// The run heard since the last `is_final` boundary. The model may still rewrite it, so it is
  /// shown dimmed and never inserted.
  public private(set) var provisional: String = ""

  /// Runs of the current utterance that arrived with `is_final`, joined. Settled, but not
  /// committed until the utterance's `speech_final` arrives.
  private var utterance: String = ""

  /// The committed transcript plus the settled runs of the current utterance, shown solid. The
  /// utterance's `speech_final` text replaces its runs wholesale, so this is not guaranteed to
  /// only grow at its end.
  public var settled: String { Self.join(text, utterance) }

  public mutating func apply(_ event: STTEvent) {
    switch event {
    case .partial(let partial):
      applyPartial(partial)
    case .done:
      // `finalize` may resolve the tail without a further `speech_final`. Committing the
      // current utterance here recovers that last sentence, and is a no-op when a
      // `speech_final` already closed it.
      commit(Self.join(utterance, provisional))
    case .created, .error:
      break
    }
  }

  private mutating func applyPartial(_ partial: STTEvent.Partial) {
    let run = partial.text.trimmingCharacters(in: .whitespacesAndNewlines)
    if partial.speechFinal {
      commit(run)
    } else if partial.isFinal {
      utterance = Self.join(utterance, run)
      provisional = ""
    } else {
      provisional = run
    }
  }

  private mutating func commit(_ segment: String) {
    text = Self.join(text, segment)
    utterance = ""
    provisional = ""
  }

  /// Segments and runs are separate stretches of speech, so they are joined with a single space
  /// rather than run together. Nothing is added at either end, and an empty side adds nothing.
  private static func join(_ head: String, _ tail: String) -> String {
    if head.isEmpty { return tail }
    if tail.isEmpty { return head }
    return head + " " + tail
  }
}
