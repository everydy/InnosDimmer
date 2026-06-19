import AppKit
import XCTest
@testable import InnosDimmer

final class SoftwareDimmingControllerTests: XCTestCase {
    func testOverlayAppearanceMapsBrightnessToBlackOpacityOnly() {
        let appearance = OverlayAppearance.make(brightness: 45, blueReduction: 32)

        XCTAssertEqual(appearance.blackOpacity, CGFloat(55) / 130.0)
        XCTAssertEqual(appearance.warmOpacity, 0)
    }

    func testOverlayAppearanceClampsInputs() {
        let appearance = OverlayAppearance.make(brightness: 140, blueReduction: -10)

        XCTAssertEqual(appearance.blackOpacity, 0)
        XCTAssertEqual(appearance.warmOpacity, 0)
    }

    func testOverlayAppearanceUsesMinimumVisibleBrightnessFloor() {
        let appearance = OverlayAppearance.make(brightness: 0, blueReduction: 0)

        XCTAssertEqual(appearance.blackOpacity, CGFloat(90) / 130.0)
        XCTAssertEqual(appearance.warmOpacity, 0)
    }

    func testGammaBlueReductionScalesOnlyBlueChannelAndRestoresOriginalTable() throws {
        let display = DisplayIdentity.fixture(cgDisplayID: 2, localizedName: "27QA100M")
        let original = GammaTableSnapshot(
            red: [0, 0.5, 1],
            green: [0, 0.25, 1],
            blue: [0, 0.5, 1]
        )
        let tableController = RecordingGammaTableController(tables: [display.cgDisplayID: original])
        let controller = GammaDimmingController(tableController: tableController)

        try controller.apply(display: display, blueReduction: 20)

        XCTAssertEqual(tableController.setCalls.count, 1)
        let reduced = tableController.setCalls[0].table
        XCTAssertEqual(reduced.red, original.red)
        XCTAssertEqual(reduced.green, original.green)
        XCTAssertEqual(reduced.blue[0], 0, accuracy: 0.0001)
        XCTAssertEqual(reduced.blue[1], 0.4744, accuracy: 0.0001)
        XCTAssertEqual(reduced.blue[2], 0.9488, accuracy: 0.0001)
        XCTAssertTrue(controller.hasOriginalTableForTesting(displayID: display.cgDisplayID))

        try controller.clear(display: display)

        XCTAssertEqual(tableController.setCalls.count, 2)
        XCTAssertEqual(tableController.setCalls[1].table, original)
        XCTAssertFalse(controller.hasOriginalTableForTesting(displayID: display.cgDisplayID))
    }

