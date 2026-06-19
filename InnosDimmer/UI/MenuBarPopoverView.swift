import AppKit

enum MenuBarCommand: Equatable, Hashable {
    case brightnessDown
    case brightnessUp
    case setBrightness(Int)
    case blueReductionDown
    case blueReductionUp
    case setBlueReduction(Int)
    case pauseAutomation
    case quickDisable
    case restorePrevious
    case openAppWindow
    case openSettings

    static let buttonCommands: [MenuBarCommand] = [
        .brightnessDown,
        .brightnessUp,
        .blueReductionDown,
        .blueReductionUp,
        .pauseAutomation,
        .quickDisable,
        .restorePrevious,
        .openAppWindow,
        .openSettings
    ]
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

    static func buttonBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.19, alpha: 1) : NSColor(calibratedWhite: 0.93, alpha: 1)
    }

    static func buttonBorder(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.36, alpha: 1) : NSColor(calibratedWhite: 0.76, alpha: 1)
    }

    static func primaryButtonBackground(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.85, alpha: 1)
        }
        return NSColor(calibratedRed: 0.03, green: 0.42, blue: 0.74, alpha: 1)
    }

    static func warningButtonBackground(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.10, alpha: 1)
        }
        return NSColor(calibratedRed: 1.00, green: 0.95, blue: 0.84, alpha: 1)
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

private final class DashboardRootView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
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
        layer?.backgroundColor = PopoverPalette.background(for: effectiveAppearance).cgColor
    }
}

private final class ProgressTrackView: NSView {
    var onUserFractionChange: ((CGFloat) -> Void)?

    var fraction: CGFloat = 0 {
        didSet {
            fraction = min(1, max(0, fraction))
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 18)
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

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        updateFromEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateFromEvent(event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0, dy: max(0, (bounds.height - 8) / 2))
        let radius = rect.height / 2
        let fillColor = PopoverPalette.trackFill(for: effectiveAppearance)

        PopoverPalette.trackBackground(for: effectiveAppearance).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        if fraction > 0 {
            var fillRect = rect
            fillRect.size.width = max(rect.height, rect.width * fraction)
            fillColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
        }

        let thumbDiameter: CGFloat = 14
        let thumbX = rect.minX + (rect.width * fraction) - (thumbDiameter / 2)
        let clampedThumbX = min(max(thumbX, rect.minX), rect.maxX - thumbDiameter)
        let thumbRect = NSRect(
            x: clampedThumbX,
            y: bounds.midY - (thumbDiameter / 2),
            width: thumbDiameter,
            height: thumbDiameter
        )
        fillColor.setFill()
        NSBezierPath(ovalIn: thumbRect).fill()
        PopoverPalette.sectionBackground(for: effectiveAppearance).setStroke()
        let thumbBorder = NSBezierPath(ovalIn: thumbRect.insetBy(dx: 0.5, dy: 0.5))
        thumbBorder.lineWidth = 1
        thumbBorder.stroke()
    }

    func simulateUserFractionChangeForTesting(_ fraction: CGFloat) {
        updateFromUserFraction(fraction)
    }

    private func updateFromEvent(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        updateFromUserFraction(location.x / max(bounds.width, 1))
    }

    private func updateFromUserFraction(_ newFraction: CGFloat) {
        fraction = newFraction
        onUserFractionChange?(fraction)
    }
}

private final class PopoverCommandButton: NSButton {
    static let minimumHeight: CGFloat = 30

    private let popoverStyle: PopoverButtonStyle

    init(title: String, style: PopoverButtonStyle, target: AnyObject?, action: Selector?) {
        self.popoverStyle = style
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        controlSize = .regular
        font = .systemFont(ofSize: 12, weight: .semibold)
        setButtonType(.momentaryPushIn)
        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width, height: max(Self.minimumHeight, size.height))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        let foreground: NSColor
        let background: NSColor
        let border: NSColor

        switch popoverStyle {
        case .normal:
            foreground = .labelColor
            background = PopoverPalette.buttonBackground(for: effectiveAppearance)
            border = PopoverPalette.buttonBorder(for: effectiveAppearance)
        case .primary:
            foreground = .white
            background = PopoverPalette.primaryButtonBackground(for: effectiveAppearance)
            border = background
        case .warning:
            foreground = PopoverPalette.warningColor(for: effectiveAppearance)
            background = PopoverPalette.warningButtonBackground(for: effectiveAppearance)
            border = PopoverPalette.warningColor(for: effectiveAppearance).withAlphaComponent(0.46)
        }

