import Foundation

/// What happened during one dictation, for the debug window and its JSON export.
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
  /// What went in, or "" when nothing did.
  public var inserted: String
  public var outcome: Outcome

  public init(
    startedAt: Date, endedAt: Date? = nil, cleanUp: Bool, commits: [Commit] = [],
    revisions: [Revision] = [], streamed: String = "", inserted: String = "",
    outcome: Outcome = .nothing
  ) {
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.cleanUp = cleanUp
    self.commits = commits
    self.revisions = revisions
    self.streamed = streamed
    self.inserted = inserted
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

  public enum Outcome: Codable, Equatable, Sendable {
    case inserted, nothing, cancelled
    case failed(String)
  }

  /// A streamed word marked against the inserted text.
  public struct Mark: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case kept, deleted
      case changed(inserted: String)
    }

    /// The streamed form.
    public var word: String
    public var kind: Kind
    /// The index in `commits` of the commit that starts at this word, when a boundary falls
    /// before it. Nil for the first word and for words inside a commit.
    public var commit: Int?
  }

  /// The streamed words marked against the inserted text, using the word rule of
  /// `Reviser.isFaithful`. Each inserted word matches the next equal streamed word, so when
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
    var remaining = Prose.tokens(inserted)[...]
    return Prose.tokens(streamed).enumerated().map { index, token in
      let kind: Mark.Kind
      if let next = remaining.first, next.word == token.word {
        remaining.removeFirst()
        kind = next.raw == token.raw ? .kept : .changed(inserted: next.raw)
      } else {
        kind = .deleted
      }
      return Mark(word: token.raw, kind: kind, commit: commitStarts[index])
    }
  }
}
