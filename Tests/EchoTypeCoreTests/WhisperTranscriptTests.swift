import Testing

@testable import EchoTypeCore

@Suite struct WhisperTranscriptTests {
  private func segments(_ texts: String...) -> [WhisperSegment] {
    texts.enumerated().map { WhisperSegment(text: $1, end: Double($0 + 1)) }
  }

  @Test("Text commits once two decodes agree on it, never the segment still growing")
  func commitsOnAgreement() {
    var transcript = WhisperTranscript()
    #expect(transcript.update(with: segments("Hello there.", "How are"), settle: .agreed) == nil)
    #expect(transcript.transcript == Transcript(provisional: "Hello there. How are"))

    // The first segment is repeated and the second has grown: only the first is settled.
    #expect(transcript.update(with: segments("Hello there.", "How are you?"), settle: .agreed) == 1)
    #expect(transcript.transcript == Transcript(committed: "Hello there.", provisional: "How are you?"))

    // A segment that changed between decodes is not settled.
    #expect(transcript.update(with: segments("How are you today?", "I am"), settle: .agreed) == nil)
    #expect(transcript.transcript == Transcript(committed: "Hello there.", provisional: "How are you today? I am"))
  }

  @Test("A pause, forced window boundary or the end commits everything")
  func commitsOnDemand() {
    var transcript = WhisperTranscript()
    #expect(transcript.update(with: segments("One.", "Two.", "Thr"), settle: .all) == 3)
    #expect(transcript.transcript == Transcript(committed: "One. Two. Thr"))

    #expect(transcript.update(with: segments("Three."), settle: .all) == 1)
    #expect(transcript.update(with: segments("Four."), settle: .all) == 1)
    #expect(transcript.transcript == Transcript(committed: "One. Two. Thr Three. Four."))

    // Silence decodes to nothing and changes nothing.
    #expect(transcript.update(with: [], settle: .all) == nil)
    #expect(transcript.transcript == Transcript(committed: "One. Two. Thr Three. Four."))
  }
}
