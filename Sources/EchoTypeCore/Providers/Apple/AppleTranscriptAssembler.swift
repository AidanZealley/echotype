import Foundation

extension Apple {
  /// Turns `SpeechTranscriber` results into the neutral transcript.
  ///
  /// A volatile result rewrites the segment in progress, so it replaces the provisional text. A
  /// final result settles a segment that no later result repeats, so it appends to the
  /// committed text. Final segments carry their own leading whitespace. A final result does not
  /// mark the end of an utterance, so the utterance stays empty.
  struct TranscriptAssembler: Equatable, Sendable {
    private(set) var transcript = Transcript()

    /// The events one result produces: the new transcript, then `.speech` if anything was heard.
    mutating func apply(text: String, isFinal: Bool) -> [TranscriptionEvent] {
      if isFinal {
        transcript.committed += transcript.committed.isEmpty ? Self.trimmedStart(text) : text
        transcript.provisional = ""
      } else {
        transcript.provisional = text.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      // A paired `SpeechDetector` reported nothing in testing, so recognised text is the
      // evidence.
      let heard = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return [.transcript(transcript)] + (heard ? [.speech] : [])
    }

    /// What a failure of analysis ends the events with: nil to finish normally, or the error
    /// to throw. Finishing a session that recognised nothing makes the framework reject the
    /// recognition, which is an empty transcript rather than a failure.
    func ending(after error: any Error, finishing: Bool) -> (any Error)? {
      if error is CancellationError { return error }
      if finishing && transcript.committed.isEmpty && transcript.provisional.isEmpty
        && Self.isRejection(error)
      { return nil }
      return ProviderError.failed(error.localizedDescription)
    }

    /// Speech's `RecogRejected`, observed as `SFSpeechErrorDomain` code 1.
    static func isRejection(_ error: any Error) -> Bool {
      let error = error as NSError
      return error.domain == "SFSpeechErrorDomain" && error.code == 1
    }

    private static func trimmedStart(_ text: String) -> String {
      String(text.drop { $0.isWhitespace })
    }
  }
}
