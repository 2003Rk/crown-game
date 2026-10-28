import SwiftUI

/// Today's challenge with its status and an action.
struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    let record: PlayerProgress.DailyRecord
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Daily Challenge", systemImage: "calendar")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                DailyStatusLabel(completed: record.completed)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                ArtworkView(kind: challenge.artwork, height: 40)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(challenge.title)
                        .font(Theme.Typography.title2)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(challenge.goalDescription)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if record.bestScore > 0 {
                Text("Today's best: \(record.bestScore.formatted())")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.goldLight)
            }
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Label(actionTitle, systemImage: "flag.checkered")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("daily.open")
            }
        }
        .royalCard(highlighted: !record.completed)
        .accessibilityElement(children: .contain)
    }
}

/// "Completed" / "Open" with icon and text, never color alone.
struct DailyStatusLabel: View {
    let completed: Bool

    var body: some View {
        Group {
            if completed {
                Label("Completed", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Colors.success)
                    .accessibilityIdentifier("daily.completed")
            } else {
                Label("Open", systemImage: "circle.dashed")
                    .foregroundStyle(Theme.Colors.goldLight)
            }
        }
        .font(Theme.Typography.caption)
    }
}

extension DailyChallenge {
    /// The jewel that best represents today's goal.
    var artwork: ArtworkKind {
        switch goal {
        case .catchKind(let kind, _): return .jewel(kind)
        case .flawless: return .heart
        case .catchJewels: return .jewel(.emerald)
        case .reachScore: return .jewel(.gold)
        }
    }
}

/// Card shown when a paused run can be resumed.
struct ResumeRunCard: View {
    let game: GameController
    let onResume: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Run in progress", systemImage: "pause.circle.fill")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.goldLight)
            Text("\(game.mode.title) · Score \(game.hud.score.formatted()) · \(game.hud.lives) \(game.hud.lives == 1 ? "life" : "lives") left")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    actionButtons
                }
                VStack(spacing: Theme.Spacing.sm) {
                    actionButtons
                }
            }
        }
        .royalCard(highlighted: true)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onResume) { Label("Resume", systemImage: "play.fill") }
            .buttonStyle(PrimaryButtonStyle())
            .frame(minWidth: 120)
            .accessibilityIdentifier("resume.run")
        Button(action: onAbandon) { Text("End Run") }
            .buttonStyle(SecondaryButtonStyle())
            .frame(minWidth: 120)
            .accessibilityHint("Discards the paused run without saving it.")
            .accessibilityIdentifier("resume.abandon")
    }
}

/// Round achievement medallion: gold when unlocked, subdued with a lock when not.
struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked ? AnyShapeStyle(Theme.Colors.goldGradient) : AnyShapeStyle(Theme.Colors.emeraldDeep))
                .overlay(Circle().strokeBorder(Theme.Colors.gold.opacity(unlocked ? 0.95 : 0.3), lineWidth: 1.5))
                .shadow(color: unlocked ? Theme.Shadow.glow : .clear, radius: 8)
            Image(systemName: unlocked ? achievement.symbol : "lock.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(unlocked ? Theme.Colors.textOnGold : Theme.Colors.textSecondary.opacity(0.7))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
