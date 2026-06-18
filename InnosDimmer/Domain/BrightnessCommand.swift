import Foundation

enum BrightnessCommandSource: String, Codable, Equatable {
    case menuSlider
    case hotkey
    case schedule
    case startupRestore
    case forcedSoftwareTest
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
