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

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stop()
    }

    func startIfNeeded() {
        guard !didStart else {
            return
        }

        didStart = true
        terminateOtherRunningInstances()
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = Self.makeApplicationMenu(for: NSApp)
        menuBarController = MenuBarController()
        menuBarController?.start()
    }

    static func makeApplicationMenu(for application: NSApplication) -> NSMenu {
        let mainMenu = NSMenu(title: "InnosDimmer")
        let applicationItem = NSMenuItem(title: "InnosDimmer", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "InnosDimmer")
        let quitItem = NSMenuItem(
            title: "Quit InnosDimmer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = application
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        return mainMenu
    }

    private func terminateOtherRunningInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            where app.processIdentifier != currentPID {
            app.terminate()
        }
    }
}
