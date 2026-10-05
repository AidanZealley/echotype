import Foundation
import Synchronization
import Testing

@testable import EchoTypeCore

@Suite struct QwenTTSSpeechTests {
  @Test("Generation runs at most one utterance ahead of what has been pulled, and an utterance with no audio does not stall it")
  func boundedReadAhead() async throws {
    let started = Mutex(0)
    let stream = QwenTTSSpeech(utterances: ["One.", "Two.", "Silent.", "Four."], sampleRate: 1000) { utterance in
      started.withLock { $0 += 1 }
      return AsyncThrowingStream { continuation in
        if utterance != "Silent." {
          for _ in 0..<3 { continuation.yield([Float](repeating: 0, count: 300)) }
        }
        continuation.finish()
      }
    }
    let first = try await stream.next()
    #expect(first?.samples.count == 100)
    for _ in 0..<1000 { await Task.yield() }
    #expect(started.withLock { $0 } <= 2)

    var chunks = 1
    while try await stream.next() != nil { chunks += 1 }
    #expect(chunks == 27)
    #expect(started.withLock { $0 } == 4)
  }

  @Test("Cancelling ends a waiting pull and stops generation")
  func cancelWhileGenerating() async {
    let (stopped, stop) = AsyncStream.makeStream(of: Void.self)
    let stream = QwenTTSSpeech(utterances: ["One sentence."], sampleRate: 1000) { _ in
      AsyncThrowingStream<[Float], any Error> { continuation in
        continuation.onTermination = { _ in stop.yield() }
      }
    }
    let pull = Task { try await stream.next() }
    for _ in 0..<100 { await Task.yield() }
    stream.cancel()
    await #expect(throws: CancellationError.self) { try await pull.value }
    for await _ in stopped { break }
    stream.cancel()
  }
}
