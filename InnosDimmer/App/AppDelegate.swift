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
        menuBarController = MenuBarController()
        menuBarController?.start()
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
