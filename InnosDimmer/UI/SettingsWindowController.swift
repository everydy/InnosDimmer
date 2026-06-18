import AppKit

struct SettingsActions {
    var selectDisplay: @MainActor (DisplayIdentity?) -> Result<SettingsSnapshot, Error>
    var updateSchedule: @MainActor ([ScheduleEntry]) -> Result<SettingsSnapshot, Error>
    var updateShortcuts: @MainActor ([ShortcutBinding]) -> Result<SettingsSnapshot, Error>
    var setLaunchAtLogin: @MainActor (Bool) -> Result<LoginItemStatus, Error>

    static let noop = SettingsActions(
        selectDisplay: { _ in .success(.defaultSnapshot()) },
        updateSchedule: { _ in .success(.defaultSnapshot()) },
        updateShortcuts: { _ in .success(.defaultSnapshot()) },
        setLaunchAtLogin: { _ in .success(.notRegistered) }
    )
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private enum Layout {
        static let scheduleEntryCount = 3
        static let fieldWidth: CGFloat = 72
    }

    private struct ScheduleControls {
        var time: NSTextField
        var brightness: NSTextField
        var warmth: NSTextField
    }

    private enum SettingsFormError: LocalizedError {
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

    private let actions: SettingsActions
    private let displayPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scheduleSummary = NSTextField(labelWithString: "")
    private let shortcutSummary = NSTextField(labelWithString: "")
    private let loginItemCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let loginItemSummary = NSTextField(labelWithString: "")
    private let diagnosticsSummary = NSTextField(labelWithString: "Diagnostics: local export available")
    private let matrixSummary = NSTextField(labelWithString: VerificationMatrix.summary(for: VerificationMatrix.defaultRows))
    private let statusLabel = NSTextField(labelWithString: "")
    private var scheduleControls: [ScheduleControls] = []
    private var shortcutCheckboxes: [ShortcutAction: NSButton] = [:]
    private var snapshot = SettingsSnapshot.defaultSnapshot()
    private var displayCandidates: [DisplayIdentity] = []
    private var loginItemStatus: LoginItemStatus = .notRegistered

    init(actions: SettingsActions = .noop) {
        self.actions = actions
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer Settings"
        super.init(window: window)
        installContent()
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        snapshot: SettingsSnapshot,
        displayCandidates: [DisplayIdentity],
        loginItemStatus: LoginItemStatus
    ) {
        self.snapshot = snapshot
        self.displayCandidates = displayCandidates
        self.loginItemStatus = loginItemStatus
        render()
    }

    func updateDisplayCandidates(_ candidates: [DisplayIdentity]) {
        displayCandidates = candidates
        renderDisplayPicker()
    }

    func snapshotForTesting() -> SettingsSnapshot {
        snapshot
    }

