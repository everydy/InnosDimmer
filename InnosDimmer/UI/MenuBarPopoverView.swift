import AppKit

enum MenuBarCommand: Equatable, Hashable {
    case brightnessDown
    case brightnessUp
    case setBrightness(Int)
    case blueReductionDown
    case blueReductionUp
    case setBlueReduction(Int)
    case openScheduleEditor
    case pauseAutomation
    case resumeAutomation
    case quickDisable
    case restorePrevious
    case openAppWindow
    case openShortcuts
    case openDiagnostics
    case openSettings
    case openPopover

    static let buttonCommands: [MenuBarCommand] = [
        .brightnessDown,
        .brightnessUp,
        .blueReductionDown,
        .blueReductionUp,
        .openScheduleEditor,
        .pauseAutomation,
        .quickDisable,
        .restorePrevious,
        .openAppWindow,
        .openShortcuts
    ]
}

struct MenuBarActions {
    var perform: @MainActor (MenuBarCommand) -> Void

    static let noop = MenuBarActions { _ in }
}

private enum PopoverButtonStyle {
    case normal
    case subtle
    case primary
    case warning
}

private enum PopoverPalette {
    static func background(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.surfaceRoot(for: appearance)
    }

    static func sectionBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.surfaceSection(for: appearance)
    }

    static func subtleBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.surfaceSubtle(for: appearance)
    }

    static func border(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.border(for: appearance)
    }

    static func trackBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.trackBackground(for: appearance)
    }

    static func trackFill(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.accent(for: appearance)
    }

    static func statusColor(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.foreground(for: .ready, appearance: appearance)
    }

    static func warningColor(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.foreground(for: .warning, appearance: appearance)
    }

    static func buttonBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.surfaceControl(for: appearance)
    }

    static func buttonBorder(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.controlBorder(for: appearance)
    }

    static func badgeBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.surfaceSection(for: appearance)
    }

    static func primaryButtonBackground(for appearance: NSAppearance) -> NSColor {
        InnosDesignTokens.primaryBackground(for: appearance)
    }

    static func warningButtonBackground(for appearance: NSAppearance) -> NSColor {
        warningColor(for: appearance).withAlphaComponent(0.12)
    }
}

private enum BadgeTone {
    case neutral
    case success
}

private final class BadgePillView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let tone: BadgeTone
    private let compact: Bool

    init(title: String, tone: BadgeTone, compact: Bool = false) {
        self.tone = tone
        self.compact = compact
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = compact ? 6 : 8
        layer?.borderWidth = 1

        label.stringValue = title
        label.font = compact
            ? InnosDesignTokens.Font.badgeCompact
            : InnosDesignTokens.Font.badgeLabel
        label.alignment = .center
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: compact ? 4 : 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: compact ? -4 : -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: compact ? 2 : 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: compact ? -2 : -4)
        ])

        updateColors()
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    override var intrinsicContentSize: NSSize {
        let size = label.intrinsicContentSize
        if compact {
            return NSSize(width: size.width + 8, height: max(16, size.height + 4))
        }
        return NSSize(width: size.width + 16, height: max(24, size.height + 8))
    }

    var stringValue: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            setAccessibilityLabel(newValue)
            invalidateIntrinsicContentSize()
        }
    }

    private func updateColors() {
        switch tone {
        case .neutral:
            layer?.backgroundColor = PopoverPalette.badgeBackground(for: effectiveAppearance).cgColor
            layer?.borderColor = PopoverPalette.buttonBorder(for: effectiveAppearance).cgColor
            label.textColor = .secondaryLabelColor
        case .success:
            let border = PopoverPalette.statusColor(for: effectiveAppearance)
            let background = PopoverPalette.statusColor(for: effectiveAppearance).withAlphaComponent(0.12)
            layer?.backgroundColor = background.cgColor
            layer?.borderColor = border.withAlphaComponent(0.35).cgColor
            label.textColor = border
        }
    }
}

private final class ControlTitleView: NSView {
    init(
        title: String,
        systemSymbolName: String,
        fallback: String,
        iconColor: NSColor,
        font: NSFont,
        textColor: NSColor
    ) {
        super.init(frame: .zero)

        let icon = Self.iconView(
            systemSymbolName: systemSymbolName,
            fallback: fallback,
            iconColor: iconColor,
            font: font
        )
        let label = NSTextField(labelWithString: title)
        label.font = font
        label.textColor = textColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [icon, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private static func iconView(
        systemSymbolName: String,
        fallback: String,
        iconColor: NSColor,
        font: NSFont
    ) -> NSView {
        let view: NSView
        if let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil) {
            let imageView = NSImageView(image: image)
            imageView.contentTintColor = iconColor
            imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .semibold)
            view = imageView
        } else {
            let label = NSTextField(labelWithString: fallback)
            label.font = font
            label.textColor = iconColor
            label.alignment = .center
            view = label
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.heightAnchor.constraint(equalToConstant: 16).isActive = true
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
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

private enum BlueReductionWarning {
    static let threshold = 50
    static let message = "High warmth may shift colors."

    static func message(for blueReduction: Int) -> String? {
        Clamped.percent(blueReduction) >= threshold ? message : nil
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

private final class ScheduleSummaryRowsView: NSView {
    private let stack = NSStackView()
    private(set) var plainSummary = "Not configured"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(schedule: [ScheduleEntry]) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let entries = SettingsSnapshot.sortedSchedule(schedule)
        guard !entries.isEmpty else {
            plainSummary = "Not configured"
            let label = NSTextField(labelWithString: plainSummary)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
            return
        }

        plainSummary = entries.map { entry in
            "\(Self.timeLabel(for: entry.minuteOfDay)) · ☀ \(entry.brightness)% · 🌡 \(entry.blueReduction)%"
        }.joined(separator: "\n")
        entries.map(Self.rowView(for:)).forEach { row in
            stack.addArrangedSubview(row)
        }
    }

    private static func rowView(for entry: ScheduleEntry) -> NSView {
        let time = pillLabel(timeLabel(for: entry.minuteOfDay))
        time.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let brightness = metricView(
            systemSymbolName: "sun.max.fill",
            fallback: "☀",
            value: "\(entry.brightness)%",
            iconColor: NSColor(calibratedRed: 0.94, green: 0.58, blue: 0.16, alpha: 1)
        )
        let warmth = metricView(
            systemSymbolName: "thermometer.medium",
            fallback: "🌡",
            value: "\(entry.blueReduction)%",
            iconColor: PopoverPalette.warningColor(for: NSApp.effectiveAppearance)
        )

        let row = NSStackView(views: [time, brightness, warmth, spacer()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let container = PopoverContainerView(style: .subtle, content: row)
        return container
    }

    private static func metricView(
        systemSymbolName: String,
        fallback: String,
        value: String,
        iconColor: NSColor
    ) -> NSStackView {
        let icon = metricIcon(systemSymbolName: systemSymbolName, fallback: fallback, iconColor: iconColor)
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = InnosDesignTokens.Font.numericValue
        valueLabel.textColor = .labelColor
        valueLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [icon, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }

    private static func metricIcon(
        systemSymbolName: String,
        fallback: String,
        iconColor: NSColor
    ) -> NSView {
        let iconView: NSView
        if let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil) {
            let imageView = NSImageView(image: image)
            imageView.contentTintColor = iconColor
            imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            iconView = imageView
        } else {
            let label = NSTextField(labelWithString: fallback)
            label.font = InnosDesignTokens.Font.app(ofSize: 11, weight: .semibold)
            label.textColor = iconColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            iconView = label
        }

        return iconView
    }

    private static func pillLabel(_ title: String) -> NSView {
        let label = BadgePillView(title: title, tone: .neutral)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

struct ShortcutSummaryRow: Equatable {
    var action: ShortcutAction
    var title: String
    var keyLabel: String
}

private struct ShortcutSummaryGroup {
    var title: String
    var upKeyLabel: String
    var downKeyLabel: String
}

private enum ShortcutSummaryFormatter {
    static func groups(from rows: [ShortcutSummaryRow]) -> [ShortcutSummaryGroup] {
        let lookup = Dictionary(uniqueKeysWithValues: rows.map { ($0.action, $0.keyLabel) })
        return [
            ShortcutSummaryGroup(
                title: "Brightness",
                upKeyLabel: lookup[.brightnessUp] ?? "Off",
                downKeyLabel: lookup[.brightnessDown] ?? "Off"
            ),
            ShortcutSummaryGroup(
                title: "Warmth",
                upKeyLabel: lookup[.blueReductionUp] ?? "Off",
                downKeyLabel: lookup[.blueReductionDown] ?? "Off"
            )
        ]
    }

    static func plainSummary(from rows: [ShortcutSummaryRow]) -> String {
        groups(from: rows)
            .map { "\($0.title)  Up  \($0.upKeyLabel)  Down  \($0.downKeyLabel)" }
            .joined(separator: "\n")
    }
}

private final class ShortcutSummaryRowsView: NSView {
    private let stack = NSStackView()
    private(set) var plainSummary = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
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

    func update(rows: [ShortcutSummaryRow]) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let groups = ShortcutSummaryFormatter.groups(from: rows)
        plainSummary = ShortcutSummaryFormatter.plainSummary(from: rows)
        for (index, group) in groups.enumerated() {
            if index > 0 {
                let separator = ShortcutSeparatorView()
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
            let rowView = ShortcutPairRowView(group: group)
            stack.addArrangedSubview(rowView)
            rowView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func updateColors() {
        layer?.backgroundColor = PopoverPalette.subtleBackground(for: effectiveAppearance).cgColor
        layer?.borderColor = PopoverPalette.border(for: effectiveAppearance).cgColor
    }
}

private final class ShortcutSeparatorView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 1)
    }

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
        layer?.backgroundColor = PopoverPalette.border(for: effectiveAppearance).cgColor
    }
}

private final class ShortcutPairRowView: NSView {
    private enum Metrics {
        static let titleWidth: CGFloat = 76
        static let directionWidth: CGFloat = 28
        static let rowHeight: CGFloat = 34
        static let horizontalPadding: CGFloat = 8
    }

    init(group: ShortcutSummaryGroup) {
        super.init(frame: .zero)
        wantsLayer = true
        updateColors()

        let title = Self.titleLabel(group.title)
        let upLabel = Self.directionLabel("Up")
        let upKey = ShortcutKeyChipView(title: group.upKeyLabel)
        let downLabel = Self.directionLabel("Down")
        let downKey = ShortcutKeyChipView(title: group.downKeyLabel)
        let actionGrid = NSStackView(views: [upLabel, upKey, downLabel, downKey])
        actionGrid.orientation = .horizontal
        actionGrid.alignment = .centerY
        actionGrid.spacing = 6
        actionGrid.translatesAutoresizingMaskIntoConstraints = false

        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        addSubview(actionGrid)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Metrics.rowHeight),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.horizontalPadding),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.widthAnchor.constraint(equalToConstant: Metrics.titleWidth),
            actionGrid.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            actionGrid.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Metrics.horizontalPadding),
            actionGrid.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = PopoverPalette.subtleBackground(for: effectiveAppearance).cgColor
    }

    private static func titleLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = InnosDesignTokens.Font.shortcutName
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private static func directionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = InnosDesignTokens.Font.shortcutDirection
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: Metrics.directionWidth).isActive = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

}

private final class ShortcutKeyChipView: NSView {
    private enum Metrics {
        static let horizontalPadding: CGFloat = 6
        static let topPadding: CGFloat = 2
        static let bottomPadding: CGFloat = 3
        static let tokenSpacing: CGFloat = 3
    }

    private let stack = NSStackView()
    private var tokenLabels: [NSTextField] = []
    private var plusLabels: [NSTextField] = []
    private let isOff: Bool

    init(title: String) {
        isOff = title == "Off"
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        buildTokens(from: title)

        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.horizontalPadding),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateColors()
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let stackSize = stack.fittingSize
        return NSSize(
            width: stackSize.width + (Metrics.horizontalPadding * 2),
            height: 20
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = PopoverPalette.buttonBackground(for: effectiveAppearance).cgColor
        layer?.borderColor = PopoverPalette.border(for: effectiveAppearance).cgColor
        tokenLabels.forEach { label in
            label.textColor = isOff ? .secondaryLabelColor : .labelColor
        }
        plusLabels.forEach { label in
            label.textColor = .tertiaryLabelColor
        }
    }

    private func buildTokens(from title: String) {
        let tokens = isOff ? [title] : title.map(String.init)
        for (index, token) in tokens.enumerated() {
            if index > 0 {
                let plus = Self.label(
                    "+",
                    font: InnosDesignTokens.Font.shortcutSeparator
                )
                plusLabels.append(plus)
                stack.addArrangedSubview(plus)
                stack.setCustomSpacing(Metrics.tokenSpacing, after: plus)
            }

            let tokenLabel = Self.label(
                token,
                font: isOff
                    ? InnosDesignTokens.Font.shortcutOff
                    : InnosDesignTokens.Font.shortcutToken
            )
            tokenLabels.append(tokenLabel)
            stack.addArrangedSubview(tokenLabel)
            if !isOff {
                stack.setCustomSpacing(Metrics.tokenSpacing, after: tokenLabel)
            }
        }
    }

    private static func label(_ title: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = font
        label.alignment = .center
        label.lineBreakMode = .byClipping
        label.maximumNumberOfLines = 1
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
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
        font = InnosDesignTokens.Font.buttonLabel
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
        case .subtle:
            foreground = .labelColor
            background = PopoverPalette.subtleBackground(for: effectiveAppearance)
            border = PopoverPalette.border(for: effectiveAppearance)
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
                .font: font ?? InnosDesignTokens.Font.buttonLabel
            ]
        )
    }
}

