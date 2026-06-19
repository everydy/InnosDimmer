import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let option = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let command = ShortcutModifiers(rawValue: 1 << 3)
}

enum ShortcutAction: String, Codable, Equatable, CaseIterable, Sendable {
    case brightnessUp
    case brightnessDown
    case blueReductionUp
    case blueReductionDown
    case quickDisableOverlay
    case restorePreviousDimming

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "warmthUp":
            self = .blueReductionUp
        case "warmthDown":
            self = .blueReductionDown
        default:
            guard let action = ShortcutAction(rawValue: rawValue) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown shortcut action: \(rawValue)")
                )
            }
            self = action
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ShortcutBinding: Codable, Equatable, Sendable {
    var action: ShortcutAction
    var keyCode: UInt16
    var modifiers: ShortcutModifiers
    var isEnabled: Bool
}

struct ShortcutSignature: Codable, Equatable, Hashable, Comparable, Sendable {
    var keyCode: UInt16
    var modifiers: ShortcutModifiers

    static func < (lhs: ShortcutSignature, rhs: ShortcutSignature) -> Bool {
        if lhs.keyCode == rhs.keyCode {
            return lhs.modifiers.rawValue < rhs.modifiers.rawValue
        }
        return lhs.keyCode < rhs.keyCode
    }
}

struct HotkeyValidationReport: Equatable, Sendable {
    var duplicateSignatures: [ShortcutSignature]
    var unsafeBindings: [ShortcutBinding]

    var isValid: Bool {
        duplicateSignatures.isEmpty && unsafeBindings.isEmpty
    }
}

extension ShortcutBinding {
    static let defaultBindings: [ShortcutBinding] = [
        ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
        ShortcutBinding(action: .brightnessDown, keyCode: 125, modifiers: [.option, .shift], isEnabled: true),
        ShortcutBinding(action: .blueReductionUp, keyCode: 124, modifiers: [.option, .shift], isEnabled: true),
        ShortcutBinding(action: .blueReductionDown, keyCode: 123, modifiers: [.option, .shift], isEnabled: true),
        ShortcutBinding(action: .quickDisableOverlay, keyCode: 29, modifiers: [.option, .shift], isEnabled: true),
        ShortcutBinding(action: .restorePreviousDimming, keyCode: 15, modifiers: [.option, .shift], isEnabled: true)
    ]
}
