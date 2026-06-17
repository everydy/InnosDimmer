import AppKit

struct MenuBarViewModel: Equatable {
    var modeTitle: String
    var brightnessLabel: String
    var warmthLabel: String
    var automationTitle: String
    var scheduleSummary: String
    var shortcutSummary: String

    init(state: BrightnessState) {
        modeTitle = ModeStatusLabel.title(for: state.activeMode)
        brightnessLabel = "\(state.targetBrightness)%"
        warmthLabel = "\(state.targetWarmth)%"
        automationTitle = state.automationPausedUntilNextBoundary
            ? "Automation paused until next schedule boundary"
            : "Automation active"
        scheduleSummary = "Schedule: 09:00 / 19:00 / 23:00"
        shortcutSummary = "Shortcuts: customizable"
    }
}

final class MenuBarPopoverView: NSView {
    private let modeBadge: StatusBadgeView
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let warmthValueLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let shortcutSummaryLabel = NSTextField(labelWithString: "")

    init(state: BrightnessState) {
        modeBadge = StatusBadgeView(mode: state.activeMode)
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 220))
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
    }

    private func buildLayout() {
        let title = NSTextField(labelWithString: "INNOS 27QA100M")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        let brightnessTitle = NSTextField(labelWithString: "Brightness")
        let warmthTitle = NSTextField(labelWithString: "Warmth")
        let probeButton = NSButton(title: "DDC Probe", target: nil, action: nil)
        let pauseButton = NSButton(title: "Pause automation", target: nil, action: nil)
        let brightnessDownButton = NSButton(title: "Brightness down", target: nil, action: nil)
        let brightnessUpButton = NSButton(title: "Brightness up", target: nil, action: nil)
        let settingsButton = NSButton(title: "Settings", target: nil, action: nil)

        let stack = NSStackView(views: [
            title,
            modeBadge,
            row(label: brightnessTitle, value: brightnessValueLabel),
            row(label: warmthTitle, value: warmthValueLabel),
            automationLabel,
            scheduleSummaryLabel,
            shortcutSummaryLabel,
            row(label: brightnessDownButton, value: brightnessUpButton),
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
}
