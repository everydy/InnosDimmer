import XCTest
@testable import InnosDimmer

final class BrightnessStateTests: XCTestCase {
    func testBrightnessStateClampsBrightnessAndBlueReduction() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 140,
            targetBlueReduction: -20,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: false,
            automationPausedAtMinuteOfDay: nil,
            automationResumeMinuteOfDay: nil,
            lastAppliedCommandSource: nil
        )

        XCTAssertEqual(state.targetBrightness, 100)
        XCTAssertEqual(state.targetBlueReduction, 0)
    }

    func testDefaultStateStartsUnknown() {
        let state = BrightnessState.defaultState()

        XCTAssertEqual(state.activeMode, .unknown)
    }

    func testAutomationResumeMinuteIsBoundedToDay() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 80,
            targetBlueReduction: 12,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: true,
            automationPausedAtMinuteOfDay: -50,
            automationResumeMinuteOfDay: 2_000,
            lastAppliedCommandSource: nil
        )

        XCTAssertEqual(state.automationPausedAtMinuteOfDay, 0)
        XCTAssertEqual(state.automationResumeMinuteOfDay, 1_439)
    }
}
