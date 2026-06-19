import AppKit
import UniformTypeIdentifiers

struct SettingsActions {
    var selectDisplay: @MainActor (DisplayIdentity?) -> Result<SettingsSnapshot, Error>
    var openScheduleEditor: @MainActor () -> Void
    var updateShortcuts: @MainActor ([ShortcutBinding]) -> Result<SettingsSnapshot, Error>
    var setLaunchAtLogin: @MainActor (Bool) -> Result<LoginItemStatus, Error>
    var exportDiagnostics: @MainActor () -> Result<Data, Error>

    static let noop = SettingsActions(
        selectDisplay: { _ in .success(.defaultSnapshot()) },
        openScheduleEditor: {},
        updateShortcuts: { _ in .success(.defaultSnapshot()) },
        setLaunchAtLogin: { _ in .success(.notRegistered) },
        exportDiagnostics: { .success(Data()) }
    )
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private enum Layout {
        static let shortcutActionWidth: CGFloat = 122
        static let shortcutToggleWidth: CGFloat = 34
        static let shortcutModifierWidth: CGFloat = 38
        static let shortcutKeyWidth: CGFloat = 58
    }

    private struct ShortcutControls {
        var enabled: NSButton
        var option: NSButton
        var shift: NSButton
        var control: NSButton
        var command: NSButton
        var keyCode: ShortcutKeyField
    }

    private enum SettingsFormError: LocalizedError {
        case invalidShortcutKey(action: String)

