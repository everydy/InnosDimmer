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
        XCTAssertEqual(viewModel.displaySummary, "Display: Not selected")
        XCTAssertEqual(viewModel.brightnessLabel, "45%")
        XCTAssertEqual(viewModel.warmthLabel, "32%")
        XCTAssertEqual(viewModel.automationTitle, "Automation paused until 19:00")
        XCTAssertEqual(viewModel.scheduleSummary, "Schedule: 09:00 / 19:00 / 23:00")
        XCTAssertEqual(viewModel.shortcutSummary, "Shortcuts: 6 enabled")
        XCTAssertEqual(viewModel.diagnosticsSummary, "Diagnostics: Overlay active, DDC unsupported: DDC unavailable")
    }

    func testMenuBarViewModelIncludesDisplayAndLatestDiagnosticEvent() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let event = DiagnosticsEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            category: .softwareDimming,
            message: "Applied brightness 45% warmth 32% on INNOS 27QA100M",
            severity: .info
        )

        let viewModel = MenuBarViewModel(state: state, latestDiagnosticEvent: event)

        XCTAssertEqual(viewModel.displaySummary, "Display: INNOS 27QA100M")
        XCTAssertEqual(
            viewModel.diagnosticsSummary,
            "Diagnostics: Not probed, DDC not probed. Last: Applied brightness 45% warmth 32% on INNOS 27QA100M"
        )
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
    func testMenuBarPopoverUpdateRefreshesVisibleStateAndDiagnostics() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let view = MenuBarPopoverView(state: state)
        state.targetBrightness = 45
        state.targetWarmth = 32
        state.activeMode = .overlay
        state.hardwareCapability = .unsupported(reason: "DDC unavailable")
        let event = DiagnosticsEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            category: .softwareDimming,
            message: "Applied brightness 45% warmth 32% on INNOS 27QA100M",
            severity: .info
        )

        view.update(state: state, latestDiagnosticEvent: event)

        XCTAssertEqual(view.displaySummaryForTesting(), "Display: INNOS 27QA100M")
        XCTAssertEqual(view.brightnessLabelForTesting(), "45%")
        XCTAssertEqual(
            view.diagnosticsSummaryForTesting(),
            "Diagnostics: Overlay active, DDC unsupported: DDC unavailable. Last: Applied brightness 45% warmth 32% on INNOS 27QA100M"
        )
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
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)

        menuBarController.perform(.warmthDown)

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 85)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 7)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .menuSlider)
        XCTAssertEqual(brightnessController.state.targetWarmth, 7)
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

    @MainActor
    func testMenuBarControllerRecordsDiagnosticsForAppliedCommand() {
        let software = RecordingSoftwareDimmingStrategy()
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.hardwareCapability = .unsupported(reason: "DDC unavailable")
        let brightnessController = BrightnessController(
            state: state,
            softwareStrategy: software
        )
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            diagnosticsStore: diagnosticsStore
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [75])
        XCTAssertTrue(diagnosticsStore.events.contains { event in
            event.category == .softwareDimming
                && event.message == "Applied brightness 75% warmth 12% on INNOS 27QA100M"
        })
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Software dimming active for INNOS 27QA100M")
    }

    @MainActor
    func testMenuBarControllerRecordsWarningWhenRestoreHasNoSavedState() {
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(diagnosticsStore: diagnosticsStore)

        menuBarController.perform(.restorePrevious)

        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .softwareDimming)
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Restore previous requested without saved state")
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
    }
}

@MainActor
private final class RecordingSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {}
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
