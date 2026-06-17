import Foundation

final class BrightnessController {
    private(set) var state: BrightnessState
    private let softwareStrategy: SoftwareDimmingStrategy

    init(
        state: BrightnessState = .defaultState(),
        softwareStrategy: SoftwareDimmingStrategy = SoftwareDimmingController()
    ) {
        self.state = state
        self.softwareStrategy = softwareStrategy
    }

    func applyPreviewState(_ state: BrightnessState) {
        self.state = state
    }

    func apply(_ command: BrightnessCommand) {
        guard let reason = softwareActivationReason(for: command) else {
            return
        }

        do {
            try softwareStrategy.apply(command, reason: reason)
            state.targetBrightness = command.brightness
            state.targetWarmth = command.warmth
            state.lastAppliedCommandSource = command.source
            state.activeMode = .overlay
        } catch SoftwareDimmingError.platformBlocked {
            state.activeMode = .platformBlocked
        } catch {
            state.activeMode = .platformBlocked
        }
    }

    private func softwareActivationReason(for command: BrightnessCommand) -> SoftwareActivationReason? {
        if state.isForcedSoftwareModeForTesting || command.source == .forcedSoftwareTest {
            return .forcedForDiagnostics
        }

        if state.hardwareCapability.isExhaustedFailure {
            return .hardwareExhausted(state.hardwareCapability)
        }

        return nil
    }
}
