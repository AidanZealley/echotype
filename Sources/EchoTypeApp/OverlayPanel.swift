import AppKit
import EchoTypeCore
import SwiftUI

/// The floating panel that holds the pill at the bottom centre of a screen.
///
/// It must never take focus: if it became key or main, the target field would lose focus and
/// the insertion would go nowhere. So the window is private, cannot become key or main, is
/// non-activating, and is only ever ordered front with `orderFrontRegardless()`. Clicks reach
/// it without activating the app and are reported to the owner rather than handled.
@MainActor final class OverlayPanel {
  private let panel: Panel
  private let hosting: NSHostingView<PillView>
  /// Set while the fade-out runs, so a `show` during it keeps the panel on screen.
  private var isHiding = false

  init(onClick: @escaping @MainActor () -> Void) {
    // Replaced by the first `show`, before the panel is ever on screen.
    hosting = NSHostingView(rootView: PillView(pill: Pill(phase: .starting, startedAt: .now)))
    panel = Panel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: true)
    panel.onClick = onClick
    panel.isFloatingPanel = true
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    // A panel hides whenever its app is inactive by default, and this app never activates.
    panel.hidesOnDeactivate = false
    // The glass draws the pill's shape and shadow; the window draws nothing.
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.contentView = hosting
  }

  /// Shows the pill, or updates it if it is already showing, at the bottom centre of `screen`.
  func show(_ pill: Pill, on screen: NSScreen) {
    hosting.rootView = PillView(pill: pill)
    let size = hosting.fittingSize
    let area = screen.visibleFrame
    let origin = NSPoint(x: area.midX - size.width / 2, y: area.minY + 12)
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
    guard isHiding || !panel.isVisible else { return }
    isHiding = false
    // A zero-length animation, not a plain `alphaValue = 1`, so it replaces an in-flight
    // fade-out, which would otherwise overwrite the plain assignment as it runs.
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0
      panel.animator().alphaValue = 1
    }
    panel.orderFrontRegardless()
  }

  /// Fades the pill out.
  func hide() {
    guard panel.isVisible, !isHiding else { return }
    isHiding = true
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.3
      panel.animator().alphaValue = 0
    } completionHandler: {
      MainActor.assumeIsolated {
        guard self.isHiding else { return }
        self.isHiding = false
        self.panel.orderOut(nil)
      }
    }
  }
}

private final class Panel: NSPanel {
  var onClick: @MainActor () -> Void = {}

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// Any click on the pill goes to the owner. Nothing inside the pill handles clicks itself.
  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown {
      onClick()
    } else {
      super.sendEvent(event)
    }
  }
}

extension NSScreen {
  /// The screen for a session's pill: the one holding the frontmost app's focused window, or
  /// the one under the mouse when there is no focused window.
  @MainActor static func forFocusedWindow() -> NSScreen? {
    if let window = focusedWindowFrame(),
      let index = Overlay.screenIndex(holding: window, among: screens.map(\.frame))
    {
      return screens[index]
    }
    let mouse = NSEvent.mouseLocation
    return screens.first { $0.frame.contains(mouse) } ?? main
  }

  /// The focused window's frame in Accessibility coordinates, if Accessibility can say.
  @MainActor private static func focusedWindowFrame() -> CGRect? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    guard let window: AXUIElement = copy(kAXFocusedWindowAttribute, of: element),
      let position: AXValue = copy(kAXPositionAttribute, of: window),
      let size: AXValue = copy(kAXSizeAttribute, of: window)
    else { return nil }
    var frame = CGRect.zero
    guard AXValueGetValue(position, .cgPoint, &frame.origin),
      AXValueGetValue(size, .cgSize, &frame.size)
    else { return nil }
    return frame
  }

  /// Reads one attribute with a short timeout. The lookup runs on the main thread, which also
  /// serves the event tap, and a timeout set on one element does not carry to the elements
  /// read from it, so each read bounds its own. A hung app would otherwise hold both for the
  /// default six seconds per read.
  private static func copy<T>(_ attribute: String, of element: AXUIElement) -> T? {
    AXUIElementSetMessagingTimeout(element, 0.25)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
    else { return nil }
    return value as? T
  }
}
