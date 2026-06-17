import Foundation

final class BrightnessController {
    private(set) var state: BrightnessState

    init(state: BrightnessState = .defaultState()) {
        self.state = state
    }

    func applyPreviewState(_ state: BrightnessState) {
        self.state = state
    }
}
