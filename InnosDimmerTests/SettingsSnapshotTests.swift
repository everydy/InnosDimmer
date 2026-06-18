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

    func testReplacingSelectedDisplayUpdatesSnapshotAndStateDisplay() {
        let display = DisplayIdentity(
            cgDisplayID: 42,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440@2x"
        )

        let snapshot = SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay(display)

        XCTAssertEqual(snapshot.selectedDisplay, display)
        XCTAssertEqual(snapshot.state.display, display)
    }

    func testReplacingScheduleStoresEntriesByMinuteOfDay() {
        let late = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            minuteOfDay: 1_380,
            brightness: 25,
            warmth: 58
        )
        let early = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            minuteOfDay: 540,
            brightness: 80,
            warmth: 12
        )
        let evening = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            minuteOfDay: 1_140,
            brightness: 45,
            warmth: 32
        )

        let snapshot = SettingsSnapshot.defaultSnapshot().replacingSchedule([late, early, evening])

        XCTAssertEqual(snapshot.schedule, [early, evening, late])
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
