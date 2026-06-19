import Foundation

enum BrightnessCommandSource: String, Codable, Equatable {
    case menuSlider
    case hotkey
    case schedule
    case startupRestore

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BrightnessCommandSource(rawValue: raw) ?? .startupRestore
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct BrightnessCommand: Codable, Equatable {
    var display: DisplayIdentity
    var brightness: Int
    var blueReduction: Int
    var source: BrightnessCommandSource
    var issuedAt: Date

    private enum CodingKeys: String, CodingKey {
        case display
        case brightness
        case blueReduction
        case legacyWarmth = "warmth"
        case source
        case issuedAt
    }

    init(display: DisplayIdentity, brightness: Int, blueReduction: Int, source: BrightnessCommandSource, issuedAt: Date = Date()) {
        self.display = display
        self.brightness = Clamped.percent(brightness)
        self.blueReduction = Clamped.percent(blueReduction)
        self.source = source
        self.issuedAt = issuedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        display = try container.decode(DisplayIdentity.self, forKey: .display)
        brightness = Clamped.percent(try container.decode(Int.self, forKey: .brightness))
        blueReduction = Clamped.percent(
            try container.decodeIfPresent(Int.self, forKey: .blueReduction)
                ?? container.decodeIfPresent(Int.self, forKey: .legacyWarmth)
                ?? 0
        )
        source = try container.decode(BrightnessCommandSource.self, forKey: .source)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(display, forKey: .display)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(blueReduction, forKey: .blueReduction)
        try container.encode(source, forKey: .source)
        try container.encode(issuedAt, forKey: .issuedAt)
    }
}
