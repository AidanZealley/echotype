import AppKit

/// Opt+D, hardcoded for the spike. Keycode 2 is the physical D key on an ANSI layout.
private let dKeyCode: Int64 = 2

/// Opt must be the only one of these held, so Cmd+Opt+D, Ctrl+Opt+D and Shift+Opt+D
/// pass through untouched.
private let chordModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

/// Global so the C callback, which cannot capture context, can re-enable it.
@MainActor private var tap: CFMachPort?

/// Installs an active keyDown tap that consumes Opt+D and pastes a fixed string.
/// If the tap cannot be created yet (Accessibility not granted), retries every
/// second so granting the permission takes effect without a relaunch.
@MainActor func startHotkey() {
  // Surfaces the Accessibility prompt instead of failing quietly. The key is the
  // value of kAXTrustedCheckOptionPrompt, which Swift 6 rejects as a mutable global.
  AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  retryUntilInstalled()
}

@MainActor private func retryUntilInstalled() {
  if installTap() { return }
  DispatchQueue.main.asyncAfter(deadline: .now() + 1) { retryUntilInstalled() }
}

@MainActor private func installTap() -> Bool {
  guard
    let port = CGEvent.tapCreate(
      tap: .cghidEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
      callback: handleEvent,
      userInfo: nil
    )
  else { return false }

  let source = CFMachPortCreateRunLoopSource(nil, port, 0)
  CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
  tap = port
  return true
}

/// Runs on the main run loop, where the tap's source is installed.
private func handleEvent(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  switch type {
  case .tapDisabledByTimeout, .tapDisabledByUserInput:
    // The system disables a slow tap; without this the hotkey silently stops.
    MainActor.assumeIsolated {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
    return Unmanaged.passUnretained(event)
  case .keyDown
  where event.getIntegerValueField(.keyboardEventKeycode) == dKeyCode
    && event.flags.intersection(chordModifiers) == .maskAlternate:
    // Repeats are consumed too, so no `d` leaks while the chord is held, but only
    // the initial press inserts. A repeat would otherwise snapshot our own string
    // as the "previous" pasteboard and lose the user's contents.
    if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
      // Insert after returning, so the tap callback stays fast.
      DispatchQueue.main.async { insert("hello from echotype") }
    }
    return nil
  default:
    return Unmanaged.passUnretained(event)
  }
}
