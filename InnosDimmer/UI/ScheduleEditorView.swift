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
final class ScheduleEditorView: NSView {
    private enum Layout {
        static let fieldWidth: CGFloat = 72
        static let rowSpacing: CGFloat = 8
        static let columnSpacing: CGFloat = 8
    }

    private struct RowControls {
        var time: NSTextField
        var brightness: NSTextField
        var blueReduction: NSTextField
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
            row.brightness.stringValue = "\(entry.brightness)"
            row.blueReduction.stringValue = "\(entry.blueReduction)"
        }
    }

    func editedSchedule() throws -> [ScheduleEntry] {
        try rows.enumerated().map { index, row in
            guard let minuteOfDay = Self.minuteOfDay(from: row.time.stringValue) else {
                throw ScheduleEditorError.invalidTime(row: index + 1)
            }
            guard let brightness = Int(row.brightness.stringValue), (0...100).contains(brightness) else {
                throw ScheduleEditorError.invalidPercent(row: index + 1, field: "brightness")
            }
            guard let blueReduction = Int(row.blueReduction.stringValue), (0...100).contains(blueReduction) else {
                throw ScheduleEditorError.invalidPercent(row: index + 1, field: "blue reduction")
            }

            return ScheduleEntry(minuteOfDay: minuteOfDay, brightness: brightness, blueReduction: blueReduction)
        }
    }

    func setRowForTesting(index: Int, time: String, brightness: String, blueReduction: String) {
        guard rows.indices.contains(index) else {
            return
        }

        rows[index].time.stringValue = time
        rows[index].brightness.stringValue = brightness
        rows[index].blueReduction.stringValue = blueReduction
    }

    private func installContent() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [
            fixedLabel("Time"),
            fixedLabel("Brightness"),
            fixedLabel("Blue")
        ])
        header.orientation = .horizontal
        header.spacing = Layout.columnSpacing
        stack.addArrangedSubview(header)

        for _ in 0..<rowCount {
            let controls = RowControls(
                time: editableField(),
                brightness: editableField(),
                blueReduction: editableField()
            )
            rows.append(controls)

            let row = NSStackView(views: [controls.time, controls.brightness, controls.blueReduction])
            row.orientation = .horizontal
            row.spacing = Layout.columnSpacing
            stack.addArrangedSubview(row)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func fixedLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: Layout.fieldWidth).isActive = true
        return label
    }

    private func editableField() -> NSTextField {
        let field = NSTextField(string: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: Layout.fieldWidth).isActive = true
        return field
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
}
