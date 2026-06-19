import XCTest
@testable import InnosDimmer

final class ScheduleEntryTests: XCTestCase {
    func testScheduleEntryClampsValuesAndBoundsMinuteOfDay() {
        let entry = ScheduleEntry(minuteOfDay: 1_900, brightness: -1, blueReduction: 120)

        XCTAssertEqual(entry.minuteOfDay, 1_439)
        XCTAssertEqual(entry.brightness, 0)
        XCTAssertEqual(entry.blueReduction, 100)
    }

    func testDefaultScheduleIsSortedAndContainsBrightnessAndBlueReduction() {
        let schedule = ScheduleEntry.defaultSchedule

        XCTAssertEqual(schedule.map(\.minuteOfDay), [540, 1_140, 1_380])
        XCTAssertEqual(schedule.map(\.brightness), [80, 45, 25])
        XCTAssertEqual(schedule.map(\.blueReduction), [12, 32, 58])
    }
}
