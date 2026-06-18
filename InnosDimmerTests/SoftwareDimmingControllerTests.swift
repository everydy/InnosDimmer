import AppKit
import XCTest
@testable import InnosDimmer

final class SoftwareDimmingControllerTests: XCTestCase {
    func testOverlayAppearanceMapsBrightnessAndWarmthToOpacity() {
        let appearance = OverlayAppearance.make(brightness: 45, warmth: 32)

        XCTAssertEqual(appearance.blackOpacity, CGFloat(55) / 130.0)
        XCTAssertEqual(appearance.warmOpacity, CGFloat(32) / 180.0)
    }

    func testOverlayAppearanceClampsInputs() {
        let appearance = OverlayAppearance.make(brightness: 140, warmth: -10)

        XCTAssertEqual(appearance.blackOpacity, 0)
        XCTAssertEqual(appearance.warmOpacity, 0)
    }

    func testOverlayAppearanceUsesMinimumVisibleBrightnessFloor() {
        let appearance = OverlayAppearance.make(brightness: 0, warmth: 0)

        XCTAssertEqual(appearance.blackOpacity, CGFloat(90) / 130.0)
        XCTAssertEqual(appearance.warmOpacity, 0)
    }

    func testDisplayInventoryFallsBackToFirstNonMainDisplayWhenNoSavedTarget() {
        let main = DisplayIdentity.fixture(cgDisplayID: 1, localizedName: "Built-in Display")
        let external = DisplayIdentity.fixture(cgDisplayID: 2, localizedName: "INNOS 27QA100M")

        let selected = DisplayInventory.resolveSelectedDisplay(
            saved: nil,
            candidates: [main, external],
            mainDisplayID: main.cgDisplayID
        )

        XCTAssertEqual(selected, external)
    }

    func testDisplayInventoryDoesNotSilentlyChooseMainDisplayWithoutExternalTarget() {
        let main = DisplayIdentity.fixture(cgDisplayID: 1, localizedName: "Built-in Display")

        let selected = DisplayInventory.resolveSelectedDisplay(
            saved: nil,
            candidates: [main],
            mainDisplayID: main.cgDisplayID
        )

        XCTAssertNil(selected)
    }

