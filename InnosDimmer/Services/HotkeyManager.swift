import Foundation
#if canImport(Carbon)
import Carbon
#endif

enum HotkeyManagerError: Error, Equatable {
    case validationFailed(HotkeyValidationReport)
    case registrationFailed(status: Int32)
}

protocol HotkeyRegistrationBackend: AnyObject {
    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws
    func unregisterAll()
}

final class HotkeyManager {
    static let defaultBindings = ShortcutBinding.defaultBindings

    private let backend: HotkeyRegistrationBackend
    private let actionHandler: (ShortcutAction) -> Void

    init(
        backend: HotkeyRegistrationBackend = CarbonHotkeyRegistrationBackend(),
        actionHandler: @escaping (ShortcutAction) -> Void
    ) {
        self.backend = backend
        self.actionHandler = actionHandler
    }

    func start(bindings: [ShortcutBinding] = defaultBindings) throws {
        let report = Self.validate(bindings)
        guard report.isValid else {
            throw HotkeyManagerError.validationFailed(report)
        }

        try backend.register(bindings, handler: actionHandler)
    }

    func stop() {
        backend.unregisterAll()
    }

    static func duplicateShortcuts(_ bindings: [ShortcutBinding]) -> [ShortcutSignature] {
        var seen = Set<ShortcutSignature>()
        var duplicates = Set<ShortcutSignature>()

        for binding in bindings where binding.isEnabled {
            let signature = ShortcutSignature(keyCode: binding.keyCode, modifiers: binding.modifiers)
            if !seen.insert(signature).inserted {
                duplicates.insert(signature)
            }
        }

        return duplicates.sorted()
    }

    static func unsafeBindings(in bindings: [ShortcutBinding]) -> [ShortcutBinding] {
        bindings.filter { binding in
            binding.isEnabled && !isSafe(binding)
        }
    }

    static func validate(_ bindings: [ShortcutBinding]) -> HotkeyValidationReport {
        HotkeyValidationReport(
            duplicateSignatures: duplicateShortcuts(bindings),
            unsafeBindings: unsafeBindings(in: bindings)
        )
    }

    static func summary(for bindings: [ShortcutBinding]) -> String {
        let enabledCount = bindings.filter(\.isEnabled).count
        return "Shortcuts: \(enabledCount) enabled"
    }

    private static func isSafe(_ binding: ShortcutBinding) -> Bool {
        let modifiers = binding.modifiers
        let hasAnchorModifier = modifiers.contains(.option) || modifiers.contains(.control) || modifiers.contains(.command)
        return hasAnchorModifier && modifiers.contains(.shift)
    }
}

#if canImport(Carbon)
final class CarbonHotkeyRegistrationBackend: HotkeyRegistrationBackend {
    private let signature = FourCharCode("INOS")
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var actionsByID: [UInt32: ShortcutAction] = [:]
    private var handler: ((ShortcutAction) -> Void)?

    deinit {
        unregisterAll()
    }

    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws {
        unregisterAll()

        self.handler = handler
        let enabledBindings = bindings.filter(\.isEnabled)

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else {
                    return noErr
                }

                let backend = Unmanaged<CarbonHotkeyRegistrationBackend>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                var hotkeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                guard status == noErr, let action = backend.actionsByID[hotkeyID.id] else {
                    return status
                }

                backend.handler?(action)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            throw HotkeyManagerError.registrationFailed(status: installStatus)
        }

        for (index, binding) in enabledBindings.enumerated() {
            let id = UInt32(index + 1)
            let hotkeyID = EventHotKeyID(signature: signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode),
                carbonModifiers(binding.modifiers),
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            guard status == noErr, let ref else {
                unregisterAll()
                throw HotkeyManagerError.registrationFailed(status: status)
            }

            actionsByID[id] = binding.action
            hotkeyRefs.append(ref)
        }
    }

    func unregisterAll() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        actionsByID.removeAll()
        handler = nil

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func carbonModifiers(_ modifiers: ShortcutModifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.option) {
            flags |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }
        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }
        return flags
    }
}

private func FourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}
#else
final class CarbonHotkeyRegistrationBackend: HotkeyRegistrationBackend {
    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws {
        _ = bindings
        _ = handler
        throw HotkeyManagerError.registrationFailed(status: -1)
    }

    func unregisterAll() {}
}
#endif
