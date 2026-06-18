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
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .unsupported(reason: "DDC unavailable")
        let controller = BrightnessController(state: state, softwareStrategy: software)

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
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .unsupported(reason: "DDC unavailable")
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 45,
            warmth: 32,
            source: .menuSlider
        ))

        XCTAssertEqual(controller.state.activeMode, .platformBlocked)
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

        manager.apply(display: display, brightness: 45, warmth: 32)
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
