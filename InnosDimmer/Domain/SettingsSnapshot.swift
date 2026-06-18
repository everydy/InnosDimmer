import Foundation

struct SettingsSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var selectedDisplay: DisplayIdentity?
    var state: BrightnessState
    var schedule: [ScheduleEntry]
    var shortcuts: [ShortcutBinding]

    static func defaultSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            schemaVersion: currentSchemaVersion,
            selectedDisplay: nil,
            state: .defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: ShortcutBinding.defaultBindings
        )
    }

    func replacingSelectedDisplay(_ display: DisplayIdentity?) -> SettingsSnapshot {
        var snapshot = self
        snapshot.selectedDisplay = display
        snapshot.state.display = display
        return snapshot
    }

    func replacingSchedule(_ schedule: [ScheduleEntry]) -> SettingsSnapshot {
        var snapshot = self
        snapshot.schedule = Self.sortedSchedule(schedule)
        return snapshot
    }

    func replacingShortcuts(_ shortcuts: [ShortcutBinding]) -> SettingsSnapshot {
        var snapshot = self
        snapshot.shortcuts = shortcuts
        return snapshot
    }

    static func sortedSchedule(_ schedule: [ScheduleEntry]) -> [ScheduleEntry] {
        schedule.sorted { lhs, rhs in
            if lhs.minuteOfDay == rhs.minuteOfDay {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.minuteOfDay < rhs.minuteOfDay
        }
    }
}
