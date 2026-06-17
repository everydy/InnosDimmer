import XCTest
@testable import InnosDimmer

final class SettingsSnapshotTests: XCTestCase {
    func testSettingsSnapshotRoundTripsShortcutBindingsThroughJSON() throws {
        let display = DisplayIdentity(
            cgDisplayID: 42,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440@2x"
        )
        let snapshot = SettingsSnapshot(
            schemaVersion: SettingsSnapshot.currentSchemaVersion,
            selectedDisplay: display,
            state: BrightnessState.defaultState(),
            schedule: ScheduleEntry.defaultSchedule,
            shortcuts: [
                ShortcutBinding(
                    action: .brightnessUp,
                    keyCode: 126,
                    modifiers: [.option, .shift],
                    isEnabled: true
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testDisplayTargetStoreFallsBackToDefaultSnapshotWhenEmpty() {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let store = DisplayTargetStore(defaults: defaults, key: "snapshot")

        let snapshot = store.load()

        XCTAssertEqual(snapshot.schemaVersion, SettingsSnapshot.currentSchemaVersion)
        XCTAssertFalse(snapshot.state.isForcedSoftwareModeForTesting)
        XCTAssertEqual(snapshot.schedule, ScheduleEntry.defaultSchedule)
        XCTAssertEqual(snapshot.shortcuts, ShortcutBinding.defaultBindings)
    }
}
