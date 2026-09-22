import EchoTypeCore
import Foundation
import Testing

/// A transport the test scripts frame by frame.
///
/// `emit` returns only once the session has finished handling the frame and come back for the
/// next one, so a test never has to sleep or yield to know the session has caught up.
actor ScriptedTransport: WebSocketTransport {
  private struct Pending {
    let message: String
    let acknowledge: CheckedContinuation<Void, Never>
  }

  private(set) var textFrames: [String] = []
  private var queue: [Pending] = []
  private var inFlight: CheckedContinuation<Void, Never>?
  private var consumer: CheckedContinuation<Void, Never>?
  private var failure: (any Error)?
  private var isFinished = false

  /// Sends one server frame and waits for the session to process it.
  func emit(_ message: String) async {
    guard !isFinished else { return }
    await withCheckedContinuation { acknowledge in
      queue.append(Pending(message: message, acknowledge: acknowledge))
      wakeConsumer()
    }
  }

  /// Fails the server stream, as a dropped socket does.
  func fail(with error: any Error) {
    failure = error
    wakeConsumer()
  }

  nonisolated func close() {
    Task { await self.end() }
  }

  nonisolated func messages() -> AsyncThrowingStream<String, any Error> {
    AsyncThrowingStream { try await self.take() }
  }

  func send(text: String) async throws {
    textFrames.append(text)
  }

  /// Audio delivery belongs to `STTClient` and is covered by its own tests.
  func send(binary: Data) async throws {}

  private func take() async throws -> String? {
    // Reaching for the next frame is what says the previous one has been handled.
    acknowledgeInFlight()
    while true {
      if let failure {
        self.failure = nil
        end()
        throw failure
      }
      if !queue.isEmpty {
        let pending = queue.removeFirst()
        inFlight = pending.acknowledge
        return pending.message
      }
      if isFinished { return nil }
      await withCheckedContinuation { consumer = $0 }
    }
  }

  private func end() {
    isFinished = true
    acknowledgeInFlight()
    for pending in queue { pending.acknowledge.resume() }
    queue.removeAll()
    wakeConsumer()
  }

  private func acknowledgeInFlight() {
    inFlight?.resume()
    inFlight = nil
  }

  private func wakeConsumer() {
    consumer?.resume()
    consumer = nil
  }
}

/// A clock the test moves by hand. Advancing past a deadline runs it and waits for the session
/// to react, so a timeout's effect is in place by the time `advance` returns.
final class TestClock: SessionClock, @unchecked Sendable {
  private let lock = NSLock()
  private var time: TimeInterval = 0
  private var deadline: TimeInterval?
  private var pending: (@Sendable () async -> Void)?

  var now: TimeInterval { lock.withLock { time } }

  func schedule(at deadline: TimeInterval, fire: @Sendable @escaping () async -> Void) {
    lock.withLock {
      self.deadline = deadline
      pending = fire
    }
  }

  func cancel() {
    lock.withLock {
      deadline = nil
      pending = nil
    }
  }

  func advance(by interval: TimeInterval) async {
    let target = now + interval
    while let fire = takeDeadline(upTo: target) {
      await fire()
    }
    lock.withLock { time = target }
  }

  /// Moves time to the next deadline at or before `target` and hands back what it should run.
  private func takeDeadline(upTo target: TimeInterval) -> (@Sendable () async -> Void)? {
    lock.withLock {
      guard let deadline, deadline <= target, let fire = pending else { return nil }
      time = deadline
      self.deadline = nil
      pending = nil
      return fire
    }
  }
}

/// Reads the session's transitions in order. Awaiting the next transition is how these tests
/// synchronise with the session's own timeline.
actor StateLog {
  private var buffered: [SessionMachine.State] = []
  private var waiter: CheckedContinuation<SessionMachine.State?, Never>?
  private var isFinished = false

  init(_ states: AsyncStream<SessionMachine.State>) {
    Task { await self.consume(states) }
  }

  func next() async -> SessionMachine.State? {
    if !buffered.isEmpty { return buffered.removeFirst() }
    if isFinished { return nil }
    return await withCheckedContinuation { waiter = $0 }
  }

  /// Every transition still to come. The stream finishes with the session, so this returns once
  /// the session has ended.
  func rest() async -> [SessionMachine.State] {
    var states: [SessionMachine.State] = []
    while let state = await next() {
      states.append(state)
    }
    return states
  }

  private func consume(_ states: AsyncStream<SessionMachine.State>) async {
    for await state in states {
      if let waiter {
        self.waiter = nil
        waiter.resume(returning: state)
      } else {
        buffered.append(state)
      }
    }
    isFinished = true
    waiter?.resume(returning: nil)
    waiter = nil
  }
}

@Suite(.timeLimit(.minutes(1)))
struct SessionMachineTests {
  let transport = ScriptedTransport()
  let clock = TestClock()
  let session: SessionMachine
  let log: StateLog

  init() {
    session = SessionMachine(transport: transport, settings: Settings(), clock: clock)
    log = StateLog(session.states)
  }

  /// Starts the session and waits until it is listening, which is also what proves its message
  /// loop is running before a test scripts anything.
  private func start() async -> Task<SessionMachine.Outcome, Never> {
    let running = Task { await session.run() }
    #expect(await log.next() == .listening)
    return running
  }

