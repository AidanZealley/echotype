import EchoTypeCore
import Foundation

/// A transcriber the test scripts event by event.
///
/// `emit` returns only once the session has finished handling the event and come back for the
/// next one, so a test never has to sleep or yield to know the session has caught up.
actor ScriptedTranscriber: LiveTranscriber {
  enum Call: Equatable {
    case audio(Data)
    case finish
  }

  private struct Pending {
    let event: TranscriptionEvent
    let acknowledge: CheckedContinuation<Void, Never>
  }

  /// Audio sends and `finish()`, in the order they completed.
  private(set) var calls: [Call] = []
  private var queue: [Pending] = []
  private var inFlight: CheckedContinuation<Void, Never>?
  private var consumer: CheckedContinuation<Void, Never>?
  private var failure: (any Error)?
  private var isFinished = false
  private var sendFailure: (any Error)?
  private var heldSend: CheckedContinuation<Void, Never>?
  private var holdsNextSend = false
  private var sendArrival: CheckedContinuation<Void, Never>?

  /// Sends one event and waits for the session to process it.
  func emit(_ event: TranscriptionEvent) async {
    guard !isFinished else { return }
    await withTaskCancellationHandler {
      await withCheckedContinuation { acknowledge in
        guard !isFinished, !Task.isCancelled else { acknowledge.resume(); return }
        queue.append(Pending(event: event, acknowledge: acknowledge))
        wakeConsumer()
      }
    } onCancel: {
      close()
    }
  }

  /// A complete transcript with only committed text, as a provider reports it.
  func emit(committed: String) async {
    await emit(.transcript(Transcript(committed: committed)))
  }

  /// Fails the event stream, as a dropped connection does.
  func fail(with error: any Error) {
    failure = error
    wakeConsumer()
  }

  /// Every later send and `finish()` throws.
  func failSends(with error: any Error) {
    sendFailure = error
  }

  /// The next audio send suspends until `releaseSend()`.
  func holdNextSend() {
    holdsNextSend = true
  }

  /// Returns once a held send is suspended in the transcriber.
  func waitForHeldSend() async {
    guard heldSend == nil else { return }
    await withCheckedContinuation { sendArrival = $0 }
  }

  func releaseSend() {
    heldSend?.resume()
    heldSend = nil
  }

  nonisolated var events: AsyncThrowingStream<TranscriptionEvent, any Error> {
    AsyncThrowingStream { try await self.take() }
  }

  func send(audio: Data) async throws {
    if holdsNextSend {
      holdsNextSend = false
      await withCheckedContinuation {
        heldSend = $0
        sendArrival?.resume()
        sendArrival = nil
      }
    }
    if let sendFailure { throw sendFailure }
    calls.append(.audio(audio))
  }

  func finish() async throws {
    if let sendFailure { throw sendFailure }
    calls.append(.finish)
  }

  nonisolated func close() {
    Task { await self.end() }
  }

  func waitForClose() async {}

  private func take() async throws -> TranscriptionEvent? {
    // Reaching for the next event is what says the previous one has been handled.
    acknowledgeInFlight()
    while true {
      if Task.isCancelled { end(); return nil }
      if let failure {
        self.failure = nil
        end()
        throw failure
      }
      if !queue.isEmpty {
        let pending = queue.removeFirst()
        inFlight = pending.acknowledge
        return pending.event
      }
      if isFinished { return nil }
      await withTaskCancellationHandler {
        await withCheckedContinuation {
          if isFinished || Task.isCancelled { $0.resume() } else { consumer = $0 }
        }
      } onCancel: {
        close()
      }
    }
  }

  /// Closing releases a suspended send, as a real connection does.
  private func end() {
    isFinished = true
    releaseSend()
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
