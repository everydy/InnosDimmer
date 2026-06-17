import Foundation

struct ScheduleEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var minuteOfDay: Int
    var brightness: Int
    var warmth: Int

    init(id: UUID = UUID(), minuteOfDay: Int, brightness: Int, warmth: Int) {
        self.id = id
        self.minuteOfDay = max(0, min(1_439, minuteOfDay))
        self.brightness = Clamped.percent(brightness)
        self.warmth = Clamped.percent(warmth)
    }

    static let defaultSchedule: [ScheduleEntry] = [
        ScheduleEntry(minuteOfDay: 540, brightness: 80, warmth: 12),
        ScheduleEntry(minuteOfDay: 1_140, brightness: 45, warmth: 32),
        ScheduleEntry(minuteOfDay: 1_380, brightness: 25, warmth: 58)
    ]
}
