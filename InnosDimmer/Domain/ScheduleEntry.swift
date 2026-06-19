import Foundation

struct ScheduleEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var minuteOfDay: Int
    var brightness: Int
    var blueReduction: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case minuteOfDay
        case brightness
        case blueReduction
        case legacyWarmth = "warmth"
    }

    init(id: UUID = UUID(), minuteOfDay: Int, brightness: Int, blueReduction: Int) {
        self.id = id
        self.minuteOfDay = max(0, min(1_439, minuteOfDay))
        self.brightness = Clamped.percent(brightness)
        self.blueReduction = Clamped.percent(blueReduction)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        minuteOfDay = max(0, min(1_439, try container.decode(Int.self, forKey: .minuteOfDay)))
        brightness = Clamped.percent(try container.decode(Int.self, forKey: .brightness))
        blueReduction = Clamped.percent(
            try container.decodeIfPresent(Int.self, forKey: .blueReduction)
                ?? container.decodeIfPresent(Int.self, forKey: .legacyWarmth)
                ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(minuteOfDay, forKey: .minuteOfDay)
        try container.encode(brightness, forKey: .brightness)
        try container.encode(blueReduction, forKey: .blueReduction)
    }

    static let defaultSchedule: [ScheduleEntry] = [
        ScheduleEntry(minuteOfDay: 540, brightness: 80, blueReduction: 12),
        ScheduleEntry(minuteOfDay: 1_140, brightness: 45, blueReduction: 32),
        ScheduleEntry(minuteOfDay: 1_380, brightness: 25, blueReduction: 58)
    ]
}
