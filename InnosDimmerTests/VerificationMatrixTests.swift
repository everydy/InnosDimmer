import XCTest
@testable import InnosDimmer

final class VerificationMatrixTests: XCTestCase {
    func testDefaultRowsCoverEveryScenarioAsNotTested() {
        let rows = VerificationMatrix.defaultRows

        XCTAssertEqual(rows.map(\.id), VerificationScenario.allCases)
        XCTAssertTrue(rows.allSatisfy { $0.status == .notTested })
    }

    func testUpdatingRowChangesStatusNoteAndTimestamp() {
        let now = Date(timeIntervalSince1970: 10)
        let rows = VerificationMatrix.update(
            VerificationMatrix.defaultRows,
            scenario: .browserFullScreenVideo,
            status: .partial,
            note: "Overlay dims video but needs DRM check",
            checkedAt: now
        )

        let row = rows.first { $0.id == .browserFullScreenVideo }

        XCTAssertEqual(row?.status, .partial)
        XCTAssertEqual(row?.note, "Overlay dims video but needs DRM check")
        XCTAssertEqual(row?.lastCheckedAt, now)
    }

    func testCannotClaimAllContextsWhenRowsAreNotTestedOrFailing() {
        XCTAssertFalse(VerificationMatrix.canClaimAllRequestedContextsHandled(VerificationMatrix.defaultRows))

        let failing = VerificationMatrix.update(
            VerificationMatrix.handledFixtureRows(),
            scenario: .hdmiReconnect,
            status: .fail,
            note: "Reconnect changes target",
            checkedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertFalse(VerificationMatrix.canClaimAllRequestedContextsHandled(failing))
    }

    func testCannotClaimAllContextsWhenAnyScenarioRowIsMissing() {
        let missingOne = VerificationMatrix.handledFixtureRows().filter { $0.id != .scheduleBoundary }

        XCTAssertFalse(VerificationMatrix.canClaimAllRequestedContextsHandled(missingOne))
    }

    func testPlatformBlockedCountsHandledOnlyWithVisibleNote() {
        let withoutNote = VerificationMatrix.update(
            VerificationMatrix.handledFixtureRows(),
            scenario: .drmProtectedPlayback,
            status: .platformBlocked,
            note: " ",
            checkedAt: Date(timeIntervalSince1970: 1)
        )
        let withNote = VerificationMatrix.update(
            VerificationMatrix.handledFixtureRows(),
            scenario: .drmProtectedPlayback,
            status: .platformBlocked,
            note: "Protected video prevents local overlay verification",
            checkedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertFalse(VerificationMatrix.canClaimAllRequestedContextsHandled(withoutNote))
        XCTAssertTrue(VerificationMatrix.canClaimAllRequestedContextsHandled(withNote))
    }
}

private extension VerificationMatrix {
    static func handledFixtureRows() -> [VerificationRow] {
        defaultRows.map { row in
            VerificationRow(
                id: row.id,
                status: .pass,
                lastCheckedAt: Date(timeIntervalSince1970: 1),
                note: "Verified \(row.id.rawValue)"
            )
        }
    }
}
