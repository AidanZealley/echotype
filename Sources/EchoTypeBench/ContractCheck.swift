import EchoTypeCore

/// Checks one transcription session's events against the `LiveTranscriber` contract, collecting
/// every violation as a sentence for the run's record. Pure, so the rules can be tested without
/// a provider.
struct ContractCheck {
  private(set) var violations: [String] = []
  private var eventCount = 0
  private var readyCount = 0
  private var committed = ""
  private(set) var sawFinished = false

  mutating func observe(_ event: TranscriptionEvent) {
    eventCount += 1
    switch event {
    case .ready:
      readyCount += 1
      if eventCount > 1 { violations.append(".ready was not the first event") }
      if readyCount > 1 { violations.append(".ready arrived more than once") }
    case .transcript(let transcript):
      if readyCount == 0 { violations.append(".transcript arrived before .ready") }
      // "Only grows at its end": the earlier committed text must be a prefix of the new.
      if !transcript.committed.hasPrefix(committed) {
        violations.append("committed text did not only grow: \"\(committed)\" became \"\(transcript.committed)\"")
      }
      committed = transcript.committed
    case .speech:
      if readyCount == 0 { violations.append(".speech arrived before .ready") }
    case .finished:
      sawFinished = true
    }
  }

  /// Called when the stream has ended after `finish()`.
  mutating func finishWasCalled() {
    if !sawFinished { violations.append("no .finished after finish()") }
  }
}

/// Checks one reading's `SpeechStream` against its contract, collecting every violation as a
/// sentence for the run's record. Pure, like `ContractCheck`.
struct SpeechContractCheck {
  /// The longest chunk the contract allows, in seconds.
  static let maximumChunkSeconds = 0.1
  /// How long `cancel()` may leave a pending `next()` running, in seconds.
  static let maximumCancelSeconds = 1.0

  private(set) var violations: [String] = []
  private var sampleRate: Int?
  private var chunkCount = 0

  mutating func observe(_ chunk: SpeechAudio) {
    chunkCount += 1
    if let sampleRate, chunk.sampleRate != sampleRate {
      violations.append("sample rate changed from \(sampleRate) to \(chunk.sampleRate) Hz")
    }
    sampleRate = chunk.sampleRate
    let seconds = Double(chunk.samples.count) / Double(chunk.sampleRate)
    if seconds > Self.maximumChunkSeconds {
      violations.append("chunk \(chunkCount) was \(Int((seconds * 1000).rounded())) ms")
    }
  }

  /// Called when the stream returned nil, for the text that was spoken.
  mutating func streamEnded(spoken text: String) {
    if chunkCount == 0, !text.isEmpty { violations.append("the stream ended without audio") }
  }

  mutating func threw(_ error: any Error) { violations.append("next() threw: \(error)") }

  /// Called with how long `next()` took to end after `cancel()`, nil if it never did.
  mutating func cancellationTook(seconds: Double?) {
    if (seconds ?? .infinity) > Self.maximumCancelSeconds {
      violations.append("cancel() did not end next() within \(Int(Self.maximumCancelSeconds)) s")
    }
  }
}
