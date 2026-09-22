import AppKit

/// Inserts text at the focused caret via the pasteboard and a synthetic Cmd+V,
/// following the specification's Insertion sequence.
@MainActor func insert(_ text: String) {
    let pasteboard = NSPasteboard.general
    let saved = (pasteboard.pasteboardItems ?? []).map(copy)

    let before = pasteboard.changeCount
    pasteboard.clearContents()  // The only call here that advances changeCount.
    pasteboard.setString(text, forType: .string)

    let vKeyCode: CGKeyCode = 9
    for keyDown in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: keyDown)
        // Explicit flags, so the still-held Option key does not turn this into Cmd+Opt+V.
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        // Anything else writing in the meantime owns the pasteboard now; leave it.
        guard pasteboard.changeCount == before + 1 else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(saved)
    }
}

/// Pasteboard items cannot be rewritten once read, so restore from a copy.
private func copy(_ item: NSPasteboardItem) -> NSPasteboardItem {
    let copy = NSPasteboardItem()
    for type in item.types {
        if let data = item.data(forType: type) { copy.setData(data, forType: type) }
    }
    return copy
}
