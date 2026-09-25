import EchoTypeCore
import Foundation

/// Reads the session's snapshots in order. Awaiting the next one is how these tests synchronise
/// with the session's own timeline.
actor SnapshotLog {
  private var buffered: [SessionMachine.Snapshot] = []
  private var waiter: CheckedContinuation<SessionMachine.Snapshot?, Never>?
  private var isFinished = false
  /// The most recent snapshot read, whether by `snapshot()` or `next()`.
  private(set) var latest: SessionMachine.Snapshot?

  init(_ snapshots: AsyncStream<SessionMachine.Snapshot>) {
    Task { await self.consume(snapshots) }
  }

  /// The next snapshot, whatever changed.
  func snapshot() async -> SessionMachine.Snapshot? {
    let next: SessionMachine.Snapshot?
    if !buffered.isEmpty {
      next = buffered.removeFirst()
    } else if isFinished {
      next = nil
    } else {
      next = await withCheckedContinuation { waiter = $0 }
    }
    if let next { latest = next }
    return next
  }

  /// The next state the session enters, passing over snapshots that only changed its text.
  func next() async -> SessionMachine.State? {
    let current = latest?.state
    while let next = await snapshot() {
      if next.state != current { return next.state }
    }
    return nil
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

  private func consume(_ snapshots: AsyncStream<SessionMachine.Snapshot>) async {
    for await snapshot in snapshots {
      if let waiter {
        self.waiter = nil
        waiter.resume(returning: snapshot)
      } else {
        buffered.append(snapshot)
      }
    }
    isFinished = true
    waiter?.resume(returning: nil)
    waiter = nil
  }
}
