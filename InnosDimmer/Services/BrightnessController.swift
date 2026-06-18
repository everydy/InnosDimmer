import Foundation

@MainActor
final class BrightnessController {
    private(set) var state: BrightnessState
    private(set) var pendingCommand: BrightnessCommand?
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
        if let reason = forcedSoftwareActivationReason(for: command) {
            applySoftware(command, reason: reason)
            return
        }

        applySoftware(command, reason: .softwareOnly)
    }

    private func applySoftware(_ command: BrightnessCommand, reason: SoftwareActivationReason) {
        do {
            try softwareStrategy.apply(command, reason: reason)
            pendingCommand = nil
            recordApplied(command)
            state.activeMode = .overlay
        } catch SoftwareDimmingError.platformBlocked {
            state.activeMode = .platformBlocked
        } catch {
            state.activeMode = .platformBlocked
        }
    }

    private func recordApplied(_ command: BrightnessCommand) {
        state.display = command.display
        state.targetBrightness = command.brightness
        state.targetWarmth = command.warmth
        state.lastAppliedCommandSource = command.source
    }

    private func forcedSoftwareActivationReason(for command: BrightnessCommand) -> SoftwareActivationReason? {
        if state.isForcedSoftwareModeForTesting || command.source == .forcedSoftwareTest {
            return .forcedForDiagnostics
        }

        return nil
    }
}
