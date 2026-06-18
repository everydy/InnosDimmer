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

        let shortcuts = ShortcutBinding.defaultBindings.map { binding in
            binding.action == .brightnessUp
                ? ShortcutBinding(action: binding.action, keyCode: binding.keyCode, modifiers: binding.modifiers, isEnabled: false)
                : binding
        }
        let viewModel = MenuBarViewModel(
            state: state,
            schedule: [ScheduleEntry(minuteOfDay: 600, brightness: 70, warmth: 20)],
            shortcuts: shortcuts
        )

        XCTAssertEqual(viewModel.modeTitle, "Overlay active")
        XCTAssertEqual(viewModel.displaySummary, "Display: Not selected")
        XCTAssertEqual(viewModel.brightnessLabel, "45%")
        XCTAssertEqual(viewModel.warmthLabel, "32%")
        XCTAssertEqual(viewModel.automationTitle, "Automation paused until 19:00")
        XCTAssertEqual(viewModel.scheduleSummary, "Schedule: 10:00 70%/20")
        XCTAssertEqual(viewModel.shortcutSummary, "Shortcuts: 5 enabled")
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

        let shortcuts = ShortcutBinding.defaultBindings.map { binding in
            binding.action == .brightnessDown
                ? ShortcutBinding(action: binding.action, keyCode: binding.keyCode, modifiers: binding.modifiers, isEnabled: false)
                : binding
        }
        view.update(
            state: state,
            schedule: [ScheduleEntry(minuteOfDay: 615, brightness: 66, warmth: 21)],
            shortcuts: shortcuts,
            latestDiagnosticEvent: event
        )

        XCTAssertEqual(view.displaySummaryForTesting(), "Display: INNOS 27QA100M")
        XCTAssertEqual(view.brightnessLabelForTesting(), "45%")
        XCTAssertEqual(view.scheduleSummaryForTesting(), "Schedule: 10:15 66%/21")
        XCTAssertEqual(view.shortcutSummaryForTesting(), "Shortcuts: 5 enabled")
        XCTAssertEqual(
            view.diagnosticsSummaryForTesting(),
            "Diagnostics: Overlay active, DDC unsupported: DDC unavailable. Last: Applied brightness 45% warmth 32% on INNOS 27QA100M"
        )
    }

    @MainActor
    func testMenuBarControllerRoutesDimmingCommandsThroughBrightnessController() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(brightnessController: brightnessController)

        menuBarController.perform(.brightnessUp)

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.display), [.menuBarTestDisplay])
        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85])
        XCTAssertEqual(software.appliedCommands.map(\.warmth), [12])
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        menuBarController.perform(.warmthDown)

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85, 85])
        XCTAssertEqual(software.appliedCommands.map(\.warmth), [12, 7])
        XCTAssertEqual(brightnessController.state.targetWarmth, 7)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
    }

    @MainActor
    func testMenuBarControllerRoutesQuickDisableAndRestoreThroughBrightnessController() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(brightnessController: brightnessController)

        menuBarController.perform(.quickDisable)

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100])
        XCTAssertEqual(software.appliedCommands.map(\.warmth), [12])
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        menuBarController.perform(.restorePrevious)

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100, 80])
        XCTAssertEqual(software.appliedCommands.map(\.warmth), [12, 12])
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
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

    @MainActor
    func testMenuBarControllerRunsDDCProbeAndSurfacesUnsupportedResult() {
        let adapter = MenuBarProbeDDCAdapter(currentBrightness: nil)
        let software = RecordingSoftwareDimmingStrategy()
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let brightnessController = BrightnessController(
            state: state,
            softwareStrategy: software
        )
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            diagnosticsStore: diagnosticsStore,
            hardwareDDCController: HardwareDDCController(
                adapter: adapter,
                now: { Date(timeIntervalSince1970: 42) }
            )
        )

        menuBarController.perform(.probeDDC)

        XCTAssertEqual(brightnessController.state.hardwareCapability, .unsupported(reason: "brightness read failed"))
        XCTAssertEqual(
            brightnessController.state.lastHardwareProbeResult?.steps.map(\.kind),
            [.identifyDisplay, .readBrightness, .classifyFailure]
        )
        XCTAssertTrue(adapter.writtenValues.isEmpty)
        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .hardwareProbe)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
        XCTAssertTrue(diagnosticsStore.latestEvent?.message.contains("DDC probe result for INNOS 27QA100M") == true)

        let viewModel = MenuBarViewModel(state: brightnessController.state)
        XCTAssertEqual(
            viewModel.diagnosticsSummary,
            "Diagnostics: Not probed, DDC unsupported: brightness read failed. Probe: DDC unsupported: brightness read failed after 3 steps"
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [75])
        XCTAssertNil(brightnessController.pendingCommand)
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

private final class MenuBarProbeDDCAdapter: DDCAdapter {
    var currentBrightness: Int?
    private(set) var writtenValues: [Int] = []

    init(currentBrightness: Int?) {
        self.currentBrightness = currentBrightness
    }

    func readBrightness(display: DisplayIdentity) throws -> DDCBrightnessValue {
        guard let currentBrightness else {
            throw DDCAdapterError.readFailed
        }

        return DDCBrightnessValue(current: currentBrightness, range: 0...100)
    }

    func writeBrightness(_ value: Int, display: DisplayIdentity) throws {
        writtenValues.append(value)
        currentBrightness = value
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
