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
    private let popover = NSPopover()
    private lazy var settingsWindowController = SettingsWindowController()
    private var commandBeforeQuickDisable: BrightnessCommand?

    init(
        brightnessController: BrightnessController = BrightnessController(),
        displayInventory: DisplayInventory = DisplayInventory(),
        displayTargetStore: DisplayTargetStore = DisplayTargetStore(),
        diagnosticsStore: DiagnosticsStore = DiagnosticsStore()
    ) {
        self.brightnessController = brightnessController
        self.displayInventory = displayInventory
        self.displayTargetStore = displayTargetStore
        self.diagnosticsStore = diagnosticsStore
        super.init()
    }

    func start() {
        record(.appLifecycle, "Menu bar controller started")
        let initialState = stateResolvingSelectedDisplayIfNeeded()
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
        switch command {
        case .brightnessDown:
            adjust(brightnessDelta: -DimmingStep.brightness)
        case .brightnessUp:
            adjust(brightnessDelta: DimmingStep.brightness)
        case .warmthDown:
            adjust(warmthDelta: -DimmingStep.warmth)
        case .warmthUp:
            adjust(warmthDelta: DimmingStep.warmth)
        case .quickDisable:
            quickDisable()
        case .restorePrevious:
            restorePrevious()
        case .openSettings:
            openSettings()
        case .probeDDC:
            record(.hardwareProbe, "DDC probe requested")
            refreshPopover()
        case .pauseAutomation:
            record(.schedule, "Pause automation requested")
            refreshPopover()
        }
    }

    private func adjust(brightnessDelta: Int = 0, warmthDelta: Int = 0) {
        let state = brightnessController.state
        apply(
            brightness: state.targetBrightness + brightnessDelta,
            warmth: state.targetWarmth + warmthDelta,
            source: .menuSlider
        )
    }

    private func quickDisable() {
        let state = brightnessController.state
        commandBeforeQuickDisable = makeCommand(
            brightness: state.targetBrightness,
            warmth: state.targetWarmth,
            source: .menuSlider
        )
        apply(brightness: 100, warmth: state.targetWarmth, source: .menuSlider)
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

    private func applyCommand(_ command: BrightnessCommand) {
        let previousMode = brightnessController.state.activeMode
        brightnessController.apply(command)
        if brightnessController.pendingCommand == command {
            applyPendingPreview(command)
        }
        recordAppliedCommand(command, previousMode: previousMode)
        refreshPopover()
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
}
