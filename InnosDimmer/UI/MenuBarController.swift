import AppKit

@MainActor
final class MenuBarController: NSObject {
    private enum DimmingStep {
        static let brightness = 5
        static let warmth = 5
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let brightnessController: BrightnessController
    private let displayInventory: DisplayInventory
    private let displayTargetStore: DisplayTargetStore
    private let diagnosticsStore: DiagnosticsStore
    private let shortcutBindings: [ShortcutBinding]
    private let hotkeyRegistrationBackend: HotkeyRegistrationBackend
    private let registersHotkeysOnStart: Bool
    private let scheduleEntries: [ScheduleEntry]
    private let scheduleTimerController: ScheduleTimerController
    private let currentMinuteOfDay: () -> Int
    private let popover = NSPopover()
    private lazy var settingsWindowController = SettingsWindowController()
    private var hotkeyManager: HotkeyManager?
    private var commandBeforeQuickDisable: BrightnessCommand?
    private var scheduleReconciliationObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private var hasStarted = false

    init(
        brightnessController: BrightnessController = BrightnessController(),
        displayInventory: DisplayInventory = DisplayInventory(),
        displayTargetStore: DisplayTargetStore = DisplayTargetStore(),
        diagnosticsStore: DiagnosticsStore = DiagnosticsStore(),
        shortcutBindings: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        hotkeyRegistrationBackend: HotkeyRegistrationBackend = CarbonHotkeyRegistrationBackend(),
        registersHotkeysOnStart: Bool? = nil,
        scheduleEntries: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        scheduleTimerController: ScheduleTimerController = ScheduleTimerController(),
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
        self.currentMinuteOfDay = currentMinuteOfDay
        super.init()
    }

    func start() {
        record(.appLifecycle, "Menu bar controller started")
        hasStarted = true
        _ = stateResolvingSelectedDisplayIfNeeded()
        applyScheduleDecision()
        let initialState = brightnessController.state
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "InnosDimmer")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 330)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = MenuBarPopoverView(
            state: initialState,
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
    }

    func stop() {
        stopHotkeys()
        scheduleTimerController.invalidate()
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
        case .warmthDown:
            adjust(warmthDelta: -DimmingStep.warmth, source: source)
        case .warmthUp:
            adjust(warmthDelta: DimmingStep.warmth, source: source)
        case .quickDisable:
            quickDisable(source: source)
        case .restorePrevious:
            restorePrevious()
        case .openSettings:
            openSettings()
        case .probeDDC:
            record(.hardwareProbe, "DDC probe requested")
            refreshPopover()
        case .pauseAutomation:
            pauseAutomationUntilNextBoundary(messagePrefix: "Automation pause requested")
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
        warmthDelta: Int = 0,
        source: BrightnessCommandSource = .menuSlider
    ) {
        let state = brightnessController.state
        apply(
            brightness: state.targetBrightness + brightnessDelta,
            warmth: state.targetWarmth + warmthDelta,
            source: source
        )
    }

