import SwiftUI

/// Home: the royal stage artwork with a welcome, Play Now, live statistics, today's
/// challenge and the latest achievement.
struct HomeView: View {
    /// Room left at the top so the crown in the background artwork stays visible.
    private static let artworkCrownClearance: CGFloat = 24

    @Environment(AppModel.self) private var model
    @Environment(ProgressStore.self) private var store

    var body: some View {
        let progress = store.progress
        let challenge = model.todaysChallenge
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero
                    .padding(.top, Self.artworkCrownClearance)

                if let suspended = model.suspendedGame {
                    ResumeRunCard(game: suspended,
                                  onResume: model.resumeSuspendedGame,
                                  onAbandon: model.abandonSuspendedGame)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                    JewelStatCard(title: "Best Score", value: progress.highestScore.formatted(),
                                  icon: .symbol("crown.fill"), identifier: "home.stat.bestScore")
                    JewelStatCard(title: "Jewels", value: progress.totalJewels.formatted(),
                                  icon: .artwork(.jewel(.ruby)), identifier: "home.stat.jewels")
                    JewelStatCard(title: "Games", value: progress.gamesPlayed.formatted(),
                                  icon: .symbol("gamecontroller.fill"), identifier: "home.stat.games")
                }

                DailyChallengeCard(challenge: challenge,
                                   record: store.dailyRecord(for: challenge),
                                   actionTitle: "Open Daily Challenge") {
                    model.openPlay(mode: .daily)
                }

                AchievementHighlightCard(progress: progress) {
                    model.select(.achievements)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
            .readableWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background { RoyalBackground(dimming: .home) }
    }

    private var topBar: some View {
        HStack {
            BadgeLabel(text: "Offline Ready", systemImage: "wifi.slash")
                .accessibilityLabel("Core gameplay works offline. No account needed.")
                .accessibilityIdentifier("home.offlineBadge")
            Spacer()
            RoundIconButton(systemImage: "gearshape.fill", label: "Settings", size: 44) {
                model.isSettingsPresented = true
            }
            .accessibilityIdentifier("home.settings")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xxs)
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                ArtworkView(kind: .crownEmblem, height: 26)
                Text("Catch the Jewels")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.goldGradient)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Text("Ready for the Royal Hunt?")
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Colors.textPrimary)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .accessibilityIdentifier("home.headline")
            Text("Catch jewels. Dodge obstacles. Beat your best.")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.goldLight)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)

            Button {
                model.openPlay()
            } label: {
                Label("Play Now", systemImage: "play.fill")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Opens the Play screen to choose a challenge.")
            .accessibilityIdentifier("home.playNow")
            .padding(.top, Theme.Spacing.xs)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shows the latest unlocked achievement, or the next one within reach.
struct AchievementHighlightCard: View {
    let progress: PlayerProgress
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.Spacing.md) {
                content
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .royalCard(highlighted: progress.latestAchievement != nil)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Achievements.")
        .accessibilityIdentifier("home.achievementCard")
    }

    @ViewBuilder
    private var content: some View {
        if let latest = progress.latestAchievement {
            AchievementBadge(achievement: latest.achievement, unlocked: true, size: 52)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Latest Achievement")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.goldLight)
                Text(latest.achievement.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(progress.unlockedCount) of \(Achievement.allCases.count) unlocked")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        } else if let next = progress.nextAchievement {
            AchievementBadge(achievement: next, unlocked: false, size: 52)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Next Milestone")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.goldLight)
                Text(next.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(next.detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
