import AppKit

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func start() {
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "InnosDimmer")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    @objc private func togglePopover() {
        // The detailed popover UI is added in the menu bar UI commit.
    }
}
