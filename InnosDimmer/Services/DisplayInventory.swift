import AppKit
import CoreGraphics

enum DisplayResolution: Equatable {
    case selected(DisplayIdentity, source: DisplayResolutionSource)
    case unavailable(DisplayResolutionFailure)
}

enum DisplayResolutionSource: Equatable {
    case saved
    case automatic
    case fallback(saved: DisplayIdentity)
}

enum DisplayResolutionFailure: Equatable {
    case noEligibleExternalDisplay
    case multipleExternalDisplays(candidates: [DisplayIdentity])
}

protocol DisplayInventoryProviding {
    func activeDisplays() -> [DisplayIdentity]
    func resolveDisplayResolution(saved: DisplayIdentity?, candidates: [DisplayIdentity]) -> DisplayResolution
}

final class DisplayInventory {
    func activeDisplays() -> [DisplayIdentity] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return []
        }

        var displayIDs = Array<CGDirectDisplayID>(repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displayIDs, &count) == .success else {
            return []
        }

        return displayIDs.map(identity(for:))
    }

    func selectedDisplay(using targetStore: DisplayTargetStore) -> DisplayIdentity? {
        let candidates = activeDisplays()
        let resolution = Self.resolveSelectedDisplay(
            saved: targetStore.load().selectedDisplay,
            candidates: candidates,
            mainDisplayID: CGMainDisplayID(),
            builtInDisplayIDs: builtInDisplayIDs(for: candidates)
        )

        guard case .selected(let display, _) = resolution else {
            return nil
        }
        return display
    }

    static func resolveSelectedDisplay(
        saved: DisplayIdentity?,
        candidates: [DisplayIdentity],
        mainDisplayID: CGDirectDisplayID,
        builtInDisplayIDs: Set<CGDirectDisplayID>
    ) -> DisplayResolution {
        if let saved,
           let match = DisplayTargetResolver.resolve(saved: saved, candidates: candidates) {
            return .selected(match, source: .saved)
        }

        let eligible = candidates.filter { candidate in
            candidate.cgDisplayID != mainDisplayID
                && !builtInDisplayIDs.contains(candidate.cgDisplayID)
        }.sorted { lhs, rhs in
            if lhs.localizedName == rhs.localizedName {
                return lhs.cgDisplayID < rhs.cgDisplayID
            }
            return lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
        }

        switch eligible.count {
        case 0:
            return .unavailable(.noEligibleExternalDisplay)
        case 1:
            let display = eligible[0]
            if let saved {
                return .selected(display, source: .fallback(saved: saved))
            }
            return .selected(display, source: .automatic)
        default:
            return .unavailable(.multipleExternalDisplays(candidates: eligible))
        }
    }

    func displayContainingCursor() -> DisplayIdentity? {
        displayContaining(point: NSEvent.mouseLocation)
    }

    func displayContaining(point: NSPoint) -> DisplayIdentity? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }.flatMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return identity(for: number.uint32Value)
        }
    }

    private func identity(for displayID: CGDirectDisplayID) -> DisplayIdentity {
        let screen = NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == displayID
        }

        let frame = screen?.frame ?? .zero
        return DisplayIdentity(
            cgDisplayID: displayID,
            localizedName: screen?.localizedName ?? "Display \(displayID)",
            vendorNumber: optionalHardwareNumber(CGDisplayVendorNumber(displayID)),
            modelNumber: optionalHardwareNumber(CGDisplayModelNumber(displayID)),
            serialNumber: optionalHardwareNumber(CGDisplaySerialNumber(displayID)),
            frameDescription: "\(Int(frame.width))x\(Int(frame.height))@\(Int(frame.origin.x)),\(Int(frame.origin.y))"
        )
    }

    private func optionalHardwareNumber(_ value: UInt32) -> UInt32? {
        value == 0 ? nil : value
    }

    private func builtInDisplayIDs(for displays: [DisplayIdentity]) -> Set<CGDirectDisplayID> {
        Set(displays.compactMap { display in
            CGDisplayIsBuiltin(display.cgDisplayID) != 0 ? display.cgDisplayID : nil
        })
    }
}

extension DisplayInventory: DisplayInventoryProviding {
    func resolveDisplayResolution(saved: DisplayIdentity?, candidates: [DisplayIdentity]) -> DisplayResolution {
        Self.resolveSelectedDisplay(
            saved: saved,
            candidates: candidates,
            mainDisplayID: CGMainDisplayID(),
            builtInDisplayIDs: builtInDisplayIDs(for: candidates)
        )
    }
}
