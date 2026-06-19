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
        XCTAssertEqual(snapshot.schedule, ScheduleEntry.defaultSchedule)
        XCTAssertEqual(snapshot.shortcuts, ShortcutBinding.defaultBindings)
    }

    func testDecodesLegacyHardwareSettingsSnapshot() throws {
        let legacyJSON = legacyHardwareSettingsJSON()

        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.selectedDisplay?.localizedName, "INNOS 27QA100M")
        XCTAssertEqual(decoded.state.display?.cgDisplayID, 42)
        XCTAssertEqual(decoded.state.targetBrightness, 45)
        XCTAssertEqual(decoded.state.targetWarmth, 32)
        XCTAssertEqual(decoded.state.activeMode, .overlay)
        XCTAssertTrue(decoded.state.automationPausedUntilNextBoundary)
        XCTAssertEqual(decoded.state.automationPausedAtMinuteOfDay, 600)
        XCTAssertEqual(decoded.state.automationResumeMinuteOfDay, 1_140)
        XCTAssertEqual(decoded.state.lastAppliedCommandSource, .menuSlider)
        XCTAssertEqual(decoded.schedule.first?.brightness, 45)
        XCTAssertEqual(decoded.shortcuts.first?.action, .brightnessDown)
    }

    func testDecodesLegacyForcedSoftwareCommandSourceAsStartupRestore() throws {
        let legacyJSON = legacyHardwareSettingsJSON(
            lastAppliedCommandSource: "forcedSoftwareTest",
            isForcedSoftwareModeForTesting: true
        )

        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.state.lastAppliedCommandSource, .startupRestore)
        XCTAssertEqual(decoded.state.targetBrightness, 45)
        XCTAssertEqual(decoded.schedule.first?.minuteOfDay, 600)
        XCTAssertEqual(decoded.shortcuts.first?.action, .brightnessDown)
    }

    func testDecodesUnknownCommandSourceAsStartupRestore() throws {
        let legacyJSON = legacyHardwareSettingsJSON(lastAppliedCommandSource: "diagnosticProbe")

        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.state.lastAppliedCommandSource, .startupRestore)
        XCTAssertEqual(decoded.state.targetWarmth, 32)
        XCTAssertEqual(decoded.shortcuts.first?.action, .brightnessDown)
    }

    func testStoreLoadMigratesLegacyHardwareSettingsSnapshot() throws {
        let defaults = UserDefaults(suiteName: "InnosDimmerTests.\(UUID().uuidString)")!
        let key = "snapshot"
        let legacyJSON = legacyHardwareSettingsJSON()
        defaults.set(Data(legacyJSON.utf8), forKey: key)
        let store = DisplayTargetStore(defaults: defaults, key: key)

        let loaded = store.load()

        XCTAssertEqual(loaded.schemaVersion, SettingsSnapshot.currentSchemaVersion)
        XCTAssertEqual(loaded.selectedDisplay?.localizedName, "INNOS 27QA100M")
        XCTAssertEqual(loaded.state.targetBrightness, 45)
        XCTAssertEqual(loaded.state.targetWarmth, 32)
        XCTAssertEqual(loaded.schedule.first?.minuteOfDay, 600)
        XCTAssertEqual(loaded.shortcuts.first?.action, .brightnessDown)
        XCTAssertEqual(loaded.shortcuts.first?.modifiers, [.option, .shift])
    }
}

private func legacyHardwareSettingsJSON(
    lastAppliedCommandSource: String = "menuSlider",
    isForcedSoftwareModeForTesting: Bool = false
) -> String {
    """
    {
      "schemaVersion": 1,
      "selectedDisplay": {
        "cgDisplayID": 42,
        "localizedName": "INNOS 27QA100M",
        "vendorNumber": 1,
        "modelNumber": 2,
        "serialNumber": 3,
        "frameDescription": "2560x1440@2x"
      },
      "state": {
        "display": {
          "cgDisplayID": 42,
          "localizedName": "INNOS 27QA100M",
          "vendorNumber": 1,
          "modelNumber": 2,
          "serialNumber": 3,
          "frameDescription": "2560x1440@2x"
        },
        "targetBrightness": 45,
        "targetWarmth": 32,
        "activeMode": "overlay",
        "hardwareCapability": { "unsupported": { "reason": "DDC unavailable" } },
        "lastHardwareProbeResult": null,
        "automationPausedUntilNextBoundary": true,
        "automationPausedAtMinuteOfDay": 600,
        "automationResumeMinuteOfDay": 1140,
        "lastAppliedCommandSource": "\(lastAppliedCommandSource)",
        "isForcedSoftwareModeForTesting": \(isForcedSoftwareModeForTesting)
      },
      "schedule": [
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "minuteOfDay": 600,
          "brightness": 45,
          "warmth": 32
        }
      ],
      "shortcuts": [
        {
          "action": "brightnessDown",
          "keyCode": 125,
          "modifiers": 3,
          "isEnabled": true
        }
      ]
    }
    """
}
