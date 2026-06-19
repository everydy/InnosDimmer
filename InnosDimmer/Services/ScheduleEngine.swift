import Foundation

enum ScheduleDecision: Equatable {
    case apply(entry: ScheduleEntry, nextBoundaryMinuteOfDay: Int, clearsManualOverride: Bool)
    case paused(untilMinuteOfDay: Int?)
    case idle
}

enum ScheduleEngine {
    static func activeEntry(at minuteOfDay: Int, entries: [ScheduleEntry]) -> ScheduleEntry? {
        let sorted = sortedEntries(entries)
        guard !sorted.isEmpty else {
            return nil
        }

        let minute = normalizedMinute(minuteOfDay)
        return sorted.last { $0.minuteOfDay <= minute } ?? sorted.last
    }

    static func nextBoundary(after minuteOfDay: Int, entries: [ScheduleEntry]) -> Int? {
        let sorted = sortedEntries(entries)
        guard !sorted.isEmpty else {
            return nil
        }

        let minute = normalizedMinute(minuteOfDay)
        return sorted.first { $0.minuteOfDay > minute }?.minuteOfDay ?? sorted.first?.minuteOfDay
    }

    static func minutesUntilNextBoundary(after minuteOfDay: Int, entries: [ScheduleEntry]) -> Int? {
        guard let next = nextBoundary(after: minuteOfDay, entries: entries) else {
            return nil
        }

        let minute = normalizedMinute(minuteOfDay)
        if next > minute {
            return next - minute
        }
        return (1_440 - minute) + next
    }

    static func decision(at minuteOfDay: Int, entries: [ScheduleEntry], state: BrightnessState) -> ScheduleDecision {
        guard let active = activeEntry(at: minuteOfDay, entries: entries) else {
            return .idle
        }

        let next = nextBoundary(after: minuteOfDay, entries: entries)
        if state.automationPausedUntilNextBoundary {
            if hasReachedResumeBoundary(at: minuteOfDay, state: state) {
                return .apply(entry: active, nextBoundaryMinuteOfDay: next ?? active.minuteOfDay, clearsManualOverride: true)
            }
            return .paused(untilMinuteOfDay: state.automationResumeMinuteOfDay ?? next)
        }

        return .apply(entry: active, nextBoundaryMinuteOfDay: next ?? active.minuteOfDay, clearsManualOverride: false)
    }

    static func stateAfterManualOverride(from state: BrightnessState, at minuteOfDay: Int, entries: [ScheduleEntry]) -> BrightnessState {
        var updated = state
        updated.automationPausedUntilNextBoundary = true
        updated.automationPausedAtMinuteOfDay = normalizedMinute(minuteOfDay)
        updated.automationResumeMinuteOfDay = nextBoundary(after: minuteOfDay, entries: entries)
        return updated
    }

    static func stateAfterResumingAutomation(from state: BrightnessState) -> BrightnessState {
        var updated = state
        updated.automationPausedUntilNextBoundary = false
        updated.automationPausedAtMinuteOfDay = nil
        updated.automationResumeMinuteOfDay = nil
        return updated
    }

    static func stateAfterApplying(_ decision: ScheduleDecision, to state: BrightnessState) -> BrightnessState {
        guard case .apply(_, _, true) = decision else {
            return state
        }

        return stateAfterResumingAutomation(from: state)
    }

    private static func hasReachedResumeBoundary(at minuteOfDay: Int, state: BrightnessState) -> Bool {
        guard let resumeMinute = state.automationResumeMinuteOfDay else {
            return false
        }

        let current = normalizedMinute(minuteOfDay)
        guard let pausedAt = state.automationPausedAtMinuteOfDay else {
            return current == resumeMinute
        }

        if pausedAt < resumeMinute {
            return current >= resumeMinute || current < pausedAt
        }
        if pausedAt > resumeMinute {
            return current >= resumeMinute && current < pausedAt
        }
        return current == resumeMinute
    }

    private static func sortedEntries(_ entries: [ScheduleEntry]) -> [ScheduleEntry] {
        entries.sorted { lhs, rhs in
            if lhs.minuteOfDay == rhs.minuteOfDay {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.minuteOfDay < rhs.minuteOfDay
        }
    }

    private static func normalizedMinute(_ minuteOfDay: Int) -> Int {
        max(0, min(1_439, minuteOfDay))
    }
}

struct ScheduledScheduleBoundary: Equatable {
    var minuteOfDay: Int
    var minutesUntilBoundary: Int
    var interval: TimeInterval
    var tolerance: TimeInterval
}

@MainActor
protocol ScheduleTimerToken: AnyObject {
    func invalidate()
}

extension Timer: ScheduleTimerToken {}

@MainActor
final class ScheduleTimerController {
    typealias TimerFactory = @MainActor (
        _ interval: TimeInterval,
        _ tolerance: TimeInterval,
        _ fire: @escaping @MainActor () -> Void
    ) -> ScheduleTimerToken

    private var timer: ScheduleTimerToken?
    private let makeTimer: TimerFactory
    private(set) var scheduledBoundary: ScheduledScheduleBoundary?

    init(makeTimer: @escaping TimerFactory = ScheduleTimerController.defaultMakeTimer) {
        self.makeTimer = makeTimer
    }

    @discardableResult
    func scheduleNextBoundary(
        after minuteOfDay: Int,
        entries: [ScheduleEntry],
        fire: @escaping @MainActor () -> Void
    ) -> ScheduledScheduleBoundary? {
        timer?.invalidate()
        timer = nil
        scheduledBoundary = nil

        guard
            let minutesUntilBoundary = ScheduleEngine.minutesUntilNextBoundary(after: minuteOfDay, entries: entries),
            let nextBoundaryMinuteOfDay = ScheduleEngine.nextBoundary(after: minuteOfDay, entries: entries)
        else {
            return nil
        }

        let interval = TimeInterval(max(1, minutesUntilBoundary) * 60)
        let tolerance = min(60, interval * 0.1)
        let boundary = ScheduledScheduleBoundary(
            minuteOfDay: nextBoundaryMinuteOfDay,
            minutesUntilBoundary: minutesUntilBoundary,
            interval: interval,
            tolerance: tolerance
        )
        timer = makeTimer(interval, tolerance, fire)
        scheduledBoundary = boundary
        return boundary
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
        scheduledBoundary = nil
    }

    private static func defaultMakeTimer(
        interval: TimeInterval,
        tolerance: TimeInterval,
        fire: @escaping @MainActor () -> Void
    ) -> ScheduleTimerToken {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                fire()
            }
        }
        timer.tolerance = tolerance
        return timer
    }
}
