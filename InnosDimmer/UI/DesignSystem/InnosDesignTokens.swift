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
        static var appTitle: NSFont { app(ofSize: 17, weight: .bold) }
        static var windowTitle: NSFont { app(ofSize: 22, weight: .bold) }
        static var sectionLabel: NSFont { app(ofSize: 12, weight: .semibold) }
        static var body: NSFont { app(ofSize: 13, weight: .regular) }
        static var bodySmall: NSFont { app(ofSize: 12, weight: .regular) }
        static var bodyStrong: NSFont { app(ofSize: 13, weight: .semibold) }
        static var bodySmallStrong: NSFont { app(ofSize: 12, weight: .semibold) }
        static var controlLabel: NSFont { app(ofSize: 13, weight: .semibold) }
        static var controlValue: NSFont { app(ofSize: 18, weight: .semibold) }
        static var compactControlValue: NSFont { app(ofSize: 16, weight: .semibold) }
        static var numericValue: NSFont { app(ofSize: 13, weight: .semibold) }
        static var buttonLabel: NSFont { app(ofSize: 12, weight: .semibold) }
        static var badgeLabel: NSFont { app(ofSize: 12, weight: .semibold) }
        static var badgeCompact: NSFont { app(ofSize: 9, weight: .semibold) }
        static var shortcutName: NSFont { app(ofSize: 13, weight: .semibold) }
        static var shortcutDirection: NSFont { app(ofSize: 12, weight: .semibold) }
        static var shortcutToken: NSFont { app(ofSize: 13, weight: .semibold) }
        static var shortcutSeparator: NSFont { app(ofSize: 9, weight: .medium) }
        static var shortcutOff: NSFont { app(ofSize: 12, weight: .semibold) }

        static var popoverTitle: NSFont { app(ofSize: 17, weight: .bold) }
        static var popoverSectionLabel: NSFont { app(ofSize: 12, weight: .semibold) }
        static var popoverLabel: NSFont { app(ofSize: 13, weight: .semibold) }
        static var popoverValue: NSFont { app(ofSize: 18, weight: .bold) }
        static var popoverButton: NSFont { app(ofSize: 12, weight: .semibold) }
        static var popoverBadge: NSFont { app(ofSize: 12, weight: .semibold) }
        static var popoverBadgeCompact: NSFont { app(ofSize: 9, weight: .semibold) }
        static var popoverShortcutName: NSFont { app(ofSize: 13, weight: .semibold) }
        static var popoverShortcutDirection: NSFont { app(ofSize: 12, weight: .medium) }
        static var popoverShortcutToken: NSFont { app(ofSize: 13, weight: .semibold) }
        static var popoverShortcutSeparator: NSFont { app(ofSize: 9, weight: .regular) }
        static var popoverShortcutOff: NSFont { app(ofSize: 12, weight: .semibold) }

        static var sectionTitle: NSFont { sectionLabel }
        static var bodyEmphasis: NSFont { bodyStrong }
        static var value: NSFont { app(ofSize: 18, weight: .bold) }
        static var chip: NSFont { badgeLabel }
        static var button: NSFont { buttonLabel }

        static func app(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
            if let font = NSFont(name: pretendardPostScriptName(for: weight), size: size)
                ?? NSFont(name: "Pretendard", size: size) {
                return font
            }
            return NSFont.systemFont(ofSize: size, weight: weight)
        }

        private static func pretendardPostScriptName(for weight: NSFont.Weight) -> String {
            if weight == .ultraLight {
                return "Pretendard-ExtraLight"
            }
            if weight == .thin {
                return "Pretendard-Thin"
            }
            if weight == .light {
                return "Pretendard-Light"
            }
            if weight == .medium {
                return "Pretendard-Medium"
            }
            if weight == .semibold {
                return "Pretendard-SemiBold"
            }
            if weight == .bold {
                return "Pretendard-Bold"
            }
            if weight == .heavy {
                return "Pretendard-ExtraBold"
            }
            if weight == .black {
                return "Pretendard-Black"
            }
            return "Pretendard-Regular"
        }
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
        token(dark: 0x18181b, light: 0xf1f2f4, appearance: appearance)
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
