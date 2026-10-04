import FluidAudio
import Foundation

/// What a Parakeet session has heard: the committed text, and the tokens decoded since, which are
/// not yet committed. Committed text only grows, because nothing but whole tokens leaves
/// `pending`, and only at its front. Unified's tokens are not rewritten once emitted, but keyterm
/// rescoring rewrites those it has not yet seen, so every pending token is shown as provisional.
struct ParakeetTranscript {
  private(set) var committed = ""
  private(set) var pending: [TokenTiming] = []

  var transcript: Transcript { Transcript(committed: committed, provisional: Self.text(of: pending[...])) }

  /// Tokens carry their own leading space, so the text of a run is just their pieces joined.
  private static func text(of tokens: ArraySlice<TokenTiming>) -> String {
    tokens.map(\.token).joined().trimmingCharacters(in: .whitespaces)
  }

  mutating func append(_ tokens: [TokenTiming]) {
    pending += tokens
  }

  /// Commits the first `count` pending tokens, as `text` when something else (the rescorer) has
  /// rewritten them. Runs of tokens are separate stretches of speech, so they are joined with a
  /// single space.
  mutating func commit(first count: Int, as text: String? = nil) {
    let run = (text?.trimmingCharacters(in: .whitespaces)) ?? Self.text(of: pending.prefix(count))
    pending.removeFirst(count)
    if committed.isEmpty { committed = run } else if !run.isEmpty { committed += " " + run }
  }

  /// How many leading tokens end before the last word, which may still be growing: the run that
  /// can be rescored without cutting a word in two. Nil while there is only one word.
  var settledCount: Int? {
    guard let lastWordStart = pending.lastIndex(where: { $0.token.hasPrefix(" ") }), lastWordStart > 0
    else { return nil }
    return lastWordStart
  }
}
