import XCTest
@testable import InnosDimmer

final class DisplayTargetStoreTests: XCTestCase {
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
