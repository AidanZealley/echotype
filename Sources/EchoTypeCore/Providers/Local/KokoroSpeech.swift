import Foundation
import Synchronization

/// One Kokoro reading. The text is split into short utterances up front; each is synthesised
/// whole, then handed out in chunks of at most 100 ms. The next utterance starts synthesising when
/// the reader takes the first chunk of the current one, so production stays at most one utterance
/// ahead of what has been pulled and a paused reader stops synthesis.
final class KokoroSpeech: SpeechStream {
  /// Synthesises one utterance off the main actor. Kokoro's model runs on its own actor.
  typealias Synthesize = @Sendable (String) async throws -> SpeechAudio

  /// The first utterance is cut shorter than the rest, at a clause or a word, so first audio does
  /// not wait for a long opening sentence. See the workstream 2 handoff for how it was chosen.
  static let firstUtteranceLimit = 100
  /// Later utterances are whole sentences up to this many scalars, which keeps each well inside
  /// Kokoro's 510-phoneme input and 2000-frame output at the slowest speed.
  static let utteranceLimit = 250

  private typealias Waiter = CheckedContinuation<SpeechAudio?, any Error>

  private struct State {
    /// Utterances not yet synthesising.
    var pending: ArraySlice<String>
    /// The utterance being handed out, and how much of it has been.
    var audio = SpeechAudio(sampleRate: 0, samples: [])
    var offset = 0
    /// The next utterance's synthesis while it runs, then its result until the reader needs it.
    var synthesis: Task<Void, Never>?
    var synthesized: Result<SpeechAudio, any Error>?
    var waiter: Waiter?
    /// Cancellation or a failure, which every later pull throws.
    var ending: (any Error)?
  }

  private let synthesize: Synthesize
  private let state: Mutex<State>

  init(text: String, synthesize: @escaping Synthesize) {
    self.synthesize = synthesize
    state = Mutex(State(pending: Self.utterances(in: text)[...]))
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
    state.withLock { state in
      if state.ending == nil { state.ending = CancellationError() }
      state.pending = []
      state.synthesis?.cancel()
    }
    deliver()
  }

  func waitForClose() async {
    cancel()
    let synthesis = state.withLock { $0.synthesis }
    await synthesis?.value
  }

  /// Answers a waiting pull if it can, starting synthesis when the reader needs more audio.
  private func deliver() {
    let answer = state.withLock { state -> (Waiter, Result<SpeechAudio?, any Error>)? in
      guard let waiter = state.waiter else { return nil }
      while true {
        if let ending = state.ending {
          state.waiter = nil
          return (waiter, .failure(ending))
        }
        if state.offset < state.audio.samples.count {
          let end = min(state.offset + state.audio.sampleRate / 10, state.audio.samples.count)
          defer { state.offset = end }
          state.waiter = nil
          let samples = Array(state.audio.samples[state.offset..<end])
          return (waiter, .success(SpeechAudio(sampleRate: state.audio.sampleRate, samples: samples)))
        }
        if let synthesized = state.synthesized {
          state.synthesized = nil
          switch synthesized {
          case .success(let audio):
            state.audio = audio
            state.offset = 0
            startSynthesis(&state)
          case .failure(let error):
            state.ending = error as? ProviderError ?? .failed(error.localizedDescription)
          }
          continue
        }
        if state.synthesis != nil { return nil }
        guard !state.pending.isEmpty else {
          state.waiter = nil
          return (waiter, .success(nil))
        }
        startSynthesis(&state)
        return nil
      }
    }
    if let (waiter, result) = answer { waiter.resume(with: result) }
  }

  /// Starts synthesising the next pending utterance, if there is one.
  private func startSynthesis(_ state: inout State) {
    guard let utterance = state.pending.popFirst() else { return }
    state.synthesis = Task {
      let result: Result<SpeechAudio, any Error>
      do {
        result = .success(try await synthesize(utterance))
      } catch {
        result = .failure(error)
      }
      self.state.withLock {
        $0.synthesis = nil
        if $0.ending == nil { $0.synthesized = result }
      }
      deliver()
    }
  }

  // MARK: Text

  /// The text as utterances: one per sentence, with a sentence longer than its limit cut at the
  /// last clause punctuation within the limit, else the last space, else the limit itself. The
  /// first utterance has the shorter `firstUtteranceLimit`.
  static func utterances(in text: String) -> [String] {
    var sentences: [Substring] = []
    text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, range, _, _ in
      sentences.append(text[range])
    }
    var utterances: [String] = []
    for sentence in sentences {
      var rest = sentence.trimmingCharacters(in: .whitespacesAndNewlines)[...]
      while !rest.isEmpty {
        let limit = utterances.isEmpty ? firstUtteranceLimit : utteranceLimit
        let split = cut(rest, limit: limit)
        utterances.append(String(rest[..<split]).trimmingCharacters(in: .whitespaces))
        rest = rest[split...].drop { $0.isWhitespace }
      }
    }
    return utterances
  }

  /// Where to end an utterance taken from the start of `text`.
  private static func cut(_ text: Substring, limit: Int) -> String.Index {
    let scalars = text.unicodeScalars
    guard let bound = scalars.index(scalars.startIndex, offsetBy: limit, limitedBy: scalars.endIndex),
      bound != scalars.endIndex
    else { return text.endIndex }
    let head = scalars[..<bound]
    let clause = head.indices.last { index in
      ",;:".unicodeScalars.contains(head[index]) && scalars.index(after: index) < bound
        && scalars[scalars.index(after: index)].properties.isWhitespace
    }
    if let clause { return scalars.index(after: clause) }
    if let space = head.lastIndex(where: { $0.properties.isWhitespace }) { return space }
    return bound
  }
}
