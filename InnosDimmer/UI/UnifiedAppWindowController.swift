import AppKit

struct AppWindowPageStructure: Equatable {
    var pageTitle: String
    var identifiers: Set<String>
    var visibleText: [String]

    var hasHeaderBackControl: Bool {
        containsIdentifier("app-window-header-action:Back")
    }

    var hasBodyBackRow: Bool {
        containsIdentifier("app-window-body-action:Back")
    }

    var usesSplitLayout: Bool {
        containsIdentifier("app-window-detail-split")
    }

    var diagnosticsLogRowCount: Int {
        identifiers.filter { $0 == "app-window-log-row" }.count
    }

    var compactActionLabels: [String] {
        visibleText.filter {
            $0 == "Export diagnostics" ||
            $0 == "Copy log" ||
            $0 == "Save schedule" ||
            $0 == "Save shortcuts" ||
            $0 == "Apply settings"
        }
    }

    func containsIdentifier(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    func containsText(_ fragment: String) -> Bool {
        visibleText.contains { $0.localizedCaseInsensitiveContains(fragment) }
    }
}

enum UnifiedAppWindowPage: CaseIterable {
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
            return "Overview"
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

    var navigationTitle: String {
        switch self {
        case .home:
            return "Overview"
        default:
            return title
        }
    }

    var tileDescription: String {
        switch self {
        case .home:
            return "Quick controls and status."
        case .current:
            return "State and commands."
        case .display:
            return "Target monitor."
        case .schedule:
            return "Rows and pause state."
        case .shortcuts:
            return "Global hotkeys."
        case .settings:
            return "Startup and persistence."
        case .diagnostics:
            return "Failures and export."
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
        static let sidebarWidth: CGFloat = 244
        static let sidebarButtonHeight: CGFloat = 54
        static let contentMinimumWidth: CGFloat = 560
        static let tokenRowHeight: CGFloat = 34
        static let windowContentSize = NSSize(width: 900, height: 640)
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
    private let headerStack = NSStackView()
    private let headerSpacer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let contentPane = NSView()
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
    private var toastView: AppWindowToastView?
    private var toastDismissWorkItem: DispatchWorkItem?
    private weak var homeQuickActionsSection: NSView?
    private weak var homeNextActionsSection: NSView?
    private var commandButtons: [MenuBarCommand: NSButton] = [:]
    private var pageButtons: [UnifiedAppWindowPage: NSButton] = [:]
    private var sidebarButtons: [UnifiedAppWindowPage: AppWindowSidebarButton] = [:]
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
            contentRect: NSRect(origin: .zero, size: Layout.windowContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InnosDimmer"
        window.setContentSize(Layout.windowContentSize)
        let fixedFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: Layout.windowContentSize)).size
        window.minSize = fixedFrameSize
        window.maxSize = fixedFrameSize
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
              let firstTile = sidebarButtons[.current] else {
            return nil
        }
        return (
            quickActions.frame.width,
            nextActions.frame.width,
            firstTile.frame.width,
            firstTile.frame.height
        )
    }

    func windowContentSizeForTesting() -> NSSize? {
        window?.contentView?.frame.size
    }

    func toastMessageForTesting() -> String? {
        toastView?.message
    }

    func hasInlineStatusForTesting() -> Bool {
        !statusLabel.isHidden
    }

    func copyDiagnosticsLogForTesting() {
        copyDiagnosticsLogPressed()
    }

    func sidebarNavigationForTesting() -> [String] {
        UnifiedAppWindowPage.allCases.compactMap { page in
            sidebarButtons[page]?.navigationTitleForTesting
        }
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
        blueReductionTrackView.setAccessibilityLabel("App window warmth percentage")

        let sidebar = makeSidebar()
        let header = makeHeader()
        let contentStack = NSStackView(views: [header, statusLabel, contentPane])
        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentPane.translatesAutoresizingMaskIntoConstraints = false

        let contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentStack)

