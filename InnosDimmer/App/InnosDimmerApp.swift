import AppKit

@MainActor
@main
struct InnosDimmerApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        appDelegate.startIfNeeded()
        app.run()
    }

    #if DEBUG
    static var appDelegateForTesting: AppDelegate {
        appDelegate
    }
    #endif
}
