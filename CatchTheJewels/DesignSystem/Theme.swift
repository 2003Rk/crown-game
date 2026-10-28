import SwiftUI

/// Design tokens for Catch the Jewels: royal emerald, polished gold, jewel accents.
enum Theme {
    enum Assets {
        /// Full-screen royal stage artwork used behind every screen, including gameplay.
        static let background = "RoyalStageBackground"
        /// The brand artwork with rounded corners, shown on the launch screen and splash.
        static let brandMark = "BrandMark"
    }

    /// Brand palette. Every color in the app comes from these tokens.
    enum Colors {
        /// Dark forest green — deepest backgrounds and the tab bar.
        static let emeraldDeep = Color(hex: 0x002518)
        /// Deep emerald — cards and panels.
        static let emerald = Color(hex: 0x003B24)
        /// Royal green — highlights and raised surfaces.
        static let royalGreen = Color(hex: 0x087A3C)
        static let emeraldLight = royalGreen
        static let panel = emerald
        static let panelRaised = Color(hex: 0x0A5532)

        static let gold = Color(hex: 0xF7C94B)
        /// Bright gold — selected states and gradient highlights.
        static let goldLight = Color(hex: 0xFFE7A0)
        static let goldDeep = Color(hex: 0xB07F1F)

        static let ruby = Color(hex: 0xE9273E)
        static let sapphire = Color(hex: 0x258BFF)
        static let emeraldGem = Color(hex: 0x19C77A)
        static let amethyst = Color(hex: 0x9D4EDD)
        static let heart = Color(hex: 0xFF4F7B)

        /// Cream white primary text: ~15:1 contrast on deep emerald.
        static let textPrimary = Color(hex: 0xFFF8E7)
        /// Light green secondary text: ~9:1 contrast on deep emerald.
        static let textSecondary = Color(hex: 0xCDE3D6)
        /// Dark text used on gold buttons.
        static let textOnGold = Color(hex: 0x2B1A00)
        static let success = Color(hex: 0x5BE49B)
        static let danger = Color(hex: 0xFF6B6B)

        static let goldGradient = LinearGradient(colors: [goldLight, gold, goldDeep], startPoint: .top, endPoint: .bottom)
        static let goldBorder = LinearGradient(colors: [goldLight, gold.opacity(0.9), goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let backgroundGradient = LinearGradient(colors: [emerald, emeraldDeep], startPoint: .top, endPoint: .bottom)

        static func jewel(_ kind: JewelKind) -> Color {
            switch kind {
            case .ruby: return ruby
            case .sapphire: return sapphire
            case .emerald: return emeraldGem
            case .amethyst: return amethyst
            case .gold: return gold
            }
        }
    }

    /// Typography built on Dynamic Type text styles so every menu scales.
    enum Typography {
        static let display = Font.system(.largeTitle, design: .serif).weight(.bold)
        static let title = Font.system(.title, design: .serif).weight(.bold)
        static let title2 = Font.system(.title2, design: .serif).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let callout = Font.system(.callout, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded).weight(.medium)
        static let button = Font.system(.headline, design: .rounded).weight(.bold)
        static let scoreValue = Font.system(.title, design: .rounded).weight(.heavy).monospacedDigit()
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 26
    }

    enum Layout {
        /// Minimum interactive size recommended by the Human Interface Guidelines.
        static let minimumTouchTarget: CGFloat = 44
        /// Content column width on iPad so cards don't stretch edge to edge.
        static let maxContentWidth: CGFloat = 620
        static let tabBarHeight: CGFloat = 64
    }

    enum Shadow {
        static let card = Color.black.opacity(0.35)
        static let glow = Colors.gold.opacity(0.35)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Reduced motion

private struct PrefersReducedMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when either the system Reduce Motion setting or the in-app toggle is on.
    var prefersReducedMotion: Bool {
        get { self[PrefersReducedMotionKey.self] }
        set { self[PrefersReducedMotionKey.self] = newValue }
    }
}