private final class AppWindowPageTileButton: NSButton {
    private let page: UnifiedAppWindowPage
    private let iconBox = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")

    init(page: UnifiedAppWindowPage, target: AnyObject?, action: Selector?) {
        self.page = page
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        setButtonType(.momentaryPushIn)

        iconBox.wantsLayer = true
        iconBox.layer?.cornerRadius = 8
        iconBox.layer?.borderWidth = 1
        iconBox.translatesAutoresizingMaskIntoConstraints = false

        if let image = NSImage(systemSymbolName: page.tileSymbolName, accessibilityDescription: nil) {
            iconView.image = image
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        }
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(iconView)

        titleLabel.stringValue = page.title
        titleLabel.font = InnosDesignTokens.Font.app(ofSize: 13, weight: .semibold)
        titleLabel.maximumNumberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping

        descriptionLabel.stringValue = page.tileDescription
        descriptionLabel.font = InnosDesignTokens.Font.app(ofSize: 11, weight: .regular)
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.lineBreakMode = .byWordWrapping

        let textStack = NSStackView(views: [titleLabel, descriptionLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [iconBox, textStack])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: 34),
            iconBox.heightAnchor.constraint(equalToConstant: 34),
            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 19),
            iconView.heightAnchor.constraint(equalToConstant: 19),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
        setAccessibilityLabel("\(page.title). \(page.tileDescription)")
        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        layer?.backgroundColor = PopoverPalette.sectionBackground(for: effectiveAppearance).cgColor
        layer?.borderColor = PopoverPalette.border(for: effectiveAppearance).cgColor
        iconBox.layer?.backgroundColor = PopoverPalette.buttonBackground(for: effectiveAppearance).cgColor
        iconBox.layer?.borderColor = PopoverPalette.border(for: effectiveAppearance).cgColor
        iconView.contentTintColor = PopoverPalette.trackFill(for: effectiveAppearance)
        titleLabel.textColor = .labelColor
        descriptionLabel.textColor = .secondaryLabelColor
    }
}

struct MenuBarViewModel: Equatable {
    var modeTitle: String
    var quickControlsBadgeTitle: String
    var displaySummary: String
    var brightnessLabel: String
    var blueReductionLabel: String
    var blueReductionWarning: String?
    var automationTitle: String
    var automationActionTitle: String
    var automationActionCommand: MenuBarCommand
    var scheduleStatusDetail: String
    var scheduleSummary: String
    var shortcutRows: [ShortcutSummaryRow]
    var shortcutSummary: String
    var diagnosticsSummary: String

    init(
        state: BrightnessState,
        schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        latestDiagnosticEvent: DiagnosticsEvent? = nil
    ) {
        modeTitle = ModeStatusLabel.title(for: state.activeMode)
        quickControlsBadgeTitle = state.automationPausedUntilNextBoundary ? "MANUAL" : "AUTO"
        displaySummary = state.display.map { display in
            var parts = [Self.displaySummaryDisplayName(for: display), "software dimming"]
            if state.automationPausedUntilNextBoundary {
                if let resumeMinute = state.automationResumeMinuteOfDay {
                    parts.append("automation paused until \(Self.timeLabel(for: resumeMinute))")
                } else {
                    parts.append("automation paused until next schedule boundary")
                }
            }
            return parts.joined(separator: " · ")
        } ?? "No display selected"
        brightnessLabel = "\(state.targetBrightness)%"
        blueReductionLabel = "\(state.targetBlueReduction)%"
        blueReductionWarning = BlueReductionWarning.message(for: state.targetBlueReduction)
        if state.automationPausedUntilNextBoundary, let resumeMinute = state.automationResumeMinuteOfDay {
            automationTitle = "Automation paused until \(Self.timeLabel(for: resumeMinute))"
        } else if state.automationPausedUntilNextBoundary {
            automationTitle = "Automation paused until next schedule boundary"
        } else {
            automationTitle = "Automation active"
        }
        automationActionTitle = state.automationPausedUntilNextBoundary ? "Resume automation" : "Pause automation"
        automationActionCommand = state.automationPausedUntilNextBoundary ? .resumeAutomation : .pauseAutomation
        scheduleStatusDetail = Self.scheduleStatusDetail(state: state, schedule: schedule)
        scheduleSummary = Self.scheduleSummary(for: schedule)
        shortcutRows = Self.shortcutRows(for: shortcuts)
        shortcutSummary = ShortcutSummaryFormatter.plainSummary(from: shortcutRows)
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
            "\(timeLabel(for: entry.minuteOfDay)) · ☀ \(entry.brightness)% · 🌡 \(entry.blueReduction)%"
        }
        guard !labels.isEmpty else {
            return "Not configured"
        }
        return labels.joined(separator: "\n")
    }

    private static func scheduleStatusDetail(state: BrightnessState, schedule: [ScheduleEntry]) -> String {
        if state.automationPausedUntilNextBoundary, let resumeMinute = state.automationResumeMinuteOfDay {
            return "Next boundary \(timeLabel(for: resumeMinute))"
        }
        guard !SettingsSnapshot.sortedSchedule(schedule).isEmpty else {
            return "No schedule configured"
        }
        return "Schedule rows below"
    }

    private static func shortcutRows(for shortcuts: [ShortcutBinding]) -> [ShortcutSummaryRow] {
        let focusedActions: [ShortcutAction] = [
            .brightnessUp,
            .brightnessDown,
            .blueReductionUp,
            .blueReductionDown
        ]
        return focusedActions.map { action in
            let binding = shortcuts.first { $0.action == action }
            return ShortcutSummaryRow(
                action: action,
                title: shortcutActionLabel(for: action),
                keyLabel: shortcutLabel(for: binding)
            )
        }
    }

    private static func shortcutActionLabel(for action: ShortcutAction) -> String {
        switch action {
        case .brightnessUp:
            return "Brightness up"
        case .brightnessDown:
            return "Brightness down"
        case .blueReductionUp:
            return "Warmth up"
        case .blueReductionDown:
            return "Warmth down"
        case .quickDisableOverlay:
            return "Quick disable"
        case .restorePreviousDimming:
            return "Restore previous"
        case .openPopover:
            return "Open popover"
        }
    }

    private static func shortcutLabel(for binding: ShortcutBinding?) -> String {
        guard let binding, binding.isEnabled else {
            return "Off"
        }

        return shortcutKeyLabel(modifiers: binding.modifiers, keyCode: binding.keyCode)
    }

    private static func shortcutKeyLabel(modifiers: ShortcutModifiers, keyCode: UInt16) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }

        let key = keyLabel(for: keyCode)
        guard !parts.isEmpty else {
            return key
        }
        return parts.joined() + key
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        case 29:
            return "0"
        case 15:
            return "R"
        default:
            return "Key \(keyCode)"
        }
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

    private static func displaySummaryDisplayName(for display: DisplayIdentity) -> String {
        display.localizedName.replacingOccurrences(
            of: "^INNOS\\s+",
            with: "",
            options: .regularExpression
        )
    }
}

final class MenuBarPopoverView: NSView {
    static let preferredContentSize = NSSize(width: 428, height: 749)

    private let modeBadge: BadgePillView
    private let quickControlsBadge: BadgePillView
    private let actions: MenuBarActions
    private let displaySummaryLabel = NSTextField(labelWithString: "")
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let blueReductionValueLabel = NSTextField(labelWithString: "")
    private let blueReductionWarningLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleStatusDetailLabel = NSTextField(labelWithString: "")
    private let scheduleSummaryRowsView = ScheduleSummaryRowsView()
    private let shortcutSummaryRowsView = ShortcutSummaryRowsView()
    private let diagnosticsSummaryLabel = NSTextField(labelWithString: "")
    private let brightnessTrackView = ProgressTrackView()
    private let blueReductionTrackView = ProgressTrackView()
    private var commandButtons: [MenuBarCommand: NSButton] = [:]
    private var automationActionCommand: MenuBarCommand = .pauseAutomation
    private weak var automationActionButton: NSButton?

