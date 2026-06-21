import AppKit

struct ScheduleEditorActions {
    var updateSchedule: @MainActor ([ScheduleEntry]) -> Result<SettingsSnapshot, Error>

    static let noop = ScheduleEditorActions(
        updateSchedule: { _ in .success(.defaultSnapshot()) }
    )
}

@MainActor
final class ScheduleEditorWindowController: NSWindowController {
    private let scheduleEditorView = ScheduleEditorView()
    private let statusLabel = NSTextField(labelWithString: "Schedule editor ready.")
    private let actions: ScheduleEditorActions
    private var schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule

    init(actions: ScheduleEditorActions = .noop) {
        self.actions = actions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer Schedule"
        super.init(window: window)
        installContent()
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(schedule: [ScheduleEntry]) {
        self.schedule = schedule
        render()
    }

    func scheduleSummaryForTesting() -> String {
        (try? scheduleEditorView.editedSchedule())
            .map(Self.scheduleSummary)
            ?? ""
    }

    private func installContent() {
        let title = NSTextField(labelWithString: "InnosDimmer Schedule")
        title.font = InnosDesignTokens.Font.app(ofSize: 20, weight: .bold)
        title.textColor = .labelColor

        let subtitle = NSTextField(labelWithString: "Focused editor shell for the current automation schedule.")
        subtitle.font = InnosDesignTokens.Font.body
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 0

        statusLabel.font = InnosDesignTokens.Font.bodySmall
        statusLabel.textColor = .secondaryLabelColor

        let saveButton = NSButton(title: "Save schedule", target: self, action: #selector(saveSchedulePressed))
        saveButton.bezelStyle = .rounded
        saveButton.font = InnosDesignTokens.Font.buttonLabel
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closePressed))
        closeButton.bezelStyle = .rounded
        closeButton.font = InnosDesignTokens.Font.buttonLabel
        let buttonRow = NSStackView(views: [saveButton, closeButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let content = NSStackView(views: [
            title,
            subtitle,
            makeSection(title: "Current schedule", content: scheduleEditorView),
            buttonRow,
            statusLabel
        ])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        window?.contentView = root
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20)
        ])
    }

    private func makeSection(title: String, content: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.font = InnosDesignTokens.Font.sectionLabel
        titleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, content])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        return stack
    }

    private func render() {
        scheduleEditorView.update(schedule: schedule)
    }

    @objc private func saveSchedulePressed() {
        _ = saveScheduleFromEditor(reportsStatus: true)
    }

    @objc private func closePressed() {
        close()
    }

    @discardableResult
    func saveScheduleForTesting() -> Result<SettingsSnapshot, Error> {
        saveScheduleFromEditor(reportsStatus: false)
    }

    private func saveScheduleFromEditor(reportsStatus: Bool) -> Result<SettingsSnapshot, Error> {
        do {
            let editedSchedule = try scheduleEditorView.editedSchedule()
            switch actions.updateSchedule(editedSchedule) {
            case .success(let snapshot):
                schedule = snapshot.schedule
                render()
                if reportsStatus {
                    report("Schedule saved.")
                }
                return .success(snapshot)
            case .failure(let error):
                if reportsStatus {
                    report(error.localizedDescription, isError: true)
                }
                return .failure(error)
            }
        } catch {
            if reportsStatus {
                report(error.localizedDescription, isError: true)
            }
            return .failure(error)
        }
    }

    func setScheduleRowForTesting(index: Int, time: String, brightness: String, blueReduction: String) {
        scheduleEditorView.setRowForTesting(
            index: index,
            time: time,
            brightness: brightness,
            blueReduction: blueReduction
        )
    }

    private func report(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private static func scheduleSummary(for schedule: [ScheduleEntry]) -> String {
        let labels = SettingsSnapshot.sortedSchedule(schedule).map { entry in
            "\(Self.timeLabel(for: entry.minuteOfDay)) · \(entry.brightness)% brightness / \(entry.blueReduction)% warmth"
        }
        return labels.isEmpty ? "Not configured" : labels.joined(separator: "\n")
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
