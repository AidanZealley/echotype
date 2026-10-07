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
