import SwiftUI

/// Dimmed backdrop + centered card used by the pause and game-over overlays.
private struct OverlayCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    content
                }
                .royalCard(padding: Theme.Spacing.lg, highlighted: true)
                .frame(maxWidth: 440)
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - Pause

struct PauseOverlay: View {
    let controller: GameController
    let onResume: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        @Bindable var settings = controller.settings
        OverlayCard {
            ArtworkView(kind: .crownEmblem, height: 64)
            Text("Paused")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pause.title")
            Text("Score \(controller.hud.score.formatted())")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.goldLight)

            Button(action: onResume) {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("pause.resume")

            Button(action: onRestart) {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("Starts a new run. This run's score won't be saved.")
            .accessibilityIdentifier("pause.restart")

            Button(action: onHome) {
                Label("Home", systemImage: "house.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("Keeps this run paused so you can resume it from Home or Play.")
            .accessibilityIdentifier("pause.home")

            Divider().overlay(Theme.Colors.gold.opacity(0.3))

            VStack(spacing: Theme.Spacing.xs) {
                Toggle(isOn: $settings.soundEffectsEnabled) { Label("Sound Effects", systemImage: "speaker.wave.2.fill") }
                Toggle(isOn: $settings.musicEnabled) { Label("Music", systemImage: "music.note") }
                Toggle(isOn: $settings.hapticsEnabled) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary)
            .tint(Theme.Colors.gold)
            .onChange(of: settings.musicEnabled) { _, _ in controller.settingsDidChange() }
        }
    }
}

// MARK: - Game over

struct GameOverOverlay: View {
    let summary: RunSummary
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var appeared = false

    private var result: GameResult { summary.result }

    private var title: String {
        result.endReason == .timeUp ? "Time's Up!" : "Game Over"
    }

    var body: some View {
        OverlayCard {
            Text(title)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("gameover.title")

            VStack(spacing: Theme.Spacing.xxs) {
                Text("Final Score")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(result.score.formatted())
                    .font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Colors.goldGradient)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.7)
                    .accessibilityIdentifier("gameover.score")
            }
            .accessibilityElement(children: .combine)

            bestComparison

            HStack(spacing: Theme.Spacing.md) {
                StatBlock(title: "Jewels", value: "\(result.jewelsCaught)", systemImage: "diamond.fill")
                StatBlock(title: "Best Combo", value: "\(result.maxCombo)", systemImage: "link")
            }

            if let challenge = result.mode.dailyChallenge {
                dailyResult(challenge)
            }

            if !summary.newlyUnlocked.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Achievements Unlocked")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.goldLight)
                    ForEach(Array(summary.newlyUnlocked.enumerated()), id: \.element) { index, achievement in
                        HStack(spacing: Theme.Spacing.sm) {
                            AchievementBadge(achievement: achievement, unlocked: true, size: 34)
                            Text(achievement.title)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        // Badges pop in one after another.
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55).delay(0.25 + Double(index) * 0.12),
                                   value: appeared)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("gameover.achievements")
            }

            Button(action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("gameover.playAgain")

            Button(action: onHome) {
                Label("Return Home", systemImage: "house.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("gameover.home")
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var bestComparison: some View {
        if summary.isNewBest {
            BadgeLabel(text: "New Best Score!", systemImage: "crown.fill")
                .accessibilityIdentifier("gameover.newBest")
        } else {
            Text("Best: \(summary.previousBest.formatted())")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityIdentifier("gameover.best")
        }
    }

    private func dailyResult(_ challenge: DailyChallenge) -> some View {
        let completed = summary.dailyCompleted ?? false
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(completed ? "Daily Challenge Complete" : "Daily Challenge Not Yet Complete",
                  systemImage: completed ? "checkmark.seal.fill" : "xmark.circle")
                .font(Theme.Typography.headline)
                .foregroundStyle(completed ? Theme.Colors.success : Theme.Colors.textPrimary)
            Text(challenge.goalDescription)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
            RoyalProgressBar(value: Double(challenge.progress(for: result)) / Double(max(1, challenge.target)))
            Text("\(min(challenge.progress(for: result), challenge.target)) / \(challenge.target)")
                .font(Theme.Typography.caption.monospacedDigit())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameover.daily")
    }
}
