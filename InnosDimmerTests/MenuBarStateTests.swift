import AppKit
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
        XCTAssertEqual(viewModel.shortcutSummary, "Shortcuts: 6 enabled")
        XCTAssertEqual(viewModel.diagnosticsSummary, "Diagnostics: Overlay active, DDC unsupported: DDC unavailable")
    }

    @MainActor
    func testMenuBarPopoverButtonsRouteEveryCommand() {
        var routedCommands: [MenuBarCommand] = []
        let view = MenuBarPopoverView(
            state: .defaultState(),
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )

        for command in MenuBarCommand.allCases {
            guard let button = view.commandButtonForTesting(command) else {
                XCTFail("Missing button for \(command)")
                continue
            }

            XCTAssertTrue(button.target === view)
            XCTAssertNotNil(button.action)
            button.performClick(nil)
        }

        XCTAssertEqual(routedCommands, MenuBarCommand.allCases)
    }

    @MainActor
    func testMenuBarControllerRoutesDimmingCommandsThroughBrightnessController() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let brightnessController = BrightnessController(state: state)
        let menuBarController = MenuBarController(brightnessController: brightnessController)

        menuBarController.perform(.brightnessUp)

        XCTAssertEqual(brightnessController.pendingCommand?.display, .menuBarTestDisplay)
        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 85)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .menuSlider)

        menuBarController.perform(.warmthDown)

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 80)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 7)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .menuSlider)
    }

    @MainActor
    func testMenuBarControllerRoutesQuickDisableAndRestoreThroughBrightnessController() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let brightnessController = BrightnessController(state: state)
        let menuBarController = MenuBarController(brightnessController: brightnessController)

        menuBarController.perform(.quickDisable)

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 100)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .menuSlider)

        menuBarController.perform(.restorePrevious)

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 80)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .menuSlider)
    }
}

private extension DisplayIdentity {
    static let menuBarTestDisplay = DisplayIdentity(
        cgDisplayID: 1,
        localizedName: "INNOS 27QA100M",
        vendorNumber: 1,
        modelNumber: 2,
        serialNumber: 3,
        frameDescription: "2560x1440"
    )
}
