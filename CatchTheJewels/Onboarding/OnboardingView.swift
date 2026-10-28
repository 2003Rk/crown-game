import SwiftUI

/// The three first-launch onboarding screens.
struct OnboardingView: View {
    /// Called when onboarding ends. `startPlaying` is true when the player tapped
    /// "Start Playing" (rather than Skip).
    let onFinish: (_ startPlaying: Bool) -> Void

    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.height < 720

            VStack(spacing: 0) {
                topBar
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index], isActive: page == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: page)

                VStack(spacing: compactLayout ? Theme.Spacing.sm : Theme.Spacing.lg) {
                    PageIndicator(count: pages.count, current: page)
                    Button(action: advance) {
                        Text(pages[page].cta)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(page == pages.count - 1 ? "onboarding.start" : "onboarding.continue")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, compactLayout ? Theme.Spacing.xs : 0)
                .padding(.bottom, compactLayout ? Theme.Spacing.sm : Theme.Spacing.lg)
                .readableWidth()
            }
        }
        .accessibilityIdentifier("onboarding")
    }

    private var topBar: some View {
        HStack {
            if page > 0 {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut) { page -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(TextButtonStyle())
                .accessibilityIdentifier("onboarding.back")
            }
            Spacer()
            if page < pages.count - 1 {
                Button("Skip") { onFinish(false) }
                    .buttonStyle(TextButtonStyle())
                    .accessibilityHint("Skips the introduction and opens the home screen.")
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: Theme.Layout.minimumTouchTarget + Theme.Spacing.xs)
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
        } else {
            onFinish(true)
        }
    }
}

struct OnboardingPage: Identifiable {
    enum Illustration {
        case welcome
        case howToCatch
        case preview
    }

    let id: Int
    let headline: String
    let subtitle: String
    let detail: String
    let cta: String
    let illustration: Illustration

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            headline: "Your Jewel Hunt Begins",
            subtitle: "Catch sparkling jewels and build your royal high score.",
            detail: "Rubies, sapphires, emeralds, amethysts and rare gold stars fall from the royal skies. Every jewel you catch adds to your score.",
            cta: "Continue",
            illustration: .welcome
        ),
        OnboardingPage(
            id: 1,
            headline: "Catch. Collect. Score.",
            subtitle: "Move your crown to catch jewels and avoid dangerous obstacles.",
            detail: "Touch and drag anywhere on the screen to slide your crown left and right. Each bomb you catch costs one of your three lives.",
            cta: "Continue",
            illustration: .howToCatch
        ),
        OnboardingPage(
            id: 2,
            headline: "Ready, Royal Champion?",
            subtitle: "No account needed. Jump in and beat your best score.",
            detail: "Core gameplay works offline. Your scores, achievements and settings stay on this device.",
            cta: "Start Playing",
            illustration: .preview
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let compactLayout = proxy.size.height < 540
            let illustrationScale = compactLayout ? 0.7 : 1.0

            ScrollView {
                VStack(spacing: compactLayout ? Theme.Spacing.sm : Theme.Spacing.lg) {
                    Group {
                        switch page.illustration {
                        case .welcome: WelcomeIllustration(isActive: isActive)
                        case .howToCatch: CatchIllustration(isActive: isActive)
                        case .preview: GameplayPreviewIllustration()
                        }
                    }
                    .frame(height: 300)
                    .scaleEffect(illustrationScale)
                    .frame(height: 300 * illustrationScale)
                    .accessibilityHidden(true)

                    VStack(spacing: compactLayout ? Theme.Spacing.xs : Theme.Spacing.sm) {
                        Text(page.headline)
                            .font(compactLayout ? Theme.Typography.title : Theme.Typography.display)
                            .foregroundStyle(Theme.Colors.goldGradient)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("onboarding.headline.\(page.id)")
                        Text(page.subtitle)
                            .font(compactLayout ? Theme.Typography.headline : Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(page.detail)
                            .font(compactLayout ? Theme.Typography.callout : Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                    if page.illustration == .preview {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Theme.Spacing.xs) {
                                previewBadges
                            }
                            VStack(spacing: Theme.Spacing.xs) {
                                previewBadges
                            }
                        }
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, compactLayout ? Theme.Spacing.xs : Theme.Spacing.md)
                .readableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private var previewBadges: some View {
        BadgeLabel(text: "Offline", systemImage: "wifi.slash")
        BadgeLabel(text: "No account", systemImage: "person.crop.circle.badge.xmark")
        BadgeLabel(text: "Saved locally", systemImage: "internaldrive")
    }
}

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(Theme.Colors.goldGradient) : AnyShapeStyle(Theme.Colors.textSecondary.opacity(0.35)))
                    .frame(width: index == current ? 28 : 10, height: 10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
        .accessibilityIdentifier("onboarding.pageIndicator")
    }
}

// MARK: - Illustrations

private struct WelcomeIllustration: View {
    let isActive: Bool
    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var floating = false

    private let orbit: [(JewelKind, CGFloat, CGFloat)] = [
        (.ruby, -120, -40), (.sapphire, -62, -100), (.gold, 0, -125), (.emerald, 62, -100), (.amethyst, 120, -40),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.Colors.gold.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 150))
                .frame(width: 300, height: 300)
            ForEach(orbit.indices, id: \.self) { index in
                let item = orbit[index]
                ArtworkView(kind: .jewel(item.0), height: 52)
                    .offset(x: item.1, y: item.2 + (floating ? -8 : 8) * (index.isMultiple(of: 2) ? 1 : -1))
            }
            ArtworkView(kind: .crownEmblem, height: 120)
                .offset(y: 50)
        }
        .onAppear(perform: startAnimating)
        .onChange(of: isActive) { _, _ in startAnimating() }
    }

    private func startAnimating() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            floating = true
        }
    }
}

