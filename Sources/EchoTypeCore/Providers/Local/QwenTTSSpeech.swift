import Foundation
import Synchronization

/// One Qwen3-TTS reading. MLX Audio Swift streams each utterance's audio as it generates, but its
/// stream buffers without bound, so this stream bounds it: utterance `n + 1` starts generating
/// only once utterance `n` is generated and the reader has pulled its first chunk. Production
/// stays at most one bounded utterance ahead, and a paused reader stops generation at the end of
/// the next utterance. Generated audio is handed out in chunks of at most 100 ms.
///
/// Readings share the model, which keeps codec state per generation, so they must not overlap:
/// the reader cancels one before starting the next, and a cancelled generation ends at its next
/// step. MLX Audio Swift gives no way to await that step, so a reading started at once can still
/// overlap it; workstream 3's handoff records this as a blocker to fix before productionising.
final class QwenTTSSpeech: SpeechStream {
  /// Generates one utterance off the main actor, yielding its audio as it is produced. Ending the
  /// iteration early, as cancelling does, stops generation at its next step.
  typealias Generate = @Sendable (String) -> any AsyncSequence<[Float], any Error>

  private typealias Waiter = CheckedContinuation<SpeechAudio?, any Error>

  private struct State {
    /// Audio not yet pulled.
    var chunks: [SpeechAudio] = []
    /// Chunks handed to the reader so far.
    var pulled = 0
    var finished = false
    /// Cancellation or a failure, which every later pull throws.
    var ending: (any Error)?
    var waiter: Waiter?
    /// The producer, waiting for the reader to pull past the chunk at this count.
    var producer: (after: Int, continuation: CheckedContinuation<Void, Never>)?

    /// Whether the reader has started the audio queued after `after` chunks, or has nothing
    /// left to play.
    func reached(_ after: Int) -> Bool { pulled > after || chunks.isEmpty || ending != nil }
  }

  private let utterances: [String]
  private let sampleRate: Int
  private let generate: Generate
  private let state = Mutex(State())
  private let production = Mutex<Task<Void, Never>?>(nil)

  init(utterances: [String], sampleRate: Int, generate: @escaping Generate) {
    self.utterances = utterances
    self.sampleRate = sampleRate
    self.generate = generate
    production.withLock { $0 = Task { await self.produce() } }
  }

  func next() async throws -> SpeechAudio? {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        state.withLock {
          precondition($0.waiter == nil, "SpeechStream has one consumer")
          $0.waiter = continuation
        }
        deliver()
      }
    } onCancel: {
      cancel()
    }
  }

  func cancel() {
    state.withLock { if $0.ending == nil { $0.ending = CancellationError() } }
    production.withLock { $0?.cancel() }
    deliver()
  }

  /// Generates each utterance in turn. The next starts once the reader has pulled the first
  /// chunk of the one before, or has played everything if it had none.
  private func produce() async {
    do {
      var start = 0
      for utterance in utterances {
        await reach(start)
        try Task.checkCancellation()
        start = state.withLock { $0.pulled + $0.chunks.count }
        for try await samples in generate(utterance) {
          append(samples)
        }
      }
      try Task.checkCancellation()
      state.withLock { $0.finished = true }
    } catch {
      state.withLock { state in
        if state.ending == nil { state.ending = error as? ProviderError ?? .failed(error.localizedDescription) }
      }
    }
    deliver()
  }

  private func reach(_ after: Int) async {
    await withCheckedContinuation { continuation in
      let ready = state.withLock { state in
        guard !state.reached(after) else { return true }
        state.producer = (after, continuation)
        return false
      }
      if ready { continuation.resume() }
    }
  }

  /// Queues generated samples as chunks of at most 100 ms.
  private func append(_ samples: [Float]) {
    let size = sampleRate / 10
    state.withLock { state in
      for start in stride(from: 0, to: samples.count, by: size) {
        let chunk = Array(samples[start..<min(start + size, samples.count)])
        state.chunks.append(SpeechAudio(sampleRate: sampleRate, samples: chunk))
      }
    }
    deliver()
  }

  /// Answers a waiting pull if it can, and lets the producer go on once the reader has reached
  /// what it waits for. Continuations resume outside the lock.
  private func deliver() {
    let (waiter, answer, producer) = state.withLock { state in
      var answer: Result<SpeechAudio?, any Error>?
      if state.waiter != nil {
        if let ending = state.ending {
          answer = .failure(ending)
        } else if !state.chunks.isEmpty {
          state.pulled += 1
          answer = .success(state.chunks.removeFirst())
        } else if state.finished {
          answer = .success(nil)
        }
      }
      let waiter = answer == nil ? nil : state.waiter
      if answer != nil { state.waiter = nil }
      var producer: CheckedContinuation<Void, Never>?
      if let waiting = state.producer, state.reached(waiting.after) {
        producer = waiting.continuation
        state.producer = nil
      }
      return (waiter, answer, producer)
    }
    producer?.resume()
    if let waiter, let answer { waiter.resume(with: answer) }
  }

  // MARK: Text

  /// The text as utterances of whole sentences, each up to `limit` Unicode scalars. Kokoro's
  /// splitter supplies the sentences, with any longer than 250 cut at a clause or a word; it also
  /// cuts the first sentence at 100, which joining here undoes when the limit allows.
  static func utterances(in text: String, limit: Int) -> [String] {
    var utterances: [String] = []
    for sentence in KokoroSpeech.utterances(in: text) {
      if let last = utterances.last, last.unicodeScalars.count + 1 + sentence.unicodeScalars.count <= limit {
        utterances[utterances.count - 1] = last + " " + sentence
      } else {
        utterances.append(sentence)
      }
    }
    return utterances
  }
}