    private func quickDisable(source: BrightnessCommandSource = .menuSlider) {
        let state = brightnessController.state
        commandBeforeQuickDisable = makeCommand(
            brightness: state.targetBrightness,
            warmth: state.targetWarmth,
            source: source
        )
        apply(brightness: 100, warmth: state.targetWarmth, source: source)
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

    private func openSettings() {
        record(.appLifecycle, "Opened settings")
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshPopover()
    }

    private func apply(brightness: Int, warmth: Int, source: BrightnessCommandSource) {
        guard let command = makeCommand(brightness: brightness, warmth: warmth, source: source) else {
            refreshPopover()
            return
        }

        applyCommand(command)
    }

    private func applyCommand(
        _ command: BrightnessCommand,
        updatesManualOverride: Bool = true,
        reschedulesBoundaryTimer: Bool = true,
        refreshesPopover: Bool = true
    ) {
        let previousMode = brightnessController.state.activeMode
        brightnessController.apply(command)
        if brightnessController.pendingCommand == command {
            applyPendingPreview(command)
        }
        if updatesManualOverride {
            pauseAutomationAfterManualCommandIfNeeded(command)
        }
        recordAppliedCommand(command, previousMode: previousMode)
        if reschedulesBoundaryTimer {
            scheduleNextBoundaryTimerIfRunning()
        }
        if refreshesPopover {
            refreshPopover()
        }
    }

    private func applyPendingPreview(_ command: BrightnessCommand) {
        var state = brightnessController.state
        state.display = command.display
        state.targetBrightness = command.brightness
        state.targetWarmth = command.warmth
        state.lastAppliedCommandSource = command.source
        brightnessController.applyPreviewState(state)
    }

    private func makeCommand(brightness: Int, warmth: Int, source: BrightnessCommandSource) -> BrightnessCommand? {
        guard let display = brightnessController.state.display ?? resolveSelectedDisplay() else {
            record(.display, "Skipped dimming command because no display is selected", .warning)
            return nil
        }

        return BrightnessCommand(
            display: display,
            brightness: brightness,
            warmth: warmth,
            source: source
        )
    }

    private func stateResolvingSelectedDisplayIfNeeded() -> BrightnessState {
        if brightnessController.state.display == nil {
            _ = resolveSelectedDisplay()
        }

        return brightnessController.state
    }

    @discardableResult
    private func resolveSelectedDisplay() -> DisplayIdentity? {
        guard let display = displayInventory.selectedDisplay(using: displayTargetStore) else {
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
            latestDiagnosticEvent: diagnosticsStore.latestEvent
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

    private func applyScheduledEntry(_ entry: ScheduleEntry, decision: ScheduleDecision) {
        guard let command = makeCommand(
            brightness: entry.brightness,
            warmth: entry.warmth,
            source: .schedule
        ) else {
            record(.schedule, "Skipped schedule because no display is selected", .warning)
            refreshPopover()
            return
        }

        applyCommand(
            command,
            updatesManualOverride: false,
            reschedulesBoundaryTimer: false,
            refreshesPopover: false
        )
        let updatedState = ScheduleEngine.stateAfterApplying(decision, to: brightnessController.state)
        brightnessController.applyPreviewState(updatedState)
        record(.schedule, "Applied scheduled brightness \(entry.brightness)% warmth \(entry.warmth)%")
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
        _ = stateResolvingSelectedDisplayIfNeeded()
        applyScheduleDecision()
        scheduleNextBoundaryTimer()
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
                self?.reconcileScheduleAfterRuntimeBoundaryChange()
            }
        }

        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileScheduleAfterRuntimeBoundaryChange()
            }
        }

        scheduleReconciliationObservers = [
            (workspaceCenter, wakeObserver),
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
        diagnosticsStore.record(
            category: category,
            message: message,
            severity: severity
        )
    }

    private func recordAppliedCommand(_ command: BrightnessCommand, previousMode: DimmingMode) {
        if brightnessController.pendingCommand == command {
            record(
                .display,
                "Queued brightness \(command.brightness)% warmth \(command.warmth)% for \(command.display.localizedName)"
            )
            return
        }

        let state = brightnessController.state
        record(
            Self.diagnosticsCategory(for: state.activeMode),
            "Applied brightness \(state.targetBrightness)% warmth \(state.targetWarmth)% on \(command.display.localizedName)",
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
        case .hardwareDDC:
            return .hardwareProbe
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
        case .schedule, .startupRestore, .diagnosticsProbe, .forcedSoftwareTest:
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
        case .diagnosticsProbe:
            return "diagnostics"
        case .forcedSoftwareTest:
            return "forced software"
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
        case .warmthUp:
            return .warmthUp
        case .warmthDown:
            return .warmthDown
        case .quickDisableOverlay:
            return .quickDisable
        case .restorePreviousDimming:
            return .restorePrevious
        }
    }
}
