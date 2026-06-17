import Foundation

struct DDCBrightnessValue: Codable, Equatable {
    var current: Int
    var range: ClosedRange<Int>
}

enum DDCAdapterError: Error, Equatable {
    case readFailed
    case writeFailed
    case readbackMismatch
}

protocol DDCAdapter {
    func readBrightness(display: DisplayIdentity) throws -> DDCBrightnessValue
    func writeBrightness(_ value: Int, display: DisplayIdentity) throws
}

final class NoopDDCAdapter: DDCAdapter {
    func readBrightness(display: DisplayIdentity) throws -> DDCBrightnessValue {
        _ = display
        throw DDCAdapterError.readFailed
    }

    func writeBrightness(_ value: Int, display: DisplayIdentity) throws {
        _ = value
        _ = display
        throw DDCAdapterError.writeFailed
    }
}

struct ProbeResult: Codable, Equatable {
    var display: DisplayIdentity
    var attemptedAt: Date
    var capability: HardwareCapability
    var steps: [ProbeStep]
    var shouldRetryAutomatically: Bool
}

final class HardwareDDCController {
    private let adapter: DDCAdapter
    private let now: () -> Date

    init(adapter: DDCAdapter = NoopDDCAdapter(), now: @escaping () -> Date = Date.init) {
        self.adapter = adapter
        self.now = now
    }

    func probe(display: DisplayIdentity) -> ProbeResult {
        var steps: [ProbeStep] = [
            step(.identifyDisplay, .success(note: display.localizedName))
        ]

        let original: DDCBrightnessValue
        do {
            original = try adapter.readBrightness(display: display)
            steps.append(step(.readBrightness, .success(note: "\(original.current)")))
        } catch {
            steps.append(step(.readBrightness, .failed(reason: "brightness read failed")))
            steps.append(step(.classifyFailure, .success(note: "unsupported")))
            return ProbeResult(
                display: display,
                attemptedAt: now(),
                capability: .unsupported(reason: "brightness read failed"),
                steps: steps,
                shouldRetryAutomatically: false
            )
        }

        let testValue = Self.reversibleProbeValue(current: original.current, range: original.range)
        steps.append(step(.chooseReversibleValue, .success(note: "\(testValue)")))

        do {
            try adapter.writeBrightness(testValue, display: display)
            steps.append(step(.writeTestValue, .success(note: "\(testValue)")))
            let readback = try adapter.readBrightness(display: display)
            guard readback.current == testValue else {
                throw DDCAdapterError.readbackMismatch
            }
            steps.append(step(.readBackTestValue, .success(note: "\(readback.current)")))
            do {
                try adapter.writeBrightness(original.current, display: display)
                steps.append(step(.restoreOriginalValue, .success(note: "\(original.current)")))
            } catch {
                steps.append(step(.restoreOriginalValue, .failed(reason: "restore original brightness failed")))
                return ProbeResult(
                    display: display,
                    attemptedAt: now(),
                    capability: .failedWithError(message: "restore original brightness failed"),
                    steps: steps,
                    shouldRetryAutomatically: false
                )
            }
            return ProbeResult(
                display: display,
                attemptedAt: now(),
                capability: .writeReadbackSupported(range: original.range),
                steps: steps,
                shouldRetryAutomatically: false
            )
        } catch {
            do {
                try adapter.writeBrightness(original.current, display: display)
                steps.append(step(.restoreOriginalValue, .success(note: "\(original.current)")))
            } catch {
                steps.append(step(.restoreOriginalValue, .failed(reason: "restore original brightness failed")))
                steps.append(step(.classifyFailure, .failed(reason: "restore original brightness failed")))
                return ProbeResult(
                    display: display,
                    attemptedAt: now(),
                    capability: .failedWithError(message: "restore original brightness failed"),
                    steps: steps,
                    shouldRetryAutomatically: false
                )
            }
            steps.append(step(.classifyFailure, .failed(reason: "write/readback failed")))
            return ProbeResult(
                display: display,
                attemptedAt: now(),
                capability: .failedWithError(message: "write/readback failed"),
                steps: steps,
                shouldRetryAutomatically: false
            )
        }
    }

    static func reversibleProbeValue(current: Int, range: ClosedRange<Int>) -> Int {
        let normalizedCurrent = max(range.lowerBound, min(range.upperBound, current))
        let upward = min(range.upperBound, normalizedCurrent + 1)
        if upward != normalizedCurrent {
            return upward
        }
        return max(range.lowerBound, normalizedCurrent - 1)
    }

    private func step(_ kind: ProbeStepKind, _ outcome: ProbeStepOutcome) -> ProbeStep {
        let timestamp = now()
        return ProbeStep(kind: kind, startedAt: timestamp, finishedAt: timestamp, outcome: outcome)
    }
}
