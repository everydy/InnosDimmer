import Foundation

struct BrightnessState: Codable, Equatable {
    var display: DisplayIdentity?
    var targetBrightness: Int
    var targetBlueReduction: Int
    var activeMode: DimmingMode
    var automationPausedUntilNextBoundary: Bool
    var automationPausedAtMinuteOfDay: Int?
    var automationResumeMinuteOfDay: Int?
    var lastAppliedCommandSource: BrightnessCommandSource?

    private enum CodingKeys: String, CodingKey {
        case display
        case targetBrightness
        case targetBlueReduction
        case legacyTargetWarmth = "targetWarmth"
        case activeMode
        case automationPausedUntilNextBoundary
        case automationPausedAtMinuteOfDay
        case automationResumeMinuteOfDay
        case lastAppliedCommandSource
    }

    init(
        display: DisplayIdentity?,
        targetBrightness: Int,
        targetBlueReduction: Int,
        activeMode: DimmingMode,
        automationPausedUntilNextBoundary: Bool,
        automationPausedAtMinuteOfDay: Int? = nil,
        automationResumeMinuteOfDay: Int? = nil,
        lastAppliedCommandSource: BrightnessCommandSource?
    ) {
        self.display = display
        self.targetBrightness = Clamped.percent(targetBrightness)
        self.targetBlueReduction = Clamped.percent(targetBlueReduction)
        self.activeMode = activeMode
        self.automationPausedUntilNextBoundary = automationPausedUntilNextBoundary
        self.automationPausedAtMinuteOfDay = automationPausedAtMinuteOfDay.map { max(0, min(1_439, $0)) }
        self.automationResumeMinuteOfDay = automationResumeMinuteOfDay.map { max(0, min(1_439, $0)) }
        self.lastAppliedCommandSource = lastAppliedCommandSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        display = try container.decodeIfPresent(DisplayIdentity.self, forKey: .display)
        targetBrightness = Clamped.percent(try container.decode(Int.self, forKey: .targetBrightness))
        targetBlueReduction = Clamped.percent(
            try container.decodeIfPresent(Int.self, forKey: .targetBlueReduction)
                ?? container.decodeIfPresent(Int.self, forKey: .legacyTargetWarmth)
                ?? 0
        )
        activeMode = try container.decode(DimmingMode.self, forKey: .activeMode)
        automationPausedUntilNextBoundary = try container.decode(Bool.self, forKey: .automationPausedUntilNextBoundary)
        automationPausedAtMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .automationPausedAtMinuteOfDay)
            .map { max(0, min(1_439, $0)) }
        automationResumeMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .automationResumeMinuteOfDay)
            .map { max(0, min(1_439, $0)) }
        lastAppliedCommandSource = try container.decodeIfPresent(BrightnessCommandSource.self, forKey: .lastAppliedCommandSource)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(display, forKey: .display)
        try container.encode(targetBrightness, forKey: .targetBrightness)
        try container.encode(targetBlueReduction, forKey: .targetBlueReduction)
        try container.encode(activeMode, forKey: .activeMode)
        try container.encode(automationPausedUntilNextBoundary, forKey: .automationPausedUntilNextBoundary)
        try container.encodeIfPresent(automationPausedAtMinuteOfDay, forKey: .automationPausedAtMinuteOfDay)
        try container.encodeIfPresent(automationResumeMinuteOfDay, forKey: .automationResumeMinuteOfDay)
        try container.encodeIfPresent(lastAppliedCommandSource, forKey: .lastAppliedCommandSource)
    }

    static func defaultState() -> BrightnessState {
        BrightnessState(
            display: nil,
            targetBrightness: 80,
            targetBlueReduction: 12,
            activeMode: .unknown,
            automationPausedUntilNextBoundary: false,
            automationPausedAtMinuteOfDay: nil,
            automationResumeMinuteOfDay: nil,
            lastAppliedCommandSource: nil
        )
    }
}
