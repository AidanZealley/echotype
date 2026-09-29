import EchoTypeCore
import Foundation
import Testing

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

@Test("The 100-word window includes its whole starting sentence")
func revisionWindowKeepsRecentWords() async {
  let words = (1...105).map { "word\($0)" }
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

@Test("Two long sentences stay together even when they exceed 100 words")
func revisionWindowKeepsSentences() async {
  let longSentence = (1...110).map { "word\($0)" }.joined(separator: " ") + "."
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

@Test("Failed and unfaithful calls keep streamed text for a later window")
func revisionFallback() async {
  let calls = RevisionCalls(replies: ["Unexpected words", "Let's meet at 4pm. Thanks."])
  let reviser = Reviser(request: { try await calls.answer($0) })
  _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm.")
  await calls.wait(for: 1)
  #expect(await reviser.shown == "Let's meet at 3, no, 4pm.")
  _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm. Thanks.")
  await calls.wait(for: 2)
  var updates = reviser.updates.makeAsyncIterator()
  _ = await updates.next()
  #expect(await reviser.shown == "Let's meet at 4pm. Thanks.")
  await reviser.stop()
}

@Test("A rejected stretch leaves later windows once it is out of the recent tail")
func revisionRejectionAdvances() async {
  let recentSentence = (1...105).map { "word\($0)" }.joined(separator: " ") + "."
  let first = "Old. " + recentSentence + " Wait. No."
  let calls = RevisionCalls(replies: ["Unexpected words", "Unexpected words"])
  let reviser = Reviser(request: { try await calls.answer($0) })
  _ = await reviser.submit(committed: first)
  await calls.wait(for: 1)
  _ = await reviser.submit(committed: first + " Use the second one.")
  await calls.wait(for: 2)
  #expect(await calls.all == [first, recentSentence + " Wait. No. Use the second one."])
  await reviser.stop()
}

@Test("Finish cancels a live call and uses the final reply")
func revisionFinishCancelsLiveCall() async {
  let calls = RevisionCalls()
  let reviser = Reviser(
    request: { input in
      await calls.record(input)
      try await Task.sleep(for: .seconds(60))
      return input
    },
    finalRequest: { _ in "Let's meet at 4pm." }
  )
  _ = await reviser.submit(committed: "Let's meet at 3, no, 4pm.")
  await calls.wait(for: 1)
  #expect(await reviser.finish(committed: "Let's meet at 3, no, 4pm.") == "Let's meet at 4pm.")
}

@Test("A failed final request inserts the available streamed text")
func revisionFinalFallback() async {
  let reviser = Reviser(request: { _ in throw RevisionError.failed })
  #expect(await reviser.finish(committed: "Keep this.") == "Keep this.")
}

private enum RevisionError: Error { case failed }

private actor RevisionCalls {
  private var inputs: [String] = []
  private let replies: [String]?
  private var waiter: CheckedContinuation<Void, Never>?

  init(replies: [String]? = nil) { self.replies = replies }
  var all: [String] { inputs }

  func record(_ input: String) {
    inputs.append(input)
    waiter?.resume()
    waiter = nil
  }

  func answer(_ input: String) throws -> String {
    record(input)
    return replies?[inputs.count - 1] ?? input
  }

  func wait(for count: Int) async {
    if inputs.count < count {
      await withCheckedContinuation { waiter = $0 }
    }
  }
}

private actor RevisionGate {
  private var inputs: [String] = []
  private var inputWaiter: CheckedContinuation<String, Never>?
  private var response: CheckedContinuation<String, any Error>?

  func request(_ input: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      response = continuation
      if let inputWaiter {
        self.inputWaiter = nil
        inputWaiter.resume(returning: input)
      } else {
        inputs.append(input)
      }
    }
  }

  func next() async -> String {
    if !inputs.isEmpty { return inputs.removeFirst() }
    return await withCheckedContinuation { inputWaiter = $0 }
  }

  func reply(_ text: String) {
    response?.resume(returning: text)
    response = nil
  }
}
