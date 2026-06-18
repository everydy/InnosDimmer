import AppKit
import CoreGraphics

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
        Self.resolveSelectedDisplay(
            saved: targetStore.load().selectedDisplay,
            candidates: activeDisplays(),
            mainDisplayID: CGMainDisplayID()
        )
    }

    static func resolveSelectedDisplay(
        saved: DisplayIdentity?,
        candidates: [DisplayIdentity],
        mainDisplayID: CGDirectDisplayID
    ) -> DisplayIdentity? {
        if let saved {
            return DisplayTargetResolver.resolve(saved: saved, candidates: candidates)
        }

        return candidates.first { candidate in
            candidate.cgDisplayID != mainDisplayID
        }
    }

    func preferredExternalDisplay() -> DisplayIdentity? {
        activeDisplays().first { identity in
            CGDisplayIsMain(identity.cgDisplayID) == 0
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
}
