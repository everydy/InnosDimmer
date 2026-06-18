import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let brightnessController: BrightnessController
    private let popover = NSPopover()

    init(brightnessController: BrightnessController = BrightnessController()) {
        self.brightnessController = brightnessController
        super.init()
    }

    func start() {
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "InnosDimmer")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 220)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = MenuBarPopoverView(state: brightnessController.state)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