    func testGammaBlueReductionUsesGentleLowEndCurve() {
        XCTAssertEqual(GammaDimmingController.blueScale(for: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(GammaDimmingController.blueScale(for: 20), 0.9488, accuracy: 0.0001)
        XCTAssertEqual(GammaDimmingController.blueScale(for: 40), 0.8694, accuracy: 0.0001)
        XCTAssertEqual(GammaDimmingController.blueScale(for: 50), 0.8235, accuracy: 0.0001)
        XCTAssertEqual(GammaDimmingController.blueScale(for: 100), 0.55, accuracy: 0.0001)
    }

    func testGammaBlueReductionZeroRestoresOriginalTable() throws {
        let display = DisplayIdentity.fixture(cgDisplayID: 2, localizedName: "27QA100M")
        let original = GammaTableSnapshot(red: [0, 1], green: [0, 1], blue: [0, 1])
        let tableController = RecordingGammaTableController(tables: [display.cgDisplayID: original])
        let controller = GammaDimmingController(tableController: tableController)

        try controller.apply(display: display, blueReduction: 35)
        try controller.apply(display: display, blueReduction: 0)

        XCTAssertEqual(tableController.setCalls.count, 2)
        XCTAssertEqual(tableController.setCalls[1].table, original)
        XCTAssertFalse(controller.hasOriginalTableForTesting(displayID: display.cgDisplayID))
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
            blueReduction: 20,
            source: .startupRestore
        ))

        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testRegularCommandsApplySoftwareDimmingImmediately() {
        let software = RecordingSoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 45,
            blueReduction: 32,
            source: .menuSlider
        ))

        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareApplyFailureRecordsPlatformBlockedState() {
        let software = RecordingSoftwareDimmingStrategy(error: SoftwareDimmingError.platformBlocked("protected surface"))
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(BrightnessCommand(
            display: DisplayIdentity.fixture(),
            brightness: 45,
            blueReduction: 32,
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
        state.targetBlueReduction = 22
        state.lastAppliedCommandSource = .hotkey
        let controller = BrightnessController(state: state, softwareStrategy: software)
        let failedCommand = BrightnessCommand(
            display: DisplayIdentity.fixture(cgDisplayID: 404, localizedName: "Missing"),
            brightness: 20,
            blueReduction: 80,
            source: .menuSlider
        )

        controller.apply(failedCommand)

        XCTAssertEqual(controller.state.activeMode, .platformBlocked)
        XCTAssertEqual(controller.state.display?.localizedName, "Previous")
        XCTAssertEqual(controller.state.targetBrightness, 67)
        XCTAssertEqual(controller.state.targetBlueReduction, 22)
        XCTAssertEqual(controller.state.lastAppliedCommandSource, .hotkey)
        XCTAssertEqual(controller.lastSoftwareDimmingFailure?.command, failedCommand)
        XCTAssertEqual(
            controller.lastSoftwareDimmingFailure?.message,
            "Display 404 is not currently available for software dimming."
        )
    }

    @MainActor
    func testOverlayPanelConfigurationIsClickThroughAndAllSpaces() {
        let panel = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)

        OverlayWindowManager.configureOverlayPanel(panel, for: NSRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.hidesOnDeactivate)
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
        let frame = NSRect(x: 123, y: 456, width: 321, height: 222)
        let display = DisplayIdentity.fixture(cgDisplayID: 777, localizedName: "Frame Test")
        let manager = OverlayWindowManager { candidate in
            candidate.cgDisplayID == display.cgDisplayID ? frame : nil
        }

        try manager.apply(display: display, brightness: 45, blueReduction: 32)
        defer {
            manager.clear(display: display)
        }

        let overlayPanel = try XCTUnwrap(app.windows.compactMap { $0 as? NSPanel }.first { panel in
            panel.level == .screenSaver
                && panel.ignoresMouseEvents
                && panel.contentView?.layer?.sublayers?.contains { $0.name == "InnosDimmer.dim" } == true
                && panel.frame.equalTo(frame)
        })

        XCTAssertEqual(overlayPanel.frame.origin.x, frame.origin.x, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.origin.y, frame.origin.y, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.size.width, frame.size.width, accuracy: 0.5)
        XCTAssertEqual(overlayPanel.frame.size.height, frame.size.height, accuracy: 0.5)
        let contentView = try XCTUnwrap(overlayPanel.contentView)
        XCTAssertEqual(contentView.bounds.size.width, frame.size.width, accuracy: 0.5)
        XCTAssertEqual(contentView.bounds.size.height, frame.size.height, accuracy: 0.5)
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

        XCTAssertNoThrow(try manager.apply(display: first, brightness: 45, blueReduction: 32))
        XCTAssertNoThrow(try manager.apply(display: second, brightness: 45, blueReduction: 32))
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

        XCTAssertThrowsError(try manager.apply(display: display, brightness: 45, blueReduction: 32)) { error in
            XCTAssertEqual(error as? SoftwareDimmingError, .displayUnavailable(404))
        }
        XCTAssertEqual(manager.managedDisplayIDsForTesting(), [])
    }
}

@MainActor
private final class RecordingSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func apply(_ command: BrightnessCommand) throws {
        if let error {
            throw error
        }
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {}
}

private final class RecordingGammaTableController: GammaTableControlling {
    struct SetCall {
        var displayID: CGDirectDisplayID
        var table: GammaTableSnapshot
    }

    var tables: [CGDirectDisplayID: GammaTableSnapshot]
    private(set) var setCalls: [SetCall] = []

    init(tables: [CGDirectDisplayID: GammaTableSnapshot]) {
        self.tables = tables
    }

    func capacity(for displayID: CGDirectDisplayID) -> UInt32 {
        UInt32(tables[displayID]?.red.count ?? 0)
    }

    func read(displayID: CGDirectDisplayID, capacity: UInt32) throws -> GammaTableSnapshot {
        _ = capacity
        guard let table = tables[displayID] else {
            throw SoftwareDimmingError.applyFailed("missing test gamma table")
        }
        return table
    }

    func set(displayID: CGDirectDisplayID, table: GammaTableSnapshot) throws {
        setCalls.append(SetCall(displayID: displayID, table: table))
        tables[displayID] = table
    }
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
