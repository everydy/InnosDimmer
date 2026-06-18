import Foundation

enum SoftwareActivationReason: Codable, Equatable {
    case softwareOnly
    case hardwareNotReady(HardwareCapability)
    case hardwareExhausted(HardwareCapability)
    case forcedForDiagnostics
    case platformBlocked(String)
}

enum SoftwareDimmingError: Error, Equatable {
    case platformBlocked(String)
    case applyFailed(String)
}

@MainActor
protocol SoftwareDimmingStrategy {
    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws
    func clear(display: DisplayIdentity) throws
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
        overlayWindowManager.apply(display: command.display, brightness: command.brightness, warmth: command.warmth)
    }

    func clear(display: DisplayIdentity) throws {
        overlayWindowManager.clear(display: display)
        try gammaDimmingController.clear(display: display)
    }
}