    init(
        state: BrightnessState,
        schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule,
        shortcuts: [ShortcutBinding] = ShortcutBinding.defaultBindings,
        latestDiagnosticEvent: DiagnosticsEvent? = nil,
        actions: MenuBarActions = .noop
    ) {
        modeBadge = BadgePillView(title: ModeStatusLabel.title(for: state.activeMode), tone: .success)
        quickControlsBadge = BadgePillView(title: "AUTO", tone: .neutral)
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
        modeBadge.setAccessibilityLabel(viewModel.modeTitle)
        quickControlsBadge.stringValue = viewModel.quickControlsBadgeTitle
        displaySummaryLabel.stringValue = viewModel.displaySummary
        brightnessValueLabel.stringValue = viewModel.brightnessLabel
        blueReductionValueLabel.stringValue = viewModel.blueReductionLabel
        blueReductionWarningLabel.stringValue = viewModel.blueReductionWarning ?? ""
        blueReductionWarningLabel.isHidden = viewModel.blueReductionWarning == nil
        automationLabel.stringValue = viewModel.automationTitle
        scheduleStatusDetailLabel.stringValue = viewModel.scheduleStatusDetail
        automationActionCommand = viewModel.automationActionCommand
        automationActionButton?.title = viewModel.automationActionTitle
        commandButtons[.pauseAutomation] = nil
        commandButtons[.resumeAutomation] = nil
        if let automationActionButton {
            commandButtons[automationActionCommand] = automationActionButton
        }
        scheduleSummaryRowsView.update(schedule: schedule)
        shortcutSummaryRowsView.update(rows: viewModel.shortcutRows)
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
        scheduleSummaryRowsView.plainSummary
    }

