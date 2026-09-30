import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ReviserTests {
  @Test("Only words from the input can survive a revision")
  func revisionFaithfulness() {
    #expect(Reviser.isFaithful("We should ship the settings window today.", to: "We should ship. The settings window today."))
    #expect(Reviser.isFaithful("Let's meet at 4pm.", to: "Let's meet at 3, no, 4pm."))
    #expect(Reviser.isFaithful("Hello, world!", to: "hello world"))
    #expect(Reviser.isFaithful("I'm never sure why.", to: "I-I'm never sure why."))
    #expect(!Reviser.isFaithful("We should now ship", to: "We should ship"))
    #expect(!Reviser.isFaithful("We must ship", to: "We should ship"))
    #expect(!Reviser.isFaithful("Ship we should", to: "We should ship"))
  }

  @Test("A revision that drops a reply request is rejected")
  func revisionKeepsReplyRequest() async {
    let streamed = "Check the build. Reply with EchoType."
    let calls = RevisionCalls(replies: ["Check the build."])
    let reviser = Reviser(request: { try await calls.answer($0) })
    let text = await reviser.finish(committed: streamed)
    #expect(text == streamed)
    #expect(ReplyRequest.matches(text))
  }

  @Test("The 50-word window includes its whole starting sentence")
  func revisionWindowKeepsRecentWords() async {
    let words = (1...55).map { "word\($0)" }
    let recentSentence = words.joined(separator: " ") + "."
    let first = "Old. " + recentSentence + " Wait. No."
    let calls = RevisionCalls()
    let reviser = Reviser(request: { await calls.record($0); return $0 })
    var updates = reviser.updates.makeAsyncIterator()
    _ = await reviser.submit(committed: first)
    _ = await updates.next()
    _ = await reviser.submit(committed: first + " Use the second one.")
    _ = await updates.next()
    let inputs = await calls.all
    #expect(inputs == [first, recentSentence + " Wait. No. Use the second one."])
    await reviser.stop()
  }

  @Test("Two long sentences stay together even when they exceed 50 words")
  func revisionWindowKeepsSentences() async {
    let longSentence = (1...60).map { "word\($0)" }.joined(separator: " ") + "."
    let first = "First. " + longSentence + " Third."
    let calls = RevisionCalls()
    let reviser = Reviser(request: { await calls.record($0); return $0 })
    var updates = reviser.updates.makeAsyncIterator()
    _ = await reviser.submit(committed: first)
    _ = await updates.next()
    _ = await reviser.submit(committed: first + " Fourth.")
    _ = await updates.next()
    #expect(await calls.all == [first, longSentence + " Third. Fourth."])
    await reviser.stop()
  }

  @Test("Commits arriving during a call join the next request")
  func revisionSingleFlight() async {
    let calls = RevisionGate()
    defer { calls.close() }
    let reviser = Reviser(request: { try await calls.request($0) })
    _ = await reviser.submit(committed: "One.")
    #expect(await calls.next() == "One.")
    _ = await reviser.submit(committed: "One. Two.")
    _ = await reviser.submit(committed: "One. Two. Three.")
    await calls.reply("One.")
    let nextInput = await calls.next()
    #expect(nextInput == "One. Two. Three.")
    await calls.reply("One. Two. Three.")
    var updates = reviser.updates.makeAsyncIterator()
    _ = await updates.next()
    _ = await updates.next()
    #expect(await reviser.shown == "One. Two. Three.")
    await reviser.stop()
  }

  @Test("An unfaithful call keeps streamed text for a later window")
  func revisionFallback() async {
    let calls = RevisionGate()
    defer { calls.close() }
    let reviser = Reviser(request: { try await calls.request($0) })
    var updates = reviser.updates.makeAsyncIterator()
    _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm.")
    #expect(await calls.next() == "Let's meet at 3, no, 4pm.")
    _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm. Thanks.")
    await calls.reply("Unexpected words")
    // Starting the next window proves the rejected reply has been applied.
    #expect(await calls.next() == "Let's meet at 3, no, 4pm. Thanks.")
    #expect(await reviser.shown == "Let's meet at 3, no, 4pm. Thanks.")
    await calls.reply("Let's meet at 4pm. Thanks.")
    _ = await updates.next()
    #expect(await reviser.shown == "Let's meet at 4pm. Thanks.")
    await reviser.stop()
  }

  @Test("A rejected stretch leaves later windows once it is out of the recent tail")
  func revisionRejectionAdvances() async {
    let recentSentence = (1...55).map { "word\($0)" }.joined(separator: " ") + "."
    let first = "Old. " + recentSentence + " Wait. No."
    let calls = RevisionGate()
    defer { calls.close() }
    let reviser = Reviser(request: { try await calls.request($0) })
    _ = await reviser.submit(committed: first)
    #expect(await calls.next() == first)
    _ = await reviser.submit(committed: first + " Use the second one.")
    await calls.reply("Unexpected words")
    #expect(await calls.next() == recentSentence + " Wait. No. Use the second one.")
    await calls.reply("Unexpected words")
    await reviser.stop()
  }

  @Test("Finish cancels a live call and uses the final reply")
  func revisionFinishCancelsLiveCall() async {
    let calls = RevisionGate()
    defer { calls.close() }
    let reviser = Reviser(
      request: { try await calls.request($0) },
      finalRequest: { _ in "Let's meet at 4pm." }
    )
    _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm.")
    #expect(await calls.next() == "Let's meet at 3, no, 4pm.")
    #expect(await reviser.finish(committed: "Let's meet at 3, no, 4pm.") == "Let's meet at 4pm.")
  }

  @Test("A failed final request inserts the available streamed text")
  func revisionFinalFallback() async {
    let reviser = Reviser(request: { _ in throw RevisionError.failed })
    #expect(await reviser.finish(committed: "Keep this.") == "Keep this.")
    #expect(await reviser.attempts.map(\.result) == [.failed("failed")])
  }

  @Test("Captured attempts record each request's result in start order")
  func revisionAttempts() async {
    let calls = RevisionCalls(replies: ["One", "One now two."])
    let reviser = Reviser(request: { try await calls.answer($0) })
    var updates = reviser.updates.makeAsyncIterator()
    _ = await reviser.submit(committed: "One.")
    _ = await updates.next()
    _ = await reviser.finish(committed: "One. Two.")

    let attempts = await reviser.attempts
    #expect(attempts.map(\.result) == [.accepted, .rejected(word: "now")])
    #expect(attempts.map(\.window) == ["One.", "One Two."])
    #expect(attempts.map(\.reply) == ["One", "One now two."])
    #expect(attempts.map(\.isFinal) == [false, true])
    #expect(attempts.allSatisfy { $0.duration >= 0 })
  }
}

