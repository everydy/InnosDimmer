import AppKit

@MainActor
final class MenuBarController: NSObject {
    private enum DimmingStep {
        static let brightness = 5
        static let warmth = 5
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let brightnessController: BrightnessController
    private let popover = NSPopover()
    private lazy var settingsWindowController = SettingsWindowController()
    private var commandBeforeQuickDisable: BrightnessCommand?

    init(brightnessController: BrightnessController = BrightnessController()) {
        self.brightnessController = brightnessController
        super.init()
    }

    func start() {
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "InnosDimmer")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 300)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = MenuBarPopoverView(
            state: brightnessController.state,
            actions: MenuBarActions { [weak self] command in
                self?.perform(command)
            }
        )
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func perform(_ command: MenuBarCommand) {
        switch command {
        case .brightnessDown:
            adjust(brightnessDelta: -DimmingStep.brightness)
        case .brightnessUp:
            adjust(brightnessDelta: DimmingStep.brightness)
        case .warmthDown:
            adjust(warmthDelta: -DimmingStep.warmth)
        case .warmthUp:
            adjust(warmthDelta: DimmingStep.warmth)
        case .quickDisable:
            quickDisable()
        case .restorePrevious:
            restorePrevious()
        case .openSettings:
            openSettings()
        case .probeDDC, .pauseAutomation:
            refreshPopover()
        }
    }

    private func adjust(brightnessDelta: Int = 0, warmthDelta: Int = 0) {
        let state = brightnessController.state
        apply(
            brightness: state.targetBrightness + brightnessDelta,
            warmth: state.targetWarmth + warmthDelta,
            source: .menuSlider
        )
    }

    private func quickDisable() {
        let state = brightnessController.state
        commandBeforeQuickDisable = makeCommand(
            brightness: state.targetBrightness,
            warmth: state.targetWarmth,
            source: .menuSlider
        )
        apply(brightness: 100, warmth: state.targetWarmth, source: .menuSlider)
    }

    private func restorePrevious() {
        guard let command = commandBeforeQuickDisable else {
            refreshPopover()
            return
        }

        brightnessController.apply(command)
        commandBeforeQuickDisable = nil
        refreshPopover()
    }

    private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func apply(brightness: Int, warmth: Int, source: BrightnessCommandSource) {
        guard let command = makeCommand(brightness: brightness, warmth: warmth, source: source) else {
            refreshPopover()
            return
        }

        brightnessController.apply(command)
        refreshPopover()
    }

    private func makeCommand(brightness: Int, warmth: Int, source: BrightnessCommandSource) -> BrightnessCommand? {
        guard let display = brightnessController.state.display else {
            return nil
        }

        return BrightnessCommand(
            display: display,
            brightness: brightness,
            warmth: warmth,
            source: source
        )
    }

    private func refreshPopover() {
        guard let view = popover.contentViewController?.view as? MenuBarPopoverView else {
            return
        }

        view.update(state: brightnessController.state)
    }
}
