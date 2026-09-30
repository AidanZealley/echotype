import AppKit
import EchoTypeCore

/// One owner for synthetic Copy and paste. Every transaction finishes cleanup even when its
/// caller stops. Public pasteboard change counts detect lost ownership, never writer identity.
@MainActor final class Clipboard {
  struct Access {
    var count: () -> Int
    var save: () -> [NSPasteboardItem]
    var restore: ([NSPasteboardItem]) -> Void
    var read: () -> String?
    var write: (String) -> Void
    var post: (CGKeyCode, CGEventFlags) -> Void
    var wait: (Duration) async -> Void

    static var system: Self {
      let board = NSPasteboard.general
      return Self(
        count: { board.changeCount },
        save: {
          (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
              if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
          }
        },
        restore: { board.clearContents(); if !$0.isEmpty { board.writeObjects($0) } },
        read: { board.string(forType: .string) },
        write: { board.clearContents(); board.setString($0, forType: .string) },
        post: { key, flags in
          for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
          }
        },
        wait: { try? await Task.sleep(for: $0) })
    }
  }

  struct InsertionResult: Equatable {
    var insertion: DictationTrace.Insertion
    var sending: DictationTrace.Sending
  }

  private let access: Access
  private var pending: Task<Void, Never>?

  init(access: Access = .system) { self.access = access }

  /// Includes queued transactions and any Copy response window still owned by a stopped reader.
  func waitForCleanup() async { await pending?.value }

  func copySelection(cancelled: @escaping @MainActor () -> Bool) async -> String? {
    let previous = pending
    let task = Task { () -> String? in
      await previous?.value
      guard !cancelled() else { return nil }
      let saved = access.save()
      let before = access.count()
      access.post(8, .maskCommand)
      var copied: String?
      var owned: Int?
      // Keep the full response window after cancellation. A later Copy response can arrive
      // after the first write; a second observed write invalidates attribution and restoration.
      for _ in 0..<30 {
        await access.wait(.milliseconds(10))
        let count = access.count()
        if owned == nil, count != before {
          owned = count
          copied = access.read()
        }
      }
      if let owned, access.count() == owned { access.restore(saved) }
      return copied?.isEmpty == false ? copied : nil
    }
    pending = Task { _ = await task.value }
    return await task.value
  }

  /// Cancellation and destination are checked after queued cleanup, immediately before the
  /// first write. From that write onward this service owns completion, including Return.
  func insert(
    _ text: String, destination: Destination?, sends: Bool,
    verify: @escaping @MainActor (Destination?) -> DestinationVerification = DestinationFocus().verify,
    cancelled: @escaping @MainActor () -> Bool,
    onBegin: @escaping @MainActor () -> Void = {}
  ) async -> InsertionResult {
    let previous = pending
    let task = Task { () -> InsertionResult in
      await previous?.value
      guard !cancelled() else { return .init(insertion: .cancelled, sending: .notRequested) }
      guard !text.isEmpty else { return .init(insertion: .notAttempted, sending: .notRequested) }
      let check = verify(destination)
      guard check == .matching else {
        let loss: DictationTrace.DestinationLoss = check == .changed ? .changed : .unavailable
        return .init(insertion: .skipped(loss), sending: sends ? .skipped(loss) : .notRequested)
      }
      let snapshotCount = access.count()
      let saved = access.save()
      // Saving all data may invoke pasteboard providers. Recheck at the actual write boundary.
      guard !cancelled() else { return .init(insertion: .cancelled, sending: .notRequested) }
      let boundary = verify(destination)
      guard boundary == .matching else {
        let loss: DictationTrace.DestinationLoss = boundary == .changed ? .changed : .unavailable
        return .init(insertion: .skipped(loss), sending: sends ? .skipped(loss) : .notRequested)
      }
      onBegin()
      // AX lookup and pasteboard providers can allow another process to invalidate the saved
      // contents before our write. Our later write count cannot prove that snapshot was valid.
      let snapshotValid = access.count() == snapshotCount
      access.write(text)
      let owned = access.count()
      access.post(9, .maskCommand)
      var sending = DictationTrace.Sending.notRequested
      if sends {
        await access.wait(.milliseconds(200))
        let check = verify(destination)
        if check == .matching {
          access.post(36, [])
          sending = .attempted
        } else {
          sending = .skipped(check == .changed ? .changed : .unavailable)
        }
      }
      await access.wait(sends ? .milliseconds(600) : .milliseconds(800))
      if snapshotValid, access.count() == owned, !saved.isEmpty { access.restore(saved) }
      return .init(insertion: .attempted, sending: sending)
    }
    pending = Task { _ = await task.value }
    return await task.value
  }

  /// Explicit user Copy also queues behind synthetic transactions and their restoration.
  func copy(_ text: String) async {
    let previous = pending
    let task = Task { await previous?.value; access.write(text) }
    pending = task
    await task.value
  }
}
