import AppKit
import XCTest
@testable import InnosDimmer

final class SmokeTests: XCTestCase {
    func testAppDelegateConfiguresAccessoryMenuBarShell() {
        let delegate = AppDelegate()

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertNotNil(delegate.menuBarControllerForTesting)
    }
}
