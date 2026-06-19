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
    var warmth: Int
    var source: BrightnessCommandSource
    var issuedAt: Date

    init(display: DisplayIdentity, brightness: Int, warmth: Int, source: BrightnessCommandSource, issuedAt: Date = Date()) {
        self.display = display
        self.brightness = Clamped.percent(brightness)
        self.warmth = Clamped.percent(warmth)
        self.source = source
        self.issuedAt = issuedAt
    }
}
