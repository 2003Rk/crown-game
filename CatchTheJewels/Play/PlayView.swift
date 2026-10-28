import SwiftUI

/// The Play tab: a game lobby. Choose a mode, review results, then Start Game.
/// Opening this tab never starts a run by itself.
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(ProgressStore.self) private var store
    @Environment(\.prefersReducedMotion) private var reduceMotion

    var body: some View {
        let progress = store.progress
        let challenge = model.todaysChallenge
        let dailyRecord = store.dailyRecord(for: challenge)
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.xxs) {
                    Text("Choose Your Challenge")
                        .font(Theme.Typography.display)
                        .foregroundStyle(Theme.Colors.goldGradient)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("play.title")
                    Text("Pick a mode, then tap Start Game.")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.md)

                if let suspended = model.suspendedGame {
                    ResumeRunCard(game: suspended,
                                  onResume: model.resumeSuspendedGame,
                                  onAbandon: model.abandonSuspendedGame)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    GameModeCard(
                        kind: .classic,
                        artwork: .catcher,
                        badgeSymbol: "heart.fill",
                        detail: "Three lives. Catch jewels, avoid bombs. Jewels fall faster the longer you last.",
                        stats: ["Best \(progress.bestScore.formatted())", "Ends when lives run out"],
                        isSelected: model.selectedMode == .classic
                    ) { select(.classic) }

                    GameModeCard(
                        kind: .timeChallenge,
                        artwork: .jewel(.gold),
                        badgeSymbol: "timer",
                        detail: "\(Int(GameMode.timeChallengeDuration)) seconds on the clock. Catch as many jewels as you can before time runs out.",
                        stats: ["Best \(progress.bestTimeChallengeScore.formatted())", "\(Int(GameMode.timeChallengeDuration))-second round"],
                        isSelected: model.selectedMode == .timeChallenge
                    ) { select(.timeChallenge) }

                    GameModeCard(
                        kind: .daily,
                        artwork: challenge.artwork,
                        badgeSymbol: "calendar",
                        detail: "\(challenge.title): \(challenge.goalDescription) The same jewels for everyone today — no internet needed.",
                        stats: [dailyRecord.completed ? "Completed today" : "Not yet completed",
                                dailyRecord.bestScore > 0 ? "Today's best \(dailyRecord.bestScore.formatted())" : "New challenge every day"],
                        isSelected: model.selectedMode == .daily
                    ) { select(.daily) }
                }

                LastRunCard(lastRun: progress.lastRun, highestScore: progress.highestScore)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .readableWidth()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                model.startSelectedMode()
            } label: {
                VStack(spacing: 2) {
                    Label("Start Game", systemImage: "play.fill")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                    Text(model.selectedMode.title)
                        .font(Theme.Typography.caption)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Start Game, \(model.selectedMode.title)")
            .accessibilityIdentifier("play.start")
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .readableWidth()
        }
    }

    private func select(_ kind: GameModeKind) {
        guard model.selectedMode != kind else { return }
        model.haptics.play(.selection)
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
            model.selectedMode = kind
        }
    }
}

/// A large, selectable game-mode card with an illustration.
struct GameModeCard: View {
    let kind: GameModeKind
    let artwork: ArtworkKind
    let badgeSymbol: String
    let detail: String
    let stats: [String]
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.Colors.royalGreen, Theme.Colors.emeraldDeep],
                                             center: .center, startRadius: 2, endRadius: 40))
                        .overlay(Circle().strokeBorder(Theme.Colors.gold.opacity(0.5), lineWidth: 1))
                        .frame(width: 72, height: 72)
                    ArtworkView(kind: artwork, height: artwork.aspectRatio > 1 ? 34 : 44)
                        .frame(width: 72, height: 72)
                    Image(systemName: badgeSymbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textOnGold)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.Colors.goldGradient))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack {
                        Text(kind.title)
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer(minLength: Theme.Spacing.xs)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.Colors.gold : Theme.Colors.textSecondary.opacity(0.6))
                            .accessibilityHidden(true)
                    }
                    Text(detail)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.xs) { statLabels }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) { statLabels }
                    }
                    .padding(.top, Theme.Spacing.xxs)
                }
            }
            .multilineTextAlignment(.leading)
            .royalCard(highlighted: isSelected)
            .scaleEffect(isSelected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("mode.\(kind.rawValue)")
    }

    @ViewBuilder
    private var statLabels: some View {
        ForEach(stats, id: \.self) { stat in
            Text(stat)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.goldLight)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.emeraldDeep.opacity(0.7)))
        }
    }
}

/// Summary of the most recent finished run.
private struct LastRunCard: View {
    let lastRun: RunRecord?
    let highestScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    previousRunTitle
                    Spacer()
                    bestEver
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    previousRunTitle
                    bestEver
                }
            }
            if let run = lastRun {
                Text("\(run.mode.title) · \(run.date.formatted(.relative(presentation: .named)))")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                    StatBlock(title: "Score", value: run.score.formatted())
                    StatBlock(title: "Jewels", value: run.jewels.formatted())
                    StatBlock(title: "Combo", value: run.maxCombo.formatted())
                    StatBlock(title: "Time", value: Duration.seconds(run.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .accessibilityIdentifier("play.lastRun")
            } else {
                Text("No runs yet. Your latest result will appear here.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityIdentifier("play.noRuns")
            }
        }
        .royalCard()
    }

    private var previousRunTitle: some View {
        Label("Previous Run", systemImage: "clock.arrow.circlepath")
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.goldLight)
    }

    private var bestEver: some View {
        Text("Best ever \(highestScore.formatted())")
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .accessibilityIdentifier("play.bestEver")
    }
}
