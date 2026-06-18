import AppKit

enum MenuBarCommand: CaseIterable, Equatable, Hashable {
    case brightnessDown
    case brightnessUp
    case warmthDown
    case warmthUp
    case pauseAutomation
    case quickDisable
    case restorePrevious
    case openAppWindow
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
        schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
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
        scheduleSummary = Self.scheduleSummary(for: schedule)
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

    private static func scheduleSummary(for schedule: [ScheduleEntry]) -> String {
        let labels = SettingsSnapshot.sortedSchedule(schedule).map { entry in
            "\(timeLabel(for: entry.minuteOfDay)) \(entry.brightness)% / blue \(entry.warmth)%"
        }
        guard !labels.isEmpty else {
            return "Schedule: Not configured"
        }
        return "Schedule: \(labels.joined(separator: ", "))"
    }

    private static func diagnosticsSummary(
        state: BrightnessState,
        latestDiagnosticEvent: DiagnosticsEvent?
    ) -> String {
        var parts = [
            "Diagnostics: \(ModeStatusLabel.title(for: state.activeMode))"
        ]

        if let latestDiagnosticEvent {
            parts.append("Last: \(latestDiagnosticEvent.message)")
        }

        return parts.joined(separator: ". ")
    }
}

final class MenuBarPopoverView: NSView {
    static let preferredContentSize = NSSize(width: 480, height: 620)

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
        schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        latestDiagnosticEvent: DiagnosticsEvent? = nil,
        actions: MenuBarActions = .noop
    ) {
        modeBadge = StatusBadgeView(mode: state.activeMode)
        self.actions = actions
        super.init(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        buildLayout()
        update(
            state: state,
            schedule: schedule,
            shortcuts: shortcuts,
            latestDiagnosticEvent: latestDiagnosticEvent
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(
        state: BrightnessState,
        schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        latestDiagnosticEvent: DiagnosticsEvent? = nil
    ) {
        let viewModel = MenuBarViewModel(
            state: state,
            schedule: schedule,
            shortcuts: shortcuts,
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

    func scheduleSummaryForTesting() -> String {
        scheduleSummaryLabel.stringValue
    }

    func shortcutSummaryForTesting() -> String {
        shortcutSummaryLabel.stringValue
    }

    private func buildLayout() {
        let title = NSTextField(labelWithString: "INNOS 27QA100M")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        [
            displaySummaryLabel,
            automationLabel,
            scheduleSummaryLabel,
            shortcutSummaryLabel,
            diagnosticsSummaryLabel
        ].forEach(Self.configureWrappingLabel)

        let brightnessTitle = NSTextField(labelWithString: "Brightness")
        let warmthTitle = NSTextField(labelWithString: "Blue reduction")
        let pauseButton = button("Pause automation", command: .pauseAutomation, action: #selector(pauseAutomationPressed))
        let brightnessDownButton = button("Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed))
        let brightnessUpButton = button("Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))
        let warmthDownButton = button("Blue reduction down", command: .warmthDown, action: #selector(warmthDownPressed))
        let warmthUpButton = button("Blue reduction up", command: .warmthUp, action: #selector(warmthUpPressed))
        let quickDisableButton = button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed))
        let restorePreviousButton = button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed))
        let appWindowButton = button("Open app window", command: .openAppWindow, action: #selector(openAppWindowPressed))
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
            pauseButton,
            appWindowButton,
            settingsButton
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    private func row(label: NSView, value: NSView) -> NSStackView {
        let stack = NSStackView(views: [label, value])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    private static func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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

    @objc private func pauseAutomationPressed() {
        actions.perform(.pauseAutomation)
    }

    @objc private func quickDisablePressed() {
        actions.perform(.quickDisable)
    }

    @objc private func restorePreviousPressed() {
        actions.perform(.restorePrevious)
    }

    @objc private func openAppWindowPressed() {
        actions.perform(.openAppWindow)
    }

    @objc private func openSettingsPressed() {
        actions.perform(.openSettings)
    }
}

struct AppDashboardViewModel: Equatable {
    var displayLine: String
    var modeLine: String
    var brightnessLine: String
    var automationLine: String
    var scheduleLine: String
    var shortcutLine: String
    var failureLine: String
    var diagnosticsLog: String

    init(
        state: BrightnessState,
        schedule: [ScheduleEntry],
        shortcuts: [ShortcutBinding],
        events: [DiagnosticsEvent]
    ) {
        displayLine = state.display.map { "Display: \($0.localizedName)" } ?? "Display: Not selected"
        modeLine = "Mode: \(ModeStatusLabel.title(for: state.activeMode))"
        brightnessLine = "Brightness: \(state.targetBrightness)% / Blue reduction: \(state.targetWarmth)%"
        if state.automationPausedUntilNextBoundary {
            automationLine = state.automationResumeMinuteOfDay.map {
                "Automation: paused until \(Self.timeLabel(for: $0))"
            } ?? "Automation: paused until next schedule boundary"
        } else {
            automationLine = "Automation: active"
        }
        scheduleLine = MenuBarViewModel(
            state: state,
            schedule: schedule,
            shortcuts: shortcuts
        ).scheduleSummary
        shortcutLine = HotkeyManager.summary(for: shortcuts)

        let warnings = events.filter { $0.severity == .warning }.count
        let errors = events.filter { $0.severity == .error }.count
        failureLine = "Failures: \(errors) errors, \(warnings) warnings"
        diagnosticsLog = Self.logText(for: events)
    }

    private static func logText(for events: [DiagnosticsEvent]) -> String {
        guard !events.isEmpty else {
            return "No diagnostics recorded yet."
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return events.reversed().map { event in
            "[\(formatter.string(from: event.timestamp))] \(event.severity.rawValue.uppercased()) \(event.category.rawValue): \(event.message)"
        }.joined(separator: "\n")
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

@MainActor
final class AppDashboardWindowController: NSWindowController {
    private let displayLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private let brightnessLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let failureLabel = NSTextField(labelWithString: "")
    private let diagnosticsTextView = NSTextView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer"
        super.init(window: window)
        installContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(
        state: BrightnessState,
        schedule: [ScheduleEntry],
        shortcuts: [ShortcutBinding],
        events: [DiagnosticsEvent]
    ) {
        let viewModel = AppDashboardViewModel(
            state: state,
            schedule: schedule,
            shortcuts: shortcuts,
            events: events
        )
        displayLabel.stringValue = viewModel.displayLine
        modeLabel.stringValue = viewModel.modeLine
        brightnessLabel.stringValue = viewModel.brightnessLine
        automationLabel.stringValue = viewModel.automationLine
        scheduleLabel.stringValue = viewModel.scheduleLine
        shortcutLabel.stringValue = viewModel.shortcutLine
        failureLabel.stringValue = viewModel.failureLine
        diagnosticsTextView.string = viewModel.diagnosticsLog
    }

    private func installContent() {
        let title = NSTextField(labelWithString: "InnosDimmer")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        [
            displayLabel,
            modeLabel,
            brightnessLabel,
            automationLabel,
            scheduleLabel,
            shortcutLabel,
            failureLabel
        ].forEach(Self.configureWrappingLabel)
        failureLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        diagnosticsTextView.isEditable = false
        diagnosticsTextView.isSelectable = true
        diagnosticsTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        diagnosticsTextView.textColor = .labelColor
        diagnosticsTextView.backgroundColor = .textBackgroundColor

        let diagnosticsScrollView = NSScrollView()
        diagnosticsScrollView.borderType = .bezelBorder
        diagnosticsScrollView.hasVerticalScroller = true
        diagnosticsScrollView.documentView = diagnosticsTextView
        diagnosticsScrollView.translatesAutoresizingMaskIntoConstraints = false
        diagnosticsScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        let stack = NSStackView(views: [
            title,
            sectionLabel("Current state"),
            displayLabel,
            modeLabel,
            brightnessLabel,
            automationLabel,
            sectionLabel("Configuration"),
            scheduleLabel,
            shortcutLabel,
            sectionLabel("Diagnostics"),
            failureLabel,
            diagnosticsScrollView
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        guard let contentView = window?.contentView else {
            return
        }
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
    }
}