private enum RevisionError: Error { case failed }

private actor RevisionCalls {
  private var inputs: [String] = []
  private let replies: [String]?

  init(replies: [String]? = nil) { self.replies = replies }
  var all: [String] { inputs }

  func record(_ input: String) {
    inputs.append(input)
  }

  func answer(_ input: String) throws -> String {
    record(input)
    return replies?[inputs.count - 1] ?? input
  }
}

private actor RevisionGate {
  private let inputs: AsyncStream<String>
  private nonisolated let inputPublisher: AsyncStream<String>.Continuation
  private var response: AsyncThrowingStream<String, any Error>.Continuation?

  init() {
    (inputs, inputPublisher) = AsyncStream.makeStream(of: String.self)
  }

  func request(_ input: String) async throws -> String {
    // Finishing the input stream permanently rejects requests after teardown.
    if case .terminated = inputPublisher.yield(input) { throw CancellationError() }
    let (stream, publisher) = AsyncThrowingStream.makeStream(of: String.self)
    response = publisher
    var replies = stream.makeAsyncIterator()
    guard let reply = try await replies.next() else { throw CancellationError() }
    return reply
  }

  func next() async -> String? {
    var requests = inputs.makeAsyncIterator()
    return await requests.next()
  }

  func reply(_ text: String) {
    response?.yield(text)
    response?.finish()
    response = nil
  }

  nonisolated func close() {
    inputPublisher.finish()
    Task { await self.cancelResponse() }
  }

  private func cancelResponse() {
    response?.finish(throwing: CancellationError())
    response = nil
  }
}
