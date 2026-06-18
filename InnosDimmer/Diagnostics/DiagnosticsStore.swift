import Foundation

enum DiagnosticsCategory: String, Codable, Equatable {
    case appLifecycle
    case display
    case hardwareProbe
    case softwareDimming
    case schedule
    case shortcut
    case loginItem
}

enum DiagnosticsSeverity: String, Codable, Equatable {
    case info
    case warning
    case error
}

struct DiagnosticsEvent: Codable, Equatable {
    var timestamp: Date
    var category: DiagnosticsCategory
    var message: String
    var severity: DiagnosticsSeverity
}

struct DiagnosticsSnapshot: Codable, Equatable {
    var exportedAt: Date
    var selectedDisplay: DisplayIdentity?
    var hardwareCapability: HardwareCapability
    var activeMode: DimmingMode
    var matrixSummary: String
    var events: [DiagnosticsEvent]
}

final class DiagnosticsStore {
    private let maxEvents: Int
    private(set) var events: [DiagnosticsEvent] = []
    var latestEvent: DiagnosticsEvent? {
        events.last
    }

    init(maxEvents: Int = 200) {
        self.maxEvents = max(1, maxEvents)
    }

    func record(_ event: DiagnosticsEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    @discardableResult
    func record(
        category: DiagnosticsCategory,
        message: String,
        severity: DiagnosticsSeverity = .info,
        timestamp: Date = Date()
    ) -> DiagnosticsEvent {
        let event = DiagnosticsEvent(
            timestamp: timestamp,
            category: category,
            message: message,
            severity: severity
        )
        record(event)
        return event
    }

    func snapshot(
        selectedDisplay: DisplayIdentity?,
        state: BrightnessState,
        matrixSummary: String,
        exportedAt: Date = Date()
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            exportedAt: exportedAt,
            selectedDisplay: selectedDisplay,
            hardwareCapability: state.hardwareCapability,
            activeMode: state.activeMode,
            matrixSummary: matrixSummary,
            events: events
        )
    }
}
