import AppKit

/// Inserts text at the focused caret via the pasteboard and a synthetic Cmd+V. The user's
/// pasteboard is saved first and put back through `Pasteboard`, which `Reader` also uses
/// to copy the selection.
@MainActor final class Inserter {
  /// The restore still waiting to run: what the user had, and the `changeCount` from before
  /// the transcript was written. That count identifies the insertion, so a later one can
  /// supersede it.
  private var pending: (saved: [NSPasteboardItem], before: Int)?

  func insert(_ text: String) {
    let pasteboard = NSPasteboard.general
    let saved = savedContents(of: pasteboard)

    let before = pasteboard.changeCount
    pasteboard.clearContents()  // The only call here that advances changeCount.
    pasteboard.setString(text, forType: .string)
    pending = (saved, before)

    let vKeyCode: CGKeyCode = 9
    for keyDown in [true, false] {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: keyDown)
      // Explicit flags, so the still-held Option key does not turn this into Cmd+Opt+V.
      event?.flags = .maskCommand
      event?.post(tap: .cghidEventTap)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.restore(after: before) }
  }

  /// What to put back afterwards. While an earlier insertion's restore is pending and its
  /// transcript is still on the pasteboard, the user's contents are the ones that insertion
  /// saved, not its transcript.
  private func savedContents(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
    if let pending, pasteboard.changeCount == pending.before + 1 { return pending.saved }
    return Pasteboard.saved()
  }

  /// A reading waits for the pending paste window before sending Cmd+C. Otherwise its copy
  /// can replace the transcript before Cmd+V lands or prevent the previous contents returning.
  func waitForRestore() async throws {
    while pending != nil { try await Task.sleep(for: .milliseconds(10)) }
  }

  private func restore(after before: Int) {
    // A later insertion superseded this restore and carries the saved contents forward.
    guard let pending, pending.before == before else { return }
    self.pending = nil
    let pasteboard = NSPasteboard.general
    // Anything else writing in the meantime owns the pasteboard now; leave it.
    guard pasteboard.changeCount == before + 1 else { return }
    // Nothing to put back: leave the transcript rather than clearing to an empty pasteboard.
    guard !pending.saved.isEmpty else { return }
    Pasteboard.restore(pending.saved)
  }
}
