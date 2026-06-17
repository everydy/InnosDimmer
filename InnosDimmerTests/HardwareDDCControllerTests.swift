import XCTest
@testable import InnosDimmer

final class HardwareDDCControllerTests: XCTestCase {
    func testReversibleProbeValueMovesWithinRange() {
        XCTAssertEqual(HardwareDDCController.reversibleProbeValue(current: 50, range: 0...100), 51)
        XCTAssertEqual(HardwareDDCController.reversibleProbeValue(current: 100, range: 0...100), 99)
        XCTAssertEqual(HardwareDDCController.reversibleProbeValue(current: 0, range: 0...100), 1)
    }

    func testSuccessfulProbeRestoresOriginalBrightnessAndEnablesHardware() {
        let adapter = FakeDDCAdapter(currentBrightness: 50)
        let controller = HardwareDDCController(adapter: adapter)

        let result = controller.probe(display: .fixture())

        XCTAssertEqual(result.capability, .writeReadbackSupported(range: 0...100))
        XCTAssertEqual(adapter.currentBrightness, 50)
        XCTAssertEqual(result.steps.map(\.kind), [
            .identifyDisplay,
            .readBrightness,
            .chooseReversibleValue,
            .writeTestValue,
            .readBackTestValue,
            .restoreOriginalValue
        ])
    }

    func testFailedReadClassifiesUnsupportedAndDoesNotRetryAutomatically() {
        let adapter = FakeDDCAdapter(currentBrightness: nil)
        let controller = HardwareDDCController(adapter: adapter)

        let result = controller.probe(display: .fixture())

        XCTAssertEqual(result.capability, .unsupported(reason: "brightness read failed"))
        XCTAssertFalse(result.shouldRetryAutomatically)
    }

    func testRestoreFailureIsReportedAsProbeFailure() {
        let adapter = FakeDDCAdapter(currentBrightness: 50)
        adapter.failRestoringOriginal = true
        let controller = HardwareDDCController(adapter: adapter)

        let result = controller.probe(display: .fixture())

        XCTAssertEqual(result.capability, .failedWithError(message: "restore original brightness failed"))
        XCTAssertTrue(result.steps.contains {
            $0.kind == .restoreOriginalValue && $0.outcome == .failed(reason: "restore original brightness failed")
        })
    }

    func testApplyHardwareWritesRequestedBrightness() throws {
        let adapter = FakeDDCAdapter(currentBrightness: 50)
        let controller = HardwareDDCController(adapter: adapter)

        try controller.applyHardware(BrightnessCommand(
            display: .fixture(),
            brightness: 42,
            warmth: 15,
            source: .menuSlider
        ))

        XCTAssertEqual(adapter.currentBrightness, 42)
    }
}

private final class FakeDDCAdapter: DDCAdapter {
    var currentBrightness: Int?
    var range: ClosedRange<Int> = 0...100
    var failRestoringOriginal = false

    init(currentBrightness: Int?) {
        self.currentBrightness = currentBrightness
    }

    func readBrightness(display: DisplayIdentity) throws -> DDCBrightnessValue {
        guard let currentBrightness else {
            throw DDCAdapterError.readFailed
        }
        return DDCBrightnessValue(current: currentBrightness, range: range)
    }

    func writeBrightness(_ value: Int, display: DisplayIdentity) throws {
        if failRestoringOriginal && value == 50 {
            throw DDCAdapterError.writeFailed
        }
        currentBrightness = value
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
