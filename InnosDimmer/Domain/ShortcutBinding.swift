import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt

    static let option = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let command = ShortcutModifiers(rawValue: 1 << 3)
}

enum ShortcutAction: String, Codable, Equatable, CaseIterable {
    case brightnessUp
    case brightnessDown
    case warmthUp
    case warmthDown
    case quickDisableOverlay
    case restorePreviousDimming
}

struct ShortcutBinding: Codable, Equatable {
    var action: ShortcutAction
    var keyCode: UInt16
    var modifiers: ShortcutModifiers
    var isEnabled: Bool
}
