import SwiftUI

/// Chooses between the launch splash, onboarding and the main app.
struct RootView: View {
    let sdkLaunchGate: SDKLaunchGate

    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showSplash = true

    private var reduceMotion: Bool { settings.reduceMotion || systemReduceMotion }

    var body: some View {
        ZStack {
            RoyalBackground(dimming: showSplash ? .light : .standard)
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !settings.hasCompletedOnboarding {
                OnboardingView { startPlaying in
                    // "Start Playing" lands in the Play lobby; Skip lands on Home.
                    if startPlaying {
                        model.openPlay(mode: .classic)
                    } else {
                        model.select(.home)
                    }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                        settings.hasCompletedOnboarding = true
                    }
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .environment(\.prefersReducedMotion, reduceMotion)
        .preferredColorScheme(.dark)
        .tint(Theme.Colors.gold)
        .task {
            guard showSplash else { return }
            if model.launchOptions.skipSplash {
                dismissSplash()
                return
            }

            async let sdkReady: Void = sdkLaunchGate.waitUntilReady()
            async let minimumDisplay: Void = Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.4))
            _ = try? await (sdkReady, minimumDisplay)
            dismissSplash()
        }
    }

    private func dismissSplash() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
            showSplash = false
        }
        if model.launchOptions.autoStartClassic, settings.hasCompletedOnboarding {
            model.startGame(.classic)
        }
    }
}

/// Continues the system launch screen (the same brand mark, same size and position), then animates in the title.
struct SplashView: View {
    /// Matches the brand mark's size on the system launch screen, so the hand-off
    /// from launch screen to splash is seamless.
    static let brandMarkSize: CGFloat = 160

    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        Image(Theme.Assets.brandMark)
            .resizable()
            .interpolation(.high)
            .frame(width: Self.brandMarkSize, height: Self.brandMarkSize)
            .overlay(
                // Glass sheen sweeping across the mark.
                RoundedRectangle(cornerRadius: Self.brandMarkSize * 0.2237, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.7), Theme.Colors.gold.opacity(0.4), .white.opacity(0.05)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .scaleEffect(revealed || reduceMotion ? 1 : 0.94)
            .shadow(color: .black.opacity(0.45), radius: 18, y: 12)
            .shadow(color: Theme.Shadow.glow, radius: revealed ? 30 : 8)
            // The mark stays centred exactly where the launch screen drew it; the
            // title appears beneath it.
            .overlay(alignment: .top) {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Catch the Jewels")
                        .font(Theme.Typography.display)
                        .foregroundStyle(Theme.Colors.goldGradient)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    Text("A royal jewel hunt")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .fixedSize()
                .offset(y: Self.brandMarkSize + Theme.Spacing.lg)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed || reduceMotion ? 0 : 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Catch the Jewels")
            .accessibilityIdentifier("splash")
            .onAppear {
                withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .easeOut(duration: 0.8)) {
                    revealed = true
                }
            }
    }
}