    private func installContent() {
        displayPicker.target = self
        displayPicker.action = #selector(displaySelectionChanged)

        let saveScheduleButton = NSButton(title: "Save schedule", target: self, action: #selector(saveSchedulePressed))
        saveScheduleButton.bezelStyle = .rounded

        let resetShortcutsButton = NSButton(title: "Reset shortcuts", target: self, action: #selector(resetShortcutsPressed))
        resetShortcutsButton.bezelStyle = .rounded

        loginItemCheckbox.target = self
        loginItemCheckbox.action = #selector(loginItemToggled)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let scheduleStack = makeScheduleStack()
        let shortcutStack = makeShortcutStack()
        let stack = NSStackView(views: [
            sectionLabel("Target display"),
            displayPicker,
            sectionLabel("Automation"),
            scheduleSummary,
            scheduleStack,
            saveScheduleButton,
            sectionLabel("Global shortcuts"),
            shortcutSummary,
            shortcutStack,
            resetShortcutsButton,
            sectionLabel("Startup"),
            loginItemCheckbox,
            loginItemSummary,
            sectionLabel("Diagnostics"),
            diagnosticsSummary,
            matrixSummary,
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
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

        window?.contentView?.addSubview(scrollView)
        if let contentView = window?.contentView {
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
                stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -20),
                stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
                stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
            ])
        }
    }

    private func makeScheduleStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let header = NSStackView(views: [
            fixedLabel("Time", width: Layout.fieldWidth),
            fixedLabel("Brightness", width: Layout.fieldWidth),
            fixedLabel("Warmth", width: Layout.fieldWidth)
        ])
        header.orientation = .horizontal
        header.spacing = 8
        stack.addArrangedSubview(header)

        for _ in 0..<Layout.scheduleEntryCount {
            let controls = ScheduleControls(
                time: editableField(),
                brightness: editableField(),
                warmth: editableField()
            )
            scheduleControls.append(controls)

            let row = NSStackView(views: [controls.time, controls.brightness, controls.warmth])
            row.orientation = .horizontal
            row.spacing = 8
            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func makeShortcutStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        for action in ShortcutAction.allCases {
            let checkbox = NSButton(checkboxWithTitle: Self.shortcutTitle(for: action), target: self, action: #selector(shortcutToggled))
            checkbox.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
            shortcutCheckboxes[action] = checkbox
            stack.addArrangedSubview(checkbox)
        }

        return stack
    }

    private func render() {
        renderDisplayPicker()
        renderSchedule()
        renderShortcuts()
        renderLoginItem()
        scheduleSummary.stringValue = Self.scheduleSummary(for: snapshot.schedule)
        shortcutSummary.stringValue = HotkeyManager.summary(for: snapshot.shortcuts)
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

    private func renderSchedule() {
        let entries = Array(snapshot.schedule.prefix(Layout.scheduleEntryCount))
        for index in 0..<scheduleControls.count {
            let entry = index < entries.count ? entries[index] : ScheduleEntry.defaultSchedule[index]
            let controls = scheduleControls[index]
            controls.time.stringValue = Self.timeLabel(for: entry.minuteOfDay)
            controls.brightness.stringValue = "\(entry.brightness)"
            controls.warmth.stringValue = "\(entry.warmth)"
        }
    }

    private func renderShortcuts() {
        for action in ShortcutAction.allCases {
            let binding = snapshot.shortcuts.first { $0.action == action }
            shortcutCheckboxes[action]?.state = binding?.isEnabled == true ? .on : .off
        }
    }

    private func renderLoginItem() {
        loginItemCheckbox.state = loginItemStatus == .enabled ? .on : .off
        loginItemSummary.stringValue = Self.loginItemSummary(for: loginItemStatus)
    }

    @objc private func displaySelectionChanged() {
        let selectedIndex = displayPicker.indexOfSelectedItem - 1
        let selectedDisplay = displayCandidates.indices.contains(selectedIndex)
            ? displayCandidates[selectedIndex]
            : nil

        switch actions.selectDisplay(selectedDisplay) {
        case .success(let updatedSnapshot):
            snapshot = updatedSnapshot
            render()
            report("Settings saved.")
        case .failure(let error):
            render()
            report(error.localizedDescription, isError: true)
        }
    }

    @objc private func saveSchedulePressed() {
        do {
            let schedule = try scheduleFromFields()
            switch actions.updateSchedule(schedule) {
            case .success(let updatedSnapshot):
                snapshot = updatedSnapshot
                render()
                report("Schedule saved.")
            case .failure(let error):
                render()
                report(error.localizedDescription, isError: true)
            }
        } catch {
            render()
            report(error.localizedDescription, isError: true)
        }
    }

    @objc private func shortcutToggled(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let action = ShortcutAction(rawValue: rawValue) else {
            return
        }

        var shortcuts = snapshot.shortcuts
        if let index = shortcuts.firstIndex(where: { $0.action == action }) {
            shortcuts[index].isEnabled = sender.state == .on
        }

        switch actions.updateShortcuts(shortcuts) {
        case .success(let updatedSnapshot):
            snapshot = updatedSnapshot
            render()
            report("Shortcuts saved.")
        case .failure(let error):
            render()
            report(error.localizedDescription, isError: true)
        }
    }

    @objc private func resetShortcutsPressed() {
        switch actions.updateShortcuts(ShortcutBinding.defaultBindings) {
        case .success(let updatedSnapshot):
            snapshot = updatedSnapshot
            render()
            report("Shortcuts reset.")
        case .failure(let error):
            render()
            report(error.localizedDescription, isError: true)
        }
    }

    @objc private func loginItemToggled() {
        let shouldEnable = loginItemCheckbox.state == .on
        switch actions.setLaunchAtLogin(shouldEnable) {
        case .success(let updatedStatus):
            loginItemStatus = updatedStatus
            renderLoginItem()
            report("Launch at login updated.")
        case .failure(let error):
            renderLoginItem()
            report(error.localizedDescription, isError: true)
        }
    }

    private func scheduleFromFields() throws -> [ScheduleEntry] {
        try scheduleControls.enumerated().map { index, controls in
            guard let minuteOfDay = Self.minuteOfDay(from: controls.time.stringValue) else {
                throw SettingsFormError.invalidTime(row: index + 1)
            }
            guard let brightness = Int(controls.brightness.stringValue), (0...100).contains(brightness) else {
                throw SettingsFormError.invalidPercent(row: index + 1, field: "brightness")
            }
            guard let warmth = Int(controls.warmth.stringValue), (0...100).contains(warmth) else {
                throw SettingsFormError.invalidPercent(row: index + 1, field: "warmth")
            }

            return ScheduleEntry(minuteOfDay: minuteOfDay, brightness: brightness, warmth: warmth)
        }
    }

    private func report(_ message: String, isError: Bool = false) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func fixedLabel(_ title: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }

    private func editableField() -> NSTextField {
        let field = NSTextField(string: "")
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: Layout.fieldWidth).isActive = true
        return field
    }

    private static func scheduleSummary(for schedule: [ScheduleEntry]) -> String {
        let entries = sortedScheduleLabels(schedule)
        return "Schedule: \(entries.joined(separator: ", "))"
    }

    private static func sortedScheduleLabels(_ schedule: [ScheduleEntry]) -> [String] {
        SettingsSnapshot.sortedSchedule(schedule).map { entry in
            "\(timeLabel(for: entry.minuteOfDay)) \(entry.brightness)%/\(entry.warmth)"
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
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

    private static func shortcutTitle(for action: ShortcutAction) -> String {
        let binding = ShortcutBinding.defaultBindings.first { $0.action == action }
        let suffix = binding.map { " (\(shortcutLabel(for: $0)))" } ?? ""
        return "\(actionLabel(for: action))\(suffix)"
    }

    private static func actionLabel(for action: ShortcutAction) -> String {
        switch action {
        case .brightnessUp:
            return "Brightness up"
        case .brightnessDown:
            return "Brightness down"
        case .warmthUp:
            return "Warmth up"
        case .warmthDown:
            return "Warmth down"
        case .quickDisableOverlay:
            return "Quick disable overlay"
        case .restorePreviousDimming:
            return "Restore previous dimming"
        }
    }

    private static func shortcutLabel(for binding: ShortcutBinding) -> String {
        var parts: [String] = []
        if binding.modifiers.contains(.option) {
            parts.append("Option")
        }
        if binding.modifiers.contains(.shift) {
            parts.append("Shift")
        }
        if binding.modifiers.contains(.control) {
            parts.append("Control")
        }
        if binding.modifiers.contains(.command) {
            parts.append("Command")
        }
        parts.append(keyLabel(for: binding.keyCode))
        return parts.joined(separator: " + ")
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 126:
            return "Up"
        case 125:
            return "Down"
        case 124:
            return "Right"
        case 123:
            return "Left"
        case 29:
            return "0"
        case 15:
            return "R"
        default:
            return "Key \(keyCode)"
        }
    }

    private static func loginItemSummary(for status: LoginItemStatus) -> String {
        switch status {
        case .enabled:
            return "Launch at login: enabled"
        case .disabled:
            return "Launch at login: disabled"
        case .requiresApproval:
            return "Launch at login: requires approval in System Settings"
        case .notRegistered:
            return "Launch at login: not registered"
        case .unsupported(let reason):
            return "Launch at login: unsupported (\(reason))"
        }
    }
}
