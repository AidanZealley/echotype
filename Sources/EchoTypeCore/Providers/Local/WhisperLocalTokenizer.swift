import Foundation
import NaturalLanguage
@preconcurrency import WhisperKit

/// WhisperKit 1.1.0 keeps its tokenizer wrapper initializer internal. This adapter uses its
/// public local factory and preserves the wrapper's special tokens and word splitting, without
/// entering ModelUtilities' catch-and-download path.
struct WhisperLocalTokenizer: WhisperTokenizer {
  private let tokenizer: TokenizerWrapper
  let specialTokens: SpecialTokens
  let allLanguageTokens: Set<Int>

  static func load(from folder: URL) async throws -> Self {
    try Self(tokenizer: await AutoTokenizerWrapper.from(modelFolder: folder))
  }

  private init(tokenizer: TokenizerWrapper) throws {
    self.tokenizer = tokenizer
    func token(_ text: String) throws -> Int {
      guard let id = tokenizer.convertTokenToId(text) else {
        throw WhisperError.tokenizerUnavailable()
      }
      return id
    }
    // Require the pinned vocabulary rather than silently substituting another model's tokens.
    specialTokens = try SpecialTokens(
      endToken: token("<|endoftext|>"), englishToken: token("<|en|>"),
      noSpeechToken: token("<|nospeech|>"), noTimestampsToken: token("<|notimestamps|>"),
      specialTokenBegin: token("<|endoftext|>"), startOfPreviousToken: token("<|startofprev|>"),
      startOfTranscriptToken: token("<|startoftranscript|>"), timeTokenBegin: token("<|0.00|>"),
      transcribeToken: token("<|transcribe|>"), translateToken: token("<|translate|>"),
      whitespaceToken: token(" "))
    let specialTokenBegin = specialTokens.specialTokenBegin
    allLanguageTokens = Set(Constants.languages.values.compactMap {
      tokenizer.convertTokenToId("<|\($0)|>")
    }.filter { $0 > specialTokenBegin })
  }

  func encode(text: String) -> [Int] { tokenizer.encode(text: text) }
  func decode(tokens: [Int]) -> String { tokenizer.decode(tokens: tokens) }
  func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
  func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }

  /// Match WhisperKit's Unicode grouping before space/punctuation splitting. Word timestamps
  /// are off for this candidate, but this still preserves the runtime's tokenizer contract.
  func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
    let decoded = decode(tokens: tokenIds.filter { $0 < specialTokens.specialTokenBegin })
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(decoded)
    let language = recognizer.dominantLanguage.flatMap {
      Locale(identifier: $0.rawValue).language.languageCode?.identifier
    }
    let subwords = splitOnUnicode(tokenIds)
    if ["zh", "ja", "th", "lo", "my", "yue"].contains(language) { return subwords }

    var words: [String] = []
    var wordTokens: [[Int]] = []
    for (word, tokens) in zip(subwords.words, subwords.wordTokens) {
      let special = tokens[0] >= specialTokens.specialTokenBegin
      let punctuation = UnicodeScalar(word.trimmingCharacters(in: .whitespaces))
        .map { CharacterSet.punctuationCharacters.contains($0) } ?? false
      if special || word.hasPrefix(" ") || punctuation || words.isEmpty {
        words.append(word)
        wordTokens.append(tokens)
      } else {
        words[words.count - 1] += word
        wordTokens[wordTokens.count - 1].append(contentsOf: tokens)
      }
    }
    return (words, wordTokens)
  }

  private func splitOnUnicode(_ tokens: [Int]) -> (words: [String], wordTokens: [[Int]]) {
    let fullText = decode(tokens: tokens)
    var words: [String] = []
    var wordTokens: [[Int]] = []
    var pending: [Int] = []
    for token in tokens {
      pending.append(token)
      let text = decode(tokens: pending)
      let replacementMatches: Bool
      if let replacement = text.range(of: "\u{fffd}") {
        replacementMatches = fullText[replacement] == "\u{fffd}"
      } else {
        replacementMatches = true
      }
      if replacementMatches {
        words.append(text)
        wordTokens.append(pending)
        pending = []
      }
    }
    return (words, wordTokens)
  }
}
