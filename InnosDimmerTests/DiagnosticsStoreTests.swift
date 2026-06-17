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

    func testDiagnosticsSnapshotIncludesStateAndRecentEvents() {
        var state = BrightnessState.defaultState()
        state.hardwareCapability = .unsupported(reason: "brightness read failed")
        state.activeMode = .overlay
        let store = DiagnosticsStore(maxEvents: 10)
        store.record(.fixture(category: .hardwareProbe, message: "DDC unsupported"))

        let snapshot = store.snapshot(
            selectedDisplay: .fixture(),
            state: state,
            matrixSummary: "not tested"
        )

        XCTAssertEqual(snapshot.selectedDisplay?.localizedName, "INNOS 27QA100M")
        XCTAssertEqual(snapshot.hardwareCapability, .unsupported(reason: "brightness read failed"))
        XCTAssertEqual(snapshot.activeMode, .overlay)
        XCTAssertEqual(snapshot.matrixSummary, "not tested")
        XCTAssertEqual(snapshot.events.map(\.message), ["DDC unsupported"])
    }

    func testDiagnosticsExporterEncodesSnapshotWithoutSensitiveUserContent() throws {
        let snapshot = DiagnosticsSnapshot(
            exportedAt: Date(timeIntervalSince1970: 0),
            selectedDisplay: .fixture(),
            hardwareCapability: .blockedByPlatform(reason: "protected surface"),
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
