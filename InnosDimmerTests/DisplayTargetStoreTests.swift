import XCTest
@testable import InnosDimmer

final class DisplayTargetStoreTests: XCTestCase {
    func testSaveSelectedDisplayPersistsSnapshotAndStateDisplay() throws {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let store = DisplayTargetStore(defaults: defaults, key: "snapshot")
        let display = DisplayIdentity(
            cgDisplayID: 10,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440"
        )

        let snapshot = try store.saveSelectedDisplay(display)

        XCTAssertEqual(snapshot.selectedDisplay, display)
        XCTAssertEqual(snapshot.state.display, display)
        XCTAssertEqual(store.load().selectedDisplay, display)
        XCTAssertEqual(store.load().state.display, display)
    }

    func testSaveScheduleSortsAndPersistsEntries() throws {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let store = DisplayTargetStore(defaults: defaults, key: "snapshot")
        let late = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            minuteOfDay: 1_380,
            brightness: 25,
            blueReduction: 58
        )
        let early = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            minuteOfDay: 540,
            brightness: 80,
            blueReduction: 12
        )
        let evening = ScheduleEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            minuteOfDay: 1_140,
            brightness: 45,
            blueReduction: 32
        )

        let snapshot = try store.saveSchedule([late, early, evening])

        XCTAssertEqual(snapshot.schedule, [early, evening, late])
        XCTAssertEqual(store.load().schedule, [early, evening, late])
    }

    func testSaveRejectsEmptySchedule() {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let store = DisplayTargetStore(defaults: defaults, key: "snapshot")

        XCTAssertThrowsError(try store.saveSchedule([])) { error in
            XCTAssertEqual(error as? SettingsPersistenceError, .emptySchedule)
        }
        XCTAssertEqual(store.load().schedule, ScheduleEntry.defaultSchedule)
    }

    func testSaveShortcutsRejectsUnsafeBindingsAndPreservesPreviousSnapshot() throws {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let store = DisplayTargetStore(defaults: defaults, key: "snapshot")
        let safeBindings = ShortcutBinding.defaultBindings.map { binding in
            binding.action == .brightnessUp
                ? ShortcutBinding(action: binding.action, keyCode: binding.keyCode, modifiers: binding.modifiers, isEnabled: false)
                : binding
        }
        try store.saveShortcuts(safeBindings)
        let unsafeBindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [], isEnabled: true)
        ]

        XCTAssertThrowsError(try store.saveShortcuts(unsafeBindings)) { error in
            XCTAssertEqual(
                error as? SettingsPersistenceError,
                .invalidShortcutBindings(
                    HotkeyValidationReport(duplicateSignatures: [], unsafeBindings: unsafeBindings)
                )
            )
        }
        XCTAssertEqual(store.load().shortcuts, safeBindings)
    }

    func testLoadFallsBackToDefaultSnapshotWhenPersistedSnapshotIsInvalid() throws {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let key = "snapshot"
        let invalidSnapshot = SettingsSnapshot.defaultSnapshot().replacingShortcuts([
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [], isEnabled: true)
        ])
        defaults.set(try JSONEncoder().encode(invalidSnapshot), forKey: key)
        let store = DisplayTargetStore(defaults: defaults, key: key)

        XCTAssertEqual(store.load(), SettingsSnapshot.defaultSnapshot())
    }

    func testResolvesSavedDisplayByStableHardwareIdentity() {
        let saved = DisplayIdentity(
            cgDisplayID: 10,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "old-frame"
        )
        let reconnected = DisplayIdentity(
            cgDisplayID: 99,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "new-frame"
        )

        XCTAssertEqual(DisplayTargetResolver.resolve(saved: saved, candidates: [reconnected]), reconnected)
    }

    func testDoesNotSilentlyMatchDifferentDisplayWithSameName() {
        let saved = DisplayIdentity(
            cgDisplayID: 10,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "old-frame"
        )
        let different = DisplayIdentity(
            cgDisplayID: 10,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 4,
            modelNumber: 5,
            serialNumber: 6,
            frameDescription: "same-cg-id-after-reconnect"
        )

        XCTAssertNil(DisplayTargetResolver.resolve(saved: saved, candidates: [different]))
    }

    func testZeroHardwareNumbersAreNotStableIdentity() {
        let identity = DisplayIdentity(
            cgDisplayID: 10,
            localizedName: "Unknown display",
            vendorNumber: 0,
            modelNumber: 0,
            serialNumber: 0,
            frameDescription: "frame"
        )

        XCTAssertFalse(identity.hasStableHardwareIdentity)
    }
}
