import Foundation

/// What happened during one dictation, for the Last Dictation window and its JSON export.
public struct DictationTrace: Codable, Equatable, Sendable {
  public var startedAt: Date
  public var endedAt: Date?
  public var cleanUp: Bool
  /// Each growth of committed text, in order.
  public var commits: [Commit]
  /// The revision requests `Reviser` made, in start order.
  public var revisions: [Revision]
  /// The final committed text before revision.
  public var streamed: String
  /// Available cleanup output, independent of whether a paste was attempted.
  public var finalText: String
  public var insertion: Insertion
  public var sending: Sending
  public var outcome: Outcome

  public init(
    startedAt: Date, endedAt: Date? = nil, cleanUp: Bool, commits: [Commit] = [],
    revisions: [Revision] = [], streamed: String = "", finalText: String = "",
    insertion: Insertion = .notAttempted, sending: Sending = .notRequested,
    outcome: Outcome = .nothing
  ) {
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.cleanUp = cleanUp
    self.commits = commits
    self.revisions = revisions
    self.streamed = streamed
    self.finalText = finalText
    self.insertion = insertion
    self.sending = sending
    self.outcome = outcome
  }

  public struct Commit: Codable, Equatable, Sendable {
    public var at: Date
    public var text: String

    public init(at: Date, text: String) {
      self.at = at
      self.text = text
    }
  }

  public struct Revision: Codable, Equatable, Sendable {
    public var at: Date
    public var isFinal: Bool
    public var window: String
    /// Nil when the request threw.
    public var reply: String?
    public var duration: TimeInterval
    public var result: Result
  }

  public enum Result: Codable, Equatable, Sendable {
    case accepted
    /// Accepted, but identical to the window.
    case unchanged
    /// Unfaithful: `word` is the first normalised reply word missing from the window.
    case rejected(word: String)
    /// The reply dropped a spoken EchoType reply request.
    case replyRequestRemoved
    case empty
    /// The thrown error, described.
    case failed(String)
    /// Cancelled at stop, or at finish for the live call.
    case cancelled
    /// A final reply for text that has since grown.
    case superseded
  }

  public enum DestinationLoss: String, Codable, Equatable, Sendable { case changed, unavailable }
  public enum Insertion: Codable, Equatable, Sendable {
    case notAttempted, attempted, cancelled
    case skipped(DestinationLoss)
  }
  public enum Sending: Codable, Equatable, Sendable {
    case notRequested, attempted
    case skipped(DestinationLoss)
  }

  public enum Outcome: Codable, Equatable, Sendable {
    case completed, nothing, cancelled
    case failed(String)
  }

  /// A streamed word marked against the final cleanup text.
  public struct Mark: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case kept, deleted
      case changed(revised: String)
    }

    /// The streamed form.
    public var word: String
    public var kind: Kind
    /// The index in `commits` of the commit that starts at this word, when a boundary falls
    /// before it. Nil for the first word and for words inside a commit.
    public var commit: Int?
  }

  /// The streamed words marked against the final cleanup text, using the word rule of
  /// `Reviser.isFaithful`. Each final word matches the next equal streamed word, so when
  /// a word repeats the walk may mark a different copy deleted than the model removed.
  public var marks: [Mark] {
    // Word index to the commit starting there. A commit with no words shares its start with
    // the next, which overwrites it.
    var commitStarts: [Int: Int] = [:]
    var count = 0
    for (index, commit) in commits.enumerated() {
      if count > 0 { commitStarts[count] = index }
      count += Prose.words(commit.text).count
    }
    var remaining = Prose.tokens(finalText)[...]
    return Prose.tokens(streamed).enumerated().map { index, token in
      let kind: Mark.Kind
      if let next = remaining.first, next.word == token.word {
        remaining.removeFirst()
        kind = next.raw == token.raw ? .kept : .changed(revised: next.raw)
      } else {
        kind = .deleted
      }
      return Mark(word: token.raw, kind: kind, commit: commitStarts[index])
    }
  }
}
