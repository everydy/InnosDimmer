import AppKit

@MainActor
final class ScheduleEditorWindowController: NSWindowController {
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "Schedule editor ready.")
    private var schedule: [ScheduleEntry] = ScheduleEntry.defaultSchedule

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
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
        scheduleSummaryLabel.stringValue
    }

    private func installContent() {
        let title = NSTextField(labelWithString: "InnosDimmer Schedule")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = .labelColor

        let subtitle = NSTextField(labelWithString: "Focused editor shell for the current automation schedule.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 0

        scheduleSummaryLabel.font = .systemFont(ofSize: 13)
        scheduleSummaryLabel.textColor = .labelColor
        scheduleSummaryLabel.lineBreakMode = .byWordWrapping
        scheduleSummaryLabel.maximumNumberOfLines = 0

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let content = NSStackView(views: [
            title,
            subtitle,
            makeSection(title: "Current schedule", content: scheduleSummaryLabel),
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
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, content])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        return stack
    }

    private func render() {
        let labels = SettingsSnapshot.sortedSchedule(schedule).map { entry in
            "\(Self.timeLabel(for: entry.minuteOfDay)) · \(entry.brightness)% brightness / \(entry.blueReduction)% blue"
        }
        scheduleSummaryLabel.stringValue = labels.isEmpty ? "Not configured" : labels.joined(separator: "\n")
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
