import Foundation

struct BrightnessState: Codable, Equatable {
    var display: DisplayIdentity?
    var targetBrightness: Int
    var targetWarmth: Int
    var activeMode: DimmingMode
    var automationPausedUntilNextBoundary: Bool
    var automationPausedAtMinuteOfDay: Int?
    var automationResumeMinuteOfDay: Int?
    var lastAppliedCommandSource: BrightnessCommandSource?
    var isForcedSoftwareModeForTesting: Bool

    init(
        display: DisplayIdentity?,
        targetBrightness: Int,
        targetWarmth: Int,
        activeMode: DimmingMode,
        automationPausedUntilNextBoundary: Bool,
        automationPausedAtMinuteOfDay: Int? = nil,
        automationResumeMinuteOfDay: Int? = nil,
        lastAppliedCommandSource: BrightnessCommandSource?,
        isForcedSoftwareModeForTesting: Bool
    ) {
        self.display = display
        self.targetBrightness = Clamped.percent(targetBrightness)
        self.targetWarmth = Clamped.percent(targetWarmth)
        self.activeMode = activeMode
        self.automationPausedUntilNextBoundary = automationPausedUntilNextBoundary
        self.automationPausedAtMinuteOfDay = automationPausedAtMinuteOfDay.map { max(0, min(1_439, $0)) }
        self.automationResumeMinuteOfDay = automationResumeMinuteOfDay.map { max(0, min(1_439, $0)) }
        self.lastAppliedCommandSource = lastAppliedCommandSource
        self.isForcedSoftwareModeForTesting = isForcedSoftwareModeForTesting
    }

    static func defaultState() -> BrightnessState {
        BrightnessState(
            display: nil,
            targetBrightness: 80,
            targetWarmth: 12,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: false,
            automationPausedAtMinuteOfDay: nil,
            automationResumeMinuteOfDay: nil,
            lastAppliedCommandSource: nil,
            isForcedSoftwareModeForTesting: false
        )
    }
}