        var errorDescription: String? {
            switch self {
            case .invalidShortcutKey(let action):
                return "\(action) needs a key code from 0 to 65535."
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
    private var shortcutControls: [ShortcutAction: ShortcutControls] = [:]
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

        let openScheduleButton = NSButton(title: "Open schedule editor", target: self, action: #selector(openScheduleEditorPressed))
        openScheduleButton.bezelStyle = .rounded

        let resetShortcutsButton = NSButton(title: "Reset shortcuts", target: self, action: #selector(resetShortcutsPressed))
        resetShortcutsButton.bezelStyle = .rounded
        let saveShortcutsButton = NSButton(title: "Save shortcuts", target: self, action: #selector(saveShortcutsPressed))
        saveShortcutsButton.bezelStyle = .rounded
        let shortcutButtons = NSStackView(views: [saveShortcutsButton, resetShortcutsButton])
        shortcutButtons.orientation = .horizontal
        shortcutButtons.spacing = 8

        loginItemCheckbox.target = self
        loginItemCheckbox.action = #selector(loginItemToggled)

        let exportDiagnosticsButton = NSButton(title: "Export diagnostics", target: self, action: #selector(exportDiagnosticsPressed))
        exportDiagnosticsButton.bezelStyle = .rounded

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let shortcutStack = makeShortcutStack()
        let stack = NSStackView(views: [
            sectionLabel("Target display"),
            displayPicker,
            sectionLabel("Automation"),
            scheduleSummary,
            openScheduleButton,
            sectionLabel("Global shortcuts"),
            shortcutSummary,
            shortcutStack,
            shortcutButtons,
            sectionLabel("Startup"),
            loginItemCheckbox,
            loginItemSummary,
            sectionLabel("Diagnostics"),
            diagnosticsSummary,
            matrixSummary,
            exportDiagnosticsButton,
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

    private func makeShortcutStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

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
        header.spacing = 6
        stack.addArrangedSubview(header)

        for action in ShortcutAction.allCases {
            let controls = ShortcutControls(
                enabled: checkbox(title: "", action: #selector(shortcutControlChanged), width: Layout.shortcutToggleWidth),
                option: checkbox(title: "", action: #selector(shortcutControlChanged)),
                shift: checkbox(title: "", action: #selector(shortcutControlChanged)),
                control: checkbox(title: "", action: #selector(shortcutControlChanged)),
                command: checkbox(title: "", action: #selector(shortcutControlChanged)),
                keyCode: editableKeyField(width: Layout.shortcutKeyWidth)
            )
            controls.keyCode.placeholderString = "Key"
            shortcutControls[action] = controls

            let row = NSStackView(views: [
                fixedLabel(Self.actionLabel(for: action), width: Layout.shortcutActionWidth),
                controls.enabled,
                controls.option,
                controls.shift,
                controls.control,
                controls.command,
                controls.keyCode
            ])
            row.orientation = .horizontal
            row.spacing = 6
            stack.addArrangedSubview(row)
        }

        return stack
    }

    private func render() {
        renderDisplayPicker()
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

    private func renderShortcuts() {
        for action in ShortcutAction.allCases {
            let binding = snapshot.shortcuts.first { $0.action == action }
            guard let controls = shortcutControls[action] else {
                continue
            }

            controls.enabled.state = binding?.isEnabled == true ? .on : .off
            controls.option.state = binding?.modifiers.contains(.option) == true ? .on : .off
            controls.shift.state = binding?.modifiers.contains(.shift) == true ? .on : .off
            controls.control.state = binding?.modifiers.contains(.control) == true ? .on : .off
            controls.command.state = binding?.modifiers.contains(.command) == true ? .on : .off
            controls.keyCode.setKeyCode(binding?.keyCode)
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

    @objc private func openScheduleEditorPressed() {
        actions.openScheduleEditor()
        report("Opened schedule editor.")
    }

    @objc private func shortcutControlChanged() {
        report("Shortcut changes are ready to save.")
    }

    @objc private func saveShortcutsPressed() {
        do {
            let shortcuts = try shortcutBindingsFromControls()
            switch actions.updateShortcuts(shortcuts) {
            case .success(let updatedSnapshot):
                snapshot = updatedSnapshot
                render()
                report("Shortcuts saved.")
            case .failure(let error):
                render()
                report(error.localizedDescription, isError: true)
            }
        } catch {
            render()
            report(error.localizedDescription, isError: true)
        }
    }

    @discardableResult
    func saveShortcutsForTesting() -> Result<SettingsSnapshot, Error> {
        do {
            let shortcuts = try shortcutBindingsFromControls()
            switch actions.updateShortcuts(shortcuts) {
            case .success(let updatedSnapshot):
                snapshot = updatedSnapshot
                render()
                return .success(updatedSnapshot)
            case .failure(let error):
                render()
                return .failure(error)
            }
        } catch {
            render()
            return .failure(error)
        }
    }

    func openScheduleEditorForTesting() {
        openScheduleEditorPressed()
    }

    func setShortcutForTesting(
        action: ShortcutAction,
        keyCode: UInt16,
        modifiers: ShortcutModifiers,
        isEnabled: Bool
    ) {
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
        shortcutControls[action]?.keyCode.setRawString(keyCode)
    }

    func captureShortcutKeyForTesting(action: ShortcutAction, keyCode: UInt16) {
        shortcutControls[action]?.keyCode.setKeyCode(keyCode)
    }

    func shortcutForTesting(action: ShortcutAction) -> ShortcutBinding? {
        try? shortcutBindingsFromControls().first { $0.action == action }
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

    @objc private func exportDiagnosticsPressed() {
        switch actions.exportDiagnostics() {
        case .success(let data):
            presentDiagnosticsSavePanel(data: data)
        case .failure(let error):
            report(error.localizedDescription, isError: true)
        }
    }

    func exportDiagnosticsForTesting() -> Result<Data, Error> {
        actions.exportDiagnostics()
    }

    private func presentDiagnosticsSavePanel(data: Data) {
        guard let window else {
            report("Settings window is unavailable.", isError: true)
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "innos-diagnostics.json"
        panel.allowedContentTypes = [.json]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            do {
                try data.write(to: url, options: .atomic)
                self?.report("Diagnostics exported.")
            } catch {
                self?.report(error.localizedDescription, isError: true)
            }
        }
    }

    private func shortcutBindingsFromControls() throws -> [ShortcutBinding] {
        try ShortcutAction.allCases.map { action in
            guard let controls = shortcutControls[action],
                  let keyCode = controls.keyCode.parsedKeyCode() else {
                throw SettingsFormError.invalidShortcutKey(action: Self.actionLabel(for: action))
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
        if controls.option.state == .on {
            modifiers.insert(.option)
        }
        if controls.shift.state == .on {
            modifiers.insert(.shift)
        }
        if controls.control.state == .on {
            modifiers.insert(.control)
        }
        if controls.command.state == .on {
            modifiers.insert(.command)
        }
        return modifiers
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

    private func editableKeyField(width: CGFloat) -> ShortcutKeyField {
        let field = ShortcutKeyField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.target = self
        field.action = #selector(shortcutControlChanged)
        return field
    }

    private func checkbox(title: String, action: Selector, width: CGFloat = Layout.shortcutModifierWidth) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        return button
    }

    private static func scheduleSummary(for schedule: [ScheduleEntry]) -> String {
        let entries = sortedScheduleLabels(schedule)
        return "Schedule: \(entries.joined(separator: ", "))"
    }

    private static func sortedScheduleLabels(_ schedule: [ScheduleEntry]) -> [String] {
        SettingsSnapshot.sortedSchedule(schedule).map { entry in
            "\(timeLabel(for: entry.minuteOfDay)) \(entry.brightness)% / blue \(entry.blueReduction)%"
        }
    }

    private static func timeLabel(for minuteOfDay: Int) -> String {
        let minute = max(0, min(1_439, minuteOfDay))
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func actionLabel(for action: ShortcutAction) -> String {
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

private final class ShortcutKeyField: NSTextField {
    private(set) var capturedKeyCode: UInt16?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48, 53:
            super.keyDown(with: event)
        case 51, 117:
            setKeyCode(nil)
            sendAction(action, to: target)
        default:
            setKeyCode(event.keyCode)
            sendAction(action, to: target)
        }
    }

    func setKeyCode(_ keyCode: UInt16?) {
        capturedKeyCode = keyCode
        stringValue = keyCode.map { Self.keyLabel(for: $0) } ?? ""
    }

    func setRawString(_ value: String) {
        capturedKeyCode = nil
        stringValue = value
    }

    func parsedKeyCode() -> UInt16? {
        let input = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let capturedKeyCode, input == Self.keyLabel(for: capturedKeyCode) {
            return capturedKeyCode
        }
        if let numeric = UInt16(input) {
            return numeric
        }
        return Self.keyCode(for: input)
    }

    private static func keyCode(for label: String) -> UInt16? {
        switch label.lowercased() {
        case "up":
            return 126
        case "down":
            return 125
        case "right":
            return 124
        case "left":
            return 123
        case "0":
            return 29
        case "r":
            return 15
        default:
            let normalized = label.lowercased().replacingOccurrences(of: "key ", with: "")
            return UInt16(normalized)
        }
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
}
