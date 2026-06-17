import Foundation

struct SettingsSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

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
}
