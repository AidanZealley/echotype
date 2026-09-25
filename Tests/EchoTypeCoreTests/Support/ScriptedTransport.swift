import EchoTypeCore
import Foundation

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
