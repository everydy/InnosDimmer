import AppKit

final class SettingsWindowController: NSWindowController {
    private let displayPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scheduleSummary = NSTextField(labelWithString: "Schedule: 09:00 80%/12, 19:00 45%/32, 23:00 25%/58")
    private let shortcutSummary = NSTextField(labelWithString: HotkeyManager.summary(for: ShortcutBinding.defaultBindings))
    private let loginItemSummary = NSTextField(labelWithString: "Launch at login: configurable")
    private let diagnosticsSummary = NSTextField(labelWithString: "Diagnostics: local export available")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer Settings"
        self.init(window: window)
        installContent()
    }

    func updateDisplayCandidates(_ candidates: [DisplayIdentity]) {
        displayPicker.removeAllItems()
        for candidate in candidates {
            displayPicker.addItem(withTitle: candidate.localizedName)
        }
    }

    private func installContent() {
        let label = NSTextField(labelWithString: "Target display")
        let scheduleLabel = NSTextField(labelWithString: "Automation")
        let shortcutLabel = NSTextField(labelWithString: "Global shortcuts")
        let diagnosticsLabel = NSTextField(labelWithString: "Diagnostics")
        let stack = NSStackView(views: [
            label,
            displayPicker,
            scheduleLabel,
            scheduleSummary,
            shortcutLabel,
            shortcutSummary,
            loginItemSummary,
            diagnosticsLabel,
            diagnosticsSummary
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        window?.contentView?.addSubview(stack)
        if let contentView = window?.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
            ])
        }
    }
}
