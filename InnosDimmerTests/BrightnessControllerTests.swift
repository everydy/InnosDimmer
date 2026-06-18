import XCTest
@testable import InnosDimmer

final class BrightnessControllerTests: XCTestCase {
    @MainActor
    func testAlwaysRoutesCommandsToSoftwareDimming() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .writeReadbackSupported(range: 0...100)
        let hardware = RecordingHardwareBrightnessStrategy()
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .menuSlider))

        XCTAssertEqual(hardware.appliedCommands.count, 0)
        XCTAssertEqual(software.appliedCommands, [.fixture(source: .menuSlider)])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareOnlyModeDoesNotQueueWhenHardwareIsNotProbed() {
        let hardware = RecordingHardwareBrightnessStrategy()
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .startupRestore))

        XCTAssertNil(controller.pendingCommand)
        XCTAssertEqual(hardware.appliedCommands.count, 0)
        XCTAssertEqual(software.appliedCommands, [.fixture(source: .startupRestore)])
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    @MainActor
    func testSoftwareOnlyModeIgnoresProbeAndReadOnlyHardwareStates() {
        let softwareCapabilities: [HardwareCapability] = [
            .probing(startedAt: Date(timeIntervalSince1970: 1)),
            .readSupported(current: 50)
        ]

        for capability in softwareCapabilities {
            var state = BrightnessState.defaultState()
            state.hardwareCapability = capability
            let hardware = RecordingHardwareBrightnessStrategy()
            let software = RecordingPolicySoftwareDimmingStrategy()
            let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

            controller.apply(.fixture(source: .schedule))

            XCTAssertNil(controller.pendingCommand)
            XCTAssertEqual(hardware.appliedCommands.count, 0)
            XCTAssertEqual(software.appliedCommands, [.fixture(source: .schedule)])
            XCTAssertEqual(software.activationReasons, [.softwareOnly])
            XCTAssertEqual(controller.state.activeMode, .overlay)
        }
    }

    @MainActor
    func testSoftwareOnlyModeIgnoresHardwareFailureStates() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .failedWithError(message: "write/readback failed")
        let hardware = RecordingHardwareBrightnessStrategy()
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .hotkey))

        XCTAssertEqual(hardware.appliedCommands.count, 0)
        XCTAssertEqual(software.activationReasons, [.softwareOnly])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }
}

private final class RecordingHardwareBrightnessStrategy: HardwareBrightnessStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func applyHardware(_ command: BrightnessCommand) throws {
        appliedCommands.append(command)
        if let error {
            throw error
        }
    }
}

@MainActor
private final class RecordingPolicySoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var activationReasons: [SoftwareActivationReason] = []

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        appliedCommands.append(command)
        activationReasons.append(reason)
    }

    func clear(display: DisplayIdentity) throws {}
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
