import SwiftUI

// MARK: - Background

/// The shared royal backdrop: the emerald jewel-stage artwork, scaled to fill the
/// screen, under a dark scrim that keeps text and cards readable.
struct RoyalBackground: View {
    enum Dimming {
        /// Lighter scrim for screens with little text (splash).
        case light
        /// Default scrim for menus and content screens.
        case standard
        /// Home: keeps the crown at the top of the artwork bright and darkens the
        /// lower half where cards sit.
        case home

        var colors: [Color] {
            switch self {
            case .light: return [.black.opacity(0.25), .black.opacity(0.05), .black.opacity(0.35)]
            case .standard: return [.black.opacity(0.55), .black.opacity(0.35), .black.opacity(0.6)]
            case .home: return [.black.opacity(0.05), .black.opacity(0.3), .black.opacity(0.55), .black.opacity(0.65)]
            }
        }
    }

    var dimming: Dimming = .standard

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Colors.emeraldDeep
                Image(Theme.Assets.background)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                LinearGradient(colors: dimming.colors, startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

struct RoyalCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.md
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(highlighted: highlighted)
    }
}

extension View {
    func royalCard(padding: CGFloat = Theme.Spacing.md, highlighted: Bool = false) -> some View {
        modifier(RoyalCardModifier(padding: padding, highlighted: highlighted))
    }

    /// Centers content in a readable column on wide screens.
    func readableWidth() -> some View {
        frame(maxWidth: Theme.Layout.maxContentWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Buttons

/// Polished gold primary action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.prefersReducedMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(Theme.Colors.textOnGold)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(Theme.Colors.goldGradient)
                    // Glossy top half, like polished metal.
                    Capsule(style: .continuous)
                        .fill(LinearGradient(stops: [.init(color: .white.opacity(configuration.isPressed ? 0.2 : 0.45), location: 0),
                                                     .init(color: .white.opacity(0.08), location: 0.48),
                                                     .init(color: .white.opacity(0), location: 0.5)],
                                             startPoint: .top, endPoint: .bottom))
                    // Darker lower bevel for depth.
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [.clear, Theme.Colors.goldDeep.opacity(0.55)], startPoint: .center, endPoint: .bottom))
                    Capsule(style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), Theme.Colors.goldLight.opacity(0.6), Theme.Colors.goldDeep],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                }
            )
            .shadow(color: Theme.Colors.goldDeep.opacity(0.9), radius: 0, y: configuration.isPressed ? 1 : 4)
            .shadow(color: Theme.Shadow.glow, radius: configuration.isPressed ? 4 : 14, y: 6)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Outlined gold secondary action.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.prefersReducedMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .foregroundStyle(Theme.Colors.goldLight)
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 50)
            .glassBackground(Capsule(style: .continuous), emphasis: .highlighted)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Compact text button used for Skip / Back.
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.goldLight.opacity(configuration.isPressed ? 0.6 : 1))
            .frame(minWidth: Theme.Layout.minimumTouchTarget, minHeight: Theme.Layout.minimumTouchTarget)
            .contentShape(Rectangle())
    }
}

/// Round icon button for overlays (e.g. pause).
struct RoundIconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(Theme.Colors.goldLight)
                .frame(width: size, height: size)
                .glassBackground(Circle(), emphasis: .highlighted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Small pieces

/// A gold capsule label, e.g. "Offline Ready".
struct BadgeLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.goldLight)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .glassBackground(Capsule(), emphasis: .subtle)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.title2)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A gold progress bar.
struct RoyalProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.35))
                Capsule()
                    .fill(Theme.Colors.goldGradient)
                    .frame(width: max(8, proxy.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// Title + value stat block.
struct StatBlock: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(Theme.Colors.gold)
                }
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text(value)
                .font(Theme.Typography.scoreValue)
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lives as hearts. Uses filled vs outlined shapes, not color alone.
struct LivesView: View {
    let lives: Int
    let maxLives: Int
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxLives, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < lives ? Theme.Colors.heart : Theme.Colors.textSecondary.opacity(0.6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lives")
        .accessibilityValue("\(lives) of \(maxLives)")
    }
}

/// A large jewel icon with name and points; shape + text communicate value.
struct JewelValueRow: View {
    let kind: JewelKind

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ArtworkView(kind: .jewel(kind), height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(kind.shapeDescription.capitalized)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text("+\(kind.points)")
                .font(Theme.Typography.headline.monospacedDigit())
                .foregroundStyle(Theme.Colors.goldLight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.displayName), \(kind.shapeDescription), \(kind.points) points")
    }
}

// MARK: - Statistics

/// A compact gold-bordered statistic tile with a jewel or symbol icon.
struct JewelStatCard: View {
    enum Icon {
        case artwork(ArtworkKind)
        case symbol(String)
    }

    let title: String
    let value: String
    let icon: Icon
    var identifier: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Group {
                switch icon {
                case .artwork(let kind):
                    ArtworkView(kind: kind, height: 28)
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.Colors.gold)
                        .frame(height: 28)
                }
            }
            .accessibilityHidden(true)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 104)
        .glassCard(cornerRadius: Theme.Radius.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// Circular completion indicator.
struct ProgressRing: View {
    let value: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, value)))
                .stroke(Theme.Colors.goldGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(value, format: .percent.precision(.fractionLength(0)))
                .font(.system(.headline, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.6)
                .padding(lineWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let artwork: ArtworkKind
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ArtworkView(kind: artwork, height: 56)
            Text(title)
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "play.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .royalCard(padding: Theme.Spacing.lg)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Settings rows

/// A titled group of settings inside a gold-bordered card.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.goldLight)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                content
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary)
            .tint(Theme.Colors.gold)
            .royalCard()
        }
    }
}

/// A tappable settings row label with an optional disclosure chevron.
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var showsChevron = true
    var destructive = false

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(destructive ? Theme.Colors.danger : Theme.Colors.textPrimary)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: Theme.Layout.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

/// A label/value row, e.g. version number or a statistic.
struct SettingsValueRow: View {
    let title: String
    let systemImage: String
    let value: String
    var identifier: String?

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? "")
    }
}
