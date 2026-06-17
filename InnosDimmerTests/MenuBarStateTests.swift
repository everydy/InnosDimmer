import XCTest
@testable import InnosDimmer

final class MenuBarStateTests: XCTestCase {
    func testModeLabelsMatchReviewArtifactVocabulary() {
        XCTAssertEqual(ModeStatusLabel.title(for: .hardwareDDC), "Hardware DDC")
        XCTAssertEqual(ModeStatusLabel.title(for: .overlay), "Overlay active")
        XCTAssertEqual(ModeStatusLabel.title(for: .platformBlocked), "Platform blocked")
        XCTAssertEqual(ModeStatusLabel.title(for: .gamma), "Gamma active")
        XCTAssertEqual(ModeStatusLabel.title(for: .unknown), "Not probed")
    }

    func testMenuBarViewModelUsesStateValues() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 45,
            targetWarmth: 32,
            activeMode: .overlay,
            hardwareCapability: .unsupported(reason: "DDC unavailable"),
            automationPausedUntilNextBoundary: true,
            automationPausedAtMinuteOfDay: 1_000,
            automationResumeMinuteOfDay: 1_140,
            lastAppliedCommandSource: .menuSlider,
            isForcedSoftwareModeForTesting: false
        )

        let viewModel = MenuBarViewModel(state: state)

        XCTAssertEqual(viewModel.modeTitle, "Overlay active")
        XCTAssertEqual(viewModel.brightnessLabel, "45%")
        XCTAssertEqual(viewModel.warmthLabel, "32%")
        XCTAssertEqual(viewModel.automationTitle, "Automation paused until 19:00")
        XCTAssertEqual(viewModel.scheduleSummary, "Schedule: 09:00 / 19:00 / 23:00")
        XCTAssertEqual(viewModel.shortcutSummary, "Shortcuts: customizable")
    }
}
