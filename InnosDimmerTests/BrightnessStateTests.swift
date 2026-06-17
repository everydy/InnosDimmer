import XCTest
@testable import InnosDimmer

final class BrightnessStateTests: XCTestCase {
    func testBrightnessStateClampsBrightnessAndWarmth() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 140,
            targetWarmth: -20,
            activeMode: .unknown,
            hardwareCapability: .notProbed,
            automationPausedUntilNextBoundary: false,
            lastAppliedCommandSource: nil,
            isForcedSoftwareModeForTesting: false
        )

        XCTAssertEqual(state.targetBrightness, 100)
        XCTAssertEqual(state.targetWarmth, 0)
    }

    func testReadSupportedDoesNotAllowHardwareWrites() {
        XCTAssertFalse(HardwareCapability.readSupported(current: 50).allowsHardwareWrites)
        XCTAssertTrue(HardwareCapability.writeReadbackSupported(range: 0...100).allowsHardwareWrites)
    }

    func testForcedSoftwareModeDefaultsToFalse() {
        let state = BrightnessState.defaultState()

        XCTAssertFalse(state.isForcedSoftwareModeForTesting)
        XCTAssertEqual(state.activeMode, .unknown)
    }
}
