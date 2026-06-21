import AppKit

enum ScheduleEditorError: LocalizedError, Equatable {
    case invalidTime(row: Int)
    case invalidPercent(row: Int, field: String)

    var errorDescription: String? {
        switch self {
        case .invalidTime(let row):
            return "Schedule row \(row) needs a time in HH:mm format."
        case .invalidPercent(let row, let field):
            return "Schedule row \(row) needs \(field) from 0 to 100."
        }
    }
}

@MainActor
final class ScheduleEditorView: NSView, NSTextFieldDelegate {
    private enum Layout {
        static let timeFieldWidth: CGFloat = 64
        static let metricCellWidth: CGFloat = 210
        static let percentFieldWidth: CGFloat = 38
        static let stepButtonWidth: CGFloat = 24
        static let trackMinWidth: CGFloat = 86
        static let rowSpacing: CGFloat = 8
        static let columnSpacing: CGFloat = 10
        static let controlSpacing: CGFloat = 0
        static let fieldHeight: CGFloat = 26
    }

    private enum MetricField {
        case brightness
        case blueReduction

        var accessibilityTitle: String {
            switch self {
            case .brightness:
                return "Brightness"
            case .blueReduction:
                return "Blue reduction"
            }
        }
    }

    private final class SchedulePercentField: NSTextField {
        let rowIndex: Int
        let metric: MetricField

        init(rowIndex: Int, metric: MetricField) {
            self.rowIndex = rowIndex
            self.metric = metric
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }
    }

    private final class SchedulePercentTrackView: NSView {
        var onUserFractionChange: ((CGFloat) -> Void)?

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

        func simulateUserFractionChangeForTesting(_ fraction: CGFloat) {
            updateFromUserFraction(fraction)
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

        private func updateFromEvent(_ event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            updateFromUserFraction(location.x / max(bounds.width, 1))
        }

        private func updateFromUserFraction(_ newFraction: CGFloat) {
            fraction = newFraction
            onUserFractionChange?(fraction)
        }
    }

    private final class ScheduleStepButton: NSButton {
        let rowIndex: Int
        let metric: MetricField
        let delta: Int

        init(title: String, rowIndex: Int, metric: MetricField, delta: Int, target: AnyObject?, action: Selector?) {
            self.rowIndex = rowIndex
            self.metric = metric
            self.delta = delta
            super.init(frame: .zero)
            self.title = title
            self.target = target
            self.action = action
            bezelStyle = .rounded
            controlSize = .small
            font = InnosDesignTokens.Font.buttonLabel
            setButtonType(.momentaryPushIn)
            translatesAutoresizingMaskIntoConstraints = false
            widthAnchor.constraint(equalToConstant: Layout.stepButtonWidth).isActive = true
            heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
            setAccessibilityLabel("\(metric.accessibilityTitle) row \(rowIndex + 1) \(delta < 0 ? "down" : "up")")
        }

        required init?(coder: NSCoder) {
            nil
        }
    }

    private struct RowControls {
        var time: NSTextField
        var brightnessValue: SchedulePercentField
        var brightnessTrack: SchedulePercentTrackView
        var blueReductionValue: SchedulePercentField
        var blueReductionTrack: SchedulePercentTrackView
    }

    private let rowCount: Int
    private var rows: [RowControls] = []

