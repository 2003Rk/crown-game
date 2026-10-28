import SwiftUI

/// The local player profile: avatar, nickname, rank, statistics and preferences.
/// Not an account — nothing is collected or sent anywhere.
struct ProfileView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(PlayerProfileStore.self) private var profile
    @State private var isEditing = false

    var body: some View {
        let progress = store.progress
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header(progress)
                    statistics(progress)
                    PreferencesSections()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
                .readableWidth()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Profile")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(RoyalBackground())
        }
        .tint(Theme.Colors.gold)
        .sheet(isPresented: $isEditing) {
            EditProfileView()
        }
    }

    private func header(_ progress: PlayerProgress) -> some View {
        let rank = progress.rank
        return VStack(spacing: Theme.Spacing.md) {
            AvatarView(avatar: profile.avatar, size: 96)
            VStack(spacing: Theme.Spacing.xxs) {
                Text(profile.nickname)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("profile.nickname")
                Text("Level \(rank.level) · \(rank.title)")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.goldLight)
            }
            VStack(spacing: Theme.Spacing.xxs) {
                RoyalProgressBar(value: rank.progress(totalJewels: progress.totalJewels))
                Group {
                    if let next = rank.nextThreshold {
                        Text("\(progress.totalJewels.formatted()) / \(next.formatted()) jewels to the next rank")
                    } else {
                        Text("Highest rank reached")
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Button {
                isEditing = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("profile.edit")
        }
        .frame(maxWidth: .infinity)
        .royalCard(padding: Theme.Spacing.lg, highlighted: true)
    }

    private func statistics(_ progress: PlayerProgress) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Statistics")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                JewelStatCard(title: "Games Played", value: progress.gamesPlayed.formatted(),
                              icon: .symbol("gamecontroller.fill"), identifier: "profile.stat.games")
                JewelStatCard(title: "Best Score (Classic)", value: progress.bestScore.formatted(),
                              icon: .symbol("crown.fill"), identifier: "profile.stat.bestScore")
                JewelStatCard(title: "Highest Single Run", value: progress.highestScore.formatted(),
                              icon: .symbol("star.circle.fill"), identifier: "profile.stat.highest")
                JewelStatCard(title: "Jewels Collected", value: progress.totalJewels.formatted(),
                              icon: .artwork(.jewel(.ruby)), identifier: "profile.stat.jewels")
                JewelStatCard(title: "Time Challenge Best", value: progress.bestTimeChallengeScore.formatted(),
                              icon: .symbol("timer"), identifier: "profile.stat.timeBest")
                JewelStatCard(title: "Daily Challenges", value: progress.dailyChallengesCompleted.formatted(),
                              icon: .symbol("calendar.badge.checkmark"), identifier: "profile.stat.dailies")
                JewelStatCard(title: "Achievements", value: "\(progress.unlockedCount)/\(Achievement.allCases.count)",
                              icon: .symbol("trophy.fill"), identifier: "profile.stat.achievements")
                JewelStatCard(title: "Play Time", value: Self.formatPlayTime(progress.totalPlayTime),
                              icon: .symbol("hourglass"), identifier: "profile.stat.playTime")
                JewelStatCard(title: "Best Combo", value: progress.bestCombo.formatted(),
                              icon: .symbol("link"), identifier: "profile.stat.combo")
            }
        }
    }

    /// Active play time (countdowns and pauses excluded), e.g. "4m 05s" or "2h 13m".
    static func formatPlayTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
        return "\(minutes)m \(String(format: "%02d", secs))s"
    }
}

/// A circular avatar with a gold ring.
struct AvatarView: View {
    let avatar: PlayerAvatar
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.Colors.royalGreen, Theme.Colors.emeraldDeep],
                                     center: .center, startRadius: 2, endRadius: size / 2))
            ArtworkView(kind: avatar.artwork,
                        height: avatar.artwork.aspectRatio > 1 ? size * 0.42 : size * 0.58)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.Colors.goldBorder, lineWidth: max(2, size * 0.04)))
        .shadow(color: Theme.Shadow.glow, radius: size * 0.12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Avatar: \(avatar.displayName)")
    }
}

/// Edits the nickname and avatar. Changes are saved only when tapping Save.
struct EditProfileView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var avatar: PlayerAvatar = .crown
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    AvatarView(avatar: avatar, size: 110)
                        .padding(.top, Theme.Spacing.md)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Nickname")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.goldLight)
                        TextField(PlayerProfileStore.defaultNickname, text: $nickname)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .padding(Theme.Spacing.sm)
                            .glassBackground(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous), emphasis: .subtle)
                            .onChange(of: nickname) { _, value in
                                if value.count > PlayerProfileStore.maxNicknameLength {
                                    nickname = String(value.prefix(PlayerProfileStore.maxNicknameLength))
                                }
                            }
                            .accessibilityIdentifier("profile.nicknameField")
                        Text("\(nickname.count)/\(PlayerProfileStore.maxNicknameLength) · Saved only on this device")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .royalCard()

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Avatar")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.goldLight)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: Theme.Spacing.sm)], spacing: Theme.Spacing.sm) {
                            ForEach(PlayerAvatar.allCases) { option in
                                Button {
                                    avatar = option
                                } label: {
                                    AvatarView(avatar: option, size: 64)
                                        .overlay(alignment: .bottomTrailing) {
                                            if option == avatar {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(Theme.Colors.gold, Theme.Colors.emeraldDeep)
                                            }
                                        }
                                        .opacity(option == avatar ? 1 : 0.7)
                                        .frame(minWidth: 72, minHeight: 72)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                                .accessibilityAddTraits(option == avatar ? [.isSelected, .isButton] : .isButton)
                                .accessibilityIdentifier("avatar.\(option.rawValue)")
                            }
                        }
                    }
                    .royalCard()
                }
                .padding(Theme.Spacing.md)
                .readableWidth()
            }
            .background(RoyalBackground())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("profile.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.updateNickname(nickname)
                        profile.avatar = avatar
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .accessibilityIdentifier("profile.save")
                }
            }
        }
        .tint(Theme.Colors.gold)
        .onAppear {
            nickname = profile.nickname
            avatar = profile.avatar
        }
    }
}
