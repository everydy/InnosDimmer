import Foundation

struct SoftwareDimmingFailure: Equatable {
    var command: BrightnessCommand
    var message: String
}

@MainActor
final class BrightnessController {
    private(set) var state: BrightnessState
    private(set) var lastSoftwareDimmingFailure: SoftwareDimmingFailure?
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

    func reapplyCurrentSoftwareState() {
        guard let display = state.display else {
            return
        }

        applySoftware(
            BrightnessCommand(
                display: display,
                brightness: state.targetBrightness,
                warmth: state.targetWarmth,
                source: state.lastAppliedCommandSource ?? .startupRestore
            ),
            reason: .softwareOnly
        )
    }

    func clearStaleSoftwarePanels(activeDisplayIDs: Set<UInt32>) {
        softwareStrategy.clearStalePanels(activeDisplayIDs: activeDisplayIDs)
    }

    private func applySoftware(_ command: BrightnessCommand, reason: SoftwareActivationReason) {
        do {
            try softwareStrategy.apply(command, reason: reason)
            lastSoftwareDimmingFailure = nil
            recordApplied(command)
            state.activeMode = .overlay
        } catch let SoftwareDimmingError.platformBlocked(reason) {
            lastSoftwareDimmingFailure = SoftwareDimmingFailure(
                command: command,
                message: reason
            )
            state.activeMode = .platformBlocked
        } catch {
            lastSoftwareDimmingFailure = SoftwareDimmingFailure(
                command: command,
                message: errorMessage(from: error)
            )
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

    private func errorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return String(describing: error)
    }
}
