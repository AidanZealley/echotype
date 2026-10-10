import AppKit
import SwiftUI

/// AppKit owns the sidebar's material and safe area, while the existing pages stay in SwiftUI.
/// Unlike navigation stacks, a sidebar split item can explicitly prohibit collapsing.
struct SettingsSplitView<Sidebar: View, Detail: View>: NSViewControllerRepresentable {
  let title: String
  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let detail: () -> Detail

  func makeNSViewController(context: Context) -> NSSplitViewController {
    let controller = SettingsSplitController()
    controller.pageTitle = title
    controller.splitView.isVertical = true
    controller.splitView.dividerStyle = .thin

    let sidebarItem = NSSplitViewItem(
      sidebarWithViewController: NSHostingController(rootView: sidebar()))
    sidebarItem.canCollapse = false
    sidebarItem.minimumThickness = 170
    sidebarItem.maximumThickness = 240
    sidebarItem.preferredThicknessFraction = 170.0 / 790.0
    controller.addSplitViewItem(sidebarItem)

    let detailItem = NSSplitViewItem(viewController: NSHostingController(rootView: detail()))
    detailItem.minimumThickness = 550
    controller.addSplitViewItem(detailItem)
    return controller
  }

  func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
    (controller as? SettingsSplitController)?.pageTitle = title
    (controller.splitViewItems[0].viewController as? NSHostingController<Sidebar>)?.rootView =
      sidebar()
    (controller.splitViewItems[1].viewController as? NSHostingController<Detail>)?.rootView =
      detail()
  }
}

/// The toolbar owns header height, material and title placement. The label is ordinary AppKit
/// content in a native toolbar item, not a separate header inside the detail's safe area.
private final class SettingsSplitController: NSSplitViewController, NSToolbarDelegate {
  private static let separatorID = NSToolbarItem.Identifier("settings-sidebar-separator")
  private static let titleID = NSToolbarItem.Identifier("settings-page-title")
  private let titleLabel = NSTextField(labelWithString: "")
  private lazy var settingsToolbar: NSToolbar = {
    let toolbar = NSToolbar(identifier: "settings-toolbar")
    toolbar.delegate = self
    toolbar.displayMode = .iconOnly
    toolbar.allowsUserCustomization = false
    return toolbar
  }()

  var pageTitle = "" {
    didSet {
      titleLabel.stringValue = pageTitle
      titleLabel.sizeToFit()
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    guard let window = view.window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = false
    window.toolbarStyle = .unifiedCompact
    window.toolbar = settingsToolbar
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [Self.separatorID, .space, Self.titleID, .flexibleSpace]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    if identifier == Self.separatorID {
      return NSTrackingSeparatorToolbarItem(
        identifier: identifier, splitView: splitView, dividerIndex: 0)
    }
    guard identifier == Self.titleID else { return nil }
    titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    titleLabel.sizeToFit()
    let item = NSToolbarItem(itemIdentifier: identifier)
    item.label = "Page"
    item.view = titleLabel
    item.visibilityPriority = .high
    return item
  }
}
