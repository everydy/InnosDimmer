import XCTest
@testable import InnosDimmer

final class ScheduleEngineTests: XCTestCase {
    func testActiveEntryUsesLatestEntryBeforeMinuteAcrossMidnight() {
        let entries = [
            ScheduleEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000019")!, minuteOfDay: 1_140, brightness: 45, warmth: 32),
            ScheduleEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!, minuteOfDay: 540, brightness: 80, warmth: 12),
            ScheduleEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000023")!, minuteOfDay: 1_380, brightness: 25, warmth: 58)
        ]

        XCTAssertEqual(ScheduleEngine.activeEntry(at: 1_200, entries: entries)?.minuteOfDay, 1_140)
        XCTAssertEqual(ScheduleEngine.activeEntry(at: 30, entries: entries)?.minuteOfDay, 1_380)
    }

    func testNextBoundaryUsesSortedEntriesAndWrapsAtMidnight() {
        let entries = [
            ScheduleEntry(minuteOfDay: 1_380, brightness: 25, warmth: 58),
            ScheduleEntry(minuteOfDay: 540, brightness: 80, warmth: 12),
            ScheduleEntry(minuteOfDay: 1_140, brightness: 45, warmth: 32)
        ]

        XCTAssertEqual(ScheduleEngine.nextBoundary(after: 800, entries: entries), 1_140)
        XCTAssertEqual(ScheduleEngine.nextBoundary(after: 1_400, entries: entries), 540)
    }

    func testMinutesUntilNextBoundarySupportsTargetedTimer() {
        XCTAssertEqual(ScheduleEngine.minutesUntilNextBoundary(after: 1_130, entries: ScheduleEntry.defaultSchedule), 10)
        XCTAssertEqual(ScheduleEngine.minutesUntilNextBoundary(after: 1_400, entries: ScheduleEntry.defaultSchedule), 580)
    }

    func testEmptyScheduleProducesIdleDecision() {
        let decision = ScheduleEngine.decision(
            at: 800,
            entries: [],
            state: .defaultState()
        )

        XCTAssertEqual(decision, .idle)
    }

    func testOneEntryScheduleAppliesSingleEntryAndUsesSameBoundary() {
        let entry = ScheduleEntry(minuteOfDay: 540, brightness: 80, warmth: 12)

        let decision = ScheduleEngine.decision(
            at: 800,
            entries: [entry],
            state: .defaultState()
        )

        XCTAssertEqual(decision, .apply(entry: entry, nextBoundaryMinuteOfDay: 540, clearsManualOverride: false))
    }

    func testManualOverridePausesUntilStoredNextBoundary() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_000
        state.automationResumeMinuteOfDay = 1_140

        let paused = ScheduleEngine.decision(
            at: 1_000,
            entries: ScheduleEntry.defaultSchedule,
            state: state
        )
        let resumed = ScheduleEngine.decision(
            at: 1_140,
            entries: ScheduleEntry.defaultSchedule,
            state: state
        )

        XCTAssertEqual(paused, .paused(untilMinuteOfDay: 1_140))
        XCTAssertEqual(
            resumed,
            .apply(
                entry: ScheduleEntry.defaultSchedule[1],
                nextBoundaryMinuteOfDay: 1_380,
                clearsManualOverride: true
            )
        )
    }

    func testManualOverrideResumesWhenWakeMissesExactBoundary() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_000
        state.automationResumeMinuteOfDay = 1_140

        let decision = ScheduleEngine.decision(
            at: 1_200,
            entries: ScheduleEntry.defaultSchedule,
            state: state
        )

        XCTAssertEqual(
            decision,
            .apply(
                entry: ScheduleEntry.defaultSchedule[1],
                nextBoundaryMinuteOfDay: 1_380,
                clearsManualOverride: true
            )
        )
    }

    func testManualOverrideAcrossMidnightStaysPausedBeforeMorningBoundary() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_400
        state.automationResumeMinuteOfDay = 540

        let beforeBoundary = ScheduleEngine.decision(
            at: 30,
            entries: ScheduleEntry.defaultSchedule,
            state: state
        )
        let afterBoundary = ScheduleEngine.decision(
            at: 600,
            entries: ScheduleEntry.defaultSchedule,
            state: state
        )

        XCTAssertEqual(beforeBoundary, .paused(untilMinuteOfDay: 540))
        XCTAssertEqual(
            afterBoundary,
            .apply(
                entry: ScheduleEntry.defaultSchedule[0],
                nextBoundaryMinuteOfDay: 1_140,
                clearsManualOverride: true
            )
        )
    }

    func testManualOverrideStateStoresNextBoundary() {
        let state = ScheduleEngine.stateAfterManualOverride(
            from: .defaultState(),
            at: 1_000,
            entries: ScheduleEntry.defaultSchedule
        )

        XCTAssertTrue(state.automationPausedUntilNextBoundary)
        XCTAssertEqual(state.automationPausedAtMinuteOfDay, 1_000)
        XCTAssertEqual(state.automationResumeMinuteOfDay, 1_140)
    }

    func testApplyingResumeDecisionClearsManualOverrideState() {
        var state = BrightnessState.defaultState()
        state.automationPausedUntilNextBoundary = true
        state.automationPausedAtMinuteOfDay = 1_000
        state.automationResumeMinuteOfDay = 1_140

        let updated = ScheduleEngine.stateAfterApplying(
            .apply(
                entry: ScheduleEntry.defaultSchedule[1],
                nextBoundaryMinuteOfDay: 1_380,
                clearsManualOverride: true
            ),
            to: state
        )

        XCTAssertFalse(updated.automationPausedUntilNextBoundary)
        XCTAssertNil(updated.automationPausedAtMinuteOfDay)
        XCTAssertNil(updated.automationResumeMinuteOfDay)
    }
}
