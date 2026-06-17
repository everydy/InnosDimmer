import XCTest
@testable import InnosDimmer

final class BrightnessControllerTests: XCTestCase {
    func testRoutesToHardwareOnlyAfterWriteReadbackSupport() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .writeReadbackSupported(range: 0...100)
        let hardware = RecordingHardwareBrightnessStrategy()
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .menuSlider))

        XCTAssertEqual(hardware.appliedCommands.count, 1)
        XCTAssertEqual(software.appliedCommands.count, 0)
        XCTAssertEqual(controller.state.activeMode, .hardwareDDC)
    }

    func testQueuesWhenHardwareIsNotProbed() {
        let hardware = RecordingHardwareBrightnessStrategy()
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: .defaultState(), hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .startupRestore))

        XCTAssertEqual(controller.pendingCommand, .fixture(source: .startupRestore))
        XCTAssertEqual(hardware.appliedCommands.count, 0)
        XCTAssertEqual(software.appliedCommands.count, 0)
        XCTAssertEqual(controller.state.activeMode, .unknown)
    }

    func testQueuesWhileHardwareProbeIsInProgressOrReadOnly() {
        let queuedCapabilities: [HardwareCapability] = [
            .probing(startedAt: Date(timeIntervalSince1970: 1)),
            .readSupported(current: 50)
        ]

        for capability in queuedCapabilities {
            var state = BrightnessState.defaultState()
            state.hardwareCapability = capability
            let hardware = RecordingHardwareBrightnessStrategy()
            let software = RecordingPolicySoftwareDimmingStrategy()
            let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

            controller.apply(.fixture(source: .schedule))

            XCTAssertEqual(controller.pendingCommand, .fixture(source: .schedule))
            XCTAssertEqual(hardware.appliedCommands.count, 0)
            XCTAssertEqual(software.appliedCommands.count, 0)
            XCTAssertEqual(controller.state.activeMode, .unknown)
        }
    }

    func testFallsBackToSoftwareOnlyAfterHardwareFailureIsExhausted() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .failedWithError(message: "write/readback failed")
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, softwareStrategy: software)

        controller.apply(.fixture(source: .hotkey))

        XCTAssertEqual(software.activationReasons, [.hardwareExhausted(.failedWithError(message: "write/readback failed"))])
        XCTAssertEqual(controller.state.activeMode, .overlay)
    }

    func testHardwareWriteFailureRecordsFailureAndFallsBackToSoftware() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .writeReadbackSupported(range: 0...100)
        let hardware = RecordingHardwareBrightnessStrategy(error: HardwareBrightnessTestError.writeFailed)
        let software = RecordingPolicySoftwareDimmingStrategy()
        let controller = BrightnessController(state: state, hardwareStrategy: hardware, softwareStrategy: software)

        controller.apply(.fixture(source: .menuSlider))

        XCTAssertEqual(hardware.appliedCommands.count, 1)
        XCTAssertEqual(software.appliedCommands.count, 1)
        XCTAssertEqual(controller.state.hardwareCapability, .failedWithError(message: "writeFailed"))
        XCTAssertEqual(software.activationReasons, [.hardwareExhausted(.failedWithError(message: "writeFailed"))])
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

private final class RecordingPolicySoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var activationReasons: [SoftwareActivationReason] = []

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        appliedCommands.append(command)
        activationReasons.append(reason)
    }

    func clear(display: DisplayIdentity) throws {}
}

private enum HardwareBrightnessTestError: Error {
    case writeFailed
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
