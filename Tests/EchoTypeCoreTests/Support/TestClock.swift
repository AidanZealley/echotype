import EchoTypeCore
import Foundation

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
