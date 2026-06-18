import AppKit

struct OverlayAppearance: Equatable {
    var blackOpacity: CGFloat
    var warmOpacity: CGFloat
    private static let minimumVisibleBrightness = 10

    static func make(brightness: Int, warmth: Int) -> OverlayAppearance {
        let clampedBrightness = Clamped.percent(brightness)
        let visualBrightness = max(minimumVisibleBrightness, clampedBrightness)
        let clampedWarmth = Clamped.percent(warmth)
        return OverlayAppearance(
            blackOpacity: CGFloat(100 - visualBrightness) / 130.0,
            warmOpacity: CGFloat(clampedWarmth) / 180.0
        )
    }
}

@MainActor
final class OverlayWindowManager {
    typealias DisplayFrameProvider = @MainActor (DisplayIdentity) -> CGRect?

    private var panelsByDisplayID: [UInt32: NSPanel] = [:]
    private let displayFrameProvider: DisplayFrameProvider

    init(displayFrameProvider: @escaping DisplayFrameProvider = OverlayWindowManager.screenFrame(for:)) {
        self.displayFrameProvider = displayFrameProvider
    }

    static func configureOverlayPanel(_ panel: NSPanel, for frame: CGRect) {
        panel.setFrame(frame, display: true)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
    }

    func apply(display: DisplayIdentity, brightness: Int, warmth: Int) {
        guard let frame = displayFrameProvider(display) else {
            return
        }

        let panel = panelsByDisplayID[display.cgDisplayID] ?? makePanel()
        panelsByDisplayID[display.cgDisplayID] = panel
        Self.configureOverlayPanel(panel, for: frame)
        panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
        let appearance = OverlayAppearance.make(brightness: brightness, warmth: warmth)
        updateLayers(for: panel, appearance: appearance)
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
    }

    func clear(display: DisplayIdentity) {
        panelsByDisplayID[display.cgDisplayID]?.orderOut(nil)
        panelsByDisplayID.removeValue(forKey: display.cgDisplayID)
    }

    func clearPanels(excluding activeDisplayIDs: Set<UInt32>) {
        for displayID in Array(panelsByDisplayID.keys) where !activeDisplayIDs.contains(displayID) {
            panelsByDisplayID[displayID]?.orderOut(nil)
            panelsByDisplayID.removeValue(forKey: displayID)
        }
    }

    func managedDisplayIDsForTesting() -> Set<UInt32> {
        Set(panelsByDisplayID.keys)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        panel.contentView = NSView(frame: .zero)
        panel.contentView?.wantsLayer = true
        Self.configureOverlayPanel(panel, for: .zero)
        installOverlayLayers(in: panel)
        return panel
    }

    private static func screenFrame(for display: DisplayIdentity) -> CGRect? {
        NSScreen.screens.first { screen in
            screenDisplayID(screen) == display.cgDisplayID
        }?.frame
    }

    private static func screenDisplayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return number.uint32Value
    }

    private func installOverlayLayers(in panel: NSPanel) {
        guard let contentView = panel.contentView else {
            return
        }

        let dimLayer = CALayer()
        dimLayer.name = "InnosDimmer.dim"
        let warmLayer = CALayer()
        warmLayer.name = "InnosDimmer.warm"
        contentView.layer?.addSublayer(dimLayer)
        contentView.layer?.addSublayer(warmLayer)
    }

    private func updateLayers(for panel: NSPanel, appearance: OverlayAppearance) {
        guard let contentView = panel.contentView, let rootLayer = contentView.layer else {
            return
        }

        rootLayer.sublayers?.forEach { layer in
            layer.frame = contentView.bounds
            if layer.name == "InnosDimmer.dim" {
                layer.backgroundColor = NSColor.black.withAlphaComponent(appearance.blackOpacity).cgColor
            } else if layer.name == "InnosDimmer.warm" {
                layer.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.64, blue: 0.32, alpha: appearance.warmOpacity).cgColor
            }
        }
    }
}
