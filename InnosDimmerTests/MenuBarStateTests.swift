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
            targetBlueReduction: 32,
            activeMode: .overlay,
            automationPausedUntilNextBoundary: true,
            automationPausedAtMinuteOfDay: 1_000,
            automationResumeMinuteOfDay: 1_140,
            lastAppliedCommandSource: .menuSlider
        )

        let shortcuts = ShortcutBinding.defaultBindings.map { binding in
            binding.action == .brightnessUp
                ? ShortcutBinding(action: binding.action, keyCode: binding.keyCode, modifiers: binding.modifiers, isEnabled: false)
                : binding
        }
        let viewModel = MenuBarViewModel(
            state: state,
            schedule: [ScheduleEntry(minuteOfDay: 600, brightness: 70, blueReduction: 20)],
            shortcuts: shortcuts
        )

        XCTAssertEqual(viewModel.modeTitle, "Overlay active")
        XCTAssertEqual(viewModel.displaySummary, "No display selected")
        XCTAssertEqual(viewModel.brightnessLabel, "45%")
        XCTAssertEqual(viewModel.blueReductionLabel, "32%")
        XCTAssertNil(viewModel.blueReductionWarning)
        XCTAssertEqual(viewModel.automationTitle, "Automation paused until 19:00")
        XCTAssertEqual(viewModel.automationActionTitle, "Resume automation")
        XCTAssertEqual(viewModel.automationActionCommand, .resumeAutomation)
        XCTAssertEqual(viewModel.quickControlsBadgeTitle, "MANUAL")
        XCTAssertEqual(viewModel.scheduleStatusDetail, "Next boundary 19:00")
        XCTAssertEqual(viewModel.scheduleSummary, "10:00 · ☀ 70% · 🌡 20%")
        XCTAssertEqual(
            viewModel.shortcutRows,
            [
                ShortcutSummaryRow(action: .brightnessUp, title: "Brightness up", keyLabel: "Off"),
                ShortcutSummaryRow(action: .brightnessDown, title: "Brightness down", keyLabel: "⌥⇧↓"),
                ShortcutSummaryRow(action: .blueReductionUp, title: "Warmth up", keyLabel: "⌥⇧→"),
                ShortcutSummaryRow(action: .blueReductionDown, title: "Warmth down", keyLabel: "⌥⇧←")
            ]
        )
        XCTAssertEqual(
            viewModel.shortcutSummary,
            "Brightness  Up  Off  Down  ⌥⇧↓\nWarmth  Up  ⌥⇧→  Down  ⌥⇧←"
        )
        XCTAssertEqual(viewModel.diagnosticsSummary, "Overlay active")
    }

    func testMenuBarViewModelAppendsPausedStatusToDisplaySummaryWhenDisplayExists() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.automationPausedUntilNextBoundary = true
        state.automationResumeMinuteOfDay = 1_140

        let viewModel = MenuBarViewModel(state: state)

        XCTAssertEqual(
            viewModel.displaySummary,
            "27QA100M · software dimming · automation paused until 19:00"
        )
        XCTAssertEqual(viewModel.quickControlsBadgeTitle, "MANUAL")
    }

    func testMenuBarViewModelShortcutSummaryStillFocusesOnCoreAdjustments() {
        let state = BrightnessState.defaultState()
        let shortcuts = ShortcutBinding.defaultBindings

        let viewModel = MenuBarViewModel(state: state, shortcuts: shortcuts)

        XCTAssertEqual(
            viewModel.shortcutSummary,
            "Brightness  Up  ⌥⇧↑  Down  ⌥⇧↓\nWarmth  Up  ⌥⇧→  Down  ⌥⇧←"
        )
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

        XCTAssertEqual(viewModel.displaySummary, "27QA100M · software dimming")
        XCTAssertEqual(
            viewModel.diagnosticsSummary,
            "Applied brightness 45% warmth 32% on INNOS 27QA100M"
        )
    }

    func testAppDashboardViewModelShowsFailureSummaryAndRecentDiagnostics() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.activeMode = .overlay
        state.targetBrightness = 35
        state.targetBlueReduction = 20
        let events = [
            DiagnosticsEvent(
                timestamp: Date(timeIntervalSince1970: 0),
                category: .softwareDimming,
                message: "Software dimming active",
                severity: .info
            ),
            DiagnosticsEvent(
                timestamp: Date(timeIntervalSince1970: 1),
                category: .display,
                message: "No eligible external display found",
                severity: .warning
            ),
            DiagnosticsEvent(
                timestamp: Date(timeIntervalSince1970: 2),
                category: .softwareDimming,
                message: "Overlay platform blocked",
                severity: .error
            )
        ]

        let viewModel = AppDashboardViewModel(
            state: state,
            schedule: [ScheduleEntry(minuteOfDay: 540, brightness: 80, blueReduction: 12)],
            shortcuts: ShortcutBinding.defaultBindings,
            events: events
        )

        XCTAssertEqual(viewModel.displayLine, "Display: INNOS 27QA100M")
        XCTAssertEqual(viewModel.modeLine, "Mode: Overlay active")
        XCTAssertEqual(viewModel.brightnessLine, "Brightness: 35% / Warmth: 20%")
        XCTAssertEqual(viewModel.displayValue, "INNOS 27QA100M")
        XCTAssertEqual(viewModel.modeValue, "Overlay active")
        XCTAssertEqual(viewModel.brightnessValue, "35%")
        XCTAssertEqual(viewModel.blueReductionValue, "20%")
        XCTAssertNil(viewModel.blueReductionWarning)
        XCTAssertEqual(viewModel.automationValue, "active")
        XCTAssertEqual(viewModel.automationActionTitle, "Pause automation")
        XCTAssertEqual(viewModel.automationActionCommand, .pauseAutomation)
        XCTAssertEqual(viewModel.scheduleValue, "09:00 · ☀ 80% · 🌡 12%")
        XCTAssertEqual(viewModel.shortcutValue, "7 enabled")
        XCTAssertEqual(viewModel.failureValue, "1 errors, 1 warnings")
        XCTAssertEqual(viewModel.failureLine, "Failures: 1 errors, 1 warnings")
        XCTAssertTrue(viewModel.diagnosticsLog.contains("ERROR softwareDimming: Overlay platform blocked"))
        XCTAssertTrue(viewModel.diagnosticsLog.contains("WARNING display: No eligible external display found"))
    }

    func testBlueReductionWarningAppearsAtHighRange() {
        var state = BrightnessState.defaultState()
        state.targetBlueReduction = 50

        let menuViewModel = MenuBarViewModel(state: state)
        let dashboardViewModel = AppDashboardViewModel(
            state: state,
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )

        XCTAssertEqual(menuViewModel.blueReductionWarning, "High warmth may shift colors.")
        XCTAssertEqual(dashboardViewModel.blueReductionWarning, "High warmth may shift colors.")
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

        for command in MenuBarCommand.buttonCommands {
            guard let button = view.commandButtonForTesting(command) else {
                XCTFail("Missing button for \(command)")
                continue
            }

            XCTAssertTrue(button.target === view)
            XCTAssertNotNil(button.action)
            button.performClick(nil)
        }

        XCTAssertEqual(view.commandButtonForTesting(.openShortcuts)?.title, "Edit Shortcuts")
        XCTAssertEqual(view.commandButtonForTesting(.openAppWindow)?.title, "Open Control Window")
        XCTAssertEqual(routedCommands, MenuBarCommand.buttonCommands)
    }

    @MainActor
    func testMenuBarPopoverShowsResumeAutomationWhenPaused() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_000
        state.automationResumeMinuteOfDay = 1_140
        var routedCommands: [MenuBarCommand] = []
        let view = MenuBarPopoverView(
            state: state,
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )

        XCTAssertNil(view.commandButtonForTesting(.pauseAutomation))
        let button = view.commandButtonForTesting(.resumeAutomation)
        XCTAssertEqual(button?.title, "Resume automation")

        button?.performClick(nil)

        XCTAssertEqual(routedCommands, [.resumeAutomation])
    }

    @MainActor
    func testMenuBarPopoverCommandButtonsKeepMinimumActionHeight() {
        let view = MenuBarPopoverView(state: .defaultState())
        view.layoutSubtreeIfNeeded()

        for command in MenuBarCommand.buttonCommands {
            guard let button = view.commandButtonForTesting(command) else {
                XCTFail("Missing button for \(command)")
                continue
            }

            XCTAssertGreaterThanOrEqual(button.fittingSize.height, 30, "Button for \(command) is too thin")
        }
    }

    @MainActor
    func testMenuBarPopoverTracksRouteAbsolutePercentageCommands() {
        var routedCommands: [MenuBarCommand] = []
        let view = MenuBarPopoverView(
            state: .defaultState(),
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )

        view.simulateBrightnessTrackChangeForTesting(percent: 73)
        view.simulateBlueReductionTrackChangeForTesting(percent: 18)

        XCTAssertEqual(routedCommands, [.setBrightness(73), .setBlueReduction(18)])
    }

    @MainActor
    func testScheduleEditorWindowShellShowsCurrentSchedule() {
        let controller = ScheduleEditorWindowController()
        controller.configure(schedule: [
            ScheduleEntry(minuteOfDay: 615, brightness: 66, blueReduction: 21),
            ScheduleEntry(minuteOfDay: 540, brightness: 80, blueReduction: 12),
            ScheduleEntry(minuteOfDay: 1_140, brightness: 45, blueReduction: 30)
        ])

        XCTAssertEqual(
            controller.scheduleSummaryForTesting(),
            "09:00 · 80% brightness / 12% warmth\n10:15 · 66% brightness / 21% warmth\n19:00 · 45% brightness / 30% warmth"
        )
    }

    @MainActor
    func testScheduleEditorViewReturnsSortedEditedSchedule() throws {
        let view = ScheduleEditorView()
        view.update(schedule: [
            ScheduleEntry(minuteOfDay: 615, brightness: 66, blueReduction: 21),
            ScheduleEntry(minuteOfDay: 540, brightness: 80, blueReduction: 12),
            ScheduleEntry(minuteOfDay: 1_140, brightness: 45, blueReduction: 30)
        ])
        view.setRowForTesting(index: 1, time: "10:30", brightness: "61", blueReduction: "19")

        let schedule = try view.editedSchedule()

        XCTAssertEqual(schedule.map(\.minuteOfDay), [540, 630, 1_140])
        XCTAssertEqual(schedule.map(\.brightness), [80, 61, 45])
        XCTAssertEqual(schedule.map(\.blueReduction), [12, 19, 30])
    }

    @MainActor
    func testScheduleEditorViewReportsInvalidFields() {
        let invalidTimeView = ScheduleEditorView()
        invalidTimeView.setRowForTesting(index: 0, time: "24:00", brightness: "80", blueReduction: "12")
        XCTAssertThrowsError(try invalidTimeView.editedSchedule()) { error in
            XCTAssertEqual(error.localizedDescription, "Schedule row 1 needs a time in HH:mm format.")
        }

        let invalidPercentView = ScheduleEditorView()
        invalidPercentView.setRowForTesting(index: 2, time: "23:00", brightness: "25", blueReduction: "101")
        XCTAssertThrowsError(try invalidPercentView.editedSchedule()) { error in
            XCTAssertEqual(error.localizedDescription, "Schedule row 3 needs blue reduction from 0 to 100.")
        }
    }

    @MainActor
    func testScheduleEditorWindowSaveUsesInjectedScheduleAction() {
        var savedSchedule: [ScheduleEntry]?
        let controller = ScheduleEditorWindowController(
            actions: ScheduleEditorActions(
                updateSchedule: { schedule in
                    savedSchedule = schedule
                    return .success(SettingsSnapshot.defaultSnapshot().replacingSchedule(schedule))
                }
            )
        )
        controller.configure(schedule: ScheduleEntry.defaultSchedule)
        controller.setScheduleRowForTesting(index: 0, time: "08:30", brightness: "72", blueReduction: "18")

        let result = controller.saveScheduleForTesting()

        guard case .success(let snapshot) = result else {
            XCTFail("Expected schedule save to succeed")
            return
        }
        XCTAssertEqual(savedSchedule?.first?.minuteOfDay, 510)
        XCTAssertEqual(savedSchedule?.first?.brightness, 72)
        XCTAssertEqual(savedSchedule?.first?.blueReduction, 18)
        XCTAssertEqual(snapshot.schedule.first?.minuteOfDay, 510)
    }

    @MainActor
    func testMenuBarControllerRoutesOpenScheduleEditorWithoutApplyingDimmingCommand() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.perform(.openScheduleEditor)

        XCTAssertEqual(software.appliedCommands, [])
        XCTAssertTrue(menuBarController.appWindowIsShownForTesting())
        XCTAssertEqual(menuBarController.appWindowActivePageForTesting(), "Schedule")
        XCTAssertEqual(brightnessController.state.targetBrightness, 80)
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 12)
    }

    @MainActor
    func testMenuBarControllerRoutesSettingsAndShortcutsToAppWindowWithoutApplyingDimmingCommand() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.perform(.openSettings)
        XCTAssertEqual(menuBarController.appWindowActivePageForTesting(), "Settings")
        menuBarController.perform(.openShortcuts)
        XCTAssertEqual(menuBarController.appWindowActivePageForTesting(), "Shortcuts")
        menuBarController.perform(.openDiagnostics)
        XCTAssertEqual(menuBarController.appWindowActivePageForTesting(), "Diagnostics")

        XCTAssertEqual(software.appliedCommands, [])
        XCTAssertTrue(menuBarController.appWindowIsShownForTesting())
        XCTAssertEqual(brightnessController.state.targetBrightness, 80)
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 12)
    }

    @MainActor
    func testUnifiedAppWindowRoutesDisplaySelectionThroughSettingsAction() {
        var selectedDisplay: DisplayIdentity?
        let controller = UnifiedAppWindowController(
            settingsActions: SettingsActions(
                selectDisplay: { display in
                    selectedDisplay = display
                    return .success(SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay(display))
                },
                openScheduleEditor: {},
                updateShortcuts: { .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts($0)) },
                setLaunchAtLogin: { .success($0 ? .enabled : .disabled) },
                exportDiagnostics: { .success(Data()) }
            )
        )

        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: [],
            displayCandidates: [.menuBarTestDisplay],
            loginItemStatus: .notRegistered
        )
        controller.selectDisplayIndexForTesting(1)

        XCTAssertEqual(selectedDisplay, .menuBarTestDisplay)
    }

    @MainActor
    func testUnifiedAppWindowSavesShortcutsThroughSettingsAction() {
        var savedShortcuts: [ShortcutBinding] = []
        let controller = UnifiedAppWindowController(
            settingsActions: SettingsActions(
                selectDisplay: { .success(SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay($0)) },
                openScheduleEditor: {},
                updateShortcuts: { shortcuts in
                    savedShortcuts = shortcuts
                    return .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts(shortcuts))
                },
                setLaunchAtLogin: { .success($0 ? .enabled : .disabled) },
                exportDiagnostics: { .success(Data()) }
            )
        )
        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )
        controller.focus(.shortcuts)
        controller.setShortcutForTesting(
            action: .blueReductionUp,
            keyCode: 18,
            modifiers: [.control, .shift],
            isEnabled: true
        )

        let result = controller.saveShortcutsForTesting()

        guard case .success = result else {
            XCTFail("Expected shortcut save to succeed")
            return
        }
        XCTAssertTrue(savedShortcuts.contains { binding in
            binding.action == .blueReductionUp
                && binding.keyCode == 18
                && binding.modifiers == [.control, .shift]
                && binding.isEnabled
        })
    }

    @MainActor
    func testUnifiedAppWindowReportsBlueReductionShortcutValidation() {
        let controller = UnifiedAppWindowController()
        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )
        controller.focus(.shortcuts)
        controller.setShortcutKeyStringForTesting(action: .blueReductionDown, keyCode: "not-a-key")

        let result = controller.saveShortcutsForTesting()

        guard case .failure(let error) = result else {
            XCTFail("Expected shortcut validation to fail")
            return
        }
        XCTAssertEqual(error.localizedDescription, "Blue reduction down needs a key code from 0 to 65535.")
    }

    @MainActor
    func testUnifiedAppWindowTogglesLaunchAtLoginThroughSettingsAction() {
        var toggledValue: Bool?
        let controller = UnifiedAppWindowController(
            settingsActions: SettingsActions(
                selectDisplay: { .success(SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay($0)) },
                openScheduleEditor: {},
                updateShortcuts: { .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts($0)) },
                setLaunchAtLogin: { enabled in
                    toggledValue = enabled
                    return .success(enabled ? .enabled : .disabled)
                },
                exportDiagnostics: { .success(Data()) }
            )
        )
        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: [],
            loginItemStatus: .disabled
        )

        controller.toggleLaunchAtLoginForTesting(true)

        XCTAssertEqual(toggledValue, true)
    }

    @MainActor
    func testUnifiedAppWindowExportsDiagnosticsThroughSettingsAction() {
        let expectedData = Data(#"{"ok":true}"#.utf8)
        let controller = UnifiedAppWindowController(
            settingsActions: SettingsActions(
                selectDisplay: { .success(SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay($0)) },
                openScheduleEditor: {},
                updateShortcuts: { .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts($0)) },
                setLaunchAtLogin: { .success($0 ? .enabled : .disabled) },
                exportDiagnostics: { .success(expectedData) }
            )
        )

        let result = controller.exportDiagnosticsForTesting()

        guard case .success(let data) = result else {
            XCTFail("Expected diagnostics export to succeed")
            return
        }
        XCTAssertEqual(data, expectedData)
    }

    @MainActor
    func testUnifiedAppWindowHomeLayoutKeepsControlsAndNavigationReadable() throws {
        let controller = UnifiedAppWindowController()
        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )

        let metrics = try XCTUnwrap(controller.homeLayoutMetricsForTesting())

        XCTAssertGreaterThanOrEqual(metrics.quickActionsWidth, 430)
        XCTAssertGreaterThanOrEqual(metrics.nextActionsWidth, 430)
        XCTAssertGreaterThanOrEqual(metrics.firstTileWidth, 168)
        XCTAssertEqual(metrics.firstTileHeight, 104, accuracy: 1)
    }

    @MainActor
    func testMenuBarControllerRoutesOpenPopoverWithoutApplyingDimmingCommand() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.automationPausedUntilNextBoundary = true
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay"),
            registersHotkeysOnStart: false
        )

        menuBarController.start()
        menuBarController.perform(.openPopover)

        XCTAssertEqual(software.appliedCommands, [])
    }

    func testPopoverDismissalHelperTreatsOutsideClicksAsDismissible() {
        let popoverFrame = CGRect(x: 100, y: 100, width: 240, height: 240)
        let statusItemFrame = CGRect(x: 10, y: 10, width: 32, height: 24)

        XCTAssertFalse(
            MenuBarController.shouldDismissPopover(
                mouseLocation: CGPoint(x: 150, y: 180),
                popoverFrame: popoverFrame,
                statusItemButtonFrame: statusItemFrame
            )
        )
        XCTAssertFalse(
            MenuBarController.shouldDismissPopover(
                mouseLocation: CGPoint(x: 20, y: 18),
                popoverFrame: popoverFrame,
                statusItemButtonFrame: statusItemFrame
            )
        )
        XCTAssertTrue(
            MenuBarController.shouldDismissPopover(
                mouseLocation: CGPoint(x: 40, y: 40),
                popoverFrame: popoverFrame,
                statusItemButtonFrame: statusItemFrame
            )
        )
    }

    @MainActor
    func testAppDashboardButtonsRouteEditableCommands() {
        let dashboardCommands: [MenuBarCommand] = [
            .brightnessDown,
            .brightnessUp,
            .blueReductionDown,
            .blueReductionUp,
            .quickDisable,
            .restorePrevious,
            .pauseAutomation,
            .openSettings
        ]
        var routedCommands: [MenuBarCommand] = []
        let controller = AppDashboardWindowController(
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )

        for command in dashboardCommands {
            guard let button = controller.commandButtonForTesting(command) else {
                XCTFail("Missing dashboard button for \(command)")
                continue
            }

            XCTAssertTrue(button.target === controller)
            XCTAssertNotNil(button.action)
            button.performClick(nil)
        }

        XCTAssertEqual(routedCommands, dashboardCommands)
    }

    @MainActor
    func testAppDashboardShowsResumeAutomationWhenPaused() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_000
        state.automationResumeMinuteOfDay = 1_140
        var routedCommands: [MenuBarCommand] = []
        let controller = AppDashboardWindowController(
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )
        controller.update(
            state: state,
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )

        XCTAssertNil(controller.commandButtonForTesting(.pauseAutomation))
        let button = controller.commandButtonForTesting(.resumeAutomation)
        XCTAssertEqual(button?.title, "Resume automation")

        button?.performClick(nil)

        XCTAssertEqual(routedCommands, [.resumeAutomation])
    }

    @MainActor
    func testAppDashboardCommandButtonsKeepMinimumActionHeight() {
        let dashboardCommands: [MenuBarCommand] = [
            .brightnessDown,
            .brightnessUp,
            .blueReductionDown,
            .blueReductionUp,
            .quickDisable,
            .restorePrevious,
            .pauseAutomation,
            .openSettings
        ]
        let controller = AppDashboardWindowController()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        for command in dashboardCommands {
            guard let button = controller.commandButtonForTesting(command) else {
                XCTFail("Missing dashboard button for \(command)")
                continue
            }

            XCTAssertGreaterThanOrEqual(button.fittingSize.height, 30, "Dashboard button for \(command) is too thin")
        }
    }

    @MainActor
    func testAppDashboardTracksRouteAbsolutePercentageCommands() {
        var routedCommands: [MenuBarCommand] = []
        let controller = AppDashboardWindowController(
            actions: MenuBarActions { command in
                routedCommands.append(command)
            }
        )

        controller.simulateBrightnessTrackChangeForTesting(percent: 66)
        controller.simulateBlueReductionTrackChangeForTesting(percent: 21)

        XCTAssertEqual(routedCommands, [.setBrightness(66), .setBlueReduction(21)])
    }

    @MainActor
    func testAppDashboardSavesInlineScheduleThroughInjectedAction() {
        var savedSchedule: [ScheduleEntry]?
        let controller = AppDashboardWindowController(
            scheduleActions: ScheduleEditorActions(
                updateSchedule: { schedule in
                    savedSchedule = schedule
                    return .success(SettingsSnapshot.defaultSnapshot().replacingSchedule(schedule))
                }
            )
        )
        controller.update(
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings,
            events: []
        )
        controller.setScheduleRowForTesting(index: 1, time: "10:45", brightness: "62", blueReduction: "20")

        let result = controller.saveScheduleForTesting()

        guard case .success(let snapshot) = result else {
            XCTFail("Expected dashboard schedule save to succeed")
            return
        }
        XCTAssertEqual(savedSchedule?[1].minuteOfDay, 645)
        XCTAssertEqual(savedSchedule?[1].brightness, 62)
        XCTAssertEqual(savedSchedule?[1].blueReduction, 20)
        XCTAssertEqual(snapshot.schedule[1].minuteOfDay, 645)
        XCTAssertEqual(
            controller.scheduleSummaryForTesting(),
            "09:00 · ☀ 80% · 🌡 12%\n10:45 · ☀ 62% · 🌡 20%\n23:00 · ☀ 25% · 🌡 58%"
        )
    }

    @MainActor
    func testMenuBarPopoverUsesContentFitSizeWithoutBottomSlack() {
        let view = MenuBarPopoverView(state: .defaultState())

        XCTAssertEqual(view.frame.size.width, MenuBarPopoverView.preferredContentSize.width)
        XCTAssertEqual(view.frame.size.height, MenuBarPopoverView.preferredContentSize.height)
        XCTAssertGreaterThanOrEqual(MenuBarPopoverView.preferredContentSize.width, 420)
        XCTAssertGreaterThanOrEqual(MenuBarPopoverView.preferredContentSize.height, 745)
        XCTAssertLessThanOrEqual(MenuBarPopoverView.preferredContentSize.height, 755)
    }

    @MainActor
    func testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark() {
        let appearances = [
            NSAppearance(named: .aqua),
            NSAppearance(named: .darkAqua)
        ].compactMap { $0 }

        for appearance in appearances {
            let view = MenuBarPopoverView(state: .defaultState())
            view.appearance = appearance
            view.layoutSubtreeIfNeeded()

            XCTAssertLessThanOrEqual(view.fittingSize.width, MenuBarPopoverView.preferredContentSize.width)
            XCTAssertLessThanOrEqual(view.fittingSize.height, MenuBarPopoverView.preferredContentSize.height)
        }
    }

    @MainActor
    func testMenuBarPopoverWritesDesignSnapshotsWhenRequested() throws {
        let snapshotDirectory = ProcessInfo.processInfo.environment["INNOSDIMMER_SNAPSHOT_DIR"]
            ?? "/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures"

        let directoryURL = URL(fileURLWithPath: snapshotDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.targetBrightness = 45
        state.targetBlueReduction = 32
        state.activeMode = .overlay
        state.automationPausedUntilNextBoundary = true
        state.automationResumeMinuteOfDay = 1_140
        let event = DiagnosticsEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            category: .softwareDimming,
            message: "Applied brightness 45% and warmth 32% on INNOS 27QA100M.",
            severity: .info
        )

        let variants: [(String, NSAppearance.Name)] = [
            ("actual-light", .aqua),
            ("actual-dark", .darkAqua)
        ]

        for (name, appearanceName) in variants {
            guard let appearance = NSAppearance(named: appearanceName) else {
                continue
            }

            let view = MenuBarPopoverView(
                state: state,
                schedule: [
                    ScheduleEntry(minuteOfDay: 540, brightness: 80, blueReduction: 12),
                    ScheduleEntry(minuteOfDay: 1_140, brightness: 45, blueReduction: 32),
                    ScheduleEntry(minuteOfDay: 1_380, brightness: 25, blueReduction: 58)
                ],
                shortcuts: ShortcutBinding.defaultBindings,
                latestDiagnosticEvent: event
            )
            view.appearance = appearance
            view.layoutSubtreeIfNeeded()

            guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                XCTFail("Could not create bitmap representation for \(name)")
                continue
            }
            view.cacheDisplay(in: view.bounds, to: representation)
            guard let data = representation.representation(using: .png, properties: [:]) else {
                XCTFail("Could not encode snapshot for \(name)")
                continue
            }
            try data.write(to: directoryURL.appendingPathComponent("\(name).png"))
        }
    }

    @MainActor
    func testAppDashboardWritesDesignSnapshotsWhenRequested() throws {
        let snapshotDirectory = ProcessInfo.processInfo.environment["INNOSDIMMER_SNAPSHOT_DIR"]
            ?? "/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures"

        let directoryURL = URL(fileURLWithPath: snapshotDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.targetBrightness = 45
        state.targetBlueReduction = 32
        state.activeMode = .overlay
        state.automationPausedUntilNextBoundary = true
        state.automationResumeMinuteOfDay = 1_140
        let events = [
            DiagnosticsEvent(
                timestamp: Date(timeIntervalSince1970: 0),
                category: .softwareDimming,
                message: "Applied brightness 45% warmth 32% on INNOS 27QA100M",
                severity: .info
            ),
            DiagnosticsEvent(
                timestamp: Date(timeIntervalSince1970: 1),
                category: .schedule,
                message: "Manual menu override; automation paused until 19:00",
                severity: .info
            )
        ]

        let variants: [(String, NSAppearance.Name)] = [
            ("dashboard-light", .aqua),
            ("dashboard-dark", .darkAqua)
        ]

        for (name, appearanceName) in variants {
            guard let appearance = NSAppearance(named: appearanceName) else {
                continue
            }

            let controller = AppDashboardWindowController()
            controller.window?.appearance = appearance
            controller.update(
                state: state,
                schedule: [ScheduleEntry(minuteOfDay: 1_140, brightness: 45, blueReduction: 32)],
                shortcuts: ShortcutBinding.defaultBindings,
                events: events
            )

            guard let contentView = controller.window?.contentView else {
                XCTFail("Missing dashboard content view for \(name)")
                continue
            }
            contentView.layoutSubtreeIfNeeded()

            guard let representation = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                XCTFail("Could not create dashboard bitmap representation for \(name)")
                continue
            }
            contentView.cacheDisplay(in: contentView.bounds, to: representation)
            guard let data = representation.representation(using: .png, properties: [:]) else {
                XCTFail("Could not encode dashboard snapshot for \(name)")
                continue
            }
            try data.write(to: directoryURL.appendingPathComponent("\(name).png"))
        }
    }

    @MainActor
    func testMenuBarPopoverUpdateRefreshesVisibleStateAndDiagnostics() {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let view = MenuBarPopoverView(state: state)
        state.targetBrightness = 45
        state.targetBlueReduction = 32
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
            schedule: [ScheduleEntry(minuteOfDay: 615, brightness: 66, blueReduction: 21)],
            shortcuts: shortcuts,
            latestDiagnosticEvent: event
        )

        XCTAssertEqual(view.displaySummaryForTesting(), "27QA100M · software dimming")
        XCTAssertEqual(view.brightnessLabelForTesting(), "45%")
        XCTAssertEqual(view.blueReductionLabelForTesting(), "32%")
        XCTAssertEqual(view.brightnessTrackFractionForTesting(), 0.45, accuracy: 0.001)
        XCTAssertEqual(view.blueReductionTrackFractionForTesting(), 0.32, accuracy: 0.001)
        XCTAssertEqual(view.scheduleSummaryForTesting(), "10:15 · ☀ 66% · 🌡 21%")
        XCTAssertEqual(view.scheduleStatusForTesting(), "Automation active\nSchedule rows below")
        XCTAssertFalse(view.scheduleStatusForTesting().contains("Current"))
        XCTAssertEqual(
            view.shortcutSummaryForTesting(),
            "Brightness  Up  ⌥⇧↑  Down  Off\nWarmth  Up  ⌥⇧→  Down  ⌥⇧←"
        )
        XCTAssertEqual(
            view.diagnosticsSummaryForTesting(),
            "Applied brightness 45% warmth 32% on INNOS 27QA100M"
        )
    }

    @MainActor
    func testMenuBarControllerRoutesDimmingCommandsThroughBrightnessController() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.perform(.brightnessUp)

        XCTAssertEqual(software.appliedCommands.map(\.display), [.menuBarTestDisplay])
        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [12])
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        menuBarController.perform(.blueReductionDown)

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85, 85])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [12, 7])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 7)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
    }

    @MainActor
    func testMenuBarControllerRoutesAbsoluteTrackCommandsThroughBrightnessController() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.perform(.setBrightness(42))
        menuBarController.perform(.setBlueReduction(27))

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [42, 42])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [12, 27])
        XCTAssertEqual(brightnessController.state.targetBrightness, 42)
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 27)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
    }

    @MainActor
    func testMenuBarControllerRoutesQuickDisableAndRestoreThroughBrightnessController() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.perform(.quickDisable)

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [0])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 0)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        menuBarController.perform(.restorePrevious)

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100, 80])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [0, 12])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 12)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)
    }

    @MainActor
    func testMenuBarControllerRecordsDiagnosticsForAppliedCommand() throws {
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
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay"),
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
    func testMenuBarControllerRecordsSoftwareFailureInsteadOfAppliedCommand() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        let software = RecordingSoftwareDimmingStrategy(error: SoftwareDimmingError.displayUnavailable(404))
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay"),
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
    func testMenuBarControllerDoesNotApplyCommandToMainDisplayWhenExternalTargetIsMissing() throws {
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
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay"),
            diagnosticsStore: diagnosticsStore
        )

        menuBarController.perform(.brightnessDown)

        XCTAssertEqual(software.appliedCommands, [])
        XCTAssertNil(brightnessController.state.display)
        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .display)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Skipped dimming command because no display is selected")
    }

    @MainActor
    func testMenuBarControllerStopClearsCurrentSoftwareState() throws {
        var state = BrightnessState.defaultState()
        state.display = .menuBarTestDisplay
        state.activeMode = .overlay
        let software = RecordingSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingDisplayInventory(displays: [.menuBarTestDisplay], mainDisplayID: 999),
            displayTargetStore: DisplayTargetStore(defaults: try makeTemporaryDefaults(), key: "SelectedDisplay")
        )

        menuBarController.stop()

        XCTAssertEqual(software.clearedDisplays, [.menuBarTestDisplay])
        XCTAssertEqual(brightnessController.state.activeMode, .unknown)
    }

}

@MainActor
private final class RecordingSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []
    private(set) var clearedDisplays: [DisplayIdentity] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func apply(_ command: BrightnessCommand) throws {
        if let error {
            throw error
        }
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {
        clearedDisplays.append(display)
    }
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