    init(rowCount: Int = 3) {
        self.rowCount = rowCount
        super.init(frame: .zero)
        installContent()
        update(schedule: ScheduleEntry.defaultSchedule)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(schedule: [ScheduleEntry]) {
        let sortedEntries = SettingsSnapshot.sortedSchedule(schedule)
        for index in 0..<rows.count {
            let entry = index < sortedEntries.count ? sortedEntries[index] : Self.defaultEntry(for: index)
            let row = rows[index]
            row.time.stringValue = Self.timeLabel(for: entry.minuteOfDay)
            setPercent(entry.brightness, rowIndex: index, metric: .brightness)
            setPercent(entry.blueReduction, rowIndex: index, metric: .blueReduction)
        }
    }

    func editedSchedule() throws -> [ScheduleEntry] {
        let editedEntries = try rows.enumerated().map { index, row in
            guard let minuteOfDay = Self.minuteOfDay(from: row.time.stringValue) else {
                throw ScheduleEditorError.invalidTime(row: index + 1)
            }
            guard let brightness = Self.percentValue(from: row.brightnessValue.stringValue) else {
                throw ScheduleEditorError.invalidPercent(row: index + 1, field: "brightness")
            }
            guard let blueReduction = Self.percentValue(from: row.blueReductionValue.stringValue) else {
                throw ScheduleEditorError.invalidPercent(row: index + 1, field: "blue reduction")
            }

            return ScheduleEntry(minuteOfDay: minuteOfDay, brightness: brightness, blueReduction: blueReduction)
        }
        return SettingsSnapshot.sortedSchedule(editedEntries)
    }

    func setRowForTesting(index: Int, time: String, brightness: String, blueReduction: String) {
        guard rows.indices.contains(index) else {
            return
        }

        rows[index].time.stringValue = time
        rows[index].brightnessValue.stringValue = brightness
        rows[index].blueReductionValue.stringValue = blueReduction
        syncTrackFromText(rowIndex: index, metric: .brightness)
        syncTrackFromText(rowIndex: index, metric: .blueReduction)
    }

    func stepBrightnessForTesting(index: Int, delta: Int) {
        adjustPercent(rowIndex: index, metric: .brightness, delta: delta)
    }

    func stepBlueReductionForTesting(index: Int, delta: Int) {
        adjustPercent(rowIndex: index, metric: .blueReduction, delta: delta)
    }

    func simulateBrightnessTrackChangeForTesting(index: Int, percent: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].brightnessTrack.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func simulateBlueReductionTrackChangeForTesting(index: Int, percent: Int) {
        guard rows.indices.contains(index) else { return }
        rows[index].blueReductionTrack.simulateUserFractionChangeForTesting(CGFloat(Clamped.percent(percent)) / 100)
    }

    func rowValuesForTesting(index: Int) -> (time: String, brightness: String, blueReduction: String)? {
        guard rows.indices.contains(index) else {
            return nil
        }
        return (
            rows[index].time.stringValue,
            rows[index].brightnessValue.stringValue,
            rows[index].blueReductionValue.stringValue
        )
    }

    func trackFractionsForTesting(index: Int) -> (brightness: CGFloat, blueReduction: CGFloat)? {
        guard rows.indices.contains(index) else {
            return nil
        }
        return (
            rows[index].brightnessTrack.fraction,
            rows[index].blueReductionTrack.fraction
        )
    }

    private func installContent() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Layout.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [
            fixedLabel("Time", width: Layout.timeFieldWidth),
            fixedLabel("Bright", width: Layout.metricCellWidth),
            fixedLabel("Blue", width: Layout.metricCellWidth)
        ])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = Layout.columnSpacing
        stack.addArrangedSubview(header)

        for index in 0..<rowCount {
            let controls = RowControls(
                time: editableField(width: Layout.timeFieldWidth),
                brightnessValue: percentField(rowIndex: index, metric: .brightness),
                brightnessTrack: percentTrack(rowIndex: index, metric: .brightness),
                blueReductionValue: percentField(rowIndex: index, metric: .blueReduction),
                blueReductionTrack: percentTrack(rowIndex: index, metric: .blueReduction)
            )
            rows.append(controls)

            let row = NSStackView(views: [
                controls.time,
                metricCell(
                    valueField: controls.brightnessValue,
                    track: controls.brightnessTrack,
                    rowIndex: index,
                    metric: .brightness
                ),
                metricCell(
                    valueField: controls.blueReductionValue,
                    track: controls.blueReductionTrack,
                    rowIndex: index,
                    metric: .blueReduction
                )
            ])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fill
            row.spacing = Layout.columnSpacing
            row.setAccessibilityLabel("Schedule row \(index + 1)")
            stack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func fixedLabel(_ title: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = InnosDesignTokens.Font.app(ofSize: 12, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }

    private func editableField(width: CGFloat) -> NSTextField {
        let field = NSTextField(string: "")
        field.font = InnosDesignTokens.Font.app(ofSize: 13)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.fieldHeight).isActive = true
        field.setAccessibilityLabel("Schedule time")
        return field
    }

    private func percentField(rowIndex: Int, metric: MetricField) -> SchedulePercentField {
        let field = SchedulePercentField(rowIndex: rowIndex, metric: metric)
        field.font = InnosDesignTokens.Font.app(ofSize: 13, weight: .semibold)
        field.alignment = .right
        field.delegate = self
        field.target = self
        field.action = #selector(percentFieldChanged(_:))
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: Layout.percentFieldWidth).isActive = true
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.fieldHeight).isActive = true
        field.setAccessibilityLabel("\(metric.accessibilityTitle) row \(rowIndex + 1) value")
        return field
    }

