import SwiftUI

struct AchievementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProgressStore.self) private var store

    private var isActive: Bool { model.selectedTab == .achievements }

    var body: some View {
        let progress = store.progress
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Royal Achievements")
                    .font(Theme.Typography.display)
                    .foregroundStyle(Theme.Colors.goldGradient)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Theme.Spacing.md)

                summary(progress)

                if progress.unlockedCount == 0 {
                    EmptyStateView(
                        artwork: .crownEmblem,
                        title: "Your Trophy Case Awaits",
                        message: "Every jewel you catch counts toward an achievement. Play your first run to start earning royal honours.",
                        actionTitle: "Play Now"
                    ) {
                        model.openPlay()
                    }
                    .accessibilityIdentifier("achievements.empty")
                }

                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementRow(achievement: achievement,
                                       progress: progress,
                                       isNew: model.recentlyUnlocked.contains(achievement),
                                       isActive: isActive)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
            .readableWidth()
        }
        .scrollIndicators(.hidden)
        .onChange(of: model.selectedTab) { previous, _ in
            // Badges stay "new" until the player has seen them and leaves the tab.
            if previous == .achievements { model.markAchievementsSeen() }
        }
    }

    private func summary(_ progress: PlayerProgress) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.lg) {
                summaryRing(progress)
                summaryDetails(progress)
            }
            VStack(spacing: Theme.Spacing.md) {
                summaryRing(progress)
                summaryDetails(progress)
            }
        }
        .royalCard(highlighted: true)
        .accessibilityElement(children: .combine)
    }

    private func summaryRing(_ progress: PlayerProgress) -> some View {
        ProgressRing(value: progress.completionFraction, lineWidth: 9)
            .frame(width: 92, height: 92)
    }

    private func summaryDetails(_ progress: PlayerProgress) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(progress.unlockedCount) of \(Achievement.allCases.count) unlocked")
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityIdentifier("achievements.unlockedCount")
            Text(progress.completionFraction, format: .percent.precision(.fractionLength(0)))
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.goldLight)
            + Text(" complete")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
            RoyalProgressBar(value: progress.completionFraction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let progress: PlayerProgress
    let isNew: Bool
    let isActive: Bool

    @Environment(\.prefersReducedMotion) private var reduceMotion
    @State private var celebrating = false

    var body: some View {
        let unlocked = progress.isUnlocked(achievement)
        let counts = achievement.displayProgress(progress)
        HStack(spacing: Theme.Spacing.md) {
            AchievementBadge(achievement: achievement, unlocked: unlocked, size: 54)
                .scaleEffect(celebrating ? 1.18 : 1)
                .rotationEffect(.degrees(celebrating ? -8 : 0))

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.xs) {
                        achievementTitle(unlocked: unlocked)
                        newBadge
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        achievementTitle(unlocked: unlocked)
                        newBadge
                    }
                }
                Text(achievement.detail)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked, let date = progress.unlockedAchievements[achievement.rawValue] {
                    Label("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.success)
                } else if achievement.isBinary {
                    Label("Locked", systemImage: "lock.fill")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    RoyalProgressBar(value: Double(counts.current) / Double(max(1, counts.target)))
                    Text("\(counts.current.formatted()) / \(counts.target.formatted())")
                        .font(Theme.Typography.caption.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .royalCard(padding: Theme.Spacing.sm, highlighted: unlocked)
        .opacity(unlocked ? 1 : 0.78)
        .shadow(color: celebrating ? Theme.Shadow.glow : .clear, radius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title). \(achievement.detail)")
        .accessibilityValue(accessibilityStatus(unlocked: unlocked, counts: counts))
        .accessibilityIdentifier("achievement.\(achievement.rawValue)")
        .onAppear(perform: celebrateIfNeeded)
        .onChange(of: isActive) { _, _ in celebrateIfNeeded() }
    }

    private func achievementTitle(unlocked: Bool) -> some View {
        Text(achievement.title)
            .font(Theme.Typography.headline)
            .foregroundStyle(unlocked ? Theme.Colors.goldLight : Theme.Colors.textPrimary)
    }

    @ViewBuilder
    private var newBadge: some View {
        if isNew {
            Text("NEW")
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.Colors.textOnGold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.Colors.goldGradient))
        }
    }

    /// A brief bounce-and-glow for achievements unlocked since the last visit.
    private func celebrateIfNeeded() {
        guard isNew, isActive, !reduceMotion else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { celebrating = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) { celebrating = false }
    }

    private func accessibilityStatus(unlocked: Bool, counts: (current: Int, target: Int)) -> String {
        if unlocked { return isNew ? "Unlocked, new" : "Unlocked" }
        if achievement.isBinary { return "Locked" }
        return "Locked, \(counts.current) of \(counts.target)"
    }
}
