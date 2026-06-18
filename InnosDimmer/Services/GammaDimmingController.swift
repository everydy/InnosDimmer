import CoreGraphics
import Foundation

struct GammaTableSnapshot: Equatable {
    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]

    var sampleCount: UInt32 {
        UInt32(red.count)
    }
}

protocol GammaTableControlling {
    func capacity(for displayID: CGDirectDisplayID) -> UInt32
    func read(displayID: CGDirectDisplayID, capacity: UInt32) throws -> GammaTableSnapshot
    func set(displayID: CGDirectDisplayID, table: GammaTableSnapshot) throws
}

final class CoreGraphicsGammaTableController: GammaTableControlling {
    func capacity(for displayID: CGDirectDisplayID) -> UInt32 {
        CGDisplayGammaTableCapacity(displayID)
    }

    func read(displayID: CGDirectDisplayID, capacity: UInt32) throws -> GammaTableSnapshot {
        guard capacity > 0 else {
            throw SoftwareDimmingError.applyFailed("Display \(displayID) has no gamma table capacity.")
        }

        var red = Array<CGGammaValue>(repeating: 0, count: Int(capacity))
        var green = Array<CGGammaValue>(repeating: 0, count: Int(capacity))
        var blue = Array<CGGammaValue>(repeating: 0, count: Int(capacity))
        var sampleCount: UInt32 = 0
        let status = CGGetDisplayTransferByTable(displayID, capacity, &red, &green, &blue, &sampleCount)
        guard status == .success, sampleCount > 0 else {
            throw SoftwareDimmingError.applyFailed(
                "Could not read gamma table for display \(displayID): status \(status.rawValue)."
            )
        }

        let count = Int(sampleCount)
        return GammaTableSnapshot(
            red: Array(red.prefix(count)),
            green: Array(green.prefix(count)),
            blue: Array(blue.prefix(count))
        )
    }

    func set(displayID: CGDirectDisplayID, table: GammaTableSnapshot) throws {
        guard table.red.count == table.green.count,
              table.red.count == table.blue.count,
              !table.red.isEmpty else {
            throw SoftwareDimmingError.applyFailed("Invalid gamma table for display \(displayID).")
        }

        var red = table.red
        var green = table.green
        var blue = table.blue
        let status = CGSetDisplayTransferByTable(displayID, table.sampleCount, &red, &green, &blue)
        guard status == .success else {
            throw SoftwareDimmingError.applyFailed(
                "Could not apply gamma table for display \(displayID): status \(status.rawValue)."
            )
        }
    }
}

final class GammaDimmingController {
    private enum Constants {
        static let maximumBlueReduction: CGGammaValue = 0.45
    }

    private let tableController: GammaTableControlling
    private var originalTablesByDisplayID: [UInt32: GammaTableSnapshot] = [:]

    init(tableController: GammaTableControlling = CoreGraphicsGammaTableController()) {
        self.tableController = tableController
    }

    func apply(display: DisplayIdentity, blueReduction: Int) throws {
        let reduction = Clamped.percent(blueReduction)
        guard reduction > 0 else {
            try clear(display: display)
            return
        }

        let original = try originalTable(for: display)
        let reduced = Self.tableByReducingBlue(in: original, blueReduction: reduction)
        try tableController.set(displayID: display.cgDisplayID, table: reduced)
    }

    func clear(display: DisplayIdentity) throws {
        try restoreOriginalTable(displayID: display.cgDisplayID)
    }

    func clearTables(excluding activeDisplayIDs: Set<UInt32>) {
        for displayID in Array(originalTablesByDisplayID.keys) where !activeDisplayIDs.contains(displayID) {
            try? restoreOriginalTable(displayID: displayID)
        }
    }

    func hasOriginalTableForTesting(displayID: UInt32) -> Bool {
        originalTablesByDisplayID[displayID] != nil
    }

    static func blueScale(for blueReduction: Int) -> CGGammaValue {
        let reduction = CGGammaValue(Clamped.percent(blueReduction)) / 100.0
        return max(0.0, 1.0 - (reduction * Constants.maximumBlueReduction))
    }

    static func tableByReducingBlue(in table: GammaTableSnapshot, blueReduction: Int) -> GammaTableSnapshot {
        let scale = blueScale(for: blueReduction)
        return GammaTableSnapshot(
            red: table.red,
            green: table.green,
            blue: table.blue.map { min(1.0, max(0.0, $0 * scale)) }
        )
    }

    private func originalTable(for display: DisplayIdentity) throws -> GammaTableSnapshot {
        if let original = originalTablesByDisplayID[display.cgDisplayID] {
            return original
        }

        let capacity = tableController.capacity(for: display.cgDisplayID)
        let original = try tableController.read(displayID: display.cgDisplayID, capacity: capacity)
        originalTablesByDisplayID[display.cgDisplayID] = original
        return original
    }

    private func restoreOriginalTable(displayID: UInt32) throws {
        guard let original = originalTablesByDisplayID[displayID] else {
            return
        }

        try tableController.set(displayID: displayID, table: original)
        originalTablesByDisplayID.removeValue(forKey: displayID)
    }
}