    @MainActor
    func testNormalStartupAppliesSoftwareDimmingImmediately() {
        let software = RecordingSoftwareDimmingStrategy()
        let controller = BrightnessController(
            state: .defaultState(),
            softwareStrategy: software
        )

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 50,
            warmth: 20,
            source: .startupRestore
        ))

        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testForcedSoftwareTestAppliesSoftwareWithVisibleReason() {
        let software = RecordingSoftwareDimmingStrategy()
        var state = BrightnessState.defaultState()
        state.isForcedSoftwareModeForTesting = true
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 50,
            warmth: 20,
            source: .forcedSoftwareTest
        ))

        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(software.activationReasons, [.forcedForDiagnostics])
    }

    @MainActor
    func testRegularCommandsApplySoftwareOnlyEvenWhenHardwareIsUnsupported() {
        let software = RecordingSoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 45,
            warmth: 32,
            source: .menuSlider
        ))

        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareApplyFailureRecordsPlatformBlockedState() {
        let software = RecordingSoftwareDimmingStrategy(error: SoftwareDimmingError.platformBlocked("protected surface"))
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 45,
            warmth: 32,
            source: .menuSlider
        ))

        XCTAssertEqual(controller.state.activeMode, .platformBlocked)
        XCTAssertEqual(controller.lastSoftwareDimmingFailure?.message, "protected surface")
    }

    @MainActor
    func testSoftwareApplyFailurePreservesPreviousSuccessfulTargets() {
        let software = RecordingSoftwareDimmingStrategy(error: SoftwareDimmingError.displayUnavailable(404))
        var state = BrightnessState.defaultState()
        state.display = DisplayIdentity.fixture(cgDisplayID: 1, localizedName: "Previous")
        state.targetBrightness = 67
        state.targetWarmth = 22
        state.lastAppliedCommandSource = .hotkey
        let controller = BrightnessController(state: state, softwareStrategy: software)
        let failedCommand = BrightnessCommand(
            display: DisplayIdentity.fixture(cgDisplayID: 404, localizedName: "Missing"),
            brightness: 20,
            warmth: 80,
            source: .menuSlider
        )

        controller.apply(failedCommand)

        XCTAssertEqual(controller.state.activeMode, .platformBlocked)
        XCTAssertEqual(controller.state.display?.localizedName, "Previous")
        XCTAssertEqual(controller.state.targetBrightness, 67)
        XCTAssertEqual(controller.state.targetWarmth, 22)
        XCTAssertEqual(controller.state.lastAppliedCommandSource, .hotkey)
        XCTAssertEqual(controller.lastSoftwareDimmingFailure?.command, failedCommand)
        XCTAssertEqual(
            controller.lastSoftwareDimmingFailure?.message,
            "Display 404 is not currently available for overlay dimming."
        )
    }

    @MainActor
    func testOverlayPanelConfigurationIsClickThroughAndAllSpaces() {
        let panel = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)

        OverlayWindowManager.configureOverlayPanel(panel, for: NSRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @MainActor
    func testApplySetsOverlayPanelFrameToDisplayScreenFrame() throws {
        let app = NSApplication.shared
        guard let screen = NSScreen.screens.first,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw XCTSkip("No screen available for overlay frame test")
        }
        let display = DisplayIdentity(
            cgDisplayID: displayID.uint32Value,
            localizedName: screen.localizedName,
            vendorNumber: nil,
            modelNumber: nil,
            serialNumber: nil,
            frameDescription: "test"
        )
        let manager = OverlayWindowManager()

        try manager.apply(display: display, brightness: 45, warmth: 32)
        defer {
            manager.clear(display: display)
        }

        let overlayPanel = try XCTUnwrap(app.windows.compactMap { $0 as? NSPanel }.first { panel in
            panel.level == .screenSaver
                && panel.ignoresMouseEvents
                && panel.contentView?.layer?.sublayers?.contains { $0.name == "InnosDimmer.dim" } == true
        })

        XCTAssertEqual(overlayPanel.frame.origin.x, screen.frame.origin.x, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.origin.y, screen.frame.origin.y, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.size.width, screen.frame.size.width, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.size.height, screen.frame.size.height, accuracy: 0.5)
        let contentView = try XCTUnwrap(overlayPanel.contentView)
        XCTAssertEqual(contentView.bounds.size.width, screen.frame.size.width, accuracy: 0.5)
        XCTAssertEqual(contentView.bounds.size.height, screen.frame.size.height, accuracy: 0.5)
    }

    @MainActor
    func testClearPanelsExcludingActiveDisplayIDsRemovesStalePanels() {
        let first = DisplayIdentity.fixture(cgDisplayID: 101, localizedName: "First")
        let second = DisplayIdentity.fixture(cgDisplayID: 202, localizedName: "Second")
        let manager = OverlayWindowManager { display in
            if display.cgDisplayID == first.cgDisplayID {
                return NSRect(x: 0, y: 0, width: 100, height: 100)
            }
            if display.cgDisplayID == second.cgDisplayID {
                return NSRect(x: 100, y: 0, width: 100, height: 100)
            }
            return nil
        }

        XCTAssertNoThrow(try manager.apply(display: first, brightness: 45, warmth: 32))
        XCTAssertNoThrow(try manager.apply(display: second, brightness: 45, warmth: 32))
        manager.clearPanels(excluding: [first.cgDisplayID])
        defer {
            manager.clear(display: first)
            manager.clear(display: second)
        }

        XCTAssertEqual(manager.managedDisplayIDsForTesting(), [first.cgDisplayID])
    }

    @MainActor
    func testApplyThrowsWhenDisplayFrameIsUnavailable() {
        let display = DisplayIdentity.fixture(cgDisplayID: 404, localizedName: "Missing")
        let manager = OverlayWindowManager { _ in nil }

        XCTAssertThrowsError(try manager.apply(display: display, brightness: 45, warmth: 32)) { error in
            XCTAssertEqual(error as? SoftwareDimmingError, .displayUnavailable(404))
        }
        XCTAssertEqual(manager.managedDisplayIDsForTesting(), [])
    }
}

@MainActor
private final class RecordingSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var activationReasons: [SoftwareActivationReason] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        if let error {
            throw error
        }
        appliedCommands.append(command)
        activationReasons.append(reason)
    }

    func clear(display: DisplayIdentity) throws {}
}

private extension DisplayIdentity {
    static func fixture(cgDisplayID: UInt32 = 1, localizedName: String = "INNOS 27QA100M") -> DisplayIdentity {
        DisplayIdentity(
            cgDisplayID: cgDisplayID,
            localizedName: localizedName,
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440"
        )
    }
}
