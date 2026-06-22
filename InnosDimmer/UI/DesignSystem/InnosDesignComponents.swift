import AppKit

enum InnosSectionStyle {
    case section
    case subtle
}

@MainActor
final class InnosSectionView: NSView {
    private let style: InnosSectionStyle
    private let content: NSView

    init(style: InnosSectionStyle = .section, content: NSView) {
        self.style = style
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = InnosDesignTokens.Radius.section
        layer?.borderWidth = 1

        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: InnosDesignTokens.Spacing.sectionPadding),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -InnosDesignTokens.Spacing.sectionPadding),
            content.topAnchor.constraint(equalTo: topAnchor, constant: InnosDesignTokens.Spacing.sectionPadding),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -InnosDesignTokens.Spacing.sectionPadding)
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
        switch style {
        case .section:
            layer?.backgroundColor = InnosDesignTokens.surfaceSection(for: effectiveAppearance).cgColor
        case .subtle:
            layer?.backgroundColor = InnosDesignTokens.surfaceSubtle(for: effectiveAppearance).cgColor
        }
        layer?.borderColor = InnosDesignTokens.border(for: effectiveAppearance).cgColor
    }
}

@MainActor
final class InnosStatusChipView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var tone: InnosDesignTokens.Tone

    init(title: String, tone: InnosDesignTokens.Tone = .neutral) {
        self.tone = tone
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = InnosDesignTokens.Radius.chip
        layer?.borderWidth = 1

        label.stringValue = title
        label.font = InnosDesignTokens.Font.chip
        label.alignment = .center
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            heightAnchor.constraint(greaterThanOrEqualToConstant: InnosDesignTokens.Size.chipMinHeight)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityLabel(title)
        updateColors()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func update(title: String, tone: InnosDesignTokens.Tone) {
        label.stringValue = title
        setAccessibilityLabel(title)
        self.tone = tone
        updateColors()
        invalidateIntrinsicContentSize()
    }

    private func updateColors() {
        label.textColor = InnosDesignTokens.foreground(for: tone, appearance: effectiveAppearance)
        layer?.backgroundColor = InnosDesignTokens.background(for: tone, appearance: effectiveAppearance).cgColor
        layer?.borderColor = InnosDesignTokens.border(for: tone, appearance: effectiveAppearance).cgColor
    }
}

@MainActor
final class InnosCommandButton: NSButton {
    private let tone: InnosDesignTokens.Tone

    init(title: String, tone: InnosDesignTokens.Tone = .neutral, target: AnyObject?, action: Selector?) {
        self.tone = tone
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        wantsLayer = true
        font = InnosDesignTokens.Font.button
        controlSize = .regular
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: InnosDesignTokens.Size.buttonMinHeight).isActive = true
        setAccessibilityLabel(title)
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
        contentTintColor = InnosDesignTokens.foreground(for: tone, appearance: effectiveAppearance)
        layer?.cornerRadius = InnosDesignTokens.Radius.control
        layer?.borderWidth = 1
        layer?.backgroundColor = InnosDesignTokens.background(for: tone, appearance: effectiveAppearance).cgColor
        layer?.borderColor = InnosDesignTokens.border(for: tone, appearance: effectiveAppearance).cgColor
    }
}

@MainActor
final class InnosDimmingTrackView: NSView {
    var fraction: CGFloat = 0 {
        didSet {
            fraction = min(1, max(0, fraction))
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: InnosDesignTokens.Size.trackHeight)
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
        let barHeight = InnosDesignTokens.Size.trackBarHeight
        let rect = bounds.insetBy(dx: 0, dy: max(0, (bounds.height - barHeight) / 2))
        let radius = rect.height / 2

        InnosDesignTokens.trackBackground(for: effectiveAppearance).setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        if fraction > 0 {
            var fillRect = rect
            fillRect.size.width = max(rect.height, rect.width * fraction)
            InnosDesignTokens.accent(for: effectiveAppearance).setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
        }

        let thumbDiameter = InnosDesignTokens.Size.trackThumbDiameter
        let thumbX = rect.minX + (rect.width * fraction) - (thumbDiameter / 2)
        let clampedThumbX = min(max(thumbX, rect.minX), rect.maxX - thumbDiameter)
        let thumbRect = NSRect(
            x: clampedThumbX,
            y: bounds.midY - (thumbDiameter / 2),
            width: thumbDiameter,
            height: thumbDiameter
        )
        InnosDesignTokens.accent(for: effectiveAppearance).setFill()
        NSBezierPath(ovalIn: thumbRect).fill()
        InnosDesignTokens.surfaceSection(for: effectiveAppearance).setStroke()
        NSBezierPath(ovalIn: thumbRect).stroke()
    }
}

@MainActor
final class InnosDimmingControlGroupView: NSStackView {
    let valueLabel = NSTextField(labelWithString: "")
    let trackView = InnosDimmingTrackView()
    let decrementButton: InnosCommandButton
    let incrementButton: InnosCommandButton

