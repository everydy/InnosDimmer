import XCTest
@testable import InnosDimmer

final class BrightnessStateTests: XCTestCase {
    func testBrightnessStateClampsBrightnessAndWarmth() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 140,
            targetWarmth: -20,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: false,
            automationPausedAtMinuteOfDay: nil,
            automationResumeMinuteOfDay: nil,
            lastAppliedCommandSource: nil,
            isForcedSoftwareModeForTesting: false
        )

        XCTAssertEqual(state.targetBrightness, 100)
        XCTAssertEqual(state.targetWarmth, 0)
    }

    func testForcedSoftwareModeDefaultsToFalse() {
        let state = BrightnessState.defaultState()

        XCTAssertFalse(state.isForcedSoftwareModeForTesting)
        XCTAssertEqual(state.activeMode, .unknown)
    }

    func testAutomationResumeMinuteIsBoundedToDay() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 80,
            targetWarmth: 12,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: true,
            automationPausedAtMinuteOfDay: -50,
            automationResumeMinuteOfDay: 2_000,
            lastAppliedCommandSource: nil,
            isForcedSoftwareModeForTesting: false
        )

        XCTAssertEqual(state.automationPausedAtMinuteOfDay, 0)
        XCTAssertEqual(state.automationResumeMinuteOfDay, 1_439)
    }
}
