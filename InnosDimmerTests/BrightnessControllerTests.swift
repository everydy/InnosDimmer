import XCTest
@testable import InnosDimmer

final class BrightnessControllerTests: XCTestCase {
    @MainActor
    func testAlwaysRoutesCommandsToSoftwareDimming() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .menuSlider))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .menuSlider)])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareOnlyModeDoesNotQueueWhenHardwareIsNotProbed() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .startupRestore))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .startupRestore)])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareOnlyModeRoutesScheduleWithoutCapabilityChecks() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .schedule))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .schedule)])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testReapplyCurrentSoftwareStateUsesCurrentTargets() {
        var state = BrightnessState.defaultState()
        state.display = BrightnessCommand.fixture(source: .startupRestore).display
        state.targetBrightness = 35
        state.targetWarmth = 40
        state.lastAppliedCommandSource = .hotkey
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.reapplyCurrentSoftwareState()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [35])
        XCTAssertEqual(software.appliedCommands.map(\.warmth), [40])
        XCTAssertEqual(software.appliedCommands.map(\.source), [.hotkey])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testClearStaleSoftwarePanelsForwardsActiveDisplayIDs() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.clearStaleSoftwarePanels(activeDisplayIDs: [1, 2])

        XCTAssertEqual(software.activeDisplayIDCalls, [[1, 2]])
    }
}

@MainActor
private final class RecordingPolicySoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var activationReasons: [SoftwareActivationReason] = []
    private(set) var activeDisplayIDCalls: [Set<UInt32>] = []

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        appliedCommands.append(command)
        activationReasons.append(reason)
    }

    func clear(display: DisplayIdentity) throws {}

    func clearStalePanels(activeDisplayIDs: Set<UInt32>) {
        activeDisplayIDCalls.append(activeDisplayIDs)
    }
}

private extension BrightnessCommand {
    static func fixture(source: BrightnessCommandSource) -> BrightnessCommand {
        BrightnessCommand(
            display: DisplayIdentity(
                cgDisplayID: 1,
                localizedName: "INNOS 27QA100M",
                vendorNumber: 1,
                modelNumber: 2,
                serialNumber: 3,
                frameDescription: "2560x1440"
            ),
            brightness: 45,
            warmth: 32,
            source: source,
            issuedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