    init(
        title: String,
        value: String,
        fraction: CGFloat,
        decrementAction: Selector?,
        incrementAction: Selector?,
        target: AnyObject?
    ) {
        decrementButton = InnosCommandButton(title: "-", target: target, action: decrementAction)
        incrementButton = InnosCommandButton(title: "+", target: target, action: incrementAction)
        super.init(frame: .zero)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = InnosDesignTokens.Font.bodyEmphasis
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: InnosDesignTokens.Size.dimmingLabelWidth).isActive = true

        valueLabel.stringValue = value
        valueLabel.font = InnosDesignTokens.Font.value
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: InnosDesignTokens.Size.dimmingValueWidth).isActive = true

        trackView.fraction = fraction
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.heightAnchor.constraint(equalToConstant: InnosDesignTokens.Size.trackHeight).isActive = true
        trackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        [decrementButton, incrementButton].forEach { button in
            button.widthAnchor.constraint(equalToConstant: InnosDesignTokens.Size.iconButton).isActive = true
            button.heightAnchor.constraint(equalToConstant: InnosDesignTokens.Size.buttonMinHeight).isActive = true
        }

        setViews([titleLabel, valueLabel, trackView, decrementButton, incrementButton], in: .leading)
        orientation = .horizontal
        alignment = .centerY
        spacing = InnosDesignTokens.Spacing.rowGap
        setAccessibilityLabel("\(title) \(value)")
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct InnosSummaryTableEntry: Equatable {
    var title: String
    var value: String
}

final class InnosSummaryTableView: NSView {
    private var separators: [NSView] = []

    init(entries: [InnosSummaryTableEntry], identifier: NSUserInterfaceItemIdentifier? = nil) {
        super.init(frame: .zero)
        self.identifier = identifier
        wantsLayer = true
        layer?.cornerRadius = InnosDesignTokens.Radius.control
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for (index, entry) in entries.enumerated() {
            if index > 0 {
                let separatorView = separator()
                separators.append(separatorView)
                stack.addArrangedSubview(separatorView)
            }
            let row = InnosSummaryTableRowView(entry: entry)
            row.identifier = rowIdentifier(for: entry, tableIdentifier: identifier)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        layer?.backgroundColor = InnosDesignTokens.surfaceSubtle(for: effectiveAppearance).cgColor
        layer?.borderColor = InnosDesignTokens.border(for: effectiveAppearance).cgColor
        separators.forEach {
            $0.layer?.backgroundColor = InnosDesignTokens.border(for: effectiveAppearance).cgColor
        }
    }

    private func separator() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        view.wantsLayer = true
        view.layer?.backgroundColor = InnosDesignTokens.border(for: effectiveAppearance).cgColor
        return view
    }

    private func rowIdentifier(
        for entry: InnosSummaryTableEntry,
        tableIdentifier: NSUserInterfaceItemIdentifier?
    ) -> NSUserInterfaceItemIdentifier {
        let tableName = tableIdentifier?.rawValue ?? "Summary"
        return NSUserInterfaceItemIdentifier("\(tableName):\(entry.title)")
    }
}

private final class InnosSummaryTableRowView: NSView {
    init(entry: InnosSummaryTableEntry) {
        super.init(frame: .zero)

        let titleLabel = NSTextField(labelWithString: entry.title)
        titleLabel.font = InnosDesignTokens.Font.bodyEmphasis
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: InnosDesignTokens.Size.summaryLabelWidth).isActive = true

        let valueLabel = NSTextField(wrappingLabelWithString: entry.value)
        valueLabel.font = InnosDesignTokens.Font.bodyEmphasis
        valueLabel.textColor = .labelColor
        valueLabel.maximumNumberOfLines = 0

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = InnosDesignTokens.Spacing.rowGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: InnosDesignTokens.Spacing.sectionPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -InnosDesignTokens.Spacing.sectionPadding),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: InnosDesignTokens.Spacing.rowGap),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -InnosDesignTokens.Spacing.rowGap),
            heightAnchor.constraint(greaterThanOrEqualToConstant: InnosDesignTokens.Size.buttonMinHeight + 4)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
enum InnosComponentFactory {
    static func section(title: String, trailing: NSView? = nil, views: [NSView], style: InnosSectionStyle = .section) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = InnosDesignTokens.Font.sectionTitle
        titleLabel.textColor = .secondaryLabelColor

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = InnosDesignTokens.Spacing.rowGap
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(spacer())
        if let trailing {
            header.addArrangedSubview(trailing)
        }

        let stack = NSStackView(views: [header] + views)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = InnosDesignTokens.Spacing.rowGap
        return InnosSectionView(style: style, content: stack)
    }

    static func actionRow(_ buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = InnosDesignTokens.Spacing.rowGap
        return stack
    }

    static func summaryRow(title: String, value: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = InnosDesignTokens.Font.bodyEmphasis
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: InnosDesignTokens.Size.summaryLabelWidth).isActive = true

        let valueLabel = NSTextField(wrappingLabelWithString: value)
        valueLabel.font = InnosDesignTokens.Font.body

        let row = NSStackView(views: [titleLabel, valueLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = InnosDesignTokens.Spacing.rowGap
        return row
    }

    static func summaryTable(entries: [InnosSummaryTableEntry], identifier: String) -> NSView {
        InnosSummaryTableView(
            entries: entries,
            identifier: NSUserInterfaceItemIdentifier("app-window-summary-table:\(identifier)")
        )
    }

    private static func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
}
