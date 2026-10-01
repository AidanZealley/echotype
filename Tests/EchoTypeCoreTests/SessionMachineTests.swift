import EchoTypeCore
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SessionMachineTests {
  let transcriber = ScriptedTranscriber()
  let clock = TestClock()
  let session: SessionMachine
  let log: SnapshotLog

  init() {
    session = SessionMachine(transcriber: transcriber, settings: Settings(), clock: clock)
    log = SnapshotLog(session.snapshots)
  }

  /// Starts the session and waits until it is listening, which is also what proves its event
  /// loop is running before a test scripts anything.
  private func start() async -> Task<SessionMachine.Outcome, Never> {
    let running = Task { await session.run() }
    #expect(await log.next() == .listening)
    return running
  }

  /// What a provider reports when someone speaks: the complete committed transcript so far,
  /// then evidence of speech.
  private func say(_ committed: String) async {
    await transcriber.emit(committed: committed)
    await transcriber.emit(.speech)
  }

  // MARK: Silence, pause and hard cap

  @Test("Ten seconds without speech pauses the session and speech resumes it")
  func quietPausesAndSpeechResumes() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("a thought")

    // A transcript without speech, such as a provider's empty updates through a silence, is not
    // activity.
    await clock.advance(by: 5)
    await transcriber.emit(committed: "a thought")
    await clock.advance(by: 5)
    #expect(await log.next() == .paused)

    await transcriber.emit(.speech)
    #expect(await log.next() == .listening)

    await session.cancel()
    _ = await running.value
  }

  @Test("Pause and resume cycles keep the latest transcript and insert it")
  func pauseCyclesAccumulateText() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("one")

    await clock.advance(by: 10)
    #expect(await log.next() == .paused)
    #expect(await log.latest == .init(state: .paused, transcript: .init(committed: "one")))
    await say("one two")
    #expect(await log.next() == .listening)

    await clock.advance(by: 10)
    #expect(await log.next() == .paused)
    await say("one two three")
    #expect(await log.next() == .listening)

    await session.finish()
    #expect(await log.next() == .finalizing)
    #expect(await transcriber.calls == [.finish])

    await transcriber.emit(.finished)
    #expect(await running.value == .insert("one two three"))
    #expect(await log.rest() == [.idle])
  }

  @Test("A session where nothing is said cancels silently")
  func nothingSaidCancelsSilently() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await transcriber.emit(committed: "")

    await clock.advance(by: 10)
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.cancelled])
    // Nothing was finalised, so the session never asked for a transcript.
    #expect(await transcriber.calls.isEmpty)
  }

  @Test("The hard cap ends the session and commits what accumulated")
  func hardCapCommits() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("walked away")

    await clock.advance(by: 300)
    #expect(await log.next() == .paused)
    #expect(await log.next() == .finalizing)
    // The owner drains its audio before closing, so the session never closes on its own.
    #expect(await transcriber.calls.isEmpty)
    await session.sendClosing()
    #expect(await transcriber.calls == [.finish])

    await transcriber.emit(.finished)
    #expect(await running.value == .insert("walked away"))
    #expect(await log.rest() == [.idle])
  }

  // MARK: Cancellation

  @Test("Cancelling discards everything", arguments: [false, true])
  func cancellingDiscardsEverything(afterPausing: Bool) async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("private thoughts")

    if afterPausing {
      await clock.advance(by: 10)
      #expect(await log.next() == .paused)
    }

    await session.cancel()
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.cancelled])
    #expect(await transcriber.calls.isEmpty)
  }

  @Test("Cancellation before run still completes teardown and snapshots")
  func cancellationBeforeRun() async {
    await session.cancel()
    #expect(await session.run() == .nothing)
    #expect(await log.rest() == [.cancelled])
    #expect(await transcriber.calls.isEmpty)
  }

  // MARK: Readiness and held audio

  @Test("Readiness has a bounded network deadline")
  func readinessDeadline() async {
    let running = await start()
    defer { transcriber.close() }
    await clock.advance(by: SessionMachine.readinessTimeout)
    guard case .failed(_, .socket) = await running.value else { Issue.record("Expected readiness failure"); return }
  }

  @Test("Audio before .ready is held, then sent ahead of later audio")
  func audioWaitsForReadiness() async throws {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    let firstWords = Data([1, 2])
    try await session.send(audio: firstWords)
    #expect(await transcriber.calls.isEmpty)

    await transcriber.emit(.ready)
    // Held rather than dropped, so connecting does not clip the first word.
    #expect(await transcriber.calls == [.audio(firstWords)])
    try await session.send(audio: Data([3]))
    #expect(await transcriber.calls == [.audio(firstWords), .audio(Data([3]))])

    await session.cancel()
    _ = await running.value
  }

  @Test("Stopping before .ready keeps held audio ahead of finish()")
  func finishBeforeReadiness() async throws {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    try await session.send(audio: Data([1, 2]))
    let closing = await session.startFinishing()
    #expect(await log.next() == .finalizing)
    #expect(await transcriber.calls.isEmpty)

    await transcriber.emit(.ready)
    await closing.value
    #expect(await transcriber.calls == [.audio(Data([1, 2])), .finish])
    await transcriber.emit(.finished)
    #expect(await running.value == .nothing)
  }

  @Test("A stop waiting on a .ready that never comes ends at the finishing deadline")
  func finishWaitingOnReadinessTimesOut() async throws {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    try await session.send(audio: Data([1, 2]))
    let closing = await session.startFinishing()
    #expect(await log.next() == .finalizing)

    await clock.advance(by: Settings().finalizeTimeout)

    #expect(
      await running.value
        == .failed(text: "", error: .socket("the endpoint never answered the finalize request")))
    await closing.value
    #expect(await transcriber.calls.isEmpty)
  }

  @Test("Stopping before .ready with nothing held still ends with nothing to insert")
  func triggerBeforeTheSessionIsReady() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }

    await session.finish()
    #expect(await log.next() == .finalizing)
    #expect(await transcriber.calls == [.finish])

    await transcriber.emit(.finished)
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.idle])
  }

  @Test("Held audio over the limit fails visibly")
  func heldAudioLimit() async {
    let running = await start()
    defer { transcriber.close() }
    await #expect(throws: SessionError.self) {
      try await session.send(audio: Data(count: SessionMachine.heldAudioLimit + 1))
    }
    guard case .failed(_, .socket) = await running.value else { Issue.record("Expected backlog failure"); return }
  }

  @Test("A failed send of held audio fails the session and prevents finish()")
  func heldAudioSendFailure() async throws {
    let running = await start()
    defer { transcriber.close() }
    try await session.send(audio: Data([1]))
    await transcriber.failSends(with: ProviderError.unavailable)
    await transcriber.emit(.ready)
    await session.finish()
    #expect(await running.value == .failed(text: "", error: .provider(.unavailable)))
    #expect(await transcriber.calls.isEmpty)
  }

  // MARK: Send ordering

  @Test("Audio handed over while a send is in flight stays behind it")
  func audioKeepsItsOrderWhileASendIsInFlight() async throws {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    let first = Data([0x0A])
    let second = Data([0x0B])
    try await session.send(audio: first)
    await transcriber.holdNextSend()
    let ready = Task { await transcriber.emit(.ready) }

    // The flush of held audio is suspended in the transcriber, which is exactly when capture
    // hands over its next chunk.
    await transcriber.waitForHeldSend()
    let handover = await session.startSending(audio: second)
    await transcriber.releaseSend()
    try await handover.value
    await ready.value

    #expect(await transcriber.calls == [.audio(first), .audio(second)])
    await session.cancel()
    _ = await running.value
  }

  @Test("finish() waits for audio still on its way out")
  func finishWaitsForAudioAlreadyHandedOver() async throws {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await transcriber.holdNextSend()
    let sending = await session.startSending(audio: Data([0x0A]))

    // The stop arrives while capture's chunk is still in the transcriber.
    await transcriber.waitForHeldSend()
    let stop = await session.startFinishing()
    await transcriber.releaseSend()
    try await sending.value
    await stop.value

    #expect(await transcriber.calls == [.audio(Data([0x0A])), .finish])
    await transcriber.emit(.finished)
    #expect(await running.value == .nothing)
  }

  // MARK: Finishing

  @Test("A finish the transcriber never answers ends the session rather than hanging")
  func finalizingWithoutAnAnswerTimesOut() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("said and done")

    await session.finish()
    #expect(await log.next() == .finalizing)
    #expect(await transcriber.calls == [.finish])

    // Finishing resolves the tail into one more transcript, then `.finished` never arrives.
    await transcriber.emit(committed: "said and done then some")
    await clock.advance(by: Settings().finalizeTimeout)

    let outcome = await running.value
    guard case .failed(let text, .socket) = outcome else {
      Issue.record("expected a socket failure, got \(outcome)")
      return
    }
    #expect(text == "said and done then some")
    #expect(await log.rest() == [.idle])
  }

  @Test("An empty transcript inserts nothing")
  func emptyTranscriptInsertsNothing() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await transcriber.emit(committed: "")

    await session.finish()
    #expect(await log.next() == .finalizing)

    await transcriber.emit(.finished)
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.idle])
  }

  @Test("The last snapshot carries the last text")
  func lastSnapshotCarriesTheText() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("said and done")

    await session.finish()
    #expect(await log.next() == .finalizing)
    // What finishing resolves the tail into arrives while the pill shows transcribing, and the
    // speech in it leaves the finishing deadline alone.
    await transcriber.emit(.transcript(.init(committed: "said and done", provisional: "then some")))
    await transcriber.emit(.speech)
    #expect(
      await log.snapshot()
        == .init(state: .finalizing, transcript: .init(committed: "said and done", provisional: "then some")))
    await transcriber.emit(committed: "said and done then some")
    await transcriber.emit(.finished)

    #expect(await running.value == .insert("said and done then some"))
    #expect(await log.rest() == [.idle])
    #expect(
      await log.latest == .init(state: .idle, transcript: .init(committed: "said and done then some")))
  }

  @Test("Each transcript is published as the provider reports it")
  func transcriptsArePublished() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)

    let provisional = Transcript(provisional: "tan stock")
    let settled = Transcript(utterance: "tanstack is")
    await transcriber.emit(.transcript(provisional))
    #expect(await log.snapshot() == .init(state: .listening, transcript: provisional))
    await transcriber.emit(.transcript(settled))
    #expect(await log.snapshot() == .init(state: .listening, transcript: settled))

    await session.cancel()
    _ = await running.value
  }

  // MARK: Unrequested endings and failures

  @Test(".finished nobody asked for ends the session as a failure")
  func unsolicitedFinishedDoesNotCommit() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("thinking out loud")

    // Text reaches the target app only on an explicit trigger or the hard cap, so `.finished`
    // with neither behind it is the provider ending the transcript, not a commit.
    await transcriber.emit(.finished)
    let outcome = await running.value
    guard case .failed(let text, .socket) = outcome else {
      Issue.record("expected a socket failure, got \(outcome)")
      return
    }
    #expect(text == "thinking out loud")
    #expect(await transcriber.calls.isEmpty)
  }

  @Test(".finished before closing begins is not a finalised transcript")
  func finishedBeforeClosingDoesNotCommit() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("still draining")

    // Finishing has begun, but the owner is still draining audio the provider has not heard.
    await session.beginFinishing()
    await transcriber.emit(.finished)
    guard case .failed(let text, .socket) = await running.value else {
      Issue.record("expected a socket failure")
      return
    }
    #expect(text == "still draining")
    #expect(await transcriber.calls.isEmpty)
  }

  @Test("Events ending during finishing is a failure without .finished")
  func eventsEndingWhileFinishing() async {
    let running = await start()
    defer { transcriber.close() }
    await transcriber.emit(.ready)
    await say("available words")
    await session.finish()
    transcriber.close()
    guard case .failed(let text, .socket) = await running.value else { Issue.record("Expected incomplete protocol failure"); return }
    #expect(text == "available words")
  }

  @Test("A provider failure keeps the text committed before it")
  func providerFailureKeepsCommittedText() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("half a sentence")

    await transcriber.fail(with: ProviderError.failed("upstream failed"))
    #expect(
      await running.value == .failed(text: "half a sentence", error: .provider(.failed("upstream failed"))))
    #expect(await log.rest() == [.idle])
  }

  @Test("Any other failure ends the session as a connection failure")
  func otherFailureIsAConnectionFailure() async {
    let running = await start()
    defer { running.cancel(); transcriber.close() }
    await transcriber.emit(.ready)
    await say("first sentence")

    await transcriber.fail(with: URLError(.networkConnectionLost))
    // Everything from here is past the end of the session.
    await say("first sentence second sentence")
    await session.finish()
    await transcriber.emit(.finished)

    let outcome = await running.value
    guard case .failed(let text, .socket) = outcome else {
      Issue.record("expected a socket failure, got \(outcome)")
      return
    }
    #expect(text == "first sentence")
    #expect(await transcriber.calls.isEmpty)
  }
}

private extension SessionMachine {
  /// What the owning operation does on a stop once its audio has drained.
  func finish() async {
    beginFinishing()
    await sendClosing()
  }

  // Immediate tasks run on this actor until suspension. Returning the task therefore proves the
  // call was enqueued behind the suspended send, before the test releases it.
  func startSending(audio: Data) -> Task<Void, any Error> {
    Task.immediate { try await self.send(audio: audio) }
  }

  func startFinishing() -> Task<Void, Never> {
    Task.immediate { await self.finish() }
  }
}
