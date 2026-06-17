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

    func testNormalStartupDoesNotApplySoftwareWhileHardwareIsNotProbed() {
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

        XCTAssertEqual(software.appliedCommands.count, 0)
    }

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

    func testHardwareExhaustedFailureAppliesSoftwareWithVisibleReason() {
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
        XCTAssertEqual(software.activationReasons, [.hardwareExhausted(.unsupported(reason: "DDC unavailable"))])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

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

    func testOverlayPanelConfigurationIsClickThroughAndAllSpaces() {
        let panel = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)

        OverlayWindowManager.configureOverlayPanel(panel, for: NSRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(panel.hasShadow)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
    }
}

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
    static func fixture() -> DisplayIdentity {
        DisplayIdentity(
            cgDisplayID: 1,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440"
        )
    }
}
