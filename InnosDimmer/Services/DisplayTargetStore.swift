import Foundation

enum SettingsPersistenceError: Error, Equatable, LocalizedError {
    case emptySchedule
    case invalidShortcutBindings(HotkeyValidationReport)

    var errorDescription: String? {
        switch self {
        case .emptySchedule:
            return "Schedule must include at least one entry."
        case .invalidShortcutBindings(let report):
            let duplicateCount = report.duplicateSignatures.count
            let unsafeCount = report.unsafeBindings.count
            return "Shortcuts are invalid: \(duplicateCount) duplicate, \(unsafeCount) unsafe."
        }
    }
}

final class DisplayTargetStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "InnosDimmer.SettingsSnapshot") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> SettingsSnapshot {
        guard let data = defaults.data(forKey: key) else {
            return .defaultSnapshot()
        }

        guard let snapshot = try? decoder.decode(SettingsSnapshot.self, from: data),
              let validatedSnapshot = try? Self.validated(snapshot) else {
            return .defaultSnapshot()
        }

        return validatedSnapshot
    }

    func save(_ snapshot: SettingsSnapshot) throws {
        let data = try encoder.encode(Self.validated(snapshot))
        defaults.set(data, forKey: key)
    }

    @discardableResult
    func saveSelectedDisplay(_ display: DisplayIdentity?) throws -> SettingsSnapshot {
        let snapshot = load().replacingSelectedDisplay(display)
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func saveSchedule(_ schedule: [ScheduleEntry]) throws -> SettingsSnapshot {
        let snapshot = load().replacingSchedule(schedule)
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func saveShortcuts(_ shortcuts: [ShortcutBinding]) throws -> SettingsSnapshot {
        let snapshot = load().replacingShortcuts(shortcuts)
        try save(snapshot)
        return snapshot
    }

    func resolveSelectedDisplay(from candidates: [DisplayIdentity]) -> DisplayIdentity? {
        DisplayTargetResolver.resolve(saved: load().selectedDisplay, candidates: candidates)
    }

    private static func validated(_ snapshot: SettingsSnapshot) throws -> SettingsSnapshot {
        guard !snapshot.schedule.isEmpty else {
            throw SettingsPersistenceError.emptySchedule
        }

        let shortcutReport = HotkeyManager.validate(snapshot.shortcuts)
        guard shortcutReport.isValid else {
            throw SettingsPersistenceError.invalidShortcutBindings(shortcutReport)
        }

        var validatedSnapshot = snapshot
        validatedSnapshot.schemaVersion = SettingsSnapshot.currentSchemaVersion
        validatedSnapshot.schedule = SettingsSnapshot.sortedSchedule(snapshot.schedule)
        return validatedSnapshot
    }
}
