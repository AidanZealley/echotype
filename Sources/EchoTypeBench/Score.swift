import EchoTypeCore

/// The edits that turn a reference into a hypothesis, found by word-level Levenshtein distance.
struct Alignment {
  var substitutions = 0
  var deletions = 0
  var insertions = 0
  /// Where the two differ, in order. A nil side is a missing word: a deletion has no hypothesis
  /// word and an insertion no reference word.
  var mismatches: [(reference: String?, hypothesis: String?)] = []

  var errors: Int { substitutions + deletions + insertions }
}

func align(_ reference: [String], _ hypothesis: [String]) -> Alignment {
  // distance[i][j]: edits to turn the first i reference words into the first j hypothesis words.
  var distance = Array(repeating: Array(repeating: 0, count: hypothesis.count + 1), count: reference.count + 1)
  for i in 0...reference.count { distance[i][0] = i }
  for j in 0...hypothesis.count { distance[0][j] = j }
  for i in stride(from: 1, through: reference.count, by: 1) {
    for j in stride(from: 1, through: hypothesis.count, by: 1) {
      let swap = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
      distance[i][j] = min(distance[i - 1][j - 1] + swap, distance[i - 1][j] + 1, distance[i][j - 1] + 1)
    }
  }

  // Walk back from the end, preferring a match or substitution when the costs tie.
  var alignment = Alignment()
  var i = reference.count
  var j = hypothesis.count
  while i > 0 || j > 0 {
    if i > 0, j > 0, distance[i][j] == distance[i - 1][j - 1] + (reference[i - 1] == hypothesis[j - 1] ? 0 : 1) {
      if reference[i - 1] != hypothesis[j - 1] {
        alignment.substitutions += 1
        alignment.mismatches.append((reference[i - 1], hypothesis[j - 1]))
      }
      i -= 1
      j -= 1
    } else if i > 0, distance[i][j] == distance[i - 1][j] + 1 {
      alignment.deletions += 1
      alignment.mismatches.append((reference[i - 1], nil))
      i -= 1
    } else {
      alignment.insertions += 1
      alignment.mismatches.append((nil, hypothesis[j - 1]))
      j -= 1
    }
  }
  alignment.mismatches.reverse()
  return alignment
}

/// How one sample's final text compares with its reviewed reference.
struct SampleScore {
  let id: String
  /// Over `Prose.words`: case and punctuation do not count.
  let words: Alignment
  let referenceWords: Int
  /// Over whitespace-separated tokens as written, so "Core ML" vs "CoreML", case, digits and
  /// punctuation all count. The reference's formatting is the gold standard.
  let formatted: Alignment
  let referenceTokens: Int
  let keytermHits: Int
  let keytermTotal: Int
  let missedKeyterms: [String]
}

/// With an empty reference (silence) there is no word error rate, and any word is a hallucination.
extension SampleScore {
  var hallucinated: Bool { referenceWords == 0 && words.insertions > 0 }
}

func score(id: String, finalText: String, reference: String, keyterms: [String]) -> SampleScore {
  let referenceWords = Prose.words(reference)
  let hypothesisWords = Prose.words(finalText)
  let referenceTokens = reference.split(whereSeparator: \.isWhitespace).map(String.init)
  let hypothesisTokens = finalText.split(whereSeparator: \.isWhitespace).map(String.init)

  var hits = 0
  var total = 0
  var missed: [String] = []
  for keyterm in keyterms {
    let term = Prose.words(keyterm)
    let expected = occurrences(of: term, in: referenceWords)
    let found = min(expected, occurrences(of: term, in: hypothesisWords))
    hits += found
    total += expected
    if found < expected { missed.append(keyterm) }
  }
  return SampleScore(
    id: id, words: align(referenceWords, hypothesisWords), referenceWords: referenceWords.count,
    formatted: align(referenceTokens, hypothesisTokens), referenceTokens: referenceTokens.count,
    keytermHits: hits, keytermTotal: total, missedKeyterms: missed)
}

/// How often `term`, as a run of consecutive words, appears in `words`.
func occurrences(of term: [String], in words: [String]) -> Int {
  guard !term.isEmpty, words.count >= term.count else { return 0 }
  return (0...(words.count - term.count)).filter { Array(words[$0..<($0 + term.count)]) == term }.count
}

// MARK: Cleanup

/// The positions in `input` that were deleted to leave `kept`, matching each kept word to its
/// earliest remaining copy. Nil when `kept` is not a subsequence of `input`. A repeated word
/// may therefore be charged to a different copy than the model removed, which is harmless
/// here because expected and reply are aligned the same way.
func deletedIndices(from input: [String], leaving kept: [String]) -> Set<Int>? {
  var deleted = Set(input.indices)
  var position = 0
  for word in kept {
    guard let match = input[position...].firstIndex(of: word) else { return nil }
    deleted.remove(match)
    position = match + 1
  }
  return deleted
}

/// How one cleanup sample's final text compares with its expected cleanup, over `Prose.words`.
struct CleanupScore {
  let id: String
  /// More than one edit is reasonable, so the numbers are shown but left out of totals.
  let ambiguous: Bool
  let exact: Bool
  /// Input words the reply deleted that the expected cleanup kept.
  let wrongDeletions: [String]
  /// Input words the expected cleanup deleted that the reply kept.
  let missedEdits: [String]
  /// The reply added or reordered words, so it cannot be compared as a deletion.
  let notADeletion: Bool
}

func scoreCleanup(id: String, input: String, finalText: String, expected: String, ambiguous: Bool) -> CleanupScore {
  let words = Prose.words(input)
  let reply = Prose.words(finalText)
  let target = Prose.words(expected)
  let expectedDeleted = deletedIndices(from: words, leaving: target) ?? []
  guard let replyDeleted = deletedIndices(from: words, leaving: reply) else {
    return CleanupScore(id: id, ambiguous: ambiguous, exact: false, wrongDeletions: [], missedEdits: [], notADeletion: true)
  }
  return CleanupScore(
    id: id, ambiguous: ambiguous, exact: reply == target,
    wrongDeletions: replyDeleted.subtracting(expectedDeleted).sorted().map { words[$0] },
    missedEdits: expectedDeleted.subtracting(replyDeleted).sorted().map { words[$0] },
    notADeletion: false)
}
