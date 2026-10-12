import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

@Suite struct KokoroSpeechTests {
  @Test("Text splits into sentences, with a short first utterance and long sentences cut at a clause or word")
  func utterances() {
    #expect(
      KokoroSpeech.utterances(in: "Yesterday I read the report. Today I'll read the appendix!\n\nDone?")
        == ["Yesterday I read the report.", "Today I'll read the appendix!", "Done?"])

    let clause = String(repeating: "word ", count: 12) + "then, " + String(repeating: "more ", count: 20) + "end."
    let first = KokoroSpeech.utterances(in: clause)
    #expect(first[0].hasSuffix("then,") && first[0].unicodeScalars.count <= KokoroSpeech.firstUtteranceLimit)
    #expect(first.joined(separator: " ") == clause)

    let long = "Opening. " + String(repeating: "word ", count: 80) + "end."
    let later = KokoroSpeech.utterances(in: long)
    #expect(later.dropFirst().allSatisfy { $0.unicodeScalars.count <= KokoroSpeech.utteranceLimit })
    #expect(later.joined(separator: " ") == long)
  }

  @Test("Synthesis runs at most one utterance ahead of what has been pulled")
  func boundedReadAhead() async throws {
    let started = Mutex(0)
    let second = AsyncStream.makeStream(of: Void.self)
    let release = AsyncStream.makeStream(of: Void.self)
    let stream = KokoroSpeech(text: "One. Two. Three. Four.") { _ in
      if started.withLock({ $0 += 1; return $0 }) == 2 {
        second.continuation.yield()
        for await _ in release.stream { break }
      }
      return SpeechAudio(sampleRate: 1000, samples: [Float](repeating: 0, count: 300))
    }
    let first = try await stream.next()
    #expect(first?.samples.count == 100)
    // Taking the first chunk starts the second utterance. The rest of the first starts nothing.
    for await _ in second.stream { break }
    _ = try await stream.next(); _ = try await stream.next()
    #expect(started.withLock { $0 } == 2)
    release.continuation.finish()

    var chunks = 3
    while try await stream.next() != nil { chunks += 1 }
    #expect(chunks == 12)
    #expect(started.withLock { $0 } == 4)
  }

  @Test("Close joins synthesis even when the backend ignores cancellation")
  func closeJoinsSynthesis() async {
    let entered = AsyncStream.makeStream(of: Void.self)
    let release = Mutex<CheckedContinuation<Void, Never>?>(nil)
    let stopped = Mutex(false)
    let stream = KokoroSpeech(text: "One sentence.") { _ in
      await withCheckedContinuation { continuation in
        release.withLock { $0 = continuation }
        entered.continuation.yield()
      }
      stopped.withLock { $0 = true }
      return SpeechAudio(sampleRate: 1000, samples: [0])
    }
    let pull = Task { try? await stream.next() }
    for await _ in entered.stream { break }
    stream.cancel()
    _ = await pull.value
    let close = Task { await stream.waitForClose() }
    #expect(stopped.withLock { $0 } == false)
    release.withLock { $0?.resume(); $0 = nil }
    await close.value
    #expect(stopped.withLock { $0 })
  }

  @Test("Cancelling ends a pull that is waiting on synthesis")
  func cancelWhileSynthesising() async {
    let (started, start) = AsyncStream.makeStream(of: Void.self)
    let stream = KokoroSpeech(text: "One sentence.") { _ in
      start.yield()
      try await Task.sleep(for: .seconds(3600))
      return SpeechAudio(sampleRate: 1000, samples: [0])
    }
    let pull = Task { try await stream.next() }
    for await _ in started { break }
    stream.cancel()
    await #expect(throws: CancellationError.self) { try await pull.value }
    stream.cancel()
  }
}
