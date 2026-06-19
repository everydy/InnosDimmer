import AppKit

@MainActor
final class MenuBarController: NSObject {
    private enum DimmingStep {
        static let brightness = 5
        static let blueReduction = 5
    }

    private enum SettingsRuntimeError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "Settings runtime is unavailable."
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let brightnessController: BrightnessController
    private let displayInventory: DisplayInventoryProviding
    private let displayTargetStore: DisplayTargetStore
    private let diagnosticsStore: DiagnosticsStore
    private var shortcutBindings: [ShortcutBinding]
    private let hotkeyRegistrationBackend: HotkeyRegistrationBackend
    private let registersHotkeysOnStart: Bool
    private var scheduleEntries: [ScheduleEntry]
    private let scheduleTimerController: ScheduleTimerController
    private let loginItemController: LoginItemControlling
    private let currentMinuteOfDay: () -> Int
    private let popover = NSPopover()
    private var dashboardWindowController: AppDashboardWindowController?
    private var scheduleEditorWindowController: ScheduleEditorWindowController?
    private lazy var settingsWindowController = SettingsWindowController(actions: makeSettingsActions())
    private var hotkeyManager: HotkeyManager?
    private var commandBeforeQuickDisable: BrightnessCommand?
    private var scheduleReconciliationObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var runtimeBoundaryReconcileTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        brightnessController: BrightnessController = BrightnessController(),
        displayInventory: DisplayInventoryProviding = DisplayInventory(),
        displayTargetStore: DisplayTargetStore = DisplayTargetStore(),
        diagnosticsStore: DiagnosticsStore = DiagnosticsStore(),
        shortcutBindings: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        hotkeyRegistrationBackend: HotkeyRegistrationBackend = CarbonHotkeyRegistrationBackend(),
        registersHotkeysOnStart: Bool? = nil,
        scheduleEntries: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        scheduleTimerController: ScheduleTimerController = ScheduleTimerController(),
        loginItemController: LoginItemControlling = LoginItemController(),
        currentMinuteOfDay: @escaping () -> Int = { MenuBarController.systemMinuteOfDay() }
    ) {
        self.brightnessController = brightnessController
        self.displayInventory = displayInventory
        self.displayTargetStore = displayTargetStore
        self.diagnosticsStore = diagnosticsStore
        self.shortcutBindings = shortcutBindings
        self.hotkeyRegistrationBackend = hotkeyRegistrationBackend
        self.registersHotkeysOnStart = registersHotkeysOnStart
            ?? Self.defaultRegistersHotkeysOnStart(backend: hotkeyRegistrationBackend)
        self.scheduleEntries = scheduleEntries
        self.scheduleTimerController = scheduleTimerController
        self.loginItemController = loginItemController
        self.currentMinuteOfDay = currentMinuteOfDay
        super.init()
    }

    func start() {
        record(.appLifecycle, "Menu bar controller started")
        hasStarted = true
        loadPersistedSettingsForRuntime()
        _ = stateResolvingSelectedDisplayIfNeeded()
        applyScheduleDecision()
        let initialState = brightnessController.state
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.title = "☀"
        statusItem.button?.toolTip = "InnosDimmer"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentSize = MenuBarPopoverView.preferredContentSize
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = MenuBarPopoverView(
            state: initialState,
            schedule: scheduleEntries,
            shortcuts: shortcutBindings,
            latestDiagnosticEvent: diagnosticsStore.latestEvent,
            actions: MenuBarActions { [weak self] command in
                self?.perform(command)
            }
        )
        if registersHotkeysOnStart {
            registerHotkeys()
        }
        registerScheduleReconciliationObservers()
        scheduleNextBoundaryTimer()
        showAppWindow()
    }

    func stop() {
        brightnessController.clearCurrentSoftwareState()
        stopHotkeys()
        scheduleTimerController.invalidate()
        runtimeBoundaryReconcileTask?.cancel()
        runtimeBoundaryReconcileTask = nil
        unregisterScheduleReconciliationObservers()
        hasStarted = false
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            _ = stateResolvingSelectedDisplayIfNeeded()
            refreshPopover()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func perform(_ command: MenuBarCommand) {
        perform(command, source: .menuSlider)
    }

    private func perform(_ command: MenuBarCommand, source: BrightnessCommandSource) {
        switch command {
        case .brightnessDown:
            adjust(brightnessDelta: -DimmingStep.brightness, source: source)
        case .brightnessUp:
            adjust(brightnessDelta: DimmingStep.brightness, source: source)
        case .setBrightness(let brightness):
            apply(
                brightness: brightness,
                blueReduction: brightnessController.state.targetBlueReduction,
                source: source
            )
        case .blueReductionDown:
            adjust(blueReductionDelta: -DimmingStep.blueReduction, source: source)
        case .blueReductionUp:
            adjust(blueReductionDelta: DimmingStep.blueReduction, source: source)
        case .setBlueReduction(let blueReduction):
            apply(
                brightness: brightnessController.state.targetBrightness,
                blueReduction: blueReduction,
                source: source
            )
        case .quickDisable:
            quickDisable(source: source)
        case .restorePrevious:
            restorePrevious()
        case .openAppWindow:
            showAppWindow()
        case .openScheduleEditor:
            showScheduleEditor()
        case .openSettings:
            openSettings()
        case .pauseAutomation:
            pauseAutomationUntilNextBoundary(messagePrefix: "Automation pause requested")
        case .resumeAutomation:
            resumeAutomation()
        }
    }

    private func handleShortcut(_ action: ShortcutAction) {
        perform(action.menuBarCommand, source: .hotkey)
    }

    private func stopHotkeys() {
        hotkeyManager?.stop()
        hotkeyManager = nil
    }

    private func registerHotkeys() {
        stopHotkeys()

        let manager = HotkeyManager(backend: hotkeyRegistrationBackend) { [weak self] action in
            Task { @MainActor in
                self?.handleShortcut(action)
            }
        }

        do {
            try manager.start(bindings: shortcutBindings)
            hotkeyManager = manager
            record(.shortcut, "Registered \(shortcutBindings.filter(\.isEnabled).count) shortcuts")
        } catch {
            hotkeyManager = nil
            record(.shortcut, "Shortcut registration failed: \(error)", .warning)
        }
    }

    private func adjust(
        brightnessDelta: Int = 0,
        blueReductionDelta: Int = 0,
        source: BrightnessCommandSource = .menuSlider
    ) {
        let state = brightnessController.state
        apply(
            brightness: state.targetBrightness + brightnessDelta,
            blueReduction: state.targetBlueReduction + blueReductionDelta,
            source: source
        )
    }

    private func quickDisable(source: BrightnessCommandSource = .menuSlider) {
        let state = brightnessController.state
        commandBeforeQuickDisable = makeCommand(
            brightness: state.targetBrightness,
            blueReduction: state.targetBlueReduction,
            source: source
        )
        apply(brightness: 100, blueReduction: 0, source: source)
    }

    private func restorePrevious() {
        guard let command = commandBeforeQuickDisable else {
            record(.softwareDimming, "Restore previous requested without saved state", .warning)
            refreshPopover()
            return
        }

        applyCommand(command)
        commandBeforeQuickDisable = nil
    }

    private func showAppWindow() {
        let controller = dashboardWindowController ?? AppDashboardWindowController(
            actions: MenuBarActions { [weak self] command in
                self?.perform(command)
            },
            scheduleActions: makeScheduleEditorActions()
        )
        dashboardWindowController = controller
        refreshAppWindow()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showScheduleEditor() {
        let controller = scheduleEditorWindowController ?? ScheduleEditorWindowController(
            actions: makeScheduleEditorActions()
        )
        scheduleEditorWindowController = controller
        controller.configure(schedule: scheduleEntries)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        record(.appLifecycle, "Opened schedule editor")
        refreshPopover()
    }

    private func openSettings() {
        record(.appLifecycle, "Opened settings")
        settingsWindowController.configure(
            snapshot: displayTargetStore.load(),
            displayCandidates: displayInventory.activeDisplays(),
            loginItemStatus: loginItemController.status()
        )
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshPopover()
    }

    private func makeSettingsActions() -> SettingsActions {
        SettingsActions(
            selectDisplay: { [weak self] display in
                self?.saveSelectedDisplay(display) ?? .failure(SettingsRuntimeError.unavailable)
            },
            openScheduleEditor: { [weak self] in
                self?.showScheduleEditor()
            },
            updateShortcuts: { [weak self] shortcuts in
                self?.saveShortcuts(shortcuts) ?? .failure(SettingsRuntimeError.unavailable)
            },
            setLaunchAtLogin: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled) ?? .failure(SettingsRuntimeError.unavailable)
            },
            exportDiagnostics: { [weak self] in
                self?.exportDiagnosticsData() ?? .failure(SettingsRuntimeError.unavailable)
            }
        )
    }

    private func makeScheduleEditorActions() -> ScheduleEditorActions {
        ScheduleEditorActions(
            updateSchedule: { [weak self] schedule in
                self?.saveSchedule(schedule) ?? .failure(SettingsRuntimeError.unavailable)
            }
        )
    }

    private func loadPersistedSettingsForRuntime() {
        let snapshot = displayTargetStore.load()
        shortcutBindings = snapshot.shortcuts
        scheduleEntries = snapshot.schedule

        var state = brightnessController.state
        state.targetBrightness = snapshot.state.targetBrightness
        state.targetBlueReduction = snapshot.state.targetBlueReduction
        brightnessController.applyPreviewState(state)
    }

    private func saveSelectedDisplay(_ display: DisplayIdentity?) -> Result<SettingsSnapshot, Error> {
        do {
            let snapshot = try displayTargetStore.saveSelectedDisplay(display)
            var state = brightnessController.state
            state.display = display
            brightnessController.applyPreviewState(state)

            if display == nil {
                _ = resolveSelectedDisplay()
            }

            record(.display, Self.selectedDisplaySavedMessage(for: display))
            refreshPopover()
            return .success(snapshot)
        } catch {
            record(.display, "Saving selected display failed: \(error)", .warning)
            refreshPopover()
            return .failure(error)
        }
    }

    private func saveSchedule(_ schedule: [ScheduleEntry]) -> Result<SettingsSnapshot, Error> {
        do {
            let snapshot = try displayTargetStore.saveSchedule(schedule)
            scheduleEntries = snapshot.schedule
            record(.schedule, "Saved \(scheduleEntries.count) schedule entries")
            applyScheduleDecision()
            scheduleNextBoundaryTimerIfRunning()
            return .success(snapshot)
        } catch {
            record(.schedule, "Saving schedule failed: \(error)", .warning)
            refreshPopover()
            return .failure(error)
        }
    }

    private func saveShortcuts(_ shortcuts: [ShortcutBinding]) -> Result<SettingsSnapshot, Error> {
        do {
            let snapshot = try displayTargetStore.saveShortcuts(shortcuts)
            shortcutBindings = snapshot.shortcuts
            if hasStarted && registersHotkeysOnStart {
                registerHotkeys()
            }
            record(.shortcut, "Saved \(shortcutBindings.filter(\.isEnabled).count) enabled shortcuts")
            refreshPopover()
            return .success(snapshot)
        } catch {
            record(.shortcut, "Saving shortcuts failed: \(error)", .warning)
            refreshPopover()
            return .failure(error)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) -> Result<LoginItemStatus, Error> {
        do {
            try loginItemController.setEnabled(enabled)
            let status = loginItemController.status()
            record(.appLifecycle, "Launch at login \(enabled ? "enabled" : "disabled"): \(Self.loginItemStatusLabel(for: status))")
            return .success(status)
        } catch {
            record(.appLifecycle, "Launch at login update failed: \(error)", .warning)
            return .failure(error)
        }
    }

    func exportDiagnosticsForTesting() -> Result<Data, Error> {
        exportDiagnosticsData()
    }

    private func exportDiagnosticsData() -> Result<Data, Error> {
        do {
            record(.appLifecycle, "Prepared diagnostics export")
            let snapshot = diagnosticsStore.snapshot(
                selectedDisplay: brightnessController.state.display,
                state: brightnessController.state,
                matrixSummary: VerificationMatrix.summary(for: VerificationMatrix.defaultRows)
            )
            return .success(try DiagnosticsExporter.export(snapshot))
        } catch {
            record(.appLifecycle, "Diagnostics export failed: \(error)", .warning)
            return .failure(error)
        }
    }

    private func apply(brightness: Int, blueReduction: Int, source: BrightnessCommandSource) {
        guard let command = makeCommand(brightness: brightness, blueReduction: blueReduction, source: source) else {
            refreshPopover()
            return
        }

        applyCommand(command)
    }

    @discardableResult
    private func applyCommand(
        _ command: BrightnessCommand,
        updatesManualOverride: Bool = true,
        reschedulesBoundaryTimer: Bool = true,
        refreshesPopover: Bool = true
    ) -> Bool {
        let previousMode = brightnessController.state.activeMode
        brightnessController.apply(command)
        let softwareFailed = brightnessController.lastSoftwareDimmingFailure?.command == command
        if !softwareFailed && updatesManualOverride {
            pauseAutomationAfterManualCommandIfNeeded(command)
        }
        recordAppliedCommand(command, previousMode: previousMode)
        if reschedulesBoundaryTimer {
            scheduleNextBoundaryTimerIfRunning()
        }
        if refreshesPopover {
            refreshPopover()
        }
        return !softwareFailed
    }

    private func makeCommand(brightness: Int, blueReduction: Int, source: BrightnessCommandSource) -> BrightnessCommand? {
        guard let display = resolveFreshDisplay() else {
            record(.display, "Skipped dimming command because no display is selected", .warning)
            return nil
        }

        return BrightnessCommand(
            display: display,
            brightness: brightness,
            blueReduction: blueReduction,
            source: source
        )
    }

    private func stateResolvingSelectedDisplayIfNeeded() -> BrightnessState {
        _ = resolveFreshDisplay()

        return brightnessController.state
    }

    @discardableResult
    private func resolveSelectedDisplay() -> DisplayIdentity? {
        resolveFreshDisplay()
    }

    @discardableResult
    private func resolveFreshDisplay(activeDisplays: [DisplayIdentity]? = nil) -> DisplayIdentity? {
        let candidates = activeDisplays ?? displayInventory.activeDisplays()
        let snapshot = displayTargetStore.load()
        let resolved = displayInventory.resolveSelectedDisplay(
            saved: snapshot.selectedDisplay,
            candidates: candidates
        )

        if let current = brightnessController.state.display,
           let activeCurrent = candidates.first(where: { $0.cgDisplayID == current.cgDisplayID }),
           resolved?.cgDisplayID == activeCurrent.cgDisplayID {
            if activeCurrent != current {
                var state = brightnessController.state
                state.display = activeCurrent
                brightnessController.applyPreviewState(state)
            }
            return activeCurrent
        }

        guard let display = resolved else {
            var state = brightnessController.state
            state.display = nil
            brightnessController.applyPreviewState(state)
            record(.display, "No eligible external display found", .warning)
            return nil
        }

        var state = brightnessController.state
        state.display = display
        brightnessController.applyPreviewState(state)
        record(.display, "Selected display \(display.localizedName)")
        return display
    }

    private func refreshPopover() {
        guard let view = popover.contentViewController?.view as? MenuBarPopoverView else {
            return
        }

        view.update(
            state: brightnessController.state,
            schedule: scheduleEntries,
            shortcuts: shortcutBindings,
            latestDiagnosticEvent: diagnosticsStore.latestEvent
        )
    }

    private func refreshAppWindow() {
        dashboardWindowController?.update(
            state: brightnessController.state,
            schedule: scheduleEntries,
            shortcuts: shortcutBindings,
            events: diagnosticsStore.events
        )
    }

    private func applyScheduleDecision() {
        let decision = ScheduleEngine.decision(
            at: currentMinuteOfDay(),
            entries: scheduleEntries,
            state: brightnessController.state
        )

        switch decision {
        case .apply(let entry, _, _):
            applyScheduledEntry(entry, decision: decision)
        case .paused:
            refreshPopover()
        case .idle:
            scheduleTimerController.invalidate()
            refreshPopover()
        }
    }

    @discardableResult
    private func applyScheduledEntry(_ entry: ScheduleEntry, decision: ScheduleDecision) -> Bool {
        guard let command = makeCommand(
            brightness: entry.brightness,
            blueReduction: entry.blueReduction,
            source: .schedule
        ) else {
            record(.schedule, "Skipped schedule because no display is selected", .warning)
            refreshPopover()
            return false
        }

        let applied = applyCommand(
            command,
            updatesManualOverride: false,
            reschedulesBoundaryTimer: false,
            refreshesPopover: false
        )
        guard applied else {
            refreshPopover()
            return false
        }

        let updatedState = ScheduleEngine.stateAfterApplying(decision, to: brightnessController.state)
        brightnessController.applyPreviewState(updatedState)
        record(.schedule, "Applied scheduled brightness \(entry.brightness)% blue reduction \(entry.blueReduction)%")
        refreshPopover()
        return true
    }

    private func resumeAutomation() {
        let minuteOfDay = currentMinuteOfDay()
        guard let activeEntry = ScheduleEngine.activeEntry(at: minuteOfDay, entries: scheduleEntries) else {
            let updatedState = ScheduleEngine.stateAfterResumingAutomation(from: brightnessController.state)
            brightnessController.applyPreviewState(updatedState)
            record(.schedule, "Automation resumed; no schedule entries configured")
            scheduleNextBoundaryTimerIfRunning()
            refreshPopover()
            return
        }

        let decision = ScheduleDecision.apply(
            entry: activeEntry,
            nextBoundaryMinuteOfDay: ScheduleEngine.nextBoundary(after: minuteOfDay, entries: scheduleEntries) ?? activeEntry.minuteOfDay,
            clearsManualOverride: true
        )

        guard applyScheduledEntry(activeEntry, decision: decision) else {
            return
        }

        record(.schedule, "Automation resumed")
        scheduleNextBoundaryTimerIfRunning()
        refreshPopover()
    }

    private func pauseAutomationAfterManualCommandIfNeeded(_ command: BrightnessCommand) {
        guard Self.pausesAutomation(for: command.source) else {
            return
        }

        pauseAutomationUntilNextBoundary(
            messagePrefix: "Manual \(Self.commandSourceLabel(for: command.source)) override",
            reschedulesBoundaryTimer: false,
            refreshesPopover: false
        )
    }

    private func pauseAutomationUntilNextBoundary(
        messagePrefix: String,
        reschedulesBoundaryTimer: Bool = true,
        refreshesPopover: Bool = true
    ) {
        let updatedState = ScheduleEngine.stateAfterManualOverride(
            from: brightnessController.state,
            at: currentMinuteOfDay(),
            entries: scheduleEntries
        )
        brightnessController.applyPreviewState(updatedState)

        if let resumeMinute = updatedState.automationResumeMinuteOfDay {
            record(.schedule, "\(messagePrefix); automation paused until \(Self.timeLabel(for: resumeMinute))")
        } else {
            record(.schedule, "\(messagePrefix); automation paused until next schedule boundary")
        }

        if reschedulesBoundaryTimer {
            scheduleNextBoundaryTimerIfRunning()
        }
        if refreshesPopover {
            refreshPopover()
        }
    }

    @discardableResult
    private func scheduleNextBoundaryTimer() -> ScheduledScheduleBoundary? {
        scheduleTimerController.scheduleNextBoundary(
            after: currentMinuteOfDay(),
            entries: scheduleEntries
        ) { [weak self] in
            self?.handleScheduleBoundaryTimerFired()
        }
    }

    private func scheduleNextBoundaryTimerIfRunning() {
        guard hasStarted else {
            return
        }

        scheduleNextBoundaryTimer()
    }

    private func handleScheduleBoundaryTimerFired() {
        applyScheduleDecision()
        scheduleNextBoundaryTimer()
    }

    private func reconcileScheduleAfterRuntimeBoundaryChange() {
        let activeDisplays = displayInventory.activeDisplays()
        let activeDisplayIDs = Set(activeDisplays.map(\.cgDisplayID))
        brightnessController.clearStaleSoftwarePanels(activeDisplayIDs: activeDisplayIDs)
        _ = resolveFreshDisplay(activeDisplays: activeDisplays)
        brightnessController.reapplyCurrentSoftwareState()
        applyScheduleDecision()
        scheduleNextBoundaryTimer()
    }

    private func scheduleRuntimeBoundaryReconcile() {
        runtimeBoundaryReconcileTask?.cancel()
        runtimeBoundaryReconcileTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                self?.reconcileScheduleAfterRuntimeBoundaryChange()
            }
        }
    }

    private func registerScheduleReconciliationObservers() {
        guard scheduleReconciliationObservers.isEmpty else {
            return
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRuntimeBoundaryReconcile()
            }
        }

        let screensWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRuntimeBoundaryReconcile()
            }
        }

        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRuntimeBoundaryReconcile()
            }
        }

        scheduleReconciliationObservers = [
            (workspaceCenter, wakeObserver),
            (workspaceCenter, screensWakeObserver),
            (NotificationCenter.default, screenObserver)
        ]
    }

    private func unregisterScheduleReconciliationObservers() {
        for (center, observer) in scheduleReconciliationObservers {
            center.removeObserver(observer)
        }
        scheduleReconciliationObservers.removeAll()
    }

    @discardableResult
    private func record(
        _ category: DiagnosticsCategory,
        _ message: String,
        _ severity: DiagnosticsSeverity = .info
    ) -> DiagnosticsEvent {
        let event = diagnosticsStore.record(
            category: category,
            message: message,
            severity: severity
        )
        refreshAppWindow()
        return event
    }

    private func recordAppliedCommand(_ command: BrightnessCommand, previousMode: DimmingMode) {
        if let failure = brightnessController.lastSoftwareDimmingFailure,
           failure.command == command {
            record(
                .softwareDimming,
                "Software dimming failed for \(command.display.localizedName): \(failure.message)",
                .error
            )
            return
        }

        let state = brightnessController.state
        record(
            Self.diagnosticsCategory(for: state.activeMode),
            "Applied brightness \(state.targetBrightness)% blue reduction \(state.targetBlueReduction)% on \(command.display.localizedName)",
            Self.diagnosticsSeverity(for: state.activeMode)
        )

        if state.activeMode == .overlay, previousMode != .overlay {
            record(.softwareDimming, "Software dimming active for \(command.display.localizedName)")
        } else if state.activeMode == .platformBlocked {
            record(.softwareDimming, "Software dimming blocked for \(command.display.localizedName)", .error)
        }
    }

    private static func diagnosticsCategory(for mode: DimmingMode) -> DiagnosticsCategory {
        switch mode {
        case .gamma, .overlay, .platformBlocked:
            return .softwareDimming
        case .unknown:
            return .display
        }
    }

    private static func diagnosticsSeverity(for mode: DimmingMode) -> DiagnosticsSeverity {
        mode == .platformBlocked ? .error : .info
    }

    private static func pausesAutomation(for source: BrightnessCommandSource) -> Bool {
        switch source {
        case .menuSlider, .hotkey:
            return true
        case .schedule, .startupRestore:
            return false
        }
    }

    private static func commandSourceLabel(for source: BrightnessCommandSource) -> String {
        switch source {
        case .menuSlider:
            return "menu"
        case .hotkey:
            return "hotkey"
        case .schedule:
            return "schedule"
        case .startupRestore:
            return "startup"
        }
    }

    private static func selectedDisplaySavedMessage(for display: DisplayIdentity?) -> String {
        if let display {
            return "Saved selected display \(display.localizedName)"
        }

        return "Saved automatic display selection"
    }

    private static func loginItemStatusLabel(for status: LoginItemStatus) -> String {
        switch status {
        case .enabled:
            return "enabled"
        case .disabled:
            return "disabled"
        case .requiresApproval:
            return "requires approval"
        case .notRegistered:
            return "not registered"
        case .unsupported(let reason):
            return "unsupported: \(reason)"
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func systemMinuteOfDay(date: Date = Date(), calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func defaultRegistersHotkeysOnStart(backend: HotkeyRegistrationBackend) -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           backend is CarbonHotkeyRegistrationBackend {
            return false
        }

        return true
    }
}

extension ShortcutAction {
    var menuBarCommand: MenuBarCommand {
        switch self {
        case .brightnessUp:
            return .brightnessUp
        case .brightnessDown:
            return .brightnessDown
        case .blueReductionUp:
            return .blueReductionUp
        case .blueReductionDown:
            return .blueReductionDown
        case .quickDisableOverlay:
            return .quickDisable
        case .restorePreviousDimming:
            return .restorePrevious
        }
    }
}