        layer?.backgroundColor = background.cgColor
        layer?.borderColor = border.cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: foreground,
                .font: font ?? NSFont.systemFont(ofSize: 12, weight: .semibold)
            ]
        )
    }
}

struct MenuBarViewModel: Equatable {
    var modeTitle: String
    var displaySummary: String
    var brightnessLabel: String
    var blueReductionLabel: String
    var automationTitle: String
    var scheduleNextLabel: String
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
        displaySummary = state.display.map { "\($0.localizedName) · software dimming" } ?? "No display selected"
        brightnessLabel = "\(state.targetBrightness)%"
        blueReductionLabel = "\(state.targetBlueReduction)%"
        if state.automationPausedUntilNextBoundary, let resumeMinute = state.automationResumeMinuteOfDay {
            automationTitle = "Automation paused until \(Self.timeLabel(for: resumeMinute))"
        } else if state.automationPausedUntilNextBoundary {
            automationTitle = "Automation paused until next schedule boundary"
        } else {
            automationTitle = "Automation active"
        }
        scheduleNextLabel = Self.scheduleNextLabel(for: schedule)
        scheduleSummary = Self.scheduleSummary(for: schedule)
        shortcutSummary = Self.shortcutSummary(for: shortcuts)
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
            "\(timeLabel(for: entry.minuteOfDay)) · \(entry.brightness)% brightness / \(entry.blueReduction)% blue"
        }
        guard !labels.isEmpty else {
            return "Not configured"
        }
        return labels.joined(separator: ", ")
    }

    private static func scheduleNextLabel(for schedule: [ScheduleEntry]) -> String {
        guard let next = SettingsSnapshot.sortedSchedule(schedule).first else {
            return "No schedule"
        }
        return "Next \(timeLabel(for: next.minuteOfDay))"
    }

    private static func shortcutSummary(for shortcuts: [ShortcutBinding]) -> String {
        let enabledCount = shortcuts.filter(\.isEnabled).count
        return "\(enabledCount) enabled · Option + Shift controls"
    }

    private static func diagnosticsSummary(
        state: BrightnessState,
        latestDiagnosticEvent: DiagnosticsEvent?
    ) -> String {
        if let latestDiagnosticEvent {
            return latestDiagnosticEvent.message
        }

        return ModeStatusLabel.title(for: state.activeMode)
    }
}

final class MenuBarPopoverView: NSView {
    static let preferredContentSize = NSSize(width: 480, height: 620)

    private let modeBadge: StatusBadgeView
    private let actions: MenuBarActions
    private let displaySummaryLabel = NSTextField(labelWithString: "")
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let blueReductionValueLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleNextLabel = NSTextField(labelWithString: "")
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let shortcutSummaryLabel = NSTextField(labelWithString: "")
    private let diagnosticsSummaryLabel = NSTextField(labelWithString: "")
    private let brightnessTrackView = ProgressTrackView()
    private let blueReductionTrackView = ProgressTrackView()
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
        blueReductionValueLabel.stringValue = viewModel.blueReductionLabel
        automationLabel.stringValue = viewModel.automationTitle
        scheduleNextLabel.stringValue = viewModel.scheduleNextLabel
        scheduleNextLabel.invalidateIntrinsicContentSize()
        scheduleSummaryLabel.stringValue = viewModel.scheduleSummary
        shortcutSummaryLabel.stringValue = viewModel.shortcutSummary
        diagnosticsSummaryLabel.stringValue = viewModel.diagnosticsSummary
        brightnessTrackView.fraction = CGFloat(state.targetBrightness) / 100
        blueReductionTrackView.fraction = CGFloat(state.targetBlueReduction) / 100
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

    func blueReductionLabelForTesting() -> String {
        blueReductionValueLabel.stringValue
    }

    func brightnessTrackFractionForTesting() -> CGFloat {
        brightnessTrackView.fraction
    }

