import AppKit
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
