import AppKit
import XCTest
@testable import InnosDimmer

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppDelegateConfiguresAccessoryMenuBarShell() {
        let previousMainMenu = NSApp.mainMenu
        let delegate = AppDelegate()
        defer {
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            NSApp.mainMenu = previousMainMenu
        }

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertNotNil(delegate.menuBarControllerForTesting)
    }

    @MainActor
    func testApplicationMenuProvidesStandardCommandQQuitItem() {
        let menu = AppDelegate.makeApplicationMenu(for: NSApp)

        let quitItems = menu.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .filter { $0.title == "Quit InnosDimmer" }

        XCTAssertEqual(menu.title, "InnosDimmer")
        XCTAssertEqual(menu.items.first?.title, "InnosDimmer")
        XCTAssertEqual(menu.items.first?.submenu?.title, "InnosDimmer")
        XCTAssertEqual(quitItems.count, 1)
        XCTAssertEqual(quitItems.first?.keyEquivalent, "q")
        XCTAssertEqual(quitItems.first?.keyEquivalentModifierMask, [.command])
        XCTAssertEqual(quitItems.first?.action, #selector(NSApplication.terminate(_:)))
        XCTAssertTrue(quitItems.first?.target === NSApp)
    }

    @MainActor
    func testRepeatedStartupInstallsExactlyOneQuitItem() {
        let previousMainMenu = NSApp.mainMenu
        let delegate = AppDelegate()
        defer {
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            NSApp.mainMenu = previousMainMenu
        }
        NSApp.mainMenu = NSMenu(title: "Sentinel")

        delegate.startIfNeeded()
        let firstController = delegate.menuBarControllerForTesting
        delegate.startIfNeeded()

        let quitItems = NSApp.mainMenu?.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .filter { $0.title == "Quit InnosDimmer" } ?? []
        XCTAssertTrue(delegate.menuBarControllerForTesting === firstController)
        XCTAssertEqual(quitItems.count, 1)
    }

    @MainActor
    func testAppEntryPointRetainsSharedAppDelegate() {
        XCTAssertTrue(InnosDimmerApp.appDelegateForTesting === InnosDimmerApp.appDelegateForTesting)
    }
}
