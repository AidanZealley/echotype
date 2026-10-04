import FluidAudio
import Foundation
import Testing

@testable import EchoTypeCore

@Suite struct ParakeetTranscriptTests {
  private func tokens(_ pieces: String...) -> [TokenTiming] {
    pieces.enumerated().map {
      TokenTiming(token: $1, tokenId: $0, startTime: Double($0), endTime: Double($0) + 1, confidence: 1)
    }
  }

  @Test("Utterances commit one after another, joined by a space, and only ever grow")
  func commitsGrow() {
    var transcript = ParakeetTranscript()
    transcript.append(tokens(" Hello", " world", "."))
    #expect(transcript.transcript == Transcript(provisional: "Hello world."))

    transcript.commit(first: transcript.pending.count)
    #expect(transcript.transcript == Transcript(committed: "Hello world."))

    transcript.append(tokens(" Second", " one"))
    #expect(transcript.transcript == Transcript(committed: "Hello world.", provisional: "Second one"))
    transcript.commit(first: transcript.pending.count)
    #expect(transcript.transcript == Transcript(committed: "Hello world. Second one"))
  }

  @Test("A segment holds back the word still growing, and commits the rescored words")
  func segmentsStopAtWordBoundaries() throws {
    var transcript = ParakeetTranscript()
    transcript.append(tokens(" Echo"))
    #expect(transcript.settledCount == nil)

    transcript.append(tokens(" Ty", "pe", " is", " gre", "at"))
    let count = try #require(transcript.settledCount)
    #expect(count == 4)  // " gre" and "at" are the last word.

    transcript.commit(first: count, as: "EchoType is")
    #expect(transcript.transcript == Transcript(committed: "EchoType is", provisional: "great"))
  }

  @Test("PCM becomes samples in -1...1, dropping a trailing odd byte")
  func pcmSamples() {
    let pcm = Data([0x00, 0x00, 0x00, 0x40, 0x00, 0x80, 0xFF, 0x7F, 0x01])
    #expect(ParakeetTranscriber.samples(from: pcm) == [0, 0.5, -1, 32767 / 32768])
  }
}
