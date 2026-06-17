import Foundation

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

        return (try? decoder.decode(SettingsSnapshot.self, from: data)) ?? .defaultSnapshot()
    }

    func save(_ snapshot: SettingsSnapshot) throws {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: key)
    }

    func resolveSelectedDisplay(from candidates: [DisplayIdentity]) -> DisplayIdentity? {
        DisplayTargetResolver.resolve(saved: load().selectedDisplay, candidates: candidates)
    }
}
