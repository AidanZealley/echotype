import AppKit

/// The general pasteboard's save and restore, shared by `Inserter` and `Reader`, and the copy
/// that reads the selection in the focused app.
@MainActor enum Pasteboard {
  /// A copy of every item on the pasteboard. Pasteboard items cannot be rewritten once read, so
  /// restoring needs copies.
  static func saved() -> [NSPasteboardItem] {
    (NSPasteboard.general.pasteboardItems ?? []).map { item in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) { copy.setData(data, forType: type) }
      }
      return copy
    }
  }

  /// Replaces the pasteboard's contents with `items`, which may be empty.
  static func restore(_ items: [NSPasteboardItem]) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(items)
  }

  /// Copies the focused app's selection with a synthetic Cmd+C and returns it as a string,
  /// putting back what the pasteboard held before. Returns nil when the pasteboard does not
  /// change within 300ms, which means nothing was selected, or when the copy holds no text.
  ///
  /// The wait always runs its course, even when the caller is cancelled: a copy that lands
  /// after an early return would stay on the pasteboard with nothing to restore it. Callers
  /// check for cancellation afterwards.
  static func copySelection() async -> String? {
    // An unstructured task does not inherit the caller's cancellation.
    await Task { await copyAndRestore() }.value
  }

  private static func copyAndRestore() async -> String? {
    let pasteboard = NSPasteboard.general
    let saved = saved()
    let before = pasteboard.changeCount

    let cKeyCode: CGKeyCode = 8
    for keyDown in [true, false] {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: cKeyCode, keyDown: keyDown)
      // Explicit flags, so the still-held Option key does not turn this into Cmd+Opt+C.
      event?.flags = .maskCommand
      event?.post(tap: .cghidEventTap)
    }

    for _ in 0..<30 {
      try? await Task.sleep(for: .milliseconds(10))
      guard pasteboard.changeCount != before else { continue }
      let text = pasteboard.string(forType: .string)
      restore(saved)
      return text?.isEmpty == false ? text : nil
    }
    return nil
  }
}
