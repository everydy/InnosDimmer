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
    var brightnessLabel: String
    var warmthLabel: String
    var automationTitle: String
    var scheduleSummary: String
    var shortcutSummary: String
    var diagnosticsSummary: String

    init(state: BrightnessState, shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings) {
        modeTitle = ModeStatusLabel.title(for: state.activeMode)
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
        diagnosticsSummary = "Diagnostics: \(ModeStatusLabel.title(for: state.activeMode)), \(Self.hardwareSummary(for: state.hardwareCapability))"
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func hardwareSummary(for capability: HardwareCapability) -> String {
        switch capability {
        case .notProbed:
            return "DDC not probed"
        case .probing:
            return "DDC probing"
        case .readSupported:
            return "DDC read-only"
        case .writeReadbackSupported:
            return "DDC verified"
        case .unsupported(let reason):
            return "DDC unsupported: \(reason)"
        case .blockedByPlatform(let reason):
            return "Platform blocked: \(reason)"
        case .failedWithError(let message):
            return "DDC failed: \(message)"
        }
    }
}

final class MenuBarPopoverView: NSView {
    private let modeBadge: StatusBadgeView
    private let actions: MenuBarActions
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let warmthValueLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let shortcutSummaryLabel = NSTextField(labelWithString: "")
    private let diagnosticsSummaryLabel = NSTextField(labelWithString: "")
    private var commandButtons: [MenuBarCommand: NSButton] = [:]

    init(state: BrightnessState, actions: MenuBarActions = .noop) {
        modeBadge = StatusBadgeView(mode: state.activeMode)
        self.actions = actions
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 300))
        buildLayout()
        update(state: state)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(state: BrightnessState) {
        let viewModel = MenuBarViewModel(state: state)
        modeBadge.stringValue = viewModel.modeTitle
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
