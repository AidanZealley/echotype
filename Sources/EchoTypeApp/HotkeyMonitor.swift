import AppKit
import EchoTypeCore

/// An active keyDown tap that consumes the dictation and read-aloud hotkeys, reporting which was
/// pressed, and Escape while the caller says a dictation or a reading takes it. It reads both
/// hotkeys from the store on every key event, so a change in Settings applies at once without
/// reinstalling the tap.
///
/// Created once and kept for the life of the app: the tap holds an unretained pointer to it.
@MainActor final class HotkeyMonitor {
  private static let escapeKeyCode: UInt16 = 53  // kVK_Escape

  enum Hotkey {
    case dictation
    case readAloud
  }

  private let store: SettingsStore
  private let onHotkey: (Hotkey) -> Void
  /// Returns whether a dictation or a reading took the press. Escape passes through when it
  /// did not.
  private let onEscape: () -> Bool
  private var tap: CFMachPort?

  init(
    store: SettingsStore,
    onHotkey: @escaping (Hotkey) -> Void,
    onEscape: @escaping () -> Bool
  ) {
    self.store = store
    self.onHotkey = onHotkey
    self.onEscape = onEscape
  }

  /// Installs the tap. If it cannot be created yet (the input grant not given), retries every
  /// second so granting the permission takes effect without a relaunch.
  func start() {
    // Surfaces the permission prompt instead of failing quietly. The API is still the
    // Accessibility trust check; macOS 27 shows it to the user as Device Control and
    // Data Access. The key is the value of kAXTrustedCheckOptionPrompt, which Swift 6
    // rejects as a mutable global.
    AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    retryUntilInstalled()
  }

  private func retryUntilInstalled() {
    if installTap() { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.retryUntilInstalled() }
  }

  private func installTap() -> Bool {
    guard
      let port = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
        callback: { _, type, event, userInfo in
          // The callback is a C function and cannot capture, so the monitor rides in
          // `userInfo`. It runs on the main run loop, where the tap's source is installed.
          let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
          let consumed = MainActor.assumeIsolated { monitor.handle(type, event) }
          return consumed ? nil : Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else { return false }

    let source = CFMachPortCreateRunLoopSource(nil, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    tap = port
    return true
  }

  /// Returns whether to consume the event. Keep it fast: the system disables a slow tap.
  private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      // The system disables a slow tap; without this the hotkey silently stops.
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return false
    case .keyDown:
      let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
      let modifiers = Settings.ModifierFlags(event.flags)
      let settings = store.settings
      let hotkey: Hotkey? =
        if settings.hotkey.matches(keyCode: keyCode, modifiers: modifiers) {
          .dictation
        } else if settings.readAloudHotkey.matches(keyCode: keyCode, modifiers: modifiers) {
          .readAloud
        } else {
          nil
        }
      guard let hotkey else { return keyCode == Self.escapeKeyCode && onEscape() }
      // Repeats are consumed too, so no character leaks while the chord is held, but only the
      // initial press counts.
      if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { onHotkey(hotkey) }
      return true
    default:
      return false
    }
  }
}

extension Settings.ModifierFlags {
  /// Only the four chord modifiers. Caps Lock, Fn and the rest are ignored rather than
  /// counted as extra modifiers.
  init(_ flags: CGEventFlags) {
    self = []
    if flags.contains(.maskShift) { insert(.shift) }
    if flags.contains(.maskControl) { insert(.control) }
    if flags.contains(.maskAlternate) { insert(.option) }
    if flags.contains(.maskCommand) { insert(.command) }
  }
}
