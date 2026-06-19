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

private enum PopoverButtonStyle {
    case normal
    case primary
    case warning
}

private enum PopoverPalette {
    static func background(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.10, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
    }

    static func sectionBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.15, alpha: 1) : .white
    }

    static func subtleBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.98, alpha: 1)
    }

    static func border(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.27, alpha: 1) : NSColor(calibratedWhite: 0.84, alpha: 1)
    }

    static func trackBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.24, alpha: 1) : NSColor(calibratedWhite: 0.88, alpha: 1)
    }

    static func trackFill(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1)
        }
        return NSColor(calibratedRed: 0.09, green: 0.41, blue: 0.76, alpha: 1)
    }

    static func statusColor(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.46, green: 0.85, blue: 0.61, alpha: 1)
        }
        return NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.27, alpha: 1)
    }

    static func warningColor(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.95, green: 0.77, blue: 0.37, alpha: 1)
        }
        return NSColor(calibratedRed: 0.54, green: 0.35, blue: 0, alpha: 1)
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private final class PopoverContainerView: NSView {
    enum Style {
        case section
        case subtle
    }

    private let style: Style

    init(style: Style, content: NSView) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = style == .section ? 8 : 7
        layer?.borderWidth = 1
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        let inset: CGFloat = style == .section ? 12 : 8
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            content.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset)
        ])
        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        let background: NSColor
        switch style {
        case .section:
            background = PopoverPalette.sectionBackground(for: effectiveAppearance)
        case .subtle:
            background = PopoverPalette.subtleBackground(for: effectiveAppearance)
        }
        layer?.backgroundColor = background.cgColor
        layer?.borderColor = PopoverPalette.border(for: effectiveAppearance).cgColor
    }
}

private final class ProgressTrackView: NSView {
    var fraction: CGFloat = 0 {
        didSet {
            fraction = min(1, max(0, fraction))
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 8)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0, dy: max(0, (bounds.height - 8) / 2))
        let radius = rect.height / 2

        PopoverPalette.trackBackground(for: effectiveAppearance).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        guard fraction > 0 else {
            return
        }

        var fillRect = rect
        fillRect.size.width = max(rect.height, rect.width * fraction)
        PopoverPalette.trackFill(for: effectiveAppearance).setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
    }
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
    private let brightnessTrackView = ProgressTrackView()
    private let warmthTrackView = ProgressTrackView()
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
        brightnessTrackView.fraction = CGFloat(state.targetBrightness) / 100
        warmthTrackView.fraction = CGFloat(state.targetWarmth) / 100
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

    func warmthLabelForTesting() -> String {
        warmthValueLabel.stringValue
    }

    func brightnessTrackFractionForTesting() -> CGFloat {
        brightnessTrackView.fraction
    }

    func warmthTrackFractionForTesting() -> CGFloat {
        warmthTrackView.fraction
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
        wantsLayer = true
        updateBackground()

        [
            displaySummaryLabel,
            automationLabel,
            scheduleSummaryLabel,
            shortcutSummaryLabel,
            diagnosticsSummaryLabel
        ].forEach(Self.configureWrappingLabel)

        let header = makeHeader()
        let controls = makeSection(
            title: "Quick controls",
            trailing: chip("Automation active"),
            views: [
                makeControlGroup(
                    title: "Brightness",
                    valueLabel: brightnessValueLabel,
                    trackView: brightnessTrackView,
                    decrement: compactButton("-", accessibilityLabel: "Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed)),
                    increment: compactButton("+", accessibilityLabel: "Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))
                ),
                makeSeparator(),
                makeControlGroup(
                    title: "Blue reduction",
                    valueLabel: warmthValueLabel,
                    trackView: warmthTrackView,
                    decrement: compactButton("-", accessibilityLabel: "Blue reduction down", command: .warmthDown, action: #selector(warmthDownPressed)),
                    increment: compactButton("+", accessibilityLabel: "Blue reduction up", command: .warmthUp, action: #selector(warmthUpPressed))
                )
            ]
        )
        let schedule = makeSection(
            title: "Schedule",
            trailing: nil,
            views: [
                automationLabel,
                makeSummaryRow(title: "Next", value: scheduleSummaryLabel),
                makeSummaryRow(title: "Keys", value: shortcutSummaryLabel),
                makeActionRow([
                    button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                    button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed))
                ]),
                button("Pause automation", command: .pauseAutomation, action: #selector(pauseAutomationPressed))
            ]
        )
        let diagnostics = makeSection(
            title: "Diagnostics",
            trailing: chip("Latest"),
            views: [
                PopoverContainerView(style: .subtle, content: diagnosticsSummaryLabel),
                makeActionRow([
                    button("Open app window", command: .openAppWindow, action: #selector(openAppWindowPressed), style: .primary),
                    button("Settings", command: .openSettings, action: #selector(openSettingsPressed))
                ])
            ]
        )

        let stack = NSStackView(views: [
            header,
            controls,
            schedule,
            diagnostics
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        layer?.backgroundColor = PopoverPalette.background(for: effectiveAppearance).cgColor
    }

    private func makeHeader() -> NSView {
        let title = NSTextField(labelWithString: "InnosDimmer")
        title.font = .systemFont(ofSize: 17, weight: .bold)
        title.textColor = .labelColor

        configureBadge(modeBadge)

        let topRow = NSStackView(views: [title, modeBadge])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        modeBadge.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [topRow, displaySummaryLabel])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        return stack
    }

    private func makeSection(title: String, trailing: NSView?, views: [NSView]) -> NSView {
        let titleLabel = sectionLabel(title)
        let titleViews = trailing.map { [titleLabel, $0] } ?? [titleLabel]
        let titleRow = NSStackView(views: titleViews)
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trailing?.setContentHuggingPriority(.required, for: .horizontal)

        let content = NSStackView(views: [titleRow] + views)
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 10
        return PopoverContainerView(style: .section, content: content)
    }

    private func makeControlGroup(
        title: String,
        valueLabel: NSTextField,
        trackView: ProgressTrackView,
        decrement: NSButton,
        increment: NSButton
    ) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.textColor = .labelColor
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleLabel, valueLabel, trackView, decrement, increment])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        titleLabel.widthAnchor.constraint(equalToConstant: 112).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
        trackView.heightAnchor.constraint(equalToConstant: 8).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func makeSummaryRow(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleLabel, value])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 10
        return stack
    }

    private func makeActionRow(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private static func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func chip(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func configureBadge(_ badge: StatusBadgeView) {
        badge.font = .systemFont(ofSize: 12, weight: .semibold)
        badge.textColor = PopoverPalette.statusColor(for: effectiveAppearance)
        badge.alignment = .right
    }

    private func button(
        _ title: String,
        command: MenuBarCommand,
        action: Selector,
        style: PopoverButtonStyle = .normal
    ) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        switch style {
        case .normal:
            break
        case .primary:
            button.keyEquivalent = "\r"
        case .warning:
            button.contentTintColor = PopoverPalette.warningColor(for: effectiveAppearance)
        }
        commandButtons[command] = button
        return button
    }

    private func compactButton(
        _ title: String,
        accessibilityLabel: String,
        command: MenuBarCommand,
        action: Selector
    ) -> NSButton {
        let button = button(title, command: command, action: action)
        button.setAccessibilityLabel(accessibilityLabel)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
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
