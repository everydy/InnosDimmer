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
        applySoftware(command)
    }

    func reapplyCurrentSoftwareState() {
        guard let display = state.display else {
            return
        }

        applySoftware(
            BrightnessCommand(
                display: display,
                brightness: state.targetBrightness,
                blueReduction: state.targetBlueReduction,
                source: state.lastAppliedCommandSource ?? .startupRestore
            )
        )
    }

    func clearStaleSoftwarePanels(activeDisplayIDs: Set<UInt32>) {
        softwareStrategy.clearStalePanels(activeDisplayIDs: activeDisplayIDs)
    }

    func clearCurrentSoftwareState() {
        guard let display = state.display else {
            return
        }

        do {
            try softwareStrategy.clear(display: display)
            lastSoftwareDimmingFailure = nil
            state.activeMode = .unknown
        } catch {
            let command = BrightnessCommand(
                display: display,
                brightness: state.targetBrightness,
                blueReduction: state.targetBlueReduction,
                source: state.lastAppliedCommandSource ?? .startupRestore
            )
            lastSoftwareDimmingFailure = SoftwareDimmingFailure(
                command: command,
                message: errorMessage(from: error)
            )
            state.activeMode = .platformBlocked
        }
    }

    private func applySoftware(_ command: BrightnessCommand) {
        do {
            try softwareStrategy.apply(command)
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
        state.targetBlueReduction = command.blueReduction
        state.lastAppliedCommandSource = command.source
    }

    private func errorMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return String(describing: error)
    }
}