    func blueReductionTrackFractionForTesting() -> CGFloat {
        blueReductionTrackView.fraction
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

    func simulateBrightnessTrackChangeForTesting(percent: Int) {
        brightnessTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func simulateBlueReductionTrackChangeForTesting(percent: Int) {
        blueReductionTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    private func buildLayout() {
        wantsLayer = true
        updateBackground()

        [
            displaySummaryLabel,
            automationLabel,
            scheduleNextLabel,
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
                    valueLabel: blueReductionValueLabel,
                    trackView: blueReductionTrackView,
                    decrement: compactButton("-", accessibilityLabel: "Blue reduction down", command: .blueReductionDown, action: #selector(blueReductionDownPressed)),
                    increment: compactButton("+", accessibilityLabel: "Blue reduction up", command: .blueReductionUp, action: #selector(blueReductionUpPressed))
                )
            ]
        )
        brightnessTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBrightness(Self.percent(from: fraction)))
        }
        blueReductionTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBlueReduction(Self.percent(from: fraction)))
        }
        brightnessTrackView.setAccessibilityLabel("Brightness percentage")
        blueReductionTrackView.setAccessibilityLabel("Blue reduction percentage")

        let scheduleNextChip = chipView(scheduleNextLabel)
        scheduleNextChip.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
        let schedule = makeSection(
            title: "Schedule",
            trailing: scheduleNextChip,
            views: [
                automationLabel,
                makeSummaryRow(title: "Current", value: scheduleSummaryLabel),
                makeSummaryRow(title: "Shortcuts", value: shortcutSummaryLabel),
                button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                makeActionRow([
                    button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed)),
                    button("Pause automation", command: .pauseAutomation, action: #selector(pauseAutomationPressed))
                ])
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

        let arrangedSubviews = [
            header,
            controls,
            schedule,
            diagnostics
        ]
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        arrangedSubviews.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
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
        [topRow, displaySummaryLabel].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func makeSection(title: String, trailing: NSView?, views: [NSView]) -> NSView {
        let titleLabel = sectionLabel(title)
        let titleViews = trailing.map { [titleLabel, spacer(), $0] } ?? [titleLabel]
        let titleRow = NSStackView(views: titleViews)
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailing?.setContentHuggingPriority(.required, for: .horizontal)

        let content = NSStackView(views: [titleRow] + views)
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 9
        ([titleRow] + views).forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
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
        trackView.heightAnchor.constraint(equalToConstant: 18).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func makeSummaryRow(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
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
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
        return chipView(label)
    }

    private func chipView(_ label: NSTextField) -> NSTextField {
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    private static func percent(from fraction: CGFloat) -> Int {
        Clamped.percent(Int((fraction * 100).rounded()))
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
        let button = PopoverCommandButton(title: title, style: style, target: self, action: action)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
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

    @objc private func blueReductionDownPressed() {
        actions.perform(.blueReductionDown)
    }

    @objc private func blueReductionUpPressed() {
        actions.perform(.blueReductionUp)
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
    var modeTitle: String
    var displayValue: String
    var modeValue: String
    var brightnessValue: String
    var blueReductionValue: String
    var automationValue: String
    var scheduleValue: String
    var shortcutValue: String
    var failureValue: String
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
        modeTitle = ModeStatusLabel.title(for: state.activeMode)
        displayValue = state.display.map(\.localizedName) ?? "Not selected"
        modeValue = modeTitle
        brightnessValue = "\(state.targetBrightness)%"
        blueReductionValue = "\(state.targetBlueReduction)%"
        if state.automationPausedUntilNextBoundary {
            automationValue = state.automationResumeMinuteOfDay.map {
                "paused until \(Self.timeLabel(for: $0))"
            } ?? "paused until next schedule boundary"
        } else {
            automationValue = "active"
        }
        let popoverScheduleSummary = MenuBarViewModel(
            state: state,
            schedule: schedule,
            shortcuts: shortcuts
        ).scheduleSummary
        scheduleValue = popoverScheduleSummary
        shortcutValue = "\(shortcuts.filter(\.isEnabled).count) enabled"

        let warnings = events.filter { $0.severity == .warning }.count
        let errors = events.filter { $0.severity == .error }.count
        failureValue = "\(errors) errors, \(warnings) warnings"
        displayLine = "Display: \(displayValue)"
        modeLine = "Mode: \(modeValue)"
        brightnessLine = "Brightness: \(brightnessValue) / Blue reduction: \(blueReductionValue)"
        automationLine = "Automation: \(automationValue)"
        scheduleLine = "Schedule: \(scheduleValue)"
        shortcutLine = "Shortcuts: \(shortcutValue)"
        failureLine = "Failures: \(failureValue)"
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
    private let modeBadge = StatusBadgeView(mode: .unknown)
    private let actions: MenuBarActions
    private let displayLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private let brightnessLabel = NSTextField(labelWithString: "")
    private let blueReductionLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let failureLabel = NSTextField(labelWithString: "")
    private let brightnessTrackView = ProgressTrackView()
    private let blueReductionTrackView = ProgressTrackView()
    private let diagnosticsTextView = NSTextView()
    private let diagnosticsScrollView = NSScrollView()
    private var commandButtons: [MenuBarCommand: NSButton] = [:]

    init(actions: MenuBarActions = .noop) {
        self.actions = actions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer"
        window.minSize = NSSize(width: 520, height: 700)
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
        modeBadge.update(mode: state.activeMode)
        displayLabel.stringValue = viewModel.displayValue
        modeLabel.stringValue = viewModel.modeValue
        brightnessLabel.stringValue = viewModel.brightnessValue
        blueReductionLabel.stringValue = viewModel.blueReductionValue
        brightnessTrackView.fraction = CGFloat(state.targetBrightness) / 100
        blueReductionTrackView.fraction = CGFloat(state.targetBlueReduction) / 100
        automationLabel.stringValue = viewModel.automationValue
        scheduleLabel.stringValue = viewModel.scheduleValue
        shortcutLabel.stringValue = viewModel.shortcutValue
        failureLabel.stringValue = viewModel.failureValue
        diagnosticsTextView.string = viewModel.diagnosticsLog
        refreshDiagnosticColors()
    }

    func commandButtonForTesting(_ command: MenuBarCommand) -> NSButton? {
        commandButtons[command]
    }

    func simulateBrightnessTrackChangeForTesting(percent: Int) {
        brightnessTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func simulateBlueReductionTrackChangeForTesting(percent: Int) {
        blueReductionTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    private func installContent() {
        let title = NSTextField(labelWithString: "InnosDimmer")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = .labelColor
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        configureBadge(modeBadge)

        [
            displayLabel,
            modeLabel,
            brightnessLabel,
            blueReductionLabel,
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
        diagnosticsTextView.backgroundColor = PopoverPalette.subtleBackground(for: diagnosticsTextView.effectiveAppearance)
        diagnosticsTextView.drawsBackground = true
        diagnosticsTextView.textContainerInset = NSSize(width: 8, height: 8)

        diagnosticsScrollView.borderType = .noBorder
        diagnosticsScrollView.wantsLayer = true
        diagnosticsScrollView.layer?.cornerRadius = 7
        diagnosticsScrollView.layer?.borderWidth = 1
        diagnosticsScrollView.layer?.borderColor = PopoverPalette.border(for: diagnosticsScrollView.effectiveAppearance).cgColor
        diagnosticsScrollView.layer?.backgroundColor = PopoverPalette.subtleBackground(for: diagnosticsScrollView.effectiveAppearance).cgColor
        diagnosticsScrollView.hasVerticalScroller = true
        diagnosticsScrollView.documentView = diagnosticsTextView
        diagnosticsScrollView.translatesAutoresizingMaskIntoConstraints = false
        diagnosticsScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        brightnessTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBrightness(Self.percent(from: fraction)))
        }
        blueReductionTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBlueReduction(Self.percent(from: fraction)))
        }
        brightnessTrackView.setAccessibilityLabel("Dashboard brightness percentage")
        blueReductionTrackView.setAccessibilityLabel("Dashboard blue reduction percentage")

        let header = makeHeader(title: title)
        let currentState = makeSection(
            title: "Current state",
            views: [
                makeSummaryRow(title: "Display", value: displayLabel),
                makeSummaryRow(title: "Mode", value: modeLabel),
                makeControlGroup(
                    title: "Brightness",
                    valueLabel: brightnessLabel,
                    trackView: brightnessTrackView,
                    decrement: compactButton(
                        "-",
                        accessibilityLabel: "Dashboard brightness down",
                        command: .brightnessDown,
                        action: #selector(brightnessDownPressed)
                    ),
                    increment: compactButton(
                        "+",
                        accessibilityLabel: "Dashboard brightness up",
                        command: .brightnessUp,
                        action: #selector(brightnessUpPressed)
                    )
                ),
                makeControlGroup(
                    title: "Blue reduction",
                    valueLabel: blueReductionLabel,
                    trackView: blueReductionTrackView,
                    decrement: compactButton(
                        "-",
                        accessibilityLabel: "Dashboard blue reduction down",
                        command: .blueReductionDown,
                        action: #selector(blueReductionDownPressed)
                    ),
                    increment: compactButton(
                        "+",
                        accessibilityLabel: "Dashboard blue reduction up",
                        command: .blueReductionUp,
                        action: #selector(blueReductionUpPressed)
                    )
                ),
                makeSummaryRow(title: "Automation", value: automationLabel)
            ]
        )
        let configuration = makeSection(
            title: "Configuration",
            views: [
                makeSummaryRow(title: "Schedule", value: scheduleLabel),
                makeSummaryRow(title: "Shortcuts", value: shortcutLabel),
                button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                makeActionRow([
                    button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed)),
                    button("Pause automation", command: .pauseAutomation, action: #selector(pauseAutomationPressed))
                ]),
                button("Settings", command: .openSettings, action: #selector(openSettingsPressed))
            ]
        )
        let diagnostics = makeSection(
            title: "Diagnostics",
            views: [
                makeSummaryRow(title: "Failures", value: failureLabel),
                diagnosticsScrollView
            ]
        )

        let arrangedSubviews = [header, currentState, configuration, diagnostics]
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = DashboardRootView()
        window?.contentView = contentView
        contentView.addSubview(stack)
        arrangedSubviews.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func makeHeader(title: NSTextField) -> NSView {
        let topRow = NSStackView(views: [title, modeBadge])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12
        modeBadge.setContentHuggingPriority(.required, for: .horizontal)
        return topRow
    }

    private func makeSection(title: String, views: [NSView]) -> NSView {
        let label = sectionLabel(title)
        let content = NSStackView(views: [label] + views)
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 9
        ([label] + views).forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        return PopoverContainerView(style: .section, content: content)
    }

    private func makeSummaryRow(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.widthAnchor.constraint(equalToConstant: 116).isActive = true
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleLabel, value])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 12
        return stack
    }

    private func makeControlGroup(
        title: String,
        valueLabel: NSTextField,
        trackView: ProgressTrackView,
        decrement: NSButton,
        increment: NSButton
    ) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.widthAnchor.constraint(equalToConstant: 116).isActive = true
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleLabel, valueLabel, trackView, decrement, increment])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        trackView.heightAnchor.constraint(equalToConstant: 18).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func makeActionRow(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func button(
        _ title: String,
        command: MenuBarCommand,
        action: Selector,
        style: PopoverButtonStyle = .normal
    ) -> NSButton {
        let button = PopoverCommandButton(title: title, style: style, target: self, action: action)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
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

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureBadge(_ badge: StatusBadgeView) {
        badge.font = .systemFont(ofSize: 12, weight: .semibold)
        badge.textColor = PopoverPalette.statusColor(for: window?.effectiveAppearance ?? NSApp.effectiveAppearance)
        badge.alignment = .right
    }

    private static func percent(from fraction: CGFloat) -> Int {
        Clamped.percent(Int((fraction * 100).rounded()))
    }

    private func refreshDiagnosticColors() {
        let appearance = diagnosticsScrollView.effectiveAppearance
        diagnosticsTextView.textColor = .labelColor
        diagnosticsTextView.backgroundColor = PopoverPalette.subtleBackground(for: appearance)
        diagnosticsScrollView.layer?.backgroundColor = PopoverPalette.subtleBackground(for: appearance).cgColor
        diagnosticsScrollView.layer?.borderColor = PopoverPalette.border(for: appearance).cgColor
        modeBadge.textColor = PopoverPalette.statusColor(for: window?.effectiveAppearance ?? appearance)
    }

    @objc private func brightnessDownPressed() {
        actions.perform(.brightnessDown)
    }

    @objc private func brightnessUpPressed() {
        actions.perform(.brightnessUp)
    }

    @objc private func blueReductionDownPressed() {
        actions.perform(.blueReductionDown)
    }

    @objc private func blueReductionUpPressed() {
        actions.perform(.blueReductionUp)
    }

    @objc private func quickDisablePressed() {
        actions.perform(.quickDisable)
    }

    @objc private func restorePreviousPressed() {
        actions.perform(.restorePrevious)
    }

    @objc private func pauseAutomationPressed() {
        actions.perform(.pauseAutomation)
    }

    @objc private func openSettingsPressed() {
        actions.perform(.openSettings)
    }
}