  private var closingFrames: [String] {
    [#"{"type":"finalize"}"#, #"{"type":"audio.done"}"#]
  }

  @Test("Ten seconds of quiet pauses the session and speech resumes it")
  func quietPausesAndSpeechResumes() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("a thought", speechFinal: true))

    // The endpoint keeps sending partials at about 1 Hz through a silence, with empty text, so
    // their arrival must not count as activity.
    await clock.advance(by: 5)
    await transport.emit(Fixture.partial(""))
    await clock.advance(by: 5)
    #expect(await log.next() == .paused)

    await transport.emit(Fixture.partial("and another"))
    #expect(await log.next() == .listening)

    await session.cancel()
    _ = await running.value
  }

  @Test("Pause and resume cycles accumulate every segment in order")
  func pauseCyclesAccumulateText() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("one", isFinal: true, speechFinal: true))

    await clock.advance(by: 10)
    #expect(await log.next() == .paused)
    await transport.emit(Fixture.partial("tw"))
    #expect(await log.next() == .listening)
    // The endpoint sends the closing frame twice, identical but for `speech_final`, so the
    // duplicate must not become a second segment.
    await transport.emit(Fixture.partial("two", isFinal: true))
    await transport.emit(Fixture.partial("two", isFinal: true, speechFinal: true))

    await clock.advance(by: 10)
    #expect(await log.next() == .paused)
    await transport.emit(Fixture.partial("thre"))
    #expect(await log.next() == .listening)
    await transport.emit(Fixture.partial("three", isFinal: true, speechFinal: true))

    await session.trigger()
    #expect(await log.next() == .finalizing)
    #expect(await transport.textFrames == closingFrames)

    await transport.emit(Fixture.done)
    #expect(await running.value == .insert("one two three"))
    #expect(await log.rest() == [.inserting, .idle])
  }

  @Test("A session where nothing is said cancels silently")
  func nothingSaidCancelsSilently() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial(""))

    await clock.advance(by: 10)
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.cancelled])
    // Nothing was finalised, so the session never asked the endpoint for a transcript.
    #expect(await transport.textFrames.isEmpty)
  }

  @Test("The hard cap ends the session and commits what accumulated")
  func hardCapCommits() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("walked away", speechFinal: true))

    await clock.advance(by: 600)
    #expect(await log.next() == .paused)
    #expect(await log.next() == .finalizing)
    #expect(await transport.textFrames == closingFrames)

    await transport.emit(Fixture.done)
    #expect(await running.value == .insert("walked away"))
    #expect(await log.rest() == [.inserting, .idle])
  }

  @Test("Cancelling discards everything", arguments: [false, true])
  func cancellingDiscardsEverything(afterPausing: Bool) async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("private thoughts", speechFinal: true))

    if afterPausing {
      await clock.advance(by: 10)
      #expect(await log.next() == .paused)
    }

    await session.cancel()
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.cancelled])
    #expect(await transport.textFrames.isEmpty)
  }

  @Test("Stopping before transcript.created still ends the session with nothing to insert")
  func triggerBeforeTheSessionIsReady() async {
    let running = await start()

    await session.trigger()
    #expect(await log.next() == .finalizing)
    #expect(await transport.textFrames == closingFrames)

    await transport.emit(Fixture.done)
    #expect(await running.value == .nothing)
    #expect(await log.rest() == [.idle])
  }

  @Test("A socket failure keeps the segments finalised before it")
  func socketFailureKeepsFinalisedSegments() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("half a sentence", speechFinal: true))

    await transport.fail(with: STTError.unavailable)
    #expect(await running.value == .failed(text: "half a sentence", error: .stt(.unavailable)))
    #expect(await log.rest() == [.inserting, .idle])
  }

  @Test("A server error keeps the segments finalised before it")
  func serverErrorKeepsFinalisedSegments() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("half a sentence", speechFinal: true))

    await transport.emit(Fixture.error(code: "internal_error", message: "upstream failed"))
    let serverError = STTEvent.ServerError(code: "internal_error", message: "upstream failed")
    #expect(
      await running.value
        == .failed(text: "half a sentence", error: .stt(.server(serverError))))
    #expect(await log.rest() == [.inserting, .idle])
  }

  @Test("A transcript.done nobody asked for ends the session as a failure")
  func unsolicitedDoneDoesNotCommit() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial("thinking out loud", speechFinal: true))

    // Text reaches the target app only on an explicit trigger or the hard cap, so a `done` with
    // neither behind it is the socket ending the transcript, not a commit.
    await transport.emit(Fixture.done)
    let outcome = await running.value
    guard case .failed(let text, .socket) = outcome else {
      Issue.record("expected a socket failure, got \(outcome)")
      return
    }
    #expect(text == "thinking out loud")
    #expect(await transport.textFrames.isEmpty)
  }

  @Test("An empty transcript inserts nothing")
  func emptyTranscriptInsertsNothing() async {
    let running = await start()
    await transport.emit(Fixture.created)
    await transport.emit(Fixture.partial(""))

    await session.trigger()
    #expect(await log.next() == .finalizing)

    await transport.emit(Fixture.done)
    #expect(await running.value == .nothing)
    // No `inserting`, so the macOS layer is never asked to paste an empty string.
    #expect(await log.rest() == [.idle])
  }
}