private struct CatchIllustration: View {
    let isActive: Bool
    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var sway = false

    var body: some View {
        ZStack {
            Color.clear
                .glassCard(cornerRadius: Theme.Radius.large)
            VStack {
                HStack(spacing: Theme.Spacing.lg) {
                    VStack(spacing: 6) {
                        ArtworkView(kind: .jewel(.sapphire), height: 46)
                        Label("Catch", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.success)
                    }
                    VStack(spacing: 6) {
                        ArtworkView(kind: .bomb, height: 50)
                        Label("Avoid", systemImage: "xmark.octagon.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                    VStack(spacing: 6) {
                        ArtworkView(kind: .jewel(.gold), height: 46)
                        Label("Catch", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.success)
                    }
                }
                .padding(.top, Theme.Spacing.lg)
                Spacer()
                ArtworkView(kind: .catcher, height: 72)
                    .offset(x: sway ? 50 : -50)
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.left")
                    Image(systemName: "hand.draw.fill").font(.title2)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(Theme.Colors.goldLight)
                .padding(.bottom, Theme.Spacing.md)
            }
        }
        .frame(maxWidth: 360)
        .onAppear(perform: startAnimating)
        .onChange(of: isActive) { _, _ in startAnimating() }
    }

    private func startAnimating() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            sway = true
        }
    }
}

/// A miniature, faithful rendering of the real gameplay screen.
struct GameplayPreviewIllustration: View {
    var body: some View {
        ZStack {
            Image(Theme.Assets.background)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 300)
                .overlay(Color.black.opacity(GameScene.backgroundScrimAlpha))
            VStack(spacing: 0) {
                HStack {
                    Text("1,240")
                        .font(.system(.headline, design: .rounded).weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    LivesView(lives: 2, maxLives: 3, size: 13)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.Colors.emeraldDeep.opacity(0.7)))
                .padding(10)
                ZStack {
                    ArtworkView(kind: .jewel(.ruby), height: 34).offset(x: -55, y: -40)
                    ArtworkView(kind: .jewel(.amethyst), height: 34).offset(x: 40, y: -70)
                    ArtworkView(kind: .bomb, height: 36).offset(x: 60, y: 20)
                    ArtworkView(kind: .jewel(.emerald), height: 34).offset(x: -20, y: 40)
                }
                .frame(maxHeight: .infinity)
                ArtworkView(kind: .catcher, height: 52)
                    .padding(.bottom, 16)
            }
        }
        .frame(width: 200, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.Colors.goldBorder, lineWidth: 3))
        .shadow(color: Theme.Shadow.glow, radius: 18)
    }
}
