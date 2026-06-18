import Foundation

enum SoftwareActivationReason: Codable, Equatable {
    case softwareOnly
    case forcedForDiagnostics
    case platformBlocked(String)
}

enum SoftwareDimmingError: Error, Equatable, LocalizedError {
    case displayUnavailable(UInt32)
    case platformBlocked(String)
    case applyFailed(String)

    var errorDescription: String? {
        switch self {
        case .displayUnavailable(let displayID):
            return "Display \(displayID) is not currently available for software dimming."
        case .platformBlocked(let reason), .applyFailed(let reason):
            return reason
        }
    }
}

@MainActor
protocol SoftwareDimmingStrategy {
    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws
    func clear(display: DisplayIdentity) throws
    func clearStalePanels(activeDisplayIDs: Set<UInt32>)
}

extension SoftwareDimmingStrategy {
    func clearStalePanels(activeDisplayIDs: Set<UInt32>) {
        _ = activeDisplayIDs
    }
}

@MainActor
final class SoftwareDimmingController: SoftwareDimmingStrategy {
    private let overlayWindowManager: OverlayWindowManager
    private let gammaDimmingController: GammaDimmingController

    init(
        overlayWindowManager: OverlayWindowManager = OverlayWindowManager(),
        gammaDimmingController: GammaDimmingController = GammaDimmingController()
    ) {
        self.overlayWindowManager = overlayWindowManager
        self.gammaDimmingController = gammaDimmingController
    }

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        _ = reason
        try gammaDimmingController.apply(display: command.display, blueReduction: command.warmth)
        do {
            try overlayWindowManager.apply(display: command.display, brightness: command.brightness, warmth: 0)
        } catch {
            try? gammaDimmingController.clear(display: command.display)
            throw error
        }
    }

    func clear(display: DisplayIdentity) throws {
        overlayWindowManager.clear(display: display)
        try gammaDimmingController.clear(display: display)
    }

    func clearStalePanels(activeDisplayIDs: Set<UInt32>) {
        overlayWindowManager.clearPanels(excluding: activeDisplayIDs)
        gammaDimmingController.clearTables(excluding: activeDisplayIDs)
    }
}
