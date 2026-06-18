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

final class ScheduleRuntimeTests: XCTestCase {
    @MainActor
    func testTimerControllerSchedulesOneShotBoundaryAndInvalidatesReplacement() {
        let factory = RecordingScheduleTimerFactory()
        let controller = ScheduleTimerController(makeTimer: factory.makeTimer)

        let first = controller.scheduleNextBoundary(
            after: 1_130,
            entries: ScheduleEntry.defaultSchedule
        ) {}
        let second = controller.scheduleNextBoundary(
            after: 1_200,
            entries: ScheduleEntry.defaultSchedule
        ) {}

        XCTAssertEqual(first, ScheduledScheduleBoundary(minuteOfDay: 1_140, minutesUntilBoundary: 10, interval: 600, tolerance: 60))
        XCTAssertEqual(second, ScheduledScheduleBoundary(minuteOfDay: 1_380, minutesUntilBoundary: 180, interval: 10_800, tolerance: 60))
        XCTAssertEqual(factory.timers.count, 2)
        XCTAssertTrue(factory.timers[0].isInvalidated)
        XCTAssertFalse(factory.timers[1].isInvalidated)
    }

    @MainActor
    func testMenuBarControllerAppliesScheduleAtStartupAndTimerBoundary() {
        var currentMinute = 1_130
        let factory = RecordingScheduleTimerFactory()
        let scheduleTimer = ScheduleTimerController(makeTimer: factory.makeTimer)
        var state = BrightnessState.defaultState()
        state.display = .scheduleRuntimeTestDisplay
        let software = RecordingScheduleSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            scheduleTimerController: scheduleTimer,
            currentMinuteOfDay: { currentMinute }
        )

        menuBarController.start()

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.source), [.schedule])
        XCTAssertEqual(brightnessController.state.targetBrightness, 80)
        XCTAssertEqual(brightnessController.state.targetWarmth, 12)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .schedule)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)
        XCTAssertEqual(factory.timers.last?.interval, 600)

        currentMinute = 1_140
        factory.timers.last?.fire()

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.source), [.schedule, .schedule])
        XCTAssertEqual(brightnessController.state.targetBrightness, 45)
        XCTAssertEqual(brightnessController.state.targetWarmth, 32)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .schedule)
        XCTAssertEqual(factory.timers.last?.interval, 14_400)
    }

    @MainActor
    func testManualCommandPausesScheduleUntilNextBoundaryThenTimerResumesAutomation() {
        var currentMinute = 1_000
        let factory = RecordingScheduleTimerFactory()
        let scheduleTimer = ScheduleTimerController(makeTimer: factory.makeTimer)
        var state = BrightnessState.defaultState()
        state.display = .scheduleRuntimeTestDisplay
        let software = RecordingScheduleSoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            scheduleTimerController: scheduleTimer,
            currentMinuteOfDay: { currentMinute }
        )
        menuBarController.start()
        let startupTimer = factory.timers.last

        menuBarController.perform(.brightnessUp)

        XCTAssertTrue(startupTimer?.isInvalidated == true)
        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.source).suffix(1), [.menuSlider])
        XCTAssertTrue(brightnessController.state.automationPausedUntilNextBoundary)
        XCTAssertEqual(brightnessController.state.automationPausedAtMinuteOfDay, 1_000)
        XCTAssertEqual(brightnessController.state.automationResumeMinuteOfDay, 1_140)
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .menuSlider)

        currentMinute = 1_140
        factory.timers.last?.fire()

        XCTAssertNil(brightnessController.pendingCommand)
        XCTAssertEqual(software.appliedCommands.map(\.source).suffix(1), [.schedule])
        XCTAssertFalse(brightnessController.state.automationPausedUntilNextBoundary)
        XCTAssertNil(brightnessController.state.automationPausedAtMinuteOfDay)
        XCTAssertNil(brightnessController.state.automationResumeMinuteOfDay)
        XCTAssertEqual(brightnessController.state.targetBrightness, 45)
        XCTAssertEqual(brightnessController.state.targetWarmth, 32)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .schedule)
    }

    @MainActor
    func testHotkeyRegistrationDoesNotDisableScheduleRuntime() {
        let currentMinute = 1_000
        let factory = RecordingScheduleTimerFactory()
        let scheduleTimer = ScheduleTimerController(makeTimer: factory.makeTimer)
        let hotkeyBackend = ScheduleRuntimeHotkeyRegistrationBackend()
        var state = BrightnessState.defaultState()
        state.display = .scheduleRuntimeTestDisplay
        let brightnessController = BrightnessController(state: state)
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            hotkeyRegistrationBackend: hotkeyBackend,
            scheduleTimerController: scheduleTimer,
            currentMinuteOfDay: { currentMinute }
        )

        menuBarController.start()
        let startupTimer = factory.timers.last

        menuBarController.perform(.brightnessUp)

        XCTAssertEqual(hotkeyBackend.registeredBindings, ShortcutBinding.defaultBindings)
        XCTAssertTrue(startupTimer?.isInvalidated == true)
        XCTAssertGreaterThanOrEqual(factory.timers.count, 2)
        XCTAssertEqual(factory.timers.last?.interval, 8_400)
        XCTAssertTrue(brightnessController.state.automationPausedUntilNextBoundary)
        XCTAssertEqual(brightnessController.state.automationResumeMinuteOfDay, 1_140)
    }
}

@MainActor
private final class RecordingScheduleTimerFactory {
    private(set) var timers: [RecordingScheduleTimer] = []

    func makeTimer(
        interval: TimeInterval,
        tolerance: TimeInterval,
        fire: @escaping @MainActor () -> Void
    ) -> ScheduleTimerToken {
        let timer = RecordingScheduleTimer(interval: interval, tolerance: tolerance, fire: fire)
        timers.append(timer)
        return timer
    }
}

@MainActor
private final class RecordingScheduleTimer: ScheduleTimerToken {
    let interval: TimeInterval
    let tolerance: TimeInterval
    private let fireHandler: @MainActor () -> Void
    private(set) var isInvalidated = false

    init(interval: TimeInterval, tolerance: TimeInterval, fire: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.tolerance = tolerance
        fireHandler = fire
    }

    func invalidate() {
        isInvalidated = true
    }

    func fire() {
        fireHandler()
    }
}

private final class ScheduleRuntimeHotkeyRegistrationBackend: HotkeyRegistrationBackend {
    private(set) var registeredBindings: [ShortcutBinding]?

    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws {
        registeredBindings = bindings
        _ = handler
    }

    func unregisterAll() {
        registeredBindings = nil
    }
}

@MainActor
private final class RecordingScheduleSoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []

    func apply(_ command: BrightnessCommand, reason: SoftwareActivationReason) throws {
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {}
}

private extension DisplayIdentity {
    static let scheduleRuntimeTestDisplay = DisplayIdentity(
        cgDisplayID: 1,
        localizedName: "INNOS 27QA100M",
        vendorNumber: 1,
        modelNumber: 2,
        serialNumber: 3,
        frameDescription: "2560x1440"
    )
}
