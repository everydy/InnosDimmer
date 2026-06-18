import AppKit
import XCTest
@testable import InnosDimmer

final class MenuBarStateTests: XCTestCase {
    func testModeLabelsMatchReviewArtifactVocabulary() {
        XCTAssertEqual(ModeStatusLabel.title(for: .overlay), "Overlay active")
        XCTAssertEqual(ModeStatusLabel.title(for: .platformBlocked), "Platform blocked")
        XCTAssertEqual(ModeStatusLabel.title(for: .gamma), "Gamma active")
        XCTAssertEqual(ModeStatusLabel.title(for: .unknown), "Software dimming ready")
    }

    func testMenuBarViewModelUsesStateValues() {
        let state = BrightnessState(
            display: nil,
            targetBrightness: 45,
            targetWarmth: 32,
            activeMode: .overlay,
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
        XCTAssertEqual(viewModel.diagnosticsSummary, "Diagnostics: Overlay active")
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
            "Diagnostics: Software dimming ready. Last: Applied brightness 45% warmth 32% on INNOS 27QA100M"
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
            "Diagnostics: Overlay active. Last: Applied brightness 45% warmth 32% on INNOS 27QA100M"
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
    func testMenuBarControllerRecordsSoftwareFailureInsteadOfAppliedCommand() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy(error: SoftwareDimmingError.displayUnavailable(404))
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            diagnosticsStore: diagnosticsStore
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .softwareDimming)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .error)
        XCTAssertEqual(
            diagnosticsStore.latestEvent?.message,
            "Software dimming failed for INNOS 27QA100M: Display 404 is not currently available for software dimming."
        )
        XCTAssertFalse(diagnosticsStore.events.contains { event in
            event.message.contains("Applied brightness 75%")
        })
    }

    @MainActor
    func testMenuBarControllerExportsDiagnosticsSnapshot() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let brightnessController = BrightnessController(state: state)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            diagnosticsStore: diagnosticsStore
        )

        let result = menuBarController.exportDiagnosticsForTesting()

        guard case .success(let data) = result else {
            XCTFail("Expected diagnostics export to succeed")
            return
        }
        let snapshot = try JSONDecoder().decode(DiagnosticsSnapshot.self, from: data)
        XCTAssertEqual(snapshot.selectedDisplay, .menuBarTestDisplay)
        XCTAssertEqual(snapshot.activeMode, .unknown)
        XCTAssertTrue(snapshot.events.contains { event in
            event.message == "Prepared diagnostics export"
        })
    }

    @MainActor
    func testMenuBarControllerResolvesStaleDisplayBeforeApplyingCommand() throws {
        let staleDisplay = DisplayIdentity.menuBarTestDisplay
        let activeDisplay = DisplayIdentity(
            cgDisplayID: 200,
            localizedName: "INNOS 27QA100M",
            vendorNumber: staleDisplay.vendorNumber,
            modelNumber: staleDisplay.modelNumber,
            serialNumber: staleDisplay.serialNumber,
            frameDescription: "2560x1440@0,0"
        )
        let store = DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        try store.saveSelectedDisplay(staleDisplay)
        var state = BrightnessState.defaultState()
        state.display = staleDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let inventory = RecordingDisplayInventory(displays: [activeDisplay], mainDisplayID: 1)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: inventory,
            displayTargetStore: store
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(software.appliedCommands.map(\.display), [activeDisplay])
        XCTAssertEqual(brightnessController.state.display, activeDisplay)
        XCTAssertEqual(brightnessController.state.targetBrightness, 75)
    }

    @MainActor
    func testMenuBarControllerDoesNotApplyCommandToMainDisplayWhenExternalTargetIsMissing() {
        let mainDisplay = DisplayIdentity(
            cgDisplayID: 1,
            localizedName: "Built-in Display",
            vendorNumber: nil,
            modelNumber: nil,
            serialNumber: nil,
            frameDescription: "1728x1117@0,0"
        )
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [mainDisplay], mainDisplayID: mainDisplay.cgDisplayID),
            diagnosticsStore: diagnosticsStore
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(software.appliedCommands, [])
        XCTAssertNil(brightnessController.state.display)
        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .display)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Skipped dimming command because no display is selected")
    }

}

@MainActor
private final class RecordingSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        if let error {
            throw error
        }
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {}
}

private final class RecordingDisplayInventory: DisplayInventoryProviding {
    var displays: [DisplayIdentity]
    var mainDisplayID: UInt32

    init(displays: [DisplayIdentity], mainDisplayID: UInt32) {
        self.displays = displays
        self.mainDisplayID = mainDisplayID
    }

    func activeDisplays() -> [DisplayIdentity] {
        displays
    }

    func resolveSelectedDisplay(saved: DisplayIdentity?, candidates: [DisplayIdentity]) -> DisplayIdentity? {
        DisplayInventory.resolveSelectedDisplay(
            saved: saved,
            candidates: candidates,
            mainDisplayID: mainDisplayID
        )
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

private func makeTemporaryDefaults() throws -> UserDefaults {
    let suiteName = "InnosDimmer.MenuBarStateTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
