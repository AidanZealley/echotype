import Foundation

/// The session's only source of time, injected so that tests move time forward explicitly
/// instead of waiting.
///
/// A session needs one wake-up at a time: the silence timeout while listening, and the hard cap
/// once it is paused or once silence has already fired. Scheduling replaces whatever was
/// pending, so there is no timer identity to track on either side of the seam.
public protocol SessionClock: Sendable {
  /// Seconds on a monotonic timeline. Only differences are meaningful.
  var now: TimeInterval { get }

  /// Runs `fire` when the clock reaches `deadline`, replacing any wake-up scheduled before it.
  func schedule(at deadline: TimeInterval, fire: @Sendable @escaping () async -> Void)

  /// Cancels the pending wake-up, if any.
  func cancel()
}

/// The clock a real session runs on.
///
/// Time is `systemUptime` rather than a date, so a session is unaffected by the wall clock
/// moving under it.
public final class SystemClock: SessionClock, @unchecked Sendable {
  private let lock = NSLock()
  private var pending: Task<Void, Never>?

  public init() {}

  public var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

  public func schedule(at deadline: TimeInterval, fire: @Sendable @escaping () async -> Void) {
    let delay = max(0, deadline - now)
    let task = Task {
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await fire()
    }
    lock.lock()
    let previous = pending
    pending = task
    lock.unlock()
    previous?.cancel()
  }

  public func cancel() {
    lock.lock()
    let previous = pending
    pending = nil
    lock.unlock()
    previous?.cancel()
  }
}
