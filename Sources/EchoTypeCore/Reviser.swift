import Foundation

/// Revises committed dictation while keeping the current utterance outside the model window.
public actor Reviser {
  public typealias Request = @Sendable (String) async throws -> String

  private let request: Request
  private let finalRequest: Request
  private var committed = ""
  private var revised = ""
  private var covered = 0
  private var attempted = 0
  private var working: Task<Void, Never>?
  private var finishing = false

  public nonisolated let updates: AsyncStream<Void>
  private nonisolated let publisher: AsyncStream<Void>.Continuation

  public init(request: @escaping Request, finalRequest: Request? = nil) {
    self.request = request
    self.finalRequest = finalRequest ?? request
    (updates, publisher) = AsyncStream.makeStream(of: Void.self)
  }

  /// Adds committed text without waiting for the network. Only one drain task makes requests.
  @discardableResult public func submit(committed: String) -> String {
    guard !finishing else { return shown }
    if committed.count > self.committed.count {
      self.committed = committed
      if working == nil { working = Task { await drain() } }
    }
    return shown
  }

  public var shown: String { Self.join(revised, String(committed.dropFirst(covered))) }

  /// Cancels the live call before asking for one last revision of the recent window.
  public func finish(committed: String) async -> String {
    finishing = true
    working?.cancel()
    await working?.value
    self.committed = committed
    await revise(committed: committed, using: finalRequest)
    publisher.finish()
    return shown
  }

  /// Stops revisions for a cancelled session or an outcome that cannot make a final call.
  public func stop() {
    finishing = true
    working?.cancel()
    publisher.finish()
  }

  private func drain() async {
    while !finishing && attempted < committed.count {
      let input = committed
      attempted = input.count
      await revise(committed: input, using: request)
    }
    working = nil
  }

  private func revise(committed input: String, using request: Request) async {
    let (head, tail) = Self.split(revised)
    let window = Self.join(tail, String(input.dropFirst(covered)))
    guard !window.isEmpty else { return }
    let result = try? await request(window)
    guard !Task.isCancelled, !finishing || input == committed else { return }
    let trimmed = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let accepted = !trimmed.isEmpty && Self.isFaithful(trimmed, to: window)
    // A failed or unfaithful call keeps the streamed words but still counts them as covered.
    // They stay in the recent tail for later windows, but an edit the model keeps making
    // cannot hold every later window open until the final call gets the whole dictation.
    revised = Self.join(head, accepted ? trimmed : window)
    covered = input.count
    if accepted { publisher.yield(()) }
  }

  private static func split(_ text: String) -> (String, String) {
    var starts = [text.startIndex]
    var index = text.startIndex
    while index < text.endIndex {
      let character = text[index]
      let next = text.index(after: index)
      if ".!?".contains(character), next < text.endIndex, text[next].isWhitespace {
        let start = text[next...].firstIndex(where: { !$0.isWhitespace }) ?? text.endIndex
        if start < text.endIndex { starts.append(start) }
      }
      index = next
    }
    let sentenceStart = starts.count > 1 ? starts[starts.count - 2] : text.startIndex
    // Short fragments can contain sentence punctuation without providing enough context.
    let words = text.split(whereSeparator: \.isWhitespace)
    let wordStart = words.count > 100 ? words[words.count - 100].startIndex : text.startIndex
    let wordSentenceStart = starts.last(where: { $0 <= wordStart }) ?? text.startIndex
    let tailStart = min(sentenceStart, wordSentenceStart)
    return (String(text[..<tailStart]).trimmingCharacters(in: .whitespaces), String(text[tailStart...]))
  }

  private static func join(_ head: String, _ tail: String) -> String {
    let tail = tail.trimmingCharacters(in: .whitespacesAndNewlines)
    if head.isEmpty { return tail }
    if tail.isEmpty { return head }
    return head + " " + tail
  }

  public static func isFaithful(_ revision: String, to input: String) -> Bool {
    func words(_ text: String) -> [String] {
      // Hyphens and dashes separate words, so dropping the stutter in "I-I'm" is a deletion.
      text.split(whereSeparator: { $0.isWhitespace || "-–—".contains($0) }).compactMap { raw in
        let word = raw.drop(while: isPunctuation).reversed().drop(while: isPunctuation)
          .reversed().map(String.init).joined().lowercased()
        return word.isEmpty ? nil : word
      }
    }
    let source = words(input)
    var position = 0
    for word in words(revision) {
      guard let match = source[position...].firstIndex(of: word) else { return false }
      position = match + 1
    }
    return true
  }

  private static func isPunctuation(_ character: Character) -> Bool {
    character.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
  }
}