    private func percentTrack(rowIndex: Int, metric: MetricField) -> SchedulePercentTrackView {
        let track = SchedulePercentTrackView(frame: .zero)
        track.translatesAutoresizingMaskIntoConstraints = false
        track.heightAnchor.constraint(equalToConstant: InnosDesignTokens.Size.trackHeight).isActive = true
        track.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.trackMinWidth).isActive = true
        track.setContentHuggingPriority(.defaultLow, for: .horizontal)
        track.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        track.setAccessibilityLabel("\(metric.accessibilityTitle) row \(rowIndex + 1) track")
        track.onUserFractionChange = { [weak self] fraction in
            self?.setPercent(Self.percent(from: fraction), rowIndex: rowIndex, metric: metric)
        }
        return track
    }

    private func metricCell(
        valueField: SchedulePercentField,
        track: SchedulePercentTrackView,
        rowIndex: Int,
        metric: MetricField
    ) -> NSView {
        let decrement = ScheduleStepButton(
            title: "-",
            rowIndex: rowIndex,
            metric: metric,
            delta: -1,
            target: self,
            action: #selector(stepButtonPressed(_:))
        )
        let increment = ScheduleStepButton(
            title: "+",
            rowIndex: rowIndex,
            metric: metric,
            delta: 1,
            target: self,
            action: #selector(stepButtonPressed(_:))
        )
        let stepper = NSStackView(views: [decrement, increment])
        stepper.orientation = .horizontal
        stepper.spacing = Layout.controlSpacing
        stepper.setContentHuggingPriority(.required, for: .horizontal)
        stepper.setContentCompressionResistancePriority(.required, for: .horizontal)

        let cell = NSStackView(views: [valueField, track, stepper])
        cell.orientation = .horizontal
        cell.alignment = .centerY
        cell.spacing = Layout.controlSpacing
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.metricCellWidth).isActive = true
        cell.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cell.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cell.setAccessibilityLabel("\(metric.accessibilityTitle) row \(rowIndex + 1)")
        return cell
    }

    @objc private func percentFieldChanged(_ sender: NSTextField) {
        guard let field = sender as? SchedulePercentField else {
            return
        }
        syncTrackFromText(rowIndex: field.rowIndex, metric: field.metric)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? SchedulePercentField else {
            return
        }
        syncTrackFromText(rowIndex: field.rowIndex, metric: field.metric)
    }

    @objc private func stepButtonPressed(_ sender: NSButton) {
        guard let button = sender as? ScheduleStepButton else {
            return
        }
        adjustPercent(rowIndex: button.rowIndex, metric: button.metric, delta: button.delta)
    }

    private func adjustPercent(rowIndex: Int, metric: MetricField, delta: Int) {
        guard rows.indices.contains(rowIndex) else {
            return
        }

        let row = rows[rowIndex]
        let field = valueField(for: row, metric: metric)
        let track = trackView(for: row, metric: metric)
        let current = Self.percentValue(from: field.stringValue)
            ?? Self.percent(from: track.fraction)
        setPercent(current + delta, rowIndex: rowIndex, metric: metric)
    }

    private func setPercent(_ value: Int, rowIndex: Int, metric: MetricField) {
        guard rows.indices.contains(rowIndex) else {
            return
        }

        let percent = Clamped.percent(value)
        let row = rows[rowIndex]
        valueField(for: row, metric: metric).stringValue = "\(percent)"
        trackView(for: row, metric: metric).fraction = CGFloat(percent) / 100
    }

    private func syncTrackFromText(rowIndex: Int, metric: MetricField) {
        guard rows.indices.contains(rowIndex) else {
            return
        }

        let row = rows[rowIndex]
        guard let percent = Self.percentValue(from: valueField(for: row, metric: metric).stringValue) else {
            return
        }
        trackView(for: row, metric: metric).fraction = CGFloat(percent) / 100
    }

    private func valueField(for row: RowControls, metric: MetricField) -> SchedulePercentField {
        switch metric {
        case .brightness:
            return row.brightnessValue
        case .blueReduction:
            return row.blueReductionValue
        }
    }

    private func trackView(for row: RowControls, metric: MetricField) -> SchedulePercentTrackView {
        switch metric {
        case .brightness:
            return row.brightnessTrack
        case .blueReduction:
            return row.blueReductionTrack
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func defaultEntry(for index: Int) -> ScheduleEntry {
        ScheduleEntry.defaultSchedule.indices.contains(index)
            ? ScheduleEntry.defaultSchedule[index]
            : ScheduleEntry.defaultSchedule.last ?? ScheduleEntry(minuteOfDay: 0, brightness: 100, blueReduction: 0)
    }

    private static func minuteOfDay(from label: String) -> Int? {
        let parts = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return hour * 60 + minute
    }

    private static func percentValue(from label: String) -> Int? {
        var value = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix("%") {
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let percent = Int(value), (0...100).contains(percent) else {
            return nil
        }
        return percent
    }

    private static func percent(from fraction: CGFloat) -> Int {
        Clamped.percent(Int((fraction * 100).rounded()))
    }
}
