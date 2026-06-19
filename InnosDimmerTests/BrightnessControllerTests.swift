import XCTest
@testable import InnosDimmer

final class BrightnessControllerTests: XCTestCase {
    @MainActor
    func testAlwaysRoutesCommandsToSoftwareDimming() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .menuSlider))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .menuSlider)])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testStartupRestoreAppliesSoftwareDimmingImmediately() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .startupRestore))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .startupRestore)])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testScheduleAppliesSoftwareDimmingImmediately() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.apply(.fixture(source: .schedule))

        XCTAssertEqual(software.appliedCommands, [.fixture(source: .schedule)])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testReapplyCurrentSoftwareStateUsesCurrentTargets() {
        var state = BrightnessState.defaultState()
        state.display = BrightnessCommand.fixture(source: .startupRestore).display
        state.targetBrightness = 35
        state.targetBlueReduction = 40
        state.lastAppliedCommandSource = .hotkey
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.reapplyCurrentSoftwareState()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [35])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [40])
        XCTAssertEqual(software.appliedCommands.map(\.source), [.hotkey])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testClearStaleSoftwarePanelsForwardsActiveDisplayIDs() {
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), softwareStrategy: software)

        controller.clearStaleSoftwarePanels(activeDisplayIDs: [1, 2])

        XCTAssertEqual(software.activeDisplayIDCalls, [[1, 2]])
    }

    @MainActor
    func testClearCurrentSoftwareStateRestoresCurrentDisplay() {
        let command = BrightnessCommand.fixture(source: .menuSlider)
        let software = RecordingPolicySoftwareDimmingStrategy()
        var state = BrightnessState.defaultState()
        state.display = command.display
        state.targetBrightness = command.brightness
        state.targetBlueReduction = command.blueReduction
        state.activeMode = .overlay
        state.lastAppliedCommandSource = command.source
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.clearCurrentSoftwareState()

        XCTAssertEqual(software.clearedDisplays, [command.display])
        XCTAssertEqual(controller.state.activeMode, .unknown)
        XCTAssertNil(controller.lastSoftwareDimmingFailure)
    }
}

@MainActor
private final class RecordingPolicySoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var activeDisplayIDCalls: [Set<UInt32>] = []
    private(set) var clearedDisplays: [DisplayIdentity] = []

    func apply(_ command: BrightnessCommand) throws {
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {
        clearedDisplays.append(display)
    }

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
            blueReduction: 32,
            source: source,
            issuedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
