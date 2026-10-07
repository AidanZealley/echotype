import AppKit

/// Retains the Accessibility objects, rather than reconstructing identity from text or PID.
struct Destination {
  fileprivate let application: AXUIElement
  fileprivate let window: AXUIElement
  fileprivate let target: AXUIElement
  fileprivate let pid: pid_t

  init(application: AXUIElement, window: AXUIElement, target: AXUIElement, pid: pid_t) {
    self.application = application
    self.window = window
    self.target = target
    self.pid = pid
  }
}

enum DestinationVerification: String {
  case matching, changed, unavailable
}

/// Each lookup is bounded and capture samples twice. A changed sample must never silently
/// adopt the field that happened to become focused while Accessibility was answering.
@MainActor struct DestinationFocus {
  private let lookup: () -> Destination?
  // Focus helpers are recreated for each probe, so activation timing is shared.
  private static var accessibilityActivation = AccessibilityActivation()

  struct AccessibilityActivation {
    private var requestedAt: [pid_t: TimeInterval] = [:]

    mutating func shouldRequest(for pid: pid_t, at now: TimeInterval) -> Bool {
      // Electron restarts a two-second debounce on every enable request. Leave it time
      // to finish, while allowing another attempt if activation failed or was disabled.
      if let last = requestedAt[pid], now - last < 3 { return false }
      requestedAt = requestedAt.filter { now - $0.value < 3 }
      requestedAt[pid] = now
      return true
    }
  }

  init() { lookup = Self.focusedDestination }

  init(lookup: @escaping () -> Destination?) { self.lookup = lookup }

  func capture() -> Destination? {
    guard let first = lookup(), let second = lookup(), Self.same(first, second) else { return nil }
    return first
  }

  func verify(_ destination: Destination?) -> DestinationVerification {
    guard let destination, let current = capture() else { return .unavailable }
    return Self.same(destination, current) ? .matching : .changed
  }

  /// The caret or selection in UTF-16 offsets. Nil means the field does not expose it.
  static func selectedRange(_ destination: Destination?) -> CFRange? {
    guard let destination,
      let value = attribute(kAXSelectedTextRangeAttribute, of: destination.target),
      CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var range = CFRange()
    return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
  }

  /// The text in a UTF-16 range, bounded like every other lookup. Nil means the read failed.
  static func string(_ destination: Destination?, in range: CFRange) -> String? {
    var range = range
    guard let destination, let parameter = AXValueCreate(.cfRange, &range),
      AXUIElementSetMessagingTimeout(destination.target, 0.1) == .success else { return nil }
    var value: CFTypeRef?
    guard AXUIElementCopyParameterizedAttributeValue(
      destination.target, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value)
      == .success else { return nil }
    return value as? String
  }

  private static func same(_ lhs: Destination, _ rhs: Destination) -> Bool {
    lhs.pid == rhs.pid && CFEqual(lhs.application, rhs.application)
      && CFEqual(lhs.window, rhs.window) && CFEqual(lhs.target, rhs.target)
  }

  private static func focusedDestination() -> Destination? {
    guard let frontmost = NSWorkspace.shared.frontmostApplication else { return nil }
    let pid = frontmost.processIdentifier
    let application = AXUIElementCreateApplication(pid)
    // Electron can hide its focused web field until an assistive client enables its tree.
    // Request that support where offered, then apply the same destination identity checks.
    if let manualAccessibility = attribute("AXManualAccessibility", of: application),
      CFEqual(manualAccessibility, kCFBooleanFalse),
      accessibilityActivation.shouldRequest(for: pid, at: ProcessInfo.processInfo.systemUptime)
    {
      _ = AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
    guard let window = element(kAXFocusedWindowAttribute, of: application),
      let target = element(kAXFocusedUIElementAttribute, of: application),
      let role = attribute(kAXRoleAttribute, of: target) as? String,
      [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
      let targetWindow = element(kAXWindowAttribute, of: target), CFEqual(window, targetWindow),
      acceptsEnabledAttribute(attributeResult(kAXEnabledAttribute, of: target)),
      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    else { return nil }
    return Destination(application: application, window: window, target: target, pid: pid)
  }

  private static func element(_ name: String, of element: AXUIElement) -> AXUIElement? {
    guard let value = attribute(name, of: element),
      CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
  }

  private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
    let result = attributeResult(name, of: element)
    return result.error == .success ? result.value : nil
  }

  /// Some focused text areas omit AXEnabled. Unsupported is a capability omission,
  /// not a disabled target or a failed identity lookup. All other errors reject focus.
  static func acceptsEnabledAttribute(_ result: (error: AXError, value: CFTypeRef?)) -> Bool {
    if result.error == .attributeUnsupported { return true }
    guard result.error == .success, let value = result.value,
      CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
    return CFEqual(value, kCFBooleanTrue)
  }

  private static func attributeResult(_ name: String, of element: AXUIElement)
    -> (error: AXError, value: CFTypeRef?)
  {
    let timeout = AXUIElementSetMessagingTimeout(element, 0.1)
    guard timeout == .success else { return (timeout, nil) }
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return (error, value)
  }
}
