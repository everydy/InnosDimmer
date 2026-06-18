import AppKit

enum MenuBarCommand: CaseIterable, Equatable, Hashable {
    case brightnessDown
    case brightnessUp
    case warmthDown
    case warmthUp
    case probeDDC
    case pauseAutomation
    case quickDisable
    case restorePrevious
    case openSettings
}

struct MenuBarActions {
    var perform: @MainActor (MenuBarCommand) -> Void

    static let noop = MenuBarActions { _ in }
}

struct MenuBarViewModel: Equatable {
    var modeTitle: String
    var displaySummary: String
    var brightnessLabel: String
    var warmthLabel: String
    var automationTitle: String
    var scheduleSummary: String
    var shortcutSummary: String
    var diagnosticsSummary: String

    init(
        state: BrightnessState,
        shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        latestDiagnosticEvent: DiagnosticsEvent? = nil
    ) {
        modeTitle = ModeStatusLabel.title(for: state.activeMode)
        displaySummary = state.display.map { "Display: \($0.localizedName)" } ?? "Display: Not selected"
        brightnessLabel = "\(state.targetBrightness)%"
        warmthLabel = "\(state.targetWarmth)%"
        if state.automationPausedUntilNextBoundary, let resumeMinute = state.automationResumeMinuteOfDay {
            automationTitle = "Automation paused until \(Self.timeLabel(for: resumeMinute))"
        } else if state.automationPausedUntilNextBoundary {
            automationTitle = "Automation paused until next schedule boundary"
        } else {
            automationTitle = "Automation active"
        }
        scheduleSummary = "Schedule: 09:00 / 19:00 / 23:00"
        shortcutSummary = HotkeyManager.summary(for: shortcuts)
        diagnosticsSummary = Self.diagnosticsSummary(
            state: state,
            latestDiagnosticEvent: latestDiagnosticEvent
        )
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func hardwareSummary(for capability: HardwareCapability) -> String {
        capability.diagnosticSummary
    }

    private static func diagnosticsSummary(
        state: BrightnessState,
        latestDiagnosticEvent: DiagnosticsEvent?
    ) -> String {
        var parts = [
            "Diagnostics: \(ModeStatusLabel.title(for: state.activeMode)), \(hardwareSummary(for: state.hardwareCapability))"
        ]
        let latestEventIsProbeResult = latestDiagnosticEvent?.category == .hardwareProbe
            && latestDiagnosticEvent?.message.hasPrefix("DDC probe result") == true

        if let lastHardwareProbeResult = state.lastHardwareProbeResult,
           !latestEventIsProbeResult {
            parts.append("Probe: \(lastHardwareProbeResult.diagnosticSummary)")
        }

        if let latestDiagnosticEvent {
            parts.append("Last: \(latestDiagnosticEvent.message)")
        }

        return parts.joined(separator: ". ")
    }
}

final class MenuBarPopoverView: NSView {
    private let modeBadge: StatusBadgeView
    private let actions: MenuBarActions
    private let displaySummaryLabel = NSTextField(labelWithString: "")
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let warmthValueLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let shortcutSummaryLabel = NSTextField(labelWithString: "")
    private let diagnosticsSummaryLabel = NSTextField(labelWithString: "")
    private var commandButtons: [MenuBarCommand: NSButton] = [:]

    init(
        state: BrightnessState,
        latestDiagnosticEvent: DiagnosticsEvent? = nil,
        actions: MenuBarActions = .noop
    ) {
        modeBadge = StatusBadgeView(mode: state.activeMode)
        self.actions = actions
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 330))
        buildLayout()
        update(state: state, latestDiagnosticEvent: latestDiagnosticEvent)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(state: BrightnessState, latestDiagnosticEvent: DiagnosticsEvent? = nil) {
        let viewModel = MenuBarViewModel(
            state: state,
            latestDiagnosticEvent: latestDiagnosticEvent
        )
        modeBadge.stringValue = viewModel.modeTitle
        displaySummaryLabel.stringValue = viewModel.displaySummary
        brightnessValueLabel.stringValue = viewModel.brightnessLabel
        warmthValueLabel.stringValue = viewModel.warmthLabel
        automationLabel.stringValue = viewModel.automationTitle
        scheduleSummaryLabel.stringValue = viewModel.scheduleSummary
        shortcutSummaryLabel.stringValue = viewModel.shortcutSummary
        diagnosticsSummaryLabel.stringValue = viewModel.diagnosticsSummary
    }

    func commandButtonForTesting(_ command: MenuBarCommand) -> NSButton? {
        commandButtons[command]
    }

    func displaySummaryForTesting() -> String {
        displaySummaryLabel.stringValue
    }

    func brightnessLabelForTesting() -> String {
        brightnessValueLabel.stringValue
    }

    func diagnosticsSummaryForTesting() -> String {
        diagnosticsSummaryLabel.stringValue
    }

    private func buildLayout() {
        let title = NSTextField(labelWithString: "INNOS 27QA100M")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let brightnessTitle = NSTextField(labelWithString: "Brightness")
        let warmthTitle = NSTextField(labelWithString: "Warmth")
        let probeButton = button("DDC Probe", command: .probeDDC, action: #selector(probeDDCPressed))
        let pauseButton = button("Pause automation", command: .pauseAutomation, action: #selector(pauseAutomationPressed))
        let brightnessDownButton = button("Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed))
        let brightnessUpButton = button("Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))
        let warmthDownButton = button("Warmth down", command: .warmthDown, action: #selector(warmthDownPressed))
        let warmthUpButton = button("Warmth up", command: .warmthUp, action: #selector(warmthUpPressed))
        let quickDisableButton = button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed))
        let restorePreviousButton = button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed))
        let settingsButton = button("Settings", command: .openSettings, action: #selector(openSettingsPressed))

        let stack = NSStackView(views: [
            title,
            modeBadge,
            displaySummaryLabel,
            row(label: brightnessTitle, value: brightnessValueLabel),
            row(label: warmthTitle, value: warmthValueLabel),
            automationLabel,
            scheduleSummaryLabel,
            shortcutSummaryLabel,
            diagnosticsSummaryLabel,
            row(label: brightnessDownButton, value: brightnessUpButton),
            row(label: warmthDownButton, value: warmthUpButton),
            row(label: quickDisableButton, value: restorePreviousButton),
            probeButton,
            pauseButton,
            settingsButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16)
        ])
    }

    private func row(label: NSView, value: NSView) -> NSStackView {
        let stack = NSStackView(views: [label, value])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    private func button(_ title: String, command: MenuBarCommand, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        commandButtons[command] = button
        return button
    }

    @objc private func brightnessDownPressed() {
        actions.perform(.brightnessDown)
    }

    @objc private func brightnessUpPressed() {
        actions.perform(.brightnessUp)
    }

    @objc private func warmthDownPressed() {
        actions.perform(.warmthDown)
    }

    @objc private func warmthUpPressed() {
        actions.perform(.warmthUp)
    }

    @objc private func probeDDCPressed() {
        actions.perform(.probeDDC)
    }

    @objc private func pauseAutomationPressed() {
        actions.perform(.pauseAutomation)
    }

    @objc private func quickDisablePressed() {
        actions.perform(.quickDisable)
    }

    @objc private func restorePreviousPressed() {
        actions.perform(.restorePrevious)
    }

    @objc private func openSettingsPressed() {
        actions.perform(.openSettings)
    }
}
