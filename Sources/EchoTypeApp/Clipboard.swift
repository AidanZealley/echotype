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
  /// Paste is confirmed by reading back the transcript at the pre-paste caret. Fields that
  /// cannot answer finish after the same fixed window, so confirmation is never required.
  func insert(
    _ text: String, destination: Destination?, sends: Bool,
    verify: @escaping @MainActor (Destination?) -> DestinationVerification = DestinationFocus().verify,
    selectedRange: @escaping @MainActor (Destination?) -> CFRange? = DestinationFocus.selectedRange,
    stringInRange: @escaping @MainActor (Destination?, CFRange) -> String? = DestinationFocus.string,
    cancelled: @escaping @MainActor () -> Bool,
    onBegin: @escaping @MainActor () -> Void = {}
  ) async -> InsertionResult {
    let previous = pending
    let task = Task { () -> InsertionResult in
      await previous?.value
      guard !cancelled() else { return .init(insertion: .cancelled, sending: .notRequested) }
      guard !text.isEmpty else { return .init(insertion: .notAttempted, sending: .notRequested) }
      let snapshotCount = access.count()
      let saved = access.save()
      // Saving all data may invoke pasteboard providers, so check at the actual write boundary.
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
      let anchor = selectedRange(destination)?.location
      access.write(text)
      let owned = access.count()
      access.post(9, .maskCommand)
      await awaitPaste(text, at: anchor, destination: destination,
        selectedRange: selectedRange, stringInRange: stringInRange)
      var sending = DictationTrace.Sending.notRequested
      if sends {
        let check = verify(destination)
        if check == .matching {
          access.post(36, [])
          sending = .attempted
        } else {
          sending = .skipped(check == .changed ? .changed : .unavailable)
        }
      }
      if snapshotValid, access.count() == owned, !saved.isEmpty { access.restore(saved) }
      return .init(insertion: .attempted, sending: sending)
    }
    pending = Task { _ = await task.value }
    return await task.value
  }

  /// Polls for the transcript at the anchor, stopping at the first failed read. Always spends
  /// the full 400 ms window when unconfirmed. Poll iterations are counted, as in `copySelection`.
  /// The string is read only once the caret has moved: before the paste lands, the transcript's
  /// range can extend past the end of the field and fail.
  private func awaitPaste(
    _ text: String, at anchor: Int?, destination: Destination?,
    selectedRange: @MainActor (Destination?) -> CFRange?,
    stringInRange: @MainActor (Destination?, CFRange) -> String?
  ) async {
    let polls = 16
    var elapsed = 0
    let length = text.utf16.count
    while let anchor, elapsed < polls {
      await access.wait(.milliseconds(25))
      elapsed += 1
      guard let caret = selectedRange(destination) else { break }
      guard caret.location == anchor + length, caret.length == 0 else { continue }
      guard let pasted = stringInRange(destination, CFRange(location: anchor, length: length))
      else { break }
      if pasted == text { return }
    }
    if elapsed < polls { await access.wait(.milliseconds(25 * (polls - elapsed))) }
  }

  /// Explicit user Copy also queues behind synthetic transactions and their restoration.
  func copy(_ text: String) async {
    let previous = pending
    let task = Task { await previous?.value; access.write(text) }
    pending = task
    await task.value
  }
}
