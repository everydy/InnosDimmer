import Foundation

struct BrightnessState: Codable, Equatable {
    var display: DisplayIdentity?
    var targetBrightness: Int
    var targetWarmth: Int
    var activeMode: DimmingMode
    var hardwareCapability: HardwareCapability
    var automationPausedUntilNextBoundary: Bool
    var lastAppliedCommandSource: BrightnessCommandSource?
    var isForcedSoftwareModeForTesting: Bool

    init(
        display: DisplayIdentity?,
        targetBrightness: Int,
        targetWarmth: Int,
        activeMode: DimmingMode,
        hardwareCapability: HardwareCapability,
        automationPausedUntilNextBoundary: Bool,
        lastAppliedCommandSource: BrightnessCommandSource?,
        isForcedSoftwareModeForTesting: Bool
    ) {
        self.display = display
        self.targetBrightness = Clamped.percent(targetBrightness)
        self.targetWarmth = Clamped.percent(targetWarmth)
        self.activeMode = activeMode
        self.hardwareCapability = hardwareCapability
        self.automationPausedUntilNextBoundary = automationPausedUntilNextBoundary
        self.lastAppliedCommandSource = lastAppliedCommandSource
        self.isForcedSoftwareModeForTesting = isForcedSoftwareModeForTesting
    }

    static func defaultState() -> BrightnessState {
        BrightnessState(
            display: nil,
            targetBrightness: 80,
            targetWarmth: 12,
            activeMode: .unknown,
            hardwareCapability: .notProbed,
            automationPausedUntilNextBoundary: false,
            lastAppliedCommandSource: nil,
            isForcedSoftwareModeForTesting: false
        )
    }
}
