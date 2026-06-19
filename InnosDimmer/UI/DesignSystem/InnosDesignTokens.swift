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
        token(dark: 0x161616, light: 0xf7f7f8, appearance: appearance)
    }

    static func surfaceSection(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x1f1f22, light: 0xffffff, appearance: appearance)
    }

    static func surfaceSubtle(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x262626, light: 0xf1f2f4, appearance: appearance)
    }

    static func surfaceControl(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x303036, light: 0xf7f7f8, appearance: appearance)
    }

    static func border(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x3b3b40, light: 0xd6d9de, appearance: appearance)
    }

    static func controlBorder(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x4b4b52, light: 0xc2c7ce, appearance: appearance)
    }

    static func trackBackground(for appearance: NSAppearance) -> NSColor {
        isDark(appearance)
            ? color(0x3b3b40, alpha: 0.70)
            : color(0xd6d9de, alpha: 0.70)
    }

    static func accent(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x5aa7ff, light: 0x0f75d3, appearance: appearance)
    }

    static func primaryBackground(for appearance: NSAppearance) -> NSColor {
        token(dark: 0x1f7bd9, light: 0x0b70c9, appearance: appearance)
    }

    static func foreground(for tone: Tone, appearance: NSAppearance) -> NSColor {
        switch tone {
        case .neutral:
            return .labelColor
        case .ready:
            return token(dark: 0x75d99b, light: 0x196b39, appearance: appearance)
        case .warning:
            return token(dark: 0xf1c45f, light: 0x8a5b00, appearance: appearance)
        case .danger:
            return token(dark: 0xff6b6b, light: 0xb42318, appearance: appearance)
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

    private static func token(dark: Int, light: Int, appearance: NSAppearance) -> NSColor {
        color(isDark(appearance) ? dark : light)
    }

    private static func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255.0,
            green: CGFloat((hex >> 8) & 0xff) / 255.0,
            blue: CGFloat(hex & 0xff) / 255.0,
            alpha: alpha
        )
    }
}
