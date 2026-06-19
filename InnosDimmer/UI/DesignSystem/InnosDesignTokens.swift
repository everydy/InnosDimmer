import AppKit

enum InnosDesignTokens {
    enum Radius {
        static let section: CGFloat = 8
        static let control: CGFloat = 7
        static let chip: CGFloat = 8
        static let track: CGFloat = 999
    }

    enum Spacing {
        static let surfacePadding: CGFloat = 16
        static let sectionPadding: CGFloat = 12
        static let sectionGap: CGFloat = 12
        static let rowGap: CGFloat = 8
        static let compactGap: CGFloat = 6
    }

    enum Size {
        static let chipMinHeight: CGFloat = 24
        static let buttonMinHeight: CGFloat = 30
        static let iconButton: CGFloat = 34
        static let trackHeight: CGFloat = 18
        static let trackBarHeight: CGFloat = 8
        static let trackThumbDiameter: CGFloat = 14
        static let dimmingLabelWidth: CGFloat = 112
        static let dimmingValueWidth: CGFloat = 54
        static let summaryLabelWidth: CGFloat = 108
    }

    enum Font {
        static var sectionTitle: NSFont { NSFont.systemFont(ofSize: 12, weight: .bold) }
        static var body: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }
        static var bodyEmphasis: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
        static var value: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold) }
        static var chip: NSFont { NSFont.systemFont(ofSize: 12, weight: .semibold) }
        static var button: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
    }

    enum Tone {
        case neutral
        case ready
        case warning
        case danger
        case primary
    }

    static func surfaceRoot(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.10, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
    }

    static func surfaceSection(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.15, alpha: 1) : .white
    }

    static func surfaceSubtle(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.98, alpha: 1)
    }

    static func surfaceControl(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.19, alpha: 1) : NSColor(calibratedWhite: 0.93, alpha: 1)
    }

    static func border(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.27, alpha: 1) : NSColor(calibratedWhite: 0.84, alpha: 1)
    }

    static func controlBorder(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.36, alpha: 1) : NSColor(calibratedWhite: 0.76, alpha: 1)
    }

    static func trackBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance) ? NSColor(calibratedWhite: 0.24, alpha: 1) : NSColor(calibratedWhite: 0.88, alpha: 1)
    }

    static func accent(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1)
        }
        return NSColor(calibratedRed: 0.09, green: 0.41, blue: 0.76, alpha: 1)
    }

    static func primaryBackground(for appearance: NSAppearance) -> NSColor {
        if isDark(appearance) {
            return NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.85, alpha: 1)
        }
        return NSColor(calibratedRed: 0.03, green: 0.42, blue: 0.74, alpha: 1)
    }

    static func foreground(for tone: Tone, appearance: NSAppearance) -> NSColor {
        switch tone {
        case .neutral:
            return .labelColor
        case .ready:
            return isDark(appearance)
                ? NSColor(calibratedRed: 0.46, green: 0.85, blue: 0.61, alpha: 1)
                : NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.27, alpha: 1)
        case .warning:
            return isDark(appearance)
                ? NSColor(calibratedRed: 0.95, green: 0.77, blue: 0.37, alpha: 1)
                : NSColor(calibratedRed: 0.54, green: 0.35, blue: 0, alpha: 1)
        case .danger:
            return isDark(appearance)
                ? NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.42, alpha: 1)
                : NSColor(calibratedRed: 0.70, green: 0.14, blue: 0.09, alpha: 1)
        case .primary:
            return .white
        }
    }

    static func background(for tone: Tone, appearance: NSAppearance) -> NSColor {
        switch tone {
        case .neutral:
            return surfaceControl(for: appearance)
        case .ready, .warning, .danger:
            return foreground(for: tone, appearance: appearance).withAlphaComponent(isDark(appearance) ? 0.12 : 0.10)
        case .primary:
            return primaryBackground(for: appearance)
        }
    }

    static func border(for tone: Tone, appearance: NSAppearance) -> NSColor {
        switch tone {
        case .neutral:
            return controlBorder(for: appearance)
        case .ready, .warning, .danger:
            return foreground(for: tone, appearance: appearance).withAlphaComponent(0.44)
        case .primary:
            return primaryBackground(for: appearance)
        }
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