    func scheduleStatusForTesting() -> String {
        [automationLabel.stringValue, scheduleStatusDetailLabel.stringValue]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func shortcutSummaryForTesting() -> String {
        shortcutSummaryRowsView.plainSummary
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
            blueReductionWarningLabel,
            automationLabel,
            scheduleStatusDetailLabel,
            diagnosticsSummaryLabel
        ].forEach(Self.configureWrappingLabel)
        automationLabel.font = InnosDesignTokens.Font.bodySmallStrong
        automationLabel.textColor = .labelColor
        scheduleStatusDetailLabel.textColor = .secondaryLabelColor
        blueReductionWarningLabel.textColor = PopoverPalette.warningColor(for: effectiveAppearance)
        blueReductionWarningLabel.isHidden = true

        let header = makeHeader()
        let controls = makeSection(
            title: "Quick controls",
            trailing: quickControlsBadge,
            views: [
                makeControlGroup(
                    title: "Brightness",
                    iconSystemName: "sun.max.fill",
                    iconFallback: "☀",
                    iconColor: PopoverPalette.warningColor(for: effectiveAppearance),
                    valueLabel: brightnessValueLabel,
                    trackView: brightnessTrackView,
                    decrement: compactButton("-", accessibilityLabel: "Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed)),
                    increment: compactButton("+", accessibilityLabel: "Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))
                ),
                makeSeparator(),
                makeControlGroup(
                    title: "Warmth",
                    iconSystemName: "thermometer.medium",
                    iconFallback: "🌡",
                    iconColor: NSColor(calibratedRed: 0.94, green: 0.58, blue: 0.16, alpha: 1),
                    valueLabel: blueReductionValueLabel,
                    trackView: blueReductionTrackView,
                    decrement: compactButton("-", accessibilityLabel: "Warmth down", command: .blueReductionDown, action: #selector(blueReductionDownPressed)),
                    increment: compactButton("+", accessibilityLabel: "Warmth up", command: .blueReductionUp, action: #selector(blueReductionUpPressed))
                ),
                blueReductionWarningLabel,
                makeActionRow([
                    button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                    button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed))
                ])
            ]
        )
        brightnessTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBrightness(Self.percent(from: fraction)))
        }
        blueReductionTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBlueReduction(Self.percent(from: fraction)))
        }
        brightnessTrackView.setAccessibilityLabel("Brightness percentage")
        blueReductionTrackView.setAccessibilityLabel("Warmth percentage")

        let automationActionButton = button(
            "Pause automation",
            command: .pauseAutomation,
            action: #selector(automationActionPressed)
        )
        self.automationActionButton = automationActionButton
        let scheduleStatusStack = NSStackView(views: [automationLabel, scheduleStatusDetailLabel])
        scheduleStatusStack.orientation = .vertical
        scheduleStatusStack.alignment = .leading
        scheduleStatusStack.spacing = 3
        let schedule = makeSection(
            title: "Schedule",
            trailing: nil,
            views: [
                PopoverContainerView(style: .subtle, content: scheduleStatusStack),
                scheduleSummaryRowsView,
                makeActionRow([
                    button("Edit schedule", command: .openScheduleEditor, action: #selector(openScheduleEditorPressed), style: .primary),
                    automationActionButton
                ])
            ]
        )
        let shortcuts = makeSection(
            title: "Shortcuts",
            trailing: pillBadge("ENABLED", tone: .neutral, compact: true),
            views: [
                shortcutSummaryRowsView,
                makeActionRow([
                    button("Edit Shortcuts", command: .openShortcuts, action: #selector(openShortcutsPressed)),
                    button("Open Control Window", command: .openAppWindow, action: #selector(openAppWindowPressed), style: .primary)
                ])
            ]
        )

        let arrangedSubviews = [
            header,
            controls,
            schedule,
            shortcuts
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
        title.font = InnosDesignTokens.Font.appTitle
        title.textColor = .labelColor

        let topRow = NSStackView(views: [title, modeBadge])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        modeBadge.setContentHuggingPriority(.required, for: .horizontal)

        let separator = makeSeparator()
        let stack = NSStackView(views: [topRow, displaySummaryLabel, separator])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        [topRow, displaySummaryLabel, separator].forEach { view in
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
        iconSystemName: String,
        iconFallback: String,
        iconColor: NSColor,
        valueLabel: NSTextField,
        trackView: ProgressTrackView,
        decrement: NSButton,
        increment: NSButton
    ) -> NSStackView {
        let titleView = ControlTitleView(
            title: title,
            systemSymbolName: iconSystemName,
            fallback: iconFallback,
            iconColor: iconColor,
            font: InnosDesignTokens.Font.controlLabel,
            textColor: .labelColor
        )
        titleView.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = InnosDesignTokens.Font.controlValue
        valueLabel.alignment = .right
        valueLabel.textColor = .labelColor
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleView, valueLabel, trackView, decrement, increment])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        titleView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
        trackView.heightAnchor.constraint(equalToConstant: 18).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func makeSummaryRow(title: String, value: NSView) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = InnosDesignTokens.Font.sectionLabel
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
        label.font = InnosDesignTokens.Font.bodySmall
        label.textColor = .secondaryLabelColor
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = InnosDesignTokens.Font.sectionLabel
        label.textColor = .secondaryLabelColor
        return label
    }

    private func pillBadge(_ title: String, tone: BadgeTone, compact: Bool = false) -> BadgePillView {
        let badge = BadgePillView(title: title, tone: tone, compact: compact)
        return badge
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

    private func button(
        _ title: String,
        command: MenuBarCommand,
        action: Selector,
        style: PopoverButtonStyle = .normal
    ) -> NSButton {
        let button = PopoverCommandButton(title: title, style: style, target: self, action: action)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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

    @objc private func automationActionPressed() {
        actions.perform(automationActionCommand)
    }

    @objc private func quickDisablePressed() {
        actions.perform(.quickDisable)
    }

    @objc private func restorePreviousPressed() {
        actions.perform(.restorePrevious)
    }

    @objc private func openScheduleEditorPressed() {
        actions.perform(.openScheduleEditor)
    }

    @objc private func openAppWindowPressed() {
        actions.perform(.openAppWindow)
    }

    @objc private func openShortcutsPressed() {
        actions.perform(.openShortcuts)
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
    var blueReductionWarning: String?
    var automationValue: String
    var automationActionTitle: String
    var automationActionCommand: MenuBarCommand
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
        blueReductionWarning = BlueReductionWarning.message(for: state.targetBlueReduction)
        if state.automationPausedUntilNextBoundary {
            automationValue = state.automationResumeMinuteOfDay.map {
                "paused until \(Self.timeLabel(for: $0))"
            } ?? "paused until next schedule boundary"
        } else {
            automationValue = "active"
        }
        automationActionTitle = state.automationPausedUntilNextBoundary ? "Resume automation" : "Pause automation"
        automationActionCommand = state.automationPausedUntilNextBoundary ? .resumeAutomation : .pauseAutomation
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
        brightnessLine = "Brightness: \(brightnessValue) / Warmth: \(blueReductionValue)"
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
enum AppDashboardFocusTarget {
    case home
    case current
    case display
    case schedule
    case shortcuts
    case settings
    case diagnostics
}

@MainActor
final class AppDashboardWindowController: NSWindowController {
    private let modeBadge = StatusBadgeView(mode: .unknown)
    private let actions: MenuBarActions
    private let scheduleActions: ScheduleEditorActions
    private let displayLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private let brightnessLabel = NSTextField(labelWithString: "")
    private let blueReductionLabel = NSTextField(labelWithString: "")
    private let dashboardBlueReductionWarningLabel = NSTextField(labelWithString: "")
    private let automationLabel = NSTextField(labelWithString: "")
    private let scheduleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let failureLabel = NSTextField(labelWithString: "")
    private let brightnessTrackView = ProgressTrackView()
    private let blueReductionTrackView = ProgressTrackView()
    private let scheduleEditorView = ScheduleEditorView()
    private let scheduleStatusLabel = NSTextField(labelWithString: "Schedule changes are ready to save.")
    private let diagnosticsTextView = NSTextView()
    private let diagnosticsScrollView = NSScrollView()
    private weak var scheduleSectionView: NSView?
    private weak var currentSectionView: NSView?
    private weak var configurationSectionView: NSView?
    private weak var diagnosticsSectionView: NSView?
    private var commandButtons: [MenuBarCommand: NSButton] = [:]
    private var automationActionCommand: MenuBarCommand = .pauseAutomation
    private weak var automationActionButton: NSButton?

    init(
        actions: MenuBarActions = .noop,
        scheduleActions: ScheduleEditorActions = .noop
    ) {
        self.actions = actions
        self.scheduleActions = scheduleActions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 880),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer"
        window.minSize = NSSize(width: 520, height: 760)
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
        dashboardBlueReductionWarningLabel.stringValue = viewModel.blueReductionWarning ?? ""
        dashboardBlueReductionWarningLabel.isHidden = viewModel.blueReductionWarning == nil
        brightnessTrackView.fraction = CGFloat(state.targetBrightness) / 100
        blueReductionTrackView.fraction = CGFloat(state.targetBlueReduction) / 100
        automationLabel.stringValue = viewModel.automationValue
        automationActionCommand = viewModel.automationActionCommand
        automationActionButton?.title = viewModel.automationActionTitle
        commandButtons[.pauseAutomation] = nil
        commandButtons[.resumeAutomation] = nil
        if let automationActionButton {
            commandButtons[automationActionCommand] = automationActionButton
        }
        scheduleLabel.stringValue = viewModel.scheduleValue
        scheduleEditorView.update(schedule: schedule)
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

    func setScheduleRowForTesting(index: Int, time: String, brightness: String, blueReduction: String) {
        scheduleEditorView.setRowForTesting(
            index: index,
            time: time,
            brightness: brightness,
            blueReduction: blueReduction
        )
    }

    @discardableResult
    func saveScheduleForTesting() -> Result<SettingsSnapshot, Error> {
        saveScheduleFromEditor(reportsStatus: false)
    }

    func scheduleSummaryForTesting() -> String {
        scheduleLabel.stringValue
    }

    func focus(_ target: AppDashboardFocusTarget?) {
        guard let target else {
            return
        }
        window?.contentView?.layoutSubtreeIfNeeded()
        let targetView: NSView?
        switch target {
        case .home:
            targetView = window?.contentView
        case .current, .display:
            targetView = currentSectionView
        case .schedule:
            targetView = scheduleSectionView
        case .shortcuts, .settings:
            targetView = configurationSectionView
        case .diagnostics:
            targetView = diagnosticsSectionView
        }
        if let targetView {
            targetView.scrollToVisible(targetView.bounds)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func installContent() {
        let title = NSTextField(labelWithString: "InnosDimmer")
        title.font = InnosDesignTokens.Font.app(ofSize: 22, weight: .bold)
        title.textColor = .labelColor
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        configureBadge(modeBadge)

        [
            displayLabel,
            modeLabel,
            brightnessLabel,
            blueReductionLabel,
            dashboardBlueReductionWarningLabel,
            automationLabel,
            scheduleLabel,
            scheduleStatusLabel,
            shortcutLabel,
            failureLabel
        ].forEach(Self.configureWrappingLabel)
        dashboardBlueReductionWarningLabel.textColor = PopoverPalette.warningColor(for: window?.effectiveAppearance ?? NSApp.effectiveAppearance)
        dashboardBlueReductionWarningLabel.isHidden = true
        scheduleStatusLabel.textColor = .secondaryLabelColor
        failureLabel.font = InnosDesignTokens.Font.app(ofSize: 13, weight: .semibold)

        diagnosticsTextView.isEditable = false
        diagnosticsTextView.isSelectable = true
        diagnosticsTextView.font = InnosDesignTokens.Font.app(ofSize: 12)
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
        blueReductionTrackView.setAccessibilityLabel("Dashboard warmth percentage")

        let header = makeHeader(title: title)
        let currentState = makeSection(
            title: "Current state",
            views: [
                makeSummaryRow(title: "Display", value: displayLabel),
                makeSummaryRow(title: "Mode", value: modeLabel),
                makeControlGroup(
                    title: "Brightness",
                    iconSystemName: "sun.max.fill",
                    iconFallback: "☀",
                    iconColor: NSColor(calibratedRed: 0.94, green: 0.58, blue: 0.16, alpha: 1),
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
                    title: "Warmth",
                    iconSystemName: "thermometer.medium",
                    iconFallback: "🌡",
                    iconColor: PopoverPalette.warningColor(for: window?.effectiveAppearance ?? NSApp.effectiveAppearance),
                    valueLabel: blueReductionLabel,
                    trackView: blueReductionTrackView,
                    decrement: compactButton(
                        "-",
                        accessibilityLabel: "Dashboard warmth down",
                        command: .blueReductionDown,
                        action: #selector(blueReductionDownPressed)
                    ),
                    increment: compactButton(
                        "+",
                        accessibilityLabel: "Dashboard warmth up",
                        command: .blueReductionUp,
                        action: #selector(blueReductionUpPressed)
                    )
                ),
                dashboardBlueReductionWarningLabel,
                makeSummaryRow(title: "Automation", value: automationLabel)
            ]
        )
        currentSectionView = currentState
        let scheduleSaveButton = PopoverCommandButton(
            title: "Save schedule",
            style: .primary,
            target: self,
            action: #selector(saveSchedulePressed)
        )
        scheduleSaveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
        let scheduleEditor = makeSection(
            title: "Automation schedule",
            views: [
                makeSummaryRow(title: "Saved rows", value: scheduleLabel),
                scheduleEditorView,
                scheduleSaveButton,
                scheduleStatusLabel
            ]
        )
        scheduleSectionView = scheduleEditor
        let automationActionButton = button(
            "Pause automation",
            command: .pauseAutomation,
            action: #selector(automationActionPressed)
        )
        self.automationActionButton = automationActionButton
        let configuration = makeSection(
            title: "Configuration",
            views: [
                makeSummaryRow(title: "Shortcuts", value: shortcutLabel),
                button("Quick disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                makeActionRow([
                    button("Restore previous", command: .restorePrevious, action: #selector(restorePreviousPressed)),
                    automationActionButton
                ]),
                button("Settings", command: .openSettings, action: #selector(openSettingsPressed))
            ]
        )
        configurationSectionView = configuration
        let diagnostics = makeSection(
            title: "Diagnostics",
            views: [
                makeSummaryRow(title: "Failures", value: failureLabel),
                diagnosticsScrollView
            ]
        )
        diagnosticsSectionView = diagnostics

        let arrangedSubviews = [header, currentState, scheduleEditor, configuration, diagnostics]
        let stack = NSStackView(views: arrangedSubviews)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.addSubview(stack)

        let contentView = DashboardRootView()
        window?.contentView = contentView
        contentView.addSubview(scrollView)
        arrangedSubviews.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -18)
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
        titleLabel.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
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
        iconSystemName: String,
        iconFallback: String,
        iconColor: NSColor,
        valueLabel: NSTextField,
        trackView: ProgressTrackView,
        decrement: NSButton,
        increment: NSButton
    ) -> NSStackView {
        let titleView = ControlTitleView(
            title: title,
            systemSymbolName: iconSystemName,
            fallback: iconFallback,
            iconColor: iconColor,
            font: InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold),
            textColor: .secondaryLabelColor
        )
        titleView.widthAnchor.constraint(equalToConstant: 116).isActive = true
        titleView.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = InnosDesignTokens.Font.app(ofSize: 16, weight: .semibold)
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [titleView, valueLabel, trackView, decrement, increment])
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
        label.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func configureWrappingLabel(_ label: NSTextField) {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.font = InnosDesignTokens.Font.app(ofSize: 13)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureBadge(_ badge: StatusBadgeView) {
        badge.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
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

    @objc private func automationActionPressed() {
        actions.perform(automationActionCommand)
    }

    @objc private func saveSchedulePressed() {
        _ = saveScheduleFromEditor(reportsStatus: true)
    }

    @objc private func openSettingsPressed() {
        actions.perform(.openSettings)
    }

    private func saveScheduleFromEditor(reportsStatus: Bool) -> Result<SettingsSnapshot, Error> {
        do {
            let editedSchedule = try scheduleEditorView.editedSchedule()
            switch scheduleActions.updateSchedule(editedSchedule) {
            case .success(let snapshot):
                scheduleEditorView.update(schedule: snapshot.schedule)
                scheduleLabel.stringValue = Self.scheduleSummary(for: snapshot.schedule)
                if reportsStatus {
                    reportScheduleStatus("Schedule saved.")
                }
                return .success(snapshot)
            case .failure(let error):
                if reportsStatus {
                    reportScheduleStatus(error.localizedDescription, isError: true)
                }
                return .failure(error)
            }
        } catch {
            if reportsStatus {
                reportScheduleStatus(error.localizedDescription, isError: true)
            }
            return .failure(error)
        }
    }

    private func reportScheduleStatus(_ message: String, isError: Bool = false) {
        scheduleStatusLabel.stringValue = message
        scheduleStatusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private static func scheduleSummary(for schedule: [ScheduleEntry]) -> String {
        MenuBarViewModel(
            state: .defaultState(),
            schedule: schedule,
            shortcuts: []
        ).scheduleSummary
    }
}

struct AppWindowPageStructure: Equatable {
    var pageTitle: String
    var identifiers: Set<String>
    var visibleText: [String]

    func containsIdentifier(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    func containsText(_ fragment: String) -> Bool {
        visibleText.contains { $0.localizedCaseInsensitiveContains(fragment) }
    }
}

private enum UnifiedAppWindowPage: CaseIterable {
    case home
    case current
    case display
    case schedule
    case shortcuts
    case settings
    case diagnostics

    init(_ target: AppDashboardFocusTarget?) {
        switch target {
        case .none, .home:
            self = .home
        case .current:
            self = .current
        case .display:
            self = .display
        case .schedule:
            self = .schedule
        case .shortcuts:
            self = .shortcuts
        case .settings:
            self = .settings
        case .diagnostics:
            self = .diagnostics
        }
    }

    var title: String {
        switch self {
        case .home:
            return "InnosDimmer Control Center"
        case .current:
            return "Current status"
        case .display:
            return "Display"
        case .schedule:
            return "Schedule"
        case .shortcuts:
            return "Shortcuts"
        case .settings:
            return "Settings"
        case .diagnostics:
            return "Diagnostics"
        }
    }

    var tileDescription: String {
        switch self {
        case .home:
            return ""
        case .current:
            return "Resolved display, mode, automation, and commands."
        case .display:
            return "Target display, picker state, and detection summary."
        case .schedule:
            return "Schedule summary, editor entry, pause and resume."
        case .shortcuts:
            return "All global bindings, including Open popover."
        case .settings:
            return "Launch at login, saved state, and persistence status."
        case .diagnostics:
            return "Verification matrix, recent failures, and JSON export."
        }
    }

    var tileSymbolName: String {
        switch self {
        case .home:
            return "house"
        case .current:
            return "slider.horizontal.3"
        case .display:
            return "display"
        case .schedule:
            return "clock"
        case .shortcuts:
            return "keyboard"
        case .settings:
            return "gearshape"
        case .diagnostics:
            return "waveform.path.ecg"
        }
    }
}

@MainActor
final class UnifiedAppWindowController: NSWindowController {
    private enum Layout {
        static let shortcutActionWidth: CGFloat = 150
        static let shortcutToggleWidth: CGFloat = 34
        static let shortcutModifierWidth: CGFloat = 42
        static let shortcutKeyWidth: CGFloat = 70
        static let homeLeftMinimumWidth: CGFloat = 430
        static let homeNavigationWidth: CGFloat = 348
        static let homeTileWidth: CGFloat = 168
        static let homeTileHeight: CGFloat = 104
        static let detailSidebarWidth: CGFloat = 256
        static let detailMinimumPrimaryWidth: CGFloat = 360
        static let tokenRowHeight: CGFloat = 34
    }

    private struct ShortcutControls {
        var enabled: NSButton
        var option: NSButton
        var shift: NSButton
        var control: NSButton
        var command: NSButton
        var keyCode: ShortcutKeyField
    }

    private enum AppWindowFormError: LocalizedError {
        case invalidShortcutKey(action: String)

        var errorDescription: String? {
            switch self {
            case .invalidShortcutKey(let action):
                return "\(action) needs a key code from 0 to 65535."
            }
        }
    }

    private let actions: MenuBarActions
    private let scheduleActions: ScheduleEditorActions
    private let settingsActions: SettingsActions
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyView = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let modeChip = InnosStatusChipView(title: "Software dimming ready", tone: .neutral)
    private let loginChip = InnosStatusChipView(title: "Login item off", tone: .neutral)
    private let displayPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scheduleEditorView = ScheduleEditorView()
    private let scheduleStatusLabel = NSTextField(labelWithString: "")
    private let loginItemCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let diagnosticsTextView = NSTextView()
    private let brightnessTrackView = ProgressTrackView()
    private let blueReductionTrackView = ProgressTrackView()
    private let brightnessValueLabel = NSTextField(labelWithString: "")
    private let blueReductionValueLabel = NSTextField(labelWithString: "")
    private weak var homeQuickActionsSection: NSView?
    private weak var homeNextActionsSection: NSView?
    private var commandButtons: [MenuBarCommand: NSButton] = [:]
    private var pageButtons: [UnifiedAppWindowPage: NSButton] = [:]
    private var shortcutControls: [ShortcutAction: ShortcutControls] = [:]
    private var activePage: UnifiedAppWindowPage = .home
    private var automationActionCommand: MenuBarCommand = .pauseAutomation
    private var state = BrightnessState.defaultState()
    private var schedule = ScheduleEntry.defaultSchedule
    private var shortcuts = ShortcutBinding.defaultBindings
    private var events: [DiagnosticsEvent] = []
    private var snapshot = SettingsSnapshot.defaultSnapshot()
    private var displayCandidates: [DisplayIdentity] = []
    private var loginItemStatus: LoginItemStatus = .notRegistered

    init(
        actions: MenuBarActions = .noop,
        scheduleActions: ScheduleEditorActions = .noop,
        settingsActions: SettingsActions = .noop
    ) {
        self.actions = actions
        self.scheduleActions = scheduleActions
        self.settingsActions = settingsActions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer"
        window.minSize = NSSize(width: 780, height: 520)
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
        events: [DiagnosticsEvent],
        snapshot: SettingsSnapshot = .defaultSnapshot(),
        displayCandidates: [DisplayIdentity] = [],
        loginItemStatus: LoginItemStatus = .notRegistered
    ) {
        self.state = state
        self.schedule = schedule
        self.shortcuts = shortcuts
        self.events = events
        self.snapshot = snapshot
        self.displayCandidates = displayCandidates
        self.loginItemStatus = loginItemStatus
        scheduleEditorView.update(schedule: schedule)
        updateLiveControls()
        renderActivePage()
    }

    func focus(_ target: AppDashboardFocusTarget?) {
        activePage = UnifiedAppWindowPage(target)
        renderActivePage()
        window?.makeKeyAndOrderFront(nil)
    }

    func commandButtonForTesting(_ command: MenuBarCommand) -> NSButton? {
        commandButtons[command]
    }

    func activePageForTesting() -> String {
        activePage.title
    }

    func pageStructureForTesting(focus target: AppDashboardFocusTarget) -> AppWindowPageStructure {
        focus(target)
        window?.contentView?.layoutSubtreeIfNeeded()
        let contentView = window?.contentView
        return AppWindowPageStructure(
            pageTitle: activePage.title,
            identifiers: Set(contentView?.appWindowIdentifiersForTesting() ?? []),
            visibleText: contentView?.appWindowVisibleTextForTesting() ?? []
        )
    }

    func homeLayoutMetricsForTesting() -> (quickActionsWidth: CGFloat, nextActionsWidth: CGFloat, firstTileWidth: CGFloat, firstTileHeight: CGFloat)? {
        activePage = .home
        renderActivePage()
        window?.contentView?.layoutSubtreeIfNeeded()
        guard let quickActions = homeQuickActionsSection,
              let nextActions = homeNextActionsSection,
              let firstTile = pageButtons[.current] else {
            return nil
        }
        return (
            quickActions.frame.width,
            nextActions.frame.width,
            firstTile.frame.width,
            firstTile.frame.height
        )
    }

    func simulateBrightnessTrackChangeForTesting(percent: Int) {
        brightnessTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func simulateBlueReductionTrackChangeForTesting(percent: Int) {
        blueReductionTrackView.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func setScheduleRowForTesting(index: Int, time: String, brightness: String, blueReduction: String) {
        scheduleEditorView.setRowForTesting(index: index, time: time, brightness: brightness, blueReduction: blueReduction)
    }

    @discardableResult
    func saveScheduleForTesting() -> Result<SettingsSnapshot, Error> {
        saveScheduleFromEditor(reportsStatus: false)
    }

    @discardableResult
    func saveShortcutsForTesting() -> Result<SettingsSnapshot, Error> {
        saveShortcutsFromControls(reportsStatus: false)
    }

    func setShortcutForTesting(action: ShortcutAction, keyCode: UInt16, modifiers: ShortcutModifiers, isEnabled: Bool) {
        ensureShortcutControls()
        guard let controls = shortcutControls[action] else {
            return
        }
        controls.enabled.state = isEnabled ? .on : .off
        controls.option.state = modifiers.contains(.option) ? .on : .off
        controls.shift.state = modifiers.contains(.shift) ? .on : .off
        controls.control.state = modifiers.contains(.control) ? .on : .off
        controls.command.state = modifiers.contains(.command) ? .on : .off
        controls.keyCode.setKeyCode(keyCode)
    }

    func setShortcutKeyStringForTesting(action: ShortcutAction, keyCode: String) {
        ensureShortcutControls()
        shortcutControls[action]?.keyCode.setRawString(keyCode)
    }

    func shortcutForTesting(action: ShortcutAction) -> ShortcutBinding? {
        ensureShortcutControls()
        return try? shortcutBindingsFromControls().first { $0.action == action }
    }

    func selectDisplayIndexForTesting(_ selectedIndex: Int) {
        activePage = .display
        renderActivePage()
        displayPicker.selectItem(at: selectedIndex)
        displaySelectionChanged()
    }

    func toggleLaunchAtLoginForTesting(_ enabled: Bool) {
        loginItemCheckbox.state = enabled ? .on : .off
        loginItemToggled()
    }

    func exportDiagnosticsForTesting() -> Result<Data, Error> {
        settingsActions.exportDiagnostics()
    }

    private func installContent() {
        titleLabel.font = InnosDesignTokens.Font.app(ofSize: 22, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.stringValue = activePage.title
        statusLabel.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Ready."
        statusLabel.isHidden = true
        scheduleStatusLabel.font = InnosDesignTokens.Font.body
        scheduleStatusLabel.textColor = .secondaryLabelColor
        displayPicker.target = self
        displayPicker.action = #selector(displaySelectionChanged)
        displayPicker.font = InnosDesignTokens.Font.body
        scheduleEditorView.identifier = NSUserInterfaceItemIdentifier("app-window-schedule-table")
        loginItemCheckbox.target = self
        loginItemCheckbox.action = #selector(loginItemToggled)
        loginItemCheckbox.font = InnosDesignTokens.Font.body
        diagnosticsTextView.isEditable = false
        diagnosticsTextView.isSelectable = true
        diagnosticsTextView.font = InnosDesignTokens.Font.app(ofSize: 12)
        diagnosticsTextView.drawsBackground = true
        brightnessTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBrightness(Self.percent(from: fraction)))
        }
        blueReductionTrackView.onUserFractionChange = { [weak self] fraction in
            self?.actions.perform(.setBlueReduction(Self.percent(from: fraction)))
        }
        brightnessTrackView.setAccessibilityLabel("App window brightness percentage")
        blueReductionTrackView.setAccessibilityLabel("App window blue reduction percentage")

        let header = makeHeader()
        let rootStack = NSStackView(views: [header, statusLabel, bodyView])
        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.spacing = 14
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        bodyView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = DashboardRootView()
        window?.contentView = contentView
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            header.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            bodyView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            bodyView.heightAnchor.constraint(greaterThanOrEqualToConstant: 330)
        ])
        renderActivePage()
    }

    private func makeHeader() -> NSView {
        let header = NSStackView(views: [
            titleLabel,
            spacer(),
            modeChip,
            loginChip
        ])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10
        return header
    }

    private func renderActivePage() {
        titleLabel.stringValue = activePage == .home ? activePage.title : "InnosDimmer"
        commandButtons.removeAll(keepingCapacity: true)
        pageButtons.removeAll(keepingCapacity: true)
        bodyView.subviews.forEach { $0.removeFromSuperview() }

        let content: NSView
        switch activePage {
        case .home:
            content = makeHomePage()
        case .current:
            content = makeCurrentPage()
        case .display:
            content = makeDisplayPage()
        case .schedule:
            content = makeSchedulePage()
        case .shortcuts:
            content = makeShortcutsPage()
        case .settings:
            content = makeSettingsPage()
        case .diagnostics:
            content = makeDiagnosticsPage()
        }

        content.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor),
            content.topAnchor.constraint(equalTo: bodyView.topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bodyView.bottomAnchor)
        ])
        updateLiveControls()
    }

    private func makeHomePage() -> NSView {
        let quickActions = makeQuickActionsSection()
        let nextActions = makeNextActionsSection()
        homeQuickActionsSection = quickActions
        homeNextActionsSection = nextActions

        let left = NSStackView(views: [quickActions, nextActions])
        left.orientation = .vertical
        left.alignment = .width
        left.spacing = 12
        left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        left.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        quickActions.translatesAutoresizingMaskIntoConstraints = false
        nextActions.translatesAutoresizingMaskIntoConstraints = false
        quickActions.widthAnchor.constraint(equalTo: left.widthAnchor).isActive = true
        nextActions.widthAnchor.constraint(equalTo: left.widthAnchor).isActive = true

        let tiles = makeNavigationGrid()
        tiles.setContentHuggingPriority(.required, for: .horizontal)
        tiles.setContentCompressionResistancePriority(.required, for: .horizontal)

        let layout = NSStackView(views: [left, tiles])
        layout.orientation = .horizontal
        layout.alignment = .top
        layout.distribution = .fill
        layout.spacing = 12
        NSLayoutConstraint.activate([
            left.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.homeLeftMinimumWidth),
            tiles.widthAnchor.constraint(equalToConstant: Layout.homeNavigationWidth)
        ])
        return layout
    }

    private func makeNavigationGrid() -> NSStackView {
        let rows = [
            [makeNavigationTile(.current), makeNavigationTile(.display)],
            [makeNavigationTile(.schedule), makeNavigationTile(.shortcuts)],
            [makeNavigationTile(.settings), makeNavigationTile(.diagnostics)]
        ].map { buttons in
            let row = NSStackView(views: buttons)
            row.orientation = .horizontal
            row.alignment = .width
            row.distribution = .fillEqually
            row.spacing = 12
            return row
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        rows.forEach { row in
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func makeCurrentPage() -> NSView {
        makeDetailPage(
            title: "Current status",
            content: verticalStack([
                makeSection(title: "Snapshot lines", trailing: makeChip("Live", tone: .neutral), views: [
                makeSummaryRow(title: "Display", value: currentDisplaySummary()),
                makeSummaryRow(title: "Mode", value: displayModeSummary()),
                makeSummaryRow(
                    title: "Brightness",
                    value: "Brightness: \(state.targetBrightness)% / Blue reduction: \(state.targetBlueReduction)%"
                ),
                makeSummaryRow(title: "Automation", value: automationSummary())
                ]),
                makeSection(title: "Commands", views: [
                    makeActionRow([
                        button("Open app window", command: .openAppWindow, action: #selector(openAppWindowPressed), style: .primary),
                        button("Settings", command: .openSettings, action: #selector(openSettingsPressed)),
                        button(automationActionTitle(), command: automationActionCommand, action: #selector(automationActionPressed))
                    ])
                ])
            ])
        )
    }

    private func makeDisplayPage() -> NSView {
        renderDisplayPicker()
        let resolvedDisplay = resolvedTargetDisplay()
        let resolvedTone: InnosDesignTokens.Tone = resolvedDisplay == nil ? .warning : .ready
        let split = makeDetailSplit(
            sidebar: makeSection(title: "Current state", trailing: makeChip("Ready", tone: .ready), views: [
                makeSummaryRow(title: "Display", value: currentDisplaySummary()),
                makeSummaryRow(title: "Mode", value: displayModeSummary()),
                makeSummaryRow(title: "Brightness", value: "\(state.targetBrightness)%"),
                makeSummaryRow(title: "Blue", value: "\(state.targetBlueReduction)%")
            ]),
            primary: verticalStack([
                makeSection(title: "Target display", trailing: makeChip(resolvedDisplay == nil ? "Unresolved" : "Resolved", tone: resolvedTone), views: [
                    displayPicker,
                    makeSummaryRow(title: "Selected", value: selectedDisplaySummary()),
                    makeSummaryRow(title: "Resolved to", value: resolvedDisplaySummary(resolvedDisplay)),
                    makeSummaryRow(title: "Main display", value: mainDisplaySummary(resolvedDisplay)),
                    makeSummaryRow(title: "Gamma table", value: gammaTableSummary(resolvedDisplay))
                ]),
                makeSection(title: "Saved selection", views: [
                    makeSummaryRow(title: "Saved", value: selectedDisplaySummary()),
                    makeActionRow([
                        PopoverCommandButton(
                            title: "Save display",
                            style: .primary,
                            target: self,
                            action: #selector(saveDisplayPressed)
                        ),
                        PopoverCommandButton(
                            title: "Use automatic",
                            style: .normal,
                            target: self,
                            action: #selector(useAutomaticDisplayPressed)
                        )
                    ])
                ])
            ])
        )
        return makeDetailPage(
            title: "Display",
            trailingActions: [
                PopoverCommandButton(
                    title: "Refresh displays",
                    style: .primary,
                    target: self,
                    action: #selector(refreshDisplaysPressed)
                )
            ],
            content: split
        )
    }

    private func makeSchedulePage() -> NSView {
        let controls = makeActionRow([
            button(automationActionTitle(), command: automationActionCommand, action: #selector(automationActionPressed)),
            PopoverCommandButton(title: "Save schedule", style: .primary, target: self, action: #selector(saveSchedulePressed))
        ])
        controls.identifier = NSUserInterfaceItemIdentifier("app-window-schedule-actions")
        return makeDetailPage(
            title: "Schedule",
            trailingActions: [
                makeChip(nextScheduleBadgeText(), tone: .warning)
            ],
            content: verticalStack([
                makeSection(title: "Schedule", views: [
                    makeTokenRow(title: "Status", value: automationSummary()),
                    makeTokenRow(title: "Current", value: scheduleSummaryText()),
                    makeTokenRow(title: "Shortcuts", value: "Option + Shift controls")
                ]),
                makeSection(title: "Schedule rows", views: [scheduleEditorView, scheduleStatusLabel, controls])
            ])
        )
    }

    private func makeShortcutsPage() -> NSView {
        ensureShortcutControls()
        renderShortcuts()
        return makeDetailPage(
            title: "Shortcuts",
            content: verticalStack([
                makeSection(title: "Shortcut rows", views: [
                    makeTokenRow(title: "Global shortcuts", value: "\(shortcuts.filter(\.isEnabled).count) enabled"),
                    makeShortcutStack(),
                    makeActionRow([
                        PopoverCommandButton(title: "Save shortcuts", style: .primary, target: self, action: #selector(saveShortcutsPressed)),
                        PopoverCommandButton(title: "Reset shortcuts", style: .normal, target: self, action: #selector(resetShortcutsPressed))
                    ])
                ])
            ])
        )
    }

    private func makeSettingsPage() -> NSView {
        loginItemCheckbox.state = loginItemStatus == .enabled ? .on : .off
        let split = makeDetailSplit(
            sidebar: makeSection(title: "Startup", views: [
                loginItemCheckbox,
                makeTokenRow(title: "Launch at login", value: loginItemSummary()),
                makeTokenRow(title: "Approval", value: loginItemApprovalSummary()),
                makeTokenRow(title: "Behavior", value: "Apply at launch and keep saved state persistent"),
                makeActionRow([
                    PopoverCommandButton(title: "Apply settings", style: .primary, target: self, action: #selector(loginItemToggled))
                ])
            ]),
            primary: makeSection(title: "Saved settings", views: [
                makeTokenRow(title: "Target display", value: snapshot.selectedDisplay?.localizedName ?? "Automatic"),
                makeTokenRow(title: "Schedule", value: "\(snapshot.schedule.count) row(s)"),
                makeTokenRow(title: "Shortcuts", value: "\(snapshot.shortcuts.filter(\.isEnabled).count) enabled"),
                makeTokenRow(title: "Schema", value: "SettingsSnapshot"),
                makeTokenRow(title: "Status label", value: statusLabel.stringValue)
            ])
        )
        return makeDetailPage(title: "Settings", content: split)
    }

    private func makeDiagnosticsPage() -> NSView {
        diagnosticsTextView.string = diagnosticsLogText()
        diagnosticsTextView.backgroundColor = PopoverPalette.subtleBackground(for: diagnosticsTextView.effectiveAppearance)
        let logFeed = makeDiagnosticsLogFeed()
        let split = makeDetailSplit(
            sidebar: makeSection(title: "Verification matrix", views: [
                makeTokenRow(title: "Summary", value: diagnosticsMatrixSummary()),
                makeTokenRow(title: "Overlay", value: modeAppliedSummary(.overlay)),
                makeTokenRow(title: "Gamma", value: modeAppliedSummary(.gamma)),
                makeTokenRow(title: "Hotkeys", value: "\(shortcuts.filter(\.isEnabled).count) registered"),
                makeTokenRow(title: "Login item", value: loginItemSummary())
            ]),
            primary: makeSection(title: "Recent diagnostics", views: [
                logFeed
            ])
        )
        return makeDetailPage(
            title: "Diagnostics",
            trailingActions: [
                PopoverCommandButton(title: "Export diagnostics", style: .primary, target: self, action: #selector(exportDiagnosticsPressed))
            ],
            content: split
        )
    }

    private func makeDetailPage(
        title: String,
        trailingActions: [NSView] = [],
        content: NSView
    ) -> NSView {
        let back = PopoverCommandButton(title: "← Back", style: .normal, target: self, action: #selector(backPressed))
        back.identifier = NSUserInterfaceItemIdentifier("app-window-header-action:Back")
        back.setContentHuggingPriority(.required, for: .horizontal)

        let pageTitle = NSTextField(labelWithString: title)
        pageTitle.font = InnosDesignTokens.Font.app(ofSize: 22, weight: .bold)
        pageTitle.textColor = .labelColor
        pageTitle.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = NSStackView(views: [back, pageTitle, spacer()] + trailingActions)
        header.identifier = NSUserInterfaceItemIdentifier("app-window-page-header")
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        trailingActions.forEach { $0.setContentHuggingPriority(.required, for: .horizontal) }

        let stack = NSStackView(views: [header, content])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        [header, content].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func verticalStack(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = spacing
        views.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func makeDetailSplit(sidebar: NSView, primary: NSView) -> NSStackView {
        let split = NSStackView(views: [sidebar, primary])
        split.identifier = NSUserInterfaceItemIdentifier("app-window-detail-split")
        split.orientation = .horizontal
        split.alignment = .top
        split.distribution = .fill
        split.spacing = 12
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        primary.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: Layout.detailSidebarWidth).isActive = true
        primary.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.detailMinimumPrimaryWidth).isActive = true
        return split
    }

    private func makeTokenRow(title: String, value: String) -> NSView {
        let titleLabel = sectionLabel(title)
        titleLabel.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = InnosDesignTokens.Font.bodyEmphasis
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.maximumNumberOfLines = 2
        valueLabel.alignment = .right
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [titleLabel, spacer(), valueLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.tokenRowHeight).isActive = true

        let container = PopoverContainerView(style: .subtle, content: row)
        container.identifier = NSUserInterfaceItemIdentifier("app-window-token-row:\(title)")
        return container
    }

    private func makeDiagnosticsLogFeed() -> NSView {
        let rows: [NSView]
        if events.isEmpty {
            rows = [makeDiagnosticsLogRow(time: "--:--:--", severity: "Info", message: "No diagnostics recorded yet.")]
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            rows = events.reversed().map { event in
                makeDiagnosticsLogRow(
                    time: formatter.string(from: event.timestamp),
                    severity: event.severity.rawValue.capitalized,
                    message: event.message
                )
            }
        }
        let stack = verticalStack(rows, spacing: 8)
        stack.identifier = NSUserInterfaceItemIdentifier("app-window-diagnostics-log-feed")
        return stack
    }

    private func makeDiagnosticsLogRow(time: String, severity: String, message: String) -> NSView {
        let timeLabel = fixedLabel(time, width: 64)
        timeLabel.textColor = .secondaryLabelColor
        let severityLabel = fixedLabel(severity, width: 64)
        severityLabel.textColor = severity.localizedCaseInsensitiveContains("warning")
            ? PopoverPalette.warningColor(for: window?.effectiveAppearance ?? NSApp.effectiveAppearance)
            : .secondaryLabelColor
        let messageLabel = NSTextField(labelWithString: message)
        messageLabel.font = InnosDesignTokens.Font.bodyEmphasis
        messageLabel.textColor = .labelColor
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [timeLabel, severityLabel, messageLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let container = PopoverContainerView(style: .subtle, content: row)
        container.identifier = NSUserInterfaceItemIdentifier("app-window-log-row")
        return container
    }

    private func makeQuickActionsSection() -> NSView {
        makeSection(title: "Quick actions", trailing: makeChip(state.automationPausedUntilNextBoundary ? "Manual" : "Automation active", tone: state.automationPausedUntilNextBoundary ? .warning : .ready), views: [
            makeControlGroup(title: "Brightness", valueLabel: brightnessValueLabel, trackView: brightnessTrackView, decrement: compactButton("-", accessibilityLabel: "Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed)), increment: compactButton("+", accessibilityLabel: "Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))),
            makeSeparator(),
            makeControlGroup(title: "Blue reduction", valueLabel: blueReductionValueLabel, trackView: blueReductionTrackView, decrement: compactButton("-", accessibilityLabel: "Blue reduction down", command: .blueReductionDown, action: #selector(blueReductionDownPressed)), increment: compactButton("+", accessibilityLabel: "Blue reduction up", command: .blueReductionUp, action: #selector(blueReductionUpPressed))),
            makeActionRow([
                button("Disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                button("Restore", command: .restorePrevious, action: #selector(restorePreviousPressed)),
                button(automationActionTitle(), command: automationActionCommand, action: #selector(automationActionPressed))
            ])
        ])
    }

    private func makeNextActionsSection() -> NSView {
        makeSection(title: "Next actions", views: [
            makeListRow(title: "Schedule", value: nextScheduleText(), page: .schedule),
            makeListRow(title: "Diagnostics", value: diagnosticsSummary(), page: .diagnostics),
            makeListRow(title: "Shortcuts", value: "\(shortcuts.filter(\.isEnabled).count) enabled", page: .shortcuts)
        ])
    }

    private func makeNavigationTile(_ page: UnifiedAppWindowPage) -> NSButton {
        let button = AppWindowPageTileButton(page: page, target: self, action: #selector(pageButtonPressed(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(page.title)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.homeTileWidth),
            button.heightAnchor.constraint(equalToConstant: Layout.homeTileHeight)
        ])
        pageButtons[page] = button
        return button
    }

    private func makeListRow(title: String, value: String, page: UnifiedAppWindowPage) -> NSButton {
        let button = PopoverCommandButton(title: "\(title)    \(value)", style: .subtle, target: self, action: #selector(pageButtonPressed(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(page.title)
        button.alignment = .left
        pageButtons[page] = button
        return button
    }

    private func makeSection(title: String, trailing: NSView? = nil, views: [NSView]) -> NSView {
        let titleLabel = sectionLabel(title)
        let titleViews = trailing.map { [titleLabel, spacer(), $0] } ?? [titleLabel]
        let titleRow = NSStackView(views: titleViews)
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        let content = NSStackView(views: [titleRow] + views)
        content.identifier = NSUserInterfaceItemIdentifier("app-window-section:\(title)")
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 10
        ([titleRow] + views).forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        return PopoverContainerView(style: .section, content: content)
    }

    private func makeControlGroup(title: String, valueLabel: NSTextField, trackView: ProgressTrackView, decrement: NSButton, increment: NSButton) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = InnosDesignTokens.Font.bodyEmphasis
        titleLabel.widthAnchor.constraint(equalToConstant: 116).isActive = true
        valueLabel.font = InnosDesignTokens.Font.value
        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
        trackView.heightAnchor.constraint(equalToConstant: 18).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [titleLabel, valueLabel, trackView, decrement, increment])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    private func makeShortcutStack() -> NSStackView {
        ensureShortcutControls()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        let header = NSStackView(views: [
            fixedLabel("Action", width: Layout.shortcutActionWidth),
            fixedLabel("On", width: Layout.shortcutToggleWidth),
            fixedLabel("Opt", width: Layout.shortcutModifierWidth),
            fixedLabel("Shift", width: Layout.shortcutModifierWidth),
            fixedLabel("Ctrl", width: Layout.shortcutModifierWidth),
            fixedLabel("Cmd", width: Layout.shortcutModifierWidth),
            fixedLabel("Key", width: Layout.shortcutKeyWidth)
        ])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        stack.addArrangedSubview(header)
        for action in ShortcutAction.allCases {
            guard let controls = shortcutControls[action] else { continue }
            let row = NSStackView(views: [
                fixedLabel(Self.shortcutActionLabel(for: action), width: Layout.shortcutActionWidth),
                controls.enabled,
                controls.option,
                controls.shift,
                controls.control,
                controls.command,
                controls.keyCode
            ])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 6
            stack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.identifier = NSUserInterfaceItemIdentifier("app-window-shortcuts-table")
        return stack
    }

    private func ensureShortcutControls() {
        guard shortcutControls.isEmpty else { return }
        for action in ShortcutAction.allCases {
            let keyField = ShortcutKeyField()
            keyField.font = InnosDesignTokens.Font.body
            keyField.target = self
            keyField.action = #selector(shortcutControlChanged)
            keyField.translatesAutoresizingMaskIntoConstraints = false
            keyField.widthAnchor.constraint(equalToConstant: Layout.shortcutKeyWidth).isActive = true
            shortcutControls[action] = ShortcutControls(
                enabled: checkbox(width: Layout.shortcutToggleWidth),
                option: checkbox(width: Layout.shortcutModifierWidth),
                shift: checkbox(width: Layout.shortcutModifierWidth),
                control: checkbox(width: Layout.shortcutModifierWidth),
                command: checkbox(width: Layout.shortcutModifierWidth),
                keyCode: keyField
            )
        }
    }

    private func renderShortcuts() {
        ensureShortcutControls()
        for action in ShortcutAction.allCases {
            let binding = shortcuts.first { $0.action == action }
            guard let controls = shortcutControls[action] else { continue }
            controls.enabled.state = binding?.isEnabled == true ? .on : .off
            controls.option.state = binding?.modifiers.contains(.option) == true ? .on : .off
            controls.shift.state = binding?.modifiers.contains(.shift) == true ? .on : .off
            controls.control.state = binding?.modifiers.contains(.control) == true ? .on : .off
            controls.command.state = binding?.modifiers.contains(.command) == true ? .on : .off
            controls.keyCode.setKeyCode(binding?.keyCode)
        }
    }

    private func renderDisplayPicker() {
        displayPicker.removeAllItems()
        displayPicker.addItem(withTitle: "Automatic external display")
        for candidate in displayCandidates {
            displayPicker.addItem(withTitle: candidate.localizedName)
        }
        guard let savedDisplay = snapshot.selectedDisplay,
              let resolved = DisplayTargetResolver.resolve(saved: savedDisplay, candidates: displayCandidates),
              let selectedIndex = displayCandidates.firstIndex(of: resolved) else {
            displayPicker.selectItem(at: 0)
            return
        }
        displayPicker.selectItem(at: selectedIndex + 1)
    }

    private func updateLiveControls() {
        brightnessValueLabel.stringValue = "\(state.targetBrightness)%"
        blueReductionValueLabel.stringValue = "\(state.targetBlueReduction)%"
        brightnessTrackView.fraction = CGFloat(state.targetBrightness) / 100
        blueReductionTrackView.fraction = CGFloat(state.targetBlueReduction) / 100
        automationActionCommand = state.automationPausedUntilNextBoundary ? .resumeAutomation : .pauseAutomation
        modeChip.update(
            title: state.automationPausedUntilNextBoundary ? "Paused" : ModeStatusLabel.title(for: state.activeMode),
            tone: state.automationPausedUntilNextBoundary ? .warning : .ready
        )
        loginChip.update(
            title: "Login item \(loginItemStatus == .enabled ? "on" : "off")",
            tone: loginItemStatus == .enabled ? .ready : .neutral
        )
    }

    private func saveScheduleFromEditor(reportsStatus: Bool) -> Result<SettingsSnapshot, Error> {
        do {
            let editedSchedule = try scheduleEditorView.editedSchedule()
            switch scheduleActions.updateSchedule(editedSchedule) {
            case .success(let updatedSnapshot):
                snapshot = updatedSnapshot
                schedule = updatedSnapshot.schedule
                scheduleEditorView.update(schedule: updatedSnapshot.schedule)
                if reportsStatus { report("Schedule saved.") }
                return .success(updatedSnapshot)
            case .failure(let error):
                if reportsStatus { report(error.localizedDescription, isError: true) }
                return .failure(error)
            }
        } catch {
            if reportsStatus { report(error.localizedDescription, isError: true) }
            return .failure(error)
        }
    }

    private func saveShortcutsFromControls(reportsStatus: Bool) -> Result<SettingsSnapshot, Error> {
        do {
            let editedShortcuts = try shortcutBindingsFromControls()
            switch settingsActions.updateShortcuts(editedShortcuts) {
            case .success(let updatedSnapshot):
                snapshot = updatedSnapshot
                shortcuts = updatedSnapshot.shortcuts
                renderShortcuts()
                if reportsStatus { report("Shortcuts saved.") }
                return .success(updatedSnapshot)
            case .failure(let error):
                if reportsStatus { report(error.localizedDescription, isError: true) }
                return .failure(error)
            }
        } catch {
            if reportsStatus { report(error.localizedDescription, isError: true) }
            return .failure(error)
        }
    }

    private func shortcutBindingsFromControls() throws -> [ShortcutBinding] {
        try ShortcutAction.allCases.map { action in
            guard let controls = shortcutControls[action],
                  let keyCode = controls.keyCode.parsedKeyCode() else {
                throw AppWindowFormError.invalidShortcutKey(action: Self.shortcutActionLabel(for: action))
            }
            return ShortcutBinding(
                action: action,
                keyCode: keyCode,
                modifiers: modifiers(from: controls),
                isEnabled: controls.enabled.state == .on
            )
        }
    }

    private func modifiers(from controls: ShortcutControls) -> ShortcutModifiers {
        var modifiers: ShortcutModifiers = []
        if controls.option.state == .on { modifiers.insert(.option) }
        if controls.shift.state == .on { modifiers.insert(.shift) }
        if controls.control.state == .on { modifiers.insert(.control) }
        if controls.command.state == .on { modifiers.insert(.command) }
        return modifiers
    }

    private func presentDiagnosticsSavePanel(data: Data) {
        guard let window else {
            report("App window is unavailable.", isError: true)
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "innos-diagnostics.json"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self?.report("Diagnostics exported.")
            } catch {
                self?.report(error.localizedDescription, isError: true)
            }
        }
    }

    private func report(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
        statusLabel.isHidden = false
    }

    private func makeActionRow(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }

    private func makeSummaryRow(title: String, value: String) -> NSStackView {
        let titleLabel = fixedLabel(title, width: 112)
        titleLabel.textColor = .secondaryLabelColor
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = InnosDesignTokens.Font.bodyEmphasis
        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.maximumNumberOfLines = 0
        let row = NSStackView(views: [titleLabel, valueLabel])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        return row
    }

    private func makeChip(_ title: String, tone: InnosDesignTokens.Tone) -> InnosStatusChipView {
        InnosStatusChipView(title: title, tone: tone)
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = InnosDesignTokens.Font.sectionTitle
        label.textColor = .secondaryLabelColor
        return label
    }

    private func fixedLabel(_ title: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = InnosDesignTokens.Font.body
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }

    private func checkbox(width: CGFloat) -> NSButton {
        let button = NSButton(checkboxWithTitle: "", target: self, action: #selector(shortcutControlChanged))
        button.font = InnosDesignTokens.Font.body
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        return button
    }

    private func button(_ title: String, command: MenuBarCommand, action: Selector, style: PopoverButtonStyle = .normal) -> NSButton {
        let button = PopoverCommandButton(title: title, style: style, target: self, action: action)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
        commandButtons[command] = button
        return button
    }

    private func compactButton(_ title: String, accessibilityLabel: String, command: MenuBarCommand, action: Selector) -> NSButton {
        let button = button(title, command: command, action: action)
        button.setAccessibilityLabel(accessibilityLabel)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private func currentDisplaySummary() -> String {
        state.display?.localizedName ?? "Automatic external display"
    }

    private func displayModeSummary() -> String {
        let modeTitle = ModeStatusLabel.title(for: state.activeMode)
        guard state.targetBlueReduction > 0 else {
            return modeTitle
        }

        switch state.activeMode {
        case .overlay:
            return "\(modeTitle) + gamma blue reduction"
        case .gamma:
            return "\(modeTitle) blue reduction"
        case .platformBlocked, .unknown:
            return modeTitle
        }
    }

    private func selectedDisplaySummary() -> String {
        snapshot.selectedDisplay?.localizedName ?? "Automatic external display"
    }

    private func resolvedTargetDisplay() -> DisplayIdentity? {
        DisplayTargetResolver.resolve(saved: snapshot.selectedDisplay, candidates: displayCandidates)
            ?? state.display
    }

    private func resolvedDisplaySummary(_ display: DisplayIdentity?) -> String {
        guard let display else {
            return "No active display"
        }
        return "\(display.localizedName) - Display \(display.cgDisplayID)"
    }

    private func mainDisplaySummary(_ display: DisplayIdentity?) -> String {
        guard let display else {
            return "Unavailable"
        }
        return CGDisplayIsMain(display.cgDisplayID) == 1 ? "Yes" : "No"
    }

    private func gammaTableSummary(_ display: DisplayIdentity?) -> String {
        guard display != nil else {
            return "Unavailable until a display resolves"
        }

        switch state.activeMode {
        case .overlay, .gamma:
            return "Supported for blue reduction"
        case .platformBlocked:
            return "Blocked by platform"
        case .unknown:
            return "Available when software dimming starts"
        }
    }

    private func automationActionTitle() -> String {
        state.automationPausedUntilNextBoundary ? "Resume automation" : "Pause automation"
    }

    private func automationSummary() -> String {
        if state.automationPausedUntilNextBoundary, let resumeMinute = state.automationResumeMinuteOfDay {
            return "Paused until \(Self.timeLabel(for: resumeMinute))"
        }
        if state.automationPausedUntilNextBoundary {
            return "Paused until next schedule boundary"
        }
        return "Active"
    }

    private func scheduleSummaryText() -> String {
        SettingsSnapshot.sortedSchedule(schedule)
            .map { "\(Self.timeLabel(for: $0.minuteOfDay)) · \($0.brightness)% / blue \($0.blueReduction)%" }
            .joined(separator: ", ")
    }

    private func nextScheduleText() -> String {
        guard let entry = SettingsSnapshot.sortedSchedule(schedule).first else { return "not configured" }
        return "\(Self.timeLabel(for: entry.minuteOfDay)) · \(entry.brightness)% / blue \(entry.blueReduction)%"
    }

    private func nextScheduleBadgeText() -> String {
        if let resumeMinute = state.automationResumeMinuteOfDay {
            return "Next \(Self.timeLabel(for: resumeMinute))"
        }
        guard let entry = SettingsSnapshot.sortedSchedule(schedule).first else {
            return "No schedule"
        }
        return "Next \(Self.timeLabel(for: entry.minuteOfDay))"
    }

    private func diagnosticsSummary() -> String {
        let warnings = events.filter { $0.severity == .warning }.count
        let errors = events.filter { $0.severity == .error }.count
        if errors == 0, warnings == 0 { return "clear" }
        return errors > 0 ? "\(errors) error(s)" : "\(warnings) warning(s)"
    }

    private func diagnosticsLogText() -> String {
        guard !events.isEmpty else { return "No diagnostics recorded yet." }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return events.reversed().map { event in
            "[\(formatter.string(from: event.timestamp))] \(event.severity.rawValue.uppercased()) \(event.category.rawValue): \(event.message)"
        }.joined(separator: "\n")
    }

    private func diagnosticsMatrixSummary() -> String {
        let handledSummary = VerificationMatrix.summary(for: VerificationMatrix.defaultRows)
        let blocked = VerificationMatrix.defaultRows.filter { $0.status == .fail }.count
        return "\(handledSummary) · handled checks · \(blocked) blocked"
    }

    private func modeAppliedSummary(_ mode: DimmingMode) -> String {
        state.activeMode == mode ? "Applied" : "Available"
    }

    private func loginItemSummary() -> String {
        switch loginItemStatus {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notRegistered:
            return "Not registered"
        case .unsupported(let reason):
            return "Unsupported (\(reason))"
        }
    }

    private func loginItemApprovalSummary() -> String {
        switch loginItemStatus {
        case .requiresApproval:
            return "Approval required in System Settings"
        case .enabled:
            return "Enabled"
        case .disabled, .notRegistered:
            return "No approval pending"
        case .unsupported(let reason):
            return "Unsupported: \(reason)"
        }
    }

    private static func shortcutActionLabel(for action: ShortcutAction) -> String {
        switch action {
        case .brightnessUp:
            return "Brightness up"
        case .brightnessDown:
            return "Brightness down"
        case .blueReductionUp:
            return "Blue reduction up"
        case .blueReductionDown:
            return "Blue reduction down"
        case .quickDisableOverlay:
            return "Quick disable overlay"
        case .restorePreviousDimming:
            return "Restore previous dimming"
        case .openPopover:
            return "Open popover"
        }
    }

    private static func percent(from fraction: CGFloat) -> Int {
        Clamped.percent(Int((fraction * 100).rounded()))
    }

    private func selectedDisplayFromPicker() -> DisplayIdentity? {
        let selectedIndex = displayPicker.indexOfSelectedItem - 1
        return displayCandidates.indices.contains(selectedIndex) ? displayCandidates[selectedIndex] : nil
    }

    private func saveSelectedDisplaySelection(_ display: DisplayIdentity?, successMessage: String) {
        switch settingsActions.selectDisplay(display) {
        case .success(let updatedSnapshot):
            snapshot = updatedSnapshot
            report(successMessage)
            renderActivePage()
        case .failure(let error):
            report(error.localizedDescription, isError: true)
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    @objc private func pageButtonPressed(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let page = pageButtons.first(where: { $0.key.title == identifier })?.key else { return }
        activePage = page
        renderActivePage()
    }

    @objc private func backPressed() {
        activePage = .home
        renderActivePage()
    }

    @objc private func brightnessDownPressed() { actions.perform(.brightnessDown) }
    @objc private func brightnessUpPressed() { actions.perform(.brightnessUp) }
    @objc private func blueReductionDownPressed() { actions.perform(.blueReductionDown) }
    @objc private func blueReductionUpPressed() { actions.perform(.blueReductionUp) }
    @objc private func quickDisablePressed() { actions.perform(.quickDisable) }
    @objc private func restorePreviousPressed() { actions.perform(.restorePrevious) }
    @objc private func automationActionPressed() { actions.perform(automationActionCommand) }
    @objc private func openAppWindowPressed() { actions.perform(.openAppWindow) }
    @objc private func openSettingsPressed() { actions.perform(.openSettings) }
    @objc private func refreshDisplaysPressed() {
        renderActivePage()
        report("Display list refreshed.")
    }
    @objc private func saveSchedulePressed() { _ = saveScheduleFromEditor(reportsStatus: true) }
    @objc private func shortcutControlChanged() { report("Shortcut changes are ready to save.") }
    @objc private func saveShortcutsPressed() { _ = saveShortcutsFromControls(reportsStatus: true) }
    @objc private func resetShortcutsPressed() {
        switch settingsActions.updateShortcuts(ShortcutBinding.defaultBindings) {
        case .success(let updatedSnapshot):
            snapshot = updatedSnapshot
            shortcuts = updatedSnapshot.shortcuts
            renderShortcuts()
            report("Shortcuts reset.")
        case .failure(let error):
            report(error.localizedDescription, isError: true)
        }
    }
    @objc private func saveDisplayPressed() {
        saveSelectedDisplaySelection(selectedDisplayFromPicker(), successMessage: "Display saved.")
    }
    @objc private func useAutomaticDisplayPressed() {
        displayPicker.selectItem(at: 0)
        saveSelectedDisplaySelection(nil, successMessage: "Automatic display selection saved.")
    }
    @objc private func displaySelectionChanged() {
        saveSelectedDisplaySelection(selectedDisplayFromPicker(), successMessage: "Settings saved.")
    }
    @objc private func loginItemToggled() {
        switch settingsActions.setLaunchAtLogin(loginItemCheckbox.state == .on) {
        case .success(let updatedStatus):
            loginItemStatus = updatedStatus
            report("Launch at login updated.")
            renderActivePage()
        case .failure(let error):
            report(error.localizedDescription, isError: true)
            renderActivePage()
        }
    }
    @objc private func exportDiagnosticsPressed() {
        switch settingsActions.exportDiagnostics() {
        case .success(let data):
            presentDiagnosticsSavePanel(data: data)
        case .failure(let error):
            report(error.localizedDescription, isError: true)
        }
    }
}

private extension NSView {
    @MainActor
    func appWindowIdentifiersForTesting() -> [String] {
        var identifiers: [String] = []
        if let identifier {
            identifiers.append(identifier.rawValue)
        }
        for subview in subviews {
            identifiers.append(contentsOf: subview.appWindowIdentifiersForTesting())
        }
        return identifiers
    }

    @MainActor
    func appWindowVisibleTextForTesting() -> [String] {
        var text: [String] = []
        if !isHidden {
            if let label = self as? NSTextField {
                text.append(label.stringValue)
            }
            if let button = self as? NSButton {
                text.append(button.title)
            }
            if let popup = self as? NSPopUpButton {
                text.append(contentsOf: popup.itemArray.map(\.title))
            }
            if let textView = self as? NSTextView {
                text.append(textView.string)
            }
            for subview in subviews {
                text.append(contentsOf: subview.appWindowVisibleTextForTesting())
            }
        }
        return text
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
