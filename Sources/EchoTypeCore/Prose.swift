import Foundation

/// The word and sentence rules shared by `Reviser` and `ReplyRequest`.
enum Prose {
  /// Lowercased words with punctuation stripped at their edges. Hyphens and dashes separate
  /// words, so dropping the stutter in "I-I'm" is a deletion.
  static func words(_ text: some StringProtocol) -> [String] {
    text.split(whereSeparator: { $0.isWhitespace || "-–—".contains($0) }).compactMap { raw in
      let word = raw.drop(while: isPunctuation).reversed().drop(while: isPunctuation)
        .reversed().map(String.init).joined().lowercased()
      return word.isEmpty ? nil : word
    }
  }

  /// Where each sentence begins. Sentences end at `.`, `!` or `?` followed by whitespace.
  static func sentenceStarts(_ text: String) -> [String.Index] {
    var starts = [text.startIndex]
    var index = text.startIndex
    while index < text.endIndex {
      let character = text[index]
      let next = text.index(after: index)
      if ".!?".contains(character), next < text.endIndex, text[next].isWhitespace {
        let start = text[next...].firstIndex(where: { !$0.isWhitespace }) ?? text.endIndex
        if start < text.endIndex { starts.append(start) }
      }
      index = next
    }
    return starts
  }

  private static func isPunctuation(_ character: Character) -> Bool {
    character.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
  }
}
