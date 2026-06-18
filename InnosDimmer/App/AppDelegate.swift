import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var didStart = false

    var menuBarControllerForTesting: MenuBarController? {
        menuBarController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startIfNeeded()
    }

    func startIfNeeded() {
        guard !didStart else {
            return
        }

        didStart = true
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
        menuBarController?.start()
    }
}
