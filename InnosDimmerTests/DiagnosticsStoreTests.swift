import XCTest
@testable import InnosDimmer

final class DiagnosticsStoreTests: XCTestCase {
    func testDiagnosticsStoreRetainsMostRecentEvents() {
        let store = DiagnosticsStore(maxEvents: 2)

        store.record(.fixture(message: "first"))
        store.record(.fixture(message: "second"))
        store.record(.fixture(message: "third"))

        XCTAssertEqual(store.events.map(\.message), ["second", "third"])
    }

    func testDiagnosticsStoreRecordHelperReturnsAndExposesLatestEvent() {
        let store = DiagnosticsStore(maxEvents: 10)
        let timestamp = Date(timeIntervalSince1970: 42)

        let event = store.record(
            category: .display,
            message: "Selected display INNOS 27QA100M",
            severity: .warning,
            timestamp: timestamp
        )

        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.category, .display)
        XCTAssertEqual(event.message, "Selected display INNOS 27QA100M")
        XCTAssertEqual(event.severity, .warning)
        XCTAssertEqual(store.latestEvent, event)
    }

    func testDiagnosticsSnapshotIncludesStateAndRecentEvents() {
        var state = BrightnessState.defaultState()
        state.activeMode = .overlay
        let store = DiagnosticsStore(maxEvents: 10)
        store.record(.fixture(category: .softwareDimming, message: "Overlay active"))

        let snapshot = store.snapshot(
            selectedDisplay: .fixture(),
            state: state,
            matrixSummary: "not tested"
        )

        XCTAssertEqual(snapshot.selectedDisplay?.localizedName, "INNOS 27QA100M")
        XCTAssertEqual(snapshot.activeMode, .overlay)
        XCTAssertEqual(snapshot.matrixSummary, "not tested")
        XCTAssertEqual(snapshot.events.map(\.message), ["Overlay active"])
    }

    func testDiagnosticsExporterEncodesSnapshotWithoutSensitiveUserContent() throws {
        let snapshot = DiagnosticsSnapshot(
            exportedAt: Date(timeIntervalSince1970: 0),
            selectedDisplay: .fixture(),
            activeMode: .platformBlocked,
            matrixSummary: "platform blocked disclosed",
            events: [
                .fixture(category: .softwareDimming, message: "Overlay platform blocked")
            ]
        )

        let data = try DiagnosticsExporter.export(snapshot)
        let decoded = try JSONDecoder().decode(DiagnosticsSnapshot.self, from: data)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertFalse(json.contains("/Users/"))
        XCTAssertFalse(json.contains("Documents"))
    }
}

private extension DiagnosticsEvent {
    static func fixture(
        category: DiagnosticsCategory = .appLifecycle,
        message: String,
        severity: DiagnosticsSeverity = .info
    ) -> DiagnosticsEvent {
        DiagnosticsEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            category: category,
            message: message,
            severity: severity
        )
    }
}

private extension DisplayIdentity {
    static func fixture() -> DisplayIdentity {
        DisplayIdentity(
            cgDisplayID: 1,
            localizedName: "INNOS 27QA100M",
            vendorNumber: 1,
            modelNumber: 2,
            serialNumber: 3,
            frameDescription: "2560x1440"
        )
    }
}
