import Foundation

enum DisplayTargetResolver {
    static func resolve(saved: DisplayIdentity?, candidates: [DisplayIdentity]) -> DisplayIdentity? {
        guard let saved else {
            return candidates.first
        }

        if let hardwareMatch = candidates.first(where: { saved.hasSameHardwareIdentity(as: $0) }) {
            return hardwareMatch
        }

        if saved.hasStableHardwareIdentity {
            return nil
        }

        return candidates.first { candidate in
            candidate.cgDisplayID == saved.cgDisplayID && candidate.localizedName == saved.localizedName
        }
    }
}

extension DisplayIdentity {
    var hasStableHardwareIdentity: Bool {
        guard let vendorNumber, let modelNumber, let serialNumber else {
            return false
        }

        return vendorNumber != 0 && modelNumber != 0 && serialNumber != 0
    }

    func hasSameHardwareIdentity(as other: DisplayIdentity) -> Bool {
        guard hasStableHardwareIdentity, other.hasStableHardwareIdentity else {
            return false
        }

        return vendorNumber == other.vendorNumber
            && modelNumber == other.modelNumber
            && serialNumber == other.serialNumber
    }
}