        let rootStack = NSStackView(views: [sidebar, contentContainer])
        rootStack.orientation = .horizontal
        rootStack.alignment = .height
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = DashboardRootView()
        window?.contentView = contentView
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth),
            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: InnosDesignTokens.Spacing.surfacePadding),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -InnosDesignTokens.Spacing.surfacePadding),
            contentStack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: InnosDesignTokens.Spacing.surfacePadding),
            contentStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -InnosDesignTokens.Spacing.surfacePadding),
            header.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contentPane.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contentPane.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.contentMinimumWidth),
            contentPane.heightAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
        renderActivePage()
    }

    private func makeSidebar() -> NSView {
        let buttons: [AppWindowSidebarButton] = UnifiedAppWindowPage.allCases.map { page in
            let button = AppWindowSidebarButton(page: page, target: self, action: #selector(pageButtonPressed(_:)))
            button.identifier = NSUserInterfaceItemIdentifier("app-window-sidebar-page:\(page.navigationTitle)")
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.sidebarButtonHeight).isActive = true
            sidebarButtons[page] = button
            return button
        }
        let buttonViews: [NSView] = buttons

        let stack = NSStackView(views: buttonViews + [spacer()])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.identifier = NSUserInterfaceItemIdentifier("app-window-sidebar")
        buttonViews.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let container = SidebarContainerView(content: stack)
        container.identifier = NSUserInterfaceItemIdentifier("app-window-sidebar-container")
        return container
    }

    private func makeHeader() -> NSView {
        headerStack.setViews([
            titleLabel,
            headerSpacer,
            modeChip,
            loginChip
        ], in: .leading)
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return headerStack
    }

    private func renderActivePage() {
        titleLabel.stringValue = activePage.title
        syncHeaderChipsForActivePage()
        commandButtons.removeAll(keepingCapacity: true)
        pageButtons.removeAll(keepingCapacity: true)
        contentPane.subviews.forEach { $0.removeFromSuperview() }

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
        contentPane.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: contentPane.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentPane.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentPane.topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: contentPane.bottomAnchor)
        ])
        updateSidebarSelection()
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

        return left
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
                    value: "Brightness: \(state.targetBrightness)% / Warmth: \(state.targetBlueReduction)%"
                ),
                makeSummaryRow(title: "Automation", value: automationSummary())
                ]),
                makeSection(title: "Commands", views: [
                    makeActionRow([
                        button("Open popover", command: .openPopover, action: #selector(openPopoverPressed), style: .primary),
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
        return makeDetailPage(
            title: "Display",
            content: verticalStack([
            makeSection(title: "Current state", trailing: makeChip("Ready", tone: .ready), views: [
                makeSummaryRow(title: "Display", value: currentDisplaySummary()),
                makeSummaryRow(title: "Brightness", value: "\(state.targetBrightness)%"),
                makeSummaryRow(title: "Warmth", value: "\(state.targetBlueReduction)%")
            ]),
            makeSection(title: "Target display", trailing: makeChip(resolvedDisplay == nil ? "Unresolved" : "Resolved", tone: resolvedTone), views: [
                displayPicker,
                makeSummaryRow(title: "Selection rule", value: targetDisplayRuleSummary()),
                makeSummaryRow(title: "Active target", value: resolvedDisplaySummary(resolvedDisplay)),
                makeSummaryRow(title: "Safety scope", value: targetDisplayScopeSummary(resolvedDisplay)),
                makeSummaryRow(title: "Warmth", value: gammaTableSummary(resolvedDisplay))
            ]),
            makeSection(title: "Saved selection", views: [
                makeSummaryRow(title: "Saved", value: selectedDisplaySummary()),
                makeActionRow([
                    PopoverCommandButton(
                        title: "Save display",
                        style: .primary,
                        target: self,
                        action: #selector(saveDisplayPressed)
                    )
                ])
            ])
            ])
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
                    makeSummaryTable(
                        identifier: "Schedule",
                        rows: [
                            .init(title: "Status", value: automationSummary()),
                            .init(title: "Current", value: scheduleSummaryText()),
                            .init(title: "Shortcuts", value: "Option + Shift controls")
                        ]
                    )
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
        return makeDetailPage(
            title: "Settings",
            content: verticalStack([
                makeSection(title: "Launch at login", trailing: makeChip(loginItemStatus == .enabled ? "Enabled" : "Disabled", tone: loginItemStatus == .enabled ? .ready : .neutral), views: [
                    loginItemCheckbox
                ])
            ])
        )
    }

    private func makeDiagnosticsPage() -> NSView {
        let content = verticalStack([
            makeSection(title: "Verification matrix", views: [
                makeSummaryTable(
                    identifier: "Verification matrix",
                    rows: [
                        .init(title: "Summary", value: diagnosticsMatrixSummary()),
                        .init(title: "Overlay", value: verificationCheckmark()),
                        .init(title: "Gamma", value: verificationCheckmark()),
                        .init(title: "Hotkeys", value: verificationCheckmark()),
                        .init(title: "Login item", value: verificationCheckmark())
                    ]
                )
            ]),
            makeSection(title: "Recent diagnostics log", trailing: PopoverCommandButton(title: "Copy log", style: .normal, target: self, action: #selector(copyDiagnosticsLogPressed)), views: [
                makeDiagnosticsCodeLogView()
            ])
        ])
        content.identifier = NSUserInterfaceItemIdentifier("app-window-diagnostics-stack")
        return makeDetailPage(
            title: "Diagnostics",
            trailingActions: [
                PopoverCommandButton(title: "Export diagnostics", style: .primary, target: self, action: #selector(exportDiagnosticsPressed))
            ],
            content: content
        )
    }

    private func makeDetailPage(
        title: String,
        trailingActions: [NSView] = [],
        content: NSView
    ) -> NSView {
        _ = title

        guard !trailingActions.isEmpty else {
            return content
        }

        let header = NSStackView(views: [spacer()] + trailingActions)
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

    private func makeSummaryTable(identifier: String, rows: [InnosSummaryTableEntry]) -> NSView {
        InnosComponentFactory.summaryTable(entries: rows, identifier: identifier)
    }

    private func makeDiagnosticsCodeLogView() -> NSView {
        diagnosticsTextView.string = diagnosticsLogText()
        diagnosticsTextView.backgroundColor = PopoverPalette.subtleBackground(for: diagnosticsTextView.effectiveAppearance)
        diagnosticsTextView.identifier = NSUserInterfaceItemIdentifier("app-window-diagnostics-code-log-text")
        diagnosticsTextView.isVerticallyResizable = true
        diagnosticsTextView.isHorizontallyResizable = false
        diagnosticsTextView.autoresizingMask = [.width]
        diagnosticsTextView.minSize = NSSize(width: 0, height: 0)
        diagnosticsTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        diagnosticsTextView.textContainer?.widthTracksTextView = true
        diagnosticsTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        let scrollView = NSScrollView()
        scrollView.identifier = NSUserInterfaceItemIdentifier("app-window-diagnostics-code-log")
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = diagnosticsTextView
        scrollView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        return scrollView
    }

    private func makeQuickActionsSection() -> NSView {
        makeSection(title: "Quick actions", trailing: makeChip(state.automationPausedUntilNextBoundary ? "Manual" : "Automation active", tone: state.automationPausedUntilNextBoundary ? .warning : .ready), views: [
            makeControlGroup(title: "Brightness", valueLabel: brightnessValueLabel, trackView: brightnessTrackView, decrement: compactButton("-", accessibilityLabel: "Brightness down", command: .brightnessDown, action: #selector(brightnessDownPressed)), increment: compactButton("+", accessibilityLabel: "Brightness up", command: .brightnessUp, action: #selector(brightnessUpPressed))),
            makeSeparator(),
            makeControlGroup(title: "Warmth", valueLabel: blueReductionValueLabel, trackView: blueReductionTrackView, decrement: compactButton("-", accessibilityLabel: "Warmth down", command: .blueReductionDown, action: #selector(blueReductionDownPressed)), increment: compactButton("+", accessibilityLabel: "Warmth up", command: .blueReductionUp, action: #selector(blueReductionUpPressed))),
            makeActionRow([
                button("Disable", command: .quickDisable, action: #selector(quickDisablePressed), style: .warning),
                button("Restore", command: .restorePrevious, action: #selector(restorePreviousPressed)),
                button(automationActionTitle(), command: automationActionCommand, action: #selector(automationActionPressed))
            ])
        ])
    }

    private func makeNextActionsSection() -> NSView {
        makeSection(title: "Status", views: [
            makeSummaryTable(
                identifier: "Overview status",
                rows: [
                    .init(title: "Schedule", value: nextScheduleText()),
                    .init(title: "Diagnostics", value: diagnosticsSummary()),
                    .init(title: "Shortcuts", value: "\(shortcuts.filter(\.isEnabled).count) enabled")
                ]
            )
        ])
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
        syncHeaderChipsForActivePage()
    }

    private func syncHeaderChipsForActivePage() {
        let isOverview = activePage == .home
        if isOverview {
            for chip in [modeChip, loginChip] where chip.superview == nil {
                headerStack.addArrangedSubview(chip)
            }
            modeChip.isHidden = false
            loginChip.isHidden = false
            return
        }

        for chip in [modeChip, loginChip] {
            if headerStack.arrangedSubviews.contains(chip) {
                headerStack.removeArrangedSubview(chip)
            }
            chip.removeFromSuperview()
        }
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
        statusLabel.isHidden = true
        showToast(message, isError: isError)
    }

    private func showToast(_ message: String, isError: Bool = false) {
        toastDismissWorkItem?.cancel()
        toastView?.removeFromSuperview()

        guard let contentView = window?.contentView else {
            return
        }

        let toast = AppWindowToastView(message: message, isError: isError)
        toast.identifier = NSUserInterfaceItemIdentifier("app-window-toast")
        toast.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -InnosDesignTokens.Spacing.surfacePadding),
            toast.topAnchor.constraint(equalTo: contentView.topAnchor, constant: InnosDesignTokens.Spacing.surfacePadding),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])
        toastView = toast

        let dismissWorkItem = DispatchWorkItem { [weak self, weak toast] in
            guard let self, self.toastView === toast else { return }
            toast?.removeFromSuperview()
            self.toastView = nil
            self.toastDismissWorkItem = nil
        }
        toastDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissWorkItem)
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
        button.identifier = NSUserInterfaceItemIdentifier("app-window-command:\(title)")
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: PopoverCommandButton.minimumHeight).isActive = true
        commandButtons[command] = button
        return button
    }

    private func compactButton(_ title: String, accessibilityLabel: String, command: MenuBarCommand, action: Selector) -> NSButton {
        let button = button(title, command: command, action: action)
        button.font = InnosDesignTokens.Font.popoverStepperButton
        button.setAccessibilityLabel(accessibilityLabel)
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
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
            return "\(modeTitle) + gamma warmth"
        case .gamma:
            return "\(modeTitle) warmth"
        case .platformBlocked, .unknown:
            return modeTitle
        }
    }

    private func selectedDisplaySummary() -> String {
        snapshot.selectedDisplay?.localizedName ?? "Automatic external display"
    }

    private func targetDisplayRuleSummary() -> String {
        if let selectedDisplay = snapshot.selectedDisplay {
            return "Pinned to \(selectedDisplay.localizedName)"
        }
        return "Automatic external display, preferring a non-main monitor"
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

    private func targetDisplayScopeSummary(_ display: DisplayIdentity?) -> String {
        guard let display else {
            return "No display will be dimmed until a target resolves"
        }
        return CGDisplayIsMain(display.cgDisplayID) == 1
            ? "Primary screen - review before saving"
            : "External display only"
    }

    private func gammaTableSummary(_ display: DisplayIdentity?) -> String {
        guard display != nil else {
            return "Unavailable until a display resolves"
        }

        switch state.activeMode {
        case .overlay, .gamma:
            return "Supported for warmth"
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
            .map { "\(Self.timeLabel(for: $0.minuteOfDay)) · \($0.brightness)% / warmth \($0.blueReduction)%" }
            .joined(separator: ", ")
    }

    private func nextScheduleText() -> String {
        guard let entry = SettingsSnapshot.sortedSchedule(schedule).first else { return "not configured" }
        return "\(Self.timeLabel(for: entry.minuteOfDay)) · \(entry.brightness)% / warmth \(entry.blueReduction)%"
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

    private func verificationCheckmark() -> String {
        "✓"
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
            return "Warmth up"
        case .blueReductionDown:
            return "Warmth down"
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
        guard let page = page(for: sender) else { return }
        activePage = page
        renderActivePage()
    }

    private func page(for button: NSButton) -> UnifiedAppWindowPage? {
        if let sidebarPage = sidebarButtons.first(where: { $0.value === button })?.key {
            return sidebarPage
        }
        if let page = pageButtons.first(where: { $0.value === button })?.key {
            return page
        }
        guard let identifier = button.identifier?.rawValue else {
            return nil
        }
        return UnifiedAppWindowPage.allCases.first { page in
            identifier == page.title ||
            identifier == page.navigationTitle ||
            identifier == "app-window-sidebar-page:\(page.navigationTitle)"
        }
    }

    private func updateSidebarSelection() {
        sidebarButtons.forEach { page, button in
            button.setSelected(page == activePage)
        }
    }

    @objc private func brightnessDownPressed() { actions.perform(.brightnessDown) }
    @objc private func brightnessUpPressed() { actions.perform(.brightnessUp) }
    @objc private func blueReductionDownPressed() { actions.perform(.blueReductionDown) }
    @objc private func blueReductionUpPressed() { actions.perform(.blueReductionUp) }
    @objc private func quickDisablePressed() { actions.perform(.quickDisable) }
    @objc private func restorePreviousPressed() { actions.perform(.restorePrevious) }
    @objc private func automationActionPressed() { actions.perform(automationActionCommand) }
    @objc private func openAppWindowPressed() { actions.perform(.openAppWindow) }
    @objc private func openPopoverPressed() { actions.perform(.openPopover) }
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

    @objc private func copyDiagnosticsLogPressed() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticsLogText(), forType: .string)
        report("Diagnostics log copied.")
    }
}

@MainActor
private final class AppWindowToastView: NSView {
    let message: String
    private let isError: Bool
    private let label = NSTextField(labelWithString: "")

    init(message: String, isError: Bool) {
        self.message = message
        self.isError = isError
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = InnosDesignTokens.Radius.section
        layer?.borderWidth = 1

        label.stringValue = message
        label.font = InnosDesignTokens.Font.bodyEmphasis
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
        setAccessibilityLabel(message)
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
        let tone: InnosDesignTokens.Tone = isError ? .danger : .ready
        label.textColor = InnosDesignTokens.foreground(for: tone, appearance: effectiveAppearance)
        layer?.backgroundColor = InnosDesignTokens.background(for: tone, appearance: effectiveAppearance).cgColor
        layer?.borderColor = InnosDesignTokens.border(for: tone, appearance: effectiveAppearance).cgColor
    }
}

@MainActor
private final class SidebarContainerView: NSView {
    private let content: NSView

    init(content: NSView) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: InnosDesignTokens.Spacing.surfacePadding),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -InnosDesignTokens.Spacing.surfacePadding),
            content.topAnchor.constraint(equalTo: topAnchor, constant: InnosDesignTokens.Spacing.surfacePadding),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -InnosDesignTokens.Spacing.surfacePadding)
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
        layer?.backgroundColor = InnosDesignTokens.surfaceSubtle(for: effectiveAppearance).cgColor
        layer?.borderColor = InnosDesignTokens.border(for: effectiveAppearance).cgColor
        layer?.borderWidth = 0
    }
}

@MainActor
private final class AppWindowSidebarButton: NSButton {
    private let page: UnifiedAppWindowPage
    private let iconBox = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var isSelectedPage = false
    var navigationTitleForTesting: String {
        page.navigationTitle
    }

    init(page: UnifiedAppWindowPage, target: AnyObject?, action: Selector?) {
        self.page = page
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = InnosDesignTokens.Radius.section
        layer?.borderWidth = 1
        setButtonType(.momentaryPushIn)

        iconBox.wantsLayer = true
        iconBox.layer?.cornerRadius = 7
        iconBox.layer?.borderWidth = 1
        iconBox.translatesAutoresizingMaskIntoConstraints = false

        if let image = NSImage(systemSymbolName: page.tileSymbolName, accessibilityDescription: nil) {
            iconView.image = image
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15.5, weight: .semibold)
        }
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(iconView)

        titleLabel.stringValue = page.navigationTitle
        titleLabel.font = InnosDesignTokens.Font.app(ofSize: 14, weight: .semibold)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [titleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 0
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [iconBox, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: 30),
            iconBox.heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityLabel(page.navigationTitle)
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

    func setSelected(_ isSelected: Bool) {
        guard isSelectedPage != isSelected else {
            return
        }
        isSelectedPage = isSelected
        updateColors()
    }

    private func updateColors() {
        let appearance = effectiveAppearance
        let accent = InnosDesignTokens.accent(for: appearance)
        if isSelectedPage {
            layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
            layer?.borderColor = accent.withAlphaComponent(0.50).cgColor
            iconBox.layer?.backgroundColor = accent.withAlphaComponent(0.22).cgColor
            iconBox.layer?.borderColor = accent.withAlphaComponent(0.42).cgColor
            titleLabel.textColor = .labelColor
        } else {
            layer?.backgroundColor = InnosDesignTokens.surfaceSection(for: appearance).cgColor
            layer?.borderColor = InnosDesignTokens.border(for: appearance).cgColor
            iconBox.layer?.backgroundColor = InnosDesignTokens.surfaceControl(for: appearance).cgColor
            iconBox.layer?.borderColor = InnosDesignTokens.border(for: appearance).cgColor
            titleLabel.textColor = .labelColor
        }
        iconView.contentTintColor = accent
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
