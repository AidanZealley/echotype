import Foundation

/// Decides whether dictated text ends by asking for a spoken reply, such as "reply with
/// EchoType". The rule is fixed words, so the decision needs no model call.
public enum ReplyRequest {
  private static let prepositions: Set = ["with", "through", "via", "using"]
  private static let verbs: Set = ["read", "reply", "respond", "speak", "say", "answer", "tell"]

  /// Whether the last sentence has the name directly after a preposition, and a speaking verb.
  public static func matches(_ committed: String) -> Bool {
    guard let start = Prose.sentenceStarts(committed).last else { return false }
    let words = Prose.words(committed[start...])
    let hasName = words.indices.contains { index in
      guard prepositions.contains(words[index]) else { return false }
      let name = words.dropFirst(index + 1)
      return name.first == "echotype" || name.starts(with: ["echo", "type"])
    }
    return hasName && !verbs.isDisjoint(with: words)
  }
}
