import Testing

@testable import EchoTypeBench

private func wordErrors(_ reference: String, _ hypothesis: String) -> Alignment {
  let score = score(id: "x", finalText: hypothesis, reference: reference, keyterms: [])
  return score.words
}

@Test("Substitutions, deletions and insertions are counted and located")
func alignmentCountsEachKindOfError() {
  let substitution = wordErrors("the cat sat", "the hat sat")
  #expect((substitution.substitutions, substitution.deletions, substitution.insertions) == (1, 0, 0))
  #expect(substitution.mismatches.map { "\($0.reference!)>\($0.hypothesis!)" } == ["cat>hat"])

  let insertion = wordErrors("the cat", "the big cat")
  #expect((insertion.substitutions, insertion.deletions, insertion.insertions) == (0, 0, 1))
  #expect(insertion.mismatches.first?.reference == nil)

  let deletion = wordErrors("the big cat", "the cat")
  #expect((deletion.substitutions, deletion.deletions, deletion.insertions) == (0, 1, 0))
  #expect(deletion.mismatches.first?.hypothesis == nil)
}

@Test("Words ignore case and punctuation but formatted tokens do not")
func formattedScoringKeepsCaseAndPunctuation() {
  let result = score(id: "x", finalText: "Is it core ML", reference: "Is it CoreML?", keyterms: [])
  #expect(result.words.errors == 2)  // "coreml" became "core" and "ml"
  #expect(result.formatted.errors == 2)  // "CoreML?" became "core" and "ML", with "it" matching

  let punctuation = score(id: "x", finalText: "Is it ok", reference: "Is it ok?", keyterms: [])
  #expect(punctuation.words.errors == 0)
  #expect(punctuation.formatted.errors == 1)
}

@Test("An empty reference has no rate, and any words are a hallucination")
func silenceHallucination() {
  let quiet = score(id: "silence", finalText: "", reference: "", keyterms: [])
  #expect(quiet.referenceWords == 0 && !quiet.hallucinated)

  let heard = score(id: "silence", finalText: "thank you", reference: "", keyterms: [])
  #expect(heard.words.insertions == 2 && heard.hallucinated)
}

@Test("Keyterms match as word sequences, so a split or misspelling misses")
func keytermMatching() {
  let keyterms = ["Core ML", "Zustand"]
  let reference = "I use Core ML and Zustand with Core ML"

  let exact = score(id: "x", finalText: "i use core ml and zustand with core ml", reference: reference, keyterms: keyterms)
  #expect((exact.keytermHits, exact.keytermTotal, exact.missedKeyterms) == (3, 3, []))

  let wrong = score(id: "x", finalText: "I use CoreML and Sustand with Core ML", reference: reference, keyterms: keyterms)
  #expect((wrong.keytermHits, wrong.keytermTotal) == (1, 3))
  #expect(wrong.missedKeyterms == ["Core ML", "Zustand"])
}

@Test("Cleanup scores the words a reply deleted against those the expected cleanup deletes")
func cleanupWrongDeletionsAndMissedEdits() {
  let input = "I think the the problem is that we we never close it"
  let expected = "I think the problem is that we never close it"

  // Removed one repeat and a good word, left the other repeat.
  let reply = scoreCleanup(
    id: "x", input: input, finalText: "I think the problem is that we we close it", expected: expected, ambiguous: false)
  #expect(reply.wrongDeletions == ["never"])
  #expect(reply.missedEdits == ["we"])
  #expect(!reply.exact && !reply.notADeletion)

  // Case and punctuation do not matter.
  let exact = scoreCleanup(
    id: "x", input: input, finalText: "I think the problem is that we never close it.", expected: expected, ambiguous: false)
  #expect(exact.exact && exact.wrongDeletions.isEmpty && exact.missedEdits.isEmpty)
}

@Test("A reply that adds words is not a deletion and gets no word-level scores")
func cleanupNotADeletion() {
  let added = scoreCleanup(
    id: "x", input: "the cat sat", finalText: "the big cat sat", expected: "the cat sat", ambiguous: false)
  #expect(added.notADeletion && !added.exact)
  #expect(added.wrongDeletions.isEmpty && added.missedEdits.isEmpty)
}
